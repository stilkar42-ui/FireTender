extends SceneTree
## Chapter II benchmark. Run on a real renderer, or pass headless for solver throughput.
const LabScene := preload("res://hearth/hearth.tscn")
const Chapter := preload("res://sim/red_hollow.gd")
const Fire := Chapter.Fire
const MODES := ["matrix", "controls", "headless", "profile", "headless_controls", "structure", "headless_structure", "thermal_trace"]

var lab
var bench
var cases: Array[Dictionary] = []
var log_file: FileAccess
var elapsed := 2.5
var case_filter := ""
var phase := "matrix"
var diagnostic = null
var write_trace := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: -- <jsonl output> [mode] [seconds] [case regex]. Modes: ", MODES)
		quit(1)
		return
	if args.size() > 1: phase = args[1]
	if phase not in MODES:
		printerr("Unknown benchmark mode: ", phase)
		quit(1)
		return
	if args.size() > 2: elapsed = maxf(0.5, args[2].to_float())
	if args.size() > 3: case_filter = args[3]
	write_trace = "--full-trace" in args
	log_file = FileAccess.open(args[0], FileAccess.WRITE)
	if log_file == null:
		quit(1)
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if ResourceLoader.exists("res://tools/stockpile_probe.gd"):
		diagnostic = load("res://tools/stockpile_probe.gd")
	_write({"meta": true, "engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(),
		"threads": OS.get_processor_count(), "ram": OS.get_memory_info().get("physical", 0),
		"gpu": RenderingServer.get_video_adapter_name(), "api": RenderingServer.get_video_adapter_api_version(),
		"os": OS.get_version(), "window": str(root.size), "phase": phase, "seconds": elapsed, "instrumented": diagnostic != null,
		"pid": OS.get_process_id()})
	_build_cases()
	var filter := RegEx.new()
	if filter.compile(case_filter) != OK:
		quit(1)
		return
	for spec in cases:
		if not case_filter.is_empty() and filter.search(spec.id) == null:
			continue
		if phase == "thermal_trace":
			_thermal_trace(spec)
		elif phase == "headless_structure":
			_structure_trace(spec)
		elif phase.begins_with("headless"):
			_headless_case(spec)
		else:
			await _rendered_case(spec)
	log_file.close()
	quit()

func _build_cases() -> void:
	if phase == "thermal_trace":
		_case(60, 9, 1, "coal")
		_case(60, 9, 1, "flame", "dense")
		_case(100, 9, 1, "scorch")
		_case(60, 9, 1, "flame", "near")
		_case(0, 0, 1, "ignition")
	elif phase in ["structure", "headless_structure"]:
		for action in ["top", "middle", "bottom", "rotation", "collapse"]:
			_case(100, 9, 1, "flame", "dense", "support_" + action)
	elif phase in ["matrix", "headless"]:
		for speed in [1, 16, 64] if phase == "matrix" else [1]:
			for stock in [0, 20, 40, 60, 100]:
				for drying in [0, 3, 6, 9]:
					_case(stock, drying, speed)
	else:
		for state in ["coal", "flame", "scorch"]:
			for stock in [0, 60, 100]:
				for count in [0, 6, 9]:
					_case(stock, count, 1, state)
		for speed in [1, 16, 64]:
			for state in ["flame", "scorch"]:
				_case(60, 9, speed, state, "dense")
		for mode in ["paused", "orbit", "render_off", "move", "drag_preview", "turn", "place", "family_idle", "family_work", "look_pile"]:
			_case(60, 9, 1, "flame", "dense", mode)
		if diagnostic != null:
			_case(60, 9, 1, "flame", "dense", "reduced")
		for stock in [20, 100]:
			_case(stock, 9, 1, "flame", "loose", "move")
			_case(stock, 9, 1, "flame", "dense", "move")
		_case(60, 9, 1, "flame", "shelf")
		_case(60, 9, 1, "flame", "near")
		_case(60, 9, 1, "flame", "dense", "audio_off")

func _case(stock: int, drying: int, speed: int, state := "coal", layout := "loose", mode := "normal") -> void:
	cases.append({"id": "%03d-%d-%02d-%s-%s-%s" % [stock, drying, speed, state, layout, mode],
		"stock": stock, "drying": drying, "speed": speed, "state": state, "layout": layout, "mode": mode})

func _setup(story: Chapter, spec: Dictionary) -> Fire.Piece:
	story.set_up_after_storm_trial()
	var fire := story.fire
	fire.wood.clear()
	fire.stored.clear()
	fire.coals.clear()
	fire._reindex()
	for i in range(6):
		var angle := TAU * i / 6.0
		fire._new_coal(Vector2.from_angle(angle) * 0.62, 0.066, 635.0, 0.037)
	for i in range(3):
		fire._new_coal(Vector2.from_angle(TAU * i / 3.0) * 0.19, 0.077, 692.0, 0.049)
	if spec.state != "coal":
		for i in range(4):
			var angle := TAU * i / 4.0
			var piece := fire.receive_fuel([8, 2, 8, 10][i], Vector2.from_angle(angle) * 0.41, angle + PI * 0.5, 0, 0.12)
			fire._prime(piece, 442.0, 427.0, 130.0)
	for i in range(spec.drying):
		var angle := TAU * i / maxf(float(spec.drying), 1.0) + 0.12
		var at := Vector2.from_angle(angle) * (0.99 if spec.state == "scorch" else 1.045)
		var kind: int = [12, 2, 10, 11, 8][i % 5]
		var piece := fire.receive_fuel(kind, at, angle + PI * 0.5, 0, 0.59 if i % 2 == 0 else 0.39)
		if spec.state == "scorch":
			for section in piece.sections:
				section.faces[0].temperature = 125.0 if i % 3 == 0 else 269.0
				section.faces[1].temperature = 101.0 if i % 3 == 0 else 318.0
			fire._sync_sections(piece)
		story.sequel.track(piece)
	var handled: Fire.Piece
	for i in range(spec.stock):
		var at := Vector2(-2.46 + (i % 10) * 0.37, -3.62 + (i / 10) * 0.156)
		var tier := 0
		var yaw := (i % 4) * 0.14
		if spec.layout == "dense":
			at = Vector2(-2.30 + (i % 8) * 0.16, -3.45 + ((i / 8) % 2) * 0.56)
			tier = i / 16
			yaw += PI * 0.5
		elif spec.layout == "shelf":
			at = Vector2(-2.38 + (i % 6) * 0.16, -3.49 + ((i / 6) % 2) * 0.37)
			tier = i / 12
		elif spec.layout == "near":
			at = Vector2(-1.15 + (i % 10) * 0.23, -1.10 - (i / 10) * 0.17)
		var piece := fire.receive_fuel([7, 8, 2, 10, 12, 9][i % 6], at, yaw, tier, 0.44 if i % 5 == 0 else 0.14)
		if i == 0:
			handled = piece
	fire.seat_new_stock()
	fire._settle()
	fire._refresh_storage_membership()
	fire._reindex()
	for i in range(12):
		story.step()
	if spec.mode.begins_with("family"):
		story.outcome = "prepared"
		story.begin_family()
		if spec.mode == "family_work":
			# Real autonomous family work using the fixture's Chapter III material stock.
			story.family.craft.starts_at = fire.time
			story.family.workshop.add("bone", 170, Chapter.Family.Workshop.HUNTER)
			story.family.workshop.add("meat", 120, Chapter.Family.Workshop.COOK)
	return handled

func _support_subject(fire: Fire, action: String) -> Fire.Piece:
	var stock := fire.stored.duplicate()
	stock.sort_custom(func(a, b): return a.id < b.id if a.height == b.height else a.height < b.height)
	if action == "support_top":
		return stock.back()
	if action in ["support_middle", "support_rotation"]:
		return stock[stock.size() / 2]
	if action == "support_bottom":
		return stock.front()
	# Pick the root whose removal affects the greatest number of support paths.
	var descendants := {}
	for piece in stock:
		for id in piece.pose.supports:
			if id > 0:
				descendants.get_or_add(id, []).append(piece.id)
	var root_piece: Fire.Piece = stock.front()
	var greatest := -1
	for piece in stock:
		var pending: Array = descendants.get(piece.id, []).duplicate()
		var visited := {}
		while not pending.is_empty():
			var id = pending.pop_back()
			if not visited.has(id):
				visited[id] = true
				pending.append_array(descendants.get(id, []))
		if visited.size() > greatest:
			greatest = visited.size()
			root_piece = piece
	return root_piece

func _support_action(fire: Fire, piece: Fire.Piece, action: String) -> void:
	var at := piece.at + Vector2(0.08, 0.10)
	var yaw := piece.axis.angle()
	if action in ["support_bottom", "support_collapse"]:
		at = Vector2(2.20, -2.96)
	elif action == "support_rotation":
		at = piece.at
		yaw += PI * 0.36
	fire.pose_fuel(piece, at, yaw, piece.lean, piece.tier, true)

func _structure_trace(spec: Dictionary) -> void:
	var story := Chapter.new(Fire.new())
	_setup(story, spec)
	var fire := story.fire
	var frames := []
	for i in range(2):
		story.step()
	var piece := _support_subject(fire, spec.mode)
	frames.append(_support_state(fire))
	_support_action(fire, piece, spec.mode)
	frames.append(_support_state(fire))
	for i in range(40):
		story.step()
		frames.append(_support_state(fire))
	_write({"id": spec.id, "subject": piece.id, "structure_trace": frames})

func _thermal_trace(spec: Dictionary) -> void:
	var story := Chapter.new(Fire.new())
	if spec.state == "ignition":
		story.fire.setup(Fire.COLD_CABIN)
		var leaves := story.fire.workable_tinder()
		var bundle := story.fire.prepare_tinder_bundle(leaves[0], leaves[1])
		story.fire.move_fuel(bundle, Vector2(0.019, 0))
		var ember := story.fire.coals[0]
		story.fire.lift_coal(ember)
		story.fire.deposit_coal(ember, bundle.at)
	else:
		_setup(story, spec)
	var fire := story.fire
	var states := []
	var peak_flame := 0.0
	for i in range(160):
		if spec.state == "ignition":
			fire.step()
		else:
			story.step()
		peak_flame = maxf(peak_flame, fire.total_flame())
		if i % 4 == 0:
			var state := [fire.time, fire.oxygen, fire.radiated, fire.absorbed, fire.evaporated_water, fire.received_water]
			for piece in fire.nodes + fire.all_fuel():
				state.append([piece.id, piece.temperature, piece.water, piece.wood, piece.char_mass, piece.flame, piece.gas])
			state.append(fire.links.map(func(link): return [link.a, link.b, link.conductance, link.view_a, link.view_b, link.receive_a, link.receive_b]))
			states.append(state)
	var row := {"id": spec.id, "peak_flame": peak_flame, "thermal_digest": JSON.stringify(states).sha256_text()}
	if write_trace:
		row["thermal_trace"] = states
	_write(row)

static func _support_state(fire: Fire) -> Array:
	var ordered := fire.all_fuel().duplicate()
	ordered.sort_custom(func(a, b): return a.id < b.id)
	var state := []
	for piece in ordered:
		state.append([piece.id, piece.at.x, piece.at.y, piece.axis.x, piece.axis.y, piece.pose.height, piece.pose.slope,
			piece.pose.span, Array(piece.pose.contacts).map(func(contact): return [contact.x, contact.y, contact.z]),
			Array(piece.pose.contact_ids), piece.airborne, piece.rolling, piece.roll_travel, piece.carried_load,
			piece.contact_load, piece.sections.map(func(section): return [section.contact_load, section.crushed])])
	return state

func _rendered_case(spec: Dictionary) -> void:
	lab = LabScene.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-benchmark-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	if spec.mode == "audio_off":
		lab.sound.set_process(false)
	lab.paused = true
	var story: Chapter = lab.chapter
	var handled := _setup(story, spec)
	if story.family != null:
		lab._open_family()
	var fire := story.fire
	bench = lab.view.workbench
	lab.view.set_tool(lab.view.Tool.WOOD)
	if diagnostic != null:
		diagnostic.force_reduced = spec.mode == "reduced"
	if spec.mode == "look_pile":
		bench.focus_on(Vector3(-1.67, 0.20, -2.98))
	lab.speed = spec.speed
	RenderingServer.viewport_set_measure_render_time(bench.stage.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await _wait_seconds(1.05)
	if spec.mode == "render_off":
		bench.stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
		bench.set_process(false)
	lab.paused = spec.mode in ["paused", "orbit"]
	var start_time := fire.time
	var start := Time.get_ticks_usec()
	var last_frame := start
	var last_action := start
	var snapshots: Array[Dictionary] = []
	var frames := PackedFloat64Array()
	var render_cpu := PackedFloat64Array()
	var render_gpu := PackedFloat64Array()
	var actions := PackedFloat64Array()
	var action_count := 0
	var preview_actions := PackedFloat64Array()
	var support_subject: Fire.Piece
	var peak_airborne := 0
	if diagnostic != null: diagnostic.begin(spec.mode == "reduced")
	var parked := handled.at if handled != null else Vector2.ZERO
	while float(last_frame - start) / 1e6 < elapsed:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last_frame) / 1000.0)
		last_frame = now
		if spec.mode == "orbit":
			bench.orbit(Vector2(1.9, 0.0))
		if spec.mode.begins_with("support_") and fire.time - start_time >= 0.5:
			if action_count == 0:
				support_subject = _support_subject(fire, spec.mode)
				var action_start := Time.get_ticks_usec()
				_support_action(fire, support_subject, spec.mode)
				actions.append((Time.get_ticks_usec() - action_start) / 1000.0)
				action_count += 1
			peak_airborne = maxi(peak_airborne, fire.all_fuel().filter(func(piece): return piece.airborne).size())
		if handled != null and spec.mode in ["move", "turn", "place"] and now - last_action > 140000:
			var action_start := Time.get_ticks_usec()
			var offset := Vector2(0.055, 0.03) if action_count % 2 == 0 else Vector2.ZERO
			match spec.mode:
				"move": fire.pose_fuel(handled, parked + offset, handled.axis.angle(), 0.0, 0, true)
				"turn": fire.turn_fuel(handled)
				"place": fire.pose_fuel(handled, Vector2(-0.48, 0.20) if action_count % 2 == 0 else parked, 0.3, 0.0, 0, true)
			actions.append((Time.get_ticks_usec() - action_start) / 1000.0)
			last_action = now
			action_count += 1
		if handled != null and spec.mode == "drag_preview" and now - last_action > 25000:
			var action_start := Time.get_ticks_usec()
			var at := parked + Vector2(cos(action_count * 0.21), sin(action_count * 0.21)) * 0.12
			bench.hit(lab.view.screen_at(at), handled)
			fire.preview(handled.kind, at, handled.axis.angle(), 0.0, handled.tier, handled.id, true)
			preview_actions.append((Time.get_ticks_usec() - action_start) / 1000.0)
			last_action = now
			action_count += 1
		var rid: RID = bench.stage.get_viewport_rid()
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		if snapshots.is_empty() or frames.size() % 10 == 0:
			var reading := _sample(fire)
			reading.family_jobs = 0 if story.family == null else story.family.craft.jobs.size()
			reading.log_mesh_nodes = bench.logs.values().reduce(func(sum, nodes): return sum + nodes.size(), 0)
			snapshots.append(reading)
	var phase_detail: Dictionary = {} if diagnostic == null else diagnostic.finish()
	var wall := (last_frame - start) / 1e6
	var result := spec.duplicate()
	result.merge({"wall_s": wall, "sim_s": fire.time - start_time, "raster": str(bench.stage.size),
		"end_positive_conduction": _positive_conduction(fire),
		"support_subject": 0 if support_subject == null else support_subject.id, "peak_airborne": peak_airborne,
		"start_active": snapshots[0].active, "end_active": fire.wood.size(), "end_outcome": story.outcome,
		"frames": _stats(frames), "render_cpu": _stats(render_cpu), "render_gpu": _stats(render_gpu),
		"actions": _stats(actions), "drag_preview": _stats(preview_actions), "readings": _aggregate(snapshots), "profile": phase_detail})
	_write(result)
	lab.free()
	await process_frame
	await process_frame

func _headless_case(spec: Dictionary) -> void:
	var story := Chapter.new(Fire.new())
	_setup(story, spec)
	var fire := story.fire
	var frames := PackedFloat64Array()
	var snapshots: Array[Dictionary] = []
	if diagnostic != null: diagnostic.begin()
	var start := Time.get_ticks_usec()
	var sim_start := fire.time
	while story.outcome.is_empty() and (frames.size() < 24 or ((Time.get_ticks_usec() - start) < elapsed * 1e6 and frames.size() < 160)):
		var at := Time.get_ticks_usec()
		story.step()
		frames.append((Time.get_ticks_usec() - at) / 1000.0)
		if frames.size() % 4 == 0:
			snapshots.append(_sample(fire))
	var detail: Dictionary = {} if diagnostic == null else diagnostic.finish()
	var row := spec.duplicate()
	row.merge({"wall_s": (Time.get_ticks_usec() - start) / 1e6, "sim_s": fire.time - sim_start,
		"end_positive_conduction": _positive_conduction(fire),
		"step": _stats(frames), "readings": _aggregate(snapshots), "profile": detail})
	_write(row)

static func _positive_conduction(fire: Fire) -> int:
	var count := 0
	for link in fire.links:
		if link.conductance > 0.0:
			count += 1
	return count

func _sample(fire: Fire) -> Dictionary:
	return {"active": fire.wood.size(), "stored": fire.stored.size(), "nodes": fire.nodes.size(),
		"pairs": fire.nodes.size() * (fire.nodes.size() - 1) / 2, "links": fire.links.size(),
		"narrow_candidates": fire.get("network_candidates") if "network_candidates" in fire else fire.nodes.size() * (fire.nodes.size() - 1) / 2,
		"radiant": fire.radiant_links.size(), "coal": fire.coals.size(),
		"steam_regions": fire.thermal_sources().filter(func(p): return p.vapor > 0.000006 and p.temperature > 25.0).size(),
		"flame": fire.total_flame(), "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"scene_nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "static_mem": Performance.get_monitor(Performance.MEMORY_STATIC),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"video_mem": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}

static func _aggregate(samples: Array[Dictionary]) -> Dictionary:
	var result := {}
	if not samples.is_empty():
		for key in samples[0]:
			var values := PackedFloat64Array()
			for row in samples: values.append(row[key])
			result[key] = _stats(values)
	return result

static func _stats(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	var sum := 0.0
	var spikes := 0
	for v in values:
		sum += v
		spikes += int(v > 33.333)
	var n := values.size()
	return {"n": n, "mean": sum / n, "p50": values[(n - 1) / 2], "p95": values[ceili(n * 0.95) - 1],
		"p99": values[ceili(n * 0.99) - 1], "max": values[-1], "over33": spikes}

func _wait_seconds(value: float) -> void:
	var end := Time.get_ticks_usec() + int(value * 1e6)
	while Time.get_ticks_usec() < end:
		await process_frame

func _write(row: Dictionary) -> void:
	log_file.store_line(JSON.stringify(row))
	log_file.flush()
	print(row.get("id", "setup"), " ", row.get("frames", row.get("step", {})))
