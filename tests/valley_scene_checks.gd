extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const Shelter := preload("res://sim/red_hollow_shelter.gd")

var passed := 0
var failed := 0
var lab: Control
var directory: PackedStringArray

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = OS.get_cmdline_user_args()
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-valley-check-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	await RenderingServer.frame_post_draw
	var view = lab.view
	var bench = view.workbench
	var camera: Camera3D = bench.camera
	var exterior = bench.exterior
	var fuel = lab.fire.stock_piece(5)
	var fuel_at: Vector2 = fuel.at
	var home: Transform3D = camera.transform
	_check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE and bench.mood.background_mode == Environment.BG_SKY and
		view.screen_at(Vector2.ZERO).distance_to(lab.size * 0.5) < lab.size.x * 0.15,
		"Red Hollow opens at eye level facing the hearth, with the native sky already present")
	_check(exterior.get_parent() == bench.cave and exterior.background.get_parent() == exterior and
		exterior.midground.get_parent() == exterior and bench.floor_node.mesh == bench.ledge,
		"Limestone, painted foreground and the continuous horizon share world space")
	_check(bench.ground_set.is_visible_in_tree() and
		bench.ground_set.get_node("LimestoneShelf").mesh.get_aabb().end.z > 8.0 and
		bench.ground_set.get_node("PinesAndScrub").mesh.get_aabb().size.y > 3.0,
		"The real limestone shelf carries trees and scrub beyond the playable fire bed")
	_check_layout()
	await _capture("hearth-daylight")

	var wall: Transform3D = bench.cave.global_transform
	var horizon: Transform3D = exterior.background.global_transform
	var foreground: Transform3D = exterior.midground.global_transform
	var nearby: Vector2 = view.screen_at(Vector2(0.10, 0.17))
	var distant: Vector2 = camera.unproject_position(exterior.to_global(Vector3(0.0, -3.20, 9.0)))
	bench.pan_direction(Vector2.RIGHT, 0.29)
	var near_shift: Vector2 = view.screen_at(Vector2(0.10, 0.17)) - nearby
	var far_shift: Vector2 = camera.unproject_position(exterior.to_global(Vector3(0.0, -3.20, 9.0))) - distant
	_check(near_shift.length() > far_shift.length() * 2.0 and bench.cave.global_transform == wall and
		exterior.background.global_transform == horizon and exterior.midground.global_transform == foreground,
		"Panning produces parallax while every scenery layer stays fixed")

	_key(KEY_HOME)
	_key_state(KEY_W, true)
	await create_timer(3.35).timeout
	_key_state(KEY_W, false)
	var at_mouth: Vector3 = camera.position
	_check(at_mouth.z > 2.70 and camera == bench.camera and camera.projection == Camera3D.PROJECTION_PERSPECTIVE and
		lab.fire.time == 0.0 and fuel.at == fuel_at,
		"W pans onto the exterior shelf without moving fuel or advancing paused time")
	_drag_look(Vector2(0.0, (0.18 - bench.tilt) / bench.TILT_SPEED))
	_drag_look(Vector2(PI / bench.ORBIT_SPEED, 0.0))
	var entrance: Vector3 = bench.cave.to_global(Vector3(-0.32, 1.42, 0.12))
	_check(camera.position.z > 5.2 and camera.is_position_in_frustum(entrance),
		"Orbiting on the outer shelf reveals the cave facade from outside")
	await _capture("cave-exterior")
	_drag_look(Vector2(-PI / bench.ORBIT_SPEED, (-0.06 - bench.tilt) / bench.TILT_SPEED))
	var sky_eye: Vector3 = camera.position
	var clear: Image = await _weather_frame(100.0, "mouth-daylight")
	if not directory.is_empty():
		_drag_look(Vector2(0.0, 0.40 / bench.TILT_SPEED))
		await _capture("shelf-valley")
		_drag_look(Vector2(0.0, -0.40 / bench.TILT_SPEED))
	var dusk: Image = await _weather_frame(270.0, "mouth-dusk")
	var night: Image = await _weather_frame(342.0, "mouth-night")
	var sky_point := Vector2(0.51, 0.34)
	_check(_pixel(clear, sky_point).get_luminance() > _pixel(night, sky_point).get_luminance() + 0.15,
		"The same world sky darkens from day to night")
	_check(_pixel(dusk, sky_point).r - _pixel(dusk, sky_point).b >
		_pixel(clear, sky_point).r - _pixel(clear, sky_point).b + 0.08,
		"The painted sky warms at dusk")
	_check(_sky_lights(night, Rect2(0.38, 0.08, 0.43, 0.57), 0.46) > 30,
		"The moon is visible at night above the valley")

	_drag_look(Vector2(0.0, -260.0))
	await RenderingServer.frame_post_draw
	var zenith: Image = bench.stage.get_texture().get_image()
	_check((-camera.basis.z).y > 0.995 and camera.position.is_equal_approx(sky_eye) and camera == bench.camera and
		camera.projection == Camera3D.PROJECTION_PERSPECTIVE and lab.fuel_bar.is_visible_in_tree() and
		_sky_lights(zenith, Rect2(0.10, 0.10, 0.80, 0.80), 0.19) > 45,
		"Right-drag reaches the stars overhead with the same camera, position and HUD")
	await _capture("zenith")
	lab._select_fuel(5)
	var center: Vector2 = view.size * 0.5
	var prior_revision: int = lab.fire.revision
	_mouse(center, MOUSE_BUTTON_LEFT, true)
	_mouse(center, MOUSE_BUTTON_LEFT, false)
	_check(not view.probe_valid and view.drop_pose == null and lab.fire.revision == prior_revision and fuel.at == fuel_at,
		"Pointing tools into the sky never picks or places a piece on the ground behind the camera")

	_drag_look(Vector2(0.0, (0.23 - bench.tilt) / bench.TILT_SPEED))
	var start_yaw: float = bench.yaw
	var center_focus: Vector3 = bench.focus
	var turned := true
	for step in range(1, 9):
		_drag_look(Vector2(PI * 0.25 / bench.ORBIT_SPEED, 0))
		var expected := wrapf(start_yaw - step * PI * 0.25, -PI, PI)
		turned = (turned and absf(angle_difference(bench.yaw, expected)) < 0.001 and
			bench.focus == center_focus and camera.unproject_position(center_focus).distance_to(lab.size * 0.5) < 1.5)
	_check(turned, "Right-drag orbits a full turn around the same focus")
	_key(KEY_HOME)
	_drag_look(Vector2(PI / bench.ORBIT_SPEED, (0.18 - bench.tilt) / bench.TILT_SPEED))
	_check(await _rock_blocks_sky(bench), "Solid rear limestone occludes the native sky")
	_key(KEY_HOME)
	bench.pan_direction(Vector2.UP, 3.35)
	_drag_look(Vector2(0.0, (-0.06 - bench.tilt) / bench.TILT_SPEED))
	await _weather_frame(620.0, "building-clouds")
	_check(lab.chapter.weather.watch() == Shelter.Watch.BUILDING and "Clouds gathering" in lab.chapter_weather.text,
		"The visible weather front advances with the existing chapter forecast")
	await _weather_frame(678.0, "rain-line")
	_check(exterior.sky_material.get_shader_parameter("rain_band") > 0.2 and not bench.rain_lines.visible,
		"Distant rain can appear before local rain enters the shelter")
	lab.fire.smoke_field.release(Vector3(0, 1.75, -0.55), 0.02, 0.4)
	var storm: Image = await _weather_frame(930.0, "storm")
	_check(_pixel(storm, sky_point).get_luminance() < _pixel(clear, sky_point).get_luminance() and
		bench.rain_lines.visible and bench.rain_lines.mesh.get_surface_count() > 0 and not bench.smoke_views.is_empty(),
		"Storm darkening, local rain and smoke follow the same weather model")

	_key(KEY_HOME)
	_check(camera.transform.is_equal_approx(home) and lab.fire.time == 930.0 and fuel.at == fuel_at,
		"Home restores the hearth framing without disturbing the current fire")
	_key(KEY_F4)
	await process_frame
	_check(camera == bench.camera and camera.projection == Camera3D.PROJECTION_PERSPECTIVE and
		bench.mood.background_mode == Environment.BG_COLOR and not exterior.is_visible_in_tree() and
		not bench.ground_set.is_visible_in_tree() and bench.floor_node.mesh == bench.floor_view,
		"The experiment reuses the same camera and clears the story scenery")
	await _check_swappable_scenery()
	print("Valley scene: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _check_layout() -> void:
	var view = lab.view
	var layout: Rect2 = view.get_global_rect()
	var scout: Rect2 = view.torch_seat
	var journal: Rect2 = lab.journal.get_global_rect()
	var button: Rect2 = lab.torch_button.get_global_rect()
	_check(layout.encloses(scout) and layout.encloses(journal) and layout.encloses(button) and
		not scout.intersects(journal) and not scout.intersects(button) and
		button.end.y >= layout.end.y - 25.0 and lab.heat_hand.get_global_rect().end.y >= layout.end.y - 22.0,
		"The Torch Bearer and hand retain their bottom-left positions")
	lab._toggle_ask()
	_check(lab.ask_panel.visible and not lab.hint.visible and
		layout.encloses(lab.fuel_bar.get_global_rect()) and not lab.fuel_bar.get_global_rect().intersects(lab.ask_panel.get_global_rect()),
		"Consultation leaves the question and fuel bar readable")
	lab._close_ask()

func _check_swappable_scenery() -> void:
	var set := Node3D.new()
	set.name = "AlternateSet"
	var packed := PackedScene.new()
	packed.pack(set)
	set.free()
	var fixture: Resource = lab.scenery.duplicate()
	fixture.set_scene = packed
	fixture.panorama_span = 360.0
	fixture.panorama = _swatch(Color("#294957"))
	fixture.foreground = _swatch(Color("#b88d52"))
	fixture.home_eye = Vector3(0.0, 1.30, -1.90)
	var alternate = Lab.instantiate()
	alternate.settings_path = lab.settings_path
	alternate.scenery = fixture
	root.add_child(alternate)
	await process_frame
	var bench = alternate.view.workbench
	_check(bench.cave.name == "AlternateSet" and bench.eye.is_equal_approx(fixture.home_eye) and
		bench.exterior.sky_material.get_shader_parameter("valley_paint") == fixture.panorama and
		bench.exterior.overhead_material.get_shader_parameter("valley_paint") == fixture.panorama and
		bench.exterior.mid_material.get_shader_parameter("slope_paint") == fixture.foreground and
		alternate.fire.coals.size() == 1 and alternate.fire.time == 0.0,
		"A second set, panorama and foreground load through the same scene and fire")
	alternate.queue_free()

func _swatch(color: Color) -> ImageTexture:
	var brush := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	brush.fill(color)
	return ImageTexture.create_from_image(brush)

func _weather_frame(time: float, title: String) -> Image:
	lab.fire.time = time
	lab.chapter.weather.sample(time)
	lab.view.workbench._refresh(0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = lab.view.workbench.stage.get_texture().get_image()
	await _capture(title)
	return frame

func _rock_blocks_sky(bench: Control) -> bool:
	var shader := Shader.new()
	shader.code = "shader_type sky; void sky() { COLOR = vec3(1, 0, 1); }"
	var marker := ShaderMaterial.new()
	marker.shader = shader
	bench.exterior.overhead.sky_material = marker
	await RenderingServer.frame_post_draw
	var frame: Image = bench.stage.get_texture().get_image()
	bench.exterior.overhead.sky_material = bench.exterior.overhead_material
	for y in range(5):
		for x in range(7):
			var ink := _pixel(frame, Vector2(0.32 + x * 0.06, 0.31 + y * 0.08))
			if ink.r > 0.85 and ink.b > 0.85 and ink.g < 0.15:
				return false
	return true

func _capture(title: String) -> void:
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var path := directory[0].path_join("outcrop-%s.png" % title)
	_check(root.get_texture().get_image().save_png(path) == OK, "Captured " + title)

func _pixel(frame: Image, uv: Vector2) -> Color:
	return frame.get_pixelv(Vector2i(uv * Vector2(frame.get_size())))

func _sky_lights(frame: Image, region: Rect2, threshold: float) -> int:
	var count := 0
	var bounds := Rect2i(region.position * Vector2(frame.get_size()), region.size * Vector2(frame.get_size()))
	for y in range(bounds.position.y, bounds.end.y, 2):
		for x in range(bounds.position.x, bounds.end.x, 2):
			if frame.get_pixel(x, y).get_luminance() > threshold:
				count += 1
	return count

func _drag_look(relative: Vector2) -> void:
	var point: Vector2 = lab.view.size * 0.5
	_mouse(point, MOUSE_BUTTON_RIGHT, true)
	var motion := InputEventMouseMotion.new()
	var stretch := root.get_stretch_transform()
	motion.position = stretch * point
	motion.global_position = motion.position
	motion.relative = stretch.basis_xform(relative)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_mouse(point, MOUSE_BUTTON_RIGHT, false)

func _mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_stretch_transform() * point
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key(code: Key) -> void:
	_key_state(code, true)
	_key_state(code, false)

func _key_state(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
