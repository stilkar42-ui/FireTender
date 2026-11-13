extends RefCounted
## Authored consultation. A fresh reading is taken at submission, independent
## of the mentor's reactive observations and apprenticeship progress.

const Fire := preload("res://sim/fire.gd")
const Heat := preload("res://sim/felt_heat.gd")
const Touch := preload("res://sim/felt_touch.gd")
const PROMPTS := {
	"growth": "Why will the fire not grow?",
	"flame": "Why is the flame so weak?",
	"coals": "Are the coals still strong?",
	"load": "Have I laid on too much wood?",
	"air": "Does it need a breath?",
	"crowd": "Is the wood too crowded?",
	"smoke": "Why is it smoking?",
	"wet": "Is this wood too wet?",
	"ember": "Can this ember wake a flame?",
	"heat": "Where is the strongest heat?",
	"shape": "How should the wood rest?",
	"fuel": "What should I feed it?",
	"bank": "Should I bank the fire now?",
	"revive": "Can I bring the flame back?",
	"place": "Where should I place this?",
	"feed": "How can I feed the inner fire?",
	"carry": "How do I move this ember?",
}
const FALLBACK := "Ask me about the flame, the coals, the wood, or the breath of the fire."
const PRACTICE_PROMPTS := ["air", "shape", "coals", "bank", "ember"]

class Reading:
	var flame := 0.0
	var smoke := 0.0
	var steam := 0.0
	var wet := false
	var packed := false
	var tight_tinder := false
	var overloaded := false
	var gust := false
	var banked := false
	var red_mass := 0.0
	var living_coal := false
	var smoldering := false
	var hot_remains := false
	var scattered := false
	var hottest_coal: Fire.Piece
	var unstable := false
	var faint := false
	var opening := false
	var nest_away := false
	var cooling_bed := false

static func classify(question: String) -> String:
	return preload("res://sim/speaker_neural.gd").infer(question).intent

static func suggestions(fire: Fire, hand: Vector3, selected: Fire.Piece, practice: int) -> Array[String]:
	var cue := _read(fire, hand, selected)
	var ordered: Array[String] = []
	if cue.banked:
		ordered.append("revive")
	elif cue.steam > 0.00045 or cue.wet:
		ordered.append("wet")
	if cue.tight_tinder or cue.packed:
		ordered.append("crowd")
	elif cue.overloaded:
		ordered.append("load")
	if cue.smoke > 0.0012:
		ordered.append("smoke")
	var lone_ember := fire.coals.size() == 1 and cue.flame < 3.0
	if lone_ember:
		ordered.push_front("ember")
	if cue.opening:
		ordered.push_front("feed")
	if cue.nest_away:
		ordered.push_front("carry")
	if practice >= 0 and practice < PRACTICE_PROMPTS.size():
		var lesson: String = PRACTICE_PROMPTS[practice]
		if lesson not in ordered:
			ordered.insert(mini(1, ordered.size()), lesson)
	if lone_ember:
		ordered.append_array(["place", "air"])
	elif cue.red_mass <= 0.002 and cue.flame < 2.0:
		ordered.append("revive")
	elif cue.flame < 3.0:
		ordered.append("coals")
		if cue.red_mass > 0.045 and fire.ash > 0.004:
			ordered.append("bank")
	elif cue.flame < 12.0:
		ordered.append("flame")
	if cue.unstable:
		ordered.append("shape")
	ordered.append_array(["fuel", "heat", "growth"])
	var unique: Array[String] = []
	for topic in ordered:
		if topic not in unique:
			unique.append(topic)
		if unique.size() == 3:
			break
	return unique

static func answer(fire: Fire, topic: String, hand: Vector3, selected: Fire.Piece, yaw: float, cue: Reading = null) -> String:
	if not PROMPTS.has(topic):
		return FALLBACK
	if cue == null:
		cue = _read(fire, hand, selected)
	match topic:
		"growth", "flame", "load":
			return _growth(cue)
		"coals", "ember", "revive":
			return _revive(cue, topic)
		"air", "crowd":
			if cue.gust:
				return "That hard breath carries heat away. Shelter the glow and let the air come softly."
			if cue.tight_tinder or cue.packed:
				return _open_space(cue)
			if cue.faint:
				return "See the red? It still eats the air. Give it a gentle breath, then let it rest. Keep dry fibres close."
			if cue.red_mass < 0.002 and cue.flame < 2.0:
				if cue.living_coal or cue.smoldering or cue.hot_remains:
					return _revive(cue, topic)
				return "I see no living glow. A breath can help a coal, but it cannot wake cold ash."
			return "There is room for breath here. A soft breath may help the glow. Let it rest if the red fades."
		"smoke":
			if cue.steam > 0.00045 and cue.wet:
				return "Some of that pale trail is water from the wood. Set the damp piece in the warmth at the edge."
			if cue.packed:
				return _open_space(cue)
			if cue.smoke > 0.0006:
				if cue.flame > 6.0:
					return "The flame is holding, but some wood still smokes. Wait for the new piece to catch before feeding it again."
				return "The wood is darkening before it has caught. Give the small dry fuel a place against the heat."
			return "I see little smoke now. Watch for a pale hiss from wet wood or smoke caught between close pieces."
		"wet":
			if selected in fire.wood and selected.water / selected.original <= 0.24:
				return "That piece seems dry enough. If it will not catch, bring a thin edge nearer the warmth."
			if cue.wet or cue.steam > 0.00045:
				return "The wood gives water before flame. Let it dry at the edge, and feed the glow with something dry."
			return "I see little sign of wet wood here. Listen for a hiss when a fresh piece warms."
		"heat", "place":
			var hottest := _hot_spot(fire)
			if hottest.w < Heat.BANDS[0]:
				return "I feel no strong place in this bed. Look for living red before adding wood."
			var side := Vector2(hottest.x, hottest.z).rotated(yaw)
			var where := _where(side)
			if topic == "place":
				if Heat.sample(fire, hand) >= hottest.w * 0.68:
					return "There is warmth where your hand is. Set a dry tip near it, with a little space underneath."
				return "Try " + where + ", near the stronger warmth. Let a dry tip meet it and leave a way for air."
			return "The strongest warmth I can feel is " + where + ". Look for the glow and flame there."
		"shape":
			if cue.unstable:
				return "That blackened wood is giving way. Let it settle before you rest another branch across it."
			return "Give each piece a firm rest. You can cross two supports or lean a tip in, if breath can still pass beneath."
		"fuel":
			if cue.opening:
				return "The heart is beneath the heavy wood. Feed a small dry stick through the opening, with its tip toward the glow."
			if cue.flame > 22.0:
				return "The flame can take one dry branch. Lay a tip near the heat and wait for it to catch."
			if cue.flame > 3.0:
				return "Try a dry splinter or a finger stick where its tip can meet the flame. Add larger wood once it holds."
			return _revive(cue, "ember")
		"feed":
			if cue.opening:
				return "The heart is beneath the heavy wood. Feed a small dry stick through the opening, with its tip toward the glow."
			return "I see little room beneath this wood. Try a thinner stick or make an open side before pushing it in."
		"carry":
			if cue.red_mass > 0.002:
				return "Lift the coal gently into loose dry fibres. Keep the red close to them, but leave room for breath."
			return _revive(cue, "ember")
		"bank":
			if cue.flame > 6.0:
				return "Let the flames settle first. When you have a bed of red coals, sift a little ash over it."
			if cue.banked:
				return "The coals are already resting under ash. Brush it back when you want the glow again."
			if cue.red_mass > 0.045 and fire.ash > 0.004:
				return "There is red enough to keep. Gather the coals and sift loose ash over them until you need the fire."
			return "I would wait for a stronger bed and enough loose ash. A little red on its own is easy to lose."
	return FALLBACK

static func _growth(cue: Reading) -> String:
	var more := ""
	if cue.wet and cue.steam > 0.00035 and (cue.overloaded or cue.packed or cue.tight_tinder):
		more = " The damp wood can dry at the edge."
	match _growth_focus(cue):
		"load":
			if cue.packed or cue.tight_tinder:
				more = " Leave room for breath too."
			return "You have laid cold wood over too little heat. Lift some away and wake the smaller wood first." + more
		"gap":
			return _open_space(cue) + more
		"dry":
			return "The wood gives water before flame. Set the damp pieces at the edge and feed the warmth with something dry."
		"feed":
			return "The flame is holding. Give the next dry piece time to catch before you add another."
	return _revive(cue, "revive")

static func _growth_focus(cue: Reading) -> String:
	if cue.overloaded:
		return "load"
	if cue.packed or cue.tight_tinder:
		return "gap"
	if cue.wet and cue.steam > 0.00035:
		return "dry"
	if cue.flame > 18.0:
		return "feed"
	return "revive"

static func guidance(cue: Reading, topic: String) -> String:
	if topic in ["growth", "flame", "load", "next", "apprentice"]:
		topic = _growth_focus(cue)
	if topic in ["air", "crowd"]:
		if cue.gust:
			return "shelter"
		if cue.packed or cue.tight_tinder:
			return "gap"
		return "cold" if cue.red_mass < 0.002 and cue.flame < 0.2 and not (cue.living_coal or cue.smoldering) else "breath"
	if topic in ["smoke", "wet"] and cue.wet:
		return "dry"
	if topic in ["revive", "ember", "coals", "fuel"]:
		if cue.banked:
			return "expose"
		if cue.flame >= 2.0:
			return "feed"
		if cue.red_mass < 0.002 and not (cue.living_coal or cue.smoldering):
			return "cold"
		if cue.faint:
			return "breath"
		if cue.scattered:
			return "gather"
		return "tinder"
	return topic

static func coal_duration(cue: Reading) -> String:
	if cue.banked:
		return "There is warmth under the ash. The cover helps it keep, but check for red before you rely on it."
	if cue.red_mass < 0.002:
		if cue.living_coal or cue.smoldering or cue.hot_remains:
			return _revive(cue, "coals")
		return "I see no living glow in these coals. Look under the ash once before you count on them."
	if cue.red_mass < 0.045 or cue.cooling_bed:
		return "There is little red to spare. It may fade soon in the open. Give it something small and dry while it still glows."
	return "There is a bed of red here with warmth to spare. Watch the edges for fading before you leave it to rest."

static func if_fire_fails(cue: Reading) -> String:
	if cue.banked:
		return "Even if the flame is gone, the ash can hide living coals. Brush back a little cover and try dry bark against the red."
	if cue.red_mass < 0.002 and cue.flame < 0.2:
		if cue.living_coal or cue.smoldering or cue.hot_remains:
			return _revive(cue, "revive")
		return "When the bed has gone cold like this, a breath will not wake it. If you find no red under the ash, bring a fresh coal."
	return "If the flame goes out, look for red in the bed. Offer dry bark to any living glow. If the ash is cold, we will need a fresh coal."

const FOLLOW_UPS := {
	"load": {
		"cause": "Cold wood takes warmth from the little fire as it heats. With less weighing on it, the small fuel has a chance to catch.",
		"consequence": "If the cold wood stays over such a little glow, it may take what warmth is left and the red can fade.",
		"demonstration": "Look at the wood above the glow. Lift one heavy piece aside and watch the small fuel underneath.",
	},
	"gap": {
		"cause": "The glow needs air between the pieces. Close-packed wood can hold smoke where the flame ought to rise.",
		"consequence": "If the spaces stay closed, the wood may keep smoking while the little flame fades.",
		"demonstration": "Look under the sticks. Move one aside until you can see a little space leading to the glow.",
	},
	"dry": {
		"cause": "Damp wood spends the fire's warmth giving up water. A dry tip can catch while the wet piece dries at the edge.",
		"consequence": "If the damp wood stays over the glow, it can take more warmth than the little fire can spare.",
		"demonstration": "Move the hissing wood to the warm edge. Put a dry tip near the living warmth and watch it catch.",
	},
	"expose": {
		"cause": "The ash keeps warmth in, but it also keeps air away from the red. Brush back a little when you want the glow to wake.",
		"consequence": "Coals can rest under ash, but even sheltered red fades in time. Check for warmth before you count on it.",
		"demonstration": "Brush back a little ash. Look for red as it takes the air, then bring dry bark close.",
	},
	"tinder": {
		"cause": "A thin dry fibre needs little warmth before it catches. A branch would take too much from a small coal.",
		"consequence": "A little glow can fade before bigger wood catches. Watch it closely if you wait.",
		"demonstration": "Find the red glow. Tuck a few dry fibres beside it and leave space for air to pass through them.",
	},
	"breath": {
		"cause": "A soft breath brings air to the red. A hard gust can carry away the warmth we are trying to keep.",
		"consequence": "A faint glow can fade without air. Watch the red and give it a gentle breath if it dims.",
		"demonstration": "Aim a soft breath at the red. Stop for a moment and see whether the glow brightens.",
	},
	"feed": {
		"cause": "Each fresh piece takes warmth before it gives any back. Let one catch before asking the fire to warm another.",
		"consequence": "If you wait too long, the flame can spend the small wood. If you pile on fuel now, it may cool instead.",
		"demonstration": "Lay one dry tip near the flame. Watch for it to catch before putting another piece on.",
	},
	"cold": {
		"cause": "A breath helps living red. Ash with no heat left cannot kindle fresh wood.",
		"consequence": "If there is no red under the ash, waiting will leave the bed cold. We will need a fresh coal.",
		"demonstration": "Look once beneath the ash. If you find no living red, bring a fresh coal before laying fuel.",
	},
	"gather": {
		"cause": "Scattered coals lose their warmth separately. Together their glow can kindle a little bark.",
		"consequence": "Left far apart, those patches can fade before any of them lights the bark.",
		"demonstration": "Draw the glowing patches together, then lay a dry edge close to the red.",
	},
}

static func _open_space(cue: Reading) -> String:
	if cue.tight_tinder:
		return "The fibres lie too close. Keep them near the glow, but open a little room for breath."
	return "The fire has wood, but it cannot breathe well. Open space beneath and between the sticks."

static func _revive(cue: Reading, topic: String) -> String:
	if cue.banked:
		return "There is warmth beneath the ash. Brush it back, then offer a little dry bark where the red shows."
	if cue.red_mass < 0.002:
		if cue.flame >= 0.2:
			return "There is flame in the wood. Tend that first while it makes a new bed below."
		if cue.smoldering:
			return "The flame has gone. The fibres still smolder. Keep them close with room for a gentle breath."
		if cue.living_coal:
			return "The flame has gone. A little life remains in the charcoal. Check beneath the ash and offer dry fibres to the red."
		if cue.hot_remains:
			return "The flame is out. The bed still holds enough heat to burn your hand. Look for living red before adding wood."
		return "I see no living red. Look beneath the ash once. If it is cold there too, we will need a fresh coal."
	if cue.faint:
		return "There is still red in that coal. A gentle breath may brighten it. Keep it sheltered and offer a little dry fibre."
	if cue.scattered and cue.flame < 5.0:
		return "The red lies far apart. Draw some coals together and lay a little dry bark against their warmth."
	if cue.red_mass < 0.045 or topic == "ember":
		return "There is still a little life in the glow. Put a few dry fibres close, with room for a gentle breath."
	return "The heart below still lives. Feed the red coals with a little dry kindling and wait for it to catch."

static func _read(fire: Fire, hand: Vector3, selected: Fire.Piece) -> Reading:
	var cue := Reading.new()
	cue.flame = fire.total_flame()
	var red: Array[Fire.Piece] = []
	for coal in fire.coals:
		cue.living_coal = cue.living_coal or coal.living_coal()
		cue.hot_remains = cue.hot_remains or (coal.char_mass + coal.mineral + coal.cover > 0.0003 and
			Touch.coal_surface_temperature(coal, fire.ambient()) >= Touch.HOT_TOUCH)
		cue.banked = cue.banked or (coal.cover > 0.006 and coal.temperature > 330.0 and coal.char_mass > 0.007)
		cue.gust = cue.gust or (coal.pulse > 1.0 and coal.breath_balance < -0.25)
		cue.cooling_bed = cue.cooling_bed or (coal.temperature > 180.0 and coal.trend < -3.0)
		if coal.temperature > 370.0 and coal.char_mass > 0.002 and coal.cover < 0.009:
			cue.red_mass += coal.char_mass
			red.append(coal)
			if cue.hottest_coal == null or coal.glow() > cue.hottest_coal.glow():
				cue.hottest_coal = coal
	if red.size() > 1:
		cue.scattered = red.all(func(coal): return coal == cue.hottest_coal or coal.at.distance_to(cue.hottest_coal.at) > 0.31)
	var cold_load := 0.0
	var distant_fibres := 0
	var spot := Vector2(hand.x, hand.z) if cue.hottest_coal == null else cue.hottest_coal.at
	for piece in fire.wood:
		cue.smoldering = cue.smoldering or piece.smolder > 0.03
		cue.hot_remains = cue.hot_remains or piece.temperature >= Touch.HOT_TOUCH or piece.sections.any(
			func(section: Fire.Piece): return section.faces.any(func(face: Fire.Piece): return face.temperature >= Touch.HOT_TOUCH))
		var moisture := piece.water / piece.original
		cue.steam += piece.vapor
		cue.smoke += piece.smoke
		cue.wet = cue.wet or moisture > 0.24
		if cue.hottest_coal != null and piece.fibre and moisture < 0.15 and piece.at.distance_to(cue.hottest_coal.at) > 0.18:
			distant_fibres += 1
		cue.packed = cue.packed or (piece.oxygen < 0.38 and (piece.smoke > 0.00013 or piece.temperature > 210.0))
		cue.tight_tinder = cue.tight_tinder or (piece.fibre and piece.oxygen < 0.48 and piece.pore_density > 0.65)
		cue.unstable = cue.unstable or (piece == selected and (piece.airborne or not piece.can_support or
			piece.sections.any(func(region): return region.integrity < 0.21 or region.crushed)))
		if piece.original >= 0.115 and piece.temperature < 200.0 and piece.pose != null:
			var nearest := piece.pose.point(clampf((spot - piece.at).dot(piece.axis), -piece.pose.span, piece.pose.span))
			if spot.distance_to(Vector2(nearest.x, nearest.y)) < 0.22 and nearest.z < 0.30:
				cold_load += piece.mass()
	cue.overloaded = cue.flame < 7.0 and (cue.red_mass > 0.002 or cue.cooling_bed) and cold_load > maxf(0.13, cue.red_mass * 3.0)
	if cue.hottest_coal != null:
		cue.faint = cue.hottest_coal.temperature < 560.0 and cue.red_mass < 0.045
		cue.opening = Fire.Feeding.opening(fire, cue.hottest_coal.at)
		cue.nest_away = distant_fibres >= 3 and cue.flame < 3.0
	return cue

static func _hot_spot(fire: Fire) -> Vector4:
	var best := Vector4.ZERO
	var candidates: Array[Vector3] = []
	for source in fire.thermal_sources():
		var power := fire.radiant_power(source)
		if power >= 0.013:
			candidates.append(Vector3(source.at.x, power, source.at.y))
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	var tested: Array[Vector3] = []
	for source in candidates:
		var point := Heat.ground(Vector2(source.x, source.z))
		if tested.any(func(previous): return point.distance_squared_to(previous) < 0.0256):
			continue
		tested.append(point)
		var warmth := Heat.sample(fire, point)
		if warmth > best.w:
			best = Vector4(point.x, point.y, point.z, warmth)
		if tested.size() == 8:
			break
	return best

static func _where(at: Vector2) -> String:
	if absf(at.x) > absf(at.y) * 0.85 and absf(at.x) > 0.20:
		return "on the left" if at.x < 0.0 else "on the right"
	if absf(at.y) > 0.22:
		return "on the far side" if at.y < 0.0 else "on the near side"
	return "near the middle"
