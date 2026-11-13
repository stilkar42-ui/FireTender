extends RefCounted
## Understanding combines neural evidence, subject cues, and recent turns.
const Fire := preload("res://sim/fire.gd")
const Advice := preload("res://sim/speaker_advice.gd")
const Understanding := preload("res://sim/speaker_understanding.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const UNCERTAIN := "What part do you mean? Tell me what you see in the hearth, or which words you want me to explain."
const UNKNOWN := "That is beyond what I can tell you. I can share what I know of tending, and what we have spoken of here."
const VERSION := 1
const GUIDANCE_ACTIONS := {
	"load": ["move", "arrange", "roll"], "gap": ["move", "arrange"], "dry": ["move", "roll"],
	"shape": ["move", "arrange", "roll"], "feed": ["place"], "place": ["place"],
	"tinder": ["place"], "breath": ["breathe"], "expose": ["expose"], "bank": ["bank"],
	"gather": ["rake"], "carry": ["move ember"],
}
var turns: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var teachings: Array[Dictionary] = []
var living_available := true # Future story owner may disable consultation; no death event here.
var serial := 0
var last_result: Dictionary = {}
var knowledge: Dictionary = {}
var chapter: Chapter

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://sim/speaker_knowledge.json"))
	if parsed is Dictionary and parsed.get("version", 0) == VERSION:
		knowledge = parsed

func reset_hearth() -> void:
	turns.clear()
	actions.clear()
	serial = 0
	last_result.clear()

func note_action(verb: String, time: float) -> void:
	serial += 1
	actions.append({"verb": verb, "time": time, "serial": serial})
	if actions.size() > 16:
		actions.pop_front()

func reply(fire: Fire, words: String, hand: Vector3, selected: Fire.Piece, yaw: float, hint := "", lesson := "") -> String:
	if not living_available:
		return "There is no living voice here to answer a new question."
	var previous: Dictionary = {} if turns.is_empty() else turns.back()
	last_result = Understanding.interpret(words, previous, hint, chapter != null)
	if chapter != null and chapter.sequel != null:
		var topic := chapter.sequel.topic(words) if not hint.begins_with("field_") else hint
		var clean := words.to_lower()
		if "storm leave" in clean or "storm left" in clean:
			topic = "field_aftermath"
		elif "where" in clean and ("wet wood" in clean or "damp wood" in clean):
			topic = "field_wet"
		elif "dry" in clean and ("left outside" in clean or ("anything" in clean and "outside" in clean)):
			topic = "field_dry"
		elif "dry first" in clean:
			topic = "field_first"
		if not topic.is_empty():
			last_result.intent = topic
			last_result.route = "subject"
	if chapter != null and chapter.family != null:
		var lessons := Chapter.Family.Workshop.Lessons
		var reflection := hint if lessons.REVIEW_AREAS.has(hint) else lessons.review_topic(words)
		if not reflection.is_empty():
			last_result.intent = reflection
			last_result.route = "family reflection"
	var intent: String = last_result.intent
	var request: String = last_result.request
	var contextual: bool = last_result.route == "context" and not previous.is_empty()
	if intent.is_empty():
		return UNCERTAIN if last_result.route == "clarify" else UNKNOWN
	var cue := Advice._read(fire, hand, selected)
	var now := _snapshot(cue)
	var first_assessment: bool = intent == "better" and last_result.route == "assessment" and not previous.has("guidance")
	var answer := ""
	match intent:
		"review_hunt", "review_cook", "review_make":
			var area: String = Chapter.Family.Workshop.Lessons.REVIEW_AREAS[intent]
			answer = chapter.family.workshop.lessons.reflect(area) if chapter != null and chapter.family != null else UNKNOWN
		"better":
			if first_assessment:
				answer = "I have no earlier reading to compare. " + Advice.answer(fire, "growth", hand, selected, yaw, cue)
			else:
				answer = _followup(now, fire, hand, selected, yaw, cue)
		"repeat":
			if not turns.is_empty():
				answer = turns.back().reply
			elif not teachings.is_empty():
				answer = teachings.back().words
			else:
				answer = "We have not spoken of a question yet. Ask me what you see in the fire."
		"next":
			if chapter != null:
				answer = chapter.guidance()
			else:
				answer = lesson if not lesson.is_empty() else Advice.answer(fire, "growth", hand, selected, yaw, cue)
		"combustion":
			answer = "Heat darkens the wood and draws out what will feed a flame. The black coal left behind can keep glowing after the flame has gone. Give that glow room for breath."
		_:
			if intent == "kin_count":
				answer = Chapter.Kin.COUNT_LIMIT
			elif intent == "ancestor":
				answer = Chapter.Kin.ANCESTOR
			elif chapter != null and chapter.sequel != null and intent.begins_with("field_"):
				answer = chapter.field_answer(intent)
			elif chapter != null and chapter.sequel != null and (intent.begins_with("myth_") or intent.begins_with("wood_")):
				answer = chapter.sequel.answer(intent, selected)
			elif chapter != null and intent == "gather_choice":
				answer = str(previous.reply) if contextual else chapter.gathering_advice()
			elif chapter != null and (intent == "prepared" or intent.begins_with("enough_")):
				answer = chapter.preparedness(intent.trim_prefix("enough_"))
			elif chapter != null and intent in ["return", "scout", "torch_kin", "shelter", "ash", "rain", "storm", "weather_wind"]:
				answer = chapter.answer(intent)
			elif contextual and previous.has("guidance") and request in ["cause", "consequence", "demonstration", "clarification"]:
				var instruction := request in ["demonstration", "clarification"]
				if instruction:
					previous.guidance = Advice.guidance(cue, intent)
				answer = _practical_followup(fire, intent, "demonstration" if instruction else request, previous.guidance, cue, hand, selected, yaw)
			elif intent == "apprentice" and request in ["advice", "demonstration", "reassurance"]:
				answer = lesson if not lesson.is_empty() else Advice.answer(fire, "growth", hand, selected, yaw, cue)
				if request == "reassurance":
					answer = "We can tend it a little at a time. " + answer
			elif knowledge.has(intent):
				var entry: Dictionary = knowledge[intent]
				var responses: Dictionary = entry.get("responses", {})
				answer = responses.get(last_result.get("detail", request), entry.reply)
			elif intent == "coals" and request == "duration":
				answer = Advice.coal_duration(cue)
			elif intent == "revive" and request == "consequence":
				answer = Advice.if_fire_fails(cue)
			else:
				answer = Advice.answer(fire, intent, hand, selected, yaw, cue)
	if contextual and intent != "better":
		previous.reply = answer
	elif first_assessment or intent not in ["repeat", "better"]:
		var topic := "growth" if first_assessment else intent
		var turn := {"intent": topic, "question": words.left(120), "reply": answer, "reading": now, "action_serial": serial}
		if Advice.PROMPTS.has(topic) or topic in ["next", "apprentice"]:
			turn.guidance = Advice.guidance(cue, topic)
		turns.append(turn)
		if turns.size() > 6:
			turns.pop_front()
		_retain(topic, answer)
	return answer

static func _snapshot(cue: Advice.Reading) -> Dictionary:
	return {"flame": cue.flame, "red": cue.red_mass, "packed": cue.packed or cue.tight_tinder,
		"load": cue.overloaded}

func _practical_followup(fire: Fire, topic: String, request: String, guidance: String, cue: Advice.Reading,
		hand: Vector3, selected: Fire.Piece, yaw: float) -> String:
	# Explain the prior recommendation. For a demonstration, point to what
	# is still useful in the live hearth, which may have changed since then.
	var lines: Dictionary = Advice.FOLLOW_UPS.get(guidance, {})
	if lines.has(request):
		return lines[request]
	if request == "demonstration" and topic in ["heat", "place", "coals", "ember", "revive"]:
		return Advice.answer(fire, "place", hand, selected, yaw, cue)
	var fallback := topic if Advice.PROMPTS.has(topic) else "growth"
	return Advice.answer(fire, fallback, hand, selected, yaw, cue)

func _followup(now: Dictionary, fire: Fire, hand: Vector3, selected: Fire.Piece, yaw: float, cue: Advice.Reading) -> String:
	if turns.is_empty():
		return "What change do you mean? Ask me about the fire first, and we can watch it together."
	var previous: Dictionary = turns.back()
	if not previous.has("guidance"):
		return "Do you mean the hearth? Show me what you changed, and ask me about that."
	var before: Dictionary = previous.reading
	var opened: bool = (before.packed and not now.packed) or (before.load and not now.load)
	var stronger_flame: bool = now.flame > before.flame + maxf(0.5, before.flame * 0.15)
	var more_red: bool = now.red > before.red + 0.005
	var worse: bool = now.flame + maxf(0.5, before.flame * 0.15) < before.flame or now.red + 0.005 < before.red
	var relevant: Array = GUIDANCE_ACTIONS.get(previous.guidance, [])
	var followed := actions.any(func(action: Dictionary) -> bool:
		return action.serial > previous.action_serial and action.verb in relevant)
	var topic: String = previous.intent if Advice.PROMPTS.has(previous.intent) else "growth"
	var lead := ""
	if opened and now.red < 0.002 and now.flame < 2.0:
		lead = "There is more space now, but I see no living red. Look beneath the ash before adding wood."
	elif opened:
		lead = "Yes. There is more room around the red now. Give it time."
	elif stronger_flame:
		lead = "The flame stands taller now. Give the wood time to catch before adding more."
	elif more_red:
		lead = "There is more red in the bed now. Keep that warmth together and offer it a little dry fuel."
	elif worse:
		lead = "The fire has faded since we spoke. " + Advice.answer(fire, topic, hand, selected, yaw, cue)
	else:
		lead = "I cannot yet see a clear change. " + Advice.answer(fire, topic, hand, selected, yaw, cue)
	if followed and (opened or stronger_flame or more_red):
		lead = "You tried what we spoke of. " + lead
	# A repeated follow-up compares with the last check, not an ever older reading.
	previous.reading = now
	previous.action_serial = serial
	previous.reply = lead
	return lead

func _retain(topic: String, words: String) -> void:
	for item in teachings:
		if item.topic == topic and item.words == words:
			return
	teachings.append({"topic": topic, "words": words, "source": "living_conversation"})
	if teachings.size() > 24:
		teachings.pop_front()

func remember_lesson(topic: String, words: String) -> void:
	_retain(topic, words)

func remembered_teaching(topic: String) -> String:
	# Future event triggers retrieve only words actually heard. No new inference.
	for i in range(teachings.size() - 1, -1, -1):
		if teachings[i].topic == topic:
			return teachings[i].words
	return ""

func export_memory() -> Dictionary:
	return {"version": VERSION, "teachings": teachings.duplicate(true)}

func import_memory(data: Dictionary) -> void:
	if data.get("version", 0) != VERSION or not data.get("teachings", null) is Array:
		return
	teachings.clear()
	for entry: Variant in data.teachings.slice(-24):
		if entry is Dictionary and entry.get("topic", null) is String and entry.get("words", null) is String:
			_retain(entry.topic.left(40), entry.words.left(700))
