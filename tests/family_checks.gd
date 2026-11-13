extends SceneTree

const Chapter := preload("res://sim/red_hollow.gd")
const Fire := Chapter.Fire
const Family := Chapter.Family
const Work := Family.Workshop
const Roster := Family.Roster

var passed := 0
var failed := 0

func _initialize() -> void:
	_processing_and_roasting()
	_resin_and_gear()
	_council()
	_knowledge_and_reports()
	_territory_and_replay()
	_skill_milestones()
	print("Chapter III model: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _trial(seed_value := Family.DEFAULT_SEED) -> Chapter:
	var chapter := Chapter.new(Fire.new())
	chapter.set_up_family_trial()
	chapter.family.rng.seed = seed_value
	return chapter

func _advance(chapter: Chapter, seconds: float) -> void:
	for tick in range(roundi(seconds / Fire.STEP)):
		chapter.step()

func _mass(model: Work) -> int:
	var grams := model.evaporated + model.eaten + model.discarded
	for parcel in model.parcels.values():
		grams += parcel.grams
	for spear in model.gear.values():
		grams += spear.grams
	return grams

func _put_meat(model: Work) -> Work.Parcel:
	var meat := model.stock("meat", Work.HUNTER)[0]
	model.carry_to_cook(meat.id)
	model.put_on_spit(meat.id)
	return model.roast

func _processing_and_roasting() -> void:
	var chapter := _trial()
	var model := chapter.family.workshop
	var stock_mass := _mass(model)
	var game := model.stock("carcass")[0]
	_check(model.butcher(game.id) and not model.butcher(game.id), "A game portion is processed once")
	_check(_mass(model) == stock_mass and model.stock("meat")[1].grams == 604 and model.stock("bone")[0].grams == 205
		and model.stock("hide")[0].grams == 140 and model.stock("fat")[0].grams == 75 and model.stock("trim")[0].grams == 56,
		"The finite cuts account for every gram of game")
	var bone := model.stock("bone")[0]
	_check(model.crack_bone(bone.id) and model.stock("marrow")[0].grams == 41 and _mass(model) == stock_mass,
		"Cracking a selected bone yields marrow and spent bone")
	var binding := model.stock("hide")[0]
	_check(model.cut_binding(binding.id) and model.stock("binding", Work.MAKER).size() == 2 and _mass(model) == stock_mass,
		"A real strip leaves the hide and reaches the Maker’s Stone")
	var roast := _put_meat(model)
	_check(roast.grams == 180 and roast.rest == "Spit" and model.stock("meat", Work.COOK)[0].grams == 424,
		"The same cut moves to the Cooking Place and a portion moves onto the spit")
	_advance(chapter, 22)
	_check(roast.condition() == "Undercooked" and roast.dose[0] > 1.0 and roast.dose[1] == 0.0,
		"Actual coal-edge heat cooks the exposed face")
	model.turn_spit()
	_advance(chapter, 21)
	_check(roast.condition() == "Roasted" and roast.core > 65.0, "Turning allows both faces and the core to cook")
	model.lift_spit()
	_check(roast.rest == Work.STORE and model.food_on_shelf() == 668 and _mass(model) == stock_mass,
		"Prepared food enters the shared shelf and cooking moisture is accounted for")
	_check(model.record["Kin’s Hearth"].size() == 1, "A successful roast records one practical technique")
	var raw := model.stock("meat", Work.COOK)[0]
	model.put_on_spit(raw.id)
	model.move_spit(2)
	_advance(chapter, 20)
	_check(model.roast.condition() == "Raw", "Time on the resting stone cannot stand in for heat")

	var hot := _trial()
	var hot_work := hot.family.workshop
	hot_work.butcher(hot_work.stock("carcass")[0].id)
	_put_meat(hot_work)
	_advance(hot, 21)
	hot_work.turn_spit()
	hot_work.move_spit(0)
	_advance(hot, 22)
	_check(hot_work.roast.condition() == "Charred" and hot.fire.smoke_field.emitted > 0.0,
		"Leaving a portion over intense heat chars it and releases smoke")
	var cold := _trial()
	var cold_work := cold.family.workshop
	cold_work.butcher(cold_work.stock("carcass")[0].id)
	_put_meat(cold_work)
	cold.fire.coals.clear()
	cold.fire._reindex()
	_advance(cold, 55)
	_check(cold_work.roast.condition() == "Raw" and cold.fire.coals.is_empty(), "A cold hearth stays cold and the raw cut stays raw")

	var dry := _trial()
	var dry_work := dry.family.workshop
	dry_work.butcher(dry_work.stock("carcass")[0].id)
	_put_meat(dry_work)
	dry_work.turn_spit()
	_advance(dry, 22)
	dry_work.turn_spit()
	var extra := dry.fire._new_coal(Vector2(-0.30, 0.0), 0.014, 655.0, 0.009)
	dry.fire._reindex()
	_advance(dry, 40)
	_check(dry_work.roast.condition() == "Overcooked" and dry_work.roast.charred < 1.0 and extra != null,
		"Prolonged moderate exposure can dry a portion before it chars")

func _resin_and_gear() -> void:
	var chapter := _trial()
	chapter.family.craft.starts_at = INF
	var model := chapter.family.workshop
	var stock_mass := _mass(model)
	var knot := model.stock("knot")[0]
	_check(model.scrape_knot(knot.id) and not model.scrape_knot(knot.id) and _mass(model) == stock_mass,
		"Resin is scraped from a finite knot with recoverable scrap")
	model.set_resin(model.stock("resin")[0].id)
	_advance(chapter, 39)
	_check(model.resin.cure >= 1.0 and model.resin.scorched == 0.0, "A cup over controlled live heat renders usable resin")
	model.lift_resin()
	_check(model.stock("pitch")[0].grams == 20 and _mass(model) == stock_mass, "Rendered adhesive returns to the Maker’s Stone")
	_check(model.haft("ivo", false) and model.gear.ivo.condition == 0.86 and not model.haft("ivo", false)
		and model.stock("binding").is_empty() and _mass(model) == stock_mass,
		"Repair consumes adhesive and binding, restores the haft and accounts for the scraps")
	model.cut_binding(_make_hide(model).id)
	var with_hide := _mass(model)
	model.gear.kett.condition = 0.12
	_check(not model.haft("kett", false) and model.haft("kett", true) and model.gear.kett.condition == 1.0
		and model.stock("shaft").is_empty() and model.stock("point").is_empty() and _mass(model) == with_hide,
		"A broken haft requires and consumes an actual new shaft and point")
	_check(model.record["Hearth Maker"].size() == 2, "Distinct maker techniques are recorded once each")
	var hot := _trial()
	var hot_work := hot.family.workshop
	hot_work.scrape_knot(hot_work.stock("knot")[0].id)
	hot_work.set_resin(hot_work.stock("resin")[0].id)
	hot_work.move_resin(1)
	_advance(hot, 20)
	_check(hot_work.resin.scorched >= 1.0 and hot.family.latest.by == "ina" and hot.fire.smoke_field.emitted > 0.0,
		"Overheated resin smokes through the cave and a nearby witness warns the player")
	hot_work.lift_resin()
	_check(hot_work.stock("pitch").is_empty() and hot_work.stock("ruined_pitch").size() == 1,
		"Scorched resin cannot repair gear")

func _make_hide(model: Work) -> Work.Parcel:
	model.butcher(model.stock("carcass")[0].id)
	return model.stock("hide")[0]

func _council() -> void:
	var chapter := _trial()
	var family := chapter.family
	var state := family.conditions()
	state.merge({"food": 1300, "hunger": 0.0, "light": 0.95, "rain": 0.0, "wind": 0.10, "ready": 3}, true)
	var fed := Family.deliberate(state)
	_check(fed.choice == 0 and fed.votes.size() == 3 and not fed.votes.has(Roster.SPEAKER), "Three elders weigh a well-fed household")
	state.merge({"food": 0, "hunger": 0.78, "large": 0.83, "small": 0.66}, true)
	_check(Family.deliberate(state).choice == 2, "Hunger and strong sign can justify a larger hunt")
	state.merge({"ready": 1, "large": 0.10}, true)
	_check(Family.deliberate(state).choice == 1, "One fit hunter takes the shorter, smaller chance")
	state.merge({"light": 0.2, "rain": 0.72, "hurt": 0.5, "injury": 0.8}, true)
	_check(Family.deliberate(state).choice == 0, "Bad travel and injury can keep the same hungry family close")
	var original := family.conditions()
	family.workshop.add("roots", 680, Work.STORE)
	family.workshop.gear.ivo.condition = 0.92
	var changed := family.conditions()
	_check(changed.food > original.food and changed.gear > original.gear, "Prepared food and repaired equipment reach the elders’ inputs")
	_check(chapter.request(2) and family.decision.is_empty() and family.hunt.is_empty(),
		"The player can request wood without commanding the elders or the hunters")
	_advance(chapter, 44)
	_check(not family.decision.is_empty(), "Council convenes on the family’s own schedule")

func _knowledge_and_reports() -> void:
	var chapter := _trial()
	var family := chapter.family
	_check(Roster.PEOPLE.size() == 15 and Roster.DESCENT.sela.has(Roster.SPEAKER) and Roster.DESCENT.sela.has("nara")
		and Roster.DESCENT.tavi.has(Roster.SCOUT) and Roster.DESCENT.nara.has(Roster.APPRENTICE), "Established kinship is represented by actual parent links")
	_check(family.latest.by == Roster.SCOUT and family.latest.heard == chapter.fire.time, "Rusk’s opening news has a witness and timestamp")
	chapter.request(2)
	_advance(chapter, 44)
	_check(chapter.away == 2 and not family.waiting_news.is_empty() and family.latest.by == Roster.SCOUT
		and family.latest.heard < chapter.fire.time, "While Rusk is away, council news waits for him")
	if family.hunt.is_empty():
		family._depart_hunt(1)
	var hunter: String = family.hunt.party[0]
	var last_seen: Dictionary = family.known[hunter].duplicate()
	_advance(chapter, 41)
	_check(family.known[hunter] == last_seen and family.people[hunter].place != last_seen.place,
		"A field encounter and movement stay out of the apprentice’s knowledge")
	_check(family.news.any(func(entry): return entry.by == Roster.SCOUT and entry.heard > entry.happened)
		and family.waiting_news.is_empty(), "Rusk learns local news upon return and dates its delayed delivery")
	_advance(chapter, 43)
	_check(family.known[hunter].learned > last_seen.learned and not family.known[hunter].away,
		"A hunter’s return replaces the old sighting")

	var lookout := _trial()
	var village := lookout.family
	village._depart_hunt(2)
	var deer_hunter: String = village.hunt.party[0]
	var departure: Dictionary = village.known[deer_hunter].duplicate()
	var encounter: float = village.hunt.encounter
	var returns: float = village.hunt.home
	_advance(lookout, 28)
	_check(lookout.request(3), "Rusk can still take the original sky-watch route")
	_advance(lookout, ceilf(encounter - lookout.fire.time) + 1.0)
	_check(not village.scout_sighting.is_empty() and village.known[deer_hunter] == departure,
		"The scout can observe the party without updating the player’s knowledge from the field")
	_advance(lookout, 17)
	var sighting: Dictionary = village.known[deer_hunter]
	_check(sighting.source == "Reported by Rusk" and sighting.place == Family.TRAIL
		and sighting.learned > sighting.seen and sighting.seen > departure.seen,
		"A credible report dates both the observation and when the player learned it")
	_advance(lookout, ceilf(returns - lookout.fire.time) + 1.0)
	_check(village.known[deer_hunter].place == Family.HOME, "The later return supersedes the field report")

func _skill_milestones() -> void:
	var chapter := _trial()
	var workshop := chapter.family.workshop
	for coal in chapter.fire.coals:
		coal.cover = 0.01
	_advance(chapter, 46)
	_check(workshop.record.has("Deep Red") and workshop.record["Deep Red"].size() == 1,
		"Sustained living coals under ash teach a single banking technique")
	var other := _trial()
	_advance(other, 8)
	var fine := other.fire.stock_piece(4)
	other.fire.pose_fuel(fine, Vector2(0.09, -0.10), 0.0, 0.0, 0, true)
	for tick in range(96):
		other.step()
		if other.family.workshop.record.has("Quick Hand"):
			break
	_check(other.family.workshop.record.has("Quick Hand"), "A real recovery with fine fuel teaches Quick Hand")

func _territory_and_replay() -> void:
	var start := Time.get_ticks_msec()
	var a := _trial(731)
	var b := _trial(731)
	_advance(a, 335)
	_advance(b, 335)
	_check(a.family.news == b.family.news and a.family.known == b.family.known and a.family.sites == b.family.sites,
		"The same seed and hearth steps repeat the family timeline")
	_check(a.family.sites.size() == 8 and a.family.sites[Family.STREAM].roots < 4
		and a.family.workshop.eaten > 0 and a.family.news.size() <= Family.EVENT_LIMIT,
		"Local errands draw down finite stores and meals use the shared food shelf")
	var results := {}
	var damaged := false
	var hurt := false
	for seed_value in range(24):
		var chapter := _trial(seed_value)
		var family := chapter.family
		var which := 1 if seed_value % 2 == 0 else 2
		family._depart_hunt(which)
		var site: Dictionary = family.sites[family.hunt.place]
		var key: String = family.hunt.kind
		var before: int = site[key]
		var hunter: String = family.hunt.party[0]
		var gear: float = family.workshop.gear[hunter].condition
		family._resolve_hunt()
		results[family.hunt.result] = true
		damaged = damaged or family.workshop.gear[hunter].condition < gear
		hurt = hurt or not family.hunt.injured.is_empty()
		if family.hunt.yield > 0:
			var grams: int = family.hunt.yield
			_check(site[key] == before - 1 and family.workshop.stock("carcass").size() == 1,
				"Game is finite and cuts stay with the party until return")
			family._return_hunt()
			_check(family.workshop.stock("carcass").back().grams == grams,
				"A returned catch becomes the same finite haul on the working stone")
	_check(results.size() == 4 and damaged and hurt, "Seeded field outcomes cover empty paths, missed game, hare, deer, damage and injury")
	var empty := _trial()
	var family := empty.family
	family.sites[Family.WOODS].small = 0
	family._depart_hunt(1)
	family._resolve_hunt()
	_check(family.hunt.yield == 0 and family.sites[Family.WOODS].small == 0, "An exhausted site cannot yield another catch")
	print("Two live replays and 24 field fixtures ran in %d ms offline." % (Time.get_ticks_msec() - start))

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		printerr("FAIL  ", label)
