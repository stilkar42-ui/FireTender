extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const View := preload("res://hearth/fire_view.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var lab := Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-chapter-check-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	await process_frame
	_check(lab.chapter != null and lab.paused and lab.fire.wood.is_empty() and lab.fire.coals.size() == 1,
		"The normal entry point opens the playable chapter paused beside a single coal")
	_check(lab.view.workbench.cave.visible and lab.view.torch_present and lab.view.torch_art != null and lab.view.speaker_art != null and lab.speech.visible and
		"mother’s kin" in lab.speech_text.text and lab.speech.get_global_rect().encloses(lab.speech_text.get_global_rect()),
		"The shelter, Torch Bearer and readable opening dialogue are visible together")
	var portrait: Image = lab.view.torch_art.get_image()
	_check(portrait.get_pixel(0, 0).a < 0.05 and not lab.view.torch_seat.intersects(lab.view.speaker_seat) and
		not lab.view.torch_seat.intersects(lab.journal.get_global_rect()) and lab.view.get_global_rect().encloses(lab.view.torch_seat),
		"The transparent portrait sits beside the workbench, clear of the elder and the journal")
	_check(lab.view.workbench.logs.size() == 21 and lab.fire.stored.size() == 21,
		"All opening supplies have ray-pickable woodpile meshes")
	var directory := OS.get_cmdline_user_args()
	if not directory.is_empty():
		await _capture(directory[0], "red-hollow")
	_click(lab.view.torch_seat.get_center())
	await process_frame
	_check(lab.torch_panel.visible and "Cousin" in lab.torch_report.text and not lab.torch_send.disabled and "fallen pine" in lab.torch_report.text,
		"The portrait opens the scout’s account and a survey of actual sites")
	if not directory.is_empty():
		await _capture(directory[0], "torch-bearer")
	_click(lab.torch_send.get_global_rect().get_center())
	await process_frame
	await process_frame
	_check(lab.chapter.away == 1 and not lab.torch_panel.visible and not lab.view.torch_present,
		"Choosing the lee path sends the cousin out and leaves the hearth usable")
	_key(KEY_3)
	_check(lab.view.placing < 0, "Fuel hotkeys respect story stock")
	var source = lab.fire.stock_piece(4)
	var source_at: Vector2 = source.at
	_key(KEY_5)
	_click(lab.view.screen_at(Vector2(0.05, 0.05)))
	await process_frame
	_check(lab.fire.wood.size() == 1 and lab.fire.wood[0] == source and lab.fire.fuel_stock[4] == 5 and lab.site_picker.is_item_disabled(0),
		"Ray-picked placement draws from the finite bundle and fixes the site")
	await _drag(lab.view._project(source.pose.point(0.0)), lab.view.screen_at(source_at))
	_check(source in lab.fire.stored and lab.fire.fuel_stock[4] == 6 and lab.fire.all_fuel().size() == 21,
		"Dragging the placed parcel back restores the same object to the pile")
	for i in range(5):
		var angle := TAU * i / 5.0
		lab.fire.add_fuel(4, Vector2.from_angle(angle) * 0.043, angle + PI * 0.5, 0.0, 0, true)
	var ember = lab.fire.coals[0]
	lab.fire.lift_coal(ember)
	lab.fire.deposit_coal(ember, Vector2.ZERO)
	lab._advance(28.0)
	while lab.jump_steps > 0:
		await process_frame
	await process_frame
	_check(lab.view.torch_present and lab.chapter.away < 0 and lab.fire.fuel_stock[8] == 4 and "I laid the wood" in lab.chapter.report,
		"The portrait returns with an updated report and his actual delivery")
	_key(KEY_Y)
	_check(lab.view.tool == View.Tool.ASH, "Y selects the ash tool in story mode")
	_click(lab.view.torch_seat.get_center())
	await process_frame
	_check(lab.torch_panel.visible and "I laid the wood" in lab.torch_report.text and lab.view.tool == View.Tool.ASH,
		"The returned cousin can be consulted while another tending tool is selected")
	_key(KEY_G)
	await process_frame
	var seat: Rect2 = lab.view.speaker_seat
	_check(lab.ask_panel.visible and lab.ask_panel.get_global_rect().position.y > seat.end.y,
		"The question popup stays below the seated elder")
	lab.ask_entry.text = "Who are our people?"
	_click(lab.ask_entry.get_global_rect().get_center())
	_key(KEY_ENTER)
	await process_frame
	_check(lab.speech.visible and "Stone Mountain’s kin" in lab.speech_text.text and lab.view.speaker_seat == seat,
		"Typed story questions reach the kinship reply in the normal dialogue interface")
	_key(KEY_F4)
	await process_frame
	_check(lab.chapter == null and lab.fire.fuel_stock.is_empty() and not lab.view.workbench.cave.visible and
		not lab.ash_button.visible and lab.weather_picker.visible and lab.mentor.ember_training,
		"One Ember keeps its experimental supplies, controls and practice")
	_key(KEY_F1)
	await process_frame
	_check(lab.chapter != null and lab.chapter.away == -1 and lab.fire.time == 0.0 and lab.fire.fuel_stock[4] == 6 and lab.fire.ash == 0.0,
		"F1 replays the chapter with a fresh ember, clear weather and original supplies")
	_key(KEY_L)
	for frame in range(30):
		await process_frame
	var workbench = lab.view.workbench
	var stocked = lab.fire.stock_piece(7)
	var pile_at: Vector2 = lab.view._project(stocked.pose.point(0.0))
	_check(Rect2(Vector2.ZERO, lab.view.size).has_point(pile_at) and
		workbench.hit(pile_at).piece == stocked,
		"The woodpile shortcut brings stored sticks into reach for direct picking")
	_click(lab.view._project(stocked.pose.point(0.0)))
	_key(KEY_F)
	await create_timer(0.55).timeout
	_check(lab.view.selected == stocked and lab.view._project(stocked.pose.point(0.0)).distance_to(lab.view.size * 0.5) < 1.5,
		"F focuses the selected physical piece in the pile")
	if not directory.is_empty():
		await _capture(directory[0], "woodpile")
		_key(KEY_HOME)
		# A paused display fixture for reviewing the storm presentation.
		lab.fire.time = 930.0
		lab.chapter.weather.sample(lab.fire.time)
		lab.view.workbench.reset_scene()
		await process_frame
		await _capture(directory[0], "red-hollow-storm")
	print("Red Hollow scene: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		_button_at(at, pressed)

func _button_at(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_stretch_transform() * at
	event.global_position = event.position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _drag(from: Vector2, to: Vector2) -> void:
	_button_at(from, true)
	await process_frame
	var event := InputEventMouseMotion.new()
	event.position = root.get_stretch_transform() * to
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_button_at(to, false)
	await process_frame

func _capture(directory: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := directory.path_join("firetender-%s.png" % name)
	_check(root.get_texture().get_image().save_png(path) == OK, "Captured " + name)

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
