extends SceneTree

const Chapter := preload("res://sim/red_hollow.gd")
const Sites := Chapter.Gathering
const Save := preload("res://sim/chapter_save.gd")
const Land := Chapter.Family.Land

var passed := 0
var failed := 0

func _initialize() -> void:
	_event()
	_travel_and_saves()
	_tutorial_supplies()
	print("Persistent gathering sites: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _event() -> void:
	var story := Chapter.new(Chapter.Fire.new())
	var sites := story.gathering
	# Spend the pine across ordinary finite loads before the storm.
	while not sites.plan(1, 0, false).is_empty():
		sites.take(1, sites.plan(1, 0, false), 100.0, 0.0, 10.0)
	sites.take(2, sites.plan(2, 0, false), 100.0, 0.0, 10.0)
	var prior := sites.records.duplicate(true)
	var event := Sites.authored_storm()
	sites.apply_storm(Sites.OPENING_STORM, event, Chapter.Shelter.END)
	var pine: Dictionary = sites.records[1]
	_check(pine.pieces.size() > prior[1].pieces.size()
		and pine.pieces.filter(func(piece): return piece.source.is_empty()).all(func(piece): return piece.state == "collected"),
		"The spent pine receives only newly fallen, finite deadwood")
	var ridge: Dictionary = sites.records[2]
	var original: Dictionary = ridge.pieces.filter(func(piece): return piece.source.is_empty() and piece.state == "available")[0]
	_check(original.moisture > original.initial_moisture and original.id < prior[2].pieces.size()
		and original.history.size() == 1 and original.exposure > 0.0,
		"An uncollected oak split keeps its identity and gains moisture history")
	_check(sites.counts(0, true)[0] > 0 and sites.counts(5, true)[3] > 0,
		"The overhang protects fuel while the willow hollow waterlogs deadwood")
	_check(sites.records[5].delay_until > Chapter.Shelter.END and sites.records[0].delay_until == 0.0,
		"Runoff slows the hollow path while the bark ledge stays accessible")
	_check(sites.records.all(func(site): return site.pieces.all(func(piece): return piece.wood == "deadwood")),
		"Storm debris introduces no green fuel")
	var green: Dictionary = pine.pieces.back().duplicate()
	green.id = pine.pieces.size()
	green.wood = "green"
	pine.pieces.append(green)
	_check(green.id not in sites.plan(1, 5, true), "Fresh material is outside the gathering pool")
	pine.pieces.pop_back()
	var saved := sites.records.duplicate(true)
	_check(not sites.apply_storm(Sites.OPENING_STORM, event, 1400.0) and sites.records == saved,
		"An applied event key cannot deposit or soak material again")
	var clear := Sites.new()
	clear.initialize(Chapter.ROUTES)
	var before := clear.records.duplicate(true)
	clear.apply_storm("clear", {"rain": 0.0, "duration": 0.0, "gust": 0.2, "wind": Vector2.ZERO, "temperature": 11.0}, 600.0)
	_check(clear.records == before, "A calm dry interval creates no stormfall or wet stock")
	var replay := Sites.new()
	var variable := Sites.new()
	replay.records = prior.duplicate(true)
	variable.records = prior.duplicate(true)
	replay.apply_storm(Sites.OPENING_STORM, event, Chapter.Shelter.END)
	variable.apply_storm(Sites.OPENING_STORM, {"rain": 85.0, "duration": 120.0, "gust": 0.59,
		"wind": -event.wind, "temperature": 8.0}, Chapter.Shelter.END)
	_check(replay.records == saved and variable.records != saved, "Matching events replay and different storm inputs change the result")
	_comparison(prior, sites)

func _travel_and_saves() -> void:
	var story := Chapter.new(Chapter.Fire.new())
	story.set_up_after_storm_trial()
	var route := 4
	_check(story.route_description(route).contains("haven’t checked") and not story.land.places.has(Land.WOODS),
		"Weathering the birch changes actual inventory before the player knows")
	_check(story.request(route, 6) and story.carried_load.is_empty(), "Rusk can survey a site without collecting")
	_step(story, story.pickup_at + 0.25)
	_check(story.picked_up and not story.land.places.has(Land.WOODS) and not story.trip_observation.is_empty(),
		"Rusk’s observations stay private on the return leg")
	var restored := Chapter.new(Chapter.Fire.new())
	_check(Save.restore(restored, Save.capture(story)) and restored.gathering.records == story.gathering.records
		and restored.gathering.events == story.gathering.events and restored.trip_observation == story.trip_observation,
		"Saving on the return leg preserves the event, field stock and private report")
	_step(restored, restored.returns_at + 0.25)
	var note: Dictionary = restored.land.places[Land.WOODS].fuel
	_check(note.source == "Rusk" and note.seen < note.learned and restored.route_description(route).contains("damp"),
		"The return publishes the observed conditions with both dates")
	var talk := preload("res://sim/speaker_conversation.gd").new()
	talk.chapter = restored
	_check(talk.reply(restored.fire, "Where can Rusk find wet wood?", Vector3.ZERO, null, 0.0).contains("standing dead birch")
		and talk.reply(restored.fire, "Which branches should I dry first?", Vector3.ZERO, null, 0.0).contains("damp deadwood"),
		"The Fire Speaker uses reported locations and recommends the least saturated logs")
	var count := restored.remaining(route)
	_check(restored.request(route, 5), "Observed damp or wet logs supply the drying route")
	_step(restored, restored.pickup_at + 0.25)
	var first_id: int = restored.carried_load[0]
	var entry: Dictionary = restored.gathering.records[route].pieces[first_id].duplicate(true)
	var in_transit := Chapter.new(Chapter.Fire.new())
	_check(Save.restore(in_transit, Save.capture(restored)) and in_transit.picked_up, "Collected wet wood saves in transit")
	_step(in_transit, in_transit.returns_at)
	var id: int = in_transit.gathering.records[route].pieces[first_id].fuel_id
	var delivered := in_transit.fire.all_fuel().filter(func(piece): return piece.id == id)
	_check(delivered.size() == 1 and is_equal_approx(delivered[0].water / delivered[0].original, entry.moisture)
		and is_equal_approx(delivered[0].temperature, entry.temperature) and in_transit.remaining(route) != count,
		"The same load reaches the fire once with its field moisture and temperature")
	var carried_mass := 0.0
	for piece: Dictionary in in_transit.gathering.records[route].pieces:
		if piece.taken_at == entry.taken_at:
			carried_mass += Sites.dry_mass(piece.kind) * (1.0 + float(piece.moisture))
	_check(carried_mass <= Sites.LIMIT, "Water in the load counts toward the carrying limit")
	in_transit.outcome = "prepared"
	_check(in_transit.begin_family() and in_transit.family.land == in_transit.land
		and in_transit.land.places[Land.WOODS].has("fuel"), "Chapter III inherits the depleted sites and the reports already learned")
	var campaign := Chapter.new(Chapter.Fire.new())
	campaign.fire.time = Chapter.Shelter.END - 9.0
	campaign.weather.sample(campaign.fire.time)
	_check(campaign.request(1), "Rusk can be on an outbound trip at the transition")
	var planned := campaign.carried_load.duplicate()
	var due := campaign.returns_at
	campaign.fire.time = Chapter.Shelter.END
	campaign.outcome = "kept"
	_check(campaign.begin_after_storm() and campaign.carried_load == planned and campaign.returns_at == due,
		"The storm leaves an outbound route and its planned IDs intact")
	var returning := Chapter.new(Chapter.Fire.new())
	returning.fire.time = Chapter.Shelter.END - 19.0
	returning.weather.sample(returning.fire.time)
	if not returning.request(1):
		_check(false, "Rusk can collect a load shortly before the chapter boundary")
		return
	returning.fire.time = returning.pickup_at
	returning._pick_up()
	var load_id: int = returning.carried_load[0]
	var before: Dictionary = returning.gathering.records[1].pieces[load_id].duplicate(true)
	returning.fire.time = Chapter.Shelter.END
	returning.outcome = "kept"
	_check(returning.begin_after_storm() and returning.picked_up and returning.gathering.records[1].pieces[load_id] == before,
		"Wood already picked up before the transition retains its moisture and collection record")
	_legacy_save()

func _legacy_save() -> void:
	var fixture := Chapter.new(Chapter.Fire.new())
	fixture.set_up_after_storm_trial()
	var old := Save.capture(fixture)
	old.version = 3
	old.erase("gathering")
	old.erase("field_land")
	old.chapter.sites = Chapter.ROUTES.map(func(route): return route.loads.duplicate(true))
	old.chapter.sites[1][0].clear()
	old.chapter.away = 1
	old.chapter.carried_load = [Vector2i(1, 1), Vector2i(1, 1)]
	old.chapter.returns_at = fixture.fire.time + 20.0
	var migrated := Chapter.new(Chapter.Fire.new())
	var ok := Save.restore(migrated, old)
	_check(ok and migrated.carried_load.size() == 2 and migrated.fire.all_fuel().size() == fixture.fire.all_fuel().size()
		and migrated.gathering.events.has(Sites.OPENING_STORM)
		and migrated.gathering.records[1].pieces[0].state == "collected",
		"Version 3 maps the old inventory and trip without repeating shelter stormfall")

func _tutorial_supplies() -> void:
	var story := Chapter.new(Chapter.Fire.new())
	for route in [0, 1, 2, 4, 5]:
		while not story.gathering.plan(route, 0, false).is_empty():
			story.gathering.take(route, story.gathering.plan(route, 0, false), 0.0, 0.0, 10.0)
	story.fire.stored.clear()
	story.fire.time = Chapter.Shelter.END
	story.outcome = "kept"
	story.begin_after_storm()
	var counts := [0, 0, 0, 0]
	var tinder := 0
	for piece in story.fire.stored:
		if piece.water / piece.original >= 0.34:
			counts[Chapter.Quests.size_group(piece.kind)] += 1
		if piece.kind in Chapter.Fire.RAW_TINDER and piece.water < piece.original * 0.23:
			tinder += 1
	_check(counts[2] >= 2 and counts[3] >= 2 and tinder >= 4 and not story.gathering.plan(2, 5, true).is_empty(),
		"Heavy Chapter I depletion still leaves tinder, both tutorial pairs and finite oak to gather")

func _comparison(prior: Array, sites: Sites) -> void:
	print("| Site | Original | Collected before rain | Surviving originals | Storm-added | Protected / damp / wet / waterlogged | Player knowledge |")
	print("| --- | ---: | ---: | ---: | ---: | --- | --- |")
	for route in [0, 1, 2, 3, 4, 5]:
		var original: Array = prior[route].pieces
		var removed := original.filter(func(piece): return piece.state == "collected").size()
		var condition := sites.counts(route, true)
		print("| %s | %d | %d | %d | %d | %d / %d / %d / %d | Awaiting a post-storm report |" %
			[prior[route].place, original.size(), removed, original.size() - removed, sites.records[route].pieces.size() - original.size(),
				condition[0], condition[1], condition[2], condition[3]])

func _step(story: Chapter, target: float) -> void:
	while story.fire.time < target and story.outcome.is_empty():
		story.step()

func _check(ok: bool, words: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", words)
	else:
		failed += 1
		printerr("FAIL  ", words)
