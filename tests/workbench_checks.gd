extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const Fire := preload("res://sim/fire.gd")
const View := preload("res://hearth/fire_view.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var lab := Lab.instantiate()
	lab.settings_path = "user://workbench-check-%d.cfg" % OS.get_process_id()
	root.add_child(lab)
	await process_frame
	var captures := OS.get_cmdline_user_args()
	_key(KEY_F4)
	await process_frame
	_check(lab.view.workbench.visible and lab.paused and lab.fire.coals.size() == 1 and lab.mentor.ember_training,
		"F4 opens a paused 3D One Ember practice")
	_check(lab.view.get_global_rect().is_equal_approx(lab.get_global_rect()) and
		lab.view.workbench.stage.size == Vector2i(lab.size.round()),
		"The 3D scene renders to all four edges at the current aspect ratio")
	_check_speech(lab)
	var center: Vector2 = lab.view.position + lab.view.screen_at(Vector2.ZERO)
	_check(lab.view.workbench.hit(center - lab.view.position).ground.length() < 0.001, "Camera projection and picking agree on the ember")
	if not captures.is_empty():
		await _capture(captures[0], "ember")
	var yaw: float = lab.view.workbench.yaw
	var tilt: float = lab.view.workbench.tilt
	await _drag(center, center + Vector2(94, 38), MOUSE_BUTTON_RIGHT)
	_check(absf(lab.view.workbench.yaw - yaw) > 0.4 and absf(lab.view.workbench.tilt - tilt) > 0.10,
		"Right drag changes azimuth and elevation")
	var zoom: float = lab.view.workbench.zoom
	_mouse(true, center, MOUSE_BUTTON_WHEEL_UP)
	_mouse(false, center, MOUSE_BUTTON_WHEEL_UP)
	await create_timer(0.24).timeout
	_check(lab.view.workbench.zoom < zoom, "The wheel zooms in the 3D view")
	_key(KEY_HOME)
	_check(is_equal_approx(lab.view.workbench.yaw, yaw) and is_equal_approx(lab.view.workbench.zoom, zoom),
		"Home restores the camera")
	_key(KEY_N)
	_check(not lab.view.snapping, "N disables optional contact snapping")
	_key(KEY_N)

	_key(KEY_M)
	await process_frame
	_check(lab.palette.visible, "The fuel tray opens")
	_click(_button_center(lab.palette, "Bark fibres  [5]"))
	await process_frame
	_hover(center)
	await process_frame
	_check(lab.view.placing == 4 and lab.view.drop_pose != null and lab.view.drop_pose.at.length() < 0.03,
		"Choosing bark fibres yields a world-space preview on the ember")
	if not captures.is_empty():
		await _capture(captures[0], "preview")
	_click(center)
	await process_frame
	_check(lab.fire.wood.size() == 1 and lab.fire.wood[0].kind == 4 and lab.fire.wood[0].precise,
		"Clicking places fine tinder into the live spatial model")
	for i in range(2):
		_click(_button_center(lab.workbench_tools, "+2 seconds"))
		await process_frame
		while lab.jump_steps > 0:
			await process_frame
	_check(lab.paused and lab.fire.time == 4.0 and lab.fire.total_flame() > 6.0,
		"Two-second controls let the player kindle a live flame while the workbench is paused")
	if not captures.is_empty():
		await _capture(captures[0], "first-flame")

	_click(lab.trials.get_global_rect().get_center())
	await process_frame
	var popup: PopupMenu = lab.trials.get_popup()
	_check(popup.visible, "The experiment menu opens beside the workbench")
	popup.index_pressed.emit(Fire.CABIN + 1)
	popup.hide()
	await process_frame
	var bridge: Fire.Piece = lab.fire.wood[4]
	_check(bridge.pose.supports.size() == 2 and lab.view.workbench.logs.size() == lab.fire.wood.size(),
		"The cabin preset shows the same supports in the renderer and the model")
	if not captures.is_empty():
		await _capture(captures[0], "cabin")
	var from: Vector2 = lab.view.position + lab.view._project(bridge.pose.point(0.0))
	var ground: Vector2 = lab.view.position + lab.view.screen_at(Vector2(-0.63, 0.12))
	var before := bridge.wood
	await _drag(from, ground, MOUSE_BUTTON_LEFT)
	_check(bridge.at.x < -0.5 and bridge.wood == before and bridge.height < 0.12,
		"Dragging an elevated rail picks the visible piece and lowers it to the ground intact")
	_click(lab.trials.get_global_rect().get_center())
	await process_frame
	popup.index_pressed.emit(Fire.COLD + 1)
	popup.hide()
	await process_frame
	for side in [-1, 1]:
		_place_rail(lab, Vector2(0.0, side * 0.20), 0.0)
	for side in [-1, 1]:
		_place_rail(lab, Vector2(side * 0.175, 0.0), PI * 0.5)
	await process_frame
	var build_ok: bool = lab.fire.wood.size() == 4
	if build_ok:
		for i in [2, 3]:
			var rail: Fire.Piece = lab.fire.wood[i]
			build_ok = build_ok and lab.fire.wood[0].id in rail.pose.supports and lab.fire.wood[1].id in rail.pose.supports
	_check(build_ok, "Four hand-placed rails form a cabin course supported at both crossings")
	if not captures.is_empty():
		await _capture(captures[0], "built-cabin")
	await _action_bar(lab)
	await _move_focus(lab)
	await _keyboard_camera(lab)
	await _heat_experiment(lab)
	await _grain_experiment(lab)
	await _break_experiment(lab, captures)
	await _keeping_tools(lab, captures)
	if not captures.is_empty():
		await _capture(captures[0], "focused-action-bar")
	await _all_experiments(lab)
	await _accelerated_view(lab)
	print("Phase 1.5.1 workbench: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _all_experiments(lab: Control) -> void:
	var bench = lab.view.workbench
	if not lab.paused:
		lab._pause()
	await process_frame
	await process_frame
	for scenario in range(Fire.SCENARIOS.size()):
		bench.orbit(Vector2(52, 21))
		lab.view.select_material(4)
		lab.debug.show()
		lab.fire.weather = 3
		lab.fire.send_breath(Vector2(0, 0.5), Vector2.ZERO, 0.84, 1.0)
		lab.fire.structure_event.emit("fall", Vector2.ZERO, 0.01, 0.23, 650.0)
		lab.trials.item_selected.emit(scenario + 1)
		await process_frame
		var model := Fire.new(scenario)
		var matches: bool = (lab.fire.time == model.time and lab.fire.wood.size() == model.wood.size() and
			lab.fire.coal_reserve() == model.coal_reserve() and lab.fire.total_flame() == model.total_flame())
		for piece: Fire.Piece in lab.fire.wood:
			matches = matches and bench.logs.has(piece.get_instance_id()) and bench.collisions.has(piece.get_instance_id())
		for piece: Fire.Piece in lab.fire.coals:
			matches = matches and bench.beds.has(piece.get_instance_id())
		var sources := {}
		for piece: Fire.Piece in lab.fire.thermal_sources():
			sources[piece.get_instance_id()] = true
		for key in bench.plumes:
			matches = matches and sources.has(key)
		_check(matches and bench.visible and bench.camera.is_current() and
			bench.logs.size() == lab.fire.wood.size() and bench.collisions.size() == lab.fire.wood.size() and
			bench.beds.size() == lab.fire.coals.size() and bench.debris.is_empty() and
			bench.eye.is_equal_approx(bench.BENCH_EYE) and bench.zoom == bench.BENCH_FOV and
			(-bench.camera.basis.z).dot((bench.HEARTH_FOCUS - bench.eye).normalized()) > 0.99999 and
			lab.view.placing == -1 and lab.view.drop_pose == null and
			lab.fire.weather == 0 and lab.fire.breaths.is_empty() and
			not lab.debug.visible and lab.mentor.ember_training == (scenario == Fire.ONE_EMBER),
			"Experiment has a fresh 3D scene · %s" % Fire.SCENARIOS[scenario])

func _accelerated_view(lab: Control) -> void:
	var bench = lab.view.workbench
	var stage: SubViewport = bench.stage
	var full_size := stage.size
	var model := Fire.new(Fire.GRAIN_CABIN)
	lab.trials.item_selected.emit(Fire.GRAIN_CABIN + 1)
	var starting_tick: float = lab.fire.time
	bench.set_acceleration(64)
	lab.fire.structure_event.emit("fall", Vector2.ZERO, 0.01, 0.23, 650.0)
	_check(stage.size.x < full_size.x and stage.render_target_update_mode == SubViewport.UPDATE_ONCE and
		bench.debris.is_empty(), "Fast-forward draws at a reduced cadence and skips transient visual coal bodies")
	lab._advance(18.0)
	while lab.jump_steps > 0:
		await process_frame
	for tick in range(int(18.0 / Fire.STEP)):
		model.step()
	await process_frame
	_check(lab.fire.time == starting_tick + 18.0 and lab.fire.coal_reserve() == model.coal_reserve() and
		lab.fire.total_flame() == model.total_flame() and stage.size == full_size and
		stage.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"A rendered time jump matches the headless fixed steps and restores full-rate drawing")

func _action_bar(lab: Control) -> void:
	_key(KEY_F4)
	await process_frame
	var expected := [[4, 5], [0, 1], [6, 7], [8, 11, 12, 13], [9, 2, 10], [3]]
	var keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_U, KEY_J, KEY_K]
	for group in range(expected.size()):
		_click(lab.group_buttons[group].get_global_rect().get_center())
		var visible: Array[int] = []
		for kind in range(lab.fuel_buttons.size()):
			var button: Button = lab.fuel_buttons[kind]
			if button.visible:
				visible.append(kind)
		var kinds: Array = expected[group]
		_check(lab.group_buttons[group].button_pressed and visible.size() == kinds.size() and
			kinds.all(func(kind): return kind in visible), "Category %d shows the intended materials" % group)
		for kind: int in kinds:
			var button: Button = lab.fuel_buttons[kind]
			_click(button.get_global_rect().get_center())
			_check(lab.view.placing == kind and button.button_pressed and button.icon != null and
				button.tooltip_text.begins_with(Fire.SPECIES[kind].label), "Selects the illustrated %s slot" % Fire.SPECIES[kind].label)
			_key(KEY_ESCAPE)
			_key(keys[kind])
			_check(lab.view.placing == kind and button.button_pressed, "Shortcut selects %s" % Fire.SPECIES[kind].label)
			_key(KEY_ESCAPE)
	_key(KEY_B)
	_key(KEY_TAB)
	_check(lab.view.placing == 3 and lab.view.tool == View.Tool.WOOD, "Tab recalls the most recent fuel from a tool")
	_key(KEY_TAB)
	_check(lab.view.placing == -1 and lab.view.tool == View.Tool.BREATH, "Tab restores the previous tool")
	_key(KEY_ESCAPE)

func _check_speech(lab: Control) -> void:
	var speech: Control = lab.speech
	var text_label: Label = lab.speech_text
	var bar: Control = lab.fuel_buttons[3].get_parent()
	_check(speech.visible and text_label.visible and not text_label.text.is_empty() and
		speech.get_global_rect().encloses(text_label.get_global_rect()) and
		not speech.get_global_rect().intersects(bar.get_global_rect()) and lab.get_global_rect().encloses(bar.get_global_rect()),
		"The action bar fits on screen and leaves the visible Fire Speaker text clear")

func _heat_experiment(lab: Control) -> void:
	_click(lab.trials.get_global_rect().get_center())
	await process_frame
	var popup: PopupMenu = lab.trials.get_popup()
	_check(popup.item_count > Fire.HEAT_GAP + 1 and popup.get_item_text(Fire.HEAT_GAP + 1).contains("Oak over a hot bed"),
		"The radiant-gap experiment is offered by the playable menu")
	popup.index_pressed.emit(Fire.HEAT_GAP + 1)
	popup.hide()
	await process_frame
	_check(lab.paused and lab.fire.coals.size() == 6 and lab.fire.wood.size() == 3,
		"The radiant-gap setup opens paused with the same coals and raised oak as the model test")
	var target: Fire.Piece = lab.fire.wood.back()
	_click(lab.view.position + lab.view._project(target.pose.point(0.0)))
	_click(_button_center(lab.workbench_tools, "+2 seconds"))
	while lab.jump_steps > 0:
		await process_frame
	_key(KEY_F3)
	await process_frame
	_check(lab.debug.visible and "Local heat ledger" in lab.report.text and "radiation +" in lab.report.text,
		"Developer readings show the selected piece's heat ledger")
	_key(KEY_F3, true)
	await process_frame
	_check(lab.view.thermal_overlay and not lab.debug.visible, "Shift+F3 reveals the local 3D heat overlay")
	_key(KEY_F3, true)

func _grain_experiment(lab: Control) -> void:
	var popup: PopupMenu = lab.trials.get_popup()
	_check(popup.get_item_text(Fire.GRAIN_END + 1).contains("burns from one end") and
		popup.get_item_text(Fire.GRAIN_CABIN + 1).contains("cabin settles"), "Both grain demonstrations are offered")
	popup.index_pressed.emit(Fire.GRAIN_END + 1)
	await process_frame
	var timber: Fire.Piece = lab.fire.wood.back()
	var bench = lab.view.workbench
	_check(lab.paused and timber.kind == 10 and bench.logs[timber.get_instance_id()].size() == 4,
		"The end-burn demonstration loads four individually rendered regions")
	for tick in range(160):
		lab.fire.step()
	await process_frame
	await process_frame
	var segments: Array = bench.logs[timber.get_instance_id()]
	_check(segments[0].transform.basis.get_scale().y < segments[3].transform.basis.get_scale().y * 0.94,
		"The rendered end shrinks locally while the far section keeps its thickness")
	_check(segments[0].mesh.get_surface_count() == 3 and segments[1].mesh.get_surface_count() == 2 and
		segments[2].mesh.get_surface_count() == 2 and segments[3].mesh.get_surface_count() == 3 and
		_shared_wood_joint(segments[0], segments[1]), "Worn grain regions share a continuous skin with caps only at the ends")
	_check(bench.collisions[timber.get_instance_id()] is AnimatableBody3D,
		"The wood provides one simplified 3D collision proxy")
	lab._speed_changed(2)
	lab._pause()
	await process_frame
	await process_frame
	var projected: Vector2 = bench.project(Vector3(0.24, -0.15, 0.0))
	_check(bench.stage.size.x < lab.size.x and bench.hit(projected).ground.distance_to(Vector2(0.24, -0.15)) < 0.001,
		"Fast-forward reduces viewport work while preserving ray placement")

func _shared_wood_joint(left: MeshInstance3D, right: MeshInstance3D) -> bool:
	var a: PackedVector3Array = left.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var b: PackedVector3Array = right.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var left_pose: Transform3D = left.get_meta("rest_pose")
	var right_pose: Transform3D = right.get_meta("rest_pose")
	var matched := 0
	for point in a:
		if not is_equal_approx(point.x, 0.5):
			continue
		var join := left_pose * point
		var found := false
		for opposite in b:
			if is_equal_approx(opposite.x, -0.5) and join.distance_to(right_pose * opposite) < 0.0001:
				found = true
				break
		if not found:
			return false
		matched += 1
	return matched >= 6

func _break_experiment(lab: Control, captures: PackedStringArray) -> void:
	lab.trials.item_selected.emit(Fire.GRAIN_BREAK + 1)
	await process_frame
	var timber: Fire.Piece = lab.fire.wood.back()
	while not timber.split_end and lab.fire.time < 120.0:
		lab.fire.step()
	var other: Fire.Piece = lab.fire.wood.back()
	_check(other != timber and timber.split_end and other.split_start and timber.wood > 0.05 and other.wood > 0.05,
		"The burning bridge divides into two substantial pieces through combustion")
	if other == timber:
		return
	var starting_height := timber.height + other.height
	var in_air := timber.airborne or other.airborne
	var bench = lab.view.workbench
	await process_frame
	await process_frame
	var rim: MeshInstance3D = bench.logs[timber.get_instance_id()].back()
	var exposed: PackedVector3Array = rim.mesh.surface_get_arrays(2)[Mesh.ARRAY_VERTEX]
	var depth := Vector2(1, -1)
	for point in exposed:
		if point.x > 0.0:
			depth = Vector2(minf(depth.x, point.x), maxf(depth.y, point.x))
	_check(depth.y - depth.x > 0.12, "The new cap has a recessed, uneven fracture surface")
	for tick in range(4):
		lab.fire.step()
	await process_frame
	_check(in_air and not timber.airborne and not other.airborne and timber.height + other.height < starting_height - 0.03,
		"The two visible halves fall and independently find support")
	if not captures.is_empty():
		await _capture(captures[0], "split-bridge")

func _move_focus(lab: Control) -> void:
	var bench = lab.view.workbench
	_key(KEY_HOME)
	var revision: int = lab.fire.revision
	var target := Vector2(0.61, 0.32)
	var point: Vector2 = lab.view.position + lab.view.screen_at(target)
	_hover(point)
	_mouse(true, point, MOUSE_BUTTON_WHEEL_UP)
	await create_timer(0.65).timeout
	var zoom: float = bench.zoom
	var yaw: float = bench.yaw
	var tilt: float = bench.tilt
	point = lab.view.position + lab.view.screen_at(target)
	_hover(point)
	_key(KEY_F)
	await create_timer(0.50).timeout
	var center: Vector2 = lab.view.position + lab.view.size * 0.5
	_check(lab.view.screen_at(target).distance_to(lab.view.size * 0.5) < 1.5 and
		bench.focus.distance_to(Vector3(target.x, 0, target.y)) < 0.004 and
		bench.yaw == yaw and bench.tilt == tilt and bench.zoom == zoom,
		"F shifts the orbit center to the cursor ground at the same angle and zoom")
	var eye: Vector3 = bench.eye
	await _drag(center, center + Vector2(-18, 12), MOUSE_BUTTON_RIGHT)
	_check(bench.eye.distance_to(eye) > 0.10 and lab.view.screen_at(target).distance_to(lab.view.size * 0.5) < 1.5,
		"Right drag swings the camera around the adjusted focus")
	eye = bench.eye
	await _drag(center, center + Vector2(65, 12), MOUSE_BUTTON_MIDDLE)
	_check(bench.eye.distance_to(eye) > 0.10 and bench.eye.y == eye.y and
		lab.fire.revision == revision, "Middle drag pans horizontally without moving or altering fuel")
	if lab.view.snapping:
		_key(KEY_N)
	_key(KEY_8)
	var placement := Vector2(0.58, 0.43)
	point = lab.view.position + lab.view.screen_at(placement)
	_hover(point)
	_check(lab.view.drop_pose != null and lab.view.drop_pose.at.distance_to(placement) < 0.004,
		"The live preview hits the intended ground after panning, orbiting and zooming")
	_click(point)
	if lab.fire.wood.is_empty():
		_check(false, "The click places the exact mapped material at the preview")
		return
	var piece: Fire.Piece = lab.fire.wood.back()
	_check(piece.kind == 7 and piece.at.distance_to(placement) < 0.004, "The click places the exact mapped material at the preview")
	point = lab.view.position + lab.view._project(piece.pose.point(0.0))
	_click(point)
	_key(KEY_F)
	await create_timer(0.50).timeout
	_check(lab.view.selected == piece and lab.view._project(piece.pose.point(0.0)).distance_to(lab.view.size * 0.5) < 1.5,
		"F recenters on the ray-picked fuel near the edge")
	_key(KEY_HOME)
	_check(bench.eye.is_equal_approx(bench.BENCH_EYE) and piece.at.distance_to(placement) < 0.004,
		"Home resets the full-hearth view while preserving the placement")
	var time: float = lab.fire.time
	_key(KEY_SPACE)
	_hover(lab.view.position + lab.view.screen_at(Vector2(-0.4, 0.24)))
	_key(KEY_F)
	await create_timer(0.60).timeout
	_check(lab.fire.time > time and piece.at.distance_to(placement) < 0.004,
		"The simulation keeps stepping while the camera changes")

func _keyboard_camera(lab: Control) -> void:
	if not lab.paused:
		_key(KEY_SPACE)
	_key(KEY_HOME)
	var bench = lab.view.workbench
	bench.orbit(Vector2(70, 0))
	var start: Vector3 = bench.eye
	var yaw: float = bench.yaw
	var revision: int = lab.fire.revision
	for pair in [[KEY_W, Vector3.FORWARD], [KEY_A, Vector3.LEFT], [KEY_S, Vector3.BACK], [KEY_D, Vector3.RIGHT]]:
		var before: Vector3 = bench.eye
		_key_state(pair[0], true)
		await create_timer(0.12).timeout
		_key_state(pair[0], false)
		var movement: Vector3 = bench.eye - before
		_check(movement.length() > 0.06 and movement.normalized().dot(pair[1].rotated(Vector3.UP, yaw)) > 0.999,
			"%s pans horizontally relative to the camera angle" % OS.get_keycode_string(pair[0]))
	var released: Vector3 = bench.eye
	await create_timer(0.10).timeout
	_check(bench.eye == released and bench.eye.y == start.y and lab.fire.revision == revision,
		"Releasing the movement keys stops the camera without altering the paused hearth")
	lab._toggle_settings()
	_key_state(KEY_W, true)
	await create_timer(0.12).timeout
	_key_state(KEY_W, false)
	_check(bench.eye == released, "Settings takes priority over the movement keys")
	lab._toggle_settings()

func _capture(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join("firetender-13-%s.png" % name)
	_check(root.get_texture().get_image().save_png(path) == OK, "Captured the %s view" % name)

func _place_rail(lab: Control, at: Vector2, yaw: float) -> void:
	_key(KEY_0)
	var current: float = lab.fire.default_yaw(lab.fire.next_id)
	var turns := roundi(angle_difference(current, yaw) / (PI / 12.0))
	for i in range(absi(turns)):
		_key(KEY_E if turns > 0 else KEY_Q)
	var point: Vector2 = lab.view.position + lab.view.screen_at(at)
	_hover(point)
	_click(point)

func _button_center(container: Control, title: String) -> Vector2:
	for button: Button in container.find_children("*", "Button", true, false):
		if button.text == title:
			return button.get_global_rect().get_center()
	_check(false, "Found the %s button" % title)
	return Vector2.ZERO

func _key(code: Key, shift := false, ctrl := false) -> void:
	_key_state(code, true, shift, ctrl)
	_key_state(code, false, shift, ctrl)

func _key_state(code: Key, down: bool, shift := false, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _keeping_tools(lab: Control, captures: PackedStringArray) -> void:
	lab.trials.item_selected.emit(Fire.CARRY_EMBER + 1)
	await process_frame
	var coal: Fire.Piece = lab.fire.coals[0]
	var state := [coal.char_mass, coal.temperature, coal.stored_heat(lab.fire.ambient())]
	_key(KEY_C)
	var from: Vector2 = lab.view._project(Vector3(coal.at.x, coal.at.y, coal.height + 0.016))
	var destination: Vector2 = lab.view.screen_at(Vector2(0.12, 0.0))
	await _drag(from, destination, MOUSE_BUTTON_LEFT)
	_check(lab.fire.coals[0] == coal and coal.at.distance_to(Vector2(0.12, 0)) < 0.003 and not coal.carried and
		state == [coal.char_mass, coal.temperature, coal.stored_heat(lab.fire.ambient())],
		"C lifts and deposits the same physical ember into the prepared nest")
	if not captures.is_empty():
		await _capture(captures[0], "carried-ember")
	_key(KEY_B)
	var peak_flame := 0.0
	for pulse in range(12):
		var origin: Vector2 = lab.view.screen_at(Vector2(0.12, 0.45))
		_mouse(true, origin, MOUSE_BUTTON_LEFT)
		_hover(destination, destination - origin, MOUSE_BUTTON_MASK_LEFT)
		await create_timer(0.6).timeout
		_mouse(false, destination, MOUSE_BUTTON_LEFT)
		lab._advance(2.5)
		while lab.jump_steps > 0:
			await process_frame
		peak_flame = maxf(peak_flame, lab.fire.total_flame())
		if peak_flame > 3.0:
			break
	_check(lab.fire.wood.any(func(piece): return piece.charred_wood > 0.0008) and peak_flame > 3.0,
		"The player's directed breaths nurse the deposited ember and fibres into flame")
	if not captures.is_empty():
		await _capture(captures[0], "nursed-nest")
	lab.trials.item_selected.emit(Fire.FEED_FIRE + 1)
	await process_frame
	var bench = lab.view.workbench
	var center: Vector2 = lab.view.size * 0.5
	await _drag(center, center + Vector2(0.0, 174.0), MOUSE_BUTTON_MIDDLE, true)
	_check(bench.eye.y < 0.30, "Shift-middle-drag lowers the same camera for work below the roof")
	bench.orbit(Vector2(-143.0, 0.0))
	bench.focus_on(Vector3(0.18, 0.055, 0.0))
	await create_timer(0.50).timeout
	var count: int = lab.fire.wood.size()
	_key(KEY_X)
	_key(KEY_8)
	_hover(lab.view.screen_at(Vector2(0.58, 0.0)))
	var yaw: float = lab.view.build_yaw if not is_inf(lab.view.build_yaw) else lab.fire.default_yaw(lab.fire.next_id)
	var turns := roundi(angle_difference(yaw, PI) / (PI / 12.0))
	for i in range(absi(turns)):
		_key(KEY_E if turns > 0 else KEY_Q)
	_key(KEY_E, false, true)
	_key(KEY_E, false, true)
	for i in range(24):
		_key(KEY_UP)
	_check(lab.view.tool == View.Tool.FEED and lab.view.drop_pose != null and not lab.view.feed_blocked and
		lab.view.drop_pose.height < 0.08, "X and the arrow keys preview a thin stick sliding below the roof")
	if not captures.is_empty():
		await _capture(captures[0], "feeding-preview")
	_click(lab.view.pointer)
	await process_frame
	var stick: Fire.Piece = lab.fire.wood.back()
	_check(lab.fire.wood.size() == count + 1 and stick.fed and stick.sections.size() == 3 and
		stick.height < 0.08, "The feed preview commits to the same low physical rest")
	_key(KEY_ESCAPE)
	_key(KEY_X)
	_click(lab.view._project(stick.pose.point(0.0)))
	_check(lab.view.selected == stick and lab.view.workbench.tilt < 0.45,
		"The low camera picks the inserted stick through the opening instead of the roof")
	var at := stick.at
	_key(KEY_DOWN)
	_check(stick.at.distance_to(at) > 0.015 and lab.view.selected == stick,
		"The inserted stick can be selected and withdrawn along its axis")

func _mouse(down: bool, point: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = root.get_stretch_transform() * point
	event.global_position = event.position
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _click(point: Vector2) -> void:
	_mouse(true, point, MOUSE_BUTTON_LEFT)
	_mouse(false, point, MOUSE_BUTTON_LEFT)

func _hover(point: Vector2, delta := Vector2.ZERO, buttons := 0, shift := false) -> void:
	var event := InputEventMouseMotion.new()
	var stretch := root.get_stretch_transform()
	event.position = stretch * point
	event.global_position = event.position
	event.relative = stretch.basis_xform(delta)
	event.button_mask = buttons
	event.shift_pressed = shift
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _drag(from: Vector2, to: Vector2, button: MouseButton, shift := false) -> void:
	_mouse(true, from, button)
	await process_frame
	var mask := {MOUSE_BUTTON_LEFT: MOUSE_BUTTON_MASK_LEFT, MOUSE_BUTTON_RIGHT: MOUSE_BUTTON_MASK_RIGHT,
		MOUSE_BUTTON_MIDDLE: MOUSE_BUTTON_MASK_MIDDLE}
	_hover(to, to - from, mask[button], shift)
	await process_frame
	_mouse(false, to, button)
	await process_frame

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
