extends Control
## A small ochre handprint with a broken, stippled edge.

const OUTLINE := [
	Vector2(22, 68), Vector2(19, 57), Vector2(16, 51), Vector2(9, 45), Vector2(5, 37),
	Vector2(7, 33), Vector2(11, 34), Vector2(19, 42), Vector2(22, 40), Vector2(16, 18),
	Vector2(17, 13), Vector2(21, 13), Vector2(25, 19), Vector2(30, 33), Vector2(29, 12),
	Vector2(31, 6), Vector2(35, 5), Vector2(38, 9), Vector2(39, 32), Vector2(43, 14),
	Vector2(46, 10), Vector2(50, 11), Vector2(51, 16), Vector2(47, 36), Vector2(53, 24),
	Vector2(57, 22), Vector2(60, 25), Vector2(59, 31), Vector2(54, 45), Vector2(53, 54),
	Vector2(48, 62), Vector2(45, 68), Vector2(44, 73), Vector2(39, 75), Vector2(34, 74),
	Vector2(29, 76), Vector2(25, 73), Vector2(22, 74),
]
const HEAT_STOPS := [0.0, 0.05, 0.18, 0.55, 1.35, 2.8]
const INK := ["#e8e2d6", "#b73828", "#e65f25", "#f29d31", "#f8d85a", "#fff8e9"]
const DAMP_BLUE := Color("#819ab4")
const WET_BLUE := Color("#6aa8e8")
const INDIGO := Color("#30266e")
const PALM_MARKS := [
	[Vector2(22, 47), Vector2(29, 49), Vector2(36, 48), Vector2(43, 44)],
	[Vector2(29, 57), Vector2(35, 58), Vector2(42, 55)],
]
var band := 0
var heat := 0.0
var wetness := Vector2.ZERO # surface outline, deeper moisture in the palm
var shown_heat := 0.0
var shown_wetness := Vector2.ZERO
var outline := PackedVector2Array(OUTLINE)
var edge := PackedVector2Array(OUTLINE)
var dust := PackedVector3Array()
var flecks := PackedVector3Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.append(edge[0])
	var random := RandomNumberGenerator.new()
	random.seed = 416
	for i in range(246):
		var point := Vector2(random.randf_range(1, 64), random.randf_range(2, 76))
		var speck := Vector3(point.x, point.y, random.randf_range(0.28, 1.15))
		if Geometry2D.is_point_in_polygon(point, outline):
			flecks.append(speck)
		elif ((point - Vector2(33, 41)) / Vector2(32, 39)).length_squared() < 1.0:
			dust.append(speck)

func show_touch(value: float, next: int, surface: float, interior: float) -> void:
	heat = maxf(0.0, value)
	band = next
	wetness = Vector2(surface, interior)

func _process(delta: float) -> void:
	var fade := 1.0 - exp(-10.0 * delta)
	var next := lerpf(shown_heat, heat, fade)
	var next_wet := shown_wetness.lerp(wetness, fade)
	if absf(next - heat) < 0.0001:
		next = heat
	if next_wet.distance_squared_to(wetness) < 0.00000001:
		next_wet = wetness
	if next != shown_heat or next_wet != shown_wetness:
		shown_heat = next
		shown_wetness = next_wet
		queue_redraw()

func heat_color(value: float) -> Color:
	for i in range(1, HEAT_STOPS.size()):
		if value <= HEAT_STOPS[i]:
			var blend := inverse_lerp(HEAT_STOPS[i - 1], HEAT_STOPS[i], value)
			return Color(INK[i - 1]).lerp(Color(INK[i]), blend)
	return Color(INK.back())

func moisture_color(value: float) -> Color:
	if value < 0.40:
		return DAMP_BLUE.lerp(WET_BLUE, smoothstep(0.14, 0.40, value))
	return WET_BLUE.lerp(INDIGO, smoothstep(0.48, 1.0, value))

func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, size / Vector2(65, 80))
	var ochre := heat_color(shown_heat)
	var fill := smoothstep(0.005, 0.08, shown_heat)
	for speck in dust:
		draw_circle(Vector2(speck.x, speck.y), speck.z, Color(ochre, 0.12 + fill * 0.20), true, -1.0, true)
	var shadow := PackedVector2Array()
	for point in outline:
		shadow.append(point + Vector2(0, 1.8))
	draw_colored_polygon(shadow, Color(0.09, 0.055, 0.04, 0.8))
	draw_colored_polygon(outline, Color(ochre, fill))
	draw_polyline(edge, ochre, 1.2, true)
	for speck in flecks:
		var soot := Color("#51392d") if speck.z > 0.59 else Color("#f1dbc0")
		draw_circle(Vector2(speck.x, speck.y), speck.z, Color(soot, 0.31 * fill), true, -1.0, true)
	var wet := shown_wetness.x
	if wet > 0.0:
		var visible_wet := smoothstep(0.38, 0.40, wet)
		var damp := smoothstep(0.0, 0.34, wet) * (1.0 - visible_wet)
		draw_line(Vector2(26, 67), Vector2(39, 68), Color(DAMP_BLUE, damp * 0.68), 2.0, true)
		var rim := 3.9 + 1.6 * smoothstep(0.55, 1.0, wet)
		if visible_wet > 0.0:
			draw_polyline(edge, Color(moisture_color(wet), visible_wet), rim, true)
		var deep := smoothstep(0.58, 0.95, wet)
		if deep > 0.0:
			draw_polyline(edge, Color(WET_BLUE, deep * 0.88), 1.05, true)
	var inner := shown_wetness.y
	if inner > 0.0:
		for stroke in PALM_MARKS:
			var marks := PackedVector2Array(stroke)
			draw_polyline(marks, Color(INDIGO, inner * 0.90), 2.8, true)
			draw_polyline(marks, Color(WET_BLUE, inner * 0.82), 1.05, true)
	draw_set_transform(Vector2.ZERO)
