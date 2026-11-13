extends RefCounted
## Chapter III uses the hearth clock. Field events change actual state first.
## A separate ledger changes when someone can see or report what happened.

const Fire := preload("res://sim/fire.gd")
const Roster := preload("res://sim/family_roster.gd")
const Craft := preload("res://sim/family_work.gd")
const Stormfall := preload("res://sim/stormfall_bison.gd")
const Workshop := preload("res://sim/family_workshop.gd")
const Shelter := preload("res://sim/red_hollow_shelter.gd")
const Land := preload("res://sim/family_land.gd")
const TITLE := "The Work of the Family"
const DEFAULT_SEED := 731
const HOME := Land.HOME
const SHELF := Land.SHELF
const PINE := Land.PINE
const WOODS := Land.WOODS
const STREAM := Land.STREAM
const TRAIL := Land.TRAIL
const MEADOW := Land.MEADOW
const RIDGE := Land.RIDGE
const ROUTE_PLACES := Land.ROUTE_PLACES
const HUNTERS := ["bera", "ivo", "kett"]
const MEAL := 450
const EVENT_LIMIT := 18
const TENDENCIES := {
	"sela": [0.47, 0.82, 1.02],
	"oren": [0.23, 1.03, 1.30],
	"dena": [0.72, 0.72, 0.77],
}
const HUNT_WORDS := ["Stay near the hearth", "Send one hunter for small game", "Send two hunters after deer"]

var fire: Fire
var weather: Shelter
var workshop: Workshop
var craft := Craft.new()
var stormfall := Stormfall.new()
var next_spoil := 0.0
var land := Land.new()
var next_weather_memory := 0.0
var rng := RandomNumberGenerator.new()
var sites := {
	HOME: {"hazard": 0.0},
	SHELF: {"hazard": 0.12},
	PINE: {"hazard": 0.12, "knots": 4},
	WOODS: {"hazard": 0.17, "small": 5},
	STREAM: {"hazard": 0.22, "roots": 4},
	TRAIL: {"hazard": 0.23, "large": 3},
	MEADOW: {"hazard": 0.30, "large": 2},
	RIDGE: {"hazard": 0.36},
}
var people: Dictionary = {}
var known: Dictionary = {}
var signs := {
	"small": {"place": WOODS, "strength": 0.67, "seen": 0.0},
	"large": {"place": TRAIL, "strength": 0.66, "seen": 0.0},
}
var news: Array[Dictionary] = []
var waiting_news: Array[Dictionary] = []
var latest: Dictionary = {}
var news_revision := 0
var knowledge_revision := 0
var decision: Dictionary = {}
var hunt: Dictionary = {}
var errand: Dictionary = {}
var next_council: float
var next_meal: float
var next_errand: float
var next_work: float
var sampled_at: float
var next_errand_index := 0
var hunger := 0.05
var recent_injury := 0.0
var recent_success := 0.0
var low_fuel := false
var thin_flame := 0.0
var bank_time := 0.0
var transfer: Dictionary = {}
var scout_route := -1
var scout_weather_at := INF
var scout_weather: Dictionary = {}
var scout_sighting: Dictionary = {}

func _init(model: Fire, seed_value: int = DEFAULT_SEED) -> void:
	fire = model
	weather = fire.shelter
	workshop = Workshop.new(fire)
	craft.begin(fire.time)
	stormfall.begin(fire.time)
	next_spoil = fire.time + 6.0
	rng.seed = seed_value
	sampled_at = fire.time
	next_council = fire.time + 42.0
	next_meal = fire.time + 135.0
	next_errand = fire.time + 61.0
	next_work = fire.time + 34.0
	for sign in signs.values():
		sign.seen = fire.time
	for id: String in Roster.PEOPLE:
		var person: Array = Roster.PEOPLE[id]
		people[id] = {"activity": person[4], "place": person[5], "away": false, "fatigue": 0.0,
			"injury": 0.28 if id == Roster.SPEAKER else 0.0}
		_learn_person(id, "Seen at the shelter")
	_observe_shelter_weather()
	remember_workplace(Workshop.HUNTER)
	land.remember(WOODS, "sign", "Rusk found fresh hare tracks.", "Rusk", fire.time, fire.time, "tracks")
	land.remember(TRAIL, "sign", "Rusk found fresh deer tracks.", "Rusk", fire.time, fire.time, "tracks")
	_publish(Roster.SCOUT, "Bera brought in a cut of game. Your mother has put out the spits. I saw fresh sign in the woods and along the deer trail.", -1.0, TRAIL)

func _learn_person(id: String, source: String) -> void:
	var state: Dictionary = people[id]
	known[id] = {"activity": state.activity, "place": state.place, "learned": fire.time,
		"seen": fire.time, "source": source, "injury": state.injury, "fatigue": state.fatigue, "away": state.away}
	knowledge_revision += 1

func _set_activity(id: String, activity: String, place: String, away := false, witness := "Seen at the shelter") -> void:
	var state: Dictionary = people[id]
	if state.activity == activity and state.place == place and state.away == away:
		return
	state.activity = activity
	state.place = place
	state.away = away
	if not witness.is_empty():
		_learn_person(id, witness)

func _publish(by: String, words: String, happened := -1.0, place := "", topic := "news", mark := "") -> void:
	var seen_at := fire.time if happened < 0.0 else happened
	latest = {"by": by, "text": words, "happened": seen_at, "heard": fire.time, "place": place}
	if not place.is_empty() and not topic.is_empty():
		land.remember(place, topic, words, Roster.person_name(by), seen_at, fire.time, mark)
	news.append(latest)
	if news.size() > EVENT_LIMIT:
		news.pop_front()
	news_revision += 1

func _tell_scout(words: String, place := "", topic := "news", mark := "") -> void:
	if people[Roster.SCOUT].away:
		waiting_news.append({"text": words, "happened": fire.time, "place": place, "topic": topic, "mark": mark})
		if waiting_news.size() > EVENT_LIMIT:
			waiting_news.pop_front()
	else:
		_publish(Roster.SCOUT, words, -1.0, place, topic, mark)

func _depart_person(id: String, place: String, purpose: String) -> void:
	_set_activity(id, "Last seen leaving for " + place.to_lower(), HOME, true)
	known[id].destination = place
	known[id].purpose = purpose

func scout_departed(route: int, observes_at := INF) -> void:
	scout_route = route
	scout_weather_at = observes_at
	scout_weather.clear()
	scout_sighting.clear()
	var place: String = ROUTE_PLACES[route]
	_depart_person(Roster.SCOUT, place, "Watching the sky" if route == 3 else "Gathering wood")
	_set_activity(Roster.SCOUT, "Out on a gathering path" if route != 3 else "Watching the valley", place, true, "")

func scout_returned(route: int, report: String, fuel_report := false, scarce := false) -> void:
	var place: String = ROUTE_PLACES[route]
	_set_activity(Roster.SCOUT, "Back from " + place.to_lower(), HOME)
	_publish(Roster.SCOUT, report, -1.0, place, "" if fuel_report else "news")
	if fuel_report:
		land.remember(place, "fuel", report, "Rusk", fire.time, fire.time, "caution" if scarce else "wood")
	if not scout_weather.is_empty():
		land.remember(place, "weather", scout_weather.text, "Rusk", scout_weather.at, fire.time, scout_weather.mark)
	if route == 1 and _take_site_material(PINE, "knots", "knot", 85, Workshop.MAKER):
		_publish(Roster.SCOUT, "I brought a sticky knot for Ina." if sites[PINE].knots == 0 else
			"I brought a sticky knot for Ina. There’s more pitch in the dead pine.", -1.0, PINE, "resin", "wood")
	elif route == 3:
		_publish(Roster.SCOUT, "From the shelf I could see rain coming across the valley." if weather.rain >= 0.12 else
			"The valley was clear from the shelf. I could see as far as the deer trail.")
		if not scout_sighting.is_empty():
			_share_sighting()
	scout_route = -1
	scout_sighting.clear()
	for entry in waiting_news:
		_publish(Roster.SCOUT, "They told me when I got back. " + entry.text, entry.happened, entry.place, entry.topic, entry.mark)
	waiting_news.clear()

func _share_sighting() -> void:
	var seen_at: float = scout_sighting.at
	var names := PackedStringArray()
	for id: String in scout_sighting.party:
		if known[id].seen >= seen_at:
			continue
		var prior: Dictionary = known[id]
		known[id] = {"activity": "Seen turning toward the shelter", "place": TRAIL,
			"learned": fire.time, "seen": seen_at, "source": "Reported by Rusk", "injury": prior.injury, "fatigue": prior.fatigue, "away": true}
		knowledge_revision += 1
		names.append(Roster.person_name(id))
	if not names.is_empty():
		_publish(Roster.SCOUT, "I saw %s turn for home from the deer trail." % " and ".join(names), seen_at, TRAIL, "sighting", "kin")

func _take_site_material(place: String, key: String, kind: String, grams: int, rest: String) -> bool:
	var site: Dictionary = sites[place]
	if site[key] <= 0:
		return false
	site[key] -= 1
	workshop.add(kind, grams, rest).origin = place
	return true

func _report_tracks(by: String, kind: String, place: String) -> void:
	var count: int = sites[place][kind]
	signs[kind] = {"place": place, "strength": minf(0.90, count * 0.28), "seen": fire.time}
	var quarry := "deer" if kind == "large" else "hare"
	_publish(by, "I found fresh %s tracks near %s." % [quarry, place.to_lower()] if count > 0 else
		"The old %s tracks near %s have gone quiet." % [quarry, place.to_lower()], -1.0, place, "sign", "tracks")

func _known_sign(kind: String) -> float:
	var sign: Dictionary = signs[kind]
	return sign.strength * lerpf(1.0, 0.30, clampf((fire.time - float(sign.seen)) / 390.0, 0.0, 1.0))

func remember_workplace(place: String, source := "Seen in the cave") -> void:
	var description := workshop.workplace_words(place)
	var known_work: Dictionary = land.places.get(place, {}).get("work", {})
	if known_work.get("text", "") != description or known_work.get("source", "") != source:
		land.remember(place, "work", description, source, fire.time, fire.time)

func instructor(place: String) -> String:
	if place != Workshop.HUNTER:
		var teacher: String = Workshop.Lessons.TEACHERS.get(place, "")
		return teacher if not teacher.is_empty() and not people[teacher].away else ""
	if not people.bera.away and transfer.get("person", "") != "bera":
		return "bera"
	return "mira" if not people.mira.away else ""

func _usable_hunters(minimum_condition := 0.30) -> Array[String]:
	var ready: Array[String] = []
	for id: String in HUNTERS:
		var person: Dictionary = people[id]
		if not person.away and person.injury < 0.36 and person.fatigue < 0.69 and workshop.gear[id].condition >= minimum_condition and workshop.gear[id].at == Workshop.HUNTER and transfer.get("person", "") != id:
			ready.append(id)
	ready.sort_custom(func(a: String, b: String) -> bool: return _readiness(a) > _readiness(b))
	return ready

func _readiness(id: String) -> float:
	var person: Dictionary = people[id]
	return workshop.gear[id].condition - person.injury - person.fatigue * 0.45

func conditions() -> Dictionary:
	var fuel := 0.0
	for piece in fire.stored:
		if piece.water <= piece.original * 0.36 and piece.temperature < 160.0:
			fuel += piece.wood
	var hot_coals := 0.0
	for coal in fire.coals:
		if coal.living_coal():
			hot_coals += coal.char_mass
	var warmth := clampf(fire.heat_at(Workshop.COOK_AT) * 2.5 + (weather.temperature - 5.0) * 0.045
		- weather.rain_at(Vector2.ZERO) * 0.38 - minf(0.20, weather.smoke * 180.0), 0.0, 1.0)
	var ready := _usable_hunters()
	var gear := 0.0
	var fatigue := 0.0
	var hurt := 0.0
	for id: String in HUNTERS:
		gear += workshop.gear[id].condition
		fatigue += people[id].fatigue
		hurt += people[id].injury
	return {"food": workshop.food_on_shelf(), "hunger": hunger, "warmth": warmth, "fuel": fuel,
		"living": clampf(hot_coals * 16.0 + fire.total_flame() * 0.10, 0.0, 1.0),
		"gear": gear / HUNTERS.size(), "fatigue": fatigue / HUNTERS.size(), "hurt": hurt / HUNTERS.size(),
		"rain": weather.rain, "light": weather.light, "wind": weather.wind.length(),
		"small": _known_sign("small"), "large": _known_sign("large"),
		"injury": recent_injury, "success": recent_success, "ready": ready.size(),
		"deer_ready": _usable_hunters(0.49).size()}

static func deliberate(state: Dictionary) -> Dictionary:
	var want: float = clampf(1.0 - float(state.food) / (MEAL * 2.0), 0.0, 1.0) * 0.75 + state.hunger * 0.74
	var risk: float = state.rain * 0.87 + state.wind * 0.42 + state.hurt * 0.60 + state.fatigue * 0.55 + state.injury * 0.54
	var support: float = state.gear * 0.46 + state.warmth * 0.26 + minf(state.fuel, 1.0) * 0.21 + state.living * 0.18
	var votes: Dictionary = {}
	var totals := [0.0, 0.0, 0.0]
	for id: String in Roster.ELDERS:
		var tendency: Array = TENDENCIES[id]
		var hold: float = tendency[0] + (1.0 - minf(want, 1.0)) * 0.48 + risk * 0.40 + state.success * 0.19
		var small: float = want * tendency[1] + state.small * 0.56 + support * 0.52 - risk * 0.66
		var large: float = want * tendency[2] + state.large * 1.05 + support * 0.76 - risk * 1.25 - 0.38
		if state.ready < 1 or state.light < 0.32 or state.small < 0.12:
			small = -2.0
		if mini(state.ready, state.deer_ready) < 2 or state.light < 0.57 or state.rain > 0.48 or state.large < 0.16:
			large = -2.0
		var scores := [hold, small, large]
		votes[id] = scores.find(scores.max())
		for i in range(scores.size()):
			totals[i] += scores[i]
	var choice := totals.find(totals.max())
	var reason := "The paths are quiet, and we can wait for clearer sign."
	if choice == 2:
		reason = "There are fresh deer tracks, and two hunters can carry sound points."
	elif choice == 1:
		reason = "A short walk in the woods may bring enough to share."
	elif state.ready == 0 or state.injury > 0.36 or state.fatigue > 0.44:
		reason = "The hunters and their hafts need time here first."
	elif state.light < 0.32 or state.rain > 0.36 or state.wind > 0.46:
		reason = "We’ll wait until we can see our feet and the ground will hold them."
	elif state.food >= MEAL:
		reason = "We have food under cover. Keep the hunters’ strength for another day."
	elif state.living < 0.25 or state.fuel < 0.20:
		reason = "There is little warmth to come back to. Stay near and save strength."
	return {"choice": choice, "votes": votes, "reason": reason}

func _council() -> void:
	var state := conditions()
	if stormfall.council(self, state):
		decision = {"choice": 0, "reason": "Recover the stormfall bison", "votes": {}, "at": fire.time}
		return
	var result := deliberate(state)
	result.at = fire.time
	if decision.is_empty() or decision.choice != result.choice or decision.reason != result.reason:
		var disagreement := ""
		for id: String in Roster.ELDERS:
			if result.votes[id] != result.choice:
				disagreement = " %s would have said, ‘%s.’" % [Roster.person_name(id), HUNT_WORDS[result.votes[id]].to_lower()]
				break
		_tell_scout("The elders say, ‘%s.’ %s%s" % [HUNT_WORDS[result.choice], result.reason, disagreement])
	decision = result
	if result.choice != 0:
		_depart_hunt(result.choice)

func _depart_hunt(choice: int) -> void:
	var ready := _usable_hunters(0.49 if choice == 2 else 0.30)
	var kind := "large" if choice == 2 else "small"
	var place: String = signs[kind].place
	var party := ready.slice(0, choice)
	var travel := (42.0 if choice == 1 else 67.0) * (1.0 + weather.rain * 0.55)
	hunt = {"party": party, "kind": kind, "place": place, "encounter": fire.time + travel * 0.62,
		"home": fire.time + travel, "result": "", "yield": 0, "injured": [], "knot": false}
	var names := PackedStringArray()
	for id: String in party:
		names.append(Roster.person_name(id))
		_depart_person(id, place, "Hunting deer" if kind == "large" else "Hunting hare")
		workshop.gear[id].at = place
	workshop.revision += 1
	_tell_scout("%s took the path to %s. I’ll watch for them at the mouth." % [" and ".join(names), place.to_lower()], place, "hunt", "tracks")

func _resolve_hunt() -> void:
	var place: String = hunt.place
	var kind: String = hunt.kind
	var site: Dictionary = sites[place]
	var large := kind == "large"
	var risk := float(site.hazard) + weather.rain * 0.44 + weather.wind.length() * 0.20 + (1.0 - weather.light) * 0.24
	var skill := 0.0
	for id: String in hunt.party:
		skill += (0.79 if id == "kett" and large or id == "ivo" and not large else 0.62) * _readiness(id)
	skill /= hunt.party.size()
	var encounter := int(site[kind]) > 0 and rng.randf() < clampf(0.44 + site[kind] * 0.13 - risk * 0.27, 0.0, 0.97)
	hunt.result = "No game crossed their path."
	if encounter:
		var successful := rng.randf() < clampf(0.48 + skill * 0.78 - risk * 0.50 - (0.10 if large else 0.0), 0.08, 0.95)
		if successful:
			site[kind] -= 1
			hunt.yield = rng.randi_range(2400, 3200) if large else rng.randi_range(660, 1080)
			hunt.result = "They brought home cuts of deer." if large else "They brought home a hare."
		else:
			hunt.result = "They found tracks and raised game, but came home empty-handed."
	for id: String in hunt.party:
		var state: Dictionary = people[id]
		state.fatigue = minf(1.0, float(state.fatigue) + 0.20 + risk * 0.30 + (0.10 if large else 0.0))
		var tool: Dictionary = workshop.gear[id]
		tool.condition = maxf(0.0, float(tool.condition) - (0.16 if encounter else 0.04) - risk * 0.08)
		if rng.randf() < risk * (0.29 if large else 0.14) + (1.0 - float(tool.condition)) * 0.08:
			state.injury = minf(1.0, float(state.injury) + rng.randf_range(0.27, 0.53))
			hunt.injured.append(id)
		_set_activity(id, "Heading home from " + place.to_lower(), place, true, "")
	if scout_route == 3 and place == TRAIL and weather.light > 0.49 and weather.rain < 0.25:
		scout_sighting = {"party": hunt.party.duplicate(), "at": fire.time}
	hunt.knot = not large and rng.randf() < 0.34

func _return_hunt() -> void:
	var words: String = hunt.result
	var loose := PackedStringArray()
	for id: String in hunt.party:
		var injury: float = people[id].injury
		_set_activity(id, "Resting after a hunt" if injury < 0.26 else "Having an injury dressed", HOME)
		craft.rests_until[id] = fire.time + 12.0
		workshop.gear[id].at = Workshop.HUNTER
		if workshop.gear[id].condition < 0.58:
			loose.append(Roster.person_name(id))
	if not loose.is_empty():
		words += " Ina wants to check the hafts brought back by %s." % " and ".join(loose)
	if hunt.yield > 0:
		workshop.receive_game(hunt.yield, hunt.place)
		remember_workplace(Workshop.HUNTER, Roster.person_name(hunt.party[0]))
		recent_success = minf(1.0, recent_success + 0.55)
	if hunt.knot and _take_site_material(PINE, "knots", "knot", 85, Workshop.MAKER):
		words += " On the way in they picked up a resinous knot for Ina."
	var reporter: String = hunt.party[0]
	_report_tracks(reporter, hunt.kind, hunt.place)
	_tell_scout(words, hunt.place, "hunt", "tracks")
	if not hunt.injured.is_empty():
		var injured := PackedStringArray()
		for id: String in hunt.injured:
			injured.append(Roster.person_name(id))
		recent_injury = minf(1.0, recent_injury + 0.67)
		var names := " and ".join(injured)
		_set_activity("dena", "Tending " + names, HOME)
		_publish("dena", "Make room by the warm stone. %s came back hurt." % names, -1.0, HOME, "concern", "caution")
	workshop.revision += 1
	hunt.clear()

func _start_errand() -> void:
	var job := next_errand_index % 3
	next_errand_index += 1
	var id: String = ["tavi", "mira", "oren"][job]
	var place: String = [STREAM, PINE, MEADOW if signs.large.place == TRAIL else TRAIL][job]
	if weather.rain > 0.46 or weather.light < 0.31 or people[id].injury > 0.3 or people[id].away:
		return
	if (job == 0 and sites[place].roots <= 0) or (job == 1 and sites[place].knots <= 0):
		return
	errand = {"job": job, "person": id, "place": place, "home": fire.time + [26.0, 31.0, 37.0][job]}
	_depart_person(id, place, ["Gathering roots", "Gathering resin", "Looking for tracks"][job])

func _end_errand() -> void:
	var id: String = errand.person
	var place: String = errand.place
	match int(errand.job):
		0:
			if _take_site_material(place, "roots", "roots", 230, Workshop.STORE):
				_tell_scout("Tavi washed roots at the stream. She laid them on the covered shelf.", STREAM, "finding", "food")
				_publish("tavi", "I’ve taken the last roots I could reach." if sites[STREAM].roots == 0 else
					"There are still roots by the stream.", -1.0, STREAM, "roots", "food")
		1:
			if _take_site_material(place, "knots", "knot", 85, Workshop.MAKER):
				_tell_scout("Mira found another sticky knot in the lee. She left it on Ina’s stone.", PINE, "finding", "wood")
				_publish("mira", "I found no more sticky knots after that one." if sites[PINE].knots == 0 else
					"I left a few sticky knots in the lee.", -1.0, PINE, "resin", "wood")
		2:
			_report_tracks(id, "large", place)
	_set_activity(id, "Back from " + place.to_lower(), HOME)
	errand.clear()

func _household_work() -> void:
	if not people.tavi.away:
		_set_activity("tavi", "Showing Lio how to sort roots" if weather.light > 0.40 else "Settling the children", HOME)
	if people.dena.activity.begins_with("Tending ") and recent_injury < 0.34:
		_set_activity("dena", "Checking Eren’s leg", HOME)

func _carry_cut(cutter: String, id: int) -> void:
	if not transfer.is_empty() or workshop.stock("meat", Workshop.COOK).size() >= 4:
		return
	var cut: Workshop.Parcel = workshop.parcels.get(id)
	if cut == null or cut.kind != "meat":
		return
	transfer = {"id": cut.id, "person": cutter, "from": cut.at,
		"via": Vector2(-1.20, -0.99), "to": workshop.find_rest(Workshop.COOK, "meat"),
		"began": fire.time, "arrives": fire.time + 5.0}
	workshop._relocate(cut, Workshop.IN_TRANSIT, cut.at)
	_set_activity(cutter, "Carrying a cut to Nara", Workshop.HUNTER)

func _advance_transfer() -> void:
	if transfer.is_empty():
		return
	var parcel: Workshop.Parcel = workshop.parcels[transfer.id]
	if fire.time >= transfer.arrives:
		workshop._relocate(parcel, Workshop.COOK, transfer.to)
		_set_activity(transfer.person, "Leaving a cut with Nara", Workshop.COOK)
		remember_workplace(Workshop.COOK, "Nara")
		transfer.clear()
		return
	var phase := inverse_lerp(float(transfer.began), float(transfer.arrives), fire.time)
	if phase <= 0.62:
		parcel.at = transfer.from.lerp(transfer.via, phase / 0.62)
	else:
		parcel.at = transfer.via.lerp(transfer.to, (phase - 0.62) / 0.38)

func step() -> void:
	_advance_transfer()
	var dt := Fire.STEP
	if workshop.step(dt):
		if workshop.resin != null and workshop.resin_position >= 0 and workshop.resin.scorched >= 1.0 and workshop.resin.temperature > 165.0:
			_publish("ina", "The pitch is smoking. Take the cup off the red and let the draft clear it.", -1.0, Workshop.MAKER, "concern", "caution")
		else:
			_publish("nara", "The spit is smoking. Draw it back onto the resting stone.", -1.0, Workshop.COOK, "concern", "caution")
	_release_workshop_smoke(dt)
	craft.step(self, dt)
	if fire.time - sampled_at < 1.0:
		return
	var elapsed := fire.time - sampled_at
	sampled_at = fire.time
	if fire.time >= next_weather_memory:
		_observe_shelter_weather()
	if scout_route >= 0 and fire.time >= scout_weather_at and scout_weather.is_empty():
		scout_weather = {"at": fire.time, "text": Land.weather_words(weather.rain, weather.wind.length()),
			"mark": Land.weather_mark(weather.rain, weather.wind.length())}
	_update_health(elapsed)
	stormfall.step(self)
	if fire.time >= next_spoil:
		workshop.age_food(6.0)
		next_spoil = fire.time + 6.0
	_observe_fire(elapsed)
	if not hunt.is_empty():
		if fire.time >= hunt.encounter and hunt.result.is_empty():
			_resolve_hunt()
		if fire.time >= hunt.home:
			_return_hunt()
	if not errand.is_empty() and fire.time >= errand.home:
		_end_errand()
	if fire.time >= next_meal:
		next_meal += 145.0
		var served := workshop.eat(MEAL)
		hunger = clampf(hunger + (0.40 if served < MEAL * 0.6 else -0.27), 0.0, 1.0)
		if served < MEAL * 0.6:
			_publish("sela", "The shelf will barely feed the little ones. We’ll share what there is.", -1.0, Workshop.STORE, "meal", "caution")
		else:
			_publish("nara", "There’s food to pass around. Come sit a while when your hands are free.", -1.0, Workshop.STORE, "meal", "food")
	if fire.time >= next_council and hunt.is_empty() and stormfall.party.is_empty():
		next_council = fire.time + 85.0
		_council()
	if fire.time >= next_errand and errand.is_empty():
		next_errand = fire.time + 87.0
		_start_errand()
	if fire.time >= next_work:
		next_work = fire.time + 28.0
		_household_work()
		var supply := float(conditions().fuel)
		if supply < 0.20 and not low_fuel:
			_tell_scout("There’s little dry wood left under cover, cousin. The smaller sticks will have to last.")
		low_fuel = supply < 0.20

func _observe_shelter_weather() -> void:
	next_weather_memory = fire.time + 25.0
	land.remember(HOME, "weather", weather.weather_words() + " · " + weather.local_words(), "Seen at Red Hollow",
		fire.time, fire.time, Land.weather_mark(weather.rain, weather.wind.length()))

func _release_workshop_smoke(dt: float) -> void:
	if workshop.roast != null and workshop.roast.smoked and workshop.roast.temperature > 175.0:
		var at: Vector2 = Workshop.ROAST_POSITIONS[workshop.roast_position]
		fire.smoke_field.release(Vector3(at.x, 0.21, at.y), 0.00008 * dt, 0.54)
	if workshop.resin != null and workshop.resin_position >= 0 and workshop.resin.smoked and workshop.resin.temperature > 165.0:
		var at: Vector2 = Workshop.RESIN_POSITIONS[workshop.resin_position]
		fire.smoke_field.release(Vector3(at.x, 0.14, at.y), 0.00030 * dt, 0.46)

func _update_health(elapsed: float) -> void:
	var care := clampf(fire.heat_at(Workshop.COOK_AT) * 1.8 + (1.0 - hunger) * 0.61, 0.12, 1.0)
	for id: String in HUNTERS + ["nara", "ina", "mira"]:
		var state: Dictionary = people[id]
		if not state.away:
			if not craft.jobs.values().any(func(job): return job.worker == id):
				state.fatigue = maxf(0.0, float(state.fatigue) - elapsed * 0.006 * care)
			state.injury = maxf(0.0, float(state.injury) - elapsed * 0.0018 * care)
	recent_injury = maxf(0.0, recent_injury - elapsed * 0.003)
	recent_success = maxf(0.0, recent_success - elapsed * 0.002)

func _observe_fire(elapsed: float) -> void:
	var living := 0.0
	var covered := 0.0
	for coal in fire.coals:
		if coal.living_coal():
			living += coal.char_mass
			if coal.cover > 0.002:
				covered += coal.char_mass
	var flame := fire.total_flame()
	if thin_flame >= 6.0 and flame > 1.0 and fire.wood.any(func(piece): return piece.original < 0.035 and piece.flame > 0.25):
		workshop.observe_fire("Quick Hand", "Wake flame from weak red", "Set dry, fine fuel along the red with a gap for air. Start with one soft breath and watch which edge brightens.")
	thin_flame = thin_flame + elapsed if living > 0.0 and flame < 0.28 else (0.0 if living == 0.0 or flame > 1.0 else thin_flame)
	bank_time = bank_time + elapsed if covered >= 0.008 and flame < 1.0 else 0.0
	if bank_time >= 45.0:
		remember_banking()

func remember_banking() -> void:
	workshop.observe_fire("Deep Red", "Keep a living bed under ash",
		"Sift loose ash over part of the bed, then check beneath it for a red core before laying fresh fuel.")

