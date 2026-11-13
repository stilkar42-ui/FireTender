extends Node3D
## Two painted layers fixed in world space. The native sky sits behind them.
const Scenery := preload("res://hearth/hearth_scenery.gd")
const ARC := PI * 1.5
const PANEL_ANGLES := [-ARC * 0.5, -0.65, 0.0, 0.65, ARC * 0.5]
const SKY := preload("res://hearth/storm_sky.gdshader")
const OVERHEAD := preload("res://hearth/hollow_overhead.gdshader")
const MIDSLOPE := preload("res://hearth/valley_midground.gdshader")
const PAINTINGS := {
	"storm_paint": "res://hearth/art/red-hollow-storm.png",
	"star_paint": "res://hearth/art/red-hollow-stars.png",
	"moon_paint": "res://hearth/art/red-hollow-moon.png",
}

var scenery: Scenery
var background: MeshInstance3D
var sky_material := ShaderMaterial.new()
var overhead_material := ShaderMaterial.new()
var overhead := Sky.new()
var mid_material := ShaderMaterial.new()
var midground: MeshInstance3D
var painted_at := -INF

func _ready() -> void:
	sky_material.shader = SKY
	overhead_material.shader = OVERHEAD
	overhead.radiance_size = Sky.RADIANCE_SIZE_32
	overhead.sky_material = overhead_material
	sky_material.set_shader_parameter("valley_paint", scenery.panorama)
	overhead_material.set_shader_parameter("valley_paint", scenery.panorama)
	for layer: String in PAINTINGS:
		var brush := _painting(PAINTINGS[layer])
		sky_material.set_shader_parameter(layer, brush)
		overhead_material.set_shader_parameter(layer, brush)
	var horizon_angles := PANEL_ANGLES.map(func(angle: float) -> float: return angle * scenery.panorama_span / 270.0)
	# Carry the painted slopes down behind the foreground even at the ledge.
	background = _arc_mesh(horizon_angles, 9.0, 3.0, 8.6, -26.0, -0.01, sky_material)
	background.name = "PaintedHorizon"
	background.scale = Vector3.ONE * scenery.exterior_scale
	mid_material.shader = MIDSLOPE
	mid_material.render_priority = -30
	mid_material.set_shader_parameter("slope_paint", scenery.foreground)
	midground = _arc_mesh([-1.75, 1.75], 5.45, 1.22, 4.8, -4.2, 1.22, mid_material)
	midground.name = "PaintedValleySlope"
	midground.scale = Vector3.ONE * scenery.exterior_scale

func _arc_mesh(angles: Array, radius: float, art_top: float, art_height: float, low: float, high: float,
		material: Material) -> MeshInstance3D:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := angles.size() - 1
	var top := (art_top - high) / art_height
	var bottom := (art_top - low) / art_height
	for section in range(sections):
		for segment in range(20):
			var weight := segment / 20.0
			var next_weight := (segment + 1) / 20.0
			var u := (section + weight) / sections
			var next := (section + next_weight) / sections
			var start := lerpf(angles[section], angles[section + 1], weight)
			var stop := lerpf(angles[section], angles[section + 1], next_weight)
			var a := Vector2(sin(start), cos(start)) * radius
			var b := Vector2(sin(stop), cos(stop)) * radius
			if material == sky_material:
				a.y = lerpf(a.y, radius, (1.0 - smoothstep(0.56, 1.05, absf(start))) * 0.72)
				b.y = lerpf(b.y, radius, (1.0 - smoothstep(0.56, 1.05, absf(stop))) * 0.72)
			_vertex(mesh, a, high, Vector2(u, top))
			_vertex(mesh, b, high, Vector2(next, top))
			_vertex(mesh, a, low, Vector2(u, bottom))
			_vertex(mesh, a, low, Vector2(u, bottom))
			_vertex(mesh, b, high, Vector2(next, top))
			_vertex(mesh, b, low, Vector2(next, bottom))
	var panel := MeshInstance3D.new()
	panel.mesh = mesh.commit()
	panel.material_override = material
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	return panel

func _vertex(mesh: SurfaceTool, position: Vector2, height: float, uv: Vector2) -> void:
	mesh.set_uv(uv)
	mesh.add_vertex(Vector3(position.x, height, position.y))

func _painting(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var painting := Image.load_from_file(path)
	if painting == null or painting.is_empty():
		return null
	painting.generate_mipmaps()
	return ImageTexture.create_from_image(painting)

func light_scene(shelter: RefCounted, time: float, sky_light: float) -> void:
	if painted_at == time:
		return
	painted_at = time
	var storm := clampf(shelter.cloud * 0.47 + shelter.rain * 0.62, 0.0, 1.0)
	for material in [sky_material, mid_material, overhead_material]:
		material.set_shader_parameter("daylight", sky_light)
		material.set_shader_parameter("twilight", shelter.twilight())
		material.set_shader_parameter("storm_light", storm)
	for material in [sky_material, overhead_material]:
		material.set_shader_parameter("cloud", shelter.cloud)
		material.set_shader_parameter("rain_band", shelter.rain_band())
		material.set_shader_parameter("chapter_time", time)
		material.set_shader_parameter("drift", Vector2(time * 0.0028, time * 0.0008) - shelter.wind * 0.86)
		material.set_shader_parameter("moon_angle", shelter.moon_angle())
	sky_material.set_shader_parameter("rain_lean", shelter.wind.x)
	mid_material.set_shader_parameter("rain_band", shelter.rain_band())

static func ledge() -> ArrayMesh:
	# All playable ground remains level. The lip bends downward past the
	# farthest placement point, independently of the selected shelter site.
	var across := [-9.0, -6.0, -3.25, -1.45, 0.0, 1.52, 3.32, 6.0, 9.0]
	var depths := [-9.0, 1.27, 1.42, 1.75, 2.35, 3.25, 4.55, 6.14]
	var heights := [-0.008, -0.008, -0.031, -0.39, -1.09, -2.30, -4.60, -10.2]
	var courses: Array[PackedVector3Array] = []
	for row in range(depths.size()):
		var vertices := PackedVector3Array()
		for column in range(across.size()):
			var fold := sin(column * 2.77 + row * 0.83)
			var roughness := clampf((row - 1) * 0.07, 0.0, 0.40)
			vertices.append(Vector3(across[column], heights[row] + roughness * fold, depths[row] + roughness * 0.43 * fold))
		courses.append(vertices)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	for row in range(courses.size() - 1):
		for column in range(across.size() - 1):
			var a := courses[row][column]
			var b := courses[row][column + 1]
			var c := courses[row + 1][column]
			var d := courses[row + 1][column + 1]
			for point: Vector3 in [a, b, c, c, b, d]:
				mesh.add_vertex(point)
	mesh.generate_normals()
	return mesh.commit()

static func ledge_backing() -> ArrayMesh:
	# Close the near shelf under the playable surface. A grazing camera
	# can see this dark rock below the near plane instead of the valley.
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	var a := Vector3(-9.0, -1.35, -9.16)
	var b := Vector3(9.0, -1.35, -9.16)
	var c := Vector3(-9.0, -1.35, 1.28)
	var d := Vector3(9.0, -1.35, 1.28)
	var lip_left := Vector3(-9.0, -0.009, 1.28)
	var lip_right := Vector3(9.0, -0.009, 1.28)
	for point: Vector3 in [a, b, c, c, b, d, lip_left, lip_right, c, c, lip_right, d]:
		mesh.add_vertex(point)
	mesh.generate_normals()
	return mesh.commit()
