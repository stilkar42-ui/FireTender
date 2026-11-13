extends SceneTree

const Fire := preload("res://sim/fire.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	_end_burn()
	_materials()
	_loads()
	_weight_limit()
	_inner_evaporation()
	_fracture()
	_falling_char()
	print("Phase 1.5 grain: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _end_burn() -> void:
	var fire := Fire.new(Fire.GRAIN_END)
	var timber: Fire.Piece = fire.wood.back()
	var hot := timber.sections[0]
	var middle := timber.sections[2]
	var far := timber.sections[3]
	var events := {"break": 0, "land": 0}
	fire.structure_event.connect(func(kind, _at, _mass, _height, _temperature):
		events[kind] = events.get(kind, 0) + 1)
	_check(timber.kind == 10 and timber.sections.size() == 4 and hot.inner.size() == 2,
		"The playable end-burn log has four slices with skin, intermediate grain and core")
	_run(fire, 15.0)
	print("      End burn at 15 s: near %.0f°C / %.1f kW / %.1f g water, far %.0f°C / %.1f kW / %.1f g water" %
		[hot.temperature, hot.flame, hot.water * 1000.0, far.temperature, far.flame, far.water * 1000.0])
	_check(hot.flame > 3.0 and hot.water < far.water * 0.84 and far.wood > far.original * 0.98 and far.flame < 0.3,
		"The exposed end burns and dries while the far end remains sound")
	_check(hot.faces[1].temperature > hot.inner[1].temperature and hot.inner[1].temperature > far.inner[1].temperature,
		"The hot underside and the inner grain retain distinct temperatures")
	_run(fire, 25.0)
	_check(middle.charred_wood > middle.original * 0.08 and far.charred_wood < far.original * 0.04 and
		hot.upper_radius < far.upper_radius and hot.lower_radius < far.lower_radius,
		"Charring advances along the middle while the far end retains its local cross-section")
	var before := timber.stored_heat(fire.ambient())
	var bottom := hot.faces[1]
	var inner := hot.inner[1]
	_check(fire.turn_fuel(timber) and hot.faces[0] == bottom and hot.inner[0] == inner and
		is_equal_approx(timber.stored_heat(fire.ambient()), before),
		"Rolling exposes a different face and preserves grain history and heat")
	var unturned := Fire.new(Fire.GRAIN_END)
	var unturned_log: Fire.Piece = unturned.wood.back()
	_run(unturned, 180.0)
	_check(unturned.last_char_fall > 0.0 and (unturned_log not in unturned.wood or unturned_log.wood < 0.02),
		"The unassisted demonstration sheds hot material as it burns through")
	_run(fire, 140.0)
	_check(events.land > 0, "Falling charcoal also occurs after the player rolls the burning log")

func _materials() -> void:
	var profiles := Fire.Materials.PROFILES
	var along := Fire.Materials.coupling(Fire.Materials.OAK, 0.0, 0.0, 0)
	var radial := Fire.Materials.coupling(Fire.Materials.OAK, 0.0, 0.0, 1)
	var around := Fire.Materials.coupling(Fire.Materials.OAK, 0.0, 0.0, 2)
	_check(along > radial * 1.5 and radial > around and
		Fire.Materials.coupling(Fire.Materials.OAK, 0.65, 0.0, 0) < along,
		"Heat follows grain more readily, and a tilted grain changes the projected coupling")
	var readings := []
	for kind in [11, 12, 13]:
		var fire := Fire.new(Fire.HEAT_DEEP_BED)
		fire.wood.pop_back()
		var piece := fire.add_fuel(kind, Vector2.ZERO, 0.0, 0.0, 1, true)
		var form: Dictionary = profiles[piece.material]
		_check(is_equal_approx(piece.original, piece.volume * float(form.density)),
			"%s dry mass follows volume and density" % form.name)
		var water := piece.water
		_run(fire, 14.0)
		readings.append(Vector3(piece.original, water - piece.water, piece.charred_wood))
		print("      %s branch at 14 s: %.0f°C, dried %.2f g, charred %.2f g" %
			[form.name, piece.temperature, (water - piece.water) * 1000.0, piece.charred_wood * 1000.0])
	_check(readings[1].x > readings[0].x and readings[0].x > readings[2].x and
		absf(readings[0].y - readings[2].y) > 0.001 and absf(readings[0].z - readings[1].z) > 0.002,
		"Equal-size pine, birch and willow have different mass, drying and decomposition histories")

func _loads() -> void:
	var fire := Fire.new(Fire.GRAIN_CABIN)
	var upper: Fire.Piece = fire.wood[4]
	var bottom := fire.wood[0]
	var initial := upper.height
	_check(bottom.carried_load > 0.5 and upper.pose.supports.size() >= 2,
		"The playable cabin transmits weight through its lower rails")
	_run(fire, 40.0)
	print("      Cabin upper course height %.3f m initially / %.3f m after 40 s" % [initial, upper.height])
	_check(upper in fire.wood and upper.wood > 0.02 and upper.height < initial - 0.015,
		"A still-combustible upper course settles as the lower contacts erode")
	_run(fire, 60.0)
	_check(upper.height < initial - 0.09 and fire.last_char_fall > 0.0,
		"Further support loss lets the upper course drop and produces fallen charcoal")
	for scenario in [Fire.LEAN_TO, Fire.CONE, Fire.PARALLEL, 11, Fire.HEAT_GAP]:
		var arrangement := Fire.new(scenario)
		_run(arrangement, 35.0)
		_check(arrangement.wood.all(func(piece): return piece.pose != null and is_finite(piece.height)),
			"%s keeps valid supports during combustion" % Fire.SCENARIOS[scenario])

func _weight_limit() -> void:
	var failures: Array[bool] = []
	for kind in [7, 10]:
		var fire := Fire.new(Fire.COLD)
		var lower := fire.add_fuel(10, Vector2.ZERO, 0.0, 0.0, 0, true)
		fire.add_fuel(kind, Vector2.ZERO, PI * 0.5, 0.0, 1, true)
		for slice in lower.sections:
			slice.integrity = 0.23
			slice.upper_radius = 0.014
			slice.lower_radius = 0.014
		fire._apply_weight(fire.wood)
		failures.append(lower.sections.any(func(slice): return slice.crushed))
	_check(not failures[0] and failures[1], "A damaged rail can still carry a stick but crushes under a heavy split")

func _inner_evaporation() -> void:
	var fire := Fire.new(Fire.GRAIN_END)
	var timber: Fire.Piece = fire.wood.back()
	var lane := timber.sections[0].inner[0]
	var skin := timber.sections[0].faces[0]
	skin.wood = 0.0
	lane.temperature = 160.0
	var capacity := lane.capacity()
	var before := lane.water
	fire._vent_inner(lane, skin, Fire.STEP)
	_check(lane.water < before and is_equal_approx(before - lane.water, lane.vapor * Fire.STEP) and
		is_equal_approx((160.0 - lane.temperature) * capacity, lane.drying_heat * Fire.STEP),
		"Interior venting debits both water and latent heat from the actual cell")

func _fracture() -> void:
	var fire := Fire.new(Fire.GRAIN_END)
	var beam: Fire.Piece = fire.wood.back()
	var region := beam.sections[1]
	var surviving := beam.sections[3]
	var hot := beam.sections[0]
	var damaged := region.faces.duplicate()
	damaged.append(region.core)
	damaged.append_array(region.inner)
	for cell in damaged:
		cell.wood = cell.original * 0.025
		cell.water *= 0.1
		cell.charred_wood = cell.original * 0.975
		cell.char_mass = cell.original * 0.07
		cell.temperature = 610.0
	fire._sync_sections(beam)
	fire._update_section_shape(beam)
	var mass := beam.mass()
	var heat := beam.stored_heat(fire.ambient())
	var material := beam.volume
	var split := fire._fracture_weak_section(beam)
	var detached: Fire.Piece = fire.wood.back()
	_check(split and beam != detached and hot in beam.sections and surviving in detached.sections and detached.wood > 0.01,
		"A weak, loaded cross-section separates surviving combustible grain regions")
	_check(is_equal_approx(beam.mass() + detached.mass(), mass) and
		is_equal_approx(beam.volume + detached.volume, material) and
		is_equal_approx(beam.stored_heat(fire.ambient()) + detached.stored_heat(fire.ambient()), heat),
		"Fracturing transfers existing regions without changing their material or sensible heat")
	fire._settle(true)
	var airborne_height := detached.height
	_check(beam.split_end and detached.split_start and detached.airborne and detached.pose.supports.is_empty(),
		"A fracture exposes two new ends and the unsupported half starts in midair")
	fire._settle(true, 0.0625)
	_check(detached.airborne and is_equal_approx(airborne_height - detached.height, 0.5 * Fire.GRAVITY * pow(0.0625, 2)) and
		is_equal_approx(detached.fall_speed, Fire.GRAVITY * 0.0625),
		"The unsupported half accelerates under gravity without a renderer")
	for step in range(8):
		fire._settle(true, 0.0625)
	_check(not detached.airborne and detached.pose.supports.size() > 0 and detached.height < airborne_height,
		"The detached fragment finds its own gravity-constrained rest")

func _falling_char() -> void:
	var fire := Fire.new(Fire.COLD)
	fire.coals.clear()
	fire.cells.clear()
	var face := Fire.Piece.new()
	face.height = 0.45
	face.temperature = 710.0
	face.char_density = 305.0
	face.char_porosity = 0.35
	face.mineral = 0.003
	var carbon := 0.034
	var water := 0.001
	var heat := (carbon * 1.15 + water * 4.18 + face.mineral * 0.8) * (face.temperature - fire.ambient())
	fire._drop_residue(Vector2.ZERO, face, carbon, water)
	fire._land_residue(0.125)
	_check(fire.falling.size() == 1 and fire.coals.is_empty(), "A substantial fragment spends time falling")
	fire._land_residue(0.25)
	var coal := fire.coals[0]
	_check(fire.falling.is_empty() and coal.char_mass == carbon and coal.water == water and
		is_equal_approx(coal.stored_heat(fire.ambient()), heat) and coal.char_density == face.char_density,
		"The landed charcoal retains its carbon, moisture, density and heat")
	fire.step()
	_check(coal.char_heat > 0.0 and coal.char_mass < carbon,
		"The fallen charcoal continues oxidizing in the coal bed")

func _run(fire: Fire, seconds: float) -> void:
	for i in range(roundi(seconds / Fire.STEP)):
		fire.step()

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
