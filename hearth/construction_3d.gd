extends TextureRect
## A camera and a lightweight 3D renderer for the live Fire model.
## World Y is height. The simulation stores the two hearth coordinates in Piece.at.

const Fire := preload("res://sim/fire.gd")
const FamilyProps := preload("res://hearth/family_props.gd")
const Paint := preload("res://hearth/painted_material.gd")
const PLUME := preload("res://hearth/plume.gdshader")
const AirInk := preload("res://hearth/air_ink.gd")
const SOIL := preload("res://hearth/soil.gdshader")
const Scenery := preload("res://hearth/hearth_scenery.gd")
const HollowExterior := preload("res://hearth/hollow_exterior.gd")
const HEARTH_FOCUS := Vector3(0, 0.105, 0)
const BENCH_EYE := Vector3(0.40, 1.65, 1.60)
const BENCH_BOUNDS := AABB(Vector3(-3.20, 0.23, -3.20), Vector3(6.40, 2.37, 6.40))
const BENCH_FOV := 55.0
const ORBIT_SPEED := 0.009
const TILT_SPEED := 0.007

signal camera_changed

class Hit:
	var ground := Vector2.INF
	var point := Vector2.INF
	var surface := Vector2.INF
	var piece: Fire.Piece
	var section: Fire.Piece
	var face := 0
	var contact := Vector3.INF
	var depth := INF

var fire: Fire
var scenery: Scenery
var stage: SubViewport
var root: Node3D
var camera: Camera3D
var family_props: FamilyProps
var lamp: OmniLight3D
var eye := BENCH_EYE
var focus := HEARTH_FOCUS
var focus_target := HEARTH_FOCUS
var orbit_radius := 2.25
var yaw := 0.0
var tilt := 0.0
var zoom := BENCH_FOV
var zoom_target := BENCH_FOV
var logs := {}
var collisions := {}
var beds := {}
var plumes := {}
var steam_views := {}
var shell: ArrayMesh
var debris: Array[RigidBody3D] = []
var fibres: ArrayMesh
var stone: SphereMesh
var hearth_stone: ArrayMesh
var ash_shape: ArrayMesh
var coal_cluster: ArrayMesh
var stone_faces: PackedVector3Array
var coal_faces: PackedVector3Array
var sheet := QuadMesh.new()
var flame_sheet: ArrayMesh
var seconds := 0.0
var mood: Environment
var daylight: DirectionalLight3D
var cave: Node3D
var ground_set: Node3D
var exterior: HollowExterior
var floor_view: BoxMesh
var ledge: ArrayMesh
var ledge_stones: Node3D
var floor_node: MeshInstance3D
var soil: ShaderMaterial
var smoke_views := {}
var cave_ground: Material
var ash_views := {}
var ash_ink: ShaderMaterial
var rain_lines: MeshInstance3D
var rain_impacts: MeshInstance3D
var spark_lines: MeshInstance3D
var wind_lines: MeshInstance3D
var effects_step := -INF
var effects_clock := 0.0
var ground_sparks: Array[Dictionary] = []
var pop_marks: Array[Dictionary] = []
var last_revision := -1
var last_weather := -1
var camera_dirty := true
var lamp_power := 0.0
var raster_scale := Vector2.ONE
var refresh_interval := 0.0
var refresh_left := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	stage = SubViewport.new()
	stage.own_world_3d = true
	stage.msaa_3d = Viewport.MSAA_DISABLED
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	texture = stage.get_texture()
	root = Node3D.new()
	stage.add_child(root)
	_create_scene()
	family_props = FamilyProps.new()
	family_props.camera = camera
	root.add_child(family_props)
	fire.structure_event.connect(_structure_event)
	fire.spark_grounded.connect(_ground_spark)

func replace_fire(model: Fire) -> void:
	fire.structure_event.disconnect(_structure_event)
	fire.spark_grounded.disconnect(_ground_spark)
	fire = model
	fire.structure_event.connect(_structure_event)
	fire.spark_grounded.connect(_ground_spark)
	last_revision = -1

func reset_scene() -> void:
	for chunk in debris:
		if is_instance_valid(chunk):
			chunk.queue_free()
	debris.clear()
	ground_sparks.clear()
	pop_marks.clear()
	effects_step = -INF
	refresh_left = 0.0
	reset_camera()
	_refresh(0.0)
	if refresh_interval > 0.0:
		stage.render_target_update_mode = SubViewport.UPDATE_ONCE

func fit_scene(bounds: Vector2) -> void:
	size = bounds
	_fit_raster()

func _fit_raster() -> void:
	var density := 1.0 if refresh_interval == 0.0 else 0.68
	stage.size = Vector2i((size * density).round())
	raster_scale = Vector2(stage.size) / size
	camera_dirty = true
	camera_changed.emit()

func _create_scene() -> void:
	var profile := Vector3.ONE
	shell = _wood_mesh(profile, profile, profile, Vector3.ZERO, 0, 0, 1, 1)
	fibres = _fibres_mesh()
	stone = SphereMesh.new()
	stone.radial_segments = 13
	stone.rings = 7
	hearth_stone = _weathered_stone()
	ash_shape = _ash_mound()
	coal_cluster = _coal_mesh()
	flame_sheet = _make_flame_sheet()
	stone_faces = stone.get_faces()
	coal_faces = coal_cluster.get_faces()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.near = 0.02
	camera.far = 44.0
	root.add_child(camera)
	camera.make_current()
	reset_camera()

	mood = Environment.new()
	mood.background_mode = Environment.BG_COLOR
	mood.background_color = Color("#1b1816")
	mood.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	mood.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	mood.ambient_light_color = Color("#e6d0bc")
	mood.ambient_light_energy = 0.58
	camera.environment = mood
	daylight = DirectionalLight3D.new()
	daylight.rotation_degrees = Vector3(-56, -35, 0)
	daylight.light_color = Color("#d4e0e8")
	daylight.light_energy = 0.68
	daylight.shadow_enabled = true
	daylight.shadow_blur = 3.0
	daylight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	daylight.directional_shadow_max_distance = 6.0
	root.add_child(daylight)
	lamp = OmniLight3D.new()
	lamp.light_color = Color("#efad79")
	lamp.omni_range = 1.65
	lamp.omni_attenuation = 1.18
	root.add_child(lamp)

	floor_view = BoxMesh.new()
	floor_view.size = Vector3(12, 0.16, 12)
	soil = ShaderMaterial.new()
	soil.shader = SOIL
	cave_ground = scenery.ground.duplicate() if scenery.ground != null else soil
	Paint.bind_brush(soil, "earth", 0.84, 0.34)
	var painted_shelter_floor: bool = cave_ground is ShaderMaterial and cave_ground.shader == preload("res://hearth/valley_soil.gdshader")
	if painted_shelter_floor:
		Paint.bind_brush(cave_ground, "earth", 0.96, 0.34)
	var hearth_paint := Paint.ART + "hearth-clay.png"
	if ResourceLoader.exists(hearth_paint):
		var paint := load(hearth_paint)
		soil.set_shader_parameter("hearth_paint", paint)
		soil.set_shader_parameter("has_hearth_paint", true)
		if painted_shelter_floor:
			cave_ground.set_shader_parameter("hearth_paint", paint)
			cave_ground.set_shader_parameter("has_hearth_paint", true)
	ledge = HollowExterior.ledge()
	floor_node = _mesh(floor_view, soil)
	floor_node.position.y = -0.088
	ledge_stones = Node3D.new()
	ledge_stones.name = "LooseLedgeStone"
	floor_node.add_child(ledge_stones)
	ledge_stones.hide()
	# The solid backing closes the underside of the shelf at grazing angles.
	var backing := MeshInstance3D.new()
	backing.mesh = HollowExterior.ledge_backing()
	backing.material_override = Paint.style(Paint.Surface.STONE, Color("#4a3d33"))
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ledge_stones.add_child(backing)
	if scenery.ground_scene != null:
		ground_set = scenery.ground_scene.instantiate() as Node3D
		root.add_child(ground_set)
		ground_set.hide()
	var bed_collision := StaticBody3D.new()
	bed_collision.collision_mask = 0
	root.add_child(bed_collision)
	bed_collision.position.y = -0.088
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = floor_view.size
	ground_shape.shape = ground_box
	bed_collision.add_child(ground_shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4131
	for i in range(23):
		var angle := TAU * i / 23.0
		var rock := _mesh(hearth_stone, Paint.style(Paint.Surface.STONE, Color("#75695d").darkened(rng.randf_range(0.0, 0.18))))
		rock.material_override.set_shader_parameter("brush_seed", float(i) * 0.17)
		rock.position = Vector3(cos(angle) * 1.036, 0.038, sin(angle) * 0.90)
		rock.rotation.y = angle + rng.randf_range(-0.3, 0.3)
		rock.rotation.x = 0.15 * sin(angle * 7.0)
		rock.scale = Vector3(rng.randf_range(0.15, 0.22), rng.randf_range(0.085, 0.143), rng.randf_range(0.13, 0.18))
	var gravel := MultiMesh.new()
	gravel.transform_format = MultiMesh.TRANSFORM_3D
	gravel.use_colors = true
	gravel.mesh = stone
	gravel.instance_count = 244
	for i in range(gravel.instance_count):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(0.24, 1.65)
		var scale := rng.randf_range(0.007, 0.025)
		gravel.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(scale, scale * 0.44, scale)),
			Vector3(cos(angle) * distance, -0.003, sin(angle) * distance * 0.89)))
		gravel.set_instance_color(i, Color("#574338").lerp(Color("#211c19"), rng.randf()))
	var pebbles := MultiMeshInstance3D.new()
	pebbles.multimesh = gravel
	pebbles.material_override = Paint.style(Paint.Surface.STONE, Color.WHITE, true)
	pebbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pebbles)
	var spark_ink := StandardMaterial3D.new()
	spark_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_ink.vertex_color_use_as_albedo = true
	spark_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	rain_lines = _mesh(ImmediateMesh.new(), spark_ink)
	rain_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_impacts = _mesh(ImmediateMesh.new(), spark_ink)
	rain_impacts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark_lines = _mesh(ImmediateMesh.new(), spark_ink)
	spark_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wind_lines = _mesh(ImmediateMesh.new(), spark_ink)
	wind_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cave = scenery.set_scene.instantiate() as Node3D if scenery.set_scene != null else Node3D.new()
	root.add_child(cave)
	exterior = HollowExterior.new()
	exterior.scenery = scenery
	exterior.name = "AuthoredExterior"
	cave.add_child(exterior)
	cave.hide()
	ash_ink = Paint.style(Paint.Surface.ASH, Color("#b0a393"))

func reset_camera() -> void:
	var in_shelter := fire.shelter != null
	focus = scenery.home_target if in_shelter else HEARTH_FOCUS
	focus_target = focus
	var home := scenery.home_eye if in_shelter else BENCH_EYE
	var offset := home - focus
	orbit_radius = offset.length()
	yaw = atan2(offset.x, offset.z)
	tilt = asin(offset.y / orbit_radius)
	zoom = scenery.field_of_view if in_shelter else BENCH_FOV
	zoom_target = zoom
	_update_camera()

func orbit(delta: Vector2) -> void:
	yaw = wrapf(yaw - delta.x * ORBIT_SPEED, -PI, PI)
	tilt = clampf(tilt + delta.y * TILT_SPEED, deg_to_rad(-89.0), deg_to_rad(84.0))
	_update_camera()

func magnify(direction: int) -> void:
	zoom_target = clampf(zoom_target * pow(0.88, direction), 16.0, 82.0)

func pan(from: Vector2, to: Vector2, change_height := false) -> void:
	var delta := to - from
	if change_height:
		tilt = clampf(tilt - delta.y * 0.008, 0.06, deg_to_rad(84.0))
	else:
		var scale_per_pixel := 2.0 * orbit_radius * tan(deg_to_rad(zoom * 0.5)) / maxf(1.0, size.y)
		var offset := Vector3(-delta.x, 0, -delta.y).rotated(Vector3.UP, yaw) * scale_per_pixel
		var start := _pan_plane(from)
		var end := _pan_plane(to)
		if tilt > 0.25 and start.is_finite() and end.is_finite():
			offset = (start - end).limit_length(offset.length() * 2.5)
		focus = _bounded_focus(focus + offset)
		focus_target = focus
	_update_camera()

func _pan_plane(screen: Vector2) -> Vector3:
	var pixel := screen * raster_scale
	var origin := camera.project_ray_origin(pixel)
	var ray := camera.project_ray_normal(pixel)
	if ray.y >= -0.02:
		return Vector3.INF
	return origin + ray * ((focus.y - origin.y) / ray.y)

func pan_direction(direction: Vector2, delta: float) -> void:
	var travel := Vector3(direction.x, 0.0, direction.y).rotated(Vector3.UP, yaw)
	var target := _bounded_focus(focus + travel * 1.72 * delta)
	if target != focus:
		focus = target
		focus_target = target
		_update_camera()

func focus_on(point: Vector3) -> void:
	if point.is_finite():
		focus_target = _bounded_focus(point)

func _bounded_focus(point: Vector3) -> Vector3:
	if fire.shelter == null:
		return point.clamp(Vector3(-1.42, 0, -1.42), Vector3(1.42, 1.15, 1.42))
	return point.clamp(scenery.focus_bounds.position, scenery.focus_bounds.end)

func _ease_camera(delta: float) -> void:
	if focus == focus_target and zoom == zoom_target:
		return
	var blend := 1.0 - exp(-15.0 * delta)
	focus = focus.lerp(focus_target, blend)
	zoom = lerpf(zoom, zoom_target, blend)
	if focus.distance_squared_to(focus_target) < 0.000001:
		focus = focus_target
	if absf(zoom - zoom_target) < 0.001:
		zoom = zoom_target
	_update_camera()

func _update_camera() -> void:
	# Keep the orbit above the floor at low angles, then let the lens tilt
	# upward from that same position all the way to the sky.
	var arm_tilt := maxf(tilt, 0.16 if fire.shelter != null else 0.06)
	var axis := Vector3(sin(yaw) * cos(arm_tilt), sin(arm_tilt), cos(yaw) * cos(arm_tilt))
	eye = focus + axis * _clear_orbit_distance(axis)
	camera.position = eye
	camera.rotation = Vector3(-tilt, yaw, 0.0)
	camera.fov = zoom
	camera_dirty = true
	camera_changed.emit()

func _clear_orbit_distance(axis: Vector3) -> float:
	var distance := orbit_radius
	var bounds := BENCH_BOUNDS if fire.shelter == null else scenery.eye_bounds
	var depth := 0.0 if fire.shelter == null else -float(Fire.Shelter.DEPTHS[fire.shelter.site])
	var low := bounds.position + Vector3(0, 0, depth)
	for index in [0, 1, 2]:
		if axis[index] > 0.001:
			distance = minf(distance, (bounds.end[index] - focus[index]) / axis[index])
		elif axis[index] < -0.001:
			distance = minf(distance, (low[index] - focus[index]) / axis[index])
	if fire.shelter != null:
		var origin := focus - Vector3(0, 0, depth)
		var end := origin + axis * maxf(distance, 0.0)
		for obstacle in scenery.camera_obstacles:
			var contact: Variant = obstacle.intersects_segment(origin, end)
			if contact is Vector3:
				distance = minf(distance, origin.distance_to(contact) - 0.10)
	return maxf(0.08, distance)
static func world(model_point: Vector3) -> Vector3:
	return Vector3(model_point.x, model_point.z, model_point.y)

func project(model_point: Vector3) -> Vector2:
	var point := world(model_point)
	return Vector2.INF if camera.is_position_behind(point) else camera.unproject_position(point) / raster_scale

func ground_at(screen: Vector2) -> Vector3:
	var pixel := screen * raster_scale
	return _floor_hit(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))

func _floor_hit(origin: Vector3, ray: Vector3) -> Vector3:
	if ray.y >= -0.001:
		return Vector3.INF
	var floor := origin + ray * (-origin.y / ray.y)
	var work_area := Fire.Shelter.YARD.grow(0.14) if fire.shelter != null else Rect2(-5.98, -5.98, 11.96, 11.96)
	return Vector3(floor.x, 0.0, floor.z) if work_area.has_point(Vector2(floor.x, floor.z)) else Vector3.INF

func hit(screen: Vector2, ignored: Fire.Piece = null, logs_only := false) -> Hit:
	var result := Hit.new()
	var pixel := screen * raster_scale
	var origin := camera.project_ray_origin(pixel)
	var normal := camera.project_ray_normal(pixel)
	var floor := _floor_hit(origin, normal)
	result.ground = Vector2(floor.x, floor.z)
	result.point = result.ground
	result.surface = result.ground
	for piece in fire.all_fuel():
		if piece == ignored or piece.pose == null or (logs_only and piece.core == null):
			continue
		var count := maxi(1, piece.sections.size())
		for i in range(count):
			var section := piece if piece.sections.is_empty() else piece.sections[i]
			var offset := (section.upper_radius - section.lower_radius) * 0.5
			var a := world(piece.pose.point(piece.pose.span * (2.0 * i / count - 1.0), offset))
			var b := world(piece.pose.point(piece.pose.span * (2.0 * (i + 1) / count - 1.0), offset))
			var nearest := Geometry3D.get_closest_points_between_segments(origin, origin + normal * 12.0, a, b)
			var radius := section.radius + 0.009
			var gap := nearest[0].distance_squared_to(nearest[1])
			if gap > radius * radius:
				continue
			var depth := origin.distance_to(nearest[0]) - sqrt(radius * radius - gap)
			if depth > camera.near and depth < result.depth:
				result.depth = depth
				result.piece = piece
				result.section = section
				result.point = Vector2(nearest[1].x, nearest[1].z)
				var surface := origin + normal * depth
				result.surface = Vector2(surface.x, surface.z)
				result.contact = surface
				var along := (result.surface - piece.pose.at).dot(piece.pose.axis)
				result.face = int(surface.y < piece.pose.point(along).z)
	return result

func touch_at(screen: Vector2) -> Hit:
	var result := hit(screen)
	var pixel := screen * raster_scale
	var origin := camera.project_ray_origin(pixel)
	var ray := camera.project_ray_normal(pixel)
	for coal in fire.coals:
		var amount := _coal_amount(coal)
		if amount <= 0.0003:
			continue
		var center := Vector3(coal.at.x, coal.height + 0.015, coal.at.y)
		var scale := _coal_scale(coal, amount)
		var shape := _coal_shape(coal)
		var local_origin := (origin - center) / scale
		var local_ray := ray / scale
		if shape.get_aabb().intersects_ray(local_origin, local_ray) == null:
			continue
		var faces := stone_faces if shape == stone else coal_faces
		for i in range(0, faces.size(), 3):
			var point: Variant = Geometry3D.ray_intersects_triangle(local_origin, local_ray,
				faces[i], faces[i + 1], faces[i + 2])
			if point is Vector3:
				var contact: Vector3 = point * scale + center
				var depth := (contact - origin).dot(ray)
				if depth > camera.near and depth < result.depth:
					result.depth = depth
					result.piece = coal
					result.section = null
					result.contact = contact
	return result

func hit_coal(screen: Vector2) -> Fire.Piece:
	var pixel := screen * raster_scale
	var origin := camera.project_ray_origin(pixel)
	var ray := camera.project_ray_normal(pixel)
	var closest := INF
	var picked: Fire.Piece
	for coal in fire.coals:
		var center := Vector3(coal.at.x, coal.height + 0.016, coal.at.y)
		var along := (center - origin).dot(ray)
		if along <= camera.near:
			continue
		var radius := maxf(0.025, coal.size * 0.36)
		var offset := (origin + ray * along).distance_squared_to(center)
		if offset < radius * radius and along < closest:
			var obstruction := hit(screen)
			if obstruction.piece != null and obstruction.piece.kind not in [4, 5]:
				var wood_center := world(obstruction.piece.pose.point(0.0))
				if (wood_center - origin).dot(ray) < along - radius:
					continue
			picked = coal
			closest = along
	return picked

func _process(delta: float) -> void:
	_ease_camera(delta)
	if refresh_interval > 0.0:
		refresh_left -= delta
		if refresh_left > 0.0 and not camera_dirty:
			seconds += delta
			return
		refresh_left = refresh_interval
		stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	_refresh(delta)

func set_acceleration(multiplier: int) -> void:
	var interval := 0.0
	if multiplier >= 16:
		interval = 0.083 if multiplier >= 64 else 0.055
	if interval == refresh_interval:
		return
	refresh_interval = interval
	refresh_left = 0.0
	_fit_raster()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS if interval == 0.0 else SubViewport.UPDATE_ONCE

func _refresh(delta: float) -> void:
	if fire == null:
		return
	seconds += delta
	if last_revision == fire.revision and last_weather == fire.weather and not camera_dirty:
		_ambient_effects()
		return
	last_revision = fire.revision
	last_weather = fire.weather
	camera_dirty = false
	var alive := {}
	var sources := {}
	var steam_sources := {}
	var strongest := 0.0
	var luminous := Vector3(0, 0.14, 0)
	for piece in fire.all_fuel():
		if piece.pose == null:
			continue
		var key := piece.get_instance_id()
		alive[key] = true
		if not logs.has(key):
			_create_log(piece)
		elif logs[key].size() != maxi(1, piece.sections.size()):
			for node in logs[key]:
				node.queue_free()
			_create_log(piece)
		var first: MeshInstance3D = logs[key][0]
		var is_stored := piece in fire.stored
		var moisture := _face_moisture(piece) if is_stored else PackedFloat32Array()
		if not is_stored or not first.has_meta("stored_pose") or first.get_meta("stored_pose") != piece.pose or first.get_meta("stored_moisture") != moisture:
			_update_log(piece, logs[key])
			first.set_meta("stored_pose", piece.pose)
			first.set_meta("stored_moisture", moisture)
		if piece.sections.is_empty():
			_show_steam(piece, steam_sources)
		for section in piece.sections:
			for face in section.faces:
				_show_steam(face, steam_sources)
	for p in fire.thermal_sources():
		var key := p.get_instance_id()
		sources[key] = true
		if p.kind < 0:
			if not beds.has(key):
				beds[key] = _mesh(stone if p.size < 0.09 else coal_cluster, Paint.style(Paint.Surface.CHARCOAL, Color.WHITE, true))
			_update_bed(p, beds[key])
			_show_steam(p, steam_sources)
		if p.flame > 0.20:
			if not plumes.has(key):
				plumes[key] = _sheet(false)
			_update_flame(p, plumes[key])
		elif plumes.has(key):
			plumes[key].hide()
		var power := fire.radiant_power(p)
		if power > strongest:
			strongest = power
			var drift := p.draft.limit_length(1.8) * smoothstep(0.0, 28.0, p.flame) * 0.13
			luminous = Vector3(p.at.x + drift.x, maxf(p.height + 0.14, 0.16), p.at.y + drift.y)
	_prune(logs, alive)
	_prune(collisions, alive)
	_prune(beds, sources)
	_prune(plumes, sources)
	_prune(steam_views, steam_sources)
	_update_ash()
	lamp.position = luminous
	lamp_power = clampf(strongest * 1.15, 0.0, 1.94)
	mood.ambient_light_energy = 0.50 if fire.weather == 3 else 0.58
	_ambient_effects()

func _ambient_effects() -> void:
	if effects_step != fire.time:
		effects_step = fire.time
		effects_clock = seconds
	lamp.light_energy = lamp_power * (0.94 + 0.06 * sin(seconds * 9.4))
	_update_shelter()
	family_props.light_field = lamp
	family_props.sky_fill = mood.ambient_light_color
	family_props.sky_energy = mood.ambient_light_energy
	_update_rain()
	_update_sparks()
	_update_smoke()
	_update_wind()

func portrait_light(at: Vector2) -> Color:
	return Paint.cutout_light(Vector3(at.x, 0.40, at.y), mood.ambient_light_color, mood.ambient_light_energy, lamp)

func _update_shelter() -> void:
	var shelter := fire.shelter
	var in_shelter := shelter != null
	if cave.visible != in_shelter:
		cave.visible = in_shelter
		mood.sky = exterior.overhead if in_shelter else null
		mood.background_mode = Environment.BG_SKY if in_shelter else Environment.BG_COLOR
		floor_node.mesh = ledge if in_shelter else floor_view
		floor_node.position.y = 0.0 if in_shelter else -0.088
		ledge_stones.visible = in_shelter
		if ground_set != null:
			ground_set.visible = in_shelter
		floor_node.material_override = cave_ground if in_shelter else soil
		lamp.omni_range = 2.08 if in_shelter else 1.65
	if shelter == null:
		mood.ambient_light_color = Color("#e6d0bc")
		daylight.light_energy = 0.68
		return
	var depth: float = -Fire.Shelter.DEPTHS[shelter.site]
	if cave.position.z != depth:
		cave.position.z = depth
		if cave.has_method("align_floor"):
			cave.align_floor()
		_update_camera()
	lamp.omni_range = lerpf(2.18, 4.05, smoothstep(0.32, 1.85, lamp_power))
	var sky_light: float = shelter.sky_light()
	mood.ambient_light_energy = 0.22 + 0.43 * sky_light * (1.0 - shelter.cloud * 0.41)
	mood.ambient_light_color = Color("#95a2b7").lerp(Color("#ead7c4"), shelter.light * (1.0 - shelter.cloud))
	daylight.light_energy = 0.06 + 0.42 * sky_light * (1.0 - shelter.cloud * 0.72)
	exterior.light_scene(shelter, fire.time, sky_light)

func _update_sparks() -> void:
	var mesh := spark_lines.mesh as ImmediateMesh
	mesh.clear_surfaces()
	while not ground_sparks.is_empty() and seconds - float(ground_sparks[0].at) > 0.96:
		ground_sparks.pop_front()
	while not pop_marks.is_empty() and seconds - float(pop_marks[0].at) > 0.33:
		pop_marks.pop_front()
	if fire.sparks.is_empty() and ground_sparks.is_empty() and pop_marks.is_empty():
		return
	var fraction := 1.0 if refresh_interval > 0.0 else clampf((seconds - effects_clock) / Fire.STEP, 0.0, 1.0)
	var facing := camera.global_basis.z
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for fragment in fire.sparks:
		_paint_spark(mesh, fragment, facing, fraction)
	for mark in ground_sparks:
		var age := seconds - float(mark.at)
		var fragment: Fire.Spark = mark.spark
		if age < Fire.STEP:
			_paint_spark(mesh, fragment, facing, age / Fire.STEP)
		else:
			var point := world(fragment.position) + Vector3.UP * 0.015
			AirInk.cinder(mesh, point, camera.global_basis.y, facing, 0.015, 0.39,
				1.0 - smoothstep(0.27, 0.96, age), 0.35)
	for mark in pop_marks:
		var age := (seconds - float(mark.at)) / 0.33
		var point: Vector3 = mark.point
		var ink := Color("#ffb465") if mark.hot else Color("#ddd9c8")
		for ray: float in [-1.0, -0.2, 0.76]:
			var direction := (camera.global_basis.y + camera.global_basis.x * ray * 1.6).normalized()
			var reach := float(mark.size) * (0.35 + age * 1.6)
			AirInk.ribbon(mesh, point + direction * reach, point + direction * (reach + 0.034), facing,
				0.005, 0.001, Color(ink, (1.0 - age) * 0.76))
	mesh.surface_end()

func _paint_spark(mesh: ImmediateMesh, spark: Fire.Spark, facing: Vector3, fraction: float) -> void:
	var at := world(spark.position)
	var flying := spark.flight.size() > 1 and (spark.surface == null or fraction < 1.0)
	var heat := smoothstep(210.0, 720.0, spark.temperature)
	var size_scale := lerpf(0.015, 0.033, smoothstep(0.00008, 0.0012, spark.mass))
	var up := camera.global_basis.y
	var opacity := 0.48 + heat * 0.52
	if flying:
		at = world(_flight_point(spark.flight, fraction))
		var tail := world(_flight_point(spark.flight, maxf(0.0, fraction - 0.48)))
		if at.distance_squared_to(tail) > 0.00001:
			AirInk.ribbon(mesh, tail, at, facing, 0.001, size_scale * 0.24, Color("#e45b27", opacity * 0.58))
		var drift := world(spark.velocity).slide(facing).limit_length(3.0)
		up = (up - drift * 0.21).normalized()
	else:
		size_scale *= 0.55
		opacity *= 1.0 - smoothstep(2.5, 4.5, spark.contact_age)
	AirInk.cinder(mesh, at + Vector3.UP * 0.008, up, facing, size_scale, heat, opacity,
		sin(seconds * 19.0 + spark.source) * 0.42)

func _flight_point(path: PackedVector3Array, fraction: float) -> Vector3:
	var along := fraction * (path.size() - 1)
	var first := mini(floori(along), path.size() - 2)
	return path[first].lerp(path[first + 1], along - first)

func _ground_spark(fragment: Fire.Spark) -> void:
	if refresh_interval == 0.0:
		ground_sparks.append({"spark": fragment, "at": seconds})

func _update_wind() -> void:
	var mesh := wind_lines.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if refresh_interval > 0.0:
		return
	var started := false
	var facing := camera.global_basis.z
	for i in range(40):
		var cell := Vector2(i % 8, floori(i / 8.0))
		var jitter := Vector2(fposmod(i * 0.618033, 1.0), fposmod(i * 0.263932 + 0.17, 1.0))
		var spread := (cell + jitter) * Vector2(0.60, 0.85) - Vector2(2.55, 3.05)
		var height := 0.052 + 0.052 * fposmod(i * 0.172, 1.0)
		var flow := fire.background_wind(spread, height)
		var speed := flow.length()
		if speed < 0.037:
			continue
		var phase := fposmod(seconds * (0.17 + speed * 0.49) + i * 0.417, 1.0)
		var at := spread + flow * (phase - 0.5) * 0.64
		var local := fire.background_wind(at, height)
		var opacity := smoothstep(0.03, 0.53, local.length()) * sin(phase * PI)
		if opacity < 0.02:
			continue
		if not started:
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			started = true
		var vector := local.normalized() * lerpf(0.095, 0.32, clampf(local.length(), 0.0, 1.0))
		var beginning := Vector3(at.x, height, at.y)
		var end := beginning + Vector3(vector.x, 0.002, vector.y)
		var side := Vector3(-vector.y, 0.0, vector.x).normalized()
		var ink := Color(Color("#dbccab"), opacity * 0.54)
		var previous := beginning
		var previous_width := 0.0005
		for j in range(1, 6):
			var t := j / 5.0
			var taper := sin(t * PI)
			var point := beginning.lerp(end, t) + Vector3.UP * (0.015 * taper)
			point += side * (0.023 * taper * sin(TAU * t + i * 0.81))
			var width := 0.0005 + 0.0046 * taper
			AirInk.ribbon(mesh, previous, point, facing, previous_width, width, ink)
			previous = point
			previous_width = width
	if started:
		mesh.surface_end()

func _update_ash() -> void:
	for cell: Vector2i in fire.ash_piles:
		var node: MeshInstance3D = ash_views.get(cell)
		if node == null:
			node = _mesh(ash_shape, ash_ink)
			ash_views[cell] = node
		var radius := Fire.ash_radius(fire.ash_piles[cell])
		node.position = Vector3(cell.x * Fire.CELL, 0.002, cell.y * Fire.CELL)
		node.rotation.y = float(cell.x * 13 + cell.y * 7)
		node.scale = Vector3(radius, radius * 0.13, radius * 0.82)
	_prune(ash_views, fire.ash_piles)

func _create_log(piece: Fire.Piece) -> void:
	var nodes: Array[MeshInstance3D] = []
	var is_fine := piece.fibre
	for i in range(maxi(1, piece.sections.size())):
		var shape: Mesh = fibres if is_fine else (shell if piece.sections.is_empty() else null)
		var node := _mesh(shape, null)
		if shape != null:
			_wood_ink(node, piece.kind, float(piece.id % 23) * 0.38)
		nodes.append(node)
	logs[piece.get_instance_id()] = nodes
	if not collisions.has(piece.get_instance_id()):
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.collision_mask = 0
		var geometry := CollisionShape3D.new()
		geometry.shape = BoxShape3D.new()
		body.add_child(geometry)
		root.add_child(body)
		collisions[piece.get_instance_id()] = body

func _update_log(piece: Fire.Piece, nodes: Array) -> void:
	var a := world(piece.pose.point(-piece.pose.span))
	var b := world(piece.pose.point(piece.pose.span))
	var along := a.direction_to(b)
	var side := along.cross(Vector3.UP).normalized()
	var upright := side.cross(along).normalized()
	var basis := Basis(along, upright, side)
	basis = basis.rotated(along, piece.roll_travel / maxf(0.026, piece.radius))
	var span := a.distance_to(b)
	var body: AnimatableBody3D = collisions[piece.get_instance_id()]
	body.transform = Transform3D(basis, a.lerp(b, 0.5))
	var geometry: CollisionShape3D = body.get_child(0)
	var box: BoxShape3D = geometry.shape
	var dimensions := Vector3(span, piece.radius * 1.46, piece.radius * 1.48)
	if box.size != dimensions:
		box.size = dimensions
	for i in range(nodes.size()):
		var node: MeshInstance3D = nodes[i]
		var sample := piece if piece.sections.is_empty() else piece.sections[i]
		var top := sample if sample.core == null else sample.faces[0]
		var bottom := sample if sample.core == null else sample.faces[1]
		var fraction := (i + 0.5) / nodes.size()
		var middle := a.lerp(b, fraction)
		var thickness := (sample.upper_radius + sample.lower_radius) * 0.5
		_place_log_mesh(node, Transform3D(basis.scaled_local(Vector3(span / nodes.size(), thickness, sample.radius)), middle), piece.rolling)
		if not piece.sections.is_empty():
			_shape_log_section(piece, i, node, Vector3(thickness, thickness, sample.radius))
		var wood_color := _wood_color(piece.kind, sample)
		_finish_wood(node.get_surface_override_material(0), wood_color, top, 0.35)
		if node.mesh.get_surface_count() >= 2:
			_finish_wood(node.get_surface_override_material(1), wood_color.darkened(0.09), bottom, 0.50)
		if node.mesh.get_surface_count() == 3:
			_finish_wood(node.get_surface_override_material(2), wood_color.lerp(Color("#cdad81"), 0.66), sample, 0.29)

func _wood_ink(node: MeshInstance3D, kind: int, seed: float) -> void:
	for surface in range(node.mesh.get_surface_count()):
		if node.get_surface_override_material(surface) == null:
			var skin := Paint.Surface.BARK
			if surface == 2:
				skin = Paint.Surface.END_GRAIN
			elif surface == 0 and kind in [2, 3, 8, 10]:
				skin = Paint.Surface.SPLIT_WOOD
			elif kind in Fire.RAW_TINDER or kind == Fire.TINDER_BUNDLE:
				skin = Paint.Surface.ORGANIC
			var material := Paint.style(skin, Color.WHITE, true)
			material.set_shader_parameter("brush_seed", seed if surface != 2 else 0.0)
			node.set_surface_override_material(surface, material)

func _shape_log_section(piece: Fire.Piece, i: int, node: MeshInstance3D, scale: Vector3) -> void:
	var last := piece.sections.size() - 1
	var section := piece.sections[i]
	var before := piece.sections[maxi(i - 1, 0)]
	var after := piece.sections[mini(i + 1, last)]
	var center := _section_profile(section)
	var left := center.lerp(_section_profile(before), 0.5)
	var right := center.lerp(_section_profile(after), 0.5)
	var integrity := snappedf(section.integrity, 0.125)
	var wear := Vector3(lerpf(snappedf(before.integrity, 0.125), integrity, 0.5),
		integrity, lerpf(snappedf(after.integrity, 0.125), integrity, 0.5))
	var start := (2 if piece.split_start else 1) if i == 0 else 0
	var end := (2 if piece.split_end else 1) if i == last else 0
	var profile := [left, center, right, wear, start, end]
	if node.get_meta("wood_profile", []) == profile:
		return
	node.set_meta("wood_profile", profile)
	node.mesh = _wood_mesh(left / scale, center / scale, right / scale, Vector3.ONE - wear,
		floori(section.id / 5.0), section.id % 5, start, end, piece.kind in [2, 3, 8, 10])
	_wood_ink(node, piece.kind, float(piece.id % 23) * 0.38)

func _section_profile(section: Fire.Piece) -> Vector3:
	return Vector3(section.upper_radius, section.lower_radius, (section.upper_radius + section.lower_radius) * 0.5)

func _place_log_mesh(node: MeshInstance3D, target: Transform3D, rolling: bool) -> void:
	var previous: Transform3D = node.get_meta("rest_pose", target)
	if node.has_meta("rest_pose") and previous == target:
		return
	node.set_meta("rest_pose", target)
	if node.has_meta("drop_tween"):
		var running: Tween = node.get_meta("drop_tween")
		if running.is_valid():
			running.kill()
	var drop := previous.origin.y - target.origin.y
	if drop <= 0.027 and not rolling:
		node.transform = target
		return
	var motion := node.create_tween()
	var duration := 0.19 if rolling else clampf(sqrt(2.0 * drop / Fire.GRAVITY), 0.06, 0.18)
	var settling := motion.tween_property(node, "transform", target, duration)
	settling.set_trans(Tween.TRANS_SINE if rolling else Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT if rolling else Tween.EASE_IN)
	node.set_meta("drop_tween", motion)

func _wood_color(kind: int, p: Fire.Piece) -> Color:
	var base: Color = Fire.Materials.PROFILES[p.material].color
	match kind:
		4: base = Color("#d39a57")
		5: base = Color("#bca05d")
		6: base = Color("#bd956a")
		7: base = Color("#9f784d")
		0: base = Color("#c1a17d")
		1: base = Color("#9d7954")
		Fire.LEAVES: base = Color("#a67948")
		Fire.TINDER_BUNDLE: base = Color("#cb9352")
		11: base = base.lerp(Color("#a5754c"), 0.26)
		12: base = base.lerp(Color("#c2b4a3"), 0.48)
		13: base = base.lerp(Color("#797453"), 0.42)
	return base

func _face_moisture(piece: Fire.Piece) -> PackedFloat32Array:
	var values := PackedFloat32Array([snappedf(piece.water / piece.original, 0.025)])
	for section in piece.sections:
		for face in section.faces:
			values.append(snappedf(face.water / face.original, 0.025))
	return values

func _finish_wood(material: ShaderMaterial, dry_ink: Color, face: Fire.Piece, glow: float) -> void:
	var wet := smoothstep(0.15, 0.65, face.water / face.original)
	Paint.color(material, dry_ink)
	material.set_shader_parameter("moisture", wet)
	material.set_shader_parameter("scorch", clampf(face.charred_wood / face.original, 0.0, 1.0))
	material.set_shader_parameter("resin", smoothstep(0.0, 0.0016, face.resin))
	material.set_shader_parameter("ember", face.glow() * glow)

func _structure_event(kind: String, at: Vector2, mass: float, height: float, temperature: float) -> void:
	if kind == "pop" and refresh_interval == 0.0:
		pop_marks.append({"at": seconds, "point": Vector3(at.x, height + 0.028, at.y),
			"size": clampf(mass * 0.30, 0.028, 0.092), "hot": temperature >= 365.0})
	# Falling carbon is already tracked by Fire. The short-lived body only illustrates it at play speed.
	if kind != "fall" or refresh_interval > 0.0:
		return
	for i in range(debris.size() - 1, -1, -1):
		if not is_instance_valid(debris[i]):
			debris.remove_at(i)
	if debris.size() >= 10:
		return
	var chunk := RigidBody3D.new()
	chunk.mass = maxf(0.0022, mass)
	chunk.collision_layer = 0
	var radius := clampf(pow(mass / 460.0, 1.0 / 3.0), 0.012, 0.047)
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collider := CollisionShape3D.new()
	collider.shape = shape
	chunk.add_child(collider)
	var coal := MeshInstance3D.new()
	coal.mesh = stone
	coal.scale = Vector3.ONE * radius * 2.0
	var glow := smoothstep(345.0, 880.0, temperature)
	coal.material_override = Paint.style(Paint.Surface.CHARCOAL, Color("#43312a").lerp(Color("#ec6d32"), glow))
	coal.material_override.set_shader_parameter("ember", glow * 1.8)
	chunk.add_child(coal)
	root.add_child(chunk)
	chunk.position = Vector3(at.x, height, at.y)
	chunk.angular_velocity = Vector3(3.2, -1.6, 2.1)
	debris.append(chunk)
	get_tree().create_timer(0.34 + sqrt(2.0 * height / Fire.GRAVITY)).timeout.connect(chunk.queue_free)

func _update_bed(p: Fire.Piece, node: MeshInstance3D) -> void:
	var ash := clampf((p.cover + p.mineral) * 25.0, 0.0, 0.9)
	node.material_override.set_shader_parameter("ash_cover", ash)
	var glow := p.glow() * exp(-3.5 * p.depth())
	var amount := _coal_amount(p)
	node.visible = amount > 0.0003
	node.position = Vector3(p.at.x, p.height + 0.015, p.at.y)
	var shape := _coal_shape(p)
	if node.mesh != shape:
		node.mesh = shape
	node.scale = _coal_scale(p, amount)
	var red := Color("#5e1b13").lerp(Color("#d84218"), smoothstep(390.0, 640.0, p.temperature))
	red = red.lerp(Color("#ffb44a"), smoothstep(640.0, 970.0, p.temperature))
	var color := Color("#352820").lerp(red, glow).lerp(Color("#80756b"), ash)
	var reaction := smoothstep(0.0, 1.5, p.char_heat)
	var brightening := smoothstep(0.04, 0.32, p.pulse) * smoothstep(0.0, 0.075, p.breath_balance)
	brightening *= smoothstep(275.0, 455.0, p.temperature) * exp(-3.5 * p.depth())
	node.set_meta("breath_glow", brightening)
	color = color.lerp(Color("#ff431f"), brightening * 0.82)
	var emission := glow * (0.72 + reaction * 0.28) + brightening * 1.45
	if refresh_interval > 0.0 or not node.has_meta("glow_color"):
		Paint.color(node.material_override, color)
		node.material_override.set_shader_parameter("ember", emission)
	elif node.get_meta("glow_color") != color or node.get_meta("glow_power") != emission:
		if node.has_meta("glow_tween"):
			var previous: Tween = node.get_meta("glow_tween")
			if previous.is_valid():
				previous.kill()
		var transition := node.create_tween().set_parallel()
		transition.tween_property(node.material_override, "shader_parameter/ink", color, 0.20)
		transition.tween_property(node.material_override, "shader_parameter/ember", emission, 0.20)
		node.set_meta("glow_tween", transition)
	node.set_meta("glow_color", color)
	node.set_meta("glow_power", emission)

func _coal_amount(piece: Fire.Piece) -> float:
	return maxf(piece.char_mass, (piece.cover + piece.mineral) * 0.9)

func _compact_coal(piece: Fire.Piece) -> bool:
	return piece.char_porosity < 0.40 and piece.char_mass > 0.05

func _coal_shape(piece: Fire.Piece) -> Mesh:
	return stone if _compact_coal(piece) or piece.size < 0.09 else coal_cluster

func _coal_scale(piece: Fire.Piece, amount: float) -> Vector3:
	if _compact_coal(piece):
		return Vector3(0.17, 0.078, 0.14) * pow(piece.charcoal_volume() / 0.00077, 1.0 / 3.0)
	var size_scale := clampf(pow(amount / piece.original, 0.44), 0.20, 1.34)
	return Vector3(0.071, 0.047, 0.064) * size_scale if piece.size < 0.09 else Vector3.ONE * size_scale

func _sheet(vapor: bool, steam := false) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = PLUME
	material.set_shader_parameter("vapor", vapor)
	material.set_shader_parameter("steam", steam)
	var node := _mesh(sheet if vapor else flame_sheet, material)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _make_flame_sheet() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(8):
		var top := row / 8.0
		var bottom := (row + 1) / 8.0
		for uv: Vector2 in [Vector2(0, top), Vector2(0, bottom), Vector2(1, top),
			Vector2(1, top), Vector2(0, bottom), Vector2(1, bottom)]:
			surface.set_uv(uv)
			surface.add_vertex(Vector3(uv.x - 0.5, 0.5 - uv.y, 0))
	return surface.commit()

func _update_flame(p: Fire.Piece, flame: MeshInstance3D) -> void:
	var rise := clampf(sqrt(p.flame / 75.0), 0.07, 1.3)
	var at := Vector3(p.at.x, p.height, p.at.y)
	var draft := Vector3(p.draft.x, 0, p.draft.y).limit_length(2.3)
	var column := 0.46 * rise
	var width := (0.22 + p.size * 0.47) * rise
	var right := camera.global_basis.x
	flame.show()
	flame.transform = Transform3D(Basis(right * width, Vector3.UP * column, right.cross(Vector3.UP)),
		at + Vector3.UP * column * 0.48)
	flame.material_override.set_shader_parameter("phase", p.id * 1.77)
	flame.material_override.set_shader_parameter("opacity", clampf(p.flame / 4.5, 0.20, 1.0))
	flame.material_override.set_shader_parameter("flame_bend", draft * column * 0.92)

func _update_smoke() -> void:
	var visible_parcels := {}
	var blend := 1.0 if refresh_interval > 0.0 else clampf((seconds - effects_clock) / Fire.STEP, 0.0, 1.0)
	for parcel in fire.smoke_field.parcels:
		var strength := 1.0 - exp(-parcel.mass * 34.0 / maxf(0.035, parcel.radius * parcel.radius))
		if strength < 0.025:
			continue
		visible_parcels[parcel.id] = true
		if not smoke_views.has(parcel.id):
			smoke_views[parcel.id] = _sheet(true)
		var smoke: MeshInstance3D = smoke_views[parcel.id]
		var width := parcel.radius * 2.9
		var ceiling := smoothstep(1.65, 2.12, parcel.at.y) if fire.shelter != null and +			fire.shelter.depth_at(Vector2(parcel.at.x, parcel.at.z)) < 0.0 else 0.0
		smoke.transform = Transform3D(camera.global_basis.scaled_local(
			Vector3(width * lerpf(1.0, 1.7, ceiling), width * lerpf(1.06, 0.42, ceiling), 1.0)),
			parcel.previous.lerp(parcel.at, blend))
		smoke.material_override.set_shader_parameter("phase", parcel.id * 2.39)
		smoke.material_override.set_shader_parameter("opacity", strength * 0.64)
		smoke.material_override.set_shader_parameter("smoke_color", Color("#b1a99b").lerp(Color("#645a51"), parcel.warmth))
	_prune(smoke_views, visible_parcels)

func _show_steam(p: Fire.Piece, active: Dictionary) -> void:
	if p.temperature < 25.0 or p.vapor <= 0.000006:
		return
	var key := p.get_instance_id()
	active[key] = true
	if not steam_views.has(key):
		steam_views[key] = _sheet(true, true)
	var steam: MeshInstance3D = steam_views[key]
	var strength := smoothstep(0.000004, 0.00045, p.vapor)
	var height := lerpf(0.13, 0.40, strength)
	var steam_air := fire.wind_at(p.at, p.height)
	var lift_axis := (Vector3.UP + Vector3(steam_air.x, 0.0, steam_air.y) * 0.53).normalized()
	var right := camera.global_basis.z.cross(lift_axis).normalized()
	var at := Vector3(p.at.x, p.height, p.at.y)
	steam.transform = Transform3D(Basis(right * lerpf(0.11, 0.29, strength), lift_axis * height, right.cross(lift_axis)),
		at + lift_axis * (height * 0.48 + 0.012))
	var phase := p.id * 1.91 + p.owner * 0.83 + p.at.dot(Vector2(2.3, -3.1)) + p.layer * 2.0
	steam.material_override.set_shader_parameter("phase", phase)
	steam.material_override.set_shader_parameter("opacity", lerpf(0.37, 0.83, strength))

func _update_rain() -> void:
	var rain := fire.rain_at(Vector2(0, 3.0))
	var ground := floor_node.material_override as ShaderMaterial
	if ground != null and (ground == soil or ground.shader == preload("res://hearth/valley_soil.gdshader")):
		var lip := -float(Fire.Shelter.DEPTHS[fire.shelter.site]) if fire.shelter != null else -20.0
		var drive := maxf(0.0, -fire.shelter.wind.y) * 0.6 if fire.shelter != null else 0.0
		ground.set_shader_parameter("rain_film", Vector2(maxf(fire.ground_wetness, rain * 0.73), lip - drive))
	rain_lines.visible = rain > 0.014
	rain_impacts.visible = rain_lines.visible
	if not rain_lines.visible:
		return
	var mesh: ImmediateMesh = rain_lines.mesh
	var impacts: ImmediateMesh = rain_impacts.mesh
	mesh.clear_surfaces()
	impacts.clear_surfaces()
	var drops := false
	var splashes := false
	var fuel := fire.all_fuel()
	for i in range(132):
		var life := seconds * (1.22 + fposmod(i * 0.217, 1.0) * 0.44) + i * 0.61803
		var cycle := floorf(life)
		var phase := fposmod(life, 1.0)
		var at := Vector2(fposmod(i * 0.537 + cycle * 0.331, 1.0) * 4.10 - 2.43,
			fposmod(i * 0.317 + cycle * 0.693, 1.0) * 2.88 - 1.64)
		var wetting := fire.rain_at(at)
		if wetting <= 0.0 or fposmod(i * 0.4721 + cycle * 0.152, 1.0) >= wetting:
			continue
		var surface := fire.rain_landing_height(at, fuel)
		var landing := Vector3(at.x, surface + 0.008, at.y)
		if phase < 0.76:
			if not drops:
				mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				drops = true
			var air := fire.weather_wind(at)
			var path := Vector3(air.x * 0.26, -1.93, air.y * 0.26)
			var head := landing - path * (1.0 - phase / 0.76)
			AirInk.ribbon(mesh, head - path * (0.048 + phase * 0.045), head, camera.global_basis.z,
				0.0015, 0.0034, Color("#c2d5d7", 0.42 + wetting * 0.28))
		else:
			if not splashes:
				impacts.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				splashes = true
			_draw_rain_impact(impacts, landing, (phase - 0.76) / 0.24, i)
	if drops:
		mesh.surface_end()
	if splashes:
		impacts.surface_end()

func _draw_rain_impact(mesh: ImmediateMesh, at: Vector3, age: float, seed: int) -> void:
	var radius := lerpf(0.018, 0.090, age)
	var ink := Color("#b3d0d1", pow(1.0 - age, 1.3) * 0.78)
	for i in range(7):
		var a := Vector2.from_angle(i * TAU / 7.0) * radius
		var b := Vector2.from_angle((i + 1) * TAU / 7.0) * radius
		AirInk.ribbon(mesh, at + Vector3(a.x, 0, a.y), at + Vector3(b.x, 0, b.y), Vector3.UP, 0.0027, 0.0027, ink)
	if age < 0.64:
		for i in range(3):
			var side := Vector2.from_angle(seed * 2.39 + i * TAU / 3.0) * (0.012 + age * 0.12)
			var tip := at + Vector3(side.x, sin(age * PI) * 0.065, side.y)
			AirInk.ribbon(mesh, tip - Vector3(side.x, 0.025, side.y) * 0.43, tip, camera.global_basis.z, 0.001, 0.003, ink)

func _prune(pool: Dictionary, alive: Dictionary) -> void:
	for key in pool.keys():
		if alive.has(key):
			continue
		if pool[key] is Array:
			for node in pool[key]:
				node.queue_free()
		else:
			pool[key].queue_free()
		pool.erase(key)

func _mesh(shape: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	root.add_child(node)
	return node

func _wood_mesh(left: Vector3, center: Vector3, right: Vector3, wear: Vector3,
		seed: int, slice: int, start: int, end: int, split := false) -> ArrayMesh:
	const HALF_SIDES := 8
	const SIDES := 2 * HALF_SIDES
	const LENGTH_STEPS := 6
	var result := ArrayMesh.new()
	var rings: Array[PackedVector3Array] = []
	for step in range(LENGTH_STEPS + 1):
		var x := float(step) / LENGTH_STEPS
		var blend := smoothstep(0.0, 1.0, absf(2.0 * x - 1.0))
		var profile := center.lerp(left if x < 0.5 else right, blend)
		var charred := lerpf(wear.y, wear.x if x < 0.5 else wear.z, blend)
		var tip := start if step == 0 else (end if step == LENGTH_STEPS else 0)
		var bow := 0.075 * sin((slice + x) * 1.25 + seed * 0.82)
		var ring := PackedVector3Array()
		for edge in range(SIDES):
			var angle := TAU * edge / SIDES
			var grain := sin(angle * 3.0 + seed * 1.7 + (slice + x) * 1.27)
			var ridges := sin(angle * 5.0 - seed * 0.56 + (slice + x) * 3.85)
			var ripple := 1.0 + grain * 0.08 + ridges * (0.055 + charred * 0.14)
			var cut := (0.11 + 0.09 * ridges + 0.05 * grain) if tip == 2 else 0.0
			var y := sin(angle)
			var shoulder := 1.0 - 0.28 * smoothstep(0.05, 0.92, y) if split else 1.0
			if split:
				y = maxf(-0.86, y)
			ring.append(Vector3(x - 0.5 - signf(x - 0.5) * cut,
				y * (profile.x if y >= 0.0 else profile.y) * ripple,
				(cos(angle) * ripple * shoulder + bow) * profile.z))
		rings.append(ring)

	for band in range(2):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in range(LENGTH_STEPS):
			for edge in range(band * HALF_SIDES, (band + 1) * HALF_SIDES):
				var next := (edge + 1) % SIDES
				var axial := slice + (step + 0.5) / LENGTH_STEPS
				var shade := 0.91 + 0.047 * sin(edge * 0.8 + seed + axial * 0.5)
				shade += 0.024 * sin(edge * 1.4 - axial * 2.0 + seed * 0.6)
				var tint := Color(shade, shade * 0.96, shade * 0.90)
				var a := rings[step][edge]
				var b := rings[step + 1][edge]
				var c := rings[step + 1][next]
				var d := rings[step][next]
				_tri(tool, a, b, c, tint)
				_tri(tool, a, c, d, tint)
		tool.generate_normals()
		tool.commit(result)

	if start > 0 or end > 0:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tip in [0, LENGTH_STEPS]:
			var style := start if tip == 0 else end
			if style == 0:
				continue
			var side := -1.0 if tip == 0 else 1.0
			var fracture := style == 2
			var ring := rings[tip]
			var center_point := Vector3(side * (0.20 if fracture else 0.49), 0.0, 0.0)
			for edge in range(SIDES):
				var a := ring[edge]
				var b := ring[(edge + 1) % SIDES]
				var inside_a := center_point.lerp(a, 0.56)
				var inside_b := center_point.lerp(b, 0.56)
				var grain_tint := Color("#9c7861") if fracture else Color("#f0d5ad")
				var seam_tint := Color("#735448") if fracture else Color("#e2c59b")
				_tri(tool, a, b, inside_a, grain_tint.darkened(0.09 * (edge % 3)))
				_tri(tool, inside_a, b, inside_b, grain_tint)
				_tri(tool, center_point, inside_a, inside_b, seam_tint)
		tool.generate_normals()
		tool.commit(result)
	return result

func _fibres_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73013
	for i in range(37):
		var point := Vector3(rng.randf_range(-0.47, 0.40), rng.randf_range(-0.36, 0.70), rng.randf_range(-1.12, 1.12))
		var tip := point + Vector3(rng.randf_range(0.05, 0.24), rng.randf_range(0.1, 1.9), rng.randf_range(-0.32, 0.32))
		_tri(tool, point, tip, point + Vector3(0.14, 0, 0.27),
			Color("#cbb293").lerp(Color("#7d523a"), rng.randf()))
	tool.generate_normals()
	return tool.commit()

func _coal_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1011
	for i in range(18):
		var at := Vector3(rng.randf_range(-0.105, 0.105), -0.010, rng.randf_range(-0.089, 0.089))
		var radius := rng.randf_range(0.011, 0.026)
		var broken := PackedVector3Array()
		var crown := PackedVector3Array()
		for side in range(7):
			var angle := TAU * side / 7.0
			var offset := Vector3(cos(angle), 0, sin(angle)) * radius * rng.randf_range(0.72, 1.22)
			broken.append(at + offset)
			crown.append(at + offset * 0.64 + Vector3.UP * radius * rng.randf_range(0.48, 1.12))
		for side in range(7):
			var next := (side + 1) % 7
			var pigment := Color.WHITE.darkened(rng.randf_range(0.12, 0.39))
			_tri(tool, broken[side], crown[side], broken[next], pigment)
			_tri(tool, broken[next], crown[side], crown[next], pigment)
			_tri(tool, crown[side], at + Vector3.UP * radius, crown[next], pigment.lightened(0.09))
	tool.generate_normals()
	return tool.commit()

func _weathered_stone() -> ArrayMesh:
	var ball := SphereMesh.new()
	ball.radial_segments = 18
	ball.rings = 10
	var arrays := ball.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(points.size()):
		var v := points[i] * 2.0
		var chips := sin(v.x * 6.0 + v.z * 4.0) * 0.095 + cos(v.z * 7.0 - v.y * 5.0) * 0.07
		v *= 1.0 + chips
		v.y = minf(0.77 + 0.10 * sin(v.z * 3.1 + v.x * 2.4), v.y)
		points[i] = v * 0.5
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _ash_mound() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(28):
		var a := Vector2.from_angle(TAU * i / 28.0)
		var b := Vector2.from_angle(TAU * (i + 1) / 28.0)
		var crest := Vector3(0.08, 0.39, -0.11)
		var edge_a := Vector3(a.x, 0.0, a.y) * (0.9 + sin(a.x * 7.3 + a.y * 6.1) * 0.13)
		var edge_b := Vector3(b.x, 0.0, b.y) * (0.9 + sin(b.x * 7.3 + b.y * 6.1) * 0.13)
		var mid_a := edge_a.lerp(crest, 0.55)
		var mid_b := edge_b.lerp(crest, 0.55)
		_tri(mesh, edge_a, mid_a, edge_b, Color.WHITE)
		_tri(mesh, edge_b, mid_a, mid_b, Color.WHITE)
		_tri(mesh, mid_a, crest, mid_b, Color.WHITE)
	mesh.generate_normals()
	return mesh.commit()

func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	tool.set_color(color)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)
