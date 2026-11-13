extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Lab := preload("res://hearth/hearth.tscn")
var lab: Control
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_windbreak()
	if DisplayServer.get_name() != "headless":
		await _scene()
	print("Hearth feedback: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _windbreak() -> void:
	var open := Fire.new(Fire.COLD)
	var sheltered := Fire.new(Fire.COLD)
	open.weather = 2
	sheltered.weather = 2
	var exposed := open._new_coal(Vector2.ZERO, 0.035, 525.0, 0.041)
	var lee := sheltered._new_coal(Vector2.ZERO, 0.035, 525.0, 0.041)
	var barrier := sheltered.add_fuel(10, Vector2(-0.25, 0.0), PI * 0.5, 0.0, 0, true)
	var in_lee := sheltered.background_wind(Vector2.ZERO, lee.height)
	print("Windbreak profile · coal %.3f m · rest %.3f m · at bed %s · upstream %s · around %s · above %s" %
		[lee.height, barrier.pose.height, in_lee, sheltered.background_wind(Vector2(-0.45, 0.0)),
			sheltered.background_wind(Vector2(0.0, 0.55)), sheltered.background_wind(Vector2.ZERO, 0.40)])
	_check(in_lee.x < 0.54 and sheltered.background_wind(Vector2(-0.45, 0.0)).x > 0.99 and
		sheltered.background_wind(Vector2(0.0, 0.55)).x > 0.95 and
		sheltered.background_wind(Vector2.ZERO, 0.40).x > 0.95,
		"A transverse log shelters low air downstream, with open flow above and around it")
	open.step()
	sheltered.step()
	print("Coal cooling · open %.3f kW · screened %.3f kW" % [exposed.convection_loss, lee.convection_loss])
	_check(lee.draft.length() < exposed.draft.length() and lee.convection_loss < exposed.convection_loss * 0.80,
		"The windbreak changes the actual coal draft and reduces convective heat loss")
	sheltered.move_fuel(barrier, Vector2(0.40, 0.0))
	_check(sheltered.background_wind(Vector2.ZERO).x > 0.99, "A log placed downwind leaves the coals exposed")

func _scene() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-feedback-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	lab._load_trial(8)
	lab.paused = true
	var fire: Fire = lab.fire
	var view = lab.view
	var bench = view.workbench
	var coal := fire.coals[0]
	_key(KEY_B)
	var aim: Vector2 = view.screen_at(coal.at)
	var source: Vector2 = view.screen_at(coal.at + Vector2(0.0, 0.45))
	_mouse(source, true)
	_mouse(aim, false)
	var first: Fire.Breath = view.last_breath
	_check(first != null and fire.breaths.size() == 1 and first.strength < 1.0 and first.direction.y < -0.9,
		"The player sets a gentle breath with the real drag gesture")
	if first == null:
		return
	lab._step_budgeted(3)
	bench._refresh(0.0)
	var ember: MeshInstance3D = bench.beds[coal.get_instance_id()]
	_check(float(ember.get_meta("breath_glow")) > 0.01 and coal.breath_balance > 0.0,
		"Useful breath brings out a red glow from the actual oxidation response")
	await create_timer(0.22).timeout
	await _capture("breath-red")
	while not view.breath_ready():
		lab._step_budgeted(1)
	_key(KEY_B)
	var second: Fire.Breath = view.last_breath
	_check(second != first and second.origin == first.origin and second.direction == first.direction and
		second.reach == first.reach and second.strength == first.strength and second.duration == first.duration,
		"B repeats the same origin, direction, reach, strength and duration")
	while not view.breath_ready():
		lab._step_budgeted(1)
	_mouse(source, true, true)
	_mouse(aim, false)
	var gust: Fire.Breath = view.last_breath
	_check(gust.strength > 2.5, "Shift-drag sets and keeps a stronger gust")
	lab._start_after_storm_trial()
	var pine := fire.stock_piece(11, true)
	fire.pose_fuel(pine, Vector2(-0.44, 0.10), 0.0, 0.0, 0, true)
	var face := pine.sections[1].faces[0]
	face.temperature = 645.0
	face.char_mass = 0.004
	face.pocket_pressure = 0.22
	fire._pop_if_pressurized(face)
	_check(not fire.sparks.is_empty() and not bench.pop_marks.is_empty() and lab.sound.pop > 0.2,
		"A pressurized knot triggers a visible burst, audible snap and physical cinder")
	fire._advance_sparks(0.20, fire.ambient())
	var fragment := fire.sparks[0]
	bench._refresh(0.01)
	_check(fragment.flight.size() > 2 and bench.spark_lines.mesh.get_surface_count() == 1 and
		bench.spark_lines.get_aabb().size.y > 0.02, "The cinder draws as a flame shape along its rising flight path")
	await _capture("cinder-in-flight")
	for i in range(16):
		fire._advance_sparks(0.20, fire.ambient())
		if not bench.ground_sparks.is_empty() or fragment.surface != null:
			break
	bench._refresh(0.01)
	_check(not bench.ground_sparks.is_empty() or fragment.surface != null,
		"The physical impact leaves a trackable ember at the landing")
	await create_timer(0.35).timeout
	await _capture("cinder-landing")
	var wet := fire.stock_piece(12, true)
	for tick in range(4):
		if wet != null:
			break
		# Removing the pine can leave the adjacent parcel briefly airborne.
		lab._step_budgeted(1)
		wet = fire.stock_piece(12, true)
	_check(wet != null, "Wet birch is available after the stormfall settles")
	if wet == null:
		return
	fire.pose_fuel(wet, Vector2(0.38, 0.06), PI * 0.5, 0.0, 0, true)
	var dry_face := wet.sections[0].faces[0]
	var damp_face := wet.sections[2].faces[0]
	dry_face.water = dry_face.original * 0.10
	damp_face.water = damp_face.original * 0.72
	damp_face.temperature = 71.0
	fire._sync_sections(wet)
	lab._step_budgeted(1)
	bench._refresh(0.0)
	var steam: MeshInstance3D = bench.steam_views.get(damp_face.get_instance_id())
	var logs: Array = bench.logs[wet.get_instance_id()]
	var dry_ink: StandardMaterial3D = logs[0].get_surface_override_material(0)
	var damp_ink: StandardMaterial3D = logs[2].get_surface_override_material(0)
	_check(damp_face.vapor > 0.000006 and steam != null and steam.visible and not bench.plumes.has(damp_face.get_instance_id()),
		"Actual evaporation draws pale steam from the wet face independently of smoke")
	_check(dry_ink.roughness > damp_ink.roughness and dry_ink.albedo_color.v > damp_ink.albedo_color.v,
		"The drier face renders lighter and more matte than the waterlogged end")
	fire.shelter.wind = Vector2(0.65, -0.6)
	fire.shelter.site = 2
	lab._update_ambient_weather()
	bench._refresh(0.0)
	_check(lab.ambient_figure.wind.length() > 0.10 and bench.wind_lines.mesh.get_surface_count() > 0 and
		lab.ambient_overlay.get_global_rect().end.y < lab.view.torch_seat.position.y,
		"The ochre wind figure and world wisps follow live airflow")
	await _capture("wind-and-drying")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _mouse(at: Vector2, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_stretch_transform() * at
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shift
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
