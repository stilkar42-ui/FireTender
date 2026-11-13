extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Mentor := preload("res://sim/mentor.gd")
const Observe := preload("res://sim/observe.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	_building()
	_heating()
	_one_ember()
	_growth()
	print("Phase 1.3 model: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)

func _building() -> void:
	var cabin := Fire.new(Fire.CABIN)
	var base := cabin.wood[0]
	var rail := cabin.wood[2]
	var roof := cabin.wood[4]
	_check(base.sections.size() == 4 and rail.sections.size() == 3 and cabin.wood.back().sections.is_empty(),
		"Fuel scale selects one, three or four local thermal regions")
	_check(cabin.wood[1].id in rail.pose.supports and base.id in rail.pose.supports and
		rail.id in roof.pose.supports and cabin.wood[3].id in roof.pose.supports and roof.height > rail.height + 0.08,
		"Both elevated cabin levels bridge two actual supports")
	var before := _signature(roof)
	var preview := cabin.preview(roof.kind, Vector2(0.64, 0.37), PI * 0.3, 0.66, 2, roof.id, true)
	_check(preview.height < roof.height - 0.15 and before == _signature(roof), "A clear landing preview finds the floor without mutating fuel")
	cabin.turn_fuel(roof)
	cabin.pose_fuel(roof, preview.at, PI * 0.3, 0.66, 2, true)
	_check(roof.height == preview.height and roof.axis.is_equal_approx(Vector2.from_angle(PI * 0.3))
		and before == _signature(roof), "Rotation, rolling and 3D repositioning preserve every region's material and heat")
	var old_height := rail.height
	cabin.move_fuel(base, Vector2(-0.69, -0.4))
	_check(rail.height < old_height - 0.028 and base.id not in rail.pose.supports, "Pulling out a bottom rail settles the bridged fuel")

	var lean := Fire.new(Fire.LEAN_TO)
	var arm := lean.wood[1]
	var tail := arm.pose.point(-arm.pose.span)
	var tip := arm.pose.point(arm.pose.span)
	_check(absf(tail.z - tip.z) > 0.075 and lean.wood[0].id in arm.pose.supports and 0 in arm.pose.supports
		and absf(tail.distance_to(tip) * 0.5 - arm.size) < 0.03, "A leaning branch has different endpoint heights and a floor and wood rest")
	var cone := Fire.new(Fire.CONE)
	var leaning := 0
	for piece in cone.wood:
		if absf(piece.pose.slope) > 0.35:
			leaning += 1
	_check(leaning >= 4 and Fire.new(Fire.PARALLEL).wood.size() == 3, "Cone and open parallel configurations are playable")

	var hearth := Fire.new(Fire.COLD)
	var pole := hearth.add_fuel(7, Vector2(0.60, 0.28), 0.0, 0.0, 0, true)
	var held := hearth.add_fuel(8, pole.at, PI * 0.5, 0.0, 1, true)
	var high := held.height
	pole.wood = 0.030
	pole.temperature = 545.0
	pole.water = 0.0
	hearth.step()
	_check(pole.id in held.pose.supports and held.height < high - 0.004 and pole.can_support,
		"Burning down a 3D support reduces its bearing height before failure")
	pole.wood = 0.0052
	pole.temperature = 545.0
	hearth.step()
	var released := held.airborne
	hearth.step()
	_check(released and pole.id not in held.pose.supports and held.height < high - 0.025,
		"A consumed support lets the upper branch fall to its new rest")

func _heating() -> void:
	var touching := Fire.new(Fire.ONE_EMBER)
	var suspended := Fire.new(Fire.ONE_EMBER)
	var direct := _bridge(touching, -1)
	var raised := _bridge(suspended, 2)
	_advance(touching, 3.0)
	_advance(suspended, 3.0)
	_check(raised.height > direct.height + 0.075 and direct.temperature > raised.temperature + 3.0
		and suspended.coals[0].temperature > touching.coals[0].temperature + 150.0,
		"An air gap weakens direct heating and protects the tiny coal from the suspended cold split")

	var hot := Fire.new(10)
	var wet: Fire.Piece = hot.wood.back()
	var left := wet.sections[0]
	var right := wet.sections[1]
	_advance(hot, 17.0)
	_check(left.temperature > right.temperature + 90.0 and left.water < right.water and left.flame > 4.0 and right.flame < 1.0,
		"A damp elevated end ignites without heating its far end uniformly")
	_advance(hot, 29.0)
	_check(right.flame > 4.0 and right.core.temperature > 110.0, "Heat propagates into the far core and can light the remaining surface")

func _bridge(fire: Fire, tier: int) -> Fire.Piece:
	fire.add_fuel(8, Vector2(-0.15, 0), PI * 0.5, 0, 0, true)
	fire.add_fuel(8, Vector2(0.15, 0), PI * 0.5, 0, 0, true)
	return fire.add_fuel(8, Vector2.ZERO, 0, 0, tier, true)

func _one_ember() -> void:
	var fire := Fire.new(Fire.ONE_EMBER)
	_check(fire.coals.size() == 1 and fire.coal_reserve() < 0.02 and fire.wood.is_empty() and
		fire.total_flame() == 0.0 and "single coal glows" in Observe.read(fire), "One Ember starts with one finite glowing coal")
	var fine := fire.add_fuel(4, Vector2.ZERO, 0, 0, 0, true)
	var spark := fire.coals[0]
	var initial_mass := spark.char_mass
	_check(_advance(fire, 7.0) > 7.0 and fine.charred_wood > 0.001 and spark.char_mass < initial_mass,
		"Prepared fibres catch from the ember's heat and the original coal is consumed")

	var distant := Fire.new(Fire.ONE_EMBER)
	distant.add_fuel(4, Vector2(0.57, 0.1), 0, 0, 0, true)
	_check(_advance(distant, 23.0) < 0.1, "Poor placement leaves tinder unlit")
	var damp := Fire.new(Fire.ONE_EMBER)
	var wet := damp.add_fuel(4, Vector2.ZERO, 0, 0, 0, true)
	wet.water = wet.original * 1.8
	_check(_advance(damp, 22.0) < 0.25 and damp.coals[0].temperature < 300.0, "Soaked tinder consumes the coal's useful heat")

	var loaded := Fire.new(Fire.ONE_EMBER)
	var elder := Mentor.new()
	elder.enter(loaded, true, 4)
	var split := loaded.add_fuel(2, Vector2.ZERO, 0, 0, 0, true)
	elder.tend("place", loaded)
	_check(_advance(loaded, 16.0, elder) == 0.0 and loaded.coals[0].temperature < 130.0
		and elder.history.any(func(line): return "cold branch" in line), "Heavy cold fuel quenches the ember and prompts specific teaching")
	loaded.move_fuel(split, Vector2(0.72, 0.0))
	_advance(loaded, 70.0)
	loaded.add_fuel(4, Vector2.ZERO, 0, 0, 0, true)
	loaded.send_breath(Vector2(0, 0.42), Vector2.ZERO, 0.62, 1.4)
	_check(_advance(loaded, 40.0, elder) == 0.0 and elder.lesson == 4, "Fresh tinder and breath cannot revive a cooled ember")

func _growth() -> void:
	var bark_result := _build_from(4)
	var grass_result := _build_from(5)
	var bark: Fire = bark_result.fire
	var grass: Fire = grass_result.fire
	_check(bark.coal_reserve() > 0.075 and bark_result.branch_seconds >= 12.0 and bark.coals.size() > 2,
		"Fibres can grow through kindling into sustained branch flame and new coals")
	_check(grass.coal_reserve() > 0.085 and grass_result.branch_seconds >= 12.0,
		"Dry grass and a staggered arrangement can also grow a hearth")
	var nest := Fire.new(Fire.NEST)
	var first: Fire.Piece = nest.wood[3]
	var second: Fire.Piece = nest.wood[4]
	var peak := 0.0
	for i in range(100):
		nest.step()
		peak = maxf(peak, first.flame + second.flame)
	_check(peak > 14.0, "A prearranged loose tinder nest can pass flame to its surrounding splinters")
	var repeat: Fire = _build_from(4, false).fire
	_check(bark.total_flame() == repeat.total_flame() and bark.coal_reserve() == repeat.coal_reserve()
		and bark.wood[0].sections[0].temperature == repeat.wood[0].sections[0].temperature,
		"Repeated construction and tending at the same steps give identical results")

func _build_from(kind: int, report := true) -> Dictionary:
	var fire := Fire.new(Fire.ONE_EMBER)
	var elder := Mentor.new()
	elder.enter(fire, true, 4)
	fire.add_fuel(kind, Vector2(0.01, 0.0), 0, 0, 0, true)
	elder.tend("place", fire)
	var fine_peak := 0.0
	var branch_peak := 0.0
	var branch_seconds := 0.0
	for i in range(360):
		if i == (16 if kind == 4 else 20):
			for side in [-1, 1]:
				fire.add_fuel(6, Vector2(0.0, side * 0.10), PI / 2.0, 0, 0, true)
		if i == (32 if kind == 4 else 29) or (i == 52 and kind == 5):
			for side in [-1, 1]:
				fire.add_fuel(7, Vector2(side * 0.096, 0.0), 0, 0, 0, true)
		if i == (56 if kind == 4 else 58):
			fire.add_fuel(8, Vector2(0.02, 0.046), PI * 0.23, 0, 1, true)
		if i == (104 if kind == 4 else 106):
			fire.add_fuel(9, Vector2(-0.04, -0.10), -PI * 0.35, 0, 1, true)
		_advance(fire, Fire.STEP, elder)
		for piece in fire.wood:
			if piece.kind == kind:
				fine_peak = maxf(fine_peak, piece.flame)
			elif piece.kind == 9:
				branch_peak = maxf(branch_peak, piece.flame)
				if piece.flame > 12.0:
					branch_seconds += Fire.STEP
	if report:
		print("      %s build: %.1f kW tinder peak, %.1f kW branch peak, %.1f g bed after 90 s" %
			[Fire.SPECIES[kind].label, fine_peak, branch_peak, fire.coal_reserve() * 1000.0])
		_check(elder.lesson == 5 and elder.history.any(func(line): return "given us a fire" in line),
			"The Fire Speaker recognizes the grown hearth after the %s route" % Fire.SPECIES[kind].label)
	return {"fire": fire, "branch_seconds": branch_seconds}

func _signature(piece: Fire.Piece) -> Dictionary:
	var state := {}
	for section in piece.sections:
		var nodes: Array[Fire.Piece] = section.faces.duplicate()
		nodes.append(section.core)
		for node in nodes:
			state[node] = [node.temperature, node.wood, node.water, node.char_mass, node.gas]
	return state

func _advance(fire: Fire, seconds: float, elder: Mentor = null) -> float:
	var peak := 0.0
	for i in range(int(seconds / Fire.STEP)):
		fire.step()
		peak = maxf(peak, fire.total_flame())
		if elder != null:
			elder.observe(fire)
			elder.tick(Fire.STEP)
	return peak
