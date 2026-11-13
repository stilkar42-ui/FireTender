extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const Chapter := preload("res://sim/red_hollow.gd")
const Family := Chapter.Family
const Work := Family.Workshop
const Roster := Family.Roster
var lab: Control
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-family-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	_key(KEY_F7)
	await process_frame
	var old: Chapter = lab.chapter
	var coal := old.fire.coals[0]
	var wood := old.fire.stored[0]
	var geometry: Node3D = lab.view.workbench.cave
	var time := old.fire.time
	var sites := old.gathering.records.duplicate(true)
	lab.mentor.story_line("The warmth stays with us.", "family_fixture")
	_check(not lab.story_menu.visible and not old.begin_family(), "Chapter III is gated by Chapter II completion")
	old.outcome = "prepared"
	old.sequel.outcomes = "prepared"
	await process_frame
	_check(lab.story_menu.results_continue.is_visible_in_tree() and lab.story_menu.results_continue.text == "Continue to Chapter III",
		"Chapter II completion exposes the normal handoff")
	_click(lab.story_menu.results_continue.get_global_rect().get_center())
	await process_frame
	_click(lab.story_menu.chapter_button.get_global_rect().get_center())
	await process_frame
	_check(lab.chapter == old and old.family != null and old.fire.coals[0] == coal and old.fire.stored[0] == wood
		and old.gathering.records == sites and old.fire.time == time and geometry == lab.view.workbench.cave
		and lab.mentor.history.has("The warmth stays with us."), "The live handoff retains the physical cave, time, fuel, routes and dialogue")
	_check(lab.paused and not lab.pause_button.disabled and lab.practice_line.text.contains("Chapter III"),
		"Chapter III opens paused with the ordinary time controls available")
	var page = lab.family_page
	_check(lab.site_picker.item_count == lab.family_area_start + 3 and lab.view.workbench.family_props.is_visible_in_tree(),
		"The shelter offers three new working surfaces in the shared scene")
	_check(lab.view.torch_present and lab.torch_button.visible, "The Torch Bearer retains his portrait and main-screen interaction")
	_key(KEY_F9)
	await process_frame
	_check(page.family_panel.is_visible_in_tree() and page.cards.size() == 15
		and page.detail.text.contains("Ember Tender"), "The family page presents fifteen selectable people")
	_click(page.cards[Roster.SPEAKER].get_global_rect().get_center())
	await process_frame
	_check(page.detail.text.contains("Mother’s brother") and page.detail.text.contains("Fire Speaker"),
		"Selecting the Fire Speaker shows his relationship and responsibility")
	_click(page.cards[Roster.SCOUT].get_global_rect().get_center())
	await process_frame
	_check(page.detail.text.contains("Mother’s sister’s son") and page.detail.text.contains("Day 4")
		and page.detail.text.contains("Seen at the shelter") and page.portraits_by_person[Roster.SCOUT].visible,
		"Selecting Rusk shows known activity, source, date and the existing portrait")
	await _capture("family-tree")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not page.family_panel.visible and lab.view.mouse_filter == Control.MOUSE_FILTER_STOP, "Escape returns control to the physical hearth")
	_key(KEY_F6)
	await process_frame
	_check(lab.torch_panel.visible and lab.torch_report.text.contains("Bera brought in") and not lab.torch_send.disabled,
		"Rusk announces the new catch through his original gathering interface")
	_click(lab.torch_send.get_global_rect().get_center())
	await process_frame
	_check(old.away >= 0 and not lab.view.torch_present and old.family.known[Roster.SCOUT].activity.contains("Last seen leaving"),
		"The usual gathering request sends Rusk away and records his departure")
	_key(KEY_F8)
	await process_frame
	_check(lab.chapter.family != null and lab.chapter != old and lab.paused, "F8 opens the reproducible practice start")
	var model: Work = lab.chapter.family.workshop
	var game := model.stock("carcass")[0]
	lab.site_picker.item_selected.emit(lab.family_area_start + 1)
	await create_timer(0.60).timeout
	_check(page.work_panel.visible and page.station == Work.HUNTER and page.choose_action.text == "Separate cuts",
		"The shelter menu focuses the hunters’ board and offers its actual game parcel")
	await _capture("hunters-board")
	_key(KEY_ESCAPE)
	var label: Label3D = lab.view.workbench.family_props.labels[Work.HUNTER]
	var anchor := label.global_position
	_click(lab.view.workbench.project(Vector3(anchor.x, anchor.z, anchor.y)))
	await process_frame
	_check(page.teaching_panel.visible and page.station == Work.HUNTER, "The board’s label also opens its physical work area")
	_click(page.bench_button.get_global_rect().get_center())
	await process_frame
	_click(page.choose_action.get_global_rect().get_center())
	await process_frame
	_check(not model.parcels.has(game.id) and model.stock("bone").size() == 1, "The working interface processes that parcel")
	_select_action("Carry to Nara")
	_click(page.choose_action.get_global_rect().get_center())
	lab.site_picker.item_selected.emit(lab.family_area_start)
	await create_timer(0.60).timeout
	_check(page.station == Work.COOK and page.choose_action.text == "Set on spit", "The carried cut is offered at the Cooking Place")
	_click(page.choose_action.get_global_rect().get_center())
	await process_frame
	var roast := model.roast
	await process_frame
	_check(roast != null and lab.view.workbench.family_props.roast.visible, "The roasting cut appears over the coals")
	page.choice.select(2)
	page.choice.item_selected.emit(2)
	_check(model.roast_position == 2, "The resting position moves the physical spit off the coals")
	page.choice.select(1)
	page.choice.item_selected.emit(1)
	await _elapse(22.0)
	_click(page.operations[0].get_global_rect().get_center())
	await _elapse(22.0)
	_check(model.roast.condition() == "Roasted" and page.work_status.text.contains("Roasted"), "Turning over live heat updates the roast and its visual reading")
	await _capture("cooking")
	_click(page.operations[1].get_global_rect().get_center())
	await process_frame
	_check(roast.rest == Work.STORE and model.roast == null, "Lifting the roast stores the same cooked portion")
	_key(KEY_ESCAPE)
	_key(KEY_F9)
	page._set_page(2)
	await process_frame
	_check(page.ledger.text.contains("Turn a portion and roast it through") and page.path_picker.item_count == 4,
		"The Ember Tender page records the lesson and offers four paths")
	_key(KEY_F8)
	await process_frame
	model = lab.chapter.family.workshop
	lab.site_picker.item_selected.emit(lab.family_area_start + 2)
	await create_timer(0.60).timeout
	await _capture("makers-stone")
	_check(page.station == Work.MAKER and page.choose_action.text == "Scrape resin", "The Maker’s Stone exposes the resinous knot")
	_click(page.choose_action.get_global_rect().get_center())
	_select_action("Warm the cup")
	_click(page.choose_action.get_global_rect().get_center())
	await process_frame
	await process_frame
	_check(model.resin != null and lab.view.workbench.family_props.cup.visible, "Heating resin places the physical stone cup by the red")
	await _elapse(39.0)
	_check(page.work_status.text.contains("Runs evenly"), "Ina’s cup shows when adhesive is ready")
	await _capture("resin-cup")
	_click(page.operations[0].get_global_rect().get_center())
	await process_frame
	for i in range(page.options.size()):
		if str(page.options[i].value) == "ivo":
			page.choice.select(i)
			page.choice.item_selected.emit(i)
			break
	await process_frame
	_check(page.secondary.visible and not page.choose_action.disabled, "Both hafting choices stay visible for Ivo’s loose spear")
	_click(page.choose_action.get_global_rect().get_center())
	await process_frame
	_check(model.gear.ivo.condition == 0.86 and model.stock("binding").is_empty(), "The Maker’s controls repair Ivo’s actual spear")
	_key(KEY_F4)
	await process_frame
	_check(lab.chapter == null and not page.family_panel.visible and not lab.view.workbench.family_props.visible,
		"Leaving the story removes the Chapter III panels and work objects")
	_key(KEY_F1)
	await process_frame
	_check(lab.chapter.family == null and lab.chapter.sequel == null and lab.site_picker.item_count == lab.family_area_start,
		"Chapter I replay preserves its original shelter controls")
	print("Chapter III scene: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _select_action(action: String) -> void:
	var page = lab.family_page
	for i in range(page.options.size()):
		if page.options[i].action == action:
			page.choice.select(i)
			page.choice.item_selected.emit(i)
			return
	_check(false, "Missing action " + action)

func _elapse(seconds: float) -> void:
	for tick in range(roundi(seconds / Chapter.Fire.STEP)):
		lab.chapter.step()
	await process_frame

func _capture(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(args[0].path_join(name + ".png")) == OK, "Captured " + name)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _click(point: Vector2) -> void:
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = root.get_stretch_transform() * point
		click.global_position = click.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		Input.parse_input_event(click)
		Input.flush_buffered_events()

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		printerr("FAIL  ", label)
