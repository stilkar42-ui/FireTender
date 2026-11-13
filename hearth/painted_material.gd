extends RefCounted
## Surface styles shared by cave props and the live hearth renderers.
const PAINT_SHADER := preload("res://hearth/painted_object.gdshader")
const ART := "res://hearth/art/painted/"
enum Surface { STONE, BARK, END_GRAIN, ORGANIC, CHARCOAL, ASH, SPLIT_WOOD, FLINT, HIDE, BONE }

static func style(kind: Surface, color: Color, vertex := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PAINT_SHADER
	material.set_shader_parameter("surface_kind", kind)
	material.set_shader_parameter("ink", color)
	material.set_shader_parameter("vertex_pigment", vertex)
	match kind:
		Surface.STONE, Surface.CHARCOAL:
			bind_brush(material, "limestone", 0.58, 0.37)
		Surface.BARK:
			bind_brush(material, "bark", 0.85, 0.26)
		Surface.END_GRAIN:
			bind_brush(material, "end-grain", 0.70, 0.47)
		Surface.SPLIT_WOOD:
			bind_brush(material, "bark", 0.57, 0.26)
		Surface.FLINT:
			bind_brush(material, "flint", 0.86, 0.35)
		Surface.HIDE:
			bind_brush(material, "hide", 0.88, 0.38)
		Surface.BONE:
			bind_brush(material, "bone", 0.72, 0.61)
		Surface.ORGANIC, Surface.ASH:
			bind_brush(material, "earth", 0.47, 0.34)
	return material

static func bind_brush(material: ShaderMaterial, name: String, weight: float, center: float) -> void:
	var path := ART + name + ".png"
	if ResourceLoader.exists(path):
		material.set_shader_parameter("brush_map", load(path))
		material.set_shader_parameter("brush_weight", weight)
		material.set_shader_parameter("brush_center", center)

static func color(material: ShaderMaterial, ink: Color) -> void:
	material.set_shader_parameter("ink", ink)

static func cutout_light(at: Vector3, sky: Color, energy: float, lamp: OmniLight3D) -> Color:
	var room := sky.lerp(Color("#dfcfbd"), clampf(energy * 0.7, 0.0, 1.0))
	room = room.darkened(0.38 * (1.0 - smoothstep(0.19, 0.62, energy)))
	if lamp == null:
		return room
	var distance := lamp.position.distance_to(at)
	var reach := 1.0 - smoothstep(0.13, lamp.omni_range, distance)
	var bounced := 1.0 - exp(-lamp.light_energy * pow(reach, 1.7) * 1.25)
	return room.lerp(lamp.light_color.lightened(0.38), bounced)
