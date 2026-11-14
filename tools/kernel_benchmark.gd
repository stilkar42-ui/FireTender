extends SceneTree
## Run from an isolated project containing the extension and this script.

func _initialize() -> void:
	if not ClassDB.class_exists(&"FiretenderKernel"):
		printerr("Build and import the Firetender extension before running this prototype.")
		quit(1)
		return
	var good := true
	for count: int in [89, 243, 480]:
		good = _compare(count) and good
	quit(0 if good else 1)

func _compare(count: int) -> bool:
	var nodes := PackedFloat64Array()
	var links := PackedFloat64Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 34
	for i in count:
		nodes.append_array(PackedFloat64Array([
			rng.randf_range(15.0, 695.0), rng.randf_range(0.01, 0.70), rng.randf_range(0.1, 1.0),
			rng.randf_range(0.1, 2.0) if i % 3 == 0 else 0.0, rng.randf_range(0.0, 2.0),
			rng.randf_range(0.0, 2.0), rng.randf_range(0.001, 0.07), rng.randf(), rng.randf(),
			1.0, 0.0, rng.randf() if i < 9 else 0.0, float(i % 7 == 0)
		]))
	var links_per_node := 8 if count < 100 else 31
	for i in count:
		for j in range(i + 1, mini(count, i + links_per_node)):
			links.append_array(PackedFloat64Array([
				i, j, rng.randf_range(0.0, 0.1), rng.randf(), rng.randf(), rng.randf(), 0.025, 0.027,
				i if i < 9 and j >= 9 else -1, 1.0, 0.0, 0.02, 0.003, 0.002, 0.1 if j < 9 else 0.0
			]))
	var memory := OS.get_memory_info()
	var reference := _reference(nodes, links)
	var native: PackedFloat64Array = ClassDB.class_call_static(&"FiretenderKernel", &"exchange", nodes, links)
	if native.size() != reference.size():
		printerr("Native kernel returned an unexpected buffer size.")
		return false
	var error := 0.0
	var net := 0.0
	for i in native.size():
		error = maxf(error, absf(native[i] - reference[i]))
		if i < count * 4 and i % 4 == 0:
			net += native[i]
	var start := Time.get_ticks_usec()
	for i in 30:
		_reference(nodes, links)
	var script_us := (Time.get_ticks_usec() - start) / 30.0
	start = Time.get_ticks_usec()
	for i in 500:
		ClassDB.class_call_static(&"FiretenderKernel", &"exchange", nodes, links)
	var native_us := (Time.get_ticks_usec() - start) / 500.0
	start = Time.get_ticks_usec()
	for i in 3000:
		ClassDB.class_call_static(&"FiretenderKernel", &"boundary", nodes, links)
	var boundary_us := (Time.get_ticks_usec() - start) / 3000.0
	var repeat: PackedFloat64Array = ClassDB.class_call_static(&"FiretenderKernel", &"exchange", nodes, links)
	var fit: PackedFloat64Array = ClassDB.class_call_static(&"FiretenderKernel", &"fit",
		PackedFloat64Array([-0.5, 0.2, 0.0, 0.2, 0.5, 0.2]), 0.0, 0.0, 0.5)
	print(JSON.stringify({"nodes": count, "links": links.size() / 15, "working_bytes": (nodes.size() + links.size() + native.size()) * 8,
		"system_memory_bytes": memory.get("physical", 0), "script_us": script_us, "native_us": native_us,
		"boundary_us": boundary_us, "max_error": error, "net_conduction_kw": net, "repeat_equal": native == repeat}))
	return error < 1e-11 and absf(net) < 1e-10 and native == repeat and fit == PackedFloat64Array([0.0, 0.2])

func _reference(nodes: PackedFloat64Array, links: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(nodes.size() / 13 * 4 + 1)
	for k in range(0, links.size(), 15):
		var i := int(links[k])
		var j := int(links[k + 1])
		var a := i * 13
		var b := j * 13
		var ra := i * 4
		var rb := j * 4
		var insulation := nodes[a + 2] * nodes[b + 2]
		var capacity := minf(nodes[a + 1], nodes[b + 1])
		if nodes[a + 12] != 0.0 and nodes[b + 12] != 0.0:
			capacity = nodes[a + 1] * nodes[b + 1] / 0.0065
		var exchange := links[k + 2] * insulation * capacity
		var coal := int(links[k + 8])
		if coal >= 0:
			var c := coal * 13
			var to := rb if coal == i else ra
			var aligned := Vector2(nodes[c + 9], nodes[c + 10]).dot(Vector2(links[k + 9], links[k + 10]))
			exchange *= 1.0 + nodes[c + 11] * (0.28 + 0.72 * maxf(0.0, aligned))
			out[to + 1] += nodes[c + 5] * links[k + 11] * insulation
		var heat := exchange * (nodes[b] - nodes[a])
		out[ra] += heat
		out[rb] -= heat
		out[ra + 3] += nodes[b + 6] * links[k + 14]
		out[rb + 3] += nodes[a + 6] * links[k + 14]
		var delta := Vector2(links[k + 4], links[k + 5])
		var lean_a := delta.dot(Vector2(nodes[a + 7], nodes[a + 8])) * 0.18
		var lean_b := delta.dot(Vector2(nodes[b + 7], nodes[b + 8])) * 0.18
		out[rb + 1] += nodes[a + 3] * maxf(0.0, links[k + 3] + lean_a) * links[k + 7] * insulation
		out[ra + 1] += nodes[b + 3] * maxf(0.0, links[k + 3] - lean_b) * links[k + 6] * insulation
		var from_a := nodes[a + 4] * links[k + 12] * nodes[b + 2]
		var from_b := nodes[b + 4] * links[k + 13] * nodes[a + 2]
		out[ra + 2] += from_b
		out[rb + 2] += from_a
		out[-1] += from_a + from_b
	return out
