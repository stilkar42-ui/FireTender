extends SceneTree

const Lab := preload("res://hearth/hearth.tscn")
const Fire := preload("res://sim/fire.gd")
const Shelter := preload("res://sim/red_hollow_shelter.gd")
const SHELF := Vector2(-1.89, -3.20)
const TOWARD_REAR := Vector3(-0.38, 0.35, -2.06)
const TOWARD_MOUTH := Vector3(-0.33, 0.31, -1.18)
var lab: Control
var passed := 0
var failed := 0
var directory: PackedStringArray

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = OS.get_cmdline_user_args()
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-continuity-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	for site in range(Shelter.SITES.size()):
		await _site_handoff(site)
	print("Red Hollow spatial continuity: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _site_handoff(site: int) -> void:
	lab._start_chapter()
	var fire: Fire = lab.fire
	var bench = lab.view.workbench
	var label: String = Shelter.SITES[site]
	_check(fire.coals.size() == 1 and fire.wood.is_empty() and fire.fuel_stock[4] == 6 and
		lab.chapter.sequel == null and not lab.site_picker.is_item_disabled(site),
		label + " opens with the rescued ember, limited stock and site choice")
	lab.site_picker.item_selected.emit(site)
	bench._refresh(0.0)
	await process_frame
	var depth: float = -Shelter.DEPTHS[site]
	var bark := fire.stock_piece(4)
	_check(fire.shelter.site == site and is_equal_approx(bench.cave.position.z, depth) and
		is_equal_approx(bark.at.y, clampf(-1.32 + depth, -1.42, 1.23)),
		label + " retains its original entrance depth and woodpile rest")
	var home: Transform3D = bench.camera.transform
	if site == 1:
		var reachable := true
		for area in range(lab.AREA_FOCUS.size()):
			lab.site_picker.item_selected.emit(lab.shelter_area_start + area)
			await create_timer(0.53).timeout
			var at: Vector2 = lab.AREA_FOCUS[area]
			reachable = reachable and bench.focus.distance_to(Vector3(at.x, 0.10, at.y)) < 0.004 and not fire.shelter.after_storm
		_check(reachable, "All six camera destinations are reachable from the Chapter I menu")
	lab.site_picker.item_selected.emit(lab.shelter_area_start + 1)
	await create_timer(0.53).timeout
	var point: Vector2 = lab.view.screen_at(SHELF)
	lab._select_fuel(4)
	_mouse(point, true)
	_mouse(point, false)
	_check(bench.cave.interior.is_visible_in_tree() and bench.cave.stations.is_visible_in_tree() and
		bench.focus.z < -3.0 and bark.at.distance_to(SHELF) < 0.02 and fire.has_fuel(bark),
		label + " can navigate to the deep shelf and place the same physical tinder in Chapter I")
	_check(fire.shelter.wind_at(Shelter.PASSAGE).is_zero_approx() and fire.shelter.seepage_at(Shelter.SEEP) == 0.0,
		label + " starts with a sheltered passage and the Chapter I moisture conditions")
	lab._reset_camera()
	_check(bench.camera.transform.is_equal_approx(home), label + " returns from the rear chamber to the original hearth view")

	var log := fire.add_fuel(7, Vector2(-0.22, 0.27), 0.6)
	var coal := fire.coals[0]
	fire._pile_ash(Vector2(0.40, 0.17), 0.008)
	fire.time = Shelter.END
	fire.shelter.sample(fire.time)
	fire.revision += 1
	bench._refresh(0.0)
	lab.chapter.outcome = "kept"
	lab._update_chapter()
	await process_frame
	_check(log != null and lab.site_picker.is_item_disabled(site) and
		not lab.site_picker.is_item_disabled(lab.shelter_area_start + 1), label + " locks site selection while keeping camera destinations usable")

	await _frame_camera(TOWARD_REAR, true, 0.37)
	var rear: Transform3D = bench.camera.transform
	if site == 1:
		await _capture("chapter-i-hearth-to-rear")
	await _frame_camera(TOWARD_MOUTH, false, 0.25)
	var forward: Transform3D = bench.camera.transform
	if site == 1:
		await _capture("chapter-i-rear-to-entrance")
	var geometry := _scenery(bench)
	var pieces := _fuel_state(fire)
	var ember := [coal.at, coal.height, coal.temperature, coal.char_mass, coal.cover, fire.ash, fire.ash_piles.duplicate()]
	lab._continue_after_storm()
	await process_frame
	_check(lab.chapter.sequel != null and fire.shelter.site == site and _scenery(bench) == geometry,
		label + " uses the exact same rock, floor, stations, ledge and panorama across the handoff")
	_check(bench.camera.transform.is_equal_approx(forward) and
		[coal.at, coal.height, coal.temperature, coal.char_mass, coal.cover, fire.ash, fire.ash_piles] == ember and fire.coals[0] == coal and
		_fuel_state(fire, pieces.keys()) == pieces,
		label + " retains the viewing angle, same fuel poses, living coal and ash")
	_check(fire.shelter.seepage_at(Shelter.SEEP) > 0.30 and fire.shelter.seepage_at(SHELF) == 0.0,
		label + " applies aftermath moisture at the same fixed seep and shelf coordinates")
	if site == 1:
		await _capture("chapter-ii-rear-to-entrance")
	await _frame_camera(TOWARD_REAR, true, 0.37)
	_check(bench.camera.transform.is_equal_approx(rear), label + " uses identical camera limits when looking into the rear")
	if site == 1:
		await _capture("chapter-ii-hearth-to-rear")

func _frame_camera(target: Vector3, inward: bool, angle: float) -> void:
	var bench = lab.view.workbench
	bench.reset_camera()
	var yaw_delta: float = PI / bench.ORBIT_SPEED if inward else 0.0
	bench.orbit(Vector2(yaw_delta, (angle - bench.tilt) / bench.TILT_SPEED))
	bench.focus_on(target)
	await create_timer(0.58).timeout

func _scenery(bench: Control) -> Dictionary:
	var signatures := {}
	var meshes := bench.cave.find_children("*", "MeshInstance3D", true, false) as Array[Node]
	meshes.append_array(bench.ground_set.find_children("*", "MeshInstance3D", true, false))
	meshes.append(bench.floor_node)
	for node: MeshInstance3D in meshes:
		signatures[node.get_instance_id()] = [node.global_transform, node.mesh, node.material_override, node.is_visible_in_tree()]
	return signatures

func _fuel_state(fire: Fire, restrict_to := []) -> Dictionary:
	var state := {}
	for piece in fire.all_fuel():
		if restrict_to.is_empty() or piece in restrict_to:
			state[piece] = [piece.at, piece.axis, piece.pose, piece.height, piece.water, piece.temperature,
				piece.wood, piece.charred_wood, piece.airborne, piece.fall_speed, piece.pose.at, piece.pose.slope, piece.pose.supports.duplicate()]
	return state

func _capture(name: String) -> void:
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var stage: SubViewport = lab.view.workbench.stage
	_check(stage.get_texture().get_image().save_png(directory[0].path_join(name + ".png")) == OK, "Captured " + name)

func _mouse(point: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.position = root.get_stretch_transform() * point
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	Input.parse_input_event(click)
	Input.flush_buffered_events()

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
