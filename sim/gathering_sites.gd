extends RefCounted
## Field inventory. IDs persist through weather, collection and delivery.
const Fire := preload("res://sim/fire.gd")
const Shelter := Fire.Shelter
const SCOUT := 3
const LIMIT := 3.25
const MAX_PIECES := 18
const OPENING_STORM := "red_hollow_first_storm"
const DEFAULT_SEED := 8217
const CONDITIONS := ["protected", "damp", "wet", "waterlogged"]
# Cover by patch, wind exposure, runoff, and dead branch sources.
const TERRAIN := [
	[[0.95, 0.90], 0.14, 0.0, {}],
	[[0.66, 0.42, 0.20], 0.54, 0.12, {1: 4, 7: 4, 8: 3, 11: 3}],
	[[0.22, 0.30], 0.94, 0.0, {2: 3, 9: 3, 10: 2}],
	[[], 0.70, 0.25, {}],
	[[0.68, 0.45], 0.61, 0.10, {7: 4, 12: 4}],
	[[0.14, 0.04], 0.43, 1.0, {13: 6, 7: 2}],
]

var records: Array = []
var events: Dictionary = {}
var world_seed := DEFAULT_SEED

func initialize(routes: Array, legacy_stock: Array = []) -> void:
	records.clear()
	events.clear()
	for route in range(routes.size()):
		var spec: Dictionary = routes[route]
		var entries: Array = []
		var remaining: Array = spec.loads if legacy_stock.is_empty() else legacy_stock[route]
		for patch in range(spec.loads.size()):
			var stock: Dictionary = remaining[patch] if patch < remaining.size() else {}
			for kind: int in spec.loads[patch]:
				for index in range(spec.loads[patch][kind]):
					var entry := _entry(kind, entries.size(), patch, float(TERRAIN[route][0][patch]), spec.moisture)
					if index >= int(stock.get(kind, 0)):
						entry.state = "collected"
						entry.collector = "Rusk"
					entries.append(entry)
		records.append({"place": spec.place, "pieces": entries, "changes": {}, "delay_until": 0.0, "revision": 0})

static func _entry(kind: int, id: int, patch: int, cover: float, moisture := -1.0) -> Dictionary:
	var water := float(Fire.SPECIES[kind].water) if moisture < 0.0 else moisture
	return {"id": id, "kind": kind, "patch": patch, "cover": cover, "source": "", "state": "available",
		"moisture": water, "initial_moisture": water, "temperature": 10.0, "skin": false,
		"wood": "deadwood", "exposure": 0.0, "history": [], "collector": "", "taken_at": -1.0, "fuel_id": 0}

static func grade(kind: int) -> int:
	if kind in Fire.RAW_TINDER:
		return 1
	if kind in [1, 6, 7, 8]:
		return 2
	return 3

static func condition(entry: Dictionary) -> int:
	var moisture: float = entry.moisture
	return 0 if moisture < 0.26 else (1 if moisture < 0.50 else (2 if moisture < 0.88 else 3))

static func dry_mass(kind: int) -> float:
	var material: Dictionary = Fire.Materials.PROFILES[Fire.FUEL_MATERIAL[kind]]
	var species: Dictionary = Fire.SPECIES[kind]
	return float(species.get("mass", float(species.get("volume", 0.0)) * float(material.density)))

func plan(route: int, priority: int, after_storm: bool) -> PackedInt32Array:
	var load := PackedInt32Array()
	if route == SCOUT:
		return load
	var mass := 0.0
	var last_patch := -1
	var eligible: Array = records[route].pieces.filter(func(piece: Dictionary) -> bool:
		return piece.wood == "deadwood" and piece.state == "available" and (priority in [0, 4, 5] or grade(piece.kind) == priority) \
			and (priority != 4 or condition(piece) == 0) and (priority != 5 or (condition(piece) > 0 and piece.moisture >= 0.34)))
	if priority == 5:
		eligible = eligible.filter(func(piece: Dictionary) -> bool: return piece.kind in [2, 8, 9, 10, 11, 12, 13])
		eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.moisture < b.moisture)
	for piece: Dictionary in eligible:
		if not after_storm and priority == 0 and last_patch >= 0 and piece.patch != last_patch:
			break
		var weight := dry_mass(piece.kind) * (1.0 + (float(piece.moisture) if after_storm else 0.0))
		if mass + weight > LIMIT:
			continue
		mass += weight
		last_patch = piece.patch
		load.append(piece.id)
		if load.size() == MAX_PIECES:
			break
	return load

func counts(route: int, by_condition := false) -> PackedInt32Array:
	var amounts := PackedInt32Array([0, 0, 0, 0] if by_condition else [0, 0, 0])
	for piece: Dictionary in records[route].pieces:
		if piece.wood == "deadwood" and piece.state == "available":
			amounts[condition(piece) if by_condition else grade(piece.kind) - 1] += 1
	return amounts

func take(route: int, ids: PackedInt32Array, at: float, rain: float, temperature: float,
		collector := "Rusk", wet_limit := false) -> PackedInt32Array:
	var taken := PackedInt32Array()
	var mass := 0.0
	for id in ids:
		var piece: Dictionary = records[route].pieces[id]
		if piece.state != "available" or piece.wood != "deadwood":
			continue
		if rain > 0.44:
			_wet(piece, 0.72 if route == 2 else rain * 0.60, temperature, "collected in rain", at)
		elif events.is_empty():
			piece.temperature = temperature
		var weight := dry_mass(piece.kind) * (1.0 + (float(piece.moisture) if wet_limit else 0.0))
		if wet_limit and (mass + weight > LIMIT or taken.size() >= MAX_PIECES):
			continue
		mass += weight
		piece.state = "collected"
		piece.collector = collector
		piece.taken_at = at
		taken.append(id)
	records[route].revision += 1
	return taken

static func authored_storm() -> Dictionary:
	var weather := Shelter.new()
	var rainfall := 0.0
	var duration := 0.0
	var peak := 0.0
	var wind := Vector2.ZERO
	for at in range(int(Shelter.STORM_BEGINS), int(Shelter.END), 4):
		weather.sample(at)
		rainfall += weather.rain * 4.0
		if weather.rain > 0.08:
			duration += 4.0
		peak = maxf(peak, weather.wind.length())
		wind += weather.wind * weather.rain
	weather.sample(Shelter.END)
	return {"duration": duration, "rain": rainfall, "wind": wind.normalized(), "gust": peak, "temperature": weather.temperature}

func apply_storm(key: String, event: Dictionary, at: float) -> bool:
	if events.has(key):
		return false
	events[key] = event.duplicate(true)
	events[key].at = at
	var rain := clampf(event.rain / 260.0, 0.0, 1.5)
	var duration := clampf(event.duration / 345.0, 0.0, 1.5)
	var gust: float = event.gust
	if rain <= 0.0 and gust < 0.54:
		return true
	for route in range(records.size()):
		if route == SCOUT:
			continue
		var terrain: Array = TERRAIN[route]
		var site: Dictionary = records[route]
		var bearing := Vector2.from_angle(route * 1.51 + 0.40)
		var exposure := float(terrain[1]) * (0.82 + 0.18 * bearing.dot(event.wind))
		var runoff := float(terrain[2]) * rain
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world_seed, key, route])
		var weathered := 0
		for piece: Dictionary in site.pieces:
			if piece.state != "available":
				continue
			var absorbed := rain * (1.0 - float(piece.cover)) * (0.43 + exposure * 0.48)
			var target := float(piece.moisture) + absorbed + runoff * duration * 0.39
			if _wet(piece, target, event.temperature, key, at):
				weathered += 1
		var added := 0
		var impact := maxf(0.0, gust - 0.37) * exposure * 1.42 + rain * 0.18 + runoff * 0.36
		for kind: int in terrain[3]:
			for roll in range(int(terrain[3][kind])):
				if rng.randf() > impact:
					continue
				var cover := clampf(float(terrain[0][0]) + rng.randf_range(-0.32, 0.33), 0.0, 0.97)
				var piece := _entry(kind, site.pieces.size(), terrain[0].size(), cover)
				piece.source = key
				var target := float(piece.moisture) + rain * (1.0 - cover) * (0.40 + 0.50 * exposure) + runoff * 0.72
				_wet(piece, target, event.temperature, key, at)
				site.pieces.append(piece)
				added += 1
		var delay := clampf((impact + runoff - 0.82) * 92.0, 0.0, 95.0)
		if delay > 0.0:
			site.delay_until = maxf(site.delay_until, at + delay)
		site.changes[key] = {"at": at, "weathered": weathered, "added": added, "delay": delay}
		site.revision += 1
	return true

static func _wet(piece: Dictionary, target: float, temperature: float, event: String, at: float) -> bool:
	var capacity: float = Fire.Materials.PROFILES[Fire.FUEL_MATERIAL[piece.kind]].water_capacity
	piece.temperature = temperature
	var water := minf(capacity, maxf(target, piece.moisture))
	if water <= float(piece.moisture) + 0.001:
		return false
	piece.history.append({"event": event, "at": at, "from": piece.moisture, "to": water})
	piece.exposure += water - float(piece.moisture)
	piece.moisture = water
	piece.skin = condition(piece) == 1
	return true

func snapshot(route: int, at: float) -> Dictionary:
	var site: Dictionary = records[route]
	var change: Dictionary = site.changes.values().back() if not site.changes.is_empty() else {}
	return {"counts": counts(route, true), "grades": counts(route), "fallen": int(change.get("added", 0)),
		"dry_load": not plan(route, 4, true).is_empty(), "drying_load": not plan(route, 5, true).is_empty(),
		"delay": float(site.delay_until), "seen": at, "revision": site.revision}

func restore_legacy_aftermath(temperature: float, at: float) -> void:
	events[OPENING_STORM] = {"legacy": true}
	for route in [1, 2, 4, 5]:
		for piece: Dictionary in records[route].pieces:
			if piece.state != "available":
				continue
			var water := 0.0
			match route:
				1: water = (0.16 if piece.patch == 0 else 0.32) if piece.kind in [1, 6, 7] and piece.patch <= 1 else (0.83 if piece.kind == 11 else 0.63)
				2: water = 0.84 if piece.patch == 0 else 0.68
				4: water = 0.24 if piece.patch == 0 else 0.73
				5: water = 1.12 if piece.kind == 13 else 0.62
			_wet(piece, water, temperature, OPENING_STORM, at)
