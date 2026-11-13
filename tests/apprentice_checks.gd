extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Mentor := preload("res://sim/mentor.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	_wet_end()
	_supports()
	_arrangements()
	_speaker()
	_practices()
	_repeatable()
	print("Phase 1.2: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)

func _wet_end() -> void:
	var fire := Fire.new(10)
	var log: Fire.Piece = fire.wood.back()
	var left := log.sections[0]
	var right := log.sections[1]
	_check(left.water == right.water and left.temperature == right.temperature and left.height > right.height + 0.04,
		"The propped damp log starts with matched ends at different heights")
	_advance(fire, 17.0)
	print("      Wet oak after 17s: left %.0f°C, %.1fg water, %.1f flame; right %.0f°C, %.1fg water, %.1f flame" %
		[left.temperature, left.water * 1000, left.flame, right.temperature, right.water * 1000, right.flame])
	_check(left.temperature > right.temperature + 90.0 and left.water + 0.006 < right.water,
		"The end over the fire heats and dries ahead of the far end")
	_check(left.flame > 4.0 and right.flame < 1.0 and left.faces[1].charred_wood > 0.009,
		"Ignition and charring stay at the exposed end")
	var far_core := right.core.temperature
	_advance(fire, 30.0)
	_check(right.core.temperature > far_core + 25.0 and right.flame > 4.0,
		"Heat propagates and the far end can ignite later")

	var face := left.faces[1]
	var original_state := _fuel_signature(log)
	var old_height := log.height
	fire.turn_fuel(log)
	fire.pose_fuel(log, Vector2(0.48, 0.25), PI / 3.0, 0.35, -1)
	_check(left.faces[0] == face and _fuel_signature(log) == original_state and log.height != old_height
		and log.axis.is_equal_approx(Vector2.from_angle(PI / 3.0)),
		"Rolling, lowering, rotating and moving preserve each end's thermal and fuel history")
	var cold_look := fire.preview(2, Vector2(0.83, -0.03), 0.0, 1.2, 0, fire.next_id)
	_check(absf(cold_look.slope) < 0.001 and is_equal_approx(cold_look.height, Fire.Structure.radius(2)),
		"An unsupported requested tilt settles flat on the floor")

func _fuel_signature(piece: Fire.Piece) -> Array:
	var state := []
	for section in piece.sections:
		var nodes: Array[Fire.Piece] = section.faces.duplicate()
		nodes.append(section.core)
		var signatures := {}
		for node in nodes:
			signatures[node] = [node.temperature, node.wood, node.water, node.char_mass, node.gas, node.charred_wood]
		state.append(signatures)
	return state

func _supports() -> void:
	var hearth := Fire.new(Fire.COLD)
	var spot := Vector2(0.55, 0.25)
	var rail := hearth.add_fuel(2, spot, 0.0)
	var above := hearth.add_fuel(2, spot, PI / 2)
	_check(rail.id in above.pose.supports and above.height > rail.height + 0.09,
		"Crossed oak has a concrete vertical support")
	var projected := hearth.preview(2, spot, above.axis.angle(), 0.0, -1, above.id)
	var initial := above.height
	_check(above.height == initial and projected.height < initial - 0.08,
		"Lower-layer preview resolves a different support without moving real fuel")
	hearth.pose_fuel(above, spot, above.axis.angle(), 0.0, -1)
	_check(rail.height > above.height and above.id in rail.pose.supports, "Lowering seats the selected piece under the cross")
	var carried := rail.wood
	hearth.move_fuel(above, Vector2(-0.80, 0.23))
	_check(rail.height < initial - 0.08 and above.id not in rail.pose.supports and rail.wood == carried,
		"Separating a prop settles the supported piece")

	var collapse := Fire.new(Fire.COLD)
	var twig := collapse.add_fuel(1, spot, 0.0)
	var heavy := collapse.add_fuel(3, spot, PI * 0.5)
	var perched := heavy.height
	twig.wood = 0.010
	twig.water = 0.0
	twig.temperature = 555.0
	collapse.step()
	var released := heavy.airborne
	collapse.step()
	_check(released and twig.wood < 0.0085 and not twig.can_support and heavy.height < perched - 0.035
		and twig.id not in heavy.pose.supports, "Burnout of a weakened prop settles the remaining structure")

	var open := Fire.new(1)
	var tight := Fire.new(1)
	var open_tinder := open.add_fuel(1, Vector2.ZERO)
	var tight_tinder := tight.add_fuel(1, Vector2.ZERO)
	for i in range(4):
		tight.add_fuel(2, Vector2.ZERO, 0.0)
	open.step()
	tight.step()
	_check(tight_tinder.oxygen < open_tinder.oxygen * 0.8 and tight.wood[1].height > tight_tinder.height,
		"A low dense stack shields tinder from fresh air")

func _arrangements() -> void:
	var crossed := Fire.new(11)
	var rails := Fire.new(12)
	var cross_tinder: Fire.Piece = crossed.wood.back()
	var rail_tinder: Fire.Piece = rails.wood.back()
	_check(cross_tinder.height > rail_tinder.height + 0.075 and cross_tinder.pose.supports.size() != rail_tinder.pose.supports.size(),
		"Crossed and parallel arrangements place equal kindling at distinct heights")
	_advance(crossed, 0.75)
	_advance(rails, 0.75)
	print("      Matched structures after 0.75s: tinder %.1f°C crossed / %.1f°C parallel" %
		[cross_tinder.temperature, rail_tinder.temperature])
	_check(absf(cross_tinder.temperature - rail_tinder.temperature) > 5.0,
		"Different supports change kindling heating without a structure-specific combustion rule")
	_advance(crossed, 100.0)
	_advance(rails, 100.0)
	_check(_local_residue(rails, Vector2(0.20, 0.27), 0.09) > _local_residue(crossed, Vector2(0.20, 0.27), 0.09) + 0.006,
		"Coal and ash patterns follow the footprint of the stacked fuel")

	var cone := Fire.new(13)
	var slopes := 0
	for piece in cone.wood:
		if piece.kind == 1 and absf(piece.pose.slope) > 0.30 and piece.pose.supports.size() > 1:
			slopes += 1
	_check(slopes >= 3, "A conical arrangement uses several independently supported slopes")

func _local_residue(fire: Fire, point: Vector2, radius: float) -> float:
	var mass := 0.0
	for coal in fire.coals:
		if point.distance_to(coal.at) <= radius:
			mass += coal.char_mass + coal.mineral
	return mass

func _speaker() -> void:
	var wet := Fire.new(8)
	var mentor := Mentor.new()
	mentor.enter(wet, false)
	mentor.observe(wet)
	mentor.tick(0.1)
	_check(mentor.text.contains("hiss") or mentor.text.contains("vapor"),
		"The Speaker describes a real steam cue in the damp trial")
	var first := mentor.text
	for i in range(4):
		wet.step()
		mentor.observe(wet)
		mentor.tick(0.25)
	_check(mentor.history.size() == 1 and mentor.text == first, "Continuous steam leaves a single readable observation")
	mentor.tick(20.0)
	_check(mentor.text.is_empty() and mentor.history[0] == first, "A bubble expires while its words remain in history")

	var pacing := Mentor.new()
	pacing.enter(wet, false)
	pacing._offer("wet", 35)
	pacing._offer("packed", 58)
	pacing.tick(0.1)
	_check(pacing.text.contains("smoke"), "Relevant higher-priority advice takes precedence")
	pacing._offer("packed", 58)
	pacing._offer("gentle", 44)
	pacing.tick(3.0)
	_check(pacing.history.size() == 1, "Global quiet time and topic cooldown prevent chatter")
	pacing.tick(8.0)
	_check(pacing.history.size() == 2 and pacing.text.contains("breath"),
		"A different observation can be spoken after the quiet interval")
	pacing.tick(45.0)
	pacing._offer("packed", 58)
	pacing.tick(0.1)
	_check(pacing.history.size() == 3 and pacing.text != pacing.history[0],
		"A returning condition uses a different authored line")
	var dark := Fire.new(Fire.COLD)
	var cautious := Mentor.new()
	cautious.enter(dark, false)
	cautious.observe(dark)
	cautious.tick(0.1)
	_check(cautious.history.is_empty(), "The elder can watch a cold scene in silence")
	cautious.tend("breathe", dark)
	_advance(dark, 1.0, cautious)
	_check(cautious.text.contains("bed is dark") and dark.total_flame() == 0.0,
		"Tending a cold bed prompts a grounded observation without relighting it")

func _practices() -> void:
	var first := Fire.new(Fire.OPENING)
	var mentor := Mentor.new()
	mentor.enter(first, true)
	_advance(first, 3.0, mentor)
	_check(mentor.lesson == 0 and mentor.history.size() == 1, "Waiting beside the inherited fire leaves the opening lesson active")
	first.add_fuel(1, Vector2(0.18, 0.26))
	mentor.tend("place", first)
	_advance(first, 22.0, mentor)
	_check(mentor.lesson == 1, "A sustained fresh flame advances the opening without a prescribed arrangement")

	var alternative := Fire.new(1)
	var observer := Mentor.new()
	observer.enter(alternative, true)
	var twig := alternative.add_fuel(1, Vector2(-0.76, 0.01))
	alternative.move_fuel(twig, Vector2(-0.26, 0.15))
	observer.tend("move", alternative)
	_advance(alternative, 20.0, observer)
	_check(observer.lesson == 1, "Moving existing tinder also satisfies the airflow practice")

	var damp := Fire.new(10)
	mentor.enter(damp, true, 1)
	var oak: Fire.Piece = damp.wood.back()
	damp.turn_fuel(oak)
	mentor.tend("roll", damp)
	_advance(damp, 32.0, mentor)
	_check(mentor.lesson == 2, "Local drying and heat travel earn the second lesson")

	var coals := Fire.new(1)
	mentor.enter(coals, true, 2)
	_advance(coals, 1.0, mentor)
	coals.add_fuel(0, Vector2.ZERO)
	mentor.tend("place", coals)
	_advance(coals, 18.0, mentor)
	_check(mentor.lesson == 3, "Recovering flame from viable coals earns the third lesson")

	var bank := Fire.new(1)
	mentor.enter(bank, true, 3)
	bank.rake()
	bank.bank()
	mentor.tend("bank", bank)
	_advance(bank, 60.0, mentor)
	_check(mentor.lesson == 3 and mentor.bank_kept, "Banking earns a readiness cue while the fourth lesson waits for recovery")
	bank.uncover()
	bank.add_fuel(1, Vector2.ZERO)
	mentor.tend("place", bank)
	_advance(bank, 28.0, mentor)
	_check(mentor.lesson == 4, "Exposed banked coals earn completion when their heat revives flame")
	mentor.enter(bank, false)
	_check(not mentor.training and not mentor.history.is_empty(), "Free experiments keep the dialogue history separate from progress")

func _repeatable() -> void:
	var first := Fire.new(10)
	var second := Fire.new(10)
	for model in [first, second]:
		var log: Fire.Piece = model.wood.back()
		_advance(model, 20.0)
		model.turn_fuel(log)
		model.pose_fuel(log, Vector2(-0.20, 0.09), 0.34, -0.8, 0)
		_advance(model, 14.0)
	var equal := first.wood.size() == second.wood.size() and first.coals.size() == second.coals.size()
	for i in range(first.wood.size()):
		var a := first.wood[i]
		var b := second.wood[i]
		equal = equal and a.temperature == b.temperature and a.pose.supports == b.pose.supports
		for j in range(a.sections.size()):
			equal = equal and a.sections[j].temperature == b.sections[j].temperature
			equal = equal and a.sections[j].water == b.sections[j].water and is_finite(a.sections[j].temperature)
	_check(equal, "Identical structural interventions give identical supports and end states")

func _advance(fire: Fire, seconds: float, mentor: Mentor = null) -> void:
	for i in range(int(seconds / Fire.STEP)):
		fire.step()
		if mentor != null:
			mentor.observe(fire)
			mentor.tick(Fire.STEP)
