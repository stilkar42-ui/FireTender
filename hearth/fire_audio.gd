extends Node
## Original procedural sound. This mixer only reads the simulation.
## Samples run on an audio clock, including when the experiment is paused.

const Fire := preload("res://sim/fire.gd")
const RATE := 22050
const BLOCK := 512

class Mix:
	var roar := 0.0
	var crackle := 0.0
	var hiss := 0.0
	var breath := 0.0
	var bed := 0.0
	var rain := 0.0
	var wind := 0.0
	var thunder := 0.0
	var pan := 0.0
	var wet_pan := 0.0
	var draft_pan := 0.0

var fire: Fire
var listener := Vector2(0, 1.35)
var fire_volume := 0.76
var weather_volume := 0.60
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var active := true
var target := Mix.new()
var rng := RandomNumberGenerator.new()
var bass := 0.0
var mid := 0.0
var slow := 0.0
var tick_noise := 0.0
var pop := 0.0
var tail := 0.0
var pop_pan := 0.0
var rain_tap := 0.0
var scratch := 0.0
var scratch_pan := 0.0
var scrape := false
var snap_phase := 0.0
var snap_rate := 0.12
var current_roar := 0.0
var current_hiss := 0.0
var current_air := 0.0
var current_bed := 0.0
var current_wind := 0.0
var current_rain := 0.0
var current_pan := 0.0
var current_wet_pan := 0.0
var current_draft_pan := 0.0

func _ready() -> void:
	rng.randomize()
	if DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 0.23
	player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	_set_playback()

func set_active(enabled: bool) -> void:
	if active == enabled:
		return
	active = enabled
	_set_playback()

func _set_playback() -> void:
	if player == null:
		return
	if active:
		player.play()
		playback = player.get_stream_playback()
		_process(0.0)
	else:
		player.stop()
		playback = null

func _process(_delta: float) -> void:
	if playback == null or fire == null:
		return
	target = measure(fire, listener)
	var available := playback.get_frames_available()
	while available >= BLOCK:
		playback.push_buffer(render(BLOCK))
		available -= BLOCK

static func measure(model: Fire, ear: Vector2) -> Mix:
	var result := Mix.new()
	var fire_weight := 0.0
	var wet_weight := 0.0
	var gust_weight := 0.0
	for p in model.thermal_sources():
		var near := 0.38 + 0.62 / (1.0 + ear.distance_squared_to(p.at) * 1.8)
		var pan := clampf((p.at.x - ear.x * 0.30) * 0.9, -0.88, 0.88)
		var burning := near * (p.flame + p.char_heat * 0.15)
		var steam := p.vapor * near
		var gust := p.pulse * near
		fire_weight += burning
		wet_weight += steam
		gust_weight += gust
		result.pan += burning * pan
		result.wet_pan += steam * pan
		result.draft_pan += gust * pan
		result.roar += p.flame * near
		result.bed += p.char_heat * near * exp(-3.1 * p.depth())
		result.crackle += (p.flame * 0.12 + p.smoke * 210.0) * near
	result.pan /= maxf(0.001, fire_weight)
	result.wet_pan /= maxf(0.00001, wet_weight)
	result.draft_pan /= maxf(0.001, gust_weight)
	result.roar = smoothstep(0.0, 78.0, result.roar)
	result.bed = smoothstep(0.0, 38.0, result.bed)
	result.hiss = smoothstep(0.00002, 0.0032, wet_weight)
	result.breath = smoothstep(0.0, 2.1, gust_weight)
	result.crackle = clampf(result.crackle * 0.72 + result.bed * 0.38, 0.0, 11.0)
	result.wind = model.weather_wind(ear).length()
	result.rain = model.rain_at(ear)
	if model.shelter != null:
		result.rain = maxf(result.rain, model.shelter.rain * 0.28)
		result.thunder = model.shelter.thunder
	return result

func contact(at: Vector2, charcoal: bool, heavy := false) -> void:
	scratch = 1.0 if heavy or charcoal else 0.53
	scratch_pan = clampf(at.x * 0.85, -0.85, 0.85)
	scrape = charcoal
	if not charcoal:
		pop = 0.27 if heavy else 0.11
		tail = pop
		pop_pan = scratch_pan
		snap_phase = 0.0
		snap_rate = rng.randf_range(0.023, 0.048)

func structure_event(kind: String, at: Vector2, mass: float, _height: float, _temperature: float) -> void:
	if kind == "fall":
		return
	if kind == "pop":
		var distance := listener.distance_to(at)
		pop = maxf(pop, clampf(0.26 + mass * 1.8, 0.29, 0.72) / (1.0 + distance * 1.2))
		tail = maxf(tail, pop * 0.72)
		pop_pan = clampf((at.x - listener.x) * 0.55, -0.9, 0.9)
		snap_phase = 0.0
		snap_rate = lerpf(0.13, 0.072, smoothstep(0.08, 0.27, mass))
		return
	contact(at, kind == "land", mass > 0.15)
	if kind == "break":
		pop = clampf(0.22 + mass * 1.2, 0.22, 0.82)
		tail = pop * 0.58
		snap_rate = 0.07
	elif kind == "land":
		pop = clampf(0.08 + mass * 7.0, 0.08, 0.34)
		tail = pop * 0.85
		pop_pan = scratch_pan

func render(frame_count: int) -> PackedVector2Array:
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	var click_chance := target.crackle / RATE
	var rain_chance := target.rain * 235.0 / RATE
	for i in range(frame_count):
		var white := rng.randf_range(-1.0, 1.0)
		bass += (white - bass) * 0.025
		mid += (white - mid) * 0.26
		slow += (white - slow) * 0.0018
		tick_noise += (white - tick_noise) * 0.72
		current_roar = lerpf(current_roar, target.roar, 0.0007)
		current_hiss = lerpf(current_hiss, target.hiss, 0.0012)
		current_air = lerpf(current_air, target.breath, 0.0012)
		current_bed = lerpf(current_bed, target.bed, 0.0008)
		current_wind = lerpf(current_wind, target.wind, 0.0007)
		current_rain = lerpf(current_rain, target.rain, 0.0007)
		current_pan = lerpf(current_pan, target.pan, 0.0009)
		current_wet_pan = lerpf(current_wet_pan, target.wet_pan, 0.0009)
		current_draft_pan = lerpf(current_draft_pan, target.draft_pan, 0.0009)

		if rng.randf() < click_chance:
			pop = rng.randf_range(0.035, 0.23)
			tail = pop
			pop_pan = clampf(current_pan + rng.randf_range(-0.24, 0.24), -0.96, 0.96)
			snap_phase = 0.0
			snap_rate = rng.randf_range(0.07, 0.50)
		pop *= 0.974
		tail *= 0.9965
		snap_phase += snap_rate
		var snap := (white - bass) * pop + sin(snap_phase) * tail * 0.32
		if rng.randf() < rain_chance:
			rain_tap = rng.randf_range(0.012, 0.047)
		rain_tap *= 0.961
		var grit := (mid - bass) * scratch * (0.15 if scrape else 0.06)
		grit += bass * scratch * (0.08 if scrape else 0.17)
		scratch *= 0.9995 if scrape else 0.9989
		var rush := (bass * 0.79 + (mid - bass) * 0.18) * current_roar * (0.61 + slow * 4.0)
		var ember := (mid - bass) * current_bed * 0.027
		var steam := (white - mid) * current_hiss * (0.092 + slow * 0.53)
		var breath := (mid - bass) * current_air * 0.24 + bass * current_air * 0.14
		var wind := (bass * 0.53 + (mid - bass) * 0.077) * current_wind * (0.42 + slow * 4.8)
		wind += (slow * 3.7 + bass * 0.14) * target.thunder
		var rain := (tick_noise - mid) * current_rain * 0.075 + (white - mid) * rain_tap
		var local := _pan(rush + ember, current_pan) + _pan(steam, current_wet_pan) + _pan(breath, current_draft_pan)
		local += _pan(snap, pop_pan) + _pan(grit, scratch_pan)
		var outside := Vector2(wind + rain, wind + rain * 0.76 + (white - tick_noise) * current_rain * 0.042)
		frames[i] = (local * fire_volume + outside * weather_volume).clamp(-Vector2.ONE, Vector2.ONE)
	return frames

func _pan(sample: float, position: float) -> Vector2:
	return Vector2(1.0 - maxf(position, 0.0), 1.0 + minf(position, 0.0)) * sample
