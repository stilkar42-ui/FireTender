extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Feed := preload("res://sim/feeding.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	_nursing()
	_carrying()
	_feeding()
	print("Phase 1.7 firekeeping: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _nursing() -> void:
	var calm := Fire.new(Fire.NURSE_EMBER)
	var gentle := Fire.new(Fire.NURSE_EMBER)
	var hard := Fire.new(Fire.NURSE_EMBER)
	var repeat := Fire.new(Fire.NURSE_EMBER)
	for tick in range(96):
		for fire in [gentle, hard, repeat]:
			if tick % 10 == 0:
				var coal: Fire.Piece = fire.coals[0]
				fire.send_breath(coal.at + Vector2(0, 0.45), coal.at, 3.05 if fire == hard else 0.84, 1.5)
		for fire in [calm, gentle, hard, repeat]:
			fire.step()
	var coal := gentle.coals[0]
	print("      Faint coal after 24s %.1f°C calm / %.1f°C gentle / %.1f°C hard" %
		[calm.coals[0].temperature, coal.temperature, hard.coals[0].temperature])
	_check(coal.temperature > 580.0 and coal.glow() > 0.25 and coal.char_heat > 0.4 and
		coal.char_mass < 0.0135 and calm.coals[0].temperature < 350.0,
		"Timed gentle breaths nurse a faint viable coal through real charcoal oxidation")
	_check(hard.coals[0].temperature < 100.0 and hard.coals[0].at != calm.coals[0].at,
		"Hard airflow cools and displaces the fragile coal")
	_check(coal.temperature == repeat.coals[0].temperature and coal.char_mass == repeat.coals[0].char_mass,
		"The same breath timing produces the same physical result")
	var spent := Fire.new(Fire.NURSE_EMBER)
	spent.coals[0].char_mass = 0.0
	for tick in range(80):
		if tick % 10 == 0:
			spent.send_breath(Vector2(-0.44, 0.45), Vector2(-0.44, 0.0), 0.84, 1.5)
		spent.step()
	_check(spent.coals[0].char_heat == 0.0 and spent.coals[0].char_mass == 0.0 and spent.coals[0].temperature < 490.0,
		"An exhausted coal supplies no oxidation heat despite repeated breaths")
	var pair := Fire.new(Fire.NURSE_EMBER)
	pair.coals[0].char_mass = 0.028
	pair.coals[0].temperature = 650.0
	var neighbour := pair._new_coal(Vector2(-0.405, 0.0), 0.008, 390.0, 0.002)
	var far := pair._new_coal(Vector2(0.5, 0.0), 0.008, 390.0, 0.002)
	for tick in range(24):
		pair.step()
	_check(neighbour.temperature > far.temperature + 80.0, "Heat spreads into neighbouring viable charcoal before distant charcoal")

func _carrying() -> void:
	var loose := Fire.new(Fire.CARRY_EMBER)
	var coal := loose.coals[0]
	var before := [coal.temperature, coal.char_mass, coal.water, coal.mineral, coal.base_capacity, coal.stored_heat(loose.ambient())]
	loose.lift_coal(coal)
	loose.carry_coal(coal, Vector2(0.12, 0.0))
	_check(coal.carried and coal.height == 0.12 and coal not in loose.cells.values(),
		"The lifted ember remains the live object and leaves the ground-deposit index")
	_check(loose.deposit_coal(coal, Vector2(0.12, 0.0)) and not coal.carried and loose.coals.size() == 1 and
		before == [coal.temperature, coal.char_mass, coal.water, coal.mineral, coal.base_capacity, coal.stored_heat(loose.ambient())],
		"Carrying and depositing preserve the coal's actual material, temperature and stored heat")
	var packed := Fire.new(Fire.CARRY_EMBER)
	var packed_coal := packed.coals[0]
	for i in range(packed.wood.size()):
		packed.pose_fuel(packed.wood[i], Vector2(0.12, 0.0) + Vector2.from_angle(TAU * i / 5.0) * 0.012, 0, 0, 0, true)
	packed.lift_coal(packed_coal)
	packed.carry_coal(packed_coal, Vector2(0.12, 0.0))
	packed.deposit_coal(packed_coal, Vector2(0.12, 0.0))
	var loose_peak := 0.0
	var tight_peak := 0.0
	var smolder_first := false
	var balance := 0.0
	for tick in range(160):
		for fire in [loose, packed]:
			if tick % 10 == 0:
				fire.send_breath(Vector2(0.12, 0.45), Vector2(0.12, 0.0), 0.84, 1.5)
			fire.step()
			var exchanged := 0.0
			for node in fire.nodes:
				exchanged += node.conduction
			balance = maxf(balance, absf(exchanged))
		loose_peak = maxf(loose_peak, loose.total_flame())
		tight_peak = maxf(tight_peak, packed.total_flame())
		if loose.total_flame() < 0.5:
			smolder_first = smolder_first or loose.wood.any(func(piece): return piece.smolder > 0.15)
	print("      Carried nest flame %.1f kW loose / %.1f kW tight" % [loose_peak, tight_peak])
	_check(smolder_first and loose_peak > 10.0 and tight_peak < loose_peak * 0.25,
		"A carried faint coal nurses a loose nest through local smolder into flame while a tight nest struggles")
	_check(balance < 0.00000001, "Ember and tinder conduction remains equal and opposite")

func _feeding() -> void:
	var fire := Fire.new(Fire.FEED_FIRE)
	var yaw := PI
	var start := Feed.pose(Vector2(0.51, 0.0), Fire.SPECIES[7].size, yaw, 0.0, 0.055)
	var goal := Feed.pose(Vector2(0.11, 0.0), Fire.SPECIES[7].size, yaw, 0.0, 0.055)
	var path := Feed.sweep(fire, start, goal, Fire.Structure.radius(7))
	var clear := path != null and path.at.distance_to(goal.at) < 0.001
	_check(clear, "A physical path reaches through the open side beneath the larger log")
	var stick := fire.add_fed_fuel(7, goal)
	_check(stick != null and stick.height < fire.wood[2].height - 0.08 and stick.sections.size() == 3,
		"The inserted stick rests beneath the roof with distinct axial heat regions")
	if stick == null:
		return
	var near := stick.sections[2]
	var tail := stick.sections[0]
	var first_end := -1
	var peak := 0.0
	for tick in range(80):
		fire.step()
		if first_end < 0:
			for i in range(stick.sections.size()):
				if stick.sections[i].flame > 0.4:
					first_end = i
					break
		peak = maxf(peak, stick.flame)
		if tick == 15:
			print("      Feeding after 4s inner %.1f°C / outer %.1f°C" % [near.temperature, tail.temperature])
			_check(near.temperature > tail.temperature + 30.0 and near.charred_wood > tail.charred_wood,
				"The leading end heats and chars ahead of the exposed end")
	_check(first_end == 2 and peak > 3.0, "Flame starts at the inserted end and develops beneath the roof")
	var signature := [stick.wood, stick.water, stick.char_mass, stick.gas, stick.stored_heat(fire.ambient())]
	var out := Feed.pose(stick.at + Vector2(0.22, 0.0), stick.size, yaw, 0.0, stick.height + 0.008)
	_check(fire.feed_fuel(stick, out) and signature == [stick.wood, stick.water, stick.char_mass, stick.gas, stick.stored_heat(fire.ambient())],
		"Withdrawing a partially burned stick preserves its heat and fuel")
	var wall := Fire.new(Fire.FEED_FIRE)
	wall.add_fuel(2, Vector2(0.25, 0.0), PI * 0.5, 0.0, -1, true)
	var stopped := Feed.sweep(wall, start, goal, Fire.Structure.radius(7))
	_check(stopped == null or stopped.at.distance_to(goal.at) > 0.05,
		"A solid log across the opening prevents the swept insertion path")
	_check(wall.add_fed_fuel(7, Feed.pose(Vector2(0.25, 0), Fire.SPECIES[7].size, yaw, 0.0, 0.055)) == null,
		"Fuel cannot be committed inside solid wood")
	var crowded := Fire.new(Fire.FEED_FIRE)
	var airy := Fire.new(Fire.FEED_FIRE)
	var tight_stick := crowded.add_fed_fuel(7, goal)
	var airy_stick := airy.add_fed_fuel(7, goal)
	for i in range(5):
		crowded.add_fuel(8, Vector2(0.08, 0.0), 0.0, 0.0, 0, true)
	# Compare local air access before the two fires' global oxygen demands diverge.
	for tick in range(1):
		crowded.step()
		airy.step()
	_check(tight_stick.oxygen < airy_stick.oxygen,
		"Crowding the opening reduces the inserted stick's oxygen supply")
	print("      Opening oxygen %.3f crowded / %.3f open" % [tight_stick.oxygen, airy_stick.oxygen])
	var saved := Fire.new(Fire.COLD)
	var old := saved.add_fuel(7, Vector2(0.60, 0.30), 0.0, 0.0, 0, true)
	old.temperature = 420.0
	old.wood *= 0.72
	old.char_mass = 0.007
	old.water *= 0.4
	var material := Vector3(old.wood, old.water, old.char_mass)
	var stored := old.stored_heat(saved.ambient())
	_check(saved.feed_fuel(old, Feed.pose(old.at, old.size, 0.0, 0.0, 0.035)) and old.sections.size() == 3 and
		material.is_equal_approx(Vector3(old.wood, old.water, old.char_mass)) and is_equal_approx(stored, old.stored_heat(saved.ambient())),
		"Converting an existing small stick to axial regions preserves its material and heat")
	var turn := Fire.new(Fire.COLD)
	var rotating := turn.add_fuel(7, Vector2.ZERO, 0.0, 0.0, 0, true)
	turn.add_fuel(7, Vector2(0.105, 0.105), -PI * 0.25, 0.0, 0, true)
	var quarter := Feed.pose(rotating.at, rotating.size, PI * 0.5, 0.0, rotating.height)
	_check(Feed.clear(turn, quarter, rotating.radius, rotating) and not turn.feed_fuel(rotating, quarter),
		"A yaw change cannot rotate through an obstacle even when its destination is clear")

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
