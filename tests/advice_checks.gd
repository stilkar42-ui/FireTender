extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Heat := preload("res://sim/felt_heat.gd")
const Advice := preload("res://sim/speaker_advice.gd")
const Mentor := preload("res://sim/mentor.gd")
const Observe := preload("res://sim/observe.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	_heat()
	_words()
	_context()
	_mentor()
	print("Phase 1.6 heat and advice: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _heat() -> void:
	var fire := Fire.new(Fire.COLD)
	fire.coals.clear()
	fire.cells.clear()
	var cold := Heat.sample(fire, Heat.ground(Vector2.ZERO))
	_check(cold == 0.0 and Heat.level(cold) == 0, "A cold hearth registers no felt warmth")
	fire._trial_coal(Vector2.ZERO, 0.24, 720.0)
	var coal := fire.coals[0]
	var near := Heat.ground(Vector2(0.34, 0.0))
	var far := Heat.ground(Vector2(1.8, 0.0))
	var exposed := Heat.sample(fire, near)
	_check(exposed > Heat.sample(fire, far) * 5.0 and Heat.level(exposed) > Heat.level(Heat.sample(fire, far)),
		"Felt heat falls with distance from the same glowing source")
	fire.add_fuel(10, Vector2(0.15, 0.0), PI / 2.0, 0.0, 0, true)
	var blocked := Heat.sample(fire, near)
	var opposite := Heat.sample(fire, Heat.ground(Vector2(-0.34, 0.0)))
	_check(blocked < exposed * 0.55 and is_equal_approx(opposite, exposed) and Heat.level(blocked) < Heat.level(opposite),
		"A cold split casts a heat shadow on one side of the same hearth")
	var fresh := fire.add_fuel(4, Vector2(-0.23, 0.0))
	var before_flame := Heat.sample(fire, Heat.ground(fresh.at))
	fresh.flame = 20.0
	_check(Heat.sample(fire, Heat.ground(fresh.at)) > before_flame + 0.30, "A nearby flame adds felt heat above the coal reading")
	coal.cover = 0.02
	var shielded := Heat.sample(fire, Heat.ground(Vector2(-0.34, 0.0)))
	coal.cover = 0.0
	_check(shielded < Heat.sample(fire, Heat.ground(Vector2(-0.34, 0.0))), "An ash cover reduces the heat felt from otherwise identical coals")
	_check(Heat.level(0.0) == 0 and Heat.level(0.08) == 1 and Heat.level(0.3) == 2 and
		Heat.level(0.8) == 3 and Heat.level(1.8) == 4 and Heat.level(3.5) == 5,
		"All six qualitative bands have distinct ordered thresholds")
	coal.pulse = 0.4
	coal.breath_balance = 0.25
	coal.char_heat = 0.8
	var impression := Observe.read(fire, Vector2.ZERO, 0.0, "Warm")
	_check("Warm." in impression and "The draft brightens these coals." in impression,
		"Inspection records felt heat and keeps the existing breath observation")

func _words() -> void:
	var examples := {
		"Why fire not grow?": "growth", "Is small flame not hungry?": "flame", "Are the coals dying?": "coals",
		"Too much wood?": "load", "Need air?": "air", "Are they packed tight?": "crowd",
		"Why so much smoke?": "smoke", "Is this log too wet?": "wet", "Can this ember still wake a flame?": "ember",
		"Where is the hottest place?": "heat", "How do I stack logs?": "shape", "What to burn next?": "fuel",
		"Should I bank it now?": "bank", "Why did it go dark?": "revive", "Where should I place this?": "place",
		"Can this catch?": "place", "Why all this somke?": "smoke", "Is it watterlogged?": "wet",
	}
	for question: String in examples:
		_check(Advice.classify(question) == examples[question], "Recognizes “%s”" % question)
	for topic: String in Advice.PROMPTS:
		_check(Advice.classify(Advice.PROMPTS[topic]) == topic, "The suggested question maps back to %s" % topic)
	_check(Advice.classify("Tell me about the moon.") == "" and Advice.classify("bright sparks of philosophy") == "",
		"Unrelated questions avoid substring matches and fall back")

func _context() -> void:
	var hand := Heat.ground(Vector2.ZERO)
	var ember := Fire.new(Fire.ONE_EMBER)
	var cold := Fire.new(Fire.COLD)
	var banked := Fire.new(3)
	var wet := Fire.new(8)
	_check("ember" in Advice.suggestions(ember, hand, null, 4) and
		"bank" in Advice.suggestions(banked, hand, null, 3) and
		"wet" in Advice.suggestions(wet, hand, null, -1) and
		Advice.suggestions(cold, hand, null, -1) != Advice.suggestions(ember, hand, null, 4),
		"Suggestions follow the current practice, a lone ember, wet wood and a banked bed")
	_check("few dry fibres" in Advice.answer(ember, "ember", hand, null, 0.0) and
		"fresh coal" in Advice.answer(cold, "ember", hand, null, 0.0) and
		"Brush it back" in Advice.answer(banked, "revive", hand, null, 0.0),
		"Revival advice distinguishes viable embers, cold ash, and coals under cover")
	var load := ember.add_fuel(2, Vector2.ZERO, 0.0, 0.0, 0, true)
	_check("cold wood" in Advice.answer(ember, "growth", hand, load, 0.0) and
		"load" in Advice.suggestions(ember, hand, load, 4),
		"A cold split over a live ember prompts specific overload advice")
	var soaked: Fire.Piece = wet.wood.back()
	_check("gives water" in Advice.answer(wet, "wet", hand, soaked, 0.0) and
		"pale trail" in Advice.answer(wet, "smoke", hand, soaked, 0.0),
		"The speaker distinguishes wet wood and visible vapor from smoke")
	var tinder := Fire.new(Fire.ONE_EMBER)
	var tuft := tinder.add_fuel(4, Vector2.ZERO)
	tuft.oxygen = 0.30
	tuft.pore_density = 1.1
	_check("fibres lie too close" in Advice.answer(tinder, "air", hand, tuft, 0.0),
		"Restricted airflow through fine tinder elicits advice to open the nest")
	var side := Fire.new(4)
	_check("on the left" in Advice.answer(side, "heat", hand, null, 0.0) and
		"on the right" in Advice.answer(side, "heat", hand, null, PI),
		"Directional advice follows the warm side and current camera angle")
	_check(Advice.answer(cold, Advice.classify("What are stars?"), hand, null, 0.0) == Advice.FALLBACK,
		"The unsupported-question answer stays in character")
	var faint := Fire.new(Fire.NURSE_EMBER)
	var inner := Fire.new(Fire.FEED_FIRE)
	var carry := Fire.new(Fire.CARRY_EMBER)
	_check("gentle breath" in Advice.answer(faint, "air", hand, null, 0.0) and
		"feed" in Advice.suggestions(inner, hand, null, -1) and
		"carry" in Advice.suggestions(carry, hand, null, -1),
		"The Speaker recognizes viable faint embers, a distant nest, and an accessible inner opening")

func _mentor() -> void:
	var fire := Fire.new(Fire.OPENING)
	var mentor := Mentor.new()
	mentor.enter(fire, true)
	mentor._offer("uneven", 46)
	var pending := mentor.pending
	mentor.ask(fire, "Where is the hottest place?", Heat.ground(Vector2.ZERO), null, 0.0)
	_check(mentor.history.size() == 2 and "You asked" in mentor.history.back() and
		mentor.pending == pending and mentor.lesson == 0 and not mentor.engaged and fire.time == 0.0,
		"Asking adds history immediately without advancing the hearth, lesson, or reactive queue")
	for tick in range(32):
		mentor.tick(0.5)
	_check(pending != "" and mentor.history.size() == 3 and mentor.history.back() in Mentor.LINES[pending],
		"The pending reactive observation can still be spoken after an answer")
	for i in range(34):
		mentor.ask(fire, "Question %d" % i, Heat.ground(Vector2.ZERO), null, 0.0)
	_check(mentor.history.size() == 32 and "33" in mentor.history.back() and mentor.history_version > 32,
		"Repeated questions retain the newest entry when the history is full")

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
