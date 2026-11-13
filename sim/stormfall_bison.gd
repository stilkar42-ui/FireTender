extends RefCounted
## The site holds only the part of the fallen animal the party could reach.

const LANDED := 16800
const DAMAGED := 4800
const PACK := 1650
const SCOUT_DELAY := 20.0
const LOOKOUT_TIME := 32.0
var at := 0.0
var seen_at := -1.0
var scout_due := 0.0
var scout_home := 0.0
var left := LANDED
var damaged := DAMAGED
var lost := 0
var recovered := 0
var quality := 1.0
var loads: Array[Dictionary] = []
var party: Array[String] = []
var gathering_at := 0.0
var home_at := 0.0
var next_decay := 0.0
var last_decision := ""
var scout_out := false

func begin(now: float) -> void:
	at = now
	scout_due = now + SCOUT_DELAY
	next_decay = now + 6.0

func step(family) -> void:
	var now: float = family.fire.time
	if seen_at < 0.0:
		if not scout_out and now >= scout_due and not family.people.oren.away and family.errand.get("person", "") != "oren":
			scout_out = true
			scout_home = now + LOOKOUT_TIME
			family._depart_person("oren", family.SHELF, "Checking the ledge after the rain")
		elif scout_out and now >= scout_home:
			seen_at = now
			family._set_activity("oren", "Back from the ledge", family.HOME)
			family._tell_scout("Oren saw a bison below the broken ledge by the grazing ground. The Sky Father’s tears loosened the stone. The elders will speak before anyone goes down.",
				family.MEADOW, "stormfall", "caution")
			family._publish("fire_speaker", "A gift can feed us if we put our hands to it. Bring back what can be carried, and keep it sound with the warmth we have.")
	if now >= next_decay:
		decay(now, family.weather.temperature, family.weather.rain)
	if party.is_empty():
		return
	if gathering_at > 0.0 and now >= gathering_at:
		gathering_at = 0.0
		for id: String in party:
			var take := mini(left, PACK)
			if take > 0:
				left -= take
				loads.append({"grams": take, "quality": quality, "carrier": id})
	if now >= home_at:
		_arrive(family)

func decay(now: float, temperature: float, rain: float) -> void:
	var elapsed := maxf(6.0, now - next_decay + 6.0)
	next_decay = now + 6.0
	var days := elapsed / 360.0
	quality = maxf(0.0, quality - days * (0.24 + maxf(0.0, temperature - 5.0) * 0.023 + rain * 0.18))
	if now - at >= 174.0:
		var scavenged := mini(left, roundi(elapsed * lerpf(9.0, 27.0, 1.0 - quality)))
		left -= scavenged
		lost += scavenged
	if quality <= 0.0:
		lost += left
		left = 0

func council(family, state: Dictionary) -> bool:
	if seen_at < 0.0 or not party.is_empty():
		return false
	# The discovery reaches council only after Rusk or a direct field witness tells the kin.
	if not family.land.places.get(family.MEADOW, {}).has("stormfall"):
		return false
	if left <= 0 or quality <= 0.16:
		return false
	var candidates: Array[String] = []
	for id in ["kett", "ivo", "mira", "bera"]:
		var person: Dictionary = family.people[id]
		if not person.away and person.injury < 0.31 and person.fatigue < 0.65 and family.transfer.get("person", "") != id:
			candidates.append(id)
	var accessible: bool = state.rain < 0.49 and state.wind < 0.56 and state.light > 0.44 and candidates.size() >= 2
	var household_backlog: int = family.workshop.stock("carcass", family.Workshop.HUNTER).size()
	var worth_it: bool = household_backlog < 4 and (state.food < 940 or quality >= 0.52 and state.ready >= 2)
	var decision := "wait"
	if accessible and worth_it:
		decision = "carry"
	if decision != last_decision:
		last_decision = decision
		if decision == "carry":
			family._tell_scout("The elders are sending a pair down to the bison. Leave the crushed side for the birds. Bring back only what you can lift.",
				family.MEADOW, "stormfall", "tracks")
		else:
			family._tell_scout("The elders are leaving the ledge alone for now. We have to weigh the wet path and the work already under our roof.",
				family.MEADOW, "stormfall", "caution")
	if decision != "carry":
		return false
	party.assign(candidates.slice(0, 2))
	var now: float = family.fire.time
	gathering_at = now + 32.0 + state.rain * 12.0
	home_at = gathering_at + 29.0
	for id: String in party:
		family._depart_person(id, family.MEADOW, "Recovering a share of the fallen bison")
	return true

func _arrive(family) -> void:
	for id: String in party:
		family.people[id].fatigue = minf(1.0, float(family.people[id].fatigue) + 0.24)
		family._set_activity(id, "Resting after the carry from the ledge", family.HOME)
	for load: Dictionary in loads:
		var cut = family.workshop.add("carcass", load.grams, family.Workshop.HUNTER)
		cut.origin = "Stormfall bison"
		cut.species = "bison"
		cut.freshness = maxf(0.0, load.quality - 0.05)
		recovered += load.grams
	var words := "They carried back pieces of the bison. Bera can see what the fall left us."
	if loads.is_empty():
		words = "They found little fit to carry. Scavengers had reached the ledge."
	elif lost > 0:
		words += " Birds and scavengers had already taken some of the exposed meat."
	family._tell_scout(words, family.MEADOW, "stormfall", "tracks")
	family.remember_workplace(family.Workshop.HUNTER, "Recovery party")
	party.clear()
	loads.clear()
