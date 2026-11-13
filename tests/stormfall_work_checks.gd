extends SceneTree

const Save := preload("res://sim/chapter_save.gd")
const Chapter := Save.Chapter
const W := Save.Work
const T := W.Techniques
const F := Chapter.Family
const Fire := Save.Fire
var passed := 0
var failed := 0

func _initialize() -> void:
	_stormfall()
	_workers()
	_apprentice()
	_throughput()
	print("Stormfall and family work: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _trial(isolate := false) -> Chapter:
	var chapter := Chapter.new(Fire.new())
	chapter.set_up_family_trial()
	if isolate:
		chapter.family.next_council = INF
		chapter.family.next_errand = INF
		chapter.family.next_meal = INF
		chapter.family.stormfall.scout_due = INF
	return chapter

func _advance(chapter: Chapter, duration: float) -> void:
	for tick in range(roundi(duration / Fire.STEP)):
		chapter.step()

func _mass(model: W) -> int:
	var grams := model.evaporated + model.eaten + model.discarded
	for piece in model.parcels.values():
		grams += piece.grams
	for spear in model.gear.values():
		grams += spear.grams
	return grams

func _stormfall() -> void:
	var chapter := _trial()
	var kin := chapter.family
	var bison := kin.stormfall
	_check(bison.seen_at < 0.0 and not kin.land.places.has(F.MEADOW), "A field event begins without player knowledge")
	_advance(chapter, 57)
	_check(bison.seen_at >= 0.0 and kin.land.places[F.MEADOW].stormfall.source == "Rusk"
		and not kin.workshop.parcels.values().any(func(p): return p.species == "bison"),
		"Rusk relays a witness’s discovery before any carcass reaches home")
	var status := kin.conditions()
	var wet := status.duplicate()
	wet.rain = 1.0
	_check(not bison.council(kin, wet) and bison.party.is_empty(), "A dangerous path makes the elders postpone recovery")
	_advance(chapter, 141)
	_check(bison.recovered > 0 and bison.recovered <= bison.PACK * 2 and bison.left > 0,
		"The first recovery delivers only a two-person carrying load")
	_check(bison.left + bison.lost + bison.recovered + bison.damaged == bison.LANDED + bison.DAMAGED,
		"Reachable, lost, damaged and delivered bison material balance")
	_check(kin.workshop.parcels.values().any(func(p): return p.species == "bison"), "Delivered bison exists as real, identified parcels")
	_check(bison.lost > 0 and bison.quality < 1.0, "Time outside degrades and exposes unrecovered meat to scavengers")
	var work := kin.workshop
	var exposed := work.add("meat", 100, W.FLOOR)
	var covered := work.add("meat", 100, W.STORE)
	var cured := work.add("meat", 100, W.STORE)
	cured.dose = [1.1,1.1]
	cured.cure = 1.0
	work.age_food(360.0)
	_check(exposed.freshness < covered.freshness and covered.freshness < cured.freshness,
		"One story day ages exposed, covered and cooked food differently")
	exposed.freshness = 0.0
	work.pick_up(exposed.id)
	_check(not work.set_down(W.ROAST_POSITIONS[1], W.SPIT, 1), "Spoiled meat cannot be turned into edible food by a craft action")

func _workers() -> void:
	var chapter := _trial(true)
	var kin := chapter.family
	var model := kin.workshop
	var mass := _mass(model)
	var xp := model.techniques.specialists.duplicate()
	_advance(chapter, 108)
	_check(kin.craft.completed.get(W.HUNTER, 0) > 0 and kin.craft.completed.get(W.COOK, 0) > 0
		and kin.craft.completed.get(W.MAKER, 0) > 0 and model.gear.ivo.condition >= 0.86,
		"All three professions produce real work with no active station interface")
	_check(model.techniques.specialists.bera > xp.bera and model.techniques.specialists.nara > xp.nara
		and model.techniques.specialists.ina > xp.ina, "Each specialist gains experience from completed jobs")
	_check(_mass(model) == mass and model.techniques.player.is_empty(), "NPC work conserves mass and awards only specialist experience")
	var cold := _trial(true)
	cold.fire.coals.clear()
	cold.fire._reindex()
	cold.fire.network_dirty = true
	_advance(cold, 58)
	_check(cold.family.craft.heat_needs.has(W.COOK) and cold.family.craft.heat_needs.has(W.MAKER)
		and cold.family.craft.completed.get(W.HUNTER, 0) > 0, "Cold butchery continues while Nara and Ina ask for actual heat")
	_check(cold.fire.coals.is_empty() and cold.family.craft.completed.get(W.COOK, 0) == 0, "Requests never create heat or food")
	cold.fire._new_coal(Vector2(0.22, 0.07), 0.094, 652.0, 0.075)
	cold.fire._new_coal(Vector2(0.18, -0.15), 0.071, 620.0, 0.054)
	_advance(cold, 21)
	_check(not cold.family.craft.heat_needs.has(W.COOK) and cold.family.craft.jobs.get(W.COOK, {}).get("phase") == "warming",
		"Nara recognizes restored hearth heat and begins roasting")
	cold.family.people.nara.away = true
	var done: int = cold.family.craft.completed.get(W.COOK, 0)
	_advance(cold, 48)
	_check(cold.family.craft.jobs.get(W.COOK, {}).is_empty() and cold.family.craft.completed.get(W.COOK, 0) == done,
		"A departing worker puts work aside without creating or claiming a result")

func _apprentice() -> void:
	var chapter := _trial(true)
	var kin := chapter.family
	var model := kin.workshop
	var bench := kin.craft
	var bone := model.add("bone", 180, W.HUNTER)
	var learner_bone := model.add("bone", 180, W.HUNTER)
	var mass := _mass(model)
	_check(bench.request(kin, W.HUNTER, "learn", T.MARROW) and model.techniques.rank(T.MARROW) == 0,
		"Requesting instruction does not instantly unlock a recipe")
	_advance(chapter, 3)
	_check(model.parcels.has(bone.id) and bench.sessions[W.HUNTER].mode == "demonstrating"
		and model.techniques.rank(T.MARROW) == 0, "A real demonstration spends time on its input")
	var restored := Chapter.new(Fire.new())
	_check(Save.restore(restored, Save.capture(chapter)) and restored.family.craft.jobs == bench.jobs
		and restored.family.workshop.reserved == model.reserved, "Save and load retain an active demonstration and its reserved tools")
	_advance(chapter, 17)
	_check(not model.parcels.has(bone.id) and bench.sessions[W.HUNTER].mode == "supervised"
		and model.techniques.learned_from[T.MARROW] == "Bera" and _mass(model) == mass,
		"Completing the demonstration changes the actual bone and teaches from its outcome")
	var focus := Vector3(W.HUNTER_AT.x, 0.1, W.HUNTER_AT.y)
	_check(bench.coaching(kin, W.HUNTER, model.stock("carcass")[0].id, focus, true).contains("long marrow bone")
		and bench.coaching(kin, W.HUNTER, 0, Vector3(0,0,3), true).contains("Come back")
		and bench.coaching(kin, W.HUNTER, 0, focus, false).contains("hearth tool"),
		"Coaching changes with the hovered object, view focus and current tool")
	_check(bench.attempt(kin, learner_bone.id) and model.parcels.has(learner_bone.id),
		"Supervised practice starts physical work and waits for elapsed time")
	_advance(chapter, 38)
	_check(not model.parcels.has(learner_bone.id) and model.techniques.player[T.MARROW] >= 3
		and model.record.has("Kin’s Hearth") == false, "A successful apprentice action earns technique proficiency")
	kin.people.bera.away = true
	_check(bench.coaching(kin, W.HUNTER, 0, focus, true).is_empty(), "The absent Bera cannot supervise")

func _throughput() -> void:
	var alone := _sample("", 0)
	var learning := _sample("supervised", 1)
	var practiced := _sample("help", 5)
	var skilled := _sample("help", 18)
	print("Marrow, same time and stock: alone %d · supervised %d · practiced %d · skilled %d" % [alone, learning, practiced, skilled])
	_check(learning < alone and alone < practiced and practiced < skilled,
		"Real completed work is slowest under supervision and fastest alongside skilled help")

func _sample(mode: String, xp: int) -> int:
	var chapter := _trial(true)
	var kin := chapter.family
	var model := kin.workshop
	model._take(model.stock("carcass")[0], 1080)
	for i in range(28):
		model.add("bone", 150, W.HUNTER)
	kin.craft.starts_at = chapter.fire.time
	model.techniques.player[T.MARROW] = xp
	if not mode.is_empty():
		kin.craft.sessions[W.HUNTER] = {"mode": mode, "technique": T.MARROW, "teacher": "bera"}
	for i in range(60 * 4):
		if not mode.is_empty() and kin.craft.helper.is_empty():
			for bone in model.stock("bone", W.HUNTER):
				if not model.reserved.has(bone.id):
					kin.craft.attempt(kin, bone.id)
					break
		chapter.step()
	return model.stock("spent_bone").size()

func _check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", name)
	else:
		failed += 1
		printerr("FAIL  ", name)
