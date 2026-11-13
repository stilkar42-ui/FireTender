extends SceneTree
const Fire := preload("res://sim/fire.gd")
const Neural := preload("res://sim/speaker_neural.gd")
const Dialogue := preload("res://sim/speaker_conversation.gd")
const Mentor := preload("res://sim/mentor.gd")
var passed := 0
var failed := 0
var report := {}

func _initialize() -> void:
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var start := Time.get_ticks_usec()
	var first := Neural.infer("Why fire not grow?")
	var load_us := Time.get_ticks_usec() - start
	var loaded_memory := Performance.get_monitor(Performance.MEMORY_STATIC) - memory_before
	_check(Neural.ready and first.intent == "growth", "Shipped CPU model loads without any service or Python")
	_check(Neural.model.labels.size() == 27 and first.has("secondary") and first.confidence > 0.0,
		"Understanding returns 27-way intent, secondary, confidence and uncertainty evidence")
	if "--offline" not in OS.get_cmdline_user_args():
		_evaluation()
	_grounding()
	_memory()
	var timing: Array[int] = []
	for i in range(256):
		start = Time.get_ticks_usec()
		Neural.infer("Why can't I put this stick underneath?")
		timing.append(Time.get_ticks_usec() - start)
	timing.sort()
	report.merge({"godot_load_us": load_us, "godot_model_memory_bytes": loaded_memory,
		"godot_median_us": timing[128], "godot_p95_us": timing[243],
		"weights_bytes": Neural.weights.size() * 4}, true)
	print("Neural CPU measurements: ", JSON.stringify(report))
	_check(timing[243] < 16000 and loaded_memory < 16 * 1024 * 1024,
		"CPU inference stays below one frame at p95 and resident model allocation below 16 MiB")
	var destination := "res://outputs/speaker-evaluation.json"
	if "--offline" not in OS.get_cmdline_user_args():
		var output := FileAccess.open(destination, FileAccess.WRITE)
		if output:
			output.store_string(JSON.stringify(report, "\t"))
	print("Phase 1.8 neural checks: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _evaluation() -> void:
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/speaker/evaluation.json"))
	var python: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/speaker/results.json"))
	var parity := true
	var raw_correct := 0
	var accepted_correct := 0
	var known := 0
	var rejected_unknown := 0
	var outside := 0
	var total := 0
	var misses: Array[Dictionary] = []
	for topic: String in corpus:
		for words: String in corpus[topic]:
			var p := Neural.infer(words)
			var expected := "" if topic == "unknown" else topic
			var py: Dictionary = python.results[total]
			parity = parity and py.text == words and absf(p.confidence - py.confidence) < 0.0001 and \
				(p.intent if not p.intent.is_empty() else "unknown") == py.intent
			total += 1
			if not py.unseen:
				continue
			if p.raw == topic:
				raw_correct += 1
			if topic == "unknown":
				outside += 1
				if p.intent.is_empty():
					rejected_unknown += 1
			else:
				known += 1
				if p.intent == expected:
					accepted_correct += 1
			if p.intent != expected:
				misses.append({"question": words, "expected": topic, "intent": p.intent, "raw": p.raw})
	report = {"unseen_rows": known + outside, "anchor_rows": total - known - outside,
		"unseen_top1_accuracy": float(raw_correct) / (known + outside),
		"unseen_accepted_accuracy": float(accepted_correct) / known,
		"unknown_rejection": float(rejected_unknown) / outside, "misses": misses}
	_check(parity, "Godot and Python agree on every evaluation prediction and confidence")
	_check(report.unseen_top1_accuracy >= 0.78, "Unseen top-1 classification reaches the prototype accuracy floor")
	_check(report.unseen_accepted_accuracy >= 0.70, "Unseen questions retain useful coverage after uncertainty rejection")
	_check(report.unknown_rejection >= 0.80, "Unsupported questions are usually rejected rather than treated as fire knowledge")
	var vague := Neural.infer("And that thing?")
	var clarification := Dialogue.new().reply(Fire.new(Fire.COLD), "And that thing?", Vector3.ZERO, null, 0.0)
	_check(vague.intent.is_empty() or clarification == Dialogue.UNCERTAIN,
		"An ambiguous reference with no conversational context receives clarification")

func _grounding() -> void:
	var hand := Vector3.ZERO
	var dialogue := Dialogue.new()
	var ember := Fire.new(Fire.ONE_EMBER)
	var cold := Fire.new(Fire.COLD)
	_check("dry fibres" in dialogue.reply(ember, "Why fire not grow?", hand, null, 0.0) and
		"fresh coal" in dialogue.reply(cold, "Why fire not grow?", hand, null, 0.0),
		"The same neural intent yields different advice from living ember and cold ash")
	var log := ember.add_fuel(2, Vector2.ZERO, 0.0, 0.0, 0, true)
	log.water = log.original * 0.5
	log.vapor = 0.002
	var answer := dialogue.reply(ember, "Why won't my fire grow?", hand, log, 0.0)
	_check("cold wood" in answer and "damp" in answer, "A diagnosis can combine excessive cold load with observed wetness")
	ember.move_fuel(log, Vector2(1.4, 0.0))
	dialogue.note_action("move", ember.time)
	answer = dialogue.reply(ember, "Better now?", hand, log, 0.0)
	_check("You tried" in answer and "more room" in answer, "Follow-up recognizes the advised action and an actual reduction in load")
	var unchanged := dialogue.reply(ember, "Did that help?", hand, log, 0.0)
	_check("cannot yet see a clear change" in unchanged and "You tried" not in unchanged,
		"A repeated follow-up does not invent new improvement or a new player action")
	_check(dialogue.reply(ember, "What did you tell me before?", hand, null, 0.0) == unchanged,
		"Recall repeats the last grounded conversational advice")
	_check("injured leg" in dialogue.reply(ember, "Will your leg heal?", hand, null, 0.0) and
		"cannot promise" in dialogue.reply(ember, "Will your leg heal?", hand, null, 0.0),
		"The elder knows his injury but does not promise a future recovery")
	_check("passed down" in dialogue.reply(ember, "How did you learn to keep the fire?", hand, null, 0.0) and
		"Stone Mountain’s kin" in dialogue.reply(ember, "Why does the band need this fire?", hand, null, 0.0),
		"Authored experience and inherited fire remain consistent with the established band")
	_check(dialogue.reply(ember, "What is the moon made from?", hand, null, 0.0) == Dialogue.UNKNOWN,
		"An unsupported subject receives an honest in-character limit")
	var mentor := Mentor.new()
	mentor.enter(ember, true)
	mentor.ask(ember, "What should I do next?", hand, null, 0.0)
	_check(mentor.text == Mentor.TASKS[0] and not mentor.engaged and ember.time == 0.0,
		"Next-step guidance follows apprenticeship without tending or advancing time")
	var a := Fire.new(Fire.ONE_EMBER)
	var b := Fire.new(Fire.ONE_EMBER)
	for i in range(64):
		if i % 8 == 0:
			dialogue.reply(a, "Is the little flame hungry?", hand, null, 0.0)
		a.step()
		b.step()
	_check(a.time == b.time and a.coals[0].temperature == b.coals[0].temperature and
		a.coals[0].char_mass == b.coals[0].char_mass, "Consultation does not change deterministic fixed-step combustion")

func _memory() -> void:
	var d := Dialogue.new()
	var fire := Fire.new(Fire.ONE_EMBER)
	_check("What change" in d.reply(fire, "Did that help?", Vector3.ZERO, null, 0.0),
		"Follow-up with no preceding topic asks what changed")
	for i in range(40):
		d.note_action("move", float(i))
		d.reply(fire, "Where is the strongest heat?", Vector3.ZERO, null, 0.0)
		d.remember_lesson("lesson-%d" % i, "Teaching %d" % i)
	_check(d.turns.size() == 6 and d.actions.size() == 16 and d.teachings.size() == 24,
		"Conversation, actions and retained teachings have fixed memory bounds")
	var restored := Dialogue.new()
	restored.import_memory(d.export_memory())
	_check(restored.remembered_teaching("lesson-39") == "Teaching 39" and
		restored.remembered_teaching("never-heard").is_empty(), "Versioned teaching memory preserves only previously retained words")
	d.reset_hearth()
	_check(d.turns.is_empty() and d.actions.is_empty() and not d.teachings.is_empty(),
		"Changing hearth clears stale local context while keeping significant teachings")
	var mentor := Mentor.new()
	mentor.enter(fire, true)
	mentor.ask(fire, "What did you tell me before?", Vector3.ZERO, null, 0.0)
	_check(mentor.text == Mentor.LINES.welcome[0], "Recall can retrieve an apprenticeship teaching before the first question")
	var count := mentor.history.size()
	mentor.conversation.living_available = false
	mentor.ask(fire, "Who are you?", Vector3.ZERO, null, 0.0)
	mentor.observe(fire)
	_check(mentor.history.size() == count and mentor.conversation.remembered_teaching("welcome") == Mentor.LINES.welcome[0],
		"A future story gate disables new living consultation while remembered teachings remain fixed")

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
