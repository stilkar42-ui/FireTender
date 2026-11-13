extends RefCounted
## Resolve the subject and purpose of a question before choosing a reply.
const Neural := preload("res://sim/speaker_neural.gd")
const Advice := preload("res://sim/speaker_advice.gd")

const SUBJECTS := {
	"growth": "fire", "flame": "fire", "revive": "fire", "combustion": "fire",
	"better": "fire", "next": "fire", "coals": "coals", "ember": "coals", "carry": "coals",
	"bank": "coals", "fuel": "fuel", "load": "fuel", "wet": "fuel", "place": "fuel",
	"feed": "fuel", "shape": "structure", "air": "airflow", "crowd": "airflow",
	"smoke": "smoke", "heat": "heat", "injury": "injury", "experience": "elder",
	"identity": "elder", "apprentice": "apprenticeship", "heritage": "responsibility",
	"kin_count": "kinship", "ancestor": "kinship", "return": "elder", "scout": "torch bearer", "torch_kin": "kinship", "shelter": "shelter",
	"ash": "coals", "rain": "weather", "storm": "weather", "weather_wind": "weather",
	"gather_choice": "torch bearer", "prepared": "supplies",
	"enough_tinder": "fuel", "enough_small": "fuel", "enough_medium": "fuel", "enough_large": "fuel",
	"enough_ash": "coals", "enough_coals": "coals",
}

# Only distinctive subject words get spelling tolerance. Ordinary words such
# as "fire", "learn", and "walk" must match as words or in a phrase.
const SUBJECT_WORDS := {
	"injury": ["leg", "legs", "injury", "injured", "wound", "wounded"],
	"coals": ["coal", "coals", "charcoal", "ember", "embers"],
	"smoke": ["smoke", "smoking", "smoky"],
	"wet": ["damp", "wet", "soaked", "sodden", "waterlogged", "hissing", "steam"],
	"air": ["air", "airflow", "breath", "breathe", "blow", "draft", "breeze", "wind", "puff"],
}
const SPELLING := ["leg", "injury", "injured", "charcoal", "ember", "smoke", "damp", "soaked", "waterlogged", "breath", "breathe"]
const FIRE_WORDS := ["fire", "hearth", "flame", "flames", "glow"]
const OUTSIDE_WORDS := ["insurance", "stocks", "shares", "price", "buy", "sell", "online", "rifle",
	"gun", "kiln", "flute", "moon", "stars", "sun", "nuclear", "employee", "illness"]

static var request_patterns := _patterns({
	"recall": "\\b(repeat|remind)\\b|\\bwhat did you (say|tell me)\\b|\\bwhat was your advice\\b",
	"clarification": "^what do you mean\\b|\\b(explain that|do not understand)\\b",
	"reassurance": "^what if i (fail|cannot manage)\\b|^i (am|m) (worried|afraid)\\b",
	"consequence": "^(and )?if\\b|^suppose\\b|\\bwhat (if|happens if|would happen if)\\b",
	"duration": "\\bhow (long|much (longer|time))\\b|\\b(last|hold out) (much )?longer\\b",
	"demonstration": "\\b(show me|point out|walk (me|us) through|where exactly|where should i start)\\b",
	"history": "\\b(what happened|what brought on|how (did|d) (you|your|that)|who (hurt|injured|broke|taught|showed)|how old)\\b|\\bwhat\\b.*\\bcaused\\b.*\\b(leg|legs|injury|wound)\\b|\\b(name|age)\\b.*\\b(you|your|taught)\\b|\\byour (name|age)\\b",
	"cause": "\\bwhy\\b|^what (keeps|caused|s behind|is behind)\\b|^what am i doing wrong\\b",
	"next_step": "\\b(next (step|task)|do next)\\b|^what now$",
	"advice": "^(how (do|can|should)|can|could|would|should)\\b|\\b(advice|healer|medicine|treatment|what (can|should) i (do|change|try|use|add)|where can i)\\b",
	"assessment": "^(am|is|are|was|were|has|have|did|do|does|will)\\b|^what do you think\\b",
})
static var comparison := RegEx.create_from_string("\\b(better|improv\\w*|made (a|any) difference|did (it|that) help|helped|helping)\\b")
static var bare_reference := RegEx.create_from_string("\\b(that thing|this thing)\\b|^(why|what about that|and that|which one|what else)$")
static var contextual_question := _patterns({
	"cause": "^why (is that|do that|would (we|i|you) do that|did that happen|(would|does|did) (that|it) (help|work|matter|make a difference))\\b",
	"history": "^how (did|d) that happen\\b",
	"assessment": "\\bit (will|can) (mend|heal|recover)\\b",
})

static func _patterns(source: Dictionary) -> Dictionary:
	var compiled := {}
	for name: String in source:
		compiled[name] = RegEx.create_from_string(source[name])
	return compiled

static func interpret(question: String, previous: Dictionary, hint := "", story := false) -> Dictionary:
	if not hint.is_empty():
		return _resolved({"reason": "authored_prompt", "confidence": 1.0}, hint if Advice.PROMPTS.has(hint) else "", "advice", "prompt")

	var result := Neural.infer(question)
	result.neural_intent = result.intent
	var clean := _normalize(question)
	var words := clean.split(" ", false)
	var request := _request(clean, result.intent)
	var outside := _has(words, OUTSIDE_WORDS) or ("fire" in words and "job" in words)
	if request == "history":
		if "name" in words or clean.begins_with("who taught ") or clean.begins_with("who showed "):
			result.detail = "name"
		elif _has(words, ["age", "old"]):
			result.detail = "age"
	var topic := _kin_topic(clean, words)
	if topic.is_empty() and story and not outside:
		topic = _story_topic(clean, words, previous)
	if topic.is_empty():
		topic = _explicit_topic(clean, words, request, outside)
	if not topic.is_empty():
		return _resolved(result, topic, request, "subject")
	if outside:
		return _resolved(result, "", request, "unknown")

	var comparing: bool = request == "assessment" and (comparison.search(clean) != null or result.intent == "better")
	var refers_back := bare_reference.search(clean) != null
	var names_subject := _has(words, FIRE_WORDS) or _subject(words, "coals") or _has(words, ["wood", "log", "stick", "fuel", "bark"])
	if request in ["demonstration", "clarification", "consequence"] and not names_subject:
		refers_back = true
	if contextual_question.has(request) and contextual_question[request].search(clean) != null:
		refers_back = true
	if comparing and _has(words, ["that", "it"]) and not _has(words, FIRE_WORDS):
		refers_back = true

	if comparing and not refers_back:
		return _resolved(result, "better", request, "assessment")
	if refers_back:
		if not previous.is_empty():
			var prior: String = previous.intent
			if comparing and _is_practical(prior):
				prior = "better"
			return _resolved(result, prior, request, "context")
		if comparing and bare_reference.search(clean) == null:
			return _resolved(result, "better", request, "assessment" if "it" in words else "context")
		return _resolved(result, "", request, "clarify")

	if not result.intent.is_empty():
		return _resolved(result, result.intent, request, "neural")
	for subject in ["wet", "coals"]:
		if _subject(words, subject):
			return _resolved(result, subject, request, "subject")
	if _has(words, FIRE_WORDS) and _broad_fire_question(clean, words):
		return _resolved(result, "growth", request, "broad_fire")
	var route := "clarify" if result.reason == "uncertain" and words.size() < 5 else "unknown"
	return _resolved(result, "", request, route)

static func _kin_topic(clean: String, words: PackedStringArray) -> String:
	if ("how many of us" in clean or "only fifteen" in clean or "only 15" in clean) and not _has(words, ["coals", "logs", "pieces"]):
		return "kin_count"
	if "stone mountain" in clean and (clean.begins_with("who ") or clean == "stone mountain"):
		return "ancestor"
	if "who are our people" in clean or "who are your people" in clean or "what do we call ourselves" in clean or \
		"what clan" in clean or "what is red hollow" in clean or clean in ["red hollow", "our kin", "our people"]:
		return "heritage"
	if clean.begins_with("who ") and ("mother s kin" in clean or "mother s people" in clean or "our kin" in clean):
		return "heritage"
	return ""

static func _story_topic(clean: String, words: PackedStringArray, previous: Dictionary) -> String:
	var scout := "torch bearer" in clean or "cousin" in words or "scout" in words
	var refers_to_scout: bool = _has(words, ["he", "him"]) and previous.get("intent", "") in ["scout", "torch_kin", "gather_choice"]
	var requests_choice := _has(words, ["should", "recommend", "ought", "choose"]) or clean.begins_with("what would you ")
	var gathering := _has(words, ["gather", "bring", "send", "look", "seek", "collect", "fetch", "get"]) or "go for" in clean
	if (scout or refers_to_scout) and requests_choice and gathering:
		return "gather_choice"
	if scout:
		return "torch_kin" if _has(words, ["who", "related", "kin", "family"]) else "scout"
	if "fire" in words and "you" in words and (_has(words, ["found", "brought", "got"]) or ("where" in words and _has(words, ["find", "get", "bring"]))):
		return "return"
	if "ash" in words and _has(words, ["make", "find", "gather", "sweep", "collect"]):
		return "ash"
	var enough := _prepared_topic(clean, words)
	if not enough.is_empty():
		return enough
	if "wind" in words and _has(words, ["turn", "turned", "turning", "stronger", "coming", "smoke"]):
		return "weather_wind"
	if _has(words, ["sky", "cloud", "clouds", "thunder"]):
		return "storm"
	if "rain" in words and _has(words, ["hearth", "fire", "coals", "reaches", "reach", "wet"]):
		return "rain"
	if _has(words, ["storm", "clouds", "thunder", "weather"]):
		return "storm"
	if _has(words, ["shelter", "cave", "ventilation", "entrance", "mouth"]) or ("where" in words and "fire" in words and _has(words, ["build", "start", "set", "put"])):
		return "shelter"
	return ""

static func _prepared_topic(clean: String, words: PackedStringArray) -> String:
	var weather := _has(words, ["storm", "rain", "wet", "weather", "night", "rest", "downpour"])
	var judge := (_has(words, ["enough", "sufficient", "prepared", "short"]) or "ready for" in clean or "need more" in clean or "low on" in clean or
		(weather and _has(words, ["last", "carry", "endure", "survive", "hold"])))
	if not judge:
		return ""
	if "ash" in words:
		return "enough_ash"
	if _subject(words, "coals") and not _has(words, ["wood", "fuel", "tinder", "kindling"]):
		return "enough_coals"
	if _has(words, ["tinder", "fibres", "fibers", "bark", "grass"]):
		return "enough_tinder"
	if _has(words, ["kindling", "twig", "twigs", "stick", "sticks", "splinter", "splinters"]) or "small wood" in clean or "small fuel" in clean:
		return "enough_small"
	if _has(words, ["large", "larger", "heavy", "logs", "log", "splits", "oak"]):
		return "enough_large"
	if _has(words, ["medium", "branch", "branches"]):
		return "enough_medium"
	if weather or _has(words, ["wood", "fuel", "supplies", "reserve", "prepared"]):
		return "prepared"
	return ""

static func _resolved(result: Dictionary, topic: String, request: String, route: String) -> Dictionary:
	result.intent = topic
	result.subject = SUBJECTS.get(topic, "")
	result.request = request
	result.route = route
	return result

static func _normalize(question: String) -> String:
	var words := question.left(120).to_lower().replace("’", "'")
	words = words.replace("can't", "cannot").replace("won't", "will not").replace("n't", " not")
	return Neural.separator.sub(words, " ", true).strip_edges()

static func _request(clean: String, neural: String) -> String:
	for request: String in request_patterns:
		if request_patterns[request].search(clean) != null:
			return request
	if neural == "better":
		return "assessment"
	if neural == "repeat":
		return "recall"
	return "explanation"

static func _explicit_topic(clean: String, words: PackedStringArray, request: String, outside: bool) -> String:
	var addressed := _has(words, ["you", "your", "yours"])
	var mobility := _has(words, ["walk", "stand", "standing", "seated"]) or " get up" in clean
	if addressed and (_subject(words, "injury") or mobility and not ("walk me through" in clean or "walk us through" in clean)):
		return "injury"
	if outside:
		return ""
	if request == "recall":
		return "repeat"
	if request == "history" and addressed:
		if _has(words, ["taught", "teacher", "showed", "learn", "learned", "experience"]):
			return "experience"
		if _has(words, ["name", "age", "old", "childhood"]):
			return "identity"

	var fire_named := _has(words, FIRE_WORDS)
	var coals := _subject(words, "coals")
	if request == "duration" and (coals or "glow" in words):
		return "coals"
	if coals and request in ["clarification", "reassurance"]:
		return "coals"
	if request == "reassurance" and (_has(words, ["fail", "manage", "tending", "apprentice"]) or fire_named):
		return "apprentice"
	if request == "consequence" and (fire_named or coals) and _has(words, ["out", "lose", "left", "die", "dies", "cold", "gone"]):
		return "revive"
	var duty := _has(words, ["band", "duty", "depend", "inherited", "responsibility"])
	var tending_for_us := request == "cause" and "we" in words and _has(words, ["keep", "tend", "preserve"])
	if fire_named and (duty or tending_for_us):
		return "heritage"
	if request in ["advice", "demonstration"] and addressed:
		var teaching := clean.ends_with("teach me") or "teach me how" in clean or "help me learn" in clean or "walk me through" in clean
		if teaching and (clean.ends_with("teach me") or fire_named or _has(words, ["tend", "tending", "work", "apprentice"])):
			return "apprentice"
	if request == "next_step":
		return "next"
	if _subject(words, "smoke"):
		return "smoke"
	if _subject(words, "air") and not _has(words, ["room", "space", "packed", "gap", "between"]):
		return "air"
	if (fire_named or coals) and _has(words, ["relight", "rekindle", "revive"]) and request == "advice":
		return "revive"
	if fire_named and "wake" in words and request == "advice":
		return "revive"
	if _has(words, ["bank", "banking"]) or coals and _has(words, ["overnight", "dawn", "morning", "sleep", "cover"]):
		return "bank"
	if coals and request == "advice" and _has(words, ["alive", "burning", "glowing"]):
		return "coals"
	if request == "demonstration" and "where" in words and _has(words, ["wood", "stick", "log", "bark", "fuel"]):
		return "place"
	if _has(words, ["tend", "tending"]) and request == "assessment" and not addressed:
		return "growth"
	if request == "advice" and ((fire_named and _has(words, ["keep", "keeping", "stop", "sure", "alive"])) or \
		("it" in words and _has(words, ["burning", "die", "dying", "alive"]))):
		return "growth"
	if coals and (words.size() == 1 or request == "explanation" and clean.begins_with("and ")):
		return "coals"
	return ""

static func _broad_fire_question(clean: String, words: PackedStringArray) -> bool:
	return words.size() == 1 or clean.begins_with("what about ") or _has(words, ["tend", "tending",
		"keep", "keeping", "alive", "burning", "grow", "going", "hold", "fading", "fade", "dying", "die",
		"warm", "stronger", "weaker", "help", "doing", "wrong", "trouble", "catch", "save"])

static func _is_practical(topic: String) -> bool:
	return Advice.PROMPTS.has(topic) or topic in ["next", "apprentice", "combustion"]

static func _has(words: PackedStringArray, choices: Array) -> bool:
	for word: String in choices:
		if word in words:
			return true
	return false

static func _subject(words: PackedStringArray, subject: String) -> bool:
	var aliases: Array = SUBJECT_WORDS[subject]
	if _has(words, aliases):
		return true
	for alias: String in aliases:
		if alias not in SPELLING:
			continue
		for word in words:
			if word.length() >= 3 and _one_edit(word, alias):
				return true
	return false

static func _one_edit(word: String, alias: String) -> bool:
	if absi(word.length() - alias.length()) > 1:
		return false
	var shorter := word if word.length() <= alias.length() else alias
	var longer := alias if shorter == word else word
	for i in range(shorter.length()):
		if shorter[i] == longer[i]:
			continue
		if shorter.length() < longer.length():
			return alias.length() >= 4 and shorter.substr(i) == longer.substr(i + 1)
		return (alias.length() >= 4 and shorter.substr(i + 1) == longer.substr(i + 1)) or \
			(i + 1 < shorter.length() and shorter[i] == longer[i + 1] and shorter[i + 1] == longer[i] and shorter.substr(i + 2) == longer.substr(i + 2))
	return true
