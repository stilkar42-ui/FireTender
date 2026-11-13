extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Shelter := preload("res://sim/red_hollow_shelter.gd")
const Touch := preload("res://sim/felt_touch.gd")
const Advice := preload("res://sim/speaker_advice.gd")
const Lab := preload("res://hearth/hearth.tscn")
var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_wind()
	_fire_response()
	_heat()
	if DisplayServer.get_name() != "headless":
		await _scene()
	print("Cave draft and spent fire: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _wind() -> void:
	var cave := Shelter.new()
	var depths := [Vector2(0, -3.1), Shelter.PASSAGE, Vector2.ZERO]
	for sky: Vector2 in [Vector2.ZERO, Vector2(0.4, 1.1), Vector2(-1.0, 0.0)]:
		cave.wind = sky
		_check(depths.all(func(at: Vector2): return cave.wind_at(at).is_zero_approx()) and
			cave.wind_at(Vector2(0, 2.0)) == sky,
			"Outside air %s stays outside when it cannot enter the mouth" % str(sky))
	cave.wind = Vector2(0.4, -0.8)
	var hearth := cave.wind_at(Vector2.ZERO)
	_check(depths.all(func(at: Vector2): return cave.wind_at(at).y < 0.0) and
		cave.wind_at(Shelter.PASSAGE).length() > cave.wind_at(Vector2(-0.64, Shelter.PASSAGE.y)).length() and
		cave.wind_at(depths[0]).length() < hearth.length() * 0.25,
		"Inward wind reaches the hearth and passage through the mouth and weakens toward the rear")

func _fire_response() -> void:
	var calm := _tend(Vector2.ZERO, 1)
	var blocked := _tend(Vector2(0.18, 1.0), 1)
	var sheltered := _tend(Vector2(0.0, -0.24), 0)
	var exposed := _tend(Vector2(0.0, -0.24), 2)
	print("Matched opening · calm %s · blocked %s · sheltered %s · exposed %s" %
		[str(calm), str(blocked), str(sheltered), str(exposed)])
	_check(calm == blocked and calm.peak > 2.0, "Wind blowing away from the mouth has the same ignition and cooling as calm air")
	_check(exposed.draft > sheltered.draft and exposed.loss > sheltered.loss and sheltered.first >= 0.0 and exposed.first < 0.0,
		"The same inward draft lets a nest catch under cover and prevents ignition at the exposed mouth")
	_check(calm.lingering and sheltered.lingering, "After actual flame subsides, the bed can stay hot enough to burn a hand")

func _tend(wind: Vector2, site: int) -> Dictionary:
	var story := Chapter.new(Fire.new())
	var fire := story.fire
	story.choose_site(site)
	story.weather.wind = wind
	story.weather.sampled = 10000.0
	var ember := fire.coals[0]
	for i in range(5):
		var angle := TAU * i / 5.0
		fire.add_fuel(4, Vector2.from_angle(angle) * 0.043, angle + PI * 0.5, 0.0, 0, true)
	fire.lift_coal(ember)
	fire.deposit_coal(ember, Vector2.ZERO)
	var peak := 0.0
	var draft := 0.0
	var loss := 0.0
	var first := -1.0
	var lingering := false
	for tick in range(240):
		if tick in [1, 11]:
			fire.send_breath(Vector2(0, 0.45), Vector2.ZERO, 0.84, 1.2)
		if tick == 12:
			fire.add_fuel(0, Vector2(0.09, 0), 0.0, 0.0, 0, true)
		if tick == 24:
			fire.add_fuel(1, Vector2(-0.11, 0), 0.0, 0.0, 0, true)
		story.step()
		var flame := fire.total_flame()
		peak = maxf(peak, flame)
		if first < 0.0 and flame >= 2.0:
			first = fire.time
		if tick == 0:
			draft = ember.draft.length()
			loss = ember.convection_loss
		if peak > 2.0 and flame < 0.2:
			lingering = lingering or fire.coals.any(func(coal: Fire.Piece):
				return Touch.coal_surface_temperature(coal, fire.ambient()) >= Touch.HOT_TOUCH)
	return {"peak": peak, "first": first, "draft": draft, "loss": loss, "lingering": lingering}

func _heat() -> void:
	var fire := Fire.new(Fire.COLD)
	fire.coals.clear()
	var coal := fire._new_coal(Vector2.ZERO, 0.0003, 245.0, 0.028)
	coal.mineral = 0.004
	var touch := Touch.coal(coal, fire.ambient(), 0.0)
	var words := Advice.answer(fire, "revive", Vector3.ZERO, null, 0.0)
	_check(touch.words == "Ash is hot to touch." and "flame is out" in words and "burn your hand" in words and not coal.living_coal(),
		"Hot spent ash gets a touch warning while the Speaker explains the flame is out")
	coal.char_mass = 0.001
	coal.temperature = 355.0
	_check("A little life remains" in Advice.answer(fire, "revive", Vector3.ZERO, null, 0.0),
		"The Speaker recognizes a faint viable ember below the stronger red threshold")
	coal.temperature = fire.ambient()
	_check("no living red" in Advice.answer(fire, "revive", Vector3.ZERO, null, 0.0) and
		Touch.coal(coal, fire.ambient(), 0.0).heat < 0.05, "Cold ash gives neither a burn warning nor a promise of ignition")
	var log := fire.add_fuel(7, Vector2(0.35, 0))
	_check(Touch.fuel(log, log, 0, 3.0).words == "Cool and dry.\nStrong heat nearby.",
		"A cool surface beside strong radiant heat reports both conditions")

func _scene() -> void:
	var lab: Control = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-draft-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await process_frame
	var coal: Fire.Piece = lab.fire.coals[0]
	coal.char_mass = 0.0003
	coal.mineral = 0.004
	coal.temperature = 245.0
	lab.chapter.flame = true
	var bench = lab.view.workbench
	bench._refresh(0.0)
	var center := Vector3(coal.at.x, coal.at.y, 0.015)
	var screen: Vector2 = bench.project(center)
	var edge: Vector2 = bench.project(center + Vector3(0.024, 0, 0))
	_check(bench.touch_at(screen).piece == coal and bench.touch_at(edge).piece == null,
		"Touch detects the visible ash patch without picking the empty halo around it")
	lab.view.pointer = screen
	lab.view._update_probe()
	lab._inspect()
	lab._toggle_ask()
	lab._submit_question("Can I bring the flame back?", "revive")
	lab._update_chapter()
	_check(lab.warmth.text == "Ash is hot to touch." and "no standing flame" in lab.note.text and
		"flame is out" in lab.mentor.text and "Check the bed" in lab.chapter_note.text,
		"The hand, inspection, Fire Speaker and objective agree after the flame dies")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		await create_timer(0.30).timeout
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(args[0].path_join("spent-flame-hot-ash.png")) == OK,
			"Captured the coordinated heat and flame readings")

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
