extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const Save := preload("res://sim/chapter_save.gd")
const Chapter := Save.Chapter
const Work := Save.Work
const Props := preload("res://hearth/family_props.gd")
var lab: Control
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-physical-%d.cfg" % OS.get_process_id())
	lab.chapter_save_path = OS.get_environment("TEMP").path_join("firetender-physical-scene-%d.sav" % OS.get_process_id())
	root.add_child(lab)
	await _settle()
	_key(KEY_F8)
	await _settle()
	await _station(Work.HUNTER)
	var work: Work = lab.chapter.family.workshop
	var page = lab.family_page
	var props: Props = lab.view.workbench.family_props
	var game := work.stock("carcass")[0]
	_check(props.actors.bera.visible and props.items[game.id].visible and page.teaching_panel.visible
		and page.teacher_name.text == "Bera" and page.teacher_art.texture != null,
		"Bera is at the hunters’ board with the catch and greets you in his own portrait")
	await _capture("bera-and-catch")
	_hover_item(game.id)
	_key(KEY_I)
	_check(lab.note.text.contains("Carcass portion") and work.lessons.has(Work.HUNTER, "look"),
		"I inspects the actual item under the pointer")
	var flake := work.stock("flake", Work.HUNTER)[0]
	_click_item(flake.id)
	await _settle()
	_check(work.held == flake.id, "A click lifts the physical flake")
	_click_item(game.id)
	await _settle()
	_check(work.held == flake.id and game.grams == 540 and props.items[game.id].scale.x < 1.0,
		"Using the held flake shrinks the carcass and leaves separate cuts")
	if work.stock("bone").is_empty():
		_finish()
		return
	_key(KEY_ESCAPE)
	await _settle()
	var bone := work.stock("bone")[0]
	var bone_from := _item_point(bone.id)
	_mouse(bone_from, true)
	var floor_point := _clear_floor_point(props)
	_move(floor_point, MOUSE_BUTTON_MASK_LEFT)
	_mouse(floor_point, false)
	await _settle()
	_check(work.held == 0 and bone.rest == Work.FLOOR, "The same drag gesture used for wood moves an intact bone")
	_click_item(bone.id)
	await _settle()
	_click_surface(Work.HUNTER, Vector2(0.16, 0.12))
	await _settle()
	_hover_item(bone.id)
	_key(KEY_V)
	await _settle()
	_check(not work.parcels.has(bone.id) and work.stock("marrow").size() == 1 and props.items.has(work.stock("bone_shard")[0].id),
		"The stone and hammer split the bone into visible pieces and marrow")
	var hide_piece := work.stock("hide", Work.HUNTER)[0]
	_hover_item(hide_piece.id)
	_key(KEY_V)
	await _settle()
	_click_item(hide_piece.id)
	await _settle()
	_click(_screen(Work.HIDE_AT, 0.38))
	await create_timer(0.55).timeout
	_click_surface(Work.HIDE_RACK, Vector2(0.02, 0.0))
	await _settle()
	_check(hide_piece.kind == "clean_hide" and hide_piece.rest == Work.HIDE_RACK
		and props.items[hide_piece.id].scale.x > 1.3, "The cleaned hide spreads visibly when placed on its rack")
	await _station(Work.HUNTER)
	await _capture("processed-catch")
	var cut := work.stock("meat", Work.HUNTER)[0]
	_click_item(cut.id)
	await _settle()
	await _station(Work.COOK)
	_check(work.held == cut.id and page.teacher_name.text == "Nara" and props.actors.nara.visible,
		"The cut stays in hand while you move to Nara’s Cooking Place")
	_click_surface(Work.COOK, Vector2(0.0, -0.06))
	await _settle()
	_hover_item(cut.id)
	_key(KEY_V)
	await _settle()
	_check(cut.rest == Work.COOK and cut.grams == 122 and work.stock("meat", Work.COOK).size() == 2,
		"Nara’s board accepts and portions the same cut")
	var portion: Work.Parcel = work.stock("meat", Work.COOK).back()
	_click_item(portion.id)
	await _settle()
	_click(_screen(Work.ROAST_POSITIONS[1], 0.16))
	await _settle()
	_check(work.roast == portion and work.held == 0, "The coal-edge target receives the same physical portion")
	await _elapse(22.0)
	_hover_item(portion.id)
	_key(KEY_V)
	await _elapse(22.0)
	_check(work.roast != null and portion.condition() == "Roasted" and page.teacher_words.text.contains("middle is warm"),
		"The apprentice turns the portion and Nara responds to its actual heat state")
	await _capture("nara-and-roast")
	_click_item(portion.id)
	await _settle()
	_key(KEY_F5)
	_check(FileAccess.file_exists(lab.chapter_save_path) and work.held == portion.id,
		"F5 saves while the cooked portion is in hand")
	_key(KEY_F1)
	await _settle()
	_key(KEY_F11)
	await _settle()
	if lab.chapter.family == null:
		_check(false, "F11 restored Chapter III")
		_finish()
		return
	work = lab.chapter.family.workshop
	_check(work.held == portion.id and work.parcels[portion.id].condition() == "Roasted" and work.lessons.has(Work.COOK, "turn"),
		"F11 brings back the cooked portion, held identity and lesson evidence")
	lab.view.workbench.focus_on(Vector3(Work.STORE_AT.x, 0.10, Work.STORE_AT.y))
	await create_timer(0.55).timeout
	_click_surface(Work.STORE, Vector2(0.10, 0.02))
	await _settle()
	_check(work.held == 0 and work.parcels[portion.id].rest == Work.STORE and work.lessons.complete(Work.COOK),
		"The restored portion can be laid on the covered shelf to complete Nara’s lesson")
	_key(KEY_G)
	lab._submit_question("I roasted a cut for Nara")
	await _settle()
	_check(lab.mentor.text.contains("food on the covered shelf") and lab.mentor.text.contains("turned"),
		"Eren’s normal conversation reflects the actual roast and handling")

	_key(KEY_F8)
	await _settle()
	work = lab.chapter.family.workshop
	await _station(Work.MAKER)
	_check(page.teacher_name.text == "Ina" and props.actors.ina.visible, "Ina is physically present and introduces the damaged haft")
	var knot := work.stock("knot")[0]
	_hover_item(knot.id)
	_key(KEY_V)
	await _settle()
	if work.stock("resin").is_empty():
		_check(false, "Ina’s stone made raw resin")
		_finish()
		return
	var resin := work.stock("resin")[0]
	_click_item(resin.id)
	await _settle()
	_click_item(work.cup_id)
	await _settle()
	_check(work.cup_fill == resin.id and work.held == 0 and work.resin_position == -1,
		"The apprentice physically loads the stone cup with resin")
	_click_item(work.cup_id)
	await _settle()
	lab.view.workbench.focus_on(Vector3(-0.52, 0.14, -0.04))
	await create_timer(0.55).timeout
	_click(_screen(Work.RESIN_POSITIONS[0], 0.095))
	await _elapse(39.0)
	_check(work.resin_position == 0 and resin.cure >= 1.0, "The cup heats at the selected warm stone")
	await _capture("ina-and-warming-cup")
	_click_item(work.cup_id)
	await _settle()
	await _station(Work.MAKER)
	_click_surface(Work.MAKER, Vector2(0.12, 0.09))
	await _settle()
	_check(work.held == 0 and resin.kind == "pitch" and resin.rest == Work.MAKER, "The same resin is carried back as usable adhesive")
	_hover_item(work.stock("point")[0].id)
	_key(KEY_V)
	_hover_item(work.stock("shaft")[0].id)
	_key(KEY_V)
	await _station(Work.HUNTER)
	var spear := work.gear_id("ivo")
	_click_item(spear)
	await _settle()
	await _station(Work.MAKER)
	_click_surface(Work.MAKER, Vector2(0.03, 0.07))
	await _settle()
	_hover_item(spear)
	_key(KEY_V)
	_key(KEY_I)
	await _settle()
	_check(work.gear.ivo.condition == 1.0 and work.lessons.has(Work.MAKER, "inspect_tool"),
		"The same spear is rehafted and can be inspected in the scene")
	await _capture("ina-and-finished-haft")
	_click_item(spear)
	await _settle()
	await _station(Work.HUNTER)
	_click(_screen(Work.RACK_AT + Vector2(0.0, 0.10), 0.048))
	await _settle()
	_check(work.gear.ivo.at == Work.HUNTER and work.lessons.complete(Work.MAKER),
		"Returning the physical spear makes the tool available and completes Ina’s lesson")
	_key(KEY_G)
	lab._submit_question("I repaired Ivo’s haft")
	await _settle()
	_check(lab.mentor.text.contains("binding") and lab.mentor.text.contains("Ivo"), "Eren reflects on the warmed adhesive and the actual haft")
	_finish()

func _finish() -> void:
	DirAccess.remove_absolute(lab.chapter_save_path)
	print("Physical workshop scene: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _station(station: String) -> void:
	lab.site_picker.item_selected.emit(lab.family_area_start + Work.STATIONS.keys().find(station))
	await create_timer(0.55).timeout
	if lab.family_page.work_panel.visible and lab.family_page.teaching_panel.visible:
		_click(lab.family_page.bench_button.get_global_rect().get_center())
		await _settle()

func _screen(at: Vector2, height: float) -> Vector2:
	return lab.view.workbench.project(Vector3(at.x, at.y, height))

func _clear_floor_point(props: Props) -> Vector2:
	for y in range(313, 510, 19):
		for x in range(414, 850, 27):
			var point := Vector2(x, y)
			var destination := props.destination(lab.view.workbench, point)
			if destination.get("rest", "") == Work.FLOOR and destination.at.distance_to(Work.RACK_AT) > 0.44 \
				and props.pointer_item(lab.view.workbench, point) == 0 and point.distance_to(_screen(Work.HIDE_AT, 0.38)) > 28:
				return point
	_check(false, "An open patch of cave floor is visible")
	return _screen(Vector2(-0.2, -2.4), 0)

func _item_point(id: int) -> Vector2:
	var props: Props = lab.view.workbench.family_props
	var at: Vector3 = props.items[id].global_position
	var centre: Vector2 = _screen(Vector2(at.x, at.z), at.y + (0.027 if id > 0 else 0.042))
	for radius in [0, 5, 10, 17, 24, 31]:
		for i in range(8):
			var candidate: Vector2 = centre + Vector2.from_angle(TAU * i / 8.0) * radius
			if props.pointer_item(lab.view.workbench, candidate) == id:
				return candidate
	_check(false, "Physical object %d can be reached from this view (centre %s hits %d)" %
		[id, centre, props.pointer_item(lab.view.workbench, centre)])
	return centre

func _hover_item(id: int) -> void:
	_move(_item_point(id))

func _click_item(id: int) -> void:
	_click(_item_point(id))

func _click_surface(rest: String, offset: Vector2) -> void:
	_click(_screen(Work.SURFACES[rest] + offset, Props.HEIGHTS[rest]))

func _elapse(seconds: float) -> void:
	for tick in range(roundi(seconds / Chapter.Fire.STEP)):
		lab.chapter.step()
	await _settle()

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
	_move(point)
	_mouse(point, true)
	_mouse(point, false)

func _move(point: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_stretch_transform() * point
	event.global_position = event.position
	event.button_mask = mask
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _mouse(point: Vector2, down: bool) -> void:
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

