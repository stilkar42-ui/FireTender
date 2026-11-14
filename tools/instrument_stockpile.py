"""Install opt-in probes in a disposable Godot project copy, then run the benchmark."""

import argparse
from pathlib import Path


def edit(root, name, changes):
    path = root / name
    source = path.read_text(encoding="utf-8")
    for marker, replacement in changes:
        if marker not in source:
            raise RuntimeError(f"Missing probe point in {name}: {marker!r}")
        source = source.replace(marker, replacement, 1)
    path.write_text(source, encoding="utf-8")


def wrappers(root, name, methods):
    path = root / name
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    for name, args, result in methods:
        start = next(i for i, line in enumerate(lines) if line.startswith(f"func {name}("))
        end = start
        while not lines[end].endswith(":"):
            end += 1
        signature = lines[start : end + 1]
        label = path.stem + "." + name
        call = f"_bench{name}({args})"
        body = [*signature, "\tvar probe_at := Probe.start()"]
        body.append(f"\tvar result := {call}" if result else f"\t{call}")
        body.append(f'\tProbe.end("{label}", probe_at)')
        if result:
            body.append("\treturn result")
        elif name == "_prepare_network":
            body.extend([
                '	Probe.rebuilt(probe_at, nodes.size(), links.size())',
                '\tProbe.count("candidate_pairs", nodes.size() * (nodes.size() - 1) / 2)',
                '\tProbe.count("narrow_candidates", get("network_candidates") if "network_candidates" in self else nodes.size() * (nodes.size() - 1) / 2)',
                '\tProbe.count("accepted_links", links.size())',
            ])
        lines[start : end + 1] = [
            *body, "", signature[0].replace(f"func {name}(", f"func _bench{name}("), *signature[1:]
        ]
    lines.insert(1, 'const Probe := preload("res://tools/stockpile_probe.gd")')
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def instrument(root):
    template = Path(__file__).with_name("stockpile_probe.gd.template")
    (root / "tools/stockpile_probe.gd").write_bytes(template.read_bytes())
    optimized_network = "func _network_pair_rows(" in (root / "sim/fire.gd").read_text(encoding="utf-8")
    architecture = "func _exchange_links_native(" in (root / "sim/fire.gd").read_text(encoding="utf-8")
    fire_methods = [
        ("step", "dt", False), ("_prepare_network", "", False), ("_settle", "gravity, fall_step, moved_piece", False),
        ("_refresh_storage_membership", "", False), ("_weather_storage", "elapsed", False),
        ("_apply_weight", "ordered", False), ("preview", "kind, at, yaw, lean, tier, id, precise", True),
    ]
    if architecture:
        fire_methods.extend([
            ("_pack_exchange_links", "", False), ("_exchange_links_native", "", False),
            ("_index_network_occluders", "", False), ("_network_pair_rows", "", True),
        ])
    wrappers(root, "sim/fire.gd", fire_methods)
    wrappers(root, "hearth/construction_3d.gd", [
        ("_refresh", "delta", False), ("_create_log", "piece", False), ("_update_log", "piece, nodes", False),
        ("_ambient_effects", "", False), ("_wood_mesh", "left, center, right, wear, seed, slice, start, end, split", True),
        ("hit", "screen, ignored, logs_only", True),
    ])
    wrappers(root, "hearth/lab.gd", [("_step_budgeted", "ticks", True), ("_update_chapter", "", False)])
    wrappers(root, "hearth/family_props.gd", [("show_workshop", "workshop, household", False)])
    edit(root, "hearth/construction_3d.gd", [
        ("var interval := 0.0\n\tif multiplier", "if Probe.force_reduced and multiplier < 16:\n\t\tmultiplier = 64\n\tvar interval := 0.0\n\tif multiplier"),
    ])
    edit(root, "sim/fire.gd", [
        ("\tvar settle_pile", '\tProbe.count("settle_population", ordered.size())\n\tvar settle_pile'),
        ("piece.pose = Structure.seat(piece.at", "var seat_start := Probe.start()\n\t\tpiece.pose = Structure.seat(piece.at"),
        ("previous if piece.fed else null)\n\t\tif piece.airborne", 'previous if piece.fed else null)\n\t\tProbe.end("Structure.seat", seat_start)\n\t\tif piece.airborne'),
        ("\tvar oxygen_used := 0.0", '\tvar react_start := Probe.start()\n\tvar oxygen_used := 0.0'),
        ("\tsmoke_field.advance(self, dt)", '\tProbe.end("step.surface_reaction", react_start)\n\tvar smoke_start := Probe.start()\n\tsmoke_field.advance(self, dt)\n\tProbe.end("step.smoke", smoke_start)'),
        ("\tfor i in range(wood.size() - 1, -1, -1):\n\t\tvar piece := wood[i]\n\t\tif piece.core", '\tvar interiors_start := Probe.start()\n\tfor i in range(wood.size() - 1, -1, -1):\n\t\tvar piece := wood[i]\n\t\tif piece.core'),
        ("\tfor coal in coals:\n\t\tvar level := Structure.coal_level", '\tProbe.end("step.interiors_and_wear", interiors_start)\n\tfor coal in coals:\n\t\tvar level := Structure.coal_level'),
        (("\tfor i in range(nodes.size()):\n\t\tvar a := nodes[i]\n\t\tnetwork_candidates" if optimized_network
            else "\tfor i in range(nodes.size()):\n\t\tvar a := nodes[i]\n\t\tfor j"),
         '\tvar pair_start := Probe.start()\n\tvar rejected_usec := 0\n\tvar rejected := 0\n\tvar visibility_usec := 0\n\tvar visibility_calls := 0\n\tfor i in range(nodes.size()):\n\t\tvar a := nodes[i]\n'
         + ("\t\tnetwork_candidates" if optimized_network else "\t\tfor j")),
        ("\t\t\tvar b := nodes[j]\n\t\t\tif a.owner", "\t\t\tvar candidate_at := Probe.start()\n\t\t\tvar b := nodes[j]\n\t\t\tif a.owner"),
        ("if a.owner != 0 and a.owner == b.owner:\n\t\t\t\tcontinue", "if a.owner != 0 and a.owner == b.owner:\n\t\t\t\trejected += 1\n\t\t\t\trejected_usec += Time.get_ticks_usec() - candidate_at\n\t\t\t\tcontinue"),
        ("if distance >= reach or gap > 0.83:\n\t\t\t\tcontinue", "if distance >= reach or gap > 0.83:\n\t\t\t\trejected += 1\n\t\t\t\trejected_usec += Time.get_ticks_usec() - candidate_at\n\t\t\t\tcontinue"),
        ("var visibility := _radiation_visibility(from, to, a, b) if geometry else 0.20", "var visibility_start := Probe.start()\n\t\t\t\tvar visibility := _radiation_visibility(from, to, a, b) if geometry else 0.20\n\t\t\t\tvisibility_usec += Time.get_ticks_usec() - visibility_start\n\t\t\t\tvisibility_calls += 1"),
        ("\t\t\tlinks.append(link)\n\tfor link in links:", '\t\t\tlinks.append(link)\n\tProbe.end("network.pairs", pair_start)\n\tProbe.add("network.rejections", rejected_usec, rejected)\n\tProbe.add("network.visibility", visibility_usec, visibility_calls)\n\tfor link in links:'),
    ])
    if architecture:
        instrument_network(root)
    if not architecture:
        edit(root, "sim/fire.gd", [
            ("for link in links:\n\t\tvar i", 'var exchange_start := Probe.start()\n\tfor link in links:\n\t\tvar i'),
            ("\tradiated = 0.0\n\tabsorbed = 0.0\n\tvar kelvin", '\tProbe.end("step.conduction_and_plume", exchange_start)\n\tradiated = 0.0\n\tabsorbed = 0.0\n\tvar kelvin'),
            ("\tfor link in radiant_links:\n\t\tvar a", '\tvar radiation_start := Probe.start()\n\tfor link in radiant_links:\n\t\tvar a'),
            ("\tvar oxygen_used := 0.0", '\tProbe.end("step.radiation", radiation_start)\n\tvar oxygen_used := 0.0'),
        ])


def instrument_network(root):
    changes = []
    for method, reason in (
        ("_new_coal", "coal added"), ("_bench_settle", "structure settled"),
        ("_refresh_storage_membership", "active membership"),
        ("_compact_bed", "coal merged"), ("_spark_hit", "spark receiver promoted"),
    ):
        path = root / "sim/fire.gd"
        source = path.read_text(encoding="utf-8")
        start = source.index(f"func {method}(")
        end = source.find("\nfunc ", start + 1)
        block = source[start:end]
        lines = [
            f'{line}\n{line[:len(line) - len(line.lstrip())]}Probe.invalidate("{reason}")'
            if line.strip() == "network_dirty = true" else line
            for line in block.split("\n")
        ]
        if lines != block.split("\n"):
            changes.append((block, "\n".join(lines)))
    edit(root, "sim/fire.gd", changes)

    def section(before, after, name, indent):
        start = f'{indent}var phase_at_{name} := Probe.start()\n'
        stop = f'{indent}Probe.end("network.{name}", phase_at_{name})\n'
        return [(before, start + before), (after, stop + after)]

    timings = []
    timings += section("			var link := Link.new()", "			var contact := link.proximity", "allocation", "			")
    timings += section("				var solid := _solid_contact", "				if a.fibre and b.fibre:", "solid_contact", "				")
    timings += section("			var contact := link.proximity", "			# Flames can reach", "conductance_and_loads", "			")
    timings += section("			# Flames can reach", "			if link.coal >= 0:\n				var fuel", "flame_and_paths", "			")
    timings += section("			if link.coal >= 0:\n				var fuel", "			var from := positions[i]", "ember_feedback", "			")
    timings += section("			var from := positions[i]", "			# The greatest possible", "radiation_and_views", "			")
    timings += section("			var parallel :=", "			links.append(link)", "crowding", "			")
    timings += section("	for link in links:\n		# Bound outgoing", "\nfunc _network_pair_rows()", "normalization", "	")
    timings += section("	starter_ventilation.resize", "	var pair_start := Probe.start()", "starter_ventilation", "	")
    timings += section("		var pairs: PackedFloat64Array = ClassDB", "		if not pairs.is_empty():", "native_candidate_call", "		")
    timings += section("	var result: PackedFloat64Array = ClassDB.class_call_static(Native.KERNEL, &\"exchange\"", "	if result.size() != nodes.size() * 4 + 1:", "native_exchange_call", "	")
    edit(root, "sim/fire.gd", timings)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    root = parser.parse_args().project.resolve()
    if (root / ".git").exists():
        parser.error("Use a disposable copy without a .git directory")
    instrument(root)
