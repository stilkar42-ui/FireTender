extends SceneTree

const Bench := preload("res://tools/stockpile_benchmark.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Fire := Chapter.Fire
const Native := Fire.Native
const Save := preload("res://sim/chapter_save.gd")

var failures := 0
var graphs := 0
var pairs_checked := 0
var links_checked := 0
var max_error := 0.0
var first_difference := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ClassDB.class_has_method(Native.KERNEL, &"build_network"):
		printerr("The native thermal constructor is required for differential testing.")
		quit(1)
		return
	var benchmark := Bench.new()
	var story := Chapter.new(Fire.new())
	var hot: Fire.Piece = benchmark._setup(story, {"stock": 60, "drying": 9, "state": "coal", "layout": "near", "mode": "promote"})
	benchmark.free()
	# The same arrangement as the rendered mass-promotion fixture.
	var fire := story.fire
	fire.pose_fuel(hot, Vector2(-0.17, -1.52), hot.axis.angle(), 0.0, 0, true)
	_compare(fire, "mass promotion")
	_check_continuation(story)
	var rng := RandomNumberGenerator.new()
	rng.seed = 341
	for trial in 16:
		var model := Fire.new()
		model.coals.clear()
		model.wood.clear()
		model.stored.clear()
		for i in 5:
			var coal := model._new_coal(Vector2(rng.randf_range(-0.30, 0.30), rng.randf_range(-0.28, 0.28)),
				rng.randf_range(0.012, 0.073), rng.randf_range(380.0, 720.0), 0.02)
			coal.precise = true
			coal.original = 0.02 if i % 2 == 0 else 0.095
		for i in 10:
			var piece := model._make_fuel([4, 15, 6, 10, 12][i % 5],
				Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35)),
				rng.randf_range(-PI, PI), 0.0, i / 3, true, 1.0, null, 0.51)
			model.wood.append(piece)
		model._settle()
		var low := model.wood[-2]
		var high := model.wood[-1]
		# Parallel touch and near-touch, then cross the 0.25 m cell border.
		low.at = Vector2(0.249999, 0.025)
		high.at = low.at + Vector2(0.0, low.radius + high.radius + (trial % 3 - 1) * 0.000001)
		low.axis = Vector2.RIGHT
		high.axis = Vector2.RIGHT
		model._settle()
		_compare(model, "seeded stack %d" % trial)
		var section := low.sections[0]
		section.upper_radius *= 0.64
		high.at.x = 0.250001
		model._settle()
		model.coals[0].char_mass *= 0.68
		model.coals[0].at.x += 0.085
		_compare(model, "worn stack and moved ember %d" % trial)
	print("Compared %d graphs, %d ordered candidate pairs and %d accepted links. Max absolute coefficient difference %.17f." %
		[graphs, pairs_checked, links_checked, max_error])
	if not first_difference.is_empty():
		printerr(first_difference)
	Native.enabled = true
	quit(1 if failures else 0)

func _check_continuation(story: Chapter) -> void:
	var state := var_to_bytes(Save.capture(story))
	var reference := Chapter.new(Fire.new())
	var optimized := Chapter.new(Fire.new())
	if not Save.restore(reference, bytes_to_var(state)) or not Save.restore(optimized, bytes_to_var(state)):
		_fail("Active combustion snapshot did not restore")
		return
	var steps := 12
	for i in steps:
		for model in [reference, optimized]:
			Native.enabled = model == optimized
			if i in [0, 3, 6, 9]:
				model.fire.send_breath(Vector2.ZERO, Vector2(0.75, -0.65), 1.0, 0.65)
			model.step()
		# The save schema includes all solid regions, moisture, reaction fields,
		# heat accounting, structure, and ordered normalized links.
		var expected := Save.capture(reference)
		var actual := Save.capture(optimized)
		expected.erase("saved_at")
		actual.erase("saved_at")
		var difference := _difference(expected, actual, "save")
		if not difference.is_empty():
			_fail("Restored combustion and directed breath differ at step %d: %s" % [i, difference])
			return
	print("Restored active-combustion state and matched %d complete snapshots with directed breath." % steps)

static func _difference(a: Variant, b: Variant, path: String) -> String:
	if a == b:
		return ""
	if a is Dictionary and b is Dictionary and a.size() == b.size():
		for key in a:
			var delta := _difference(a[key], b.get(key), "%s.%s" % [path, key])
			if not delta.is_empty():
				return delta
	elif a is Array and b is Array and a.size() == b.size():
		for i in a.size():
			var delta := _difference(a[i], b[i], "%s[%d]" % [path, i])
			if not delta.is_empty():
				return delta
	else:
		return "%s (%s vs %s)" % [path, str(a).left(100), str(b).left(100)]
	return ""

func _compare(fire: Fire, label: String) -> void:
	Native.enabled = false
	fire._prepare_network()
	var reference: Array[Fire.Link] = fire.links.duplicate()
	var reference_crowding := fire.crowding.duplicate()
	var reference_ventilation := fire.starter_ventilation.duplicate()
	var rows := fire._network_pair_rows_reference()
	var expected := PackedFloat64Array()
	for i in rows.size():
		for j in rows[i]:
			expected.append(i)
			expected.append(j)
	Native.enabled = true
	var candidates: PackedFloat64Array = ClassDB.class_call_static(Native.KERNEL, &"candidate_pairs", fire._candidate_geometry())
	if expected != candidates:
		_fail(label + " candidate identity or order differs")
	pairs_checked += candidates.size() / 2
	if not fire._build_network_native():
		_fail(label + " native construction rejected the fixture")
		return
	fire._links.clear()
	fire._radiant_links.clear()
	var optimized := fire.links
	if reference.size() != optimized.size():
		_fail(label + " link count differs")
		return
	graphs += 1
	links_checked += reference.size()
	for i in reference_crowding.size():
		_numeric(reference_crowding[i], fire.crowding[i], label, i, "crowding")
		_numeric(reference_ventilation[i], fire.starter_ventilation[i], label, i, "starter ventilation")
	for i in reference.size():
		var a := reference[i]
		var b := optimized[i]
		for field in ["a", "b", "coal", "delta", "toward_wood", "fibre_contact"]:
			if a.get(field) != b.get(field):
				_fail("%s link %d field %s differs" % [label, i, field])
		for field in ["conductance", "proximity", "receive_a", "receive_b", "ember_feedback", "view_a", "view_b"]:
			_numeric(a.get(field), b.get(field), label, i, field)

func _numeric(a: float, b: float, label: String, index: int, field: String) -> void:
	var error := absf(a - b)
	max_error = maxf(error, max_error)
	if a != b:
		_fail("%s index %d %s differs: %.17f vs %.17f (delta %.17f)" % [label, index, field, a, b, error])

func _fail(message: String) -> void:
	failures += 1
	if first_difference.is_empty():
		first_difference = message
