extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const Fire := preload("res://sim/fire.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var lab := Lab.instantiate()
	lab.start_in_story = false
	var temp := OS.get_environment("TEMP") if OS.get_name() == "Windows" else "/tmp"
	lab.settings_path = temp.path_join("firetender-rotation-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	var out := OS.get_cmdline_user_args()
	_check(lab.view.get_global_rect().is_equal_approx(lab.get_global_rect()),
		"The hearth reaches all four edges of the application")
	_check(lab.mentor.training and lab.speech.visible and lab.view.speaker_art != null and
		lab.view.workbench.visible and lab.view.workbench.camera.is_current(),
		"The opening starts in 3D beside an illustrated Fire Speaker with a text bubble")
	if not out.is_empty():
		await _capture(out[0], "living")
	# Click controls at their current layout positions.
	_key(KEY_SPACE)
	await process_frame
	_check(lab.paused, "Space pauses the lab")
	_click(lab.fuel_buttons[0].get_global_rect().get_center())
	await process_frame
	_check(lab.view.placing == 0, "The bark button selects bark")
	_click(_scene_point(lab, Vector2(0.127, 0.094)))
	await process_frame
	_check(lab.fire.wood.size() == 3 and lab.fire.wood.back().kind == 0 and lab.view.placing == -1,
		"Clicking inside the ring places one selected piece")
	var bark = lab.fire.wood.back()
	var from: Vector2 = lab.view._project(bark.pose.point(0.0))
	var at: Vector2 = bark.at
	await _drag(from, from + Vector2(187, -58))
	_check(at.distance_to(bark.at) > 0.2, "Dragging relocates wood in the simulation")

	var log = lab.fire.wood[0]
	var face = log.faces[1]
	_key(KEY_T)
	_click(lab.view._project(log.pose.point(0.0)))
	await process_frame
	_check(log.faces[0] == face, "Roll tool turns the selected oak face up")
	_key(KEY_ESCAPE)
	_press(lab, "Rake coals")
	await process_frame
	_check(lab.fire.coals[0].at.length() < 0.28, "Rake gathers the bed")
	_press(lab, "Bank with ash")
	await process_frame
	_check(lab.fire.coals[0].cover > 0.0, "Bank spreads real ash")
	_press(lab, "Expose coals")
	await process_frame
	_check(lab.fire.coals[0].cover == 0.0, "Expose removes the cover")
	_key(KEY_R)
	var patch = lab.fire.coals[0]
	var coal_at: Vector2 = patch.at
	var coal_screen: Vector2 = _scene_point(lab, coal_at)
	await _drag(coal_screen, _scene_point(lab, coal_at + Vector2(-0.38, 0.18)))
	_check(patch.at.distance_to(coal_at) > 0.25, "The local rake gesture moves selected charcoal")

	_press(lab, "Breathe  [B]")
	var aim := _scene_point(lab, Vector2(-0.01, 0.03))
	await _drag(_scene_point(lab, Vector2(-0.01, 0.56)), aim)
	await process_frame
	_check(lab.fire.breaths.size() == 1 and lab.fire.breaths[0].direction.y < -0.9,
		"Breath tool sends an aimed burst")
	lab._update_hand()
	var touch = lab.view.workbench.touch_at(lab.view.pointer)
	_check(lab.heat_hand.heat >= lab.Heat.sample(lab.fire, lab._hand_point(touch.contact)) and not lab.warmth.text.is_empty(),
		"The painted hand reads felt heat at the hovered spot")
	_press(lab, "+30 seconds")
	await process_frame
	while lab.jump_steps > 0:
		await process_frame
	_check(lab.fire.time >= 30.0, "Advance runs fixed steps while paused")
	_key(KEY_I)
	await process_frame
	_check(lab.note.text == lab.Observe.read(lab.fire, lab.view.probe, lab.view.workbench.yaw, lab.warmth.text),
		"Inspect records a current local reading from the camera's side")

	var pickers := lab.find_children("*", "OptionButton", true, false)
	await _select_last(pickers[2], 6)
	_check(lab.fire.wood.size() == 1 and lab.fire.wood[0].faces.size() == 2, "The uneven oak trial is selectable")
	if not out.is_empty():
		await _capture(out[0], "uneven")
	await _select_last(pickers[2], 9)
	_check(lab.sound.measure(lab.fire, Vector2.ZERO).hiss > 0.1, "The damp trial drives the steam audio layer")
	if not out.is_empty():
		await _capture(out[0], "damp")
	await _select_last(pickers[2], 4)
	_check(lab.fire.total_flame() == 0.0 and lab.fire.coals[0].cover > 0.0 and
		lab.fire.heat_at(Vector2.ZERO) > 0.07, "The banked trial has local warmth without flame")
	if not out.is_empty():
		await _capture(out[0], "banked")
	await _select_last(pickers[2], 10)
	_check(lab.fire.total_flame() == 0.0 and lab.fire.heat_at(Vector2.ZERO) < 0.2,
		"The dying trial is substantially cooler")
	if not out.is_empty():
		await _capture(out[0], "dying")
	await _select_last(pickers[2], Fire.COLD + 1)
	_check(lab.fire.time == 0.0 and lab.fire.total_flame() == 0.0 and lab.fire.wood.is_empty(),
		"Trial menu loads the cold hearth")
	await _select_last(pickers[0])
	_check(lab.fire.weather == 3, "Weather menu applies driving rain")
	if not out.is_empty():
		await _capture(out[0], "rain")
	await _select_last(pickers[1])
	_check(lab.speed == 64 and lab.paused, "Speed menu sets 64× without resuming the hearth")
	_key(KEY_F3)
	await process_frame
	_check(lab.debug.visible and "Ambient 3 °C" in lab.report.text,
		"F3 shows developer readings from the current simulation")
	if DisplayServer.get_name() != "headless":
		_check(lab.sound.player.playing and lab.sound.playback != null, "Rendered scene starts the procedural audio stream")
	if not out.is_empty():
		await _capture(out[0], "debug")
	_key(KEY_F3)
	await _select_last(pickers[2], 11)
	var wet_log: Fire.Piece = lab.fire.wood.back()
	_check(wet_log.pose.slope < -0.12 and wet_log.pose.supports.size() > 1 and not lab.mentor.training,
		"The wet-end trial loads a supported lean independently of the apprenticeship")
	if not out.is_empty():
		await _capture(out[0], "propped")
	_click(lab.view.get_global_transform() * lab.view._project(wet_log.pose.point(0.0)))
	_check(lab.view.selected == wet_log, "Picking the visible log selects it at its projected height")
	var angle := wet_log.axis.angle()
	_key(KEY_E)
	_check(absf(wet_log.axis.angle() - angle) > 0.1, "E rotates the selected log")
	_key(KEY_Q, true)
	_check(wet_log.lean < -0.9, "Shift+Q changes the requested lean")
	_key(KEY_Q, false, true)
	_check(wet_log.tier == -1 and wet_log.height < 0.14, "Ctrl+Q lowers the selected log to a supported layer")
	var lower := wet_log.height
	_key(KEY_E, false, true)
	_check(wet_log.tier == 0 and wet_log.height > lower + 0.03, "Ctrl+E lifts the selected log onto the prop")
	_key(KEY_3)
	var placement: Vector2 = _scene_point(lab, Vector2(-0.12, 0.03))
	_hover(placement)
	await process_frame
	_check(lab.view.drop_pose != null and not lab.view.drop_pose.supports.is_empty(),
		"The placement ghost resolves its support before committing fuel")
	if not out.is_empty():
		await _capture(out[0], "build-guide")
	_key(KEY_ESCAPE)
	_key(KEY_F2)
	await process_frame
	_click(lab.view.get_global_transform() * lab.view.speaker_seat.get_center())
	await process_frame
	_check(lab.history_panel.visible and "mother’s kin" in lab.history_text.text,
		"Selecting the seated elder opens readable dialogue history")
	if not out.is_empty():
		await _capture(out[0], "history")
	_click(lab.retry_button.get_global_rect().get_center())
	await process_frame
	_check(lab.mentor.training and lab.mentor.lesson == 0 and lab.mentor.history.size() == 1 and lab.paused,
		"Retry starts a fresh paused practice while retaining the elder's words")
	await _rotation_settings(lab, out)
	await _apprenticeship(lab)
	await _consultation(lab, out)
	DirAccess.remove_absolute(lab.settings_path)
	print("Firetender scene check: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _rotation_settings(lab: Control, out: PackedStringArray) -> void:
	_key(KEY_3)
	_hover(_scene_point(lab, Vector2(0.02, 0.03)))
	var initial: float = lab.fire.default_yaw(lab.fire.next_id)
	_key_state(KEY_E, true)
	await create_timer(0.12).timeout
	_key_state(KEY_E, false)
	_check(is_equal_approx(angle_difference(initial, lab.view.build_yaw), PI / 12.0),
		"Fixed mode turns 15 degrees once even when E is held")

	_press(lab, "Settings")
	await process_frame
	_check(lab.settings_panel.visible, "Settings opens from the header")
	var sliders: Array[Node] = lab.settings_panel.find_children("*", "HSlider", true, false)
	_click(sliders[0].get_global_rect().position + Vector2(4, 12))
	_check(lab.sound.fire_volume < 0.04 and lab.sound.weather_volume > 0.0,
		"Settings contains the independent Fire and Weather volume controls")
	var picker: OptionButton = lab.settings_panel.find_children("*", "OptionButton", true, false)[0]
	await _select_last(picker)
	var saved := ConfigFile.new()
	_check(lab.smooth_rotation and saved.load(lab.settings_path) == OK and
		saved.get_value("controls", "smooth_rotation", false), "The smooth setting is saved locally")
	if not out.is_empty():
		await _capture(out[0], "rotation-settings")
	_key(KEY_ESCAPE)
	_key_state(KEY_E, true)
	var tap: float = lab.view.build_yaw
	await create_timer(0.14).timeout
	var held: float = lab.view.build_yaw
	_key_state(KEY_E, false)
	await create_timer(0.09).timeout
	_check(angle_difference(tap, held) > 0.08 and is_equal_approx(held, lab.view.build_yaw),
		"Smooth mode rotates while E is held and stops on release")
	_click(_scene_point(lab, Vector2(0.02, 0.03)))
	var log: Fire.Piece = lab.fire.wood.back()
	_click(lab.view.get_global_transform() * lab.view._project(log.pose.point(0.0)))
	_key_state(KEY_Q, true)
	var heading := log.axis.angle()
	await create_timer(0.14).timeout
	_key_state(KEY_Q, false)
	_check(angle_difference(heading, log.axis.angle()) < -0.08,
		"Holding Q turns a selected log smoothly in the opposite direction")

func _apprenticeship(lab: Control) -> void:
	_key(KEY_F2)
	_key(KEY_SPACE)
	await _advance(lab, 3.0)
	_key(KEY_2)
	_click(_scene_point(lab, Vector2(0.18, 0.26)))
	await _advance(lab, 22.0)
	_check(lab.mentor.lesson == 1, "3D placement of fresh kindling advances the opening practice")
	if lab.mentor.lesson != 1:
		return

	await _retry(lab)
	var wet_log: Fire.Piece = lab.fire.wood.back()
	_key(KEY_T)
	_click(lab.view._project(wet_log.pose.point(0.0)))
	await _advance(lab, 32.0)
	_check(lab.mentor.lesson == 2, "Rolling the wet-end log in 3D advances the heat-travel practice")
	if lab.mentor.lesson != 2:
		return

	await _retry(lab)
	await _advance(lab, 1.0)
	var coal: Fire.Piece = lab.fire.coals[2]
	_key(KEY_1)
	_click(_scene_point(lab, coal.at))
	await _advance(lab, 18.0)
	_check(lab.mentor.lesson == 3, "A 3D placement rekindles the bed and advances the coal practice")
	if lab.mentor.lesson != 3:
		return

	await _retry(lab)
	_press(lab, "Rake coals")
	_press(lab, "Bank with ash")
	await _advance(lab, 60.0)
	_check(lab.mentor.bank_kept, "The 3D tending controls earn the Speaker's banking cue")
	_press(lab, "Expose coals")
	_key(KEY_2)
	_click(_scene_point(lab, Vector2.ZERO))
	await _advance(lab, 28.0)
	_check(lab.mentor.lesson == 4 and "Ready for One Ember" in lab.practice_line.text,
		"Exposing and relighting the banked bed unlocks the fifth practice")

	_key(KEY_F4)
	_key(KEY_5)
	_click(_scene_point(lab, Vector2.ZERO))
	await _advance(lab, 4.0)
	_check(lab.mentor.ember_training and lab.mentor.lesson == 4 and lab.fire.total_flame() > 3.0 and
		lab.view.workbench.visible, "The fifth practice starts and kindles from one coal in the same workbench")

func _retry(lab: Control) -> void:
	_key(KEY_H)
	await process_frame
	_click(lab.retry_button.get_global_rect().get_center())
	await process_frame

func _consultation(lab: Control, out: PackedStringArray) -> void:
	_key(KEY_F4)
	await process_frame
	_hover(_scene_point(lab, Vector2(0.60, 0.55)))
	await create_timer(0.10).timeout
	var distant: int = lab.heat_hand.band
	_hover(_scene_point(lab, Vector2.ZERO))
	await create_timer(0.10).timeout
	var bar: Control = lab.fuel_buttons[0].get_parent()
	_check(lab.heat_hand.band > distant and lab.get_global_rect().encloses(lab.heat_hand.get_global_rect()) and
		lab.get_global_rect().encloses(lab.warmth.get_global_rect()) and
		not bar.get_global_rect().intersects(lab.heat_hand.get_global_rect()),
		"The hand follows heat under the cursor and fits beside the fuel bar")
	var hand = lab.heat_hand
	var between: Color = hand.heat_color(0.115)
	_check(hand.size.x > 75 and hand.size.y > 85 and hand.heat_color(0.0).r > 0.8 and
		hand.heat_color(0.05).r > hand.heat_color(0.05).g * 2.0 and
		hand.heat_color(2.8).g > 0.9 and between != hand.heat_color(0.05) and between != hand.heat_color(0.18),
		"The larger hand has a white cold outline and a continuous red-to-orange-to-yellow-to-white heat gradient")
	_key(KEY_5)
	_hover(_scene_point(lab, Vector2.ZERO))
	_check(lab.view.drop_pose != null and lab._hand_point().y > lab.Heat.HEIGHT,
		"The reading moves up to the working height of a placement preview")
	_key(KEY_ESCAPE)
	var seat_before: Rect2 = lab.view.speaker_seat
	var bar_before: Rect2 = bar.get_global_rect()
	_press(lab, "Ask Speaker  [G]")
	await process_frame
	_check(lab.ask_panel.visible and "ember" in lab.ask_topics and not lab.speech.visible and
		lab.get_global_rect().encloses(lab.ask_panel.get_global_rect()) and
		not bar.get_global_rect().intersects(lab.ask_panel.get_global_rect()),
		"Ask Speaker opens a compact panel with an ember question")
	_check(lab.ask_panel.get_global_rect().position.y > lab.view.speaker_seat.end.y and
		lab.view.speaker_seat == seat_before and lab.tending_controls.visible and
		lab.get_global_rect().encloses(bar.get_global_rect()),
		"The question popup fits below the unchanged Speaker seat while controls stay available")
	if not out.is_empty():
		await _capture(out[0], "ask-speaker")
	var at: int = lab.ask_topics.find("ember")
	if at >= 0:
		await _select_last(lab.ask_picker, at + 1)
	await process_frame
	_check(not lab.ask_panel.visible and lab.speech.visible and "dry fibres" in lab.speech_text.text and
		not lab.speech.get_global_rect().intersects(bar.get_global_rect()) and
		lab.speech.get_global_rect().encloses(lab.speech_text.get_global_rect()),
		"The suggested question closes the panel and shows a readable in-world answer")
	_key(KEY_H)
	await process_frame
	_check(lab.history_panel.visible and "You asked" in lab.history_text.text and "dry fibres" in lab.history_text.text,
		"The question and answer can be reread in the dialogue history")
	_key(KEY_H)
	lab.trials.item_selected.emit(9)
	_key(KEY_G)
	await process_frame
	_check(lab.ask_panel.visible and "wet" in lab.ask_topics and "ember" not in lab.ask_topics,
		"Changing from One Ember to steaming wood offers a different set of questions")
	_click(lab.ask_entry.get_global_rect().get_center())
	var letter := InputEventKey.new()
	letter.keycode = KEY_G
	letter.unicode = "g".unicode_at(0)
	letter.pressed = true
	Input.parse_input_event(letter)
	Input.flush_buffered_events()
	_check(lab.ask_panel.visible and lab.ask_entry.text == "g", "Typing G in the field does not trigger the consult shortcut")
	lab.ask_entry.text = "Why so much somke?"
	_key(KEY_ENTER)
	await process_frame
	_check(not lab.ask_panel.visible and lab.speech.visible and "pale trail" in lab.speech_text.text,
		"Enter submits a rough freeform question and the answer uses the current hearth")
	if not out.is_empty():
		await _capture(out[0], "speaker-answer")
	_key(KEY_G)
	await process_frame
	_click(lab.ask_entry.get_global_rect().get_center())
	_key(KEY_ESCAPE)
	await process_frame
	_check(not lab.ask_panel.visible and not lab.ask_entry.has_focus() and
		lab.view.speaker_seat == seat_before and bar.get_global_rect() == bar_before,
		"Escape closes consultation, restores the fuel bar, and keeps the Speaker seated")
	_key(KEY_F4)
	await process_frame
	var heavy = lab.fire.add_fuel(2, Vector2.ZERO, 0.0, 0.0, 0, true)
	heavy.water = heavy.original * 0.5
	heavy.vapor = 0.002
	for exchange: Array in [
		["Will your leg heal?", "cannot promise"],
		["How did you learn to keep the fire?", "passed down"],
		["What happened to your legs?", "how it happened"],
		["How do I keep the fire alive?", "cold wood"],
		["Why?", "takes warmth"],
		["Show me.", "heavy piece"],
		["Did that help?", "cannot yet see a clear change"],
	]:
		var question: String = exchange[0]
		_key(KEY_G)
		await process_frame
		lab.ask_entry.text = question
		_click(lab.ask_entry.get_global_rect().get_center())
		_key(KEY_ENTER)
		await process_frame
		_check(not lab.ask_panel.visible and lab.speech.visible and
			exchange[1] in lab.speech_text.text and
			lab.speech.get_global_rect().encloses(lab.speech_text.get_global_rect()) and
			lab.speech_text.get_minimum_size().y <= lab.speech_text.size.y and lab.view.speaker_seat == seat_before,
			"Typed neural reply fits the unchanged Speaker layout: %s" % question)
	if not out.is_empty():
		await _capture(out[0], "neural-answer")

func _advance(lab: Control, seconds: float) -> void:
	lab._advance(seconds)
	while lab.jump_steps > 0:
		await process_frame
	await process_frame

func _capture(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join("firetender-%s.png" % name)
	var result := root.get_texture().get_image().save_png(path)
	_check(result == OK, "Captured %s frame" % name)

func _select_last(picker: OptionButton, index := -1) -> void:
	_click(picker.get_global_rect().get_center())
	await process_frame
	var popup := picker.get_popup()
	_check(popup.visible, "Opened the option menu")
	# Embedded popup keyboard routing depends on desktop focus. Exercise
	# the same selection signal that Godot dispatches on row activation.
	popup.index_pressed.emit(popup.item_count - 1 if index < 0 else index)
	popup.hide()
	await process_frame

func _scene_point(lab: Control, at: Vector2) -> Vector2:
	return lab.view.get_global_transform() * lab.view.screen_at(at)

func _press(lab: Control, title: String) -> void:
	for button: Button in lab.find_children("*", "Button", true, false):
		if button.text == title and button.is_visible_in_tree():
			_click(button.get_global_rect().get_center())
			return
	_check(false, "Found the visible %s button" % title)

func _key(code: Key, shift := false, ctrl := false) -> void:
	for down in [true, false]:
		_key_state(code, down, shift, ctrl)

func _key_state(code: Key, down: bool, shift := false, ctrl := false) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = down
	key.shift_pressed = shift
	key.ctrl_pressed = ctrl
	Input.parse_input_event(key)
	Input.flush_buffered_events()

func _mouse(button_down: bool, point: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = button_down
	click.position = root.get_stretch_transform() * point
	click.global_position = click.position
	Input.parse_input_event(click)
	Input.flush_buffered_events()

func _click(point: Vector2) -> void:
	_mouse(true, point)
	_mouse(false, point)

func _hover(point: Vector2, delta := Vector2.ZERO, buttons := 0) -> void:
	var motion := InputEventMouseMotion.new()
	var stretch := root.get_stretch_transform()
	motion.position = stretch * point
	motion.global_position = motion.position
	motion.relative = stretch.basis_xform(delta)
	motion.button_mask = buttons
	Input.parse_input_event(motion)
	Input.flush_buffered_events()

func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(true, from)
	await process_frame
	_hover(to, to - from, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_mouse(false, to)
	await process_frame

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)



