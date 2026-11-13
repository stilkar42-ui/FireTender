extends RefCounted
## The opening faces +Z. The roof's drip line is at shelter depth zero.
const SITES := ["Inner shelf", "Under the lip", "Open mouth"]
const DEPTHS := [-0.86, -0.22, 0.64]
const DAY := 360.0
const END := DAY * 3.0
const STORM_BEGINS := DAY * 1.85
const EASING_AT := DAY * 2.83
const YARD := Rect2(-2.65, -3.75, 3.83, 4.98)
const DRY_SHELF := Rect2(-2.50, -3.61, 1.15, 0.74)
const ALCOVE := Rect2(-2.51, -2.64, 1.08, 0.69)
const SEEP := Vector2(0.69, -3.15)
const PASSAGE := Vector2(0.64, -1.96)
enum Watch { CLEAR, BUILDING, RAIN_LINE, RAIN, STORM, EASING }

var site := 1
var after_storm := false
var wind := Vector2.ZERO
var rain := 0.0
var temperature := 12.0
var cloud := 0.0
var light := 1.0
var smoke := 0.0
var thunder := 0.0
var sampled := -INF

func sample(time: float) -> void:
	if time - sampled < 0.5 and not (sampled < END and time >= END):
		return
	sampled = time
	var front := smoothstep(DAY * 0.8, DAY * 2.35, time)
	var storm := storm_strength(time)
	if after_storm:
		front *= lerpf(1.0, 0.38, smoothstep(END, END + 185.0, time))
	var phase := fposmod(time, DAY) / DAY
	light = daylight(phase)
	cloud = clampf(0.10 + front * 0.54 + storm * 0.33, 0.0, 1.0)
	var force := (0.09 + front * 0.16 + storm * 0.85) * (0.80 + 0.20 * sin(time * 0.082))
	wind = Vector2.from_angle(0.85 + 1.72 * sin(time * 0.011 + 0.33)) * force
	rain = storm * (0.78 + 0.22 * sin(time * 0.036))
	temperature = 8.0 + 4.0 * light - 4.0 * storm
	if after_storm:
		temperature -= 1.5 * exp(-maxf(0.0, time - END) / 210.0)
	var rumble := fposmod(time + 8.0, 33.0)
	thunder = storm * smoothstep(0.0, 1.0, rumble) * (1.0 - smoothstep(1.0, 5.5, rumble))

static func daylight(phase: float) -> float:
	return 0.2 + 0.8 * smoothstep(0.0, 0.16, phase + 0.12) * (1.0 - smoothstep(0.63, 0.95, phase))

static func storm_strength(time: float) -> float:
	return smoothstep(STORM_BEGINS, DAY * 2.58, time) * (1.0 - smoothstep(EASING_AT, END, time))

func watch() -> Watch:
	if sampled >= EASING_AT and rain > 0.06:
		return Watch.EASING
	if after_storm or sampled >= END:
		return Watch.CLEAR
	if storm_strength(sampled) > 0.53:
		return Watch.STORM
	if rain > 0.06:
		return Watch.RAIN
	if storm_strength(sampled + 60.0) > 0.09:
		return Watch.RAIN_LINE
	return Watch.BUILDING if cloud > 0.34 else Watch.CLEAR

func rain_band() -> float:
	if sampled >= EASING_AT:
		return rain
	var approaching := smoothstep(0.075, 0.19, storm_strength(sampled + 60.0)) * 0.43
	return maxf(rain, approaching)

func inward_draft() -> bool:
	return wind_at(Vector2.ZERO).y < -0.14

func sky_light() -> float:
	return smoothstep(0.20, 0.92, light)

func twilight() -> float:
	var phase := fposmod(sampled, DAY) / DAY
	return smoothstep(0.61, 0.75, phase) * (1.0 - smoothstep(0.79, 0.92, phase))

func moon_angle() -> float:
	return lerpf(1.19, 0.84, clampf(sampled / END, 0.0, 1.0))

func wet_watch() -> float:
	# A qualitative burden for the remaining front, not a survival clock.
	# Use its envelope so a lull between gusts doesn't read as an all-clear.
	var current := watch()
	if current == Watch.CLEAR:
		return 0.0
	var remaining := clampf((END - sampled) / (DAY * 0.65), 0.0, 1.0)
	var intensity := storm_strength(minf(sampled + 90.0, EASING_AT)) if current != Watch.EASING else storm_strength(sampled)
	return clampf(0.26 + remaining * (0.24 + intensity * 0.50), 0.0, 1.0)

func exposure(at: Vector2) -> float:
	return smoothstep(-0.95, 0.9, depth_at(at))

func depth_at(at: Vector2) -> float:
	return DEPTHS[site] + at.y

func wind_at(at: Vector2) -> Vector2:
	var depth := depth_at(at)
	var inward := maxf(0.0, -wind.y)
	# Only the mouth admits outside wind. The passage can carry a share of
	# that same flow deeper under the rock when the mouth is taking wind.
	var across := wind.x * 0.45 * inward / maxf(0.001, wind.length())
	var reach := exp(minf(0.0, depth) * 0.82)
	reach *= 1.0 + 1.45 * _zone(at, PASSAGE, 0.56)
	var entering := Vector2(across, -inward) * minf(1.0, reach)
	return entering.lerp(wind, smoothstep(0.0, 0.70, depth))

func rain_at(at: Vector2) -> float:
	var driven := maxf(0.0, -wind.y) * 0.6
	return rain * smoothstep(-0.32, 0.62, DEPTHS[site] + at.y + driven)

func seepage_at(at: Vector2) -> float:
	return 0.38 * _zone(at, SEEP, 0.61) if after_storm else 0.0

func air_temperature(at: Vector2) -> float:
	return temperature - 3.0 * _zone(at, SEEP, 0.74)

func humidity(at: Vector2) -> float:
	if protected_storage(at):
		return 0.49
	var retained := 0.63 + 0.14 * exp(-maxf(0.0, sampled - END) / 170.0)
	retained += 0.23 * _zone(at, SEEP, 0.75) - 0.32 * _zone(at, PASSAGE, 0.67)
	return clampf(retained, 0.32, 0.98)

static func protected_storage(at: Vector2) -> bool:
	return DRY_SHELF.has_point(at) or ALCOVE.has_point(at)

static func warming_edge(at: Vector2) -> bool:
	return at.length_squared() <= 1.34 * 1.34

static func _zone(at: Vector2, center: Vector2, reach: float) -> float:
	return 1.0 - smoothstep(0.10, reach, at.distance_to(center))

func ventilation(at: Vector2) -> float:
	var outward := clampf(0.75 + wind_at(at).y * 0.60, 0.28, 1.15)
	return lerpf(0.28, 1.0, exposure(at)) * outward

func weather_words() -> String:
	match watch():
		Watch.BUILDING: return "Clouds gathering"
		Watch.RAIN_LINE: return "Rain line over the ridge"
		Watch.RAIN: return "Rain beyond the shelter"
		Watch.STORM: return "Storm · wind-driven rain"
		Watch.EASING: return "The storm is easing"
	return "Wet valley · Rain has passed" if after_storm or sampled >= END else "Clear beyond the shelter"

func local_words() -> String:
	if smoke > 0.014:
		return "Smoke lingers · inward wind" if inward_draft() else "Smoke hangs under the rock"
	if inward_draft():
		return "Wind pushes under the lip"
	if rain_at(Vector2.ZERO) > 0.08:
		return "Rain reaches the hearth"
	if rain > 0.06:
		return "Shelter keeps the hearth dry"
	if wind.length() > 0.35:
		return "Gusts outside the shelter"
	return "Still air at the hearth" if wind_at(Vector2.ZERO).length() < 0.035 else "A light draft at the hearth"

func day_words(time: float) -> String:
	if not after_storm and time >= END:
		return "Day 3 · End"
	var day := floori(time / DAY) + 1
	var phase := fposmod(time, DAY) / DAY
	var watch := "Morning" if phase < 0.3 else ("Daylight" if phase < 0.64 else ("Dusk" if phase < 0.83 else "Night"))
	return "Day %d · %s" % [day, watch]
