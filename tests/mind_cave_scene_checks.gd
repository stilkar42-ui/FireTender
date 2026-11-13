extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const Chapter := preload("res://sim/red_hollow.gd")
const Family := Chapter.Family
const Land := Family.Land
const Roster := Family.Roster
const Work := Family.Workshop
const Page := preload("res://hearth/family_page.gd")
const Portraits := Page.Portraits

var lab: Control
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-mind-cave-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await _settle()
	_check(not lab.mind_cave_button.visible and lab.family_page.portraits_by_person.is_empty(),
		"Chapter I leaves Chapter III controls hidden and portraits unloaded")
	_key(KEY_F8)
	await _settle()
	var page: Page = lab.family_page
	var map := page.mind_cave
	var family: Family = lab.chapter.family
	_check(lab.mind_cave_button.visible and page.portraits_by_person.size() == 14,
		"Chapter III opens with fourteen portrait-bearing family members")
	_key(KEY_F9)
	await _settle()
	_check(Portraits.path_for(Roster.APPRENTICE).is_empty() and not page.portraits_by_person.has(Roster.APPRENTICE),
		"The Ember Tender has no prescribed portrait")
	for id: String in Roster.PEOPLE:
		if id == Roster.APPRENTICE:
			continue
		_click(page.cards[id].get_global_rect().get_center())
		var portrait := page.portraits_by_person[id]
		_check(portrait.is_visible_in_tree() and portrait.texture != null and portrait.texture.get_width() > 80 and
			page.cards[id].icon == portrait.texture and page.person == id,
			"%s displays a portrait in the Family Tree" % Roster.person_name(id))
	_check(Portraits.path_for(Roster.SPEAKER).ends_with("fire_speaker.svg")
		and Portraits.path_for(Roster.SCOUT).ends_with("torch_bearer.png") and lab.view.torch_present,
		"The Fire Speaker and Rusk retain their established art and Rusk stays on the main scene")
	_click(page.cards["nara"].get_global_rect().get_center())
	_check(map.inside and map.chosen == Work.COOK, "Selecting Nara prepares her last-known place on the map")
	await _capture("family-tree")
	_click(page.show_on_map.get_global_rect().get_center())
	await _settle()
	_check(page.page == Page.MAP_PAGE and map.place_buttons[Work.COOK].selected
		and map.person_buttons.has("nara") and map.kin_buttons[Work.COOK].visible, "The Family Tree links to the selected work area and its people")
	await _capture("inside-red-hollow")
	_click(map.kin_buttons[Work.COOK].get_global_rect().get_center())
	_check(page.page == 0 and page.person == "nara", "A single person mark opens the matching Family Tree entry")
	_click(page.show_on_map.get_global_rect().get_center())
	_click(map.place_buttons["Seep"].get_global_rect().get_center() - Vector2(0, 7))
	var at := Vector3(Land.INSIDE["Seep"][4].x, 0.10, Land.INSIDE["Seep"][4].y)
	_check(map.chosen == "Seep" and lab.view.workbench.focus_target.is_equal_approx(lab.view.workbench._bounded_focus(at)),
		"Clicking the Seep directs the existing camera to the physical seep")
	_click(map.look_button.get_global_rect().get_center())
	_check(not page.family_panel.visible, "Look here closes the map and returns to the selected cave area")

	_key(KEY_F10)
	_click(map.area_tabs[0].get_global_rect().get_center())
	await _settle()
	var former_focus: Vector3 = lab.view.workbench.focus_target
	_click(map.place_buttons[Land.PINE].get_global_rect().get_center() - Vector2(0, 6))
	_check(map.chosen == Land.PINE and _contains_note(map, "No word of the weather here") and
		lab.view.workbench.focus_target == former_focus and not map.look_button.visible,
		"An exterior place shows remembered details and does not move the cave camera")
	_check(lab.chapter.request(1), "Rusk can depart for the fallen pine with the existing gathering action")
	await _settle()
	_check(map.kin_buttons[Land.PINE].visible and map.kin_buttons[Land.PINE].uncertain and
		map.chart.route == Land.PINE and _contains_note(map, "Seen leaving") and not lab.view.torch_present,
		"The departing scout appears as an uncertain destination with a trace")
	await _capture("rusks-gathering-path")
	_click(map.person_buttons[Roster.SCOUT].get_global_rect().get_center())
	_check(page.page == 0 and page.person == Roster.SCOUT and page.detail.text.contains("Last seen leaving"),
		"The place’s family list opens Rusk’s dated departure entry")
	_step_until(lab.chapter.returns_at + 1.0)
	await _settle()
	_click(page.page_tabs[1].get_global_rect().get_center())
	await _settle()
	_check(page.news_map.visible and page.news_portrait.texture == page.portraits_by_person[Roster.SCOUT].texture,
		"Rusk’s latest report shows his portrait and a location link")
	await _capture("shelter-news")
	_click(page.news_map.get_global_rect().get_center())
	await _settle()
	_check(map.chosen == Land.PINE and _contains_note(map, "Rusk") and _contains_note(map, "heard")
		and not map.place_buttons[Land.PINE].weather.is_empty() and not map.place_buttons[Land.PINE].weather_old,
		"Returned fuel and weather knowledge appears at the linked place")
	await _capture("mind-cave-territory")
	lab.chapter.fire.time = family.land.places[Land.PINE].weather.seen + Land.FADING_AFTER + 1
	await _settle()
	_check(map.place_buttons[Land.PINE].weather_old and _contains_note(map, "Older report"),
		"An old report fades without needing another simulation observation")
	_click(page.page_tabs[0].get_global_rect().get_center())
	_click(page.cards["nara"].get_global_rect().get_center())
	_click(page.show_on_map.get_global_rect().get_center())
	family._set_activity("nara", "Setting out roots for the children", Work.STORE)
	await _settle()
	_check(map.chosen == Work.STORE and map.person_buttons.has("nara"),
		"A linked family place follows a newly witnessed change")
	_check(page.family_panel.get_global_rect().encloses(map.get_global_rect()) and
		map.chart.get_global_rect().size.x >= 500 and map.place_buttons[Work.STORE].size.x >= 150,
		"The map chart, symbols and place details fit the supported viewport")
	_key(KEY_F1)
	await _settle()
	_check(not page.family_panel.visible and not lab.mind_cave_button.visible and lab.chapter.family == null,
		"Replaying Chapter I removes Chapter III knowledge and controls")
	print("Mind Cave scene: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _contains_note(map: Control, words: String) -> bool:
	for child in map.notes.get_children():
		if child is Label and child.text.contains(words):
			return true
	return false

func _step_until(until: float) -> void:
	while lab.chapter.fire.time < until:
		lab.chapter.step()

func _settle() -> void:
	await process_frame
	await process_frame

func _capture(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(args[0].path_join(name + ".png")) == OK, "Captured " + name)

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_stretch_transform() * point
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		printerr("FAIL  ", label)

