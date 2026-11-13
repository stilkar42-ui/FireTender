extends Control
## Ochre figure with independent wind, rain and cold marks.

const OCHRE := Color("#f29d31")
const OCHRE_FLECK := Color("#51392d")
const PALE_FLECK := Color("#f1dbc0")
const WET_PAINT := Color("#819ab4")
const OUTLINE := Color("#36251e")
const WIND_INK := Color("#d9c7a5")
const RAIN_INK := Color("#a0c3d2")
const COLD_INK := Color("#c7dce6")
const WIND_START := [0.018, 0.14, 0.34, 0.64]
const WIND_FULL := [0.13, 0.34, 0.63, 0.98]
const WIND_OFFSETS := [-12.0, 10.0, -22.0, 22.0]
var wind := Vector2.ZERO
var rain := 0.0
var chill := 0.0
var inverted := false
var shown_wind := Vector2.ZERO
var shown_rain := 0.0
var shown_wet := 0.0
var shown_chill := 0.0
var seconds := 0.0

func show_air(relative: Vector2, wetting: float, cold: float, flip_wind: bool) -> void:
	wind = relative
	rain = wetting
	chill = cold
	inverted = flip_wind

func _process(delta: float) -> void:
	var blend := 1.0 - exp(-6.0 * delta)
	shown_wind = shown_wind.lerp(wind, blend)
	shown_rain = lerpf(shown_rain, rain, blend)
	shown_chill = lerpf(shown_chill, chill, blend)
	var wet := smoothstep(0.015, 0.72, rain)
	shown_wet = lerpf(shown_wet, wet, 1.0 - exp(-delta * (2.5 if wet > shown_wet else 0.85)))
	seconds += delta
	queue_redraw()

func wind_ink(index: int, speed: float) -> float:
	return smoothstep(WIND_START[index], WIND_FULL[index], speed)

func _draw() -> void:
	var speed := shown_wind.length()
	var direction := shown_wind.normalized()
	_draw_wind(-direction if inverted else direction, speed)
	_draw_rain(direction, speed)
	_draw_person(direction, speed)
	_draw_cold()

func _draw_person(direction: Vector2, speed: float) -> void:
	var lean := direction.x * smoothstep(0.02, 0.90, speed) * 5.0
	var shiver := shown_chill * (sin(seconds * 17.0) + sin(seconds * 23.0) * 0.3)
	var tuck := shown_chill * 3.0
	var neck := Vector2(54.0 + lean + shiver, 31.0 + tuck)
	var hip := Vector2(53, 48)
	var ink := OCHRE.darkened(shown_wet * 0.12)
	var head := neck + Vector2(-0.5, -10)
	var headprint := PackedVector2Array([Vector2(-6, -1), Vector2(-4, -5), Vector2(0, -6),
		Vector2(4, -4), Vector2(6, 0), Vector2(4, 4), Vector2(0, 6), Vector2(-4, 4)])
	draw_set_transform(head)
	draw_circle(Vector2(0, 1), 6.7, OUTLINE, true, -1.0, true)
	draw_colored_polygon(headprint, ink)
	draw_circle(Vector2(-2, -2), 0.85, Color(PALE_FLECK, 0.45), true, -1.0, true)
	draw_circle(Vector2(2, 2), 0.9, Color(OCHRE_FLECK, 0.45), true, -1.0, true)
	draw_circle(Vector2(-6, -3), 0.7, Color(ink, 0.38), true, -1.0, true)
	draw_circle(Vector2(5, 5), 0.85, Color(ink, 0.28), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	_ochre_mark([neck, neck.lerp(hip, 0.55) + Vector2(-0.8, 0), hip], ink)
	_ochre_mark([neck + Vector2(-14 + tuck, 10), neck + Vector2(-7, 4), neck,
		neck + Vector2(8, 4), neck + Vector2(14 - tuck, 9 + tuck)], ink)
	_ochre_mark([Vector2(37, 67), Vector2(43, 66), Vector2(46, 58), hip,
		Vector2(61, 57), Vector2(66, 65), Vector2(72, 66)], ink)
	if shown_wet > 0.02:
		draw_polyline(PackedVector2Array([neck + Vector2(1.5, 3), neck.lerp(hip, 0.5) + Vector2(1.5, 1),
			hip + Vector2(1.5, -3)]), Color(WET_PAINT, shown_wet * 0.95), 1.4, true)

func _ochre_mark(points: Array, ink: Color) -> void:
	var path := PackedVector2Array(points)
	_stroke(points, ink, 3.3)
	for i in range(1, path.size()):
		var along := path[i] - path[i - 1]
		var side := along.normalized().orthogonal()
		for j in range(maxi(1, floori(along.length() / 2.3))):
			var fraction := (j * 2.3 + 0.8) / along.length()
			var offset := fposmod(i * 0.61 + j * 0.38, 1.0) - 0.5
			var dot := path[i - 1] + along * fraction
			var fleck := OCHRE_FLECK if (i + j) % 2 == 0 else PALE_FLECK
			draw_circle(dot + side * offset * 2.6, 0.5, Color(fleck, 0.46), true, -1.0, true)
			draw_circle(dot + side * offset * 7.5, 0.52, Color(ink, 0.30), true, -1.0, true)

func _draw_wind(direction: Vector2, speed: float) -> void:
	var cross := direction.orthogonal()
	for index in range(WIND_START.size()):
		var strength := wind_ink(index, speed)
		if strength < 0.005:
			continue
		var side: float = WIND_OFFSETS[index]
		var reach := lerpf(15.0, 27.0, strength)
		var phase := fposmod(seconds * (0.34 + speed * 0.41) + index * 0.23, 1.0)
		var start := Vector2(54, 37) - direction * (30.0 - 5.0 * phase) + cross * side
		var ink := Color(WIND_INK, strength * (0.62 + 0.35 * sin(phase * PI)))
		var spine := PackedVector2Array()
		for step in range(10):
			var t := step / 9.0
			var curl := sin(t * TAU - 0.7) * sin(t * PI) * (3.0 + index * 0.50)
			spine.append(start + direction * reach * t + cross * curl)
		_brush(spine, ink, 1.65)
		if index < 2:
			var tip := spine[-1]
			draw_colored_polygon(PackedVector2Array([tip - direction * 6.0 - cross * 2.8, tip + direction * 1.4,
				tip - direction * 5.0 + cross * 2.0, tip - direction * 3.8]), ink)

func _draw_rain(direction: Vector2, speed: float) -> void:
	for index in range(8):
		var weight := smoothstep(0.02 + index * 0.055, 0.22 + index * 0.068, shown_rain)
		if weight < 0.005:
			continue
		var phase := fposmod(seconds * (0.65 + index * 0.04) + index * 0.618, 1.0)
		var x := 23.0 + fposmod(index * 0.38197, 1.0) * 62.0
		var drift := direction.x * minf(1.0, speed) * 10.0
		var start := Vector2(x + drift * phase, 9.0 + 47.0 * phase)
		var tip := start + Vector2(drift * 0.16, 5.0 + weight * 3.0)
		var ink := Color(RAIN_INK, weight * sin(phase * PI) * 0.9)
		draw_colored_polygon(PackedVector2Array([start, tip + Vector2(0.9, -2.2), tip, tip - Vector2(0.85, 1.3)]), ink)

func _draw_cold() -> void:
	var opacity := smoothstep(0.10, 0.82, shown_chill)
	if opacity < 0.005:
		return
	var beat := seconds * 3.4
	for side: float in [-1.0, 1.0]:
		var pulse := 0.58 + 0.39 * sin(beat + side)
		var wrist := Vector2(54.0 + side * 20.0, 42.0 + sin(beat + side) * 2.0)
		_stroke([wrist + Vector2(0, -7), wrist + Vector2(side * 3.0, -2), wrist + Vector2(0, 2),
			wrist + Vector2(side * 3.0, 6)], Color(COLD_INK, opacity * pulse), 1.55)
	var breath := fposmod(seconds * 0.68, 1.0)
	var start := Vector2(61, 23) + Vector2(13, -8) * breath
	_stroke([start, start + Vector2(4, -1), start + Vector2(8, 1)],
		Color(COLD_INK, opacity * sin(breath * PI) * 0.64), 1.6)

func _stroke(points: Array, ink: Color, width: float) -> void:
	var path := PackedVector2Array(points)
	draw_polyline(path, Color(OUTLINE, ink.a * 0.86), width + 1.65, true)
	draw_polyline(path, ink, width, true)

func _brush(spine: PackedVector2Array, ink: Color, width: float) -> void:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in range(spine.size()):
		var tangent := spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]
		var t := float(i) / (spine.size() - 1)
		var taper := 0.16 + 0.84 * sin(t * PI)
		var edge := tangent.normalized().orthogonal() * width * taper
		top.append(spine[i] - edge)
		bottom.append(spine[i] + edge * 0.73)
	bottom.reverse()
	top.append_array(bottom)
	draw_colored_polygon(top, ink)
