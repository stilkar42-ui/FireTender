extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Weather := preload("res://sim/felt_weather.gd")
const Lab := preload("res://hearth/hearth.tscn")
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_model()
	if DisplayServer.get_name() != "headless":
		await _scene()
	print("Ambient weather: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _model() -> void:
	var fire := Fire.new(Fire.COLD)
	var chapter := Chapter.new(fire)
	_storm(chapter)
	var cave := Weather.sample(fire, Vector3(0, 1.0, -2.7))
	var mouth := Weather.sample(fire, Vector3(0, 1.0, 2.1))
	_check(cave.rain < 0.01 and mouth.rain > 0.7 and mouth.wind.length() > cave.wind.length() * 2.0 and
		mouth.chill > cave.chill, "The same storm feels wetter, windier and colder at the mouth than under rock")
	var level := Weather.relative_wind(mouth.wind, Basis.IDENTITY)
	var pitched := Weather.relative_wind(mouth.wind, Basis(Vector3.RIGHT, -1.15))
	var turned := Weather.relative_wind(mouth.wind, Basis(Vector3.UP, PI))
	_check(level.y < -0.7 and level.is_equal_approx(pitched) and level.is_equal_approx(-turned),
		"Wind coming from behind moves into view at any pitch and reverses after a half turn")
	var x := Weather.relative_wind(Vector2.RIGHT, Basis.IDENTITY)
	_check(x.is_equal_approx(Vector2.RIGHT), "A crosswind from the left travels right")
	fire.coals.clear()
	var eye := Vector3(0, 0.30, 0)
	var unheated := Weather.sample(fire, eye)
	fire._new_coal(Vector2.ZERO, 0.1, 740.0, 0.09)
	var warmed := Weather.sample(fire, eye)
	_check(warmed.chill < unheated.chill and warmed.wind == unheated.wind and warmed.rain == unheated.rain,
		"Nearby radiant heat eases the chill independently of wind and rain")
	var cold := Fire.new(Fire.COLD)
	cold.weather = 1
	var winter := Weather.sample(cold, Vector3(0, 1.2, 0))
	_check(winter.chill > 0.9 and winter.wind.is_zero_approx() and winter.rain == 0.0,
		"Dry still air can feel cold without rain or wind")

func _scene() -> void:
	var config := OS.get_environment("TEMP").path_join("firetender-ambient-%d.cfg" % OS.get_process_id())
	var lab: Control = Lab.instantiate()
	lab.settings_path = config
	root.add_child(lab)
	await process_frame
	var figure = lab.ambient_figure
	var bench = lab.view.workbench
	var camera: Camera3D = bench.camera
	_storm(lab.chapter)
	var mouth := Vector3(0, 1.02, 2.1)
	_look_from(bench, mouth, 0.0, 0.40)
	lab.view.probe = Vector2(0, -2.7)
	lab.view.probe_valid = true
	lab._update_ambient_weather()
	await create_timer(0.75).timeout
	_check(camera.position.is_equal_approx(mouth) and lab.ambient_words.text.begins_with("From behind") and figure.wind.y < -0.7 and
		figure.shown_rain > 0.6 and figure.shown_wet > 0.5 and figure.shown_chill > 0.4,
		"Looking in from the mouth shows wind from behind, wetness and chill even with the cursor deep inside")
	var bounds: Rect2 = lab.ambient_overlay.get_global_rect()
	_check(lab.get_global_rect().encloses(bounds) and bounds.end.y < lab.view.torch_seat.position.y and
		not bounds.intersects(lab.journal.get_global_rect()) and not bounds.intersects(lab.chapter_controls.get_global_rect()) and
		figure.size.x > 90.0, "The larger reading fits directly above the Torch Bearer")
	await _capture("storm-from-the-mouth")
	var flow: Vector2 = figure.wind
	var world_flow := Weather.sample(lab.fire, camera.global_position).wind
	lab._toggle_settings()
	_click(lab.invert_wind_button.get_global_rect().get_center())
	_check(lab.invert_wind and figure.inverted and figure.wind == flow and
		Weather.sample(lab.fire, camera.global_position).wind == world_flow and
		lab.ambient_words.text.begins_with("From behind"),
		"Invert wind changes the illustrated direction and keeps the actual air and caption")
	await _capture("invert-wind-setting")
	lab._toggle_settings()
	_look_from(bench, mouth, PI, 0.40)
	lab._update_ambient_weather()
	_check(camera.position.is_equal_approx(mouth) and lab.ambient_words.text.begins_with("From ahead") and figure.wind.y > 0.7,
		"Turning outward from the same spot shows that the wind is now coming toward the player")

	figure.set_process(false)
	var shown_before: Vector2 = figure.shown_wind
	var rain_before: float = figure.shown_rain
	var wet_before: float = figure.shown_wet
	_look_from(bench, Vector3(0, 1.02, -2.7), PI, 0.40)
	lab._update_ambient_weather()
	figure._process(0.10)
	_check(figure.wind.length() < 0.3 and figure.rain < 0.01 and figure.shown_rain < rain_before and
		figure.shown_rain > figure.rain and figure.shown_wet < wet_before and figure.shown_wet > 0.1 and
		figure.shown_wind.distance_to(figure.wind) < shown_before.distance_to(figure.wind) and
		figure.wind_ink(1, 0.20) > 0.0 and figure.wind_ink(1, 0.20) < 1.0 and figure.wind_ink(3, 0.20) == 0.0,
		"Moving under rock fades rain and gust layers smoothly while the figure dries more slowly")
	figure.set_process(true)
	await create_timer(0.80).timeout
	await _capture("under-cover")
	lab._start_ember()
	lab.weather_picker.select(1)
	lab.weather_picker.item_selected.emit(1)
	lab._update_ambient_weather()
	await create_timer(0.55).timeout
	_check(figure.shown_chill > 0.85 and figure.shown_rain < 0.01 and "Cold" in lab.ambient_words.text and
		not lab.ambient_overlay.get_global_rect().intersects(lab.journal.get_global_rect()),
		"The cold-only animation works in One Ember and sits above its journal")
	await _capture("cold-without-rain")
	var saved := ConfigFile.new()
	_check(saved.load(config) == OK and saved.get_value("display", "invert_wind", false) == true,
		"The wind preference is saved with the other settings")
	lab.queue_free()
	await process_frame
	lab = Lab.instantiate()
	lab.settings_path = config
	root.add_child(lab)
	await process_frame
	_check(lab.invert_wind and lab.ambient_figure.inverted and lab.invert_wind_button.button_pressed,
		"Restarting the game restores the wind preference")

func _storm(chapter: Chapter) -> void:
	chapter.weather.wind = Vector2(0, -0.86)
	chapter.weather.rain = 0.84
	chapter.weather.temperature = 8.0

func _look_from(bench: Control, eye: Vector3, yaw: float, tilt: float) -> void:
	var arm := Vector3(sin(yaw) * cos(tilt), sin(tilt), cos(yaw) * cos(tilt)) * 2.1
	bench.focus = eye - arm
	bench.focus_target = bench.focus
	bench.orbit_radius = arm.length()
	bench.yaw = yaw
	bench.tilt = tilt
	bench._update_camera()

func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_stretch_transform() * at
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _capture(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(args[0].path_join(name + ".png")) == OK, "Captured " + name)

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
