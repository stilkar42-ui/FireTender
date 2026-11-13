extends Control
## Every moving effect samples the model. Randomness is visual and seeded per object.

const Work := preload("res://sim/family_workshop.gd")
const Fire := preload("res://sim/fire.gd")
const Workbench := preload("res://hearth/construction_3d.gd")
const RAKE_RADIUS := 0.31
enum Tool { WOOD, ROLL, RAKE, BREATH, COAL, FEED, ASH }

var fire: Fire
var scenery: Workbench.Scenery
var placing := -1
var placing_piece: Fire.Piece
var dragging: Fire.Piece
var tool := Tool.WOOD
var gesture := false
var start := Vector2.ZERO
var began := 0.0
var strong := false
var breath_origin := Vector2.ZERO
var breath_target := Vector2.INF
var breath_strength := 0.84
var breath_duration := 1.15
var last_breath: Fire.Breath
var probe := Vector2(0, 1.35)
var probe_valid := false
var drag_offset := Vector2.ZERO
var selected: Fire.Piece
var build_yaw := INF
var build_lean := 0.0
var build_tier := 0
var drop_pose: Fire.Structure.Pose
var drop_tier := 0
var thermal_overlay := false
var workbench: Workbench
var snapping := true
var speaker_seat := Rect2()
var torch_seat := Rect2()
var torch_art: Texture2D
var torch_present := false
var material_grab := Vector2.INF
var material_hover := 0
var pointer := Vector2.ZERO
var grab_start := Vector2.ZERO
var drag_edited := false
var layer_override := false
var looking := false
var panning := false
var look_distance := 0.0
var seconds := 0.0
var speaker_art: Texture2D
var speaker_talking := false
var carried_coal: Fire.Piece
var coal_origin := Vector2.ZERO
var feed_pose: Fire.Structure.Pose
var feed_depth := 0.0
var feed_height := 0.035
var feed_blocked := false

signal placed(piece: Fire.Piece)
signal moved(piece: Fire.Piece)
signal rolled(piece: Fire.Piece)
signal arranged(piece: Fire.Piece)
signal raked(count: int, at: Vector2)
signal breathed(at: Vector2, strong: bool)
signal full
signal cancelled
signal speaker_selected
signal torch_selected
signal station_selected(station: String)
signal material_feedback(words: String)
signal material_placed(rest: String, at: Vector2)
signal coal_moved(at: Vector2)
signal blocked
signal ash_swept(mass: float)

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	workbench = Workbench.new()
	workbench.fire = fire
	workbench.scenery = scenery
	add_child(workbench)
	workbench.camera_changed.connect(_camera_moved)
	var portrait := "res://hearth/fire_speaker.svg"
	if ResourceLoader.exists(portrait):
		speaker_art = load(portrait) as Texture2D
	elif FileAccess.file_exists(portrait):
		var character := Image.new()
		if character.load_svg_from_string(FileAccess.get_file_as_string(portrait), 2.0) == OK:
			speaker_art = ImageTexture.create_from_image(character)
	var scout := "res://hearth/torch_bearer.png"
	if ResourceLoader.exists(scout):
		torch_art = load(scout) as Texture2D
	elif FileAccess.file_exists(scout):
		var drawing := Image.load_from_file(scout)
		if drawing != null and not drawing.is_empty():
			torch_art = ImageTexture.create_from_image(drawing)

func fit_scene(bounds: Vector2) -> void:
	size = bounds
	speaker_seat = Rect2(bounds - Vector2(184, 309), Vector2(154, 162))
	torch_seat = Rect2(28, bounds.y - 219, 108, 162)
	pointer = size * 0.5 if pointer == Vector2.ZERO else get_local_mouse_position()
	workbench.fit_scene(size)

func reset_scene() -> void:
	material_grab = Vector2.INF
	material_hover = 0
	looking = false
	panning = false
	carried_coal = null
	feed_pose = null
	feed_height = 0.035
	feed_depth = 0.0
	breath_target = Vector2.INF
	last_breath = null
	pointer = get_local_mouse_position()
	workbench.reset_scene()

func _process(delta: float) -> void:
	seconds += delta
	queue_redraw()

func toggle_snap() -> void:
	snapping = not snapping
	_refresh_drop()

func screen_at(at: Vector2) -> Vector2:
	return _project(Vector3(at.x, at.y, 0.0))

func _project(point: Vector3) -> Vector2:
	return workbench.project(point)

func _thermal_at(piece: Fire.Piece) -> Vector2:
	var lift := 0.0 if piece.kind < 0 else piece.height - Fire.Structure.radius(piece.kind) * 0.6
	return _project(Vector3(piece.at.x, piece.at.y, lift))

func select_material(kind: int, parcel: Fire.Piece = null) -> void:
	if kind >= 0:
		cancel_material()
	placing = kind
	placing_piece = parcel if parcel != null else (fire.stock_piece(kind) if kind >= 0 and fire.shelter != null else null)
	selected = null
	build_yaw = placing_piece.axis.angle() if placing_piece != null else INF
	build_lean = 0.0
	build_tier = 0
	layer_override = false
	feed_pose = null
	feed_depth = 0.0
	if tool == Tool.FEED and kind >= 0:
		feed_height = maxf(0.035, Fire.Structure.radius(kind) + 0.012)
	_refresh_drop()

func _begin_adjustment(piece: Fire.Piece) -> void:
	build_yaw = piece.axis.angle()
	build_lean = piece.lean
	build_tier = piece.tier
	layer_override = false
	if tool == Tool.FEED:
		feed_pose = piece.pose
		feed_height = piece.height
		feed_depth = 0.0

func adjust_build(direction: int, tilt: bool, layer: bool, fine := false,
		turn_radians := PI / 12.0, notify := true) -> bool:
	if tool not in [Tool.WOOD, Tool.FEED]:
		return false
	var piece := dragging if dragging != null else selected
	if placing < 0 and (piece == null or not fire.has_fuel(piece)):
		return false
	if dragging == null and placing < 0:
		_begin_adjustment(piece)
	if tool == Tool.FEED:
		if layer:
			feed_height = clampf(feed_height + direction * (0.003 if fine else 0.01), 0.012, 0.65)
		elif tilt:
			build_lean = clampf(build_lean + direction * (0.02 if fine else 0.06), -Fire.Structure.MAX_SLOPE, Fire.Structure.MAX_SLOPE)
		else:
			if is_inf(build_yaw):
				build_yaw = fire.default_yaw(fire.next_id)
			build_yaw = wrapf(build_yaw + direction * turn_radians / (3.0 if fine else 1.0), -PI, PI)
		if placing >= 0:
			feed_pose = null
		if dragging == null and placing < 0:
			var candidate := Fire.Feeding.pose(piece.at, piece.size, build_yaw, build_lean, feed_height)
			if not fire.feed_fuel(piece, candidate):
				blocked.emit()
			elif notify:
				arranged.emit(piece)
		else:
			_refresh_drop()
		return true
	if layer:
		if not layer_override and drop_pose != null:
			build_tier = drop_tier
		build_tier = clampi(build_tier + direction, -64, 64)
		layer_override = true
	elif tilt:
		build_lean = clampf(build_lean + direction * (0.08 if fine else 0.20), -Fire.Structure.MAX_SLOPE, Fire.Structure.MAX_SLOPE)
	else:
		if is_inf(build_yaw):
			build_yaw = fire.default_yaw(fire.next_id)
		build_yaw = wrapf(build_yaw + direction * turn_radians / (3.0 if fine else 1.0), -PI, PI)
	if dragging == null and placing < 0:
		fire.pose_fuel(piece, piece.at, build_yaw, build_lean, build_tier, true)
		if notify:
			arranged.emit(piece)
	else:
		drag_edited = dragging != null
		_refresh_drop()
	return true

func _refresh_drop() -> void:
	drop_pose = null
	drop_tier = build_tier
	if fire == null or (placing < 0 and dragging == null):
		return
	if tool == Tool.FEED:
		if probe_valid:
			_refresh_feed()
		return
	var target := workbench.hit(pointer, placing_piece if placing == Fire.TINDER_BUNDLE else dragging)
	if not target.point.is_finite():
		return
	var at := target.point if snapping else target.surface
	if target.piece != null and not layer_override and placing != Fire.TINDER_BUNDLE:
		drop_tier = maxi(drop_tier, target.piece.tier + 1)
	if placing == Fire.TINDER_BUNDLE and not layer_override:
		at = target.ground
		drop_tier = -1
	if snapping:
		at = at.snapped(Vector2(0.025, 0.025))
	if placing >= 0:
		var placeable := fire.in_hearth(at) or (fire.shelter != null and Fire.Shelter.YARD.has_point(at))
		if placeable:
			var yaw := fire.default_yaw(fire.next_id) if is_inf(build_yaw) else build_yaw
			var id := fire.next_id if placing_piece == null else placing_piece.id
			if fire.shelter == null or fire.has_fuel(placing_piece):
				drop_pose = fire.preview(placing, at, yaw, build_lean, drop_tier, id, true)
	elif dragging != null and fire.has_fuel(dragging):
		drop_pose = fire.preview(dragging.kind, at + drag_offset, build_yaw, build_lean, drop_tier, dragging.id, true)

func set_tool(next: int) -> bool:
	if carried_coal in fire.coals:
		var returned := false
		for radius in [0.0, 0.08, 0.16, 0.32, 0.50, 0.75]:
			for angle in range(16):
				var destination: Vector2 = coal_origin + Vector2.from_angle(TAU * angle / 16.0) * radius
				if fire.deposit_coal(carried_coal, destination):
					returned = true
					break
			if returned:
				break
		if not returned:
			blocked.emit()
			return false
	carried_coal = null
	tool = next
	gesture = false
	dragging = null
	drop_pose = null
	selected = null
	feed_pose = null
	feed_blocked = false
	return true

func _refresh_feed() -> void:
	var kind := placing if placing >= 0 else dragging.kind
	var piece := placing_piece if placing >= 0 else dragging
	var radius := Fire.Structure.radius(kind) if piece == null else piece.radius
	var length: float = Fire.SPECIES[kind].size if piece == null else piece.size
	var yaw := fire.default_yaw(fire.next_id) if is_inf(build_yaw) else build_yaw
	var axis := Vector2.from_angle(yaw)
	var span := length / sqrt(1.0 + build_lean * build_lean)
	var at := probe - axis * span if dragging == null else probe + drag_offset
	var goal := Fire.Feeding.pose(at + axis * feed_depth, length, yaw, build_lean, feed_height + feed_depth * build_lean)
	if feed_pose == null:
		var entry := ((goal.at - axis * (2.0 * length + 0.40)) / Fire.LIMIT).limit_length() * Fire.LIMIT
		feed_pose = Fire.Feeding.pose(entry, length, yaw, build_lean, feed_height)
	var safe := Fire.Feeding.sweep(fire, feed_pose, goal, radius, piece)
	feed_blocked = (safe == null or safe.at.distance_to(goal.at) > 0.004 or absf(safe.height - goal.height) > 0.004 or
		not safe.axis.is_equal_approx(goal.axis) or not is_equal_approx(safe.slope, goal.slope))
	if safe == null:
		feed_pose = null
		drop_pose = null
		return
	feed_pose = safe
	drop_pose = Fire.Feeding.rest(fire, safe, radius, piece)
	feed_blocked = feed_blocked or drop_pose == null
	if kind in [0, 4, 5]:
		feed_blocked = true
		drop_pose = null

func slide_feed(direction: int, fine := false) -> void:
	var distance := direction * (0.005 if fine else 0.025)
	if placing >= 0 or dragging != null:
		feed_depth += distance
		_refresh_drop()
	elif selected in fire.wood:
		var piece := selected
		var goal := Fire.Feeding.pose(piece.at + piece.axis * distance, piece.size, piece.axis.angle(),
			piece.lean, piece.height + piece.pose.slope * distance)
		if fire.feed_fuel(piece, goal):
			moved.emit(piece)
		else:
			blocked.emit()

func _gui_input(event: InputEvent) -> void:
	if fire == null:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer = event.position
		_update_probe()
		_update_material_pointer()
	if _camera_input(event):
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if adjust_build(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1,
			event.shift_pressed, event.ctrl_pressed, event.alt_pressed):
			accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and torch_present and torch_seat.has_point(event.position) and carried_coal == null and _wood_under(event.position) == null:
			torch_selected.emit()
			accept_event()
			return
		if tool == Tool.WOOD and placing < 0 and _material_click(event):
			accept_event()
			return
		if tool not in [Tool.WOOD, Tool.FEED]:
			_use_tool(event)
			accept_event()
			return
		if not event.pressed:
			if dragging != null:
				_refresh_drop()
				if drop_pose != null and (pointer.distance_to(grab_start) > 3.0 or drag_edited):
					if tool == Tool.FEED:
						if not feed_blocked and fire.feed_fuel(dragging, feed_pose):
							moved.emit(dragging)
						else:
							blocked.emit()
					else:
						if fire.pose_fuel(dragging, drop_pose.at, build_yaw, build_lean, drop_tier, true):
							moved.emit(dragging)
						else:
							full.emit()
				dragging = null
				drop_pose = null
			return
		if placing >= 0:
			_refresh_drop()
			if drop_pose == null:
				return
			if tool == Tool.FEED and feed_blocked:
				blocked.emit()
				return
			var added := _place_preview()
			if added == null:
				full.emit()
			else:
				placed.emit(added)
			return
		if speaker_seat.has_point(event.position) and _wood_under(event.position) == null:
			speaker_selected.emit()
			return
		dragging = _wood_under(event.position)
		selected = dragging
		if dragging != null:
			grab_start = pointer
			drag_edited = false
			var caught := workbench.hit(pointer).point
			drag_offset = dragging.at - caught
			_begin_adjustment(dragging)
			_refresh_drop()
	elif event is InputEventMouseMotion:
		if probe_valid and carried_coal in fire.coals:
			fire.carry_coal(carried_coal, probe)
		if dragging != null or placing >= 0:
			if tool == Tool.FEED and placing >= 0:
				feed_pose = null
				feed_depth = 0.0
			_refresh_drop()

func _material_click(event: InputEventMouseButton) -> bool:
	var props := workbench.family_props
	var model := props.model
	if model == null or dragging != null:
		return false
	if not event.pressed:
		if material_grab.is_finite():
			if pointer.distance_to(material_grab) > 8.0:
				_drop_material()
			material_grab = Vector2.INF
			return true
		return model.held != 0
	for station: String in props.labels:
		var label: Label3D = props.labels[station]
		var at := workbench.project(Vector3(label.position.x, label.position.z, label.position.y))
		if pointer.distance_to(at) < 14.0:
			station_selected.emit(station)
			return true
	if model.held != 0:
		if model.held_can_work(material_hover):
			_attempt_material(material_hover)
		else:
			_drop_material()
		return true
	if material_hover != 0 and model.reserved.has(material_hover):
		material_feedback.emit("That material is in use.")
		return true
	if material_hover != 0 and model.pick_up(material_hover):
		material_grab = pointer
		props.preview(workbench, pointer)
		material_feedback.emit(model.hand_note)
		return true
	var teacher := props.teacher_at(workbench, pointer)
	if not teacher.is_empty() and _wood_under(pointer) == null:
		station_selected.emit(teacher)
		return true
	return false

func _drop_material() -> void:
	var props := workbench.family_props
	var model := props.model
	var destination := props.destination(workbench, pointer)
	if destination.is_empty():
		material_feedback.emit("Move your hand over the cave floor or a working surface.")
		return
	var id := model.held
	if model.set_down(destination.at, destination.rest, destination.heat, material_hover):
		material_placed.emit(model.object_rest(id), model.object_position(id))
	material_feedback.emit(model.hand_note)

func _update_material_pointer() -> void:
	var props := workbench.family_props
	if props.model == null or tool != Tool.WOOD or placing >= 0:
		material_hover = 0
		return
	material_hover = props.pointer_item(workbench, pointer)
	props.preview(workbench, pointer)

func context_material() -> bool:
	if workbench.family_props.model == null or tool != Tool.WOOD or material_hover == 0:
		return false
	return _attempt_material(material_hover)

func _attempt_material(id: int) -> bool:
	var props := workbench.family_props
	var model := props.model
	model.hand_note = ""
	var success := props.family.craft.attempt(props.family, id) if props.family != null else model.work(id)
	if not model.hand_note.is_empty():
		material_feedback.emit(model.hand_note)
	elif success:
		material_feedback.emit("You work the material.")
	return success

func inspect_material() -> String:
	var model := workbench.family_props.model
	if model == null or tool != Tool.WOOD:
		return ""
	var id := material_hover if material_hover != 0 else model.held
	return model.inspect_object(id) if id != 0 else ""

func cancel_material() -> bool:
	var model := workbench.family_props.model
	if model == null or model.held == 0:
		return false
	model.cancel_hand()
	material_grab = Vector2.INF
	_update_material_pointer()
	material_feedback.emit("You put the material back where you lifted it.")
	return true

func _place_preview() -> Fire.Piece:
	if placing == Fire.TINDER_BUNDLE and placing_piece != null and fire.has_fuel(placing_piece):
		return placing_piece if fire.pose_fuel(placing_piece, drop_pose.at, build_yaw, build_lean, drop_tier, true) else null
	if fire.shelter == null:
		return fire.add_fed_fuel(placing, feed_pose) if tool == Tool.FEED else fire.add_fuel(placing, drop_pose.at, build_yaw, build_lean, drop_tier, true)
	if placing_piece == null or not fire.has_fuel(placing_piece) or fire.in_hearth(placing_piece.at):
		return null
	if tool == Tool.FEED:
		var landing := Fire.Feeding.rest(fire, feed_pose, placing_piece.radius, placing_piece)
		return placing_piece if landing != null and fire.feed_stock(placing_piece, landing) else null
	return placing_piece if fire.pose_fuel(placing_piece, drop_pose.at, build_yaw, build_lean, drop_tier, true) else null

func _camera_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		panning = event.pressed
		return true
	if event is InputEventMouseMotion and panning:
		workbench.pan(pointer - event.relative, pointer, event.shift_pressed)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			looking = true
			look_distance = 0.0
		else:
			if looking and look_distance < 4.0:
				cancelled.emit()
			looking = false
		return true
	if event is InputEventMouseMotion and looking:
		look_distance += event.relative.length()
		workbench.orbit(event.relative)
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not (event.shift_pressed or event.ctrl_pressed or event.alt_pressed):
			if tool == Tool.FEED and ((probe_valid and (placing >= 0 or dragging != null)) or selected in fire.wood):
				slide_feed(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				return true
			workbench.magnify(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			return true
	return false

func _camera_moved() -> void:
	_update_probe()
	_update_material_pointer()
	_refresh_drop()

func _update_probe() -> void:
	var target := workbench.ground_at(pointer)
	probe_valid = target.is_finite()
	if probe_valid:
		probe = Vector2(target.x, target.z)

func focus_camera() -> void:
	if carried_coal in fire.coals:
		workbench.focus_on(Vector3(carried_coal.at.x, carried_coal.height, carried_coal.at.y))
		return
	var piece := dragging if dragging != null else selected
	if piece != null and fire.has_fuel(piece):
		workbench.focus_on(workbench.world(piece.pose.point(0.0)))
	else:
		workbench.focus_on(workbench.ground_at(pointer))

func _use_tool(event: InputEventMouseButton) -> void:
	if tool == Tool.COAL:
		if event.pressed and carried_coal == null:
			var coal := workbench.hit_coal(event.position)
			if coal != null and fire.lift_coal(coal):
				carried_coal = coal
				coal_origin = coal.at
		elif not event.pressed and probe_valid and carried_coal in fire.coals:
			if fire.deposit_coal(carried_coal, probe):
				coal_moved.emit(probe)
				carried_coal = null
			else:
				blocked.emit()
		return
	if tool == Tool.ROLL:
		if event.pressed:
			var log := _wood_under(event.position, true)
			if log != null and fire.turn_fuel(log):
				rolled.emit(log)
		return
	if event.pressed:
		if not probe_valid:
			return
		start = probe
		began = seconds
		strong = event.shift_pressed
		gesture = true
		return
	if not gesture:
		return
	gesture = false
	if not probe_valid:
		return
	if tool == Tool.ASH:
		ash_swept.emit(fire.sweep_ash(start, fire.work_point(probe)))
	elif tool == Tool.RAKE:
		var destination := (probe / Fire.LIMIT).limit_length() * Fire.LIMIT
		var count := 0
		if start.distance_to(probe) > 0.035:
			count = fire.split_coal_at(start, destination) if strong else fire.rake_at(start, destination, RAKE_RADIUS)
		raked.emit(count, destination)
	else:
		var dragged := start.distance_to(probe) > 0.14
		if dragged or not breath_target.is_finite() or strong:
			breath_origin = start if dragged else probe + Vector2(0.0, 0.45)
			breath_target = probe
			breath_strength = 3.05 if strong else 0.84
			breath_duration = 0.85 + minf(seconds - began, 2.5)
		repeat_breath()

func breath_ready() -> bool:
	return last_breath == null or last_breath not in fire.breaths or last_breath.age >= last_breath.duration * 0.87

func repeat_breath() -> void:
	if not breath_target.is_finite() or not breath_ready():
		return
	last_breath = fire.send_breath(breath_origin, breath_target, breath_strength, breath_duration)
	if last_breath != null:
		breathed.emit(breath_target, breath_strength > 2.0)

func _wood_under(point: Vector2, logs_only := false) -> Fire.Piece:
	return workbench.hit(point, null, logs_only).piece

func _draw_material_hint() -> void:
	var model := workbench.family_props.model
	if model == null or mouse_filter != Control.MOUSE_FILTER_STOP or tool != Tool.WOOD or placing >= 0:
		return
	var words := ""
	if model.held != 0:
		words = model.object_label(model.held) + " in hand · Click to set down"
	elif material_hover != 0:
		words = model.object_label(material_hover)
		if model.reserved.has(material_hover):
			words += " · In use"
		var action := model.context_label(material_hover)
		if not action.is_empty() and not model.reserved.has(material_hover):
			words += " · V " + action.to_lower()
		if not words.is_empty():
			words += " · I inspect"
	if words.is_empty():
		return
	var font := get_theme_default_font()
	var extent := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var at := (pointer + Vector2(16, -30)).clamp(Vector2(8, 8), size - Vector2(extent.x + 22, 27))
	draw_rect(Rect2(at, Vector2(extent.x + 16, 26)), Color("#211811ed"))
	draw_string(font, at + Vector2(8, 18), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f0d6b4"))

func _draw() -> void:
	if fire == null:
		return
	_speaker()
	if torch_present and torch_art != null:
		draw_set_transform(Vector2(torch_seat.get_center().x, torch_seat.end.y - 6.0), 0.0, Vector2(1.0, 0.14))
		draw_circle(Vector2.ZERO, 45.0, Color(0.08, 0.06, 0.05, 0.43), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(torch_art, torch_seat, false, workbench.portrait_light(Vector2(-1.40, 0.35)))
	_air_threads()
	_draw_tool()
	_draw_material_hint()
	_draw_build_guide()
	if thermal_overlay:
		_draw_heat_overlay()

func _draw_build_guide() -> void:
	if drop_pose != null:
		_build_guide(drop_pose, true)
	elif tool in [Tool.WOOD, Tool.FEED] and selected != null and fire.has_fuel(selected):
		_build_guide(selected.pose, false)

func _draw_heat_overlay() -> void:
	var focus := selected.at if selected in fire.wood else probe
	for piece: Fire.Piece in fire.thermal_sources():
		if piece.at.distance_squared_to(focus) > 0.16:
			continue
		var surface := piece.faces[0] if piece.core != null else piece
		var point := _thermal_at(piece)
		if not point.is_finite():
			continue
		var heat := smoothstep(75.0, 900.0, surface.temperature)
		var tint := Color("#70b3d9").lerp(Color("#ff8c51"), heat)
		draw_circle(point, 6.0, Color(tint, 0.68))
		var label := "%.0f°  %.1f kW" % [surface.temperature, surface.radiation_in]
		var width := 100.0
		var extra := ""
		if piece.core != null:
			var inner := piece.inner[0] if not piece.inner.is_empty() else piece.core
			label = "Skin %.0f° / inner %.0f° / core %.0f°" % [surface.temperature, inner.temperature, piece.core.temperature]
			extra = "%.1f g water   %.0f%% intact" % [piece.water * 1000.0, piece.integrity * 100.0]
			width = 180.0
			point.y -= (piece.id % 3) * 22.0
		draw_rect(Rect2(point + Vector2(9, -18), Vector2(width, 19 if extra.is_empty() else 34)), Color(0.06, 0.05, 0.04, 0.86))
		draw_string(ThemeDB.fallback_font, point + Vector2(13, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
		if not extra.is_empty():
			draw_string(ThemeDB.fallback_font, point + Vector2(13, 11), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e6c29c"))

func _speaker() -> void:
	if speaker_art == null:
		return
	var at := speaker_seat.position
	at.y -= sin(seconds * 1.65) * 0.70
	draw_texture_rect(speaker_art, Rect2(at, speaker_seat.size), false,
		workbench.portrait_light(Vector2(1.18, 0.11)))
	if speaker_talking:
		var eye := at + speaker_seat.size * Vector2(0.556, 0.215)
		draw_line(eye - Vector2(1.8, 0), eye + Vector2(1.8, 0.3),
			Color(0.84, 0.61, 0.42, 0.25 + sin(seconds * 2.5) * 0.10), 1.0, true)

func _build_guide(pose: Fire.Structure.Pose, ghost: bool) -> void:
	var span := pose.span
	var left := _project(pose.point(-span))
	var right := _project(pose.point(span))
	if not left.is_finite() or not right.is_finite():
		return
	var ink := Color("#ecc48d") if ghost else Color(0.91, 0.73, 0.53, 0.58)
	if ghost and tool == Tool.FEED and feed_blocked:
		ink = Color("#e07a5b")
	if ghost:
		draw_line(left, right, Color(ink, 0.25), 20.0, true)
	draw_dashed_line(left, right, ink, 1.25, 7.0, true)
	for along in [-span, span]:
		var tip := pose.point(along)
		var ground := screen_at(Vector2(tip.x, tip.y))
		if ground.is_finite():
			draw_dashed_line(_project(tip), ground, Color(ink, 0.43), 1.0, 4.0, true)
	for contact in pose.contacts:
		var at := _project(contact)
		if contact.z > 0.022 and at.is_finite():
			draw_circle(at, 3.6, Color("#ecbe7d"))
	if tool == Tool.FEED:
		var tip := _project(pose.point(pose.span))
		draw_circle(tip, 4.0, ink)
		draw_line(tip, _project(pose.point(pose.span * 0.72)), ink, 2.4, true)
func _air_threads() -> void:
	for breath in fire.breaths:
		var side := breath.direction.orthogonal()
		for i in range(11):
			var fraction := fposmod(seconds * (1.2 + _hash(i) * 0.5) + float(i) / 11.0, 1.0)
			var range_along := 0.13 + fraction * breath.reach
			var point := breath.origin + breath.direction * range_along
			point += side * (_hash(i + 93) - 0.5) * (0.08 + range_along * 0.2)
			var velocity := fire.breath_at(point)
			var lift := Vector2(0, 8 + _hash(i + 12) * 9.0)
			var at := screen_at(point) - lift
			var tip := screen_at(point + velocity * 0.10) - lift
			var opacity := clampf(velocity.length() * 0.16, 0.0, 0.28) * sin(PI * fraction)
			if at.is_finite() and tip.is_finite():
				draw_line(at, tip, Color(0.73, 0.77, 0.73, opacity), 1.0, true)

func _draw_tool() -> void:
	var pointer := get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(pointer) and (tool != Tool.BREATH or not breath_target.is_finite()):
		return
	var tint := Color(0.91, 0.73, 0.52, 0.65)
	if tool == Tool.COAL:
		var coal := carried_coal if carried_coal in fire.coals else workbench.hit_coal(pointer)
		if coal != null:
			var at := _project(Vector3(coal.at.x, coal.at.y, coal.height + 0.02))
			if at.is_finite():
				draw_arc(at, 17.0, 0.0, TAU, 28, tint, 1.5, true)
			if coal.carried and at.is_finite() and probe_valid:
				draw_dashed_line(at, screen_at(probe), Color(tint, 0.5), 1.0, 4.0, true)
	elif tool in [Tool.RAKE, Tool.ASH]:
		if not probe_valid:
			return
		var target := start if gesture else probe
		var anchor := screen_at(target)
		if not anchor.is_finite():
			return
		var area := PackedVector2Array()
		var radius := 0.22 if tool == Tool.ASH else RAKE_RADIUS
		for i in range(32):
			var edge := screen_at(target + Vector2.from_angle(TAU * i / 32.0) * radius)
			if not edge.is_finite():
				return
			area.append(edge)
		draw_colored_polygon(area, Color(tint, 0.09))
		draw_arc(anchor, 13.0, 0.0, TAU, 24, tint, 1.1, true)
		if gesture:
			draw_dashed_line(anchor, pointer, tint, 1.0, 5.0, true)
	elif tool == Tool.BREATH:
		var target := probe if gesture or not breath_target.is_finite() else breath_target
		var source := start if gesture else (breath_origin if breath_target.is_finite() else probe + Vector2(0, 0.45))
		var origin := screen_at(source)
		var aim := screen_at(target)
		if origin.is_finite() and aim.is_finite():
			var aim_ink := Color("#dfaf77") if breath_ready() else Color("#aebfc0")
			draw_dashed_line(origin, aim, Color(aim_ink, 0.72), 1.4, 6.0, true)
			draw_arc(aim, 12.0, 0.0, TAU, 24, aim_ink, 1.15, true)
	elif tool == Tool.ROLL:
		var piece := _wood_under(pointer, true)
		if piece != null:
			var at := _project(piece.pose.point(0.0))
			if at.is_finite():
				draw_arc(at, 25.0, -PI * 0.80, PI * 0.82, 28, tint, 1.4, true)

func _hash(seed: int) -> float:
	return fposmod(sin(seed * 12.9898 + 78.233) * 43758.5453, 1.0)



