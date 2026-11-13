extends SceneTree

const Chapter := preload("res://sim/red_hollow.gd")
const Family := Chapter.Family
const Land := Family.Land
const Roster := Family.Roster
const Work := Family.Workshop

var passed := 0
var failed := 0

func _initialize() -> void:
	var chapter := Chapter.new(Chapter.Fire.new())
	chapter.set_up_family_trial()
	var family := chapter.family
	var map := family.land
	_check(map.places[Land.HOME].weather.source == "Seen at Red Hollow" and not map.places.has(Land.PINE),
		"Visible shelter weather and reported sign are distinct from unknown field conditions")
	_check(Land.TERRITORY.size() == family.sites.size() and Land.TERRITORY.keys().all(func(place): return family.sites.has(place)),
		"Every existing simulated place is represented")
	var start := chapter.fire.time
	_check(chapter.request(1), "The existing gathering route is available")
	var known: Dictionary = family.known[Roster.SCOUT]
	_check(known.place == Land.HOME and known.destination == Land.PINE and known.away,
		"Departure records a witnessed place and an intended destination")
	_step_until(chapter, start + 20)
	_check(family.people[Roster.SCOUT].place == Land.PINE and not family.scout_weather.is_empty() and not map.places.has(Land.PINE),
		"An observation in the field remains private while Rusk is away")
	_step_until(chapter, chapter.returns_at + 1.0)
	var report: Dictionary = map.places[Land.PINE]
	_check(report.fuel.source == "Rusk" and report.weather.source == "Rusk" and report.weather.seen < report.weather.learned,
		"Returning wood and weather reports reach the map with source and both dates")
	_check(family.known[Roster.SCOUT].place == Land.HOME and not family.known[Roster.SCOUT].has("destination"),
		"A witnessed return clears the travel trace")
	var remembered: Dictionary = report.duplicate(true)
	family.sites[Land.PINE].knots = 0
	chapter.gathering.take(1, chapter.gathering.plan(1, 0, true), chapter.fire.time, 0.0, 10.0)
	_check(map.places[Land.PINE] == remembered, "Unseen depletion leaves the prior report intact")
	_check(not Land.stale(report.weather.seen, chapter.fire.time) and
		Land.stale(report.weather.seen, report.weather.seen + Land.FADING_AFTER),
		"Freshness uses the time of the observation")
	map.remember(Land.PINE, "weather", "An older report", "Rusk", report.weather.seen - 2, chapter.fire.time + 10)
	_check(report.weather == remembered.weather, "An older report arriving late cannot erase a newer observation")

	var lookout := Chapter.new(Chapter.Fire.new())
	lookout.set_up_family_trial()
	var kin := lookout.family
	kin._depart_hunt(2)
	var party: Array = kin.hunt.party.duplicate()
	var hunter: String = party[0]
	var departed: Dictionary = kin.known[hunter].duplicate(true)
	var encounter: float = kin.hunt.encounter
	var back: float = kin.hunt.home
	_step_until(lookout, lookout.fire.time + 28.0)
	lookout.request(3)
	_step_until(lookout, encounter + 1.5)
	_check(kin.known[hunter] == departed and not kin.land.places[Land.TRAIL].has("sighting"),
		"Unreported field movement cannot advance the hunter’s map marker")
	_step_until(lookout, lookout.returns_at + 1.0)
	var sighting: Dictionary = kin.land.places[Land.TRAIL].sighting
	_check(kin.known[hunter].place == Land.TRAIL and sighting.source == "Rusk" and sighting.learned > sighting.seen,
		"The lookout’s delayed sighting can move the hunter’s last-known marker")
	_step_until(lookout, back + 1.5)
	_check(kin.known[hunter].place == Land.HOME and not kin.known[hunter].away,
		"The latest sighting places the returned party in the shelter")
	print("Mind Cave knowledge: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _step_until(chapter: Chapter, until: float) -> void:
	while chapter.fire.time < until:
		chapter.step()

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", label)
	else:
		failed += 1
		printerr("FAIL  ", label)
