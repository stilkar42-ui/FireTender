extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Mentor := preload("res://sim/mentor.gd")
const Shelter := Chapter.Shelter

var passed := 0
var failed := 0

func _initialize() -> void:
	_supplies()
	_banking()
	_reading_the_sky()
	print("Weather and preparedness: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _supplies() -> void:
	var story := Chapter.new(Fire.new())
	var elder := Mentor.new()
	elder.begin_chapter(story)
	var fire := story.fire
	_check("dry fibres enough" in _ask(elder, fire, "Is there enough tinder to wake the red?") and
		"enough dry twigs" in _ask(elder, fire, "Are we low on kindling?"), "The opening stock can wake and rebuild flame")
	_check("too few dry branches" in _ask(elder, fire, "Have we got enough branches to keep the flame?") and
		"short of sound larger wood" in _ask(elder, fire, "Do we have enough logs?"), "Branches and heavy wood are judged separately")
	for i in range(3):
		fire.receive_fuel(13, Vector2(-1.9, -1.1), 0.0, i, 0.62)
	_check("too few dry branches" in story.preparedness("medium"), "Soaked wood contributes little to usable reserves")
	for i in range(3):
		fire.receive_fuel(8, Vector2(-1.9, -1.1), 0.0, i)
		fire.receive_fuel(2, Vector2(-2.0, -1.1), 0.0, i)
	_check("enough sound branches" in story.preparedness("medium") and "should carry" in story.preparedness("large"),
		"Dry deliveries change the judgment in clear weather")
	_time(story, 930.0)
	_check("short rain" in _ask(elder, fire, "Will our splits last through the storm?"),
		"The same dry splits can suffice for a short rain and fall short of a sustained storm")
	for i in range(3):
		fire.receive_fuel(10, Vector2(-2.1, -1.1), 0.0, i)
	_check("should carry" in story.preparedness("large"), "Enough sheltered large fuel improves the storm assessment")
	for piece in fire.stored:
		if piece.kind in [2, 10]:
			piece.at.y = 1.22
	_check("should carry" not in story.preparedness("large"), "Moving a reserve into the rain lowers its value even before soaking")
	for piece in fire.stored:
		if piece.kind in [2, 10]:
			piece.at.y = -1.1
			if piece.kind == 10:
				piece.water = piece.wood * 0.73
	_check("short rain" in story.preparedness("large"), "Adding wet heavy wood does not solve a dry reserve shortage")
	_time(story, 1078.0)
	_check("should carry" in story.preparedness("large"), "A shorter remaining front needs less reserve than a long storm")
	_check(story.consultations.is_empty(), "Preparedness questions never spend the elder’s gathering recommendations")

func _banking() -> void:
	var story := Chapter.new(Fire.new())
	var elder := Mentor.new()
	elder.begin_chapter(story)
	var fire := story.fire
	_check("too little loose ash" in _ask(elder, fire, "Have we enough ash to bank the coals?") and
		"too little living red" in _ask(elder, fire, "Are these coals strong enough for a rest?"),
		"The first ember and scant ash are insufficient for banking")
	fire._pile_ash(Vector2(0.3, 0.1), 0.012)
	_check("enough loose ash" in story.preparedness("ash"), "Loose ash is measured against the actual living patches")
	var coal := fire.coals[0]
	coal.char_mass = 0.13
	coal.temperature = 645.0
	_time(story, 930.0)
	_check("deep red enough" in story.preparedness("coals") and
		"The coal bed is strong." in _ask(elder, fire, "Are we ready for this downpour?"), "A deep hot bed can coexist with a wood shortage")
	coal.cover = 0.012
	_check("already enough ash" in story.preparedness("ash"), "Existing cover counts toward the required ash")
	coal.temperature = 160.0
	_check("too little living red" in story.preparedness("coals") and "Ash alone" in story.preparedness("ash"),
		"Cold charcoal and stored ash cannot substitute for living red")

func _reading_the_sky() -> void:
	var story := Chapter.new(Fire.new())
	var elder := Mentor.new()
	elder.begin_chapter(story)
	var fire := story.fire
	var sky := story.weather
	_time(story, 100.0)
	var day := sky.sky_light()
	_time(story, 270.0)
	_check(sky.twilight() > 0.8 and sky.sky_light() < day, "Dusk warms the horizon while daylight fades")
	var phase := sky.moon_angle()
	_time(story, 342.0)
	_check(sky.sky_light() < 0.1 and sky.cloud < 0.2 and sky.moon_angle() < phase,
		"The clear night leaves room for stars and an evolving moon phase")
	_time(story, 620.0)
	_check(sky.watch() == Shelter.Watch.BUILDING and "clouds thickening" in _ask(elder, fire, "What does that sky tell you?"),
		"The first cloud warning agrees with the visible cloud buildup")
	_check("clouds thickening" in story.weather_lesson() and story.weather_lesson().is_empty(),
		"An unsolicited sky lesson plays once for a given weather cue")
	_time(story, 678.0)
	_check(sky.watch() == Shelter.Watch.RAIN_LINE and sky.rain < 0.06 and sky.rain_band() > 0.2 and
		"grey curtain" in _ask(elder, fire, "What does that sky tell you?"), "The distant rain line is visible before rain reaches the shelter")
	_time(story, 930.0)
	_check(sky.watch() == Shelter.Watch.STORM and sky.rain_band() > 0.60 and
		"dark sky and broad rain" in _ask(elder, fire, "What does that sky tell you?"), "A broad dark front matches sustained heavy rain")
	_check(sky.inward_draft() and "under the lip" in sky.local_words() and "smoke lean back" in
		_ask(elder, fire, "Has the wind turned?"), "The wind lesson follows the local inward draft")
	sky.smoke = 0.02
	_check("Smoke lingers" in sky.local_words(), "The storm readout keeps the local smoke warning visible")
	_time(story, 1060.0)
	_check(sky.watch() == Shelter.Watch.EASING and sky.wet_watch() < 0.4 and "passing" in
		_ask(elder, fire, "What does that sky tell you?"), "Easing rain lowers the burden without promising a clear sky")

func _time(story: Chapter, time: float) -> void:
	story.fire.time = time
	story.weather.sample(time)

func _ask(elder: Mentor, fire: Fire, words: String) -> String:
	elder.ask(fire, words, Vector3.ZERO, null, 0.0)
	return elder.text

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
