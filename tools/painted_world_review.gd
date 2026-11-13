extends SceneTree
## Reproducible frames for comparing the same cave and assets across art passes.
const Lab := preload("res://hearth/hearth.tscn")
const Chapter := preload("res://sim/red_hollow.gd")
const Fire := Chapter.Fire
const Work := Chapter.Family.Workshop

var lab: Control
var bench: Control
var destination: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	destination = args[0]
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-art-review-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	lab._start_family_trial()
	bench = lab.view.workbench
	if bench == null:
		quit(1)
		return
	var fire: Fire = lab.fire
	var kin: Chapter.Family = lab.chapter.family
	for kind in [7, 8, 2, 9, 10, 12]:
		fire.receive_fuel(kind, Vector2(-2.10 + (kind % 4) * 0.19, -0.67 + (kind % 3) * 0.26), 1.9, 0, 0.57 if kind == 12 else -1.0)
	for entry in [[8, Vector2(-0.21, 0.09), 0.48], [8, Vector2(0.21, -0.08), 0.46], [2, Vector2(-0.02, -0.03), 1.82]]:
		var piece := fire.receive_fuel(entry[0], entry[1], entry[2], 0)
		fire.pose_fuel(piece, entry[1], entry[2], 0.0, 1 if entry[0] == 2 else 0, true)
		fire._prime(piece, 410.0, 400.0, 110.0)
	for i in range(72):
		lab._step_budgeted(1)
	fire._pile_ash(Vector2(0.48, 0.28), 0.030)
	for pair in [["bone", Work.HUNTER], ["clean_hide", Work.HIDE_RACK], ["meat", Work.COOK],
		["knot", Work.MAKER], ["point", Work.MAKER], ["shaft", Work.MAKER]]:
		kin.workshop.add(pair[0], 120, pair[1])
	lab._update_chapter()
	await _shot("family-day", Vector3(-0.36, 0.21, 0.20), 0.29, 0.03, 2.58, 57.0)
	lab.view.set_tool(lab.view.Tool.WOOD)
	lab.view.select_material(8)
	await _shot("placement-and-hud", Vector3(-0.03, 0.12, 0.01), 0.38, 0.49, 2.23, 61.0, true)
	lab.view.select_material(-1)
	await _shot("cave-rear", Vector3(0.0, 0.29, -2.30), 0.22, 0.12, 3.33, 62.0)
	await _shot("cave-mouth", Vector3(-0.06, 0.25, -2.23), PI * 0.93, 0.10, 2.77, 61.0)
	await _shot("hearth-close", Vector3(-0.03, 0.07, 0.01), 0.35, 0.46, 1.70, 57.0)
	await _shot("woodpile", Vector3(-1.92, 0.07, -0.55), -0.46, 0.57, 1.70, 56.0)
	await _shot("dry-shelf-and-seep", Vector3(-0.46, 0.10, -3.17), 0.04, 0.52, 2.85, 63.0)
	await _station("cooking", Work.COOK_AT, -0.55)
	await _station("hunting", Work.HUNTER_AT, 0.38)
	await _station("making", Work.MAKER_AT, -0.26)
	fire.time = Chapter.Shelter.END + Chapter.Shelter.DAY * 0.94
	fire.shelter.sample(fire.time)
	await _shot("family-night", Vector3(-0.36, 0.21, 0.20), 0.29, 0.03, 2.58, 57.0)
	quit()

func _station(name: String, at: Vector2, yaw: float) -> void:
	await _shot(name, Vector3(at.x, 0.24, at.y), yaw, 0.26, 1.30, 55.0)

func _shot(name: String, target: Vector3, yaw: float, tilt: float, radius: float, fov: float, hud := false) -> void:
	bench.focus = target
	bench.focus_target = target
	bench.yaw = yaw
	bench.tilt = tilt
	bench.orbit_radius = radius
	bench.zoom = fov
	bench.zoom_target = fov
	bench._update_camera()
	if hud:
		lab.view.pointer = lab.view.screen_at(Vector2(-0.37, 0.24))
		lab.view._refresh_drop()
		lab.view.queue_redraw()
	bench.last_revision = -1
	bench._refresh(0.0)
	lab.hearth_hud.visible = hud
	for frame in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(destination.path_join(name + ".png"))
	if result != OK:
		push_error("Could not write " + name)
		quit(1)
	print(name, " ", bench.camera.transform)
