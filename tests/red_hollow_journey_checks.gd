extends SceneTree
## Play through the three chapters on one live workbench. All fuel comes from the
## opening parcel, completed gathering trips, or the live stormfall.

const Fire := preload("res://sim/fire.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Lab := preload("res://hearth/hearth.tscn")
const Opening := preload("res://tests/red_hollow_checks.gd")
const ALCOVE := Vector2(-1.97, -2.30)
const SHELF := Vector2(-1.92, -3.22)
const EDGE := Vector2(-0.97, 0.01)
var lab: Control
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-journey-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	await _tend_opening()
	if lab.chapter.outcome == "kept":
		await _continue_journey()
	print("Red Hollow journey: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _tend_opening() -> void:
	var story: Chapter = lab.chapter
	var fire: Fire = lab.fire
	var rescued := fire.coals[0]
	var tinder := fire.stock_piece(5)
	var supplies := fire.pose_fuel(tinder, ALCOVE, 0.0, 0.0, 0, true)
	_check(supplies and story.sequel == null and fire.time == 0.0 and fire.coals.size() == 1,
		"Chapter I opens on the rescued ember and one parcel of tinder is saved in the alcove")
	await _capture("chapter-i-opening")
	supplies = story.request(1) and supplies
	for i in range(5):
		var angle := TAU * i / 5.0
		supplies = fire.add_fuel(4, Vector2.from_angle(angle) * 0.043, angle + PI * 0.5, 0.0, 0, true) != null and supplies
	supplies = fire.lift_coal(rescued) and fire.deposit_coal(rescued, Vector2.ZERO) and supplies
	while fire.time < Chapter.Shelter.END and story.outcome.is_empty():
		if fire.time in [0.25, 2.75]:
			fire.send_breath(Vector2(0.0, 0.45), Vector2.ZERO, 0.84, 1.2)
		if fire.time in [29.0, 110.0]:
			supplies = story.request(2) and supplies
		if fire.time == 255.0:
			supplies = story.request(1) and supplies
		if fire.time == floorf(fire.time) and Opening.FUEL_SCHEDULE.has(int(fire.time)):
			if fire.time == 751.0:
				fire.uncover()
			var load: Array = Opening.FUEL_SCHEDULE[int(fire.time)]
			supplies = fire.add_fuel(load[0], load[1], load[2], 0.0, 0, true) != null and supplies
		if fire.time in [304.0, 455.0, 530.0]:
			for coal in fire.coals.duplicate():
				fire.sweep_ash(coal.at, Vector2(0.65, 0.10))
			if fire.time >= 455.0:
				fire.rake_at(Vector2.ZERO, Vector2.ZERO, 2.0)
				supplies = fire.bank() and supplies
		lab._step_budgeted(1)
		if fposmod(fire.time, 90.0) == 0.0:
			await process_frame
	_check(supplies and story.outcome == "kept" and story.preserved and fire.time == Chapter.Shelter.END,
		"Ordinary gathering, fuel placement, and banking keep Chapter I alive through Day Three")
	_check(story.reserve_ready(), "The gathered wood meets the dry reserve before the storm · %s" % [story.storm_reserve])
	print("Chapter I · %.2f s · %.0f g charcoal · hottest %.0f C" %
		[fire.time, fire.coal_reserve() * 1000.0, _hottest(fire).temperature])
	await _capture("chapter-i-kept")

func _continue_journey() -> void:
	var story: Chapter = lab.chapter
	var fire: Fire = lab.fire
	var bed := fire.coals.duplicate()
	var fuel := fire.all_fuel()
	var stores := story.gathering.records.duplicate(true)
	lab._update_chapter()
	_check(lab.story_menu.mode == "results" and lab.story_menu.supply_rows[0].text.contains("Living charcoal"),
		"Chapter I automatically opens the results and supply inventory")
	await _capture("chapter-i-results")
	lab.story_menu.results_continue.pressed.emit()
	var sequel := story.sequel
	_check(sequel != null and fire.coals == bed and Opening._collected_unchanged(story, stores) and
		fuel.all(func(piece): return fire.has_fuel(piece)) and fire.time == Chapter.Shelter.END,
		"The regular Continue button carries the bed, fuel, gathering sites, and clock into Chapter II")
	if sequel == null:
		return
	lab.story_menu.chapter_button.pressed.emit()
	lab.quest_button.pressed.emit()
	_check(lab.quest_panel.visible and lab.quest_rows[3].text.contains("large log beside the fire"),
		"The quest journal lists both drying methods and sizes at the Chapter II start")
	await _capture("chapter-ii-quests")
	lab.quest_locations[0].pressed.emit()
	_check(not lab.quest_panel.visible and lab.view.workbench.focus_target.z < -3.0,
		"The quest journal can focus the camera on the actual dry shelf")
	var stormfall := fire.stock_piece(12, true)
	var original_water := stormfall.water
	var air_branch := fire.stock_piece(8, true)
	var air_oak := fire.stock_piece(2, true)
	var placed := fire.pose_fuel(air_branch, SHELF + Vector2(-0.29, 0.0), PI * 0.5, 0.0, 0, true)
	placed = fire.pose_fuel(air_oak, SHELF + Vector2(0.27, 0.0), PI * 0.5, 0.0, 0, true) and placed
	var warm_oak := fire.stock_piece(2, true)
	_check(warm_oak != air_oak, "The Wet wood tray chooses a second oak split once the first is on the shelf")
	fire.uncover()
	fire.rake_at(Vector2.ZERO, Vector2(-0.53, 0.02), 2.0)
	var source := _hottest(fire).at
	print("  Exposed glow at %s, %d coal patches" % [source, fire.coals.size()])
	var started := fire.time
	var remaining := fire.stored.filter(func(piece: Fire.Piece): return piece.kind == 5 and not Chapter.Shelter.protected_storage(piece.at))
	for i in range(mini(3, remaining.size())):
		var angle := TAU * i / 3.0
		placed = fire.pose_fuel(remaining[i], source + Vector2.from_angle(angle) * 0.030, angle, 0.0, 0, true) and placed
	var stashed := false
	var max_vapor := 0.0
	var supply_plan := {2: 1, 7: 6, 13: 7, 22: 1, 29: 7, 37: 8, 49: 8, 63: 2, 85: 8, 107: 2, 119: 1,
		125: 8, 148: 2, 165: 8}
	var heat_finished := false
	while fire.time < started + 1800.0 and story.outcome.is_empty():
		var elapsed := fire.time - started
		if elapsed in [0.25, 2.75]:
			fire.send_breath(source + Vector2(0.0, 0.45), source, 0.84, 1.2)
		if elapsed == floorf(elapsed) and supply_plan.has(int(elapsed)):
			_feed_dry(fire, supply_plan[int(elapsed)], source + Vector2(0.015, 0.05 * sin(elapsed)))
		if elapsed == 58.0:
			placed = fire.pose_fuel(stormfall, EDGE + Vector2(0.02, -0.22), PI * 0.5, 0.0, 0, true) and placed
		if elapsed == 70.0:
			placed = fire.pose_fuel(warm_oak, EDGE + Vector2(0.01, 0.30), PI * 0.5, 0.0, 0, true) and placed
		if not stashed and sequel.drying_complete.has("heat_medium"):
			stashed = fire.pose_fuel(stormfall, SHELF + Vector2(0.0, 0.29), 0.0, 0.0, 0, true)
		if not heat_finished and sequel.drying_complete.has("heat_large"):
			heat_finished = fire.pose_fuel(warm_oak, SHELF + Vector2(0.03, -0.28), 0.0, 0.0, 0, true)
		if elapsed >= 175.0 and fposmod(elapsed - 175.0, 35.0) == 0.0 and not (stashed and heat_finished):
			if fire.total_flame() < 4.0:
				fire.send_breath(source + Vector2(0.42, 0.0), source, 0.84, 1.2)
			for kind in [2, 9, 10, 12, 8, 7, 1]:
				if _feed_dry(fire, kind, source + Vector2(0.04, 0.08 * sin(elapsed))):
					break
		if elapsed == 30.0:
			story.request(4)
		if elapsed == 120.0 and story.remaining(1)[1] > 0:
			story.request(1, 2)
		if elapsed in [520.0, 880.0]:
			fire.uncover()
			fire.rake_at(Vector2.ZERO, Vector2(-0.46, 0.0), 2.0)
			source = _hottest(fire).at if not fire.coals.is_empty() else source
			for index in range(3):
				var angle := TAU * index / 3.0
				if not _feed_dry(fire, 4, source + Vector2.from_angle(angle) * 0.034):
					_feed_dry(fire, 5, source + Vector2.from_angle(angle) * 0.034)
		if elapsed in [520.25, 522.75, 880.25, 882.75]:
			fire.send_breath(source + Vector2(0.0, 0.45), source, 0.84, 1.2)
		var relight := elapsed - (880.0 if elapsed >= 880.0 else 520.0)
		var reheating := {3: 1, 8: 7, 15: 1, 24: 8, 38: 8, 56: 2, 85: 2, 117: 9, 150: 10}
		if relight == floorf(relight) and reheating.has(int(relight)):
			_feed_dry(fire, reheating[int(relight)], source + Vector2(0.04, 0.05 * sin(elapsed)))
		if not (elapsed >= 520.0 and relight < 180.0) and fposmod(elapsed, 30.0) == 0.0 and stashed and heat_finished and fire.total_flame() < 3.0:
			for coal in fire.coals.duplicate():
				fire.sweep_ash(coal.at, Vector2(0.65, 0.10))
			fire.rake_at(Vector2.ZERO, Vector2.ZERO, 2.0)
			fire.bank()
		lab._step_budgeted(1)
		max_vapor = maxf(max_vapor, stormfall.vapor)
		if fposmod(elapsed, 100.0) == 0.0:
			print("  +%.1f s · air oak %.0f%% · warm oak %.0f%% at %.0f C · birch %.0f%% at %.0f C · %.1f g hot coals · %.1f kW · %s" %
				[elapsed, air_oak.water / air_oak.original * 100.0, warm_oak.water / warm_oak.original * 100.0,
					warm_oak.temperature, stormfall.water / stormfall.original * 100.0, stormfall.temperature, sequel.hot_coals * 1000.0,
					fire.total_flame(), sequel.drying_complete])
			await process_frame
	_check(placed and stashed and max_vapor > 0.00002 and fire.has_fuel(stormfall),
		"Live stormfall dries beside the inherited fire and the same piece is moved to the dry shelf")
	_check(story.outcome == "prepared" and sequel.drying_complete.size() == 4 and sequel.hot_coals >= 0.009 and not sequel.hazard,
		"Chapter II ends with four distinct drying goals, living coals and no live hazard")
	_check(sequel.drying_complete.values().all(func(id): return sequel.drying_complete.values().count(id) == 1),
		"Each drying goal uses a separate log")
	_check(fire.time - started >= 1200.0 and fire.time - started <= 1800.0,
		"The full player route completes Chapter II within 20 to 30 minutes at normal speed")
	print("Chapter II · +%.2f s · stormfall %.1f to %.1f g water · ready reserve %.1f g · seasoned %.1f g · hot coals %.1f g · %s" %
		[fire.time - started, original_water * 1000.0, stormfall.water * 1000.0, sequel.ready_reserve * 1000.0,
			sequel.seasoned_reserve * 1000.0, sequel.hot_coals * 1000.0, story.outcome])
	await _capture("chapter-ii-prepared" if story.outcome == "prepared" else "chapter-ii-attempt")
	if story.outcome != "prepared":
		return
	bed = fire.coals.duplicate()
	fuel = fire.all_fuel()
	stores = story.gathering.records.duplicate(true)
	var crossing := fire.time
	lab._update_chapter()
	_check(lab.story_menu.mode == "results" and lab.story_menu.supply_rows[5].text.contains("Seasoned wood"),
		"Chapter II automatically shows the drying result and seasoned reserve")
	await _capture("chapter-ii-results")
	lab.story_menu.results_continue.pressed.emit()
	_check(story.family != null and fire.coals == bed and story.gathering.records == stores
		and fire.time == crossing and fuel.all(func(piece): return fire.has_fuel(piece)),
		"The regular Chapter III handoff keeps the same hearth, stores and clock")
	if story.family == null:
		return
	_check(lab.story_menu.mode == "chapter" and lab.story_menu.chapter_heading.text.contains("CHAPTER III"),
		"Continuing from the results opens the Chapter III loading page")
	lab.story_menu.chapter_button.pressed.emit()
	for tick in range(60 * 4):
		lab._step_budgeted(1)
		if tick % 40 == 0:
			await process_frame
	_check(story.family.stormfall.seen_at > crossing and story.family.craft.completed.get(Chapter.Family.Workshop.HUNTER, 0) > 0,
		"The bison report and autonomous work begin on the inherited Chapter III clock")

func _feed_dry(fire: Fire, kind: int, at: Vector2) -> bool:
	for piece in fire.all_fuel():
		if piece.kind == kind and fire._in_stock(piece) and not Chapter.Shelter.DRY_SHELF.has_point(piece.at) \
			and piece.water < piece.original * 0.26 and piece.wood > piece.original * 0.90:
			return fire.pose_fuel(piece, at, 0.3, 0.0, 0, true)
	return false

func _hottest(fire: Fire) -> Fire.Piece:
	var hottest := fire.coals[0]
	for coal in fire.coals:
		if coal.temperature > hottest.temperature:
			hottest = coal
	return hottest

func _capture(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(args[0].path_join(name + ".png")) == OK, "Captured " + name)

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
