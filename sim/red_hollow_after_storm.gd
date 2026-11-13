extends RefCounted
## Progress is read from fuel locations, moisture and the surviving bed.
const Fire := preload("res://sim/fire.gd")
const Shelter := preload("res://sim/red_hollow_shelter.gd")
const Quests := preload("res://sim/story_quests.gd")
const READY_MOISTURE := 0.26
const READY_CORE := 0.34
const TITLE := "After the Tears of the Sky Father"
const QUESTIONS := {
	"wood_methods": "How long does each way of drying take?",
	"wood_air": "What happens if I air-dry the logs?",
	"wood_edge": "How do I dry logs beside the fire?",
	"wood_drying": "How can I dry this wood?",
	"myth_mother": "Who is the Mother of the World?",
	"myth_twins": "Tell me about Aru and Varek.",
	"myth_thunder": "Where do lightning and thunder come from?",
	"myth_hunters": "Why did the rain bring predators?",
	"myth_fire": "Who are the Flame Children?",
	"wood_sparks": "Why does the pine spit sparks?",
	"wood_shelf": "Where should I keep the dry wood?",
}
const DRYING_LESSON := "Start on the shelf. Here, a branch takes about ten minutes and a big split twenty. Beside a steady fire they take a few minutes. The shelf is safer. Watch for scorching at the edge."
const AIR_DRYING_LESSON := "Space the wet logs on the back-left shelf. Moving air lets the water leave slowly and there’s little risk of scorch. Allow about ten minutes for a branch and twenty for a big split. Keep them away from the seep."
const EDGE_DRYING_LESSON := "Wake the fire with dry kindling. Set the wet logs just outside the ring and turn them as they warm. Give them a few minutes, then check the core. Pull them back if they darken or catch. A wet log in the bed draws heat from the coals."
const TALE := [
	"Listen to the drops. My mother called them the Sky Father’s tears. Before the hills had names, the Mother of the World walked beside him above the clouds.",
	"She bore twins. Aru came first, the Keeping Hand. Varek was the Seeking Hand. Varek could do wondrous things, but the Father scorned him and loved only Aru. Their Mother held them both close.",
	"Varek tricked Aru into trading coverings. Then he told their Mother to look down from the forbidden Chasm of the Cloud. She went to its edge, trusting the voice of her son.",
	"The Father saw her lean over the chasm. He mistook Aru for Varek and thought she meant to harm him. He cast her into the Dark Waters before either son could speak.",
	"Her body became the earth. Mountains rose where she struck, valleys opened beneath her, and rivers followed the marks of her fall. The Father saw the two coverings and knew, too late, what Varek had done.",
	"The brothers fought across the heavens. Their blows became lightning and their voices became thunder. Burning fragments broke away and fell. We call them the Flame Children of Rage.",
	"The Father wept. His tears fed roots and grass, and the animals came to feed. His grief and bitterness fell with the rain. From them, our elders say, came the cave lion, the cave hyena, and the wolf.",
	"The same tears that fed the grass put out the Flame Children. The Mother took pity and hid the living sparks inside charred wood. That is the warmth we carry from hearth to hearth.",
	"We keep one of those children here, cousin. Give a wet branch warmth enough to shed its water. Keep the dry fibres well away from where a hungry spark might land.",
]
const STAGES := ["The rain has passed", "Find shelter for the wood", "Borrow warmth", "Prepare the next fire"]
const PASSAGES_BY_STAGE := [1, 5, 8, 9]

var fire: Fire
var stage := 0
var begun: float
var passage := 0
var heard_at := -INF
var sampled_at := -INF
var settled_for := 0.0
var cold_for := 0.0
var initial_wet: Dictionary = {}
var seasoned_reserve := 0.0
var ready_reserve := 0.0
var protected_tinder := false
var hot_coals := 0.0
var hazard := false
var outcomes := ""
var drying_records: Dictionary = {}
var drying_complete: Dictionary = {}

func _init(model: Fire) -> void:
	fire = model
	begun = fire.time
	for piece in fire.all_fuel():
		track(piece)

func track(piece: Fire.Piece) -> void:
	if not initial_wet.has(piece.id) and piece.original >= 0.02 and piece.water >= piece.original * 0.34:
		initial_wet[piece.id] = piece.water
	if Quests.size_group(piece.kind) >= 2 and initial_wet.has(piece.id) and not drying_records.has(piece.id):
		drying_records[piece.id] = {"water": piece.water, "air": 0.0, "heat": 0.0, "burned": false, "credited": false}

func update() -> void:
	if fire.time - sampled_at < 0.5 or not outcomes.is_empty():
		return
	var elapsed := 0.5 if not is_finite(sampled_at) else fire.time - sampled_at
	sampled_at = fire.time
	seasoned_reserve = 0.0
	ready_reserve = 0.0
	protected_tinder = false
	hot_coals = 0.0
	hazard = false
	var wet_by_heat := false
	var measurable_loss := false
	var set_aside := false
	for coal in fire.coals:
		if coal.living_coal() and not coal.carried and fire.in_hearth(coal.at):
			hot_coals += coal.char_mass
	for piece in fire.all_fuel():
		if not drying_records.has(piece.id) and piece.water >= piece.original * 0.34:
			track(piece)
		var wet := piece.water / maxf(piece.original, 0.00001)
		var reserve := Shelter.protected_storage(piece.at)
		var live := piece.flame > 0.18 or piece.smolder > 0.05 or (piece.char_heat > 0.06 and piece.temperature > 320.0)
		hazard = hazard or (live and not fire.in_hearth(piece.at))
		_update_log(piece, live)
		if reserve and not live:
			var tinder := piece.kind in Fire.RAW_TINDER or piece.kind == Fire.TINDER_BUNDLE
			if wet < 0.23 and tinder:
				protected_tinder = protected_tinder or piece.wood >= 0.002
			if wet <= 0.36 and not tinder:
				ready_reserve += piece.wood
		if not initial_wet.has(piece.id):
			continue
		var loss := float(initial_wet[piece.id]) - piece.water
		var drying := piece.vapor > 0.000045 and piece.temperature > 38.0
		wet_by_heat = wet_by_heat or (drying and not fire.in_hearth(piece.at))
		set_aside = set_aside or (not fire.in_hearth(piece.at) and
			(piece.at.y < -1.55 or piece.at.distance_to(Vector2.ZERO) < 1.34))
		measurable_loss = measurable_loss or loss >= maxf(0.012, float(initial_wet[piece.id]) * 0.17)
		if reserve and not live and wet <= 0.36 and loss >= maxf(0.012, float(initial_wet[piece.id]) * 0.17):
			seasoned_reserve += piece.wood
	for fragment in fire.sparks:
		hazard = hazard or (fragment.receiver != null and not fire.in_hearth(fragment.receiver.at) and fragment.temperature > 250.0)
	if stage == 0 and fire.time - begun >= 2.0:
		stage = 1
	if stage == 1 and (protected_tinder or ready_reserve > 0.05) and (set_aside or wet_by_heat or measurable_loss):
		stage = 2
	if stage == 2 and measurable_loss:
		stage = 3
	var viable := hot_coals >= 0.009 or fire.total_flame() > 0.45
	cold_for = 0.0 if viable else cold_for + elapsed
	var sufficient := drying_complete.size() == Quests.DRYING_LABELS.size() and hot_coals >= 0.009
	settled_for = settled_for + elapsed if sufficient and not hazard else 0.0
	if settled_for >= 6.0:
		outcomes = "prepared"
	elif cold_for >= 25.0:
		outcomes = "lost"

func _update_log(piece: Fire.Piece, live: bool) -> void:
	if not drying_records.has(piece.id):
		return
	var record: Dictionary = drying_records[piece.id]
	var loss: float = record.water - piece.water
	record.water = piece.water
	record.burned = record.burned or live or piece.charred_wood > piece.original * 0.01
	if record.burned or record.credited:
		return
	if loss < 0.0:
		var retained := maxf(0.0, 1.0 + loss / maxf(0.00001, record.air + record.heat))
		record.air *= retained
		record.heat *= retained
	elif not piece.airborne and not fire.in_hearth(piece.at):
		if Shelter.DRY_SHELF.has_point(piece.at) and piece.temperature < 32.0:
			record.air += loss
		elif Shelter.warming_edge(piece.at) and piece.temperature >= fire.shelter.air_temperature(piece.at) + 8.0:
			record.heat += loss
	else:
		return
	if piece.airborne or not (Shelter.DRY_SHELF.has_point(piece.at) or Shelter.warming_edge(piece.at)):
		return
	var group := Quests.size_group(piece.kind)
	var method := "air" if record.air > record.heat else "heat"
	var goal := method + ("_medium" if group == 2 else "_large")
	var initial: float = initial_wet[piece.id]
	var total_loss := initial - piece.water
	if not drying_complete.has(goal) and total_loss >= maxf(0.012, initial * 0.17) \
		and piece.wood >= piece.original * 0.98 and record[method] >= total_loss * 0.65 and dry_through(piece):
		record.credited = true
		drying_complete[goal] = piece.id

func drying_detail(piece: Fire.Piece) -> String:
	if piece == null or not drying_records.has(piece.id):
		return ""
	var record: Dictionary = drying_records[piece.id]
	if record.credited:
		return "Drying goal recorded"
	if record.burned or piece.flame > 0.18:
		return "Scorched · use another wet log for the quest"
	if fire.in_hearth(piece.at):
		return "Inside the fire ring · move the log outside"
	if Shelter.DRY_SHELF.has_point(piece.at):
		return "Air drying · %s" % moisture_words(piece)
	if Shelter.warming_edge(piece.at):
		return ("Warming edge" if record.heat > 0.001 else "Waiting for warmth") + " · " + moisture_words(piece)
	return ""

static func moisture_words(piece: Fire.Piece) -> String:
	var core_wet := 0.0
	for section in piece.sections:
		core_wet = maxf(core_wet, section.core.water / section.core.original)
	return "%d%% moisture · %d%% at the core" % [roundi(piece.water / piece.original * 100.0), roundi(core_wet * 100.0)]

static func dry_through(piece: Fire.Piece) -> bool:
	if piece.water > piece.original * READY_MOISTURE:
		return false
	for section in piece.sections:
		if section.core.water > section.core.original * READY_CORE:
			return false
	return true

func next_passage() -> String:
	if passage >= PASSAGES_BY_STAGE[stage] or fire.time - heard_at < 3.0:
		return ""
	var line: String = TALE[passage]
	passage += 1
	heard_at = fire.time
	return line

func objective() -> String:
	if outcomes == "prepared":
		return "Chapter II complete · Four dry logs and living coals."
	if outcomes == "lost":
		return "The living heat is gone. F7 opens the practice start."
	if hazard:
		return "Tend the sparks or burning fuel outside the hearth."
	if drying_complete.size() == Quests.DRYING_LABELS.size():
		return "All four logs are dry. Keep a bed of living coals."
	return "Dry four wet logs. Quests [O] · %d / %d" % [drying_complete.size(), Quests.DRYING_LABELS.size()]

func guidance() -> String:
	if outcomes == "prepared":
		return "There is dry wood waiting and red beneath the ash. The fire has served us well. Leave it room to breathe through the next dark."
	if outcomes == "lost":
		return "Cold ash cannot wake the wood. Keep some dry fuel beside you while the next bed is still alive."
	if hazard:
		return "Look outside the ring. The fire has found fuel there. Move the dry fibres clear and tend the live piece before it reaches the pile."
	match stage:
		0: return TALE[0]
		1: return "Space one wet medium log and one wet large log on the back-left shelf. They dry slowly there. Start them first while you wake the coals with dry twigs."
		2:
			if fire.total_flame() < 0.60 and hot_coals >= 0.009:
				return "Brush back the ash. Draw the living coals together and give them a few dry twigs. Bring the wet wood close once the flame holds."
			return drying_advice(null)
	return "Give the warming logs a little space outside the ring. The shelf pair can stay where it is while you turn the warming pair and tend the red."

func drying_advice(piece: Fire.Piece) -> String:
	if piece != null and fire.has_fuel(piece):
		var wet := piece.water / piece.original
		if not piece.faces.is_empty() and piece.core.water / piece.core.original > 0.37 and piece.faces[0].water / piece.faces[0].original < 0.27:
			return "That skin is drying. The heart of the branch still holds water. Turn it and give it time in moving air before asking it to burn."
		if wet < 0.25:
			return "That piece is ready to give heat. Set it with the dry wood, or use it to keep the coals alive while the wetter pieces dry."
		if fire.in_hearth(piece.at) and wet > 0.42:
			return "That wet piece is taking warmth from the red. Bring it out to the edge and leave space for the steam to escape."
	if hot_coals < 0.013 and fire.total_flame() < 2.0:
		return "The red has little warmth to spare. Feed it dry, thin wood first. Let the wet branches borrow heat at the edge once it stands stronger."
	return "Let wet wood take warmth at the edge. Leave gaps and turn the branches. Feel along each face. A dry skin can hide a wet heart."

func answer(topic: String, selected: Fire.Piece) -> String:
	match topic:
		"wood_methods": return DRYING_LESSON
		"wood_air": return AIR_DRYING_LESSON
		"wood_edge": return EDGE_DRYING_LESSON
		"myth_mother": return TALE[4]
		"myth_twins": return TALE[1]
		"myth_thunder": return TALE[5]
		"myth_hunters": return TALE[6]
		"myth_fire": return TALE[7]
		"myth_chasm": return TALE[2]
		"myth_fall": return TALE[3]
		"wood_shelf": return "Keep dry fibres in the left alcove and seasoned wood on the back left shelf. The stone at the back right sweats. The gap just before it carries air away."
		"wood_sparks":
			if hazard:
				return guidance()
			if not fire.sparks.is_empty():
				return "See how it spits? Keep loose fibres out of the path of those glowing flecks. Even a small one can start a nest breathing."
			return "Pitch can gather in a pine knot. Heat draws it out, and trapped steam can split the skin with a pop. Keep dry fibres well back when the pine begins to spit."
	return drying_advice(selected)

func topic(words: String) -> String:
	var clean := words.to_lower()
	for mark in ["’", "'", "?", ".", ",", "!", "-", "–"]:
		clean = clean.replace(mark, " ")
	var tokens := clean.split(" ", false)
	if "chasm" in tokens or "coverings" in tokens: return "myth_chasm"
	if "dark waters" in clean or ("mother" in tokens and ("fell" in tokens or "cast" in tokens)): return "myth_fall"
	if "lightning" in tokens or "thunder" in tokens: return "myth_thunder"
	if ["predators", "lion", "lions", "hyena", "hyenas", "wolf", "wolves"].any(func(word): return word in tokens): return "myth_hunters"
	if "flame children" in clean or "living sparks" in clean or "living fire" in clean: return "myth_fire"
	if "aru" in tokens or "varek" in tokens or "twins" in tokens or "keeping hand" in clean or "seeking hand" in clean: return "myth_twins"
	if "mother of the world" in clean or "world mother" in clean or ("mother" in tokens and ("sky" in tokens or "earth" in tokens)): return "myth_mother"
	if "sky father" in clean or "tears" in tokens: return "myth_hunters"
	if ["spark", "sparks", "pitch", "resin", "spit", "spits", "pops", "crackles"].any(func(word): return word in tokens): return "wood_sparks"
	var drying := ["dry", "drying", "dried", "air-dry", "wet", "damp"].any(func(word): return word in tokens)
	if drying and ("how long" in clean or "how much time" in clean or "which" in tokens or "difference" in tokens or "faster" in tokens or "pros" in tokens or "cons" in tokens): return "wood_methods"
	if drying and ("air-dry" in tokens or "air dry" in clean or "air drying" in clean or "slowly" in tokens or "shelf" in tokens): return "wood_air"
	if drying and ("edge" in tokens or "beside" in tokens or "near the fire" in clean or "around the fire" in clean or "by the fire" in clean): return "wood_edge"
	if ["shelf", "alcove", "seepage", "store", "storage", "seep"].any(func(word): return word in tokens): return "wood_shelf"
	if ["dry", "drying", "dried", "steam", "wet", "soaked", "waterlogged", "damp"].any(func(word): return word in tokens): return "wood_drying"
	return ""
