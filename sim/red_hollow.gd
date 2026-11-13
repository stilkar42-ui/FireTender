extends RefCounted

const Fire := preload("res://sim/fire.gd")
const Shelter := preload("res://sim/red_hollow_shelter.gd")
const Kin := preload("res://sim/red_hollow_kin.gd")
const Preparedness := preload("res://sim/hollow_preparedness.gd")
const AfterStorm := preload("res://sim/red_hollow_after_storm.gd")
const Family := preload("res://sim/red_hollow_family.gd")
const Quests := preload("res://sim/story_quests.gd")
const TITLE := "Red Hollow"
const ROUTES := [
	{"place": "Bark ledge", "time": 42.0, "loads": [{4: 5, 5: 3, 0: 3}, {4: 3, 0: 2, Fire.LEAVES: 4}], "rain": 0.85, "moisture": -1.0,
		"description": "The overhang keeps loose bark and grass dry. I can reach it even in light rain."},
	{"place": "Fallen pine in the lee", "time": 28.0, "loads": [{1: 4, 6: 3, 7: 4, 8: 4, 11: 2}, {1: 3, 7: 3, 8: 3, 12: 3}, {8: 2, 13: 2}], "rain": 0.70, "moisture": -1.0,
		"description": "Dry twigs and small branches lie above the wet ground. It’s the shortest path to sound wood."},
	{"place": "Far oak ridge", "time": 76.0, "loads": [{2: 4, 9: 2, 10: 2}, {2: 3, 9: 2, 10: 2}], "rain": 0.36, "moisture": -1.0,
		"description": "There are heavy splits on the ridge. It takes longer, and I need daylight to bring them down safely."},
	{"place": "Watch the sky path", "time": 28.0, "loads": [{}], "rain": 0.52, "moisture": -1.0,
		"description": "From the rise I can see the clouds in the valley and the water coming down the path."},
	{"place": "Standing dead birch", "time": 50.0, "loads": [{0: 3, 7: 3, 12: 3}, {0: 2, 12: 2}], "rain": 0.59, "moisture": -1.0,
		"description": "Dry bark peels easily from the dead birch. Some heavier limbs are still within reach."},
	{"place": "Willows in the hollow", "time": 38.0, "loads": [{13: 4, 7: 2}, {13: 3}], "rain": 0.45, "moisture": 0.62,
		"description": "The hollow has fallen branches, but they lie on damp ground. I would give them time to dry by the hearth."},
]
const PRIORITIES := ["Mixed armful", "Tinder first", "Kindling first", "Larger wood first"]
const SCOUT := 3
const PILE_BOUNDS := Rect2(-2.65, -1.42, 3.83, 2.65)
const OPENING_STOCK := {0: 2, 1: 3, 4: 6, 5: 4, 6: 3, 7: 3, Fire.LEAVES: 4}
const QUESTIONS := {
	"prepared": "Do we have enough for the weather?",
	"storm": "What does that sky tell you?",
	"gather_choice": "What should my cousin bring?",
}
const HANDOFF := "You have watched me choose twice. The wood is yours to judge, and the fire is yours to keep. I’ll help you read it. The choice belongs to our Ember Tender."

var fire: Fire
var weather: Shelter
var trips := PackedInt32Array()
var sites: Array = []
var carried_load: Array[Vector2i] = [] # Source patch index and material kind.
var rack_slots := PackedInt32Array([0, 0, 0, 0])
var consultations: Array[Dictionary] = []
var away := -1
var returns_at := 0.0
var report := "Cousin, I know the dry ledge, the fallen pine and the ridge. The hollow holds damp wood. Look over the paths and tell me what our hearth needs."
var supply_revision := 0
var nest := false
var flame := false
var larger := false
var bed := false
var made_ash := false
var bank_time := 0.0
var preserved := false
var lost_for := 0.0
var outcome := ""
var last_notice := ""
var weather_taught: Dictionary = {}
var sampled_at := 0.0
var sequel: AfterStorm
var family: Family
var wet_delivery_slots := 0
var tinder_bundle_known := false
var storm_reserve: Array = []

func _init(model: Fire) -> void:
	fire = model
	fire.setup(Fire.ONE_EMBER)
	fire.ash = 0.0
	weather = Shelter.new()
	weather.sample(0.0)
	fire.shelter = weather
	trips.resize(ROUTES.size())
	for route: Dictionary in ROUTES:
		sites.append(route.loads.duplicate(true))
	for kind: int in OPENING_STOCK:
		for piece in range(OPENING_STOCK[kind]):
			_store_piece(kind, -1.0)
	fire._settle()
	fire.coals[0].at = Vector2(0.35, 0.14)
	fire._reindex()
	last_notice = Kin.WELCOME

func can_choose_site() -> bool:
	return sequel == null and outcome.is_empty() and fire.wood.is_empty() and fire.coals.size() == 1 and not fire.coals[0].carried and not flame

func begin_after_storm() -> bool:
	if sequel != null or not can_continue() or fire.time < Shelter.END:
		return false
	outcome = ""
	last_notice = ""
	weather.after_storm = true
	weather.sampled = -INF
	weather.sample(fire.time)
	fire.enable_after_storm_materials()
	# The stormfall by the mouth includes wood for both drying methods.
	fire.receive_fuel(11, Vector2(1.06, 1.05), 1.05, 0, 0.58)
	fire.set_wet_skin(fire.receive_fuel(12, Vector2(0.78, 1.12), 2.56, 0, 0.49))
	fire.receive_fuel(13, Vector2(0.40, 1.17), 0.43, 0, 0.98)
	lay_out_drying_logs()
	fire.seat_new_stock()
	sequel = AfterStorm.new(fire)
	report = "I brought in wet oak splits, pine and birch. Some dry wood stayed beneath the rock overhang. Open Quests [O] for the drying work."
	supply_revision += 1
	return true

func lay_out_drying_logs() -> void:
	fire.receive_fuel(8, Vector2(0.82, -1.49), PI * 0.5, 0, 0.45)
	fire.receive_fuel(2, Vector2(0.43, -2.54), PI * 0.5, 0, 0.49)
	fire.receive_fuel(2, Vector2(0.71, -2.54), PI * 0.5, 0, 0.49)
	fire.receive_fuel(2, Vector2(1.00, -2.54), PI * 0.5, 0, 0.54)
	# The protected armful lets a player start drying even after spending
	# the Chapter I reserve in the storm.
	for kind in [1, 1, 1, 7, 7, 8, 8, 8, 2, 2, 2, 2]:
		_store_piece(kind, -1.0)

func quest_rows() -> Array:
	if family != null:
		return []
	if sequel != null:
		return Quests.drying_rows(sequel.drying_complete, not outcome.is_empty())
	var locked := not storm_reserve.is_empty() or not outcome.is_empty()
	var reserve := Quests.storm_reserve(fire) if storm_reserve.is_empty() else storm_reserve
	return Quests.reserve_rows(reserve, locked, outcome in ["kept", "unprepared"], not outcome.is_empty())

func reserve_ready() -> bool:
	return not storm_reserve.is_empty() and Quests.reserve_ready(storm_reserve)

func can_continue() -> bool:
	return outcome in ["kept", "prepared"] or (outcome == "unprepared" and fire.time >= Shelter.END and _has_living_fire())

func _has_living_fire() -> bool:
	return fire.total_flame() > 0.2 or fire.coals.any(func(coal): return coal.living_coal()) \
		or fire.wood.any(func(piece): return piece.smolder > 0.03 or (piece.temperature > 350.0 and piece.char_mass > 0.001))

func set_up_after_storm_trial() -> void:
	# Standalone development/playtest start. The live chapter transition
	# uses the actual surviving bed and never enters this fixture.
	fire.coals.clear()
	fire._new_coal(Vector2(-0.16, 0.04), 0.068, 654.0, 0.045)
	fire._new_coal(Vector2(0.09, -0.12), 0.054, 612.0, 0.040)
	var covered := fire._new_coal(Vector2(0.18, 0.12), 0.059, 565.0, 0.033)
	covered.cover = 0.009
	fire.ash = 0.014
	fire.ash_piles[Vector2i(-6, -1)] = fire.ash
	fire._reindex()
	fire.time = Shelter.END
	fire.storage_sample = fire.time
	fire.receive_fuel(2, Vector2(0.80, -1.29), 0.29, 0, 0.78)
	fire.receive_fuel(8, Vector2(-1.68, -1.03), 0.82, 1)
	fire.receive_fuel(2, Vector2(-2.27, -0.69), 1.15, 0)
	sites[1][0].clear()
	sites[2][0].clear()
	trips[1] = 1
	trips[2] = 1
	outcome = "kept"
	begin_after_storm()

func begin_family(seed_value: int = Family.DEFAULT_SEED) -> bool:
	if outcome != "prepared" or sequel == null or family != null:
		return false
	family = Family.new(fire, seed_value)
	if preserved:
		family.remember_banking()
	outcome = ""
	last_notice = ""
	if away >= 0:
		family.scout_departed(away, (fire.time + returns_at) * 0.5)
	return true

func set_up_family_trial() -> void:
	set_up_after_storm_trial()
	# A separate practice start. The story continuation carries the actual bed.
	sequel.outcomes = "prepared"
	outcome = "prepared"
	begin_family()

func questions() -> Dictionary:
	var prompts := QUESTIONS.duplicate()
	if sequel != null:
		prompts.merge(AfterStorm.QUESTIONS)
	if family != null:
		prompts.merge(Family.Workshop.Lessons.QUESTIONS)
	return prompts

func choose_site(site: int) -> bool:
	if site < 0 or site >= Shelter.SITES.size() or not can_choose_site():
		return false
	var offset := float(Shelter.DEPTHS[weather.site]) - float(Shelter.DEPTHS[site])
	weather.site = site
	for piece in fire.stored:
		if piece.at.y >= PILE_BOUNDS.position.y:
			piece.at = (piece.at + Vector2(0.0, offset)).clamp(PILE_BOUNDS.position, PILE_BOUNDS.end)
	fire.storage_dirty = true
	fire._settle()
	return true

func route_status(route: int, priority := 0) -> String:
	var place: Dictionary = ROUTES[route]
	if not _has_supply(route):
		return "Already searched" if route == SCOUT else "Picked clean"
	if weather.rain > place.rain:
		return "Unsafe in this rain"
	if route == 2 and weather.light < 0.29:
		return "Wait for daylight"
	if route == 2 and not _ridge_daylight():
		return "Too little daylight for the return"
	if away >= 0:
		return "Out on another path"
	if route != SCOUT and _plan_load(route, priority).is_empty():
		return "That fuel is unavailable here"
	return "%d sec of hearth time" % ceili(_journey_time(route))

func can_request(route: int, priority := 0) -> bool:
	if route < 0 or route >= ROUTES.size() or away >= 0 or not outcome.is_empty():
		return false
	if not _has_supply(route) or weather.rain > ROUTES[route].rain or (route == 2 and not _ridge_daylight()):
		return false
	return route == SCOUT or not _plan_load(route, priority).is_empty()

func request(route: int, priority := 0) -> bool:
	if not can_request(route, priority):
		return false
	away = route
	carried_load = _plan_load(route, priority)
	returns_at = fire.time + _journey_time(route)
	if family != null:
		family.scout_departed(route, (fire.time + returns_at) * 0.5)
	report = "I’ll look up the valley. I’ll tell you what the rain is doing when I get back." if route == SCOUT else \
		"I’ll take the path to %s. Keep a little warmth for when I get back, cousin." % ROUTES[route].place.to_lower()
	return true

func _arrive() -> void:
	var route := away
	trips[route] += 1
	away = -1
	var soaked := route == 2 and weather.rain > 0.44
	for piece in carried_load:
		var patch: Dictionary = sites[route][piece.x]
		patch[piece.y] -= 1
		var moisture := _aftermath_moisture(route, piece) if sequel != null else (0.72 if soaked else float(ROUTES[route].moisture))
		_store_piece(piece.y, moisture)
	if not carried_load.is_empty():
		fire._settle(true)
	carried_load.clear()
	supply_revision += 1
	if sequel != null:
		report = route_description(route) + " " + remaining_words(route)
	elif route == SCOUT:
		report = "I saw water on the upper path. A crosswind is pushing it toward the mouth. Keep the dry bundle back from the drip line." if weather.rain > 0.08 else "Cloud is lying beyond the ridge. I marked a dry ledge on the way back. We can still reach the splits before the rain."
	elif soaked:
		report = "The rain reached our splits before I did. Use the drier branches first, cousin. " + remaining_words(route)
	else:
		report = "I laid the wood from %s in our pile. %s" % [ROUTES[route].place.to_lower(), remaining_words(route)]

	if family != null:
		var amounts := remaining(route)
		family.scout_returned(route, report, route != SCOUT,
			amounts[0] + amounts[1] + amounts[2] <= 3)

func route_description(route: int) -> String:
	if sequel == null:
		return ROUTES[route].description
	return [
		"The lip kept this bark dry. It is the first place I would look for fibres.",
		"The fallen pine has sticky knots. Some twigs stayed under rock, but the limbs caught rain.",
		"The oak splits on the ridge drank the rain. They are heavy enough to wait by the warmth.",
		"The water is running off the path. I can see which ledges stayed above it.",
		"Some birch sheltered against the trunk. Feel a broken end and you may find a drier heart.",
		"The fallen willow lay in the water. Save the sound, dry pieces for the fire while it dries.",
	][route]

func _aftermath_moisture(route: int, piece: Vector2i) -> float:
	match route:
		0: return -1.0
		1:
			if piece.y in [1, 6, 7] and piece.x <= 1:
				return 0.16 if piece.x == 0 else 0.32
			return 0.83 if piece.y == 11 else 0.63
		2: return 0.84 if piece.x == 0 else 0.68
		4: return 0.24 if piece.x == 0 else 0.73
		5: return 1.12 if piece.y == 13 else 0.62
	return -1.0

func _journey_time(route: int) -> float:
	return float(ROUTES[route].time) * (1.0 + weather.rain * 0.36 + (0.20 if weather.light < 0.30 else 0.0))

func _ridge_daylight() -> bool:
	var return_phase := (fposmod(fire.time, Shelter.DAY) + _journey_time(2)) / Shelter.DAY
	return weather.light >= 0.29 and return_phase < 1.0 and Shelter.daylight(return_phase) >= 0.29

func _grade(kind: int) -> int:
	if kind in [0, 4, 5, Fire.LEAVES]: return 1
	if kind in [1, 6, 7, 8]: return 2
	return 3

func remaining(route: int) -> PackedInt32Array:
	var amounts := PackedInt32Array([0, 0, 0])
	for patch: Dictionary in sites[route]:
		for kind: int in patch:
			amounts[_grade(kind) - 1] += int(patch[kind])
	return amounts

func _has_supply(route: int) -> bool:
	if route == SCOUT:
		return trips[route] == 0
	var amounts := remaining(route)
	return amounts[0] + amounts[1] + amounts[2] > 0

func _plan_load(route: int, priority: int) -> Array[Vector2i]:
	var load: Array[Vector2i] = []
	var mass := 0.0
	for index in range(sites[route].size()):
		var patch: Dictionary = sites[route][index]
		for kind: int in patch:
			if priority != 0 and _grade(kind) != priority:
				continue
			var profile: Dictionary = Fire.Materials.PROFILES[Fire.FUEL_MATERIAL[kind]]
			var material: Dictionary = Fire.SPECIES[kind]
			var weight := float(material.get("mass", float(material.get("volume", 0.0)) * float(profile.density)))
			for piece in range(int(patch[kind])):
				if load.size() == 18 or mass + weight > 3.25:
					break
				mass += weight
				load.append(Vector2i(index, kind))
		if priority == 0 and not load.is_empty():
			break
	return load

func remaining_words(route: int) -> String:
	if route == SCOUT:
		return "I’ve checked that path." if trips[route] > 0 else "I can check what’s coming down the valley."
	var amounts := remaining(route)
	var left := PackedStringArray()
	for i in range(amounts.size()):
		if amounts[i] > 0:
			var measure := "a little" if amounts[i] < 4 else ("an armful of" if amounts[i] < 11 else "plenty of")
			left.append("%s %s" % [measure, ["tinder", "small wood", "larger wood"][i]])
	if left.is_empty():
		return "I’ve taken what I can reach there."
	return "There’s %s left there." % ", ".join(left)

func _store_piece(kind: int, moisture: float) -> void:
	if sequel != null and moisture >= 0.34:
		var wet_slot := wet_delivery_slots
		wet_delivery_slots += 1
		var at := Vector2(0.37 + (wet_slot % 5) * 0.15, -1.58 - (wet_slot % 2) * 0.46)
		var piece := fire.receive_fuel(kind, at, PI * 0.5, floori(wet_slot / 5.0), moisture)
		if kind == 12:
			fire.set_wet_skin(piece)
		sequel.track(piece)
		return
	var group := 0 if kind in [0, 4, 5, Fire.LEAVES] else (1 if kind in [1, 6, 7] else (2 if kind in [8, 11, 12, 13] else 3))
	var slot := rack_slots[group]
	rack_slots[group] += 1
	var z: float = [-1.32, -1.02, -0.69, -0.27][group]
	var at := Vector2(-1.49 - (slot % 6) * 0.177, z - float(Shelter.DEPTHS[weather.site]) + (slot % 2) * 0.036)
	fire.receive_fuel(kind, at.clamp(PILE_BOUNDS.position, PILE_BOUNDS.end), PI * 0.5 + (slot % 3 - 1) * 0.10, floori(slot / 6.0), moisture)

func gathering_advice() -> String:
	if sequel != null:
		if _has_supply(0):
			return "There is bark left beneath the ledge. Use that dry tinder to keep the red alive while you set the wet branches near the warmth."
		if _has_supply(4):
			return "Try the standing birch. Some branches were protected. Your cousin can show you which wood still holds water."
		return "The dry paths have little left. Keep the dry pieces you already have for the red, and take the wet wood in small loads."
	if consultations.size() >= 2:
		return HANDOFF
	if away >= 0:
		return "Your cousin is out already. When he comes home, look at what he laid in the pile and we’ll decide what the hearth still needs."
	var stock := fire.fuel_stock
	var tinder := stock[4] + stock[5] + stock[0]
	var branch := stock[8] + stock[11] + stock[12]
	var heavy := stock[2] + stock[9] + stock[10]
	var need := 3
	if tinder < 3:
		need = 1
	elif branch < 2 or (fire.total_flame() < 3.0 and not bed and stock[1] < 2):
		need = 2
	elif heavy >= 4:
		need = 1 if tinder < 8 else 2
	var chosen := -1
	var grade := need
	var best := -INF
	for route in range(ROUTES.size()):
		if route == SCOUT:
			continue
		var left := remaining(route)
		for kind in range(1, 4):
			if left[kind - 1] == 0 or not can_request(route, kind):
				continue
			var closing := smoothstep(Shelter.DAY * 1.3, Shelter.DAY * 2.15, fire.time + _journey_time(route))
			var score := (5.0 if kind == need else 0.0) + minf(1.0, left[kind - 1] * 0.12) - _journey_time(route) * 0.018
			if kind == 3 and route == 2 and heavy < 2:
				score += 1.1
			score -= closing * (2.7 if route == 2 else 0.6)
			score -= 2.0 if float(ROUTES[route].moisture) > 0.30 else 0.0
			if score > best:
				best = score
				chosen = route
				grade = kind
	if chosen < 0:
		return "The paths he can walk have little to give us now. Check the wood under cover. Keep a little of the driest back to wake the red."
	var reason: String
	if chosen == 5:
		reason = "Those branches are damp. Let them dry near the warmth while the dry pieces keep the fire alive."
	elif grade != need:
		reason = "He can reach this wood today. Save the driest pieces we have for waking the coals when the weather turns."
	elif grade == 1:
		reason = "We need dry fibres in reserve. A little coal can wake them without spending its heat on a branch."
	elif grade == 2:
		reason = "We have little small wood ready. Give the flame thin fuel it can take before you ask it to warm a split."
	else:
		reason = "We have small wood to start the flame. Bring larger wood while the path is open, then save it for a bed of red."
	consultations.append({"route": chosen, "priority": grade, "time": fire.time, "reason": reason})
	return "Ask for %s from %s. %s" % [["tinder", "small wood", "larger wood"][grade - 1], ROUTES[chosen].place.to_lower(), reason]

func step() -> void:
	if not outcome.is_empty():
		return
	fire.step()
	if away >= 0 and fire.time >= returns_at:
		_arrive()
	if family != null:
		family.step()
		return
	if sequel != null:
		sequel.update()
		outcome = sequel.outcomes
		return
	if fire.time < Shelter.END and fire.time - sampled_at < 0.5:
		return
	var elapsed := fire.time - sampled_at
	sampled_at = fire.time
	if storm_reserve.is_empty() and fire.time >= Quests.RESERVE_AT:
		storm_reserve = Quests.storm_reserve(fire)
	var strength := fire.total_flame()
	var hot_coal := 0.0
	var hot_cover := 0.0
	var ash_mass := fire.ash
	var viable := strength > 0.2
	var nest_fibres := 0
	for coal in fire.coals:
		ash_mass += coal.mineral + coal.cover
		if coal.living_coal():
			viable = true
			hot_coal += coal.char_mass
			if coal.cover > 0.002:
				hot_cover += coal.char_mass
	for piece in fire.wood:
		if piece.fibre and piece.water < piece.original * 0.2 and fire.coals.any(func(coal): return coal.at.distance_to(piece.at) < 0.17):
			nest_fibres += 1
		larger = larger or (piece.original >= 0.1 and piece.flame > 3.0)
		viable = viable or piece.smolder > 0.03 or (piece.temperature > 350.0 and piece.char_mass > 0.001)
	nest = nest or nest_fibres >= 2
	flame = flame or strength > 3.0
	bed = bed or hot_coal > 0.038
	made_ash = made_ash or ash_mass >= 0.001
	bank_time = bank_time + elapsed if hot_cover > 0.008 and strength < 4.0 else 0.0
	preserved = preserved or bank_time >= 45.0
	lost_for = 0.0 if viable else lost_for + elapsed
	if lost_for >= 18.0:
		outcome = "lost"
	elif fire.time >= Shelter.END:
		weather.sample(Shelter.END)
		outcome = ("kept" if bed and preserved else "unprepared") if viable else "lost"

func guidance() -> String:
	if family != null:
		return "Nara can show you the roasting stones, and Ina will put a sound haft to good use. Leave a little red alive while you work."
	if sequel != null:
		return sequel.guidance()
	if outcome == "lost":
		return "The living fire is gone. Return to the day I brought the coal home and we’ll try together."
	if outcome == "unprepared":
		return "The rain has passed. We still have living fire. Keep dry tinder close while we bring in the fallen wood."
	if outcome == "kept":
		return "The rain has passed, and you kept the living heart through the third night. The hearth is yours to tend."
	if not nest and not flame:
		return "Lay a little nest of loose, dry fibres. Lift our coal into it and leave a way for air."
	if not flame:
		return "Keep the fibres close to the red. Give a soft breath, then wait and see whether it brightens."
	if not larger:
		if fire.total_flame() < 0.2:
			return "The flame has gone. Look for living red before you lay on more wood. The ash can still hold heat."
		return "Let dry twigs catch first, then a thin stick. Ask your cousin for branches before the small flame spends its food."
	if not bed:
		return "Give one branch time to catch. Let the red charcoal build underneath before laying on a heavy split."
	if not made_ash:
		return "Let some fuel burn down. The powder it leaves is what will shelter our coals."
	if not preserved:
		return "Sweep loose ash aside, then sift it over a bed of red when the flame settles. Let the covered coals rest."
	if weather.rain > 0.20:
		return "Rain is at the mouth. Look for hissing wood and keep the dry bundle back. Leave a little red sheltered under ash."
	return "Keep something dry in reserve for waking the coals. The cloud will come nearer before it passes."

func objective() -> String:
	if family != null:
		return "Keep the living hearth for your kin."
	if sequel != null:
		return sequel.objective()
	if outcome == "lost": return "The living fire is gone. F1 begins again."
	if outcome == "kept": return "The storm has passed. The hearth is yours."
	if outcome == "unprepared": return "Day Three ended with living fire and some tending still to learn."
	if not nest and not flame: return "Lay loose tinder and carry the coal into it."
	if not flame: return "Nurse the red with a soft breath."
	if not larger: return "Feed the flame with twigs, then a branch." if fire.total_flame() >= 0.2 else "The flame has gone. Check the bed for living red."
	if not bed: return "Build a bed of living charcoal."
	if not made_ash: return "Let fuel burn down to ash."
	if not preserved: return "Sweep ash, cover the red and let it rest."
	return "Keep a living bed through the storm."

func preparedness(topic := "") -> String:
	return Preparedness.answer(fire, weather, topic)

func wind_advice() -> String:
	if weather.inward_draft():
		return "The wind is turning under the lip. Watch the smoke lean back toward us. Move the driest wood in from the drip line."
	if weather.wind.length() > 0.35:
		return "See the rain slant and the smoke lean? The wind is strong. Watch which way it pushes before you move the wood."
	return "There’s little wind at the hearth now. If the smoke stops rising cleanly, look which way the draft is carrying it."

func _sky_advice() -> String:
	match weather.watch():
		Shelter.Watch.BUILDING:
			return "See the clouds thickening over the ridge? The dry paths are still open. Keep sound wood under cover before the weather turns."
		Shelter.Watch.RAIN_LINE:
			return "See the grey curtain below the clouds? Rain is coming toward the mouth. Bring the driest wood back from the drip line."
		Shelter.Watch.RAIN:
			return "Rain is falling beyond the lip. See how it slants with the wind? If it bends under the rock, watch for hissing wood."
		Shelter.Watch.STORM:
			return "The dark sky and broad rain tell me this will sit a while. Feed from the dry pile and keep enough ash to shelter the red."
		Shelter.Watch.EASING:
			return "The worst of the front is passing. Watch the rain thin. Check the red before you spend any of the dry wood you saved."
	return "There’s space between the clouds. Use this clear stretch to gather dry wood and make a bed of red. Keep some ash ready to cover it."

func weather_lesson() -> String:
	if family != null:
		return ""
	if sequel != null:
		return sequel.next_passage()
	var stage := weather.watch()
	if stage != Shelter.Watch.CLEAR and not weather_taught.has(stage):
		weather_taught[stage] = true
		return _sky_advice()
	if weather.inward_draft() and not weather_taught.has("wind"):
		weather_taught["wind"] = true
		return wind_advice()
	if stage in [Shelter.Watch.RAIN_LINE, Shelter.Watch.RAIN, Shelter.Watch.STORM] and not weather_taught.has("reserve"):
		weather_taught["reserve"] = true
		return preparedness()
	return ""

func answer(topic: String) -> String:
	match topic:
		"return": return Kin.RETURNED
		"torch_kin": return Kin.TORCH
		"scout":
			if away >= 0:
				return "Your cousin is on the path now. He’ll tell us what stayed dry when he gets back."
			if weather.rain > 0.36:
				return "The ridge will be wet. Ask your cousin about the ledge and the lee path. He knows which places have cover."
			return "Your cousin can check the dry places in the lee. Ask what he has seen and choose what our hearth needs first."
		"shelter": return "Under the lip there is cover and a way out for smoke. Farther in, smoke can hang over us. At the mouth, a wind off the valley can drive rain into the coals."
		"ash":
			if fire.ash >= 0.001:
				return "There is loose ash ready. Wait for the flame to settle, then sift it over the red. Keep enough breath for the coals to live."
			return "Let the wood burn down to powder. Sweep it to a dry spot beside the bed, then use it to shelter the red when the flame settles."
		"rain":
			if fire.rain_at(Vector2.ZERO) > 0.08:
				return "The wind is bringing rain to this spot. Watch for a hiss where drops meet the wood. Keep dry fuel farther in and shelter the living coals with ash."
			return "The bed has cover here now. If the wind turns in, watch for hissing wood. Water takes the warmth a little fire needs to catch."
		"storm": return _sky_advice()
		"weather_wind": return wind_advice()
	return guidance()
