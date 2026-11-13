extends RefCounted
## Evidence comes from completed player actions. Teachers can revisit any
## lesson, and Eren only reflects on work the apprentice chooses to tell him about.

const HUNT := "Hunter’s Working Place"
const COOK := "Cooking Place"
const MAKE := "Maker’s Stone"
const TEACHERS := {HUNT: "bera", COOK: "nara", MAKE: "ina"}
const QUESTIONS := {
	"review_hunt": "Tell Eren about working the kill",
	"review_cook": "Tell Eren about the roast",
	"review_make": "Tell Eren about the haft",
}
const REVIEW_AREAS := {"review_hunt": HUNT, "review_cook": COOK, "review_make": MAKE}
const GREETINGS := {
	HUNT: "Come here, child. See what this animal gives us. Look closely at the cut. Use the sharp flake on the flesh, then save the bones and hide.",
	COOK: "Come sit by me. Bring a cut from your father’s board. Make a small portion, and put it where the red can warm it through.",
	MAKE: "Come, kin. Ivo’s point is loose. Scrape a sticky knot and catch the resin in a stone cup. We’ll warm it slowly and bind him a sound haft.",
}
var seen: Dictionary = {}
var evidence: Dictionary = {}
var reactions: Dictionary = {}
var revision := 0

func note(area: String, action: String, description: String, reaction := "") -> void:
	if not evidence.has(area):
		evidence[area] = {}
	var steps: Dictionary = evidence[area]
	var prior: Dictionary = steps.get(action, {})
	steps[action] = {"count": int(prior.get("count", 0)) + 1, "detail": description}
	reactions[area] = reaction
	revision += 1

func has(area: String, action: String) -> bool:
	return evidence.get(area, {}).has(action)

func complete(area: String) -> bool:
	var required: Array = {
		HUNT: ["carve", "crack", "carry", "hide"], COOK: ["heat", "turn", "meal"],
		MAKE: ["pitch", "point", "shaft", "haft", "inspect_tool", "rack"],
	}.get(area, [])
	return not required.is_empty() and required.all(func(action): return has(area, action))

func greet(area: String, teacher: String) -> String:
	if seen.has(area):
		return guidance(area)
	seen[area] = true
	revision += 1
	if area == HUNT and teacher != "bera":
		return "Come look with me. Your father brought this in. A sharp flake frees the meat, and a clean hide can give us binding."
	return GREETINGS[area]

func guidance(area: String) -> String:
	match area:
		HUNT:
			if not has(area, "carve"):
				return "Look at the carcass with I. Take the sharp flake and touch it to the carcass, or use V while the flake is on the board."
			if not has(area, "crack"):
				return "Lay the marrow bone on the working stones. Use the hammerstone to split it, and keep the soft marrow clear of the fragments."
			if not has(area, "carry"):
				return "Carry a cut to your mother’s board. Set it down there so she can see what’s come from the hunt."
			if not has(area, "hide"):
				return "Clean the fresh hide with the scraper, then take it to the stretching stones. A clean strip will serve Ina well."
			return "You’ve left the useful cuts where we can reach them. A kill feeds more than one kind of work. Tell Eren what you took from it."
		COOK:
			if not has(area, "heat"):
				return "Use the flake to cut a small portion on my board. Lay it at the coal edge. With weak red it takes time. You can move it nearer."
			if not has(area, "turn"):
				return "Watch the face towards the heat. Turn the spit with V when that face browns. Let the pale side and the middle catch up."
			if not has(area, "meal"):
				return "Lift the portion when it is roasted through. Carry it to the covered food shelf so there’ll be something to share."
			return "There’s food on the shelf from the heat you kept. Tell Eren how you judged when to turn and when to lift it."
		MAKE:
			if not has(area, "pitch"):
				return "Scrape the knot with the flake and place its resin in the cup. Carry the cup to the warm stone. Lift it when the resin runs evenly."
			if not has(area, "point") or not has(area, "shaft"):
				return "Dress the point and smooth the shaft on my stone with V. Keep the adhesive and a binding within reach."
			if not has(area, "haft"):
				return "Lay Ivo’s spear on my stone. Fit the prepared point and shaft, then bind the haft with the resin and rawhide."
			if not has(area, "inspect_tool"):
				return "Feel the new haft with I. Try the point sideways."
			if not has(area, "rack"):
				return "Take that spear back to the hunters’ rack. Ivo can carry it when the elders call."
			return "That point holds. A good haft keeps a hunter’s hand steady. Tell Eren how you warmed the resin and fitted it."
	return ""

func reflect(area: String) -> String:
	var steps: Dictionary = evidence.get(area, {})
	if steps.is_empty():
		return "Tell me what happened when you’ve tried it. I’d like to hear what your hands found."
	var details := PackedStringArray()
	var important: Array = {HUNT: ["crack", "carry", "hide", "carve", "look"],
		COOK: ["char", "meal", "early", "turn", "heat"], MAKE: ["scorch", "pitch", "haft", "scrape", "point", "shaft"]}[area]
	for key: String in important:
		if steps.has(key) and details.size() < 3:
			details.append(steps[key].detail)
	var reply := ""
	match area:
		HUNT:
			reply = "You tell me %s. Meat, marrow and hide each ask for a different hand. What you kept will serve the family." % ", and ".join(details)
		COOK:
			var close := "You found how much warmth the middle needs. Your mother can share what you left her."
			if steps.has("char") and not steps.has("meal"):
				close = "The outside blackened before you could save it. Start farther from the red and turn it sooner."
			elif not steps.has("meal"):
				close = "Give both faces warmth before you put it aside. Your mother can show you what the pale face still needs."
			reply = "You tell me %s. %s" % [", and ".join(details), close]
		MAKE:
			var close := "Bring the cup back gently and keep smoke out of the pitch."
			if steps.has("haft"):
				close = "Pitch holds the point while the binding keeps it seated. A hunter can trust the work of your hands."
			elif steps.has("scorch"):
				close = "The resin went brittle because the red was too strong. The warm stone will give you time."
			reply = "You tell me %s. %s" % [", and ".join(details), close]
	return reply

static func review_topic(words: String) -> String:
	var line := words.to_lower()
	if not (line.begins_with("i ") or "tell eren" in line or "lesson" in line or "what i" in line):
		return ""
	if ["haft", "spear", "adhesive", "resin", "point"].any(func(word): return word in line):
		return "review_make"
	if ["roast", "charred", "cooked", "meal", "spit"].any(func(word): return word in line):
		return "review_cook"
	if ["marrow", "bone", "kill", "carcass", "hide"].any(func(word): return word in line):
		return "review_hunt"
	return ""
