extends RefCounted
## Authored reactions to visible behavior. Internal readings only classify cues
## such as a visible flame, steam, a newly exposed red patch or a settling log.

const Fire := preload("res://sim/fire.gd")
const Advice := preload("res://sim/speaker_advice.gd")
const Conversation := preload("res://sim/speaker_conversation.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const TITLES := ["Give the fire its breath", "Make the heat travel", "Understand the coals", "Let the fire rest", "Build from one ember"]
const TASKS := [
	"Give small fuel room and keep a clean flame.",
	"Bring heat to a fresh part of a log.",
	"Recover flame from a glowing bed.",
	"Keep coals under ash, then bring back flame.",
	"Carry a single glow into flame and grow a living bed beneath larger fuel.",
]
const LINES := {
	"welcome": ["My leg will not carry me to the hearth now. Your mother’s kin will need warmth tonight. Come watch the fire with me."],
	"breath_lesson": ["See how the flame holds between the pieces? Keep that space. Now see what the heat does when it reaches only one end of a log."],
	"travel_lesson": ["You brought the heat where it was needed. Let the flames fall for a while. Watch the coals. They can give you another flame."],
	"coal_lesson": ["You found the fire under the dark. Now give it a rest. Cover the coals lightly, wait, then see what they can light."],
	"rest_lesson": ["You kept it while it rested. When you are ready, I will leave you one coal and see what you can build from it."],
	"ember_welcome": ["There is our coal. Lay a little dry fibre against its glow, with room for air. Let the small fuel show you when it is ready for more."],
	"ember_heavy": ["That cold branch drew heat out of the little coal. Try something thin enough to warm in your hand."],
	"ember_tinder": ["You saw the small fuel catch. Set a thin stick where its tip can meet the flame, with room for the heat to rise."],
	"ember_nest": ["One little coal can wake many fibers. Keep them close, but leave room for breath."],
	"ember_channel": ["There is fresh red in the bed, and the larger wood has caught. You have taken one coal and given us a fire."],
	"ember_air": ["See the flame climb through that opening? Keep the space underneath when you lay on the next piece."],
	"burned_end": ["The fire has eaten through that end. The other end is still sound. Watch what rests above it."],
	"char_drop": ["Look beneath the branch. The wood has become coal, and the coal still holds its heat."],
	"rested": ["The ash still gives off warmth. Brush it back when you are ready and see what the bed has kept."],
	"packed": [
		"Look where the smoke is caught. The little wood may have enough heat and too little room to breathe.",
		"That smoke is having trouble getting past the oak. Try making a gap beside the small pieces.",
	],
	"wet": [
		"Hear that hiss? Water is taking the heat. Give the wet wood time at the edge while the middle stays alive.",
		"See the pale vapor? I would leave that piece in the warmth a while before asking it to burn.",
	],
	"uneven": [
		"One end has caught. See how the far end is still pale? Let the heat work its way along.",
		"Look along the oak. The flame is holding to one end. You can bring the other end closer when the bed is ready.",
	],
	"coals": [
		"Good. I can see the red in one place now. A small piece laid against it has a better chance.",
		"Those coals were fading apart. Together they may have enough warmth for a little bark.",
	],
	"gentle": [
		"See the red come up where you breathed? Give it a moment. Then try another breath like that.",
		"The coals brightened under your breath. Wait until you can see what the tinder does.",
	],
	"gust": [
		"That gust lifted the ash, and the red is duller now. Wait a little before you blow again.",
		"The ash scattered, but the glow faded with it. The bed may need less breath than you think.",
	],
	"settle": [
		"Did you see the wood drop? Its rest gave way. There may be less room underneath it now.",
		"The pieces have settled against each other. Look for a gap before you add anything more.",
	],
	"dark": [
		"The bed is dark and I feel no warmth. If you find no red under the ash, we will need to bring fire back from elsewhere.",
		"I would look once beneath the ash. If the warmth has gone, there is nothing here for a breath to wake.",
	],
}

class Cues:
	var flame := 0.0
	var flame_from_fresh_tinder := false
	var wet := false
	var packed := false
	var uneven := false
	var heat_travel := false
	var red := false
	var banked := false
	var cover := false
	var gentle := false
	var gust := false
	var settled := false
	var coal_cluster := false
	var dark := false
	var small_flame := false
	var larger_flame := false
	var red_mass := 0.0
	var crowded_ember := false
	var loose_nest := false
	var burned_end := false
	var open_flame := false

var lesson := 0
var training := false
var ember_training := false
var history: Array[String] = []
var history_version := 0
var text := ""
var wall := 0.0
var expires := 0.0
var last_spoke := -100.0
var active_priority := 0
var used := {}
var said_at := {}
var active := {}
var pending := ""
var priority := 0
var queued_at := 0.0
var sampled := -INF
var last_tending := -INF
var last_rake := -INF
var engaged := false
var beginning_tinder := {}
var beginning_oak := {}
var heights := {}
var bank_held := 0.0
var bank_kept := false
var saw_coals := false
var clean_time := 0.0
var sustained_time := 0.0
var conversation := Conversation.new()

func enter(fire: Fire, practice: bool, retry := -1) -> void:
	conversation.chapter = null
	conversation.reset_hearth()
	training = practice
	ember_training = practice and retry == 4
	if training and retry < 0:
		lesson = 0
		history.clear()
		history_version += 1
		used.clear()
		said_at.clear()
	elif training:
		lesson = retry
	text = ""
	pending = ""
	priority = 0
	last_spoke = -100.0
	sampled = -INF
	last_tending = -INF
	last_rake = -INF
	active.clear()
	heights.clear()
	_prepare_lesson(fire)
	if practice and retry < 0:
		_say("welcome", 90)
	elif ember_training and not used.has("ember_welcome"):
		_say("ember_welcome", 90)

func _prepare_lesson(fire: Fire) -> void:
	engaged = false
	saw_coals = false
	clean_time = 0.0
	sustained_time = 0.0
	bank_held = 0.0
	bank_kept = false
	beginning_tinder.clear()
	beginning_oak.clear()
	for piece in fire.wood:
		if piece.core == null and piece.flame > 2.0:
			beginning_tinder[piece.id] = true
		if piece.core != null:
			beginning_oak[piece.id] = Vector3(piece.sections.front().water, piece.sections.back().water, piece.flame)

func tend(verb: String, fire: Fire) -> void:
	conversation.note_action(verb, fire.time)
	last_tending = fire.time
	engaged = true
	if verb == "rake":
		last_rake = fire.time

func observe(fire: Fire) -> void:
	if not conversation.living_available:
		return
	if fire.time - sampled < 0.5:
		return
	var elapsed := minf(0.5, fire.time - sampled)
	sampled = fire.time
	var cues := _read(fire)
	if training and lesson < TITLES.size():
		_learn(fire, cues, elapsed)
	var near_action := fire.time - last_tending < 25.0
	_edge("dark", near_action and cues.dark, 75)
	_edge("gust", near_action and cues.gust, 66)
	_edge("packed", cues.packed, 58)
	_edge("settle", cues.settled, 52)
	_edge("uneven", cues.uneven, 46)
	_edge("wet", cues.wet, 35)
	_edge("coals", fire.time - last_rake < 7.0 and cues.coal_cluster, 42)
	_edge("gentle", near_action and cues.gentle, 44)
	_edge("ember_heavy", ember_training and near_action and cues.crowded_ember, 80)
	_edge("ember_nest", ember_training and cues.loose_nest, 77)
	_edge("ember_tinder", ember_training and cues.small_flame, 73)
	_edge("ember_air", ember_training and cues.open_flame, 51)
	_edge("burned_end", cues.burned_end, 57)
	_edge("char_drop", fire.time - fire.last_char_fall < 1.0, 49)

func _read(fire: Fire) -> Cues:
	var cue := Cues.new()
	cue.flame = fire.total_flame()
	var warm := false
	var reds: Array[Vector2] = []
	for coal in fire.coals:
		var glow := coal.glow() * exp(-3.8 * coal.depth())
		if glow > 0.09:
			cue.red = true
			reds.append(coal.at)
			cue.red_mass += coal.char_mass
		warm = warm or coal.temperature > 120.0
		cue.cover = cue.cover or coal.cover > 0.006
		cue.banked = cue.banked or (coal.cover > 0.007 and coal.temperature > 330.0 and coal.char_mass > 0.012)
		cue.gentle = cue.gentle or (glow > 0.035 and coal.pulse > 0.17 and coal.breath_balance > 0.14)
		cue.gust = cue.gust or (coal.mineral > 0.001 and coal.pulse > 1.1 and coal.breath_balance < -0.45 and coal.trend < -3.0)
	if reds.size() >= 3:
		var center := Vector2.ZERO
		for point in reds:
			center += point
		center /= float(reds.size())
		var count := 0
		for point in reds:
			if center.distance_to(point) < 0.30:
				count += 1
		cue.coal_cluster = count >= 3
	var new_heights := {}
	for piece in fire.wood:
		warm = warm or piece.temperature > 130.0
		cue.loose_nest = cue.loose_nest or (piece.fibre and piece.smolder > 0.13 and
			piece.fibre_shelter > 2.0 and piece.oxygen > 0.58)
		cue.wet = cue.wet or piece.vapor > 0.0012
		cue.packed = cue.packed or (piece.smoke > 0.0010 and piece.oxygen < 0.38)
		cue.settled = cue.settled or float(heights.get(piece.id, piece.height)) - piece.height > 0.055
		new_heights[piece.id] = piece.height
		if piece.core == null:
			cue.small_flame = cue.small_flame or piece.flame > 3.0
			cue.open_flame = cue.open_flame or (piece.flame > 5.0 and piece.oxygen > 0.49 and
				piece.height - piece.radius > 0.07 and piece.pose.supports.size() >= 2)
			var clear_flame := piece.flame > 8.0 and piece.oxygen > 0.26 and piece.flame > piece.smoke * 24_500.0
			cue.flame_from_fresh_tinder = cue.flame_from_fresh_tinder or (
				clear_flame and not beginning_tinder.has(piece.id))
			continue
		var first := piece.sections[0]
		var other: Fire.Piece = piece.sections.back()
		cue.burned_end = cue.burned_end or (piece.precise and minf(first.integrity, other.integrity) < 0.34 and
			maxf(first.integrity, other.integrity) > 0.65)
		cue.larger_flame = cue.larger_flame or (piece.original >= 0.13 and piece.flame > 6.0)
		if fire.coals.size() == 1 and cue.flame < 1.0 and piece.at.distance_to(fire.coals[0].at) < 0.24:
			cue.crowded_ember = cue.crowded_ember or fire.coals[0].trend < -7.0
		var hotter := first if first.flame > other.flame else other
		var cooler := other if hotter == first else first
		cue.uneven = cue.uneven or (hotter.flame > 4.5 and cooler.flame < hotter.flame * 0.19 and
			cooler.faces[0].charred_wood < cooler.faces[0].original * 0.34)
		var baseline: Vector3 = beginning_oak.get(piece.id,
			Vector3(piece.original * Fire.SPECIES[piece.kind].water / piece.sections.size(),
				piece.original * Fire.SPECIES[piece.kind].water / piece.sections.size(), 0.0))
		var drying := absf(first.temperature - other.temperature) > 60.0 and (
			baseline.x - first.water > 0.012 or baseline.y - other.water > 0.012)
		cue.heat_travel = cue.heat_travel or drying or (baseline.z < 2.0 and piece.flame > 7.0)
	heights = new_heights
	cue.dark = not warm and not cue.red and cue.flame < 1.0
	return cue

func _learn(fire: Fire, cue: Cues, elapsed: float) -> void:
	if lesson == 2 and cue.flame < 1.0 and cue.red:
		saw_coals = true
	if lesson == 3 and cue.banked and cue.flame < 2.0:
		bank_held += elapsed
		if bank_held >= 45.0 and not bank_kept:
			bank_kept = true
			_offer("rested", 81)
	elif not bank_kept:
		bank_held = 0.0
	if not engaged:
		return
	match lesson:
		0:
			clean_time = clean_time + elapsed if cue.flame_from_fresh_tinder else 0.0
			if clean_time >= 1.0:
				_finish(fire, "breath_lesson")
		1:
			if cue.heat_travel:
				_finish(fire, "travel_lesson")
		2:
			if saw_coals and cue.flame > 6.0:
				_finish(fire, "coal_lesson")
		3:
			if bank_kept and not cue.cover and cue.flame > 6.0:
				_finish(fire, "rest_lesson")
		4:
			if ember_training:
				sustained_time = sustained_time + elapsed if cue.larger_flame and cue.red_mass > 0.022 else 0.0
				if sustained_time >= 4.0:
					_finish(fire, "ember_channel")

func _finish(fire: Fire, topic: String) -> void:
	lesson += 1
	_prepare_lesson(fire)
	_offer(topic, 95)

func _edge(topic: String, now: bool, weight: int) -> void:
	if now and not active.get(topic, false):
		_offer(topic, weight)
	elif not now and pending == topic and topic in ["packed", "uneven", "wet", "dark", "ember_air"]:
		pending = ""
		priority = 0
	active[topic] = now

func _offer(topic: String, weight: int) -> void:
	if wall - float(said_at.get(topic, -100.0)) < 43.0 or int(used.get(topic, 0)) >= LINES[topic].size():
		return
	if pending.is_empty() or weight > priority:
		pending = topic
		priority = weight
		queued_at = wall

func tick(delta: float) -> void:
	wall += delta
	if wall >= expires:
		text = ""
	if pending.is_empty():
		return
	if wall - queued_at > 16.0:
		pending = ""
		priority = 0
		return
	var interrupt := priority >= 90 and active_priority < 70 and wall - last_spoke >= 4.5
	if (text.is_empty() and wall - last_spoke >= 9.5) or interrupt:
		_say(pending, priority)
		pending = ""
		priority = 0

func _say(topic: String, weight: int) -> void:
	if not conversation.living_available:
		return
	var variant := int(used.get(topic, 0))
	var line: String = LINES[topic][variant]
	_remember(line)
	conversation.remember_lesson(topic, line)
	_show_line(line, weight)
	used[topic] = variant + 1
	said_at[topic] = wall

func begin_chapter(chapter: Chapter) -> void:
	enter(chapter.fire, false)
	history.clear()
	conversation.chapter = chapter
	story_line(Chapter.Kin.WELCOME, "red_hollow_return")

func story_line(line: String, teaching: String) -> void:
	_remember(line)
	conversation.remember_lesson(teaching, line)
	_show_line(line, 90)

func ask(fire: Fire, question: String, hand: Vector3, selected: Fire.Piece, yaw: float, topic := "") -> void:
	var words := question.strip_edges().left(120)
	if words.is_empty() or not conversation.living_available:
		return
	var task: String = TASKS[lesson] if training and lesson < TASKS.size() else ""
	var reply := conversation.reply(fire, words, hand, selected, yaw, topic, task)
	_remember("You asked “%s”\n%s" % [words, reply])
	_show_line(reply, 100)
	if not pending.is_empty():
		queued_at = wall

func _remember(line: String) -> void:
	history.append(line)
	if history.size() > 32:
		history.pop_front()
	history_version += 1

func _show_line(line: String, weight: int) -> void:
	if not conversation.living_available:
		return
	text = line
	last_spoke = wall
	active_priority = weight
	expires = wall + clampf(3.0 + text.length() / 16.0, 7.0, 14.0)
