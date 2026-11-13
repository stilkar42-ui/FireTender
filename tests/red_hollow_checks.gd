extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Mentor := preload("res://sim/mentor.gd")
const Audio := preload("res://hearth/fire_audio.gd")

# An ordinary tending sequence. Every item comes out of the opening bundle
# or a completed trip. The hearth is stepped through every action and wait.
const FUEL_SCHEDULE := {
	3: [0, Vector2(0.09, 0), 0.0], 6: [1, Vector2(-0.11, 0), 0.0],
	13: [7, Vector2(0, 0.12), PI / 2.0], 22: [1, Vector2(0.13, 0), 0.0],
	29: [8, Vector2(0.04, -0.08), PI / 2.0], 43: [8, Vector2(0.12, 0), 0.0],
	62: [8, Vector2(-0.08, 0), 0.0], 84: [8, Vector2(0.03, 0.04), PI / 2.0],
	96: [11, Vector2(-0.03, 0), 0.0], 108: [2, Vector2(0.04, 0.03), PI / 2.0],
	192: [2, Vector2.ZERO, 0.0], 240: [10, Vector2.ZERO, PI / 2.0], 350: [10, Vector2.ZERO, 0.0],
	751: [4, Vector2.ZERO, 0.0], 754: [0, Vector2(0, -0.04), 0.0],
	759: [1, Vector2(0, -0.08), PI / 2.0], 770: [11, Vector2(0.02, -0.09), PI / 2.0],
	810: [2, Vector2(0, -0.16), 0.0], 890: [10, Vector2(0, -0.12), PI / 2.0],
}

var passed := 0
var failed := 0

func _initialize() -> void:
	_opening_and_kin()
	_gathering()
	_exposure()
	var first := _tend_chapter()
	var replay := _tend_chapter()
	_check(first == replay, "The same action schedule yields identical fire, weather, stock and chapter outcome")
	_check(first.outcome == "kept" and first.time == Chapter.Shelter.END and first.coal > 0.10 and first.hot > 338.0,
		"A fire made from the supplied ember lives through all three days and the storm")
	_check(first.milestones.all(func(done): return done) and first.all_placed,
		"The physical nest, flame, larger fuel, charcoal, ash and banking milestones can all be earned")
	_check(first.ash_error < 1.0e-10 and first.banked_heat and first.banked_air,
		"Sweeping, covering and uncovering conserve ash, and a banked bed retains heat with less air")
	_check(first.continuity, "The completed three-day run continues into Chapter II with its actual bed and depleted supplies")
	print("Full run: %.0f s, %.0f g charcoal, hottest %.0f C, ash ledger error %s" % [first.time, first.coal * 1000.0, first.hot, str(first.ash_error)])
	print("Red Hollow chapter: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _opening_and_kin() -> void:
	var story := Chapter.new(Fire.new())
	var fire := story.fire
	var elder := Mentor.new()
	elder.begin_chapter(story)
	_check(Chapter.Kin.PEOPLE_COUNT == 15 and fire.coals.size() == 1 and fire.coals[0].temperature > 650 and fire.wood.is_empty() and fire.ash == 0,
		"The clan count is internal and the chapter opens with one viable ember and no preloaded fire or ash")
	_check(not fire.bank() and fire.sweep_ash(Vector2.ZERO, Vector2.RIGHT) == 0.0 and fire.add_fuel(2, Vector2.ZERO) == null,
		"Story controls cannot conjure ash or unowned fuel")
	_check(story.choose_site(0) and story.choose_site(1) and fire.coals[0].char_mass == 0.0125,
		"Choosing the site preserves the original ember")
	var before := fire.fuel_stock[4]
	fire.add_fuel(4, Vector2.ZERO)
	_check(fire.fuel_stock[4] == before - 1 and not story.choose_site(2), "Successful placement consumes stock and commits the chosen hearth site")
	var questions := {
		"Who are our people?": ["Stone Mountain’s kin", "Red Hollow"],
		"Why are there only fifteen of us?": ["mother", "cousin"],
		"Who are you?": ["mother’s brother"],
		"Who is the Torch Bearer?": ["cousin", "mother’s sister’s son"],
		"Where did you find the fire?": ["storm", "trees"],
		"Can your leg heal?": ["injured leg", "cannot"],
		"What should I do before the storm?": ["dry wood", "ash"],
		"Where should I build the fire?": ["Under the lip", "smoke"],
		"How do I make enough ash?": ["burn down", "powder"],
		"Will the Torch Bearer find dry wood?": ["cousin", "dry places"],
		"What happens if the rain reaches the hearth?": ["Water", "warmth"],
	}
	for question: String in questions:
		elder.ask(fire, question, Vector3.ZERO, null, 0.0)
		_check(questions[question].all(func(words): return words in elder.text) and "fifteen" not in elder.text.to_lower(),
			"Speaker answers with kinship or current conditions: " + question)
	var lost := Chapter.new(Fire.new())
	_advance(lost, 150.0)
	_check(lost.outcome == "lost" and lost.fire.total_flame() == 0.0, "An unattended starter ember can go cold and the chapter can be replayed")

func _gathering() -> void:
	var story := Chapter.new(Fire.new())
	var fire := story.fire
	var stock := fire.fuel_stock.duplicate()
	_check(story.request(1) and not story.request(0) and fire.fuel_stock == stock, "The cousin takes one route and supplies stay on the path until he returns")
	# Keep a large banked test bed solely to isolate the gathering clock.
	fire.coals[0].char_mass = 0.55
	fire.coals[0].cover = 0.025
	_advance(story, 27.0)
	_check(story.away == 1 and fire.fuel_stock == stock, "Elapsed fire time controls the return")
	_advance(story, 28.0)
	_check(story.away < 0 and fire.fuel_stock[8] == 4 and story.trips[1] == 1, "The completed route deposits its finite load into real stock")
	story.request(1)
	_advance(story, 56.0)
	story.request(1)
	_advance(story, 84.0)
	_check(story.trips[1] == 3 and not story.request(1) and story.route_status(1) == "Picked clean", "The lee route runs out after its third load")
	story.weather.sample(Chapter.Shelter.DAY * 2.6)
	_check(not story.request(2) and "Unsafe" in story.route_status(2), "Rain closes exposed routes while the story is running")

func _exposure() -> void:
	var inner := Chapter.new(Fire.new())
	var outer := Chapter.new(Fire.new())
	inner.choose_site(0)
	outer.choose_site(2)
	var storm_time := 930.0
	for story in [inner, outer]:
		story.fire.time = storm_time
		story.weather.sample(storm_time)
		story.fire.coals[0].temperature = story.fire.ambient()
	_check(outer.fire.rain_at(Vector2.ZERO) > inner.fire.rain_at(Vector2.ZERO) + 0.30 and
		outer.fire.weather_wind(Vector2.ZERO).length() > inner.fire.weather_wind(Vector2.ZERO).length(), "Cave depth changes rain and draft at the same time in the same storm")
	_check(outer.weather.ventilation(Vector2.ZERO) > inner.weather.ventilation(Vector2.ZERO), "The mouth gives smoke a shorter escape path")
	var inward := outer.weather.ventilation(Vector2.ZERO)
	var saved_wind := outer.weather.wind
	outer.weather.wind.y = absf(saved_wind.y) + 0.25
	var outward := outer.weather.ventilation(Vector2.ZERO)
	outer.weather.wind.y *= -1.0
	_check(outward > outer.weather.ventilation(Vector2.ZERO) and inward > 0.0, "An inward wind reduces smoke clearance even at the mouth")
	outer.weather.wind = saved_wind
	var inner_piece := inner.fire.add_fuel(1, Vector2.ZERO)
	var outer_piece := outer.fire.add_fuel(1, Vector2.ZERO)
	for i in range(16):
		inner.fire.step()
		outer.fire.step()
	_check(outer_piece.water > inner_piece.water and outer.fire.coals[0].water > inner.fire.coals[0].water,
		"Exposure wets actual fuel and coals through the combustion model")
	var thunder := 0.0
	var weather := Chapter.Shelter.new()
	for second in range(870, 940):
		weather.sample(float(second))
		thunder = maxf(thunder, weather.thunder)
	_check(thunder > 0.2 and Audio.measure(outer.fire, Vector2.ZERO).rain > 0.0,
		"Weather supplies gust, rain and rumble signals for the local mixer")

func _tend_chapter() -> Dictionary:
	var story := Chapter.new(Fire.new())
	var fire := story.fire
	var original := fire.coals[0]
	var ash_error := 0.0
	var banked_heat := false
	var banked_air := false
	var all_placed := story.request(1)
	for i in range(5):
		var angle := TAU * i / 5.0
		all_placed = fire.add_fuel(4, Vector2.from_angle(angle) * 0.043, angle + PI * 0.5, 0.0, 0, true) != null and all_placed
	all_placed = fire.lift_coal(original) and fire.deposit_coal(original, Vector2.ZERO) and all_placed
	while fire.time < Chapter.Shelter.END and story.outcome.is_empty():
		if fire.time in [0.25, 2.75]:
			fire.send_breath(Vector2(0, 0.45), Vector2.ZERO, 0.84, 1.2)
		if fire.time in [29.0, 110.0]:
			all_placed = story.request(2) and all_placed
		if fire.time == floorf(fire.time) and FUEL_SCHEDULE.has(int(fire.time)):
			var fuel: Array = FUEL_SCHEDULE[int(fire.time)]
			all_placed = fire.add_fuel(fuel[0], fuel[1], fuel[2], 0.0, 0, true) != null and all_placed
		if fire.time == 751.0:
			var before := _ash_mass(fire)
			fire.uncover()
			ash_error = maxf(ash_error, absf(before - _ash_mass(fire)))
		if fire.time in [304.0, 455.0, 530.0]:
			var before := _ash_mass(fire)
			for coal in fire.coals.duplicate():
				fire.sweep_ash(coal.at, Vector2(0.65, 0.10))
			ash_error = maxf(ash_error, absf(before - _ash_mass(fire)))
			if fire.time >= 455.0:
				fire.rake_at(Vector2.ZERO, Vector2.ZERO, 2.0)
				all_placed = fire.bank() and all_placed
				ash_error = maxf(ash_error, absf(before - _ash_mass(fire)))
		story.step()
		if fire.time == 700.0:
			banked_heat = fire.coals.any(func(coal): return coal.cover > 0.002 and coal.temperature > 500.0)
			banked_air = fire.coals.any(func(coal): return coal.cover > 0.002 and coal.oxygen < fire.oxygen * 0.7)
	var result := {"time": fire.time, "outcome": story.outcome, "coal": fire.coal_reserve(), "hot": _hottest(fire),
		"coals": fire.coals.map(func(coal): return [coal.at, coal.char_mass, coal.temperature, coal.water, coal.cover]),
		"milestones": [story.nest, story.flame, story.larger, story.bed, story.made_ash, story.preserved],
		"all_placed": all_placed, "stock": fire.fuel_stock, "wind": story.weather.wind, "rain": story.weather.rain,
		"ash_error": ash_error, "banked_heat": banked_heat, "banked_air": banked_air}
	var coals := fire.coals.duplicate()
	var supplies := story.sites.duplicate(true)
	var ash := fire.ash
	result.continuity = (story.begin_after_storm() and story.sequel != null and fire.coals == coals and
		story.sites == supplies and fire.ash == ash and fire.time == result.time and fire.coal_reserve() == result.coal)
	return result

func _advance(story: Chapter, target: float) -> void:
	while story.fire.time < target and story.outcome.is_empty():
		story.step()

func _ash_mass(fire: Fire) -> float:
	var mass := fire.ash
	for coal in fire.coals:
		mass += coal.cover + coal.mineral
	return mass

func _hottest(fire: Fire) -> float:
	var heat := fire.ambient()
	for coal in fire.coals:
		heat = maxf(heat, coal.temperature)
	return heat

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
