extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Lab := preload("res://hearth/hearth.tscn")
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_smoke()
	_rolling()
	_rain_surfaces()
	if DisplayServer.get_name() != "headless":
		await _scene()
	print("Weather and rolling: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _smoke() -> void:
	var calm := _smoke_trial(Vector2.ZERO)
	var gust := _smoke_trial(Vector2(0, -0.78))
	_check(calm.escaped > 0.009 and gust.escaped < calm.escaped * 0.15 and gust.held > calm.held,
		"Smoke finds the mouth in calm air and collects in the shelter under an inward gust")
	_check(gust.top <= 2.121 and gust.rear < -0.85 and calm.rises,
		"Buoyant smoke rises, stays below rock, and follows the draft deeper into the cave")
	_check(absf(calm.error) < 0.00000001 and absf(gust.error) < 0.00000001 and gust == _smoke_trial(Vector2(0, -0.78)),
		"The smoke budget balances and the same fixed steps reproduce the parcel state")
	var fire := Fire.new(8)
	var before := fire.smoke_field.emitted
	fire.step()
	_check(fire.smoke_field.emitted > before and fire.smoke_field.carried_mass() > 0.0,
		"Combustion supplies the transported smoke")

func _smoke_trial(wind: Vector2) -> Dictionary:
	var fire := Fire.new(Fire.COLD)
	fire.shelter = Fire.Shelter.new()
	fire.shelter.wind = wind
	var field := fire.smoke_field
	field.release(Vector3(0, 1.72, -0.42), 0.018, 0.9)
	var rises := false
	var top := 0.0
	var rear := 0.0
	for tick in range(64):
		field.advance(fire, Fire.STEP)
		for parcel in field.parcels:
			top = maxf(top, parcel.at.y)
			rear = minf(rear, parcel.at.z)
			rises = rises or parcel.at.y > 1.86
	return {"escaped": field.escaped, "held": fire.shelter.smoke, "top": top, "rear": rear, "rises": rises,
		"error": field.emitted - field.escaped - field.dispersed - field.carried_mass()}

func _rolling() -> void:
	var first := _roll_course()
	print("Roll course: ", first)
	_check(first.started and first.rested and first.distance > 0.06 and first.drop > 0.04 and first.turned,
		"An off-center branch rolls down and settles at a lower rest over several fixed steps")
	_check(first.stopped_short and first == _roll_course(),
		"The rolling branch stays clear of its neighbor and reaches the same rest on replay")

func _roll_course() -> Dictionary:
	var fire := Fire.new(Fire.COLD)
	fire.add_fuel(10, Vector2.ZERO, 0.0, 0.0, 0, true)
	var guard := fire.add_fuel(10, Vector2(0, 0.27), 0.0, 0.0, 0, true)
	var loose := fire.add_fuel(9, Vector2(0, 0.034), 0.0, 0.0, 1, true)
	var start := loose.at
	var height := loose.height
	var started := loose.rolling
	var turned := false
	var path: Array[Vector2] = []
	for tick in range(16):
		fire.step()
		path.append(loose.at)
		turned = turned or absf(loose.roll_travel) > 0.01
	return {"started": started, "rested": not loose.rolling and not loose.airborne,
		"distance": loose.at.distance_to(start), "drop": height - loose.height, "turned": turned,
		"stopped_short": loose.at.y < guard.at.y - 0.078, "path": path}

func _rain_surfaces() -> void:
	var fire := Fire.new(Fire.COLD)
	var log := fire.add_fuel(10, Vector2.ZERO, 0.0, 0.0, 0, true)
	var fuel := fire.all_fuel()
	_check(fire.rain_landing_height(log.at, fuel) > log.height and fire.rain_landing_height(Vector2(0, 0.5), fuel) == 0.0,
		"Drops can strike the crown of wood or the exposed ground")
	fire.weather = 3
	for tick in range(20):
		fire.step()
	var soaked := fire.ground_wetness
	fire.weather = 0
	fire.step()
	_check(soaked > 0.6 and fire.ground_wetness > 0.5 and fire.ground_wetness < soaked,
		"Ground takes on rain and retains its wetness as the rain lets up")

func _scene() -> void:
	var lab: Control = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-weather-physics-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	var fire: Fire = lab.fire
	var bench = lab.view.workbench
	lab._advance(300.0)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	_check(lab.jump_steps == 0 and lab.paused, "Escape stops a time jump and returns to a responsive paused hearth")
	fire.time = Fire.Shelter.END
	_check(not lab.chapter.objective().is_empty() and lab.chapter.outcome.is_empty(),
		"The time boundary is resolved by the next simulation step")
	fire.time = Fire.Shelter.END - Fire.STEP
	lab.chapter.sampled_at = fire.time - 0.5
	lab.chapter.bed = true
	lab.chapter.preserved = true
	var coal := fire.coals[0]
	lab._advance(30.0)
	await process_frame
	await process_frame
	_check(fire.time == Fire.Shelter.END and lab.jump_steps == 0 and lab.paused and lab.story_menu.mode == "results" and
		lab.pause_button.disabled and "Complete" in lab.time_label.text and lab.story_menu.results_continue.visible,
		"Day Three ends a time jump at the results page")
	lab._pause()
	_check(lab.paused, "A completed chapter waits at the handoff")
	lab.story_menu.results_continue.pressed.emit()
	_check(lab.chapter.sequel != null and not lab.pause_button.disabled and fire.coals[0] == coal and fire.time == Fire.Shelter.END,
		"Continue opens the next chapter with the same physical bed")
	lab.story_menu.chapter_button.pressed.emit()
	lab.chapter.outcome = "lost"
	lab._update_chapter()
	_check(lab.story_menu.results_replay.visible and not lab.story_menu.results_continue.visible, "A lost hearth offers an explicit retry")
	lab.story_menu.results_replay.pressed.emit()
	_check(fire.time == Fire.Shelter.END and lab.chapter.outcome.is_empty(), "Retry starts the Chapter II practice")
	lab._start_chapter()
	fire.shelter.rain = 0.92
	fire.shelter.wind = Vector2(0.42, -0.7)
	for tick in range(9):
		fire.smoke_field.release(Vector3(0.12, 0.12, -0.22), 0.0022, 0.84)
		fire.smoke_field.advance(fire, Fire.STEP)
	await create_timer(0.35).timeout
	_check(bench.rain_impacts.mesh.get_surface_count() > 0 and bench.rain_lines.mesh.get_surface_count() > 0 and
		bench.rain_impacts.get_aabb().position.z > -0.68 and
		bench.cave_ground.get_shader_parameter("rain_film").x > 0.55 and not bench.smoke_views.is_empty(),
		"Rain splashes in the exposed footprint, the soil darkens, and smoke renders at its simulated position")
	await _capture("rain-impacts-and-smoke")
	lab._load_trial(1)
	var fuel := fire.wood[0]
	var section := fuel.cross_section(0.0)
	section.flame = 25.0
	section.draft = Vector2(0.7, -0.4)
	fire.revision += 1
	bench._refresh(0.0)
	var flame: MeshInstance3D = bench.plumes[section.get_instance_id()]
	var bend: Vector3 = flame.material_override.get_shader_parameter("flame_bend")
	_check(bend.x > 0.0 and bend.z < 0.0 and flame.mesh.get_faces().size() > 6,
		"A subdivided flame bends downwind while its base stays at the fuel")
	await _capture("wind-bent-flame")

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
