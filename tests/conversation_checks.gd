extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Mentor := preload("res://sim/mentor.gd")
const Dialogue := preload("res://sim/speaker_conversation.gd")
const OLD_CLARIFICATION := "I am not sure what you mean. Are you asking about this fire, or about something I told you?"
const REPORTED := [
	{"ask": "What happened to your legs?", "topic": "injury", "request": "history", "contains": ["how it happened", "injured leg"]},
	{"ask": "How do I keep the fire alive?", "topic": "growth", "request": "advice", "contains": ["dry fibres", "breath"]},
	{"ask": "Coal", "topic": "coals", "request": "explanation", "contains": ["glow"]},
	{"ask": "What happened to your leg?", "topic": "injury", "request": "history", "contains": ["how it happened"]},
	{"ask": "Why can't you walk?", "topic": "injury", "request": "cause", "contains": ["injured leg", "hearth"]},
	{"ask": "What should I do to keep it burning?", "topic": "growth", "request": "advice", "contains": ["dry fibres"]},
	{"ask": "How long will these coals last?", "topic": "coals", "request": "duration", "contains": ["little red", "soon"]},
	{"ask": "What if the fire goes out?", "topic": "revive", "request": "consequence", "contains": ["if", "fresh coal"]},
	{"ask": "Why do we have to keep the fire?", "topic": "heritage", "request": "cause", "contains": ["stone mountain’s kin", "red hollow"]},
	{"ask": "Can you teach me?", "topic": "apprentice", "request": "advice", "contains": ["dry fibres"]},
	{"ask": "What am I doing wrong?", "topic": "growth", "request": "cause", "contains": ["dry fibres"]},
	{"ask": "Is it getting better?", "topic": "better", "request": "assessment", "contains": ["earlier reading", "dry fibres"]},
]

var baseline := false
var checks := 0
var failures := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	baseline = "--baseline" in args
	for row: Dictionary in REPORTED:
		_turn(_hearth("ember"), Mentor.new(), row, true)
	_required_followups()
	_scope_regressions()
	if "--offline" not in args:
		_evaluate(args)
	print("Phase 1.8.1 conversation checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)

func _evaluate(args: PackedStringArray) -> void:
	var corpus_path := ProjectSettings.globalize_path("res://tests/conversation_evaluation.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(corpus_path))
	if not data is Dictionary:
		_check(false, "Read independently authored conversation evaluation")
		return
	var results: Array[Dictionary] = []
	for row: Dictionary in data.single_turn:
		results.append(_turn(_hearth(row.hearth), Mentor.new(), row))
	var single_count := results.size()
	for conversation: Dictionary in data.conversations:
		var fire := _hearth(conversation.hearth)
		var mentor := Mentor.new()
		for row: Dictionary in conversation.turns:
			match row.get("action", ""):
				"move_load":
					fire.move_fuel(fire.wood[0], Vector2(1.4, 0.0))
					mentor.tend("move", fire)
				"fresh_hearth":
					fire = _hearth("cold")
					mentor.enter(fire, false)
			results.append(_turn(fire, mentor, row))
	var useful := 0
	var single_useful := 0
	var topic_matches := 0
	var request_matches := 0
	for i in range(results.size()):
		var result := results[i]
		if result.useful:
			useful += 1
			single_useful += int(i < single_count)
		else:
			print("Miss: ", JSON.stringify(result))
		topic_matches += int(result.topic == result.expected.topic)
		request_matches += int(result.request == result.expected.request)
	var report := {"baseline": baseline, "total": results.size(), "useful": useful,
		"single_count": single_count, "single_useful": single_useful,
		"multi_turn_count": results.size() - single_count, "multi_turn_useful": useful - single_useful,
		"topic_matches": topic_matches, "request_matches": request_matches, "results": results}
	print("Conversation evaluation: ", JSON.stringify(report.duplicate().merged({"results": results.size()}, true)))
	if not baseline:
		_check(useful >= 42, "Final replies meet the relevance criteria on at least 42 of 47 evaluation turns")
		_check(useful - single_useful >= 13, "Relevant replies cover at least 13 of 15 evaluation follow-ups")
		_check(topic_matches >= 42 and request_matches >= 42, "Subjects and request types are evaluated separately")
	var report_arg := args.find("--report")
	if report_arg >= 0 and report_arg + 1 < args.size():
		var file := FileAccess.open(args[report_arg + 1], FileAccess.WRITE)
		_check(file != null, "Write conversation evaluation report")
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))

func _required_followups() -> void:
	var fire := _hearth("loaded")
	var mentor := Mentor.new()
	for row: Dictionary in [
		{"ask": "How do I keep the fire alive?", "topic": "growth", "request": "advice", "contains": ["cold wood", "lift"]},
		{"ask": "Why?", "topic": "growth", "request": "cause", "contains": ["cold wood", "warmth"]},
		{"ask": "Show me.", "topic": "growth", "request": "demonstration", "contains": ["heavy piece", "glow"]},
		{"ask": "What happens if I don't?", "topic": "growth", "request": "consequence", "contains": ["cold wood", "fade"]},
	]:
		_turn(fire, mentor, row, true)
	fire.move_fuel(fire.wood[0], Vector2(1.4, 0.0))
	mentor.tend("move", fire)
	_turn(fire, mentor, {"ask": "Is that better?", "topic": "better", "request": "assessment", "contains": ["tried", "more room"]}, true)
	_turn(fire, mentor, {"ask": "And what about the coals?", "topic": "coals", "request": "explanation", "contains": ["glow"]}, true)
	_turn(fire, Mentor.new(), {"ask": "Why?", "topic": "", "request": "cause", "reply": "clarify"}, true)
	var apprentice := Mentor.new()
	apprentice.enter(fire, true)
	_turn(fire, apprentice, {"ask": "Can you teach me?", "topic": "apprentice", "request": "advice", "contains": [Mentor.TASKS[0].to_lower()]}, true)
	_turn(fire, apprentice, {"ask": "What if I fail at this?", "topic": "apprentice", "request": "reassurance", "contains": ["a little at a time", Mentor.TASKS[0].to_lower()]}, true)
	_turn(fire, mentor, {"ask": "What do you mean by that?", "topic": "coals", "request": "clarification", "contains": ["glow", "dry fibres"]}, true)

func _scope_regressions() -> void:
	_turn(_hearth("cold"), Mentor.new(), {"ask": "Why did it go dark?", "topic": "revive", "request": "cause", "contains": ["fresh coal"]}, true)
	_turn(_hearth("bed"), Mentor.new(), {"ask": "Will banking save it for morning?", "topic": "bank", "request": "assessment", "contains": ["ash"]}, true)
	_turn(_hearth("ember"), Mentor.new(), {"ask": "Can I fire someone from their job?", "topic": "", "request": "advice", "reply": "unknown"}, true)
	_turn(_hearth("ember"), Mentor.new(), {"ask": "What weapon caused your wound?", "topic": "injury", "request": "history", "contains": ["how it happened","injured leg"]}, true)
	var fire := _hearth("loaded")
	var mentor := Mentor.new()
	_turn(fire, mentor, {"ask": "Is the fire getting better?", "topic": "better", "request": "assessment", "contains": ["earlier reading", "cold wood"]}, true)
	fire.move_fuel(fire.wood[0], Vector2(1.4, 0.0))
	mentor.tend("move", fire)
	_turn(fire, mentor, {"ask": "Is it doing any better now?", "topic": "better", "request": "assessment", "contains": ["more room"]}, true)

func _turn(fire: Fire, mentor: Mentor, row: Dictionary, required := false) -> Dictionary:
	mentor.ask(fire, row.ask, Vector3.ZERO, null, 0.0)
	var answer := mentor.text
	var prediction := mentor.conversation.last_result
	var useful := true
	match row.get("reply", ""):
		"unknown":
			useful = answer == Dialogue.UNKNOWN
		"clarify":
			useful = answer == Dialogue.UNCERTAIN or (baseline and (answer == OLD_CLARIFICATION or "What change" in answer))
		_:
			for term: String in row.get("contains", []):
				useful = useful and term in answer.to_lower()
	var result := {"expected": row, "topic": prediction.get("intent", ""), "request": prediction.get("request", ""),
		"answer": answer, "useful": useful, "prediction": prediction.duplicate()}
	if required and not baseline:
		_check(useful and result.topic == row.topic and result.request == row.request, row.ask + " → " + answer)
	return result

func _hearth(kind: String) -> Fire:
	var fire := Fire.new(Fire.ONE_EMBER)
	match kind:
		"cold":
			return Fire.new(Fire.COLD)
		"banked":
			return Fire.new(3)
		"wet":
			return Fire.new(8)
		"bed":
			fire.coals.clear()
			fire._trial_bed(0.26, 650.0)
		"loaded":
			fire.add_fuel(2, Vector2.ZERO, 0.0, 0.0, 0, true)
		"flame":
			fire.add_fuel(1, Vector2.ZERO).flame = 25.0
		"packed":
			var tinder := fire.add_fuel(4, Vector2.ZERO)
			tinder.oxygen = 0.3
			tinder.pore_density = 1.1
	return fire

func _check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("PASS  " if condition else "FAIL  ", title)
