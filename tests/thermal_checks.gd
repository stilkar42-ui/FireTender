extends SceneTree
const Fire := preload("res://sim/fire.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	var readings := {}
	for trial in ["ember", "chunk", "small bed", "deep bed", "gap", "isolated", "open cabin", "tight cabin",
			"established", "wet load", "healthy", "banked", "dying", "preset cabin", "lean-to", "cone", "parallel"]:
		readings[trial] = _measure(trial)
	var ember: Dictionary = readings.ember
	var chunk: Dictionary = readings.chunk
	_check(ember.first > 0.0 and chunk.first > 0.0 and chunk.glow > ember.glow * 2.0,
		"A charcoal chunk and a small ember light the same tinder, with different survival")
	_equal_temperature()
	_check(readings["small bed"].first < 0.0 and readings["deep bed"].first > 0.0 and readings["deep bed"].charred > 10.0,
		"A deep bed heats and ignites the same raised branch that small coals leave unlit")
	var gap: Dictionary = readings.gap
	_check(gap.clearance > 0.06 and gap.radiation > 3.0 and gap.plume > 3.0 and
		gap.hottest > readings.isolated.hottest + 90.0 and readings.isolated.radiation < 0.001,
		"A suspended oak face absorbs radiation and hot gas across a real gap")
	var open: Dictionary = readings["open cabin"]
	var tight: Dictionary = readings["tight cabin"]
	_check(open.air > tight.air + 0.15 and open.first > 0.0 and tight.first < 0.0 and open.energy > tight.energy + 100.0,
		"Matched cabin fuel responds to the geometry of the open and tight cavities")
	_check(readings.established.first > 0.0 and readings.established.peak > 20.0 and readings.established.energy > 1000.0,
		"An established hearth incorporates a fresh split and keeps burning")
	_check(readings.established.dense_char > 0.01 or readings["preset cabin"].dense_char > 0.01,
		"Burning large fuel leaves a substantial dense charcoal patch")
	_check(readings["wet load"].first < 0.0 and readings["wet load"].glow < 20.0,
		"A waterlogged load still suppresses weak coals")
	_check(readings.healthy.first > 0.0 and readings.banked.first > 0.0 and readings.dying.first < 0.0,
		"Healthy and uncovered banked coals light fresh twigs, dying embers do not")
	_check(readings["lean-to"].energy > 10.0 and readings.parallel.energy > 100.0,
		"Prepared lean-to and parallel rails develop flame")
	_check(readings["preset cabin"].first > 0.0 and readings.cone.energy > 500.0,
		"The prepared cabin carries flame upstairs and the cone sustains combustion")
	_coal_history()
	_check_step_size()
	print("Phase 1.4 thermal: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _measure(trial: String) -> Dictionary:
	var scenarios := {
		"ember": Fire.HEAT_EMBER, "chunk": Fire.HEAT_CHUNK, "small bed": Fire.HEAT_SMALL_BED,
		"deep bed": Fire.HEAT_DEEP_BED, "gap": Fire.HEAT_GAP, "isolated": Fire.HEAT_ISOLATED,
		"open cabin": Fire.HEAT_OPEN_CABIN, "tight cabin": Fire.HEAT_TIGHT_CABIN,
		"established": Fire.HEAT_REFUEL, "wet load": Fire.HEAT_OVERLOAD, "healthy": 1,
		"banked": 3, "dying": 9, "preset cabin": Fire.CABIN,
		"lean-to": Fire.LEAN_TO, "cone": Fire.CONE, "parallel": Fire.PARALLEL,
	}
	var fire := Fire.new(scenarios[trial])
	if trial in ["healthy", "banked", "dying"]:
		if trial == "banked":
			fire.uncover()
		fire.add_fuel(1, Vector2.ZERO, 0.0, 0.0, 0, true)
	var target: Fire.Piece = fire.wood[4] if trial.ends_with("cabin") else fire.wood.back()
	var max_surface := 0.0
	var target_peak := 0.0
	var energy := 0.0
	var first := -1.0
	var t30 := 0.0
	var oxygen := 0.0
	var charred := 0.0
	var last_glow := 0.0
	var dense_char := 0.0
	var radiation := 0.0
	var plume := 0.0
	var balanced := true
	var clearance := target.pose.height - target.radius
	for tick in range(560):
		var receiving := target in fire.wood
		fire.step()
		var summed := 0.0
		var conduction := 0.0
		for node in fire.nodes:
			summed += node.radiation_in
			conduction += node.conduction
			balanced = balanced and absf(node.char_heat - node.charcoal_used * 26_000.0 / Fire.STEP) < 0.00001
			balanced = balanced and absf(node.flame - node.gas_used * 15_800.0 / Fire.STEP) < 0.00001
		balanced = balanced and absf(summed - fire.absorbed) < 0.00001 and absf(conduction) < 0.00001
		balanced = balanced and fire.absorbed <= fire.radiated * Fire.RADIATION_CAPTURE_LIMIT + 0.00001
		target_peak = maxf(target_peak, target.flame)
		energy += fire.total_flame() * Fire.STEP
		if target.flame > 2 and first < 0:
			first = fire.time
		var hottest := target.temperature
		if target.sections.is_empty() and receiving:
			radiation += target.radiation_in * Fire.STEP
			plume += target.plume_heat * Fire.STEP
		for region in target.sections:
			hottest = maxf(hottest, maxf(region.faces[0].temperature, region.faces[1].temperature))
			if receiving:
				for face in region.faces:
					radiation += face.radiation_in * Fire.STEP
					plume += face.plume_heat * Fire.STEP
		max_surface = maxf(hottest, max_surface)
		if tick == 3:
			oxygen = target.oxygen
		if tick == 119:
			t30 = hottest
			charred = target.charred_wood * 1000.0
			if not target.sections.is_empty():
				charred = 0.0
				for region in target.sections:
					charred += (region.faces[0].charred_wood + region.faces[1].charred_wood) * 1000.0
		for coal in fire.coals:
			if coal.char_density > 260.0:
				dense_char = maxf(dense_char, coal.char_mass)
			if coal.glow() > 0.045:
				last_glow = fire.time
	print("%-14s T30 %5.0f max %5.0f O2 %.2f char30 %5.1fg first %6.2f peak %6.1f flameE %7.1f glow %5.1fs rad %5.1f plume %5.1f" %
		[trial,t30,max_surface,oxygen,charred,first,target_peak,energy,last_glow,radiation,plume])
	_check(balanced, "%s balances solid conduction, radiant capture and charcoal reaction power" % trial)
	return {
		"first": first, "glow": last_glow, "hottest": max_surface, "air": oxygen, "charred": charred,
		"energy": energy, "peak": target_peak, "radiation": radiation, "plume": plume, "clearance": clearance,
		"dense_char": dense_char,
	}

func _coal_history() -> void:
	var fire := Fire.new(Fire.HEAT_CHUNK)
	var source := fire.coals[0]
	source.water = 0.005
	source.cover = 0.012
	source.mineral = 0.003
	var mass := source.char_mass
	var volume := source.charcoal_volume()
	var energy := source.stored_heat(fire.ambient())
	var composition := Vector3(source.water, source.cover, source.mineral)
	var split := fire.split_coal_at(source.at, Vector2(0.5, 0.0))
	var half: Fire.Piece = fire.coals.back()
	_check(split == 1 and half != source and is_equal_approx(source.char_mass + half.char_mass, mass) and
		is_equal_approx(source.stored_heat(fire.ambient()) + half.stored_heat(fire.ambient()), energy) and
		is_equal_approx(source.charcoal_volume() + half.charcoal_volume(), volume) and
		Vector3(source.water + half.water, source.cover + half.cover, source.mineral + half.mineral).is_equal_approx(composition),
		"Splitting a charcoal chunk preserves heat, material volume, moisture and ash")

func _equal_temperature() -> void:
	var ember := Fire.new(Fire.HEAT_EMBER)
	var chunk := Fire.new(Fire.HEAT_CHUNK)
	var fragment := ember.coals[0]
	var solid := chunk.coals[0]
	# Isolate charcoal longevity from new heat supplied by ignited tinder.
	ember.wood.clear()
	chunk.wood.clear()
	ember._settle()
	chunk._settle()
	fragment.temperature = solid.temperature
	_check(solid.stored_heat(chunk.ambient()) > fragment.stored_heat(ember.ambient()) * 5.0,
		"At the same temperature, a charcoal chunk stores several times the heat of a small ember")
	for tick in range(400):
		ember.step()
		chunk.step()
	_check(solid.glow() > 0.045 and fragment.glow() < 0.045,
		"The larger chunk still glows after the matched small ember fades")

func _check_step_size() -> void:
	var onset := Vector2(-1.0, -1.0)
	for i in range(2):
		var dt := Fire.STEP / float(i + 1)
		var fire := Fire.new(Fire.HEAT_DEEP_BED)
		var branch: Fire.Piece = fire.wood.back()
		for tick in range(roundi(30.0 / dt)):
			fire.step(dt)
			if branch.flame > 2.0 and onset[i] < 0.0:
				onset[i] = fire.time
	_check(onset.x > 0.0 and onset.y > 0.0 and absf(onset.x - onset.y) < 4.0,
		"Quarter- and eighth-second steps both ignite the raised branch within the same window")

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)

