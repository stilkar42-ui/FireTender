extends SceneTree

const Save := preload("res://sim/chapter_save.gd")
const Chapter := Save.Chapter
const Work := Save.Work
const Fire := Save.Fire
var passed := 0
var failed := 0

func _initialize() -> void:
	_processing()
	_roast_and_reload()
	_haft_and_reload()
	_family_carry()
	print("Physical workshop: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _trial() -> Chapter:
	var chapter := Chapter.new(Fire.new())
	chapter.set_up_family_trial()
	return chapter

func _advance(chapter: Chapter, seconds: float) -> void:
	for tick in range(roundi(seconds / Fire.STEP)):
		chapter.step()

func _mass(work: Work) -> int:
	var grams := work.evaporated + work.eaten + work.discarded
	for parcel in work.parcels.values():
		grams += parcel.grams
	for tool in work.gear.values():
		grams += tool.grams
	return grams

func _carry(work: Work, id: int, rest: String, at: Vector2) -> bool:
	return work.pick_up(id) and work.set_down(at, rest)

func _processing() -> void:
	var chapter := _trial()
	var work := chapter.family.workshop
	var grams := _mass(work)
	var carcass := work.stock("carcass")[0]
	var tool := work.stock("flake", Work.HUNTER)[0]
	_check(work.inspect_object(carcass.id).contains("1080") and work.lessons.has(Work.HUNTER, "look"), "Inspection describes the actual carcass")
	_check(work.pick_up(tool.id) and work.use_held_on(carcass.id) and carcass.grams == 540
		and work.held == tool.id and work.stock("meat", Work.HUNTER)[0].grams == 302,
		"The held flake cuts the carcass in place and leaves the remaining half")
	work.cancel_hand()
	_check(work.work(carcass.id) and not work.parcels.has(carcass.id) and _mass(work) == grams,
		"Further cuts exhaust the carcass and retain its full mass across the products")
	var bone := work.stock("bone", Work.HUNTER)[0]
	var moved := Vector2(-0.2, -1.2)
	_check(_carry(work, bone.id, Work.FLOOR, moved) and bone.at == moved and bone.rest == Work.FLOOR,
		"A bone keeps its identity and ground position when carried away")
	_check(not work.work(bone.id) and _carry(work, bone.id, Work.HUNTER, Work.HUNTER_AT) and work.work(bone.id)
		and work.stock("bone_shard").size() == 1 and work.stock("marrow").size() == 1 and _mass(work) == grams,
		"Cracking on the stone produces a split bone, fragments and marrow")
	var hide := work.stock("hide")[0]
	_check(work.work(hide.id) and hide.kind == "clean_hide" and _carry(work, hide.id, Work.HIDE_RACK, Work.HIDE_AT)
		and work.lessons.has(Work.HUNTER, "hide") and _mass(work) == grams, "The same hide is cleaned, moved and stretched")
	var cut := work.stock("meat", Work.HUNTER)[0]
	_check(_carry(work, cut.id, Work.COOK, Work.COOK_AT) and work.work(cut.id) and cut.grams == 122
		and work.stock("meat", Work.COOK).size() == 2 and _mass(work) == grams,
		"Carrying to Nara and sizing a cut produce finite physical portions")
	var mentor := Save.Mentor.new()
	mentor.begin_chapter(chapter)
	var response := mentor.conversation.reply(chapter.fire, "I cracked the marrow bone", Vector3.ZERO, null, 0.0)
	_check(response.contains("recovered") and response.contains("marrow") and response.contains("Nara’s board"),
		"Eren reflects on the apprentice’s actual processing and carrying")

func _roast_and_reload() -> void:
	var chapter := _trial()
	var work := chapter.family.workshop
	var meat := work.add("meat", 180, Work.COOK)
	work.pick_up(meat.id)
	work.set_down(Work.ROAST_POSITIONS[1], Work.SPIT, 1)
	_advance(chapter, 22)
	work.work(meat.id)
	var before := meat.dose.duplicate()
	var source_time := chapter.fire.time
	chapter.request(2)
	var mentor := Save.Mentor.new()
	mentor.begin_chapter(chapter)
	mentor.story_line("I am keeping the red beside Nara.", "fixture")
	var path := OS.get_environment("TEMP").path_join("firetender-physical-%d.sav" % OS.get_process_id())
	_check(Save.write_slot(path, chapter, mentor) == OK and Save.write_slot(path, chapter, mentor) == OK,
		"The Chapter III slot can be saved and atomically replaced")
	var state := Save.read_slot(path)
	var restored := Chapter.new(Fire.new())
	var restored_mentor := Save.Mentor.new()
	if not Save.restore(restored, state, restored_mentor):
		_check(false, "The Chapter III slot can be decoded and restored")
		return
	var restored_work := restored.family.workshop
	_check(restored.fire.time == source_time and restored.fire.coals[0].temperature == chapter.fire.coals[0].temperature
		and restored.fire.stored[0].faces.size() == chapter.fire.stored[0].faces.size(),
		"Save restores time, living coals and the wood’s internal state")
	_check(restored_work.roast.id == meat.id and restored_work.roast.dose == before and restored_work.roast.face == 1
		and restored_work.lessons.has(Work.COOK, "turn") and restored_mentor.history.has("I am keeping the red beside Nara."),
		"Save restores the same in-progress roast, lesson evidence and dialogue")
	_check(restored.away == chapter.away and restored.returns_at == chapter.returns_at
		and restored.family.known == chapter.family.known and restored.family.rng.state == chapter.family.rng.state,
		"Save restores family knowledge, the ongoing gathering trip and random state")
	_advance(restored, 22)
	_advance(chapter, 22)
	var done := restored_work.roast
	_check(done.condition() == "Roasted" and done.dose.is_same_typed(meat.dose) and absf(done.dose[1] - meat.dose[1]) < 0.01
		and restored.fire.coals[0].temperature == chapter.fire.coals[0].temperature,
		"An in-progress roast keeps cooking from the restored coals")
	_check(_carry(restored_work, done.id, Work.STORE, Work.STORE_AT) and done.rest == Work.STORE
		and restored_work.lessons.has(Work.COOK, "meal"), "The player delivers the roast to the family’s actual food shelf")
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string("incomplete")
	handle.close()
	_check(Save.read_slot(path).is_empty(), "An incomplete save is rejected before touching the live cave")
	DirAccess.remove_absolute(path)

func _haft_and_reload() -> void:
	var chapter := _trial()
	var work := chapter.family.workshop
	var grams := _mass(work)
	_check(work.work(work.stock("knot")[0].id), "The knot is worked with the stone tool at Ina’s bench")
	var resin := work.stock("resin")[0]
	var cup := work.parcels[work.cup_id]
	work.pick_up(resin.id)
	_check(work.set_down(cup.at, Work.MAKER, -1, cup.id) and work.cup_fill == resin.id and work.resin_position < 0,
		"Putting resin in a cold vessel changes its location without warming it")
	work.pick_up(cup.id)
	work.set_down(Work.RESIN_POSITIONS[0], Work.CUP, 0)
	_advance(chapter, 38)
	_check(resin.cure >= 1.0 and work.pick_up(cup.id) and work.held == cup.id and resin.kind == "pitch",
		"Heat softens the original resin and lifting the cup sets the adhesive")
	var restored := Chapter.new(Fire.new())
	if not Save.restore(restored, Save.capture(chapter)):
		_check(false, "A save with a vessel in hand restores")
		return
	work = restored.family.workshop
	_check(work.held == cup.id and work.cup_fill == resin.id and work.resin.kind == "pitch",
		"The same cup and adhesive can be carried after loading")
	work.set_down(Work.MAKER_AT, Work.MAKER)
	_check(work.work(work.stock("point")[0].id) and work.work(work.stock("shaft")[0].id),
		"A point and shaft are prepared as separate physical items")
	var id := work.gear_id("ivo")
	_check(_carry(work, id, Work.MAKER, Work.MAKER_AT) and work.work(id) and work.gear.ivo.condition == 1.0
		and work.stock("point").is_empty() and work.stock("shaft").is_empty() and _mass(work) == grams,
		"Preparing a full haft consumes the physical components and changes Ivo’s actual spear")
	_check(work.inspect_object(id).contains("haft holds") and _carry(work, id, Work.HUNTER, Work.HUNTER_AT)
		and work.lessons.has(Work.MAKER, "rack") and "ivo" in restored.family._usable_hunters(),
		"Inspection and returning the spear to the rack make it usable by the hunters")

func _family_carry() -> void:
	var chapter := _trial()
	var household := chapter.family
	var work := household.workshop
	work.receive_game(960, Chapter.Family.WOODS)
	work.butcher(work.stock("carcass")[0].id, false, 540)
	household._carry_cut("bera", work.stock("meat", Work.HUNTER)[0].id)
	var id: int = household.transfer.id
	var cut := work.parcels[id]
	_check(cut.rest == Work.IN_TRANSIT and not work.pick_up(id) and work.stock("meat", Work.COOK).is_empty(),
		"A hunter carries the real cut between work areas")
	_advance(chapter, 2.0)
	var restored := Chapter.new(Fire.new())
	if not Save.restore(restored, Save.capture(chapter)):
		_check(false, "A save with a family transfer restores")
		return
	_check(restored.family.transfer == household.transfer and restored.family.workshop.parcels[id].at == cut.at,
		"An active family delivery retains its person, route and material")
	_advance(restored, 4.0)
	var landed := restored.family.workshop.parcels[id]
	_check(landed.rest == Work.COOK and restored.family.transfer.is_empty() and
		restored.family.land.places[Work.COOK].work.source == "Nara",
		"The same cut reaches Nara and the Mind Cave records the witnessed arrival")

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		printerr("FAIL  ", label)

