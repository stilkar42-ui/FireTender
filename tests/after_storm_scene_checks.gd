extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const Fire := preload("res://sim/fire.gd")
const Chapter := preload("res://sim/red_hollow.gd")
var lab: Control
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-after-storm-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	var fire: Fire = lab.fire
	var view = lab.view
	var bench = view.workbench
	var old_coal := fire.coals[0]
	lab.mentor.story_line("I remember the coal we brought home.", "continuity_fixture")
	fire.time = Chapter.Shelter.END
	lab.chapter.outcome = "kept"
	await process_frame
	_check(lab.story_menu.results_continue.is_visible_in_tree(), "A successful Chapter I exposes the results and continuation")
	_click(lab.story_menu.results_continue.get_global_rect().get_center())
	await process_frame
	_check(lab.chapter.sequel != null and fire.coals[0] == old_coal and
		"I remember the coal we brought home." in lab.mentor.history,
		"Continuing opens Chapter II on the same model and retains earlier dialogue")
	_click(lab.story_menu.chapter_button.get_global_rect().get_center())
	_key(KEY_F7)
	await process_frame
	_check(lab.paused and fire.time == Chapter.Shelter.END and lab.chapter.sequel != null and
		lab.site_picker.item_count == lab.shelter_area_start + lab.SHELTER_AREAS.size() and
		lab.site_picker.is_item_disabled(0) and bench.cave.interior.is_visible_in_tree() and
		bench.exterior.background.is_visible_in_tree(), "F7 opens the reproducible chapter with the connected cave and painted exterior")
	_check(lab.speech.visible and lab.speech.get_global_rect().encloses(lab.speech_text.get_global_rect()) and
		not lab.speech.get_global_rect().intersects(lab.fuel_bar.get_global_rect()) and
		lab.speech_text.get_minimum_size().y <= lab.speech_text.size.y and lab.speech_text.text.contains("Watch for scorching"),
		"The opening drying lesson fits the Fire Speaker overlay")
	await _capture("opening")
	lab._switch_fuel_group(5)
	var wet := fire.stock_piece(12, true)
	_click(lab.wet_buttons[12].get_global_rect().get_center())
	_check(view.placing_piece == wet and wet.core != null, "The Wet wood tab chooses the actual wet birch branch")
	lab.site_picker.item_selected.emit(lab.shelter_area_start + 1)
	await create_timer(0.60).timeout
	var position := Vector2(-1.89, -3.19)
	var projected: Vector2 = view.screen_at(position)
	_move_pointer(projected)
	_check(view.drop_pose != null and view.drop_pose.at.distance_to(position) < 0.018 and
		bench.focus.z < -3.0, "The deep dry shelf can be focused and accepts a supported fuel preview")
	var old_water := wet.water
	_click(projected)
	await process_frame
	_check(wet.at.distance_to(position) < 0.018 and wet.water == old_water and fire.has_fuel(wet),
		"Placing fuel in the new shelf preserves the original object and moisture")
	var from: Vector2 = view._project(wet.pose.point(0.0))
	var to := Vector2(-1.83, -2.40)
	var screen: Vector2 = view.screen_at(to)
	_mouse(from, true)
	_move_pointer(screen, MOUSE_BUTTON_MASK_LEFT)
	_mouse(screen, false)
	_check(wet.at.distance_to(to) < 0.08 and fire.has_fuel(wet) and wet.water == old_water,
		"The same piece can be dragged from the dry shelf into the alcove")
	lab.site_picker.item_selected.emit(lab.shelter_area_start + 4)
	await create_timer(0.55).timeout
	bench.orbit(Vector2(PI / bench.ORBIT_SPEED, 0.0))
	await _capture("deep-interior")
	_key(KEY_G)
	lab.ask_entry.text = "Who were Aru and Varek?"
	lab.ask_entry.text_submitted.emit(lab.ask_entry.text)
	await process_frame
	_check(lab.mentor.text.contains("Keeping Hand") and lab.mentor.text.contains("Seeking Hand"),
		"The normal question box answers about the twins")
	_key(KEY_H)
	lab.tale_button.pressed.emit()
	await process_frame
	_check(lab.history_text.text.contains("Chasm of the Cloud") and lab.history_text.text.contains("cave hyena") and
		lab.history_text.text.contains("charred wood") and not lab.history_text.scroll_following,
		"Read the tale opens the whole myth as a scrollable collection")
	await _capture("tale")
	_key(KEY_H)
	_key(KEY_HOME)
	var source := fire.stock_piece(11, true)
	fire.pose_fuel(source, Vector2(0.12, 0.04), 0.1, 0.0, 0, true)
	var face := source.sections[1].faces[0]
	face.temperature = 650.0
	face.char_mass = 0.004
	fire._eject_spark(face, 0.18)
	fire._advance_sparks(0.12, fire.ambient())
	fire.revision += 1
	bench._refresh(0.0)
	_check(not fire.sparks.is_empty() and bench.spark_lines.mesh.get_surface_count() == 1,
		"The 3D workbench renders the actual airborne ember as a distinct cinder")
	await _capture("spark")
	_key(KEY_F4)
	await process_frame
	_check(lab.chapter == null and fire.sparks.is_empty() and not bench.cave.is_visible_in_tree(),
		"One Ember clears Chapter II scenery and live spark state")
	_key(KEY_F1)
	await process_frame
	_check(lab.chapter.sequel == null and not lab.site_picker.is_item_disabled(0) and bench.cave.interior.is_visible_in_tree(),
		"Chapter I replay restores the opening choices in the shared expanded cave")
	print("After the storm scene: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _capture(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	await RenderingServer.frame_post_draw
	var file := args[0].path_join("phase23-" + name + ".png")
	_check(root.get_texture().get_image().save_png(file) == OK, "Captured " + name)

func _key(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()

func _move_pointer(point: Vector2, mask := 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_stretch_transform() * point
	motion.global_position = motion.position
	motion.button_mask = mask
	Input.parse_input_event(motion)
	Input.flush_buffered_events()

func _mouse(point: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.position = root.get_stretch_transform() * point
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	Input.parse_input_event(click)
	Input.flush_buffered_events()

func _click(point: Vector2) -> void:
	_mouse(point, true)
	_mouse(point, false)

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
