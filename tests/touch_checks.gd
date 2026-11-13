extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Heat := preload("res://sim/felt_heat.gd")
const Touch := preload("res://sim/felt_touch.gd")
const Lab := preload("res://hearth/hearth.tscn")
var lab: Control
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_model()
	if DisplayServer.get_name() != "headless":
		await _scene()
	print("Heat at Hand touch: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _model() -> void:
	var fire := Fire.new(Fire.COLD)
	var tinder := fire.add_fuel(4, Vector2.ZERO)
	var dry := Touch.fuel(tinder, tinder, 0, 0.0)
	_check(dry.words == "Cool and dry." and dry.edge == 0.0 and dry.palm == 0.0,
		"Dry tinder has no blue and reads its actual temperature")
	tinder.water = tinder.original * 0.16
	tinder.temperature = 5.0
	var damp := Touch.fuel(tinder, tinder, 0, 0.0)
	tinder.water = tinder.original * 0.34
	var wet := Touch.fuel(tinder, tinder, 0, 0.0)
	tinder.water = tinder.original * 0.92
	var soaked := Touch.fuel(tinder, tinder, 0, 0.0)
	_check(damp.words == "Cold and damp." and wet.words == "Cold and wet." and soaked.words == "Soaked through." and
		damp.edge > dry.edge and wet.edge > damp.edge and soaked.edge > wet.edge,
		"Damp, wet and soaked tinder produce distinct and increasing blue cues")
	var oak := fire.add_fuel(3, Vector2(0.53, -0.03), 0.0, 0.0, 0, true)
	var section := oak.sections[0]
	_check(Touch.fuel(oak, section, 0, 0.0).words == "Soaked through.",
		"Waterlogged oak reads as soaked from its physical layers")
	_face(section.faces[0], 0.10, 35.0)
	var outer := Touch.fuel(oak, section, 0, 0.0)
	var other := Touch.fuel(oak, section, 1, 0.0)
	_check(outer.words == "Warm outside,\nwet within." and outer.heat > Heat.BANDS[1] and
		outer.edge == 0.0 and outer.palm > 0.45 and other.edge > 0.8,
		"A partly dried face has warm ochre and blue inside the palm while its opposite face remains wet")
	section.faces[0].vapor = 0.000009
	_check(Touch.fuel(oak, section, 0, 0.0).words == "This face is drying.\nWet within.",
		"Live evaporation distinguishes a drying face from one that only feels dry")
	var birch := fire.add_fuel(12, Vector2(-0.50, -0.08), 0.0, 0.0, 0, true)
	fire.set_wet_skin(birch)
	var bark := birch.sections[1]
	_face(bark.faces[0], 0.60, 8.0)
	_face(bark.inner[0], 0.20, 8.0)
	var wet_bark := Touch.fuel(birch, bark, 0, 0.0)
	_check(wet_bark.words == "Bark is wet.\nDrier within." and wet_bark.edge >= 0.4 and wet_bark.palm == 0.0,
		"Wet bark over drier wood reads as an outline with a clear palm")
	_face(bark.faces[0], 0.48, 36.0)
	var warm_wet := Touch.fuel(birch, bark, 0, 0.55)
	_check(warm_wet.heat >= 0.55 and warm_wet.edge > 0.4 and "Warm" in warm_wet.words and "wet" in warm_wet.words,
		"Nearby radiant warmth and a warm wet surface can both be felt")
	_face(bark.faces[0], 0.26, 56.0)
	bark.faces[0].vapor = 0.00021
	var steaming := Touch.fuel(birch, bark, 0, 0.0)
	_check(steaming.heat > 1.35 and steaming.edge > 0.0 and steaming.words == "Hot and damp.\nGiving off steam.",
		"A hot damp face with actual vapor reports steam")
	var water := bark.faces[0].water
	var revision := fire.revision
	Touch.fuel(birch, bark, 0, 3.0)
	_check(bark.faces[0].water == water and fire.revision == revision,
		"Touch reads state without changing moisture or advancing the fire")
	var at := Vector2(0.44, 0.44)
	fire._pile_ash(at, 0.008)
	_check(Touch.ground(fire, at, 0.0).words == "Ash is dry, but cool." and Touch.ground(fire, at, 0.3).edge == 0.0,
		"Loose ash reads dry in cover and can still feel warmth from nearby fire")
	fire.weather = 3
	_check(Touch.ground(fire, at, 0.0).words == "Rain reaches this ash." and Touch.ground(fire, at, 0.0).edge > 0.0,
		"Rain exposure comes from the weather at the ash pile")
	var coal := fire._new_coal(Vector2.ZERO, 0.035, 8.0, 0.040)
	coal.cover = 0.007
	coal.water = coal.original * 0.41
	_check(Touch.coal(coal, fire.ambient(), 0.0).words == "Ash feels cold\nand wet.",
		"A covered coal patch uses the bed's actual water reservoir")

func _scene() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-touch-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	lab._start_after_storm_trial()
	var fire: Fire = lab.fire
	var view = lab.view
	var bench = view.workbench
	var wood := fire.stock_piece(12, true)
	fire.pose_fuel(wood, Vector2(0.53, 0.27), 0.0, 0.0, 0, true)
	var left := wood.sections[0]
	var right: Fire.Piece = wood.sections.back()
	_face(left.faces[0], 0.08, 37.0)
	_face(right.faces[0], 0.48, 38.0)
	_face(left.core, 0.78, 16.0)
	_face(left.inner[0], 0.65, 15.0)
	fire._sync_sections(wood)
	bench._refresh(0.0)
	var left_screen: Vector2 = view._project(wood.pose.point(-wood.pose.span * 0.65, left.upper_radius * 0.62))
	var right_screen: Vector2 = view._project(wood.pose.point(wood.pose.span * 0.65, right.upper_radius * 0.62))
	_hover(left_screen)
	await create_timer(0.35).timeout
	var hit = bench.touch_at(view.pointer)
	_check(hit.piece == wood and hit.section == left and hit.face == 0 and lab.heat_hand.wetness.x == 0.0 and
		lab.heat_hand.wetness.y > 0.5 and "wet within" in lab.warmth.text,
		"Mouseover resolves the dry end and shows the wet inner wood")
	_check_layout()
	await _capture("warm-outside-wet-within")
	_hover(right_screen)
	await create_timer(0.35).timeout
	hit = bench.touch_at(view.pointer)
	var hand = lab.heat_hand
	_check(hit.piece == wood and hit.section == right and hand.shown_wetness.x > 0.55 and hand.shown_heat > Heat.BANDS[1] and
		"wet" in lab.warmth.text and hand.moisture_color(1.0).b > hand.moisture_color(1.0).r,
		"Moving to the wet end fades blue in over the same warm ochre hand")
	_check_layout()
	await _capture("warm-wet-surface")
	_face(right.faces[0], 0.24, 8.0)
	_face(right.core, 0.16, 8.0)
	_face(right.inner[0], 0.16, 8.0)
	await create_timer(0.45).timeout
	_check(hand.shown_wetness.x > 0.14 and hand.shown_wetness.x < 0.38 and "damp" in lab.warmth.text,
		"Damp wood stays below the blue-outline range")
	await _capture("damp-surface")
	_face(right.faces[0], 0.82, 8.0)
	_face(right.core, 0.76, 8.0)
	_face(right.inner[0], 0.74, 8.0)
	await create_timer(0.45).timeout
	_check(hand.shown_wetness.x > 0.95 and "Soaked through" in lab.warmth.text,
		"Soaked wood reaches the full indigo rim")
	await _capture("soaked-through")
	_face(right.faces[0], 0.10, 12.0)
	_face(right.core, 0.10, 12.0)
	_face(right.inner[0], 0.10, 12.0)
	await create_timer(0.35).timeout
	_check(hand.shown_wetness.length() < 0.07 and "dry" in lab.warmth.text,
		"A live moisture change updates the hand without requiring mouse movement")
	await _capture("dry-surface")
	var old_camera: Transform3D = bench.camera.transform
	wood.pose.height = 0.36
	_face(left.faces[1], 0.78, 8.0)
	var below: Vector3 = bench.world(wood.pose.point(-wood.pose.span * 0.65, -left.lower_radius * 0.7))
	bench.camera.position = below + Vector3(0.0, -0.24, 0.75)
	bench.camera.look_at(below)
	hit = bench.touch_at(bench.camera.unproject_position(below) / bench.raster_scale)
	_check(hit.piece == wood and hit.section == left and hit.face == 1,
		"An elevated log can be read on its underside from a low camera angle")
	bench.camera.transform = old_camera
	var ash_at := Vector2(0.66, 0.61)
	fire._pile_ash(ash_at, 0.008)
	bench._refresh(0.0)
	_hover(view.screen_at(ash_at))
	await create_timer(0.12).timeout
	_check("ash" in lab.warmth.text.to_lower(), "Mouseover reads the ash pile from its visible footprint")
	lab._start_ember()
	await process_frame
	_check_layout()

func _check_layout() -> void:
	var label: Label = lab.warmth
	var text: Rect2 = label.get_global_rect()
	var icon: Rect2 = lab.heat_hand.get_global_rect()
	var bar: Rect2 = lab.fuel_bar.get_global_rect()
	_check(lab.get_global_rect().encloses(text) and not text.intersects(bar) and not icon.intersects(bar) and
		text.intersection(icon).size.y <= 5.0 and label.get_line_count() <= 2 and
		label.get_visible_line_count() == label.get_line_count(),
		"The tactile text and hand fit beside the fuel bar at %s" % str(root.size))

func _face(region: Fire.Piece, water: float, temperature: float) -> void:
	region.water = region.original * water
	region.temperature = temperature

func _hover(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_stretch_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
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
