extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Mentor := preload("res://sim/mentor.gd")
const WINDOW := 40.0
const FLAME_THRESHOLD := 2.0

var passed := 0
var failed := 0

func _initialize() -> void:
	var one := _measure("one", _ring(1, 0.0))
	var two := _measure("two", _ring(2, 0.043))
	var loose := _measure("loose five", _ring(5, 0.043), true)
	var airy := _measure("airy ten", _ring(10, 0.043, 0.078))
	var dense := _measure("dense five", _ring(5, 0.018))
	var packed := _measure("packed ten", _ring(10, 0.012))
	var lumped := Fire.new(Fire.ONE_EMBER)
	lumped.add_fuel(4, Vector2.ZERO, 0.0, 0.0, 0, true, 5.0)
	var bundle := _measure("porous bundle", lumped)
	var thick := Fire.new(Fire.ONE_EMBER)
	var coarse_piece := thick.add_fuel(6, Vector2.ZERO, 0.0, 0.0, 0, true)
	coarse_piece.original = Fire.FIBRE_MASS * 5.0
	coarse_piece.wood = coarse_piece.original
	coarse_piece.water = coarse_piece.original * Fire.SPECIES[4].water
	var coarse := _measure("same mass of coarse wood", thick)
	var wet := _measure("soaked one", _ring(1, 0.0, 0.0, 1.8))
	var wet_nest := _measure("soaked five", _ring(5, 0.043, 0.0, 1.8))
	var repeat := _measure("loose five, repeat", _ring(5, 0.043), true)
	var cold := _ring(5, 0.043)
	cold.coals[0].temperature = cold.ambient()
	var cold_result := _measure("cold coal under dry nest", cold)

	_check(one.first > 0 and two.first > 0 and loose.first > 0 and airy.first > 0,
		"One, two, five and ten dry parcels can ignite with adequate air")
	_check(loose.retained_heat > one.retained_heat and loose.energy > one.energy * 3.0 and airy.energy > loose.energy,
		"An airy nest retains more heat across the coal and fibres and supplies a longer, stronger flame")
	_check(loose.preflame_smolder >= 3 and airy.preflame_smolder >= 3 and loose.smolder_energy > 1.0,
		"Several separate fine parcels oxidise locally before open flame")
	_check(dense.air < loose.air * 0.25 and dense.energy < loose.energy,
		"A five-piece compact stack restricts air and delivers less sustained flaming")
	_check(packed.air < 0.10 and packed.first < 0.0 and airy.first > 0.0,
		"Packing the same ten dry parcels tightly can prevent flame")
	_check(coarse.mass == loose.mass and coarse.first < 0 and coarse.smolder_energy == 0.0,
		"Equal dry mass as one coarse piece does not behave like a fibrous nest")
	_check(wet.first < 0 and wet_nest.first < 0 and wet.coal_loss > one.coal_loss and wet_nest.coal_loss > loose.coal_loss,
		"Soaked fibres cool the coal and fail to sustain flame")
	_check(bundle.mass == loose.mass and bundle.first > 0 and bundle.smolder_energy > 1.0 and
		absf(bundle.energy - loose.energy) / loose.energy < 0.25,
		"One effective porous bundle and five loose parcels of the same mass both smolder and flame")
	_check(loose == repeat, "Identical starting geometry gives identical heat, reaction and ignition readings")
	_check(cold_result.first < 0.0 and cold_result.smolder_energy == 0.0 and cold_result.coal_loss == 0.0,
		"A cold coal under a dry nest supplies no ignition energy")
	for sample in [one, two, loose, airy, dense, packed, bundle, coarse, wet, wet_nest, cold_result]:
		_check(sample.balance < 1.0e-8 and sample.chemistry_error < 1.0e-7 and sample.starts_cold,
			"%s conserves pair exchange and debits smolder heat from cold fuel mass" % sample.label)
	_check(loose.speaker, "The Fire Speaker recognises the breathing, smoldering nest")
	_compare_subdivision()
	print("Phase 1.3.1 tinder: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _ring(count: int, radius: float, outer := 0.0, moisture := -1.0) -> Fire:
	var fire := Fire.new(Fire.ONE_EMBER)
	for i in range(count):
		var angle := TAU * i / count
		var distance := outer if outer > 0.0 and i % 2 else radius
		var piece := fire.add_fuel(4, Vector2.from_angle(angle) * distance, angle + PI * 0.5, 0.0, 0, true)
		if moisture >= 0.0:
			piece.water = piece.original * moisture
	return fire

func _measure(label: String, fire: Fire, teach := false) -> Dictionary:
	var ember: Fire.Piece = fire.coals[0]
	var fuel: Array[Fire.Piece] = fire.wood.duplicate()
	var room := fire.ambient()
	var initial_heat := ember.capacity() * (ember.temperature - room)
	var first := -1.0
	var peak := 0.0
	var flame_energy := 0.0
	var smolder_energy := 0.0
	var mass := 0.0
	var starts_cold := true
	var balance := 0.0
	var coal_loss := 0.0
	var coal_temperature := 0.0
	var tinder_temperature := 0.0
	var air := 1.0
	var retained_heat := 0.0
	var glowing_before_flame := {}
	var elder := Mentor.new()
	if teach:
		elder.enter(fire, true, 4)
		elder.tend("place", fire)
	for piece in fuel:
		mass += piece.original
		starts_cold = starts_cold and piece.temperature == room
	for tick in range(int(WINDOW / Fire.STEP)):
		fire.step()
		if teach:
			elder.observe(fire)
			elder.tick(Fire.STEP)
		var flame := fire.total_flame()
		peak = maxf(peak, flame)
		flame_energy += flame * Fire.STEP
		var exchanged := 0.0
		for node in fire.nodes:
			exchanged += node.conduction
			smolder_energy += node.smolder * Fire.STEP
			if node.smolder > 0.13 and first < 0.0 and flame < FLAME_THRESHOLD:
				glowing_before_flame[node.id] = true
		balance = maxf(balance, absf(exchanged))
		if first < 0.0 and flame > FLAME_THRESHOLD:
			first = fire.time
		if tick == 11:
			coal_temperature = ember.temperature
			coal_loss = initial_heat - ember.capacity() * (ember.temperature - room)
			retained_heat = ember.stored_heat(room)
			for piece in fuel:
				retained_heat += piece.stored_heat(room)
				tinder_temperature = maxf(tinder_temperature, piece.temperature)
				air = minf(air, piece.oxygen)
	var debited_energy := 0.0
	for piece in fuel:
		debited_energy += piece.smoldered * (1.0 - float(Fire.SPECIES[piece.kind].yield)) * Fire.FIBRE_OXIDATION_ENERGY
	var speaker := elder.history.any(func(line): return "wake many fibers" in line)
	print("%s | at 3s coal %.1f C, loss %.2f kJ, tinder %.1f C, min O2 %.3f | preflame parcels %d, smolder %.2f kJ | onset %.2f s, peak %.2f kW, flame %.1f kJ" %
		[label, coal_temperature, coal_loss, tinder_temperature, air, glowing_before_flame.size(),
			smolder_energy, first, peak, flame_energy])
	return {
		"label": label.trim_suffix(", repeat"), "mass": mass, "first": first, "energy": flame_energy,
		"smolder_energy": smolder_energy, "preflame_smolder": glowing_before_flame.size(),
		"coal_loss": coal_loss, "air": air, "balance": balance, "starts_cold": starts_cold,
		"retained_heat": retained_heat,
		"chemistry_error": absf(smolder_energy - debited_energy), "speaker": speaker,
	}

func _compare_subdivision() -> void:
	var whole := _ring(5, 0.043)
	var split := Fire.new(Fire.ONE_EMBER)
	for parcel in whole.wood:
		for half in range(2):
			split.add_fuel(4, parcel.at, parcel.axis.angle(), 0.0, 0, true, 0.5)
	# Placement seats the entire stack. Match the thermal footprints after the last placement.
	for i in range(split.wood.size()):
		var parcel := whole.wood[i >> 1]
		split.wood[i].height = parcel.height
		split.wood[i].heat_axis = parcel.heat_axis
	var a := whole.coals[0]
	var b := split.coals[0]
	var largest_difference := 0.0
	for tick in range(4):
		whole.step()
		split.step()
		largest_difference = maxf(largest_difference, absf(a.conduction - b.conduction))
	print("      Footprint deltas kW %.8f, °C %.8f, shelter %.8f, air %.8f" %
		[largest_difference, absf(a.temperature - b.temperature), absf(a.fibre_shelter - b.fibre_shelter), absf(a.oxygen - b.oxygen)])
	_check(largest_difference < 1.0e-5 and absf(a.temperature - b.temperature) < 0.01
		and absf(a.fibre_shelter - b.fibre_shelter) < 1.0e-6 and absf(a.oxygen - b.oxygen) < 1.0e-6,
		"Doubling parcels at the same footprints and mass changes initial ember temperature by less than 0.01°C")

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
