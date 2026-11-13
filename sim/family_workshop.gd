extends RefCounted
## Each parcel has one physical rest. Grams are conserved when portions are
## cut, bones cracked, hides stripped and hafts fitted. Cooking drives off
## moisture. Smoke, discarded material and eaten food leave the stores.

const Techniques := preload("res://sim/family_techniques.gd")
const Lessons := preload("res://sim/family_lessons.gd")
const Fire := preload("res://sim/fire.gd")
const COOK := "Cooking Place"
const HUNTER := "Hunter’s Working Place"
const MAKER := "Maker’s Stone"
const STORE := "Covered food shelf"
const STORE_AT := Vector2(-1.48, -3.56)
const COOK_AT := Vector2(-0.94, 0.22)
const HUNTER_AT := Vector2(0.83, -2.47)
const MAKER_AT := Vector2(-0.85, -2.83)
const RACK_AT := Vector2(0.32, -2.21)
const HIDE_AT := Vector2(0.36, -3.13)
const HIDE_RACK := "Hide rack"
const FLOOR := "Cave floor"
const HAND := "In your hand"
const IN_TRANSIT := "In a relative’s hands"
const SPIT := "Spit"
const KIN_SPIT := "Nara’s spit"
const KIN_CUP := "Ina’s cup"
const KIN_ROAST_AT := Vector2(0.54, 0.12)
const KIN_RESIN_AT := Vector2(0.50, -0.27)
const CUP := "Resin cup"
const GEAR_IDS := ["bera", "ivo", "kett"]
const SURFACES := {HUNTER: HUNTER_AT, COOK: COOK_AT, MAKER: MAKER_AT, STORE: STORE_AT, HIDE_RACK: HIDE_AT}
const STATIONS := {COOK: COOK_AT, HUNTER: HUNTER_AT, MAKER: MAKER_AT}
const ROAST_POSITIONS := [Vector2(-0.30, 0.02), Vector2(-0.57, 0.09), COOK_AT]
const ROAST_RESTS := ["Over the red", "At the coal edge", "On the resting stone"]
const RESIN_POSITIONS := [Vector2(-0.55, -0.24), Vector2(-0.32, -0.09)]
const RESIN_RESTS := ["On the warm stone", "Close to the red"]
const LABELS := {
	"carcass": "Carcass portion", "meat": "Meat", "bone": "Marrow bone", "spent_bone": "Split bone",
	"marrow": "Marrow", "hide": "Hide", "fat": "Fat", "trim": "Trimmings", "binding": "Rawhide binding",
	"knot": "Resinous knot", "resin": "Raw resin", "pitch": "Resin adhesive", "ruined_pitch": "Scorched resin",
	"point": "Stone point", "shaft": "Wooden shaft", "scrap": "Work scraps", "roots": "Edible roots",
	"bone_shard": "Bone fragments", "clean_hide": "Cleaned hide", "flake": "Sharp stone flake",
	"scraper": "Stone scraper", "hammer": "Hammerstone", "vessel": "Stone cup",
}

class Parcel:
	var id: int
	var kind: String
	var grams: int
	var species := ""
	var freshness := 1.0
	var edge := 1.0
	var rest: String
	var at := Vector2.ZERO
	var yaw := 0.0
	var prepared := false
	var worked := false
	var temperature := 10.0
	var core := 10.0
	var dose := [0.0, 0.0]
	var charred := 0.0
	var face := 0
	var cure := 0.0
	var scorched := 0.0
	var smoked := false
	var origin := ""
	var removed_at := 0.0

	func label() -> String:
		var name: String = LABELS[kind]
		if species == "bison" and kind in ["carcass", "meat", "bone", "hide", "fat"]:
			name = "Bison " + name.to_lower()
		if freshness <= 0.0 and kind in ["carcass", "meat", "marrow"]:
			return "Spoiled " + name.to_lower()
		if kind in ["meat", "marrow"]:
			name = condition() + " " + name.to_lower()
		if prepared and kind in ["point", "shaft"]:
			name = "Prepared " + name.to_lower()
		return name

	func condition() -> String:
		if charred >= 1.0:
			return "Charred"
		if minf(dose[0], dose[1]) < 1.0 or core < 65.0 and cure < 1.0:
			if maxf(dose[0], dose[1]) >= 2.9:
				return "Dried"
			return "Undercooked" if maxf(dose[0], dose[1]) >= 0.15 else "Raw"
		return "Overcooked" if maxf(dose[0], dose[1]) >= 2.9 else "Roasted"

var fire: Fire
var lessons := Lessons.new()
var techniques := Techniques.new()
var reserved: Dictionary = {}
var held := 0
var held_from := ""
var held_at := Vector2.ZERO
var cup_id := 0
var kin_cup_id := 0
var cup_fill := 0
var hand_note := ""
var parcels: Dictionary[int, Parcel] = {}
var gear := {
	"bera": {"condition": 0.76, "grams": 360, "at": HUNTER},
	"ivo": {"condition": 0.43, "grams": 340, "at": HUNTER},
	"kett": {"condition": 0.61, "grams": 355, "at": HUNTER},
}
var roast: Parcel
var resin: Parcel
var roast_position := 1
var roast_started := 0.0
var nara_tending := false
var resin_position := 0
var next_id := 1
var revision := 0
var evaporated := 0
var eaten := 0
var discarded := 0
var record: Dictionary = {}
var lesson_revision := 0
var focus := "Kin’s Hearth"
var notices: Dictionary[String, String] = {}

func _init(model: Fire) -> void:
	fire = model
	receive_game(1080, "Bera’s catch")
	var prepared := add("meat", 180, STORE)
	prepared.dose = [1.2, 1.2]
	prepared.cure = 1.0
	add("roots", 330, STORE)
	add("knot", 85, MAKER)
	add("binding", 12, MAKER)
	add("point", 52, MAKER)
	add("shaft", 265, MAKER)
	add("flake", 33, HUNTER)
	add("flake", 24, HUNTER).edge = 0.81
	add("scraper", 57, HUNTER)
	add("hammer", 310, HUNTER)
	add("hammer", 238, HUNTER).edge = 0.86
	add("flake", 27, COOK)
	add("flake", 21, COOK).edge = 0.89
	add("scraper", 44, MAKER)
	add("scraper", 38, MAKER).edge = 0.87
	cup_id = add("vessel", 145, MAKER).id
	kin_cup_id = add("vessel", 153, MAKER).id
	for i in range(GEAR_IDS.size()):
		gear[GEAR_IDS[i]].point = RACK_AT + Vector2((i - 1) * 0.095, 0)
		gear[GEAR_IDS[i]].yaw = 0.0

func add(kind: String, grams: int, rest: String) -> Parcel:
	var parcel := Parcel.new()
	parcel.id = next_id
	next_id += 1
	parcel.kind = kind
	parcel.grams = grams
	parcel.rest = rest
	parcel.at = find_rest(rest, kind)
	parcel.yaw = fposmod(parcel.id * 0.43, TAU)
	parcel.temperature = fire.ambient()
	parcel.core = parcel.temperature
	parcels[parcel.id] = parcel
	revision += 1
	return parcel

func receive_game(grams: int, origin: String) -> void:
	add("carcass", grams, HUNTER).origin = origin

func stock(kind: String, rest := "") -> Array[Parcel]:
	var found: Array[Parcel] = []
	for parcel in parcels.values():
		if parcel.kind == kind and (rest.is_empty() or parcel.rest == rest):
			found.append(parcel)
	return found

func portions_at(rest: String) -> Array[Parcel]:
	var found: Array[Parcel] = []
	for parcel in parcels.values():
		if parcel.rest == rest:
			found.append(parcel)
	return found

func _take(parcel: Parcel, grams: int) -> void:
	parcel.grams -= grams
	if parcel.grams == 0:
		parcels.erase(parcel.id)
	revision += 1

func butcher(id: int, player := true, limit := 2147483647) -> bool:
	var parcel: Parcel = parcels.get(id)
	if parcel == null or parcel.kind != "carcass" or parcel.rest != HUNTER or parcel.freshness <= 0.0 or (player and reserved.has(id)):
		return false
	var before := parcel.grams
	var mass := mini(before, limit)
	var after := before - mass
	var meat := before * 56 / 100 - after * 56 / 100
	var bone := before * 19 / 100 - after * 19 / 100
	var hide := before * 13 / 100 - after * 13 / 100
	var fat := before * 7 / 100 - after * 7 / 100
	_take(parcel, mass)
	for yield_part in [["meat", meat], ["bone", bone], ["hide", hide], ["fat", fat], ["trim", mass - meat - bone - hide - fat]]:
		if yield_part[1] > 0:
			inherit_cut(add(yield_part[0], yield_part[1], HUNTER), parcel)
	notices[HUNTER] = "Meat, bone, hide and fat lie on the board. The trimmings go to one side."
	if player:
		lessons.note(HUNTER, "carve", "you freed the meat and kept the bone, fat and hide",
			"Good. Keep the flesh clear of the fragments. See how much is still on the carcass?")
	return true

func crack_bone(id: int, player := true) -> bool:
	var parcel: Parcel = parcels.get(id)
	if parcel == null or parcel.kind != "bone" or parcel.rest != HUNTER or (player and reserved.has(id)):
		return false
	var marrow := parcel.grams / 5
	var bone := parcel.grams - marrow
	_take(parcel, parcel.grams)
	inherit_cut(add("marrow", marrow, HUNTER), parcel)
	var chips := bone / 5
	add("spent_bone", bone - chips, HUNTER)
	add("bone_shard", chips, HUNTER)
	if player:
		techniques.practice(Techniques.MARROW, "Bera")
		lessons.note(HUNTER, "crack", "you recovered marrow from the bone you split",
			"That’s the soft part we can use. Set the fragments aside before you take the marrow to Nara.")
	notices[HUNTER] = "You split the bone and lift out the marrow."
	return true

func cut_binding(id: int, deliver := true, player := true) -> bool:
	var parcel: Parcel = parcels.get(id)
	if parcel == null or parcel.kind not in ["hide", "clean_hide"] or parcel.rest not in [HUNTER, HIDE_RACK] or parcel.grams < 12 \
			or (player and reserved.has(id)):
		return false
	_take(parcel, 12)
	add("binding", 12, MAKER if deliver else parcel.rest)
	notices[HUNTER] = "A strip of hide goes to the Maker’s Stone." if deliver else "The cut strip is ready to carry to Ina."
	return true

func clean_hide(id: int) -> bool:
	var parcel: Parcel = parcels.get(id)
	if parcel == null or parcel.kind != "hide" or parcel.rest != HUNTER:
		return false
	var removed := maxi(1, parcel.grams / 8)
	_take(parcel, removed)
	if parcels.has(id):
		parcel.kind = "clean_hide"
	add("trim", removed, HUNTER)
	return true

func carry_to_cook(id: int, player := true) -> bool:
	var parcel: Parcel = parcels.get(id)
	if parcel == null or parcel.kind not in ["meat", "marrow"] or parcel.rest != HUNTER or (player and reserved.has(id)):
		return false
	_relocate(parcel, COOK)
	if player:
		_note_carry(parcel)
	notices[COOK] = "You bring the raw cut to Nara’s board."
	return true

func return_to_board(id: int) -> void:
	var parcel: Parcel = parcels.get(id)
	if parcel != null and parcel.rest == STORE and parcel.kind in ["meat", "marrow"] and parcel.condition() in ["Raw", "Undercooked", "Dried"]:
		_relocate(parcel, COOK)

func put_on_spit(id: int, tended_by_nara := false) -> bool:
	var parcel: Parcel = parcels.get(id)
	if roast != null or parcel == null or reserved.has(id) or parcel.freshness <= 0.0 or parcel.rest != COOK or parcel.kind not in ["meat", "marrow"]:
		return false
	if parcel.grams > 180:
		_take(parcel, 180)
		var part := add(parcel.kind, 180, COOK)
		inherit_cut(part, parcel)
		parcel = part
	_set_roast(parcel, 1, tended_by_nara)
	return true

func _set_roast(parcel: Parcel, position: int, tended_by_nara := false) -> void:
	_cool_since_lift(parcel)
	roast = parcel
	roast_started = fire.time
	nara_tending = tended_by_nara
	roast.rest = SPIT
	roast_position = position
	roast.at = ROAST_POSITIONS[position]
	if not tended_by_nara:
		roast.worked = true
		lessons.note(COOK, "heat", "you set a portion over the living bed",
			"Watch the face that takes the heat. The pale side will need its turn.")
	revision += 1
	notices[COOK] = "The spit rests %s." % ROAST_RESTS[position].to_lower()

func turn_spit(by_nara := false) -> void:
	if roast != null:
		nara_tending = by_nara
		roast.face = 1 - roast.face
		if not by_nara:
			roast.worked = true
			lessons.note(COOK, "turn", "you turned the portion so both faces could take heat",
				"Now watch the face you just turned towards the red. Let the middle warm before you lift it.")
		revision += 1

func move_spit(position: int) -> void:
	if roast != null and position >= 0 and position < ROAST_POSITIONS.size():
		nara_tending = false
		roast_position = position
		roast.at = ROAST_POSITIONS[position]
		revision += 1

func lift_spit(by_nara := false) -> void:
	if roast == null:
		return
	var parcel := _unspit()
	_relocate(parcel, STORE)
	if not by_nara:
		_note_food(parcel)
	notices[COOK] = ("Nara lays %s on the shelf." % parcel.label().to_lower()) if by_nara else "%s goes onto the covered food shelf." % parcel.label()

func _unspit() -> Parcel:
	var parcel := roast
	parcel.removed_at = fire.time
	roast = null
	nara_tending = false
	return parcel

func scrape_knot(id: int, player := true) -> bool:
	var knot: Parcel = parcels.get(id)
	if knot == null or knot.kind != "knot" or knot.rest != MAKER or (player and reserved.has(id)):
		return false
	var yield_grams := knot.grams * 3 / 10
	var wood := knot.grams - yield_grams
	_take(knot, knot.grams)
	add("resin", yield_grams, MAKER)
	add("scrap", wood, MAKER)
	if player:
		lessons.note(MAKER, "scrape", "you scraped resin from the sticky knot",
			"That’s enough for the cup. Keep the sticky lumps together and warm them away from the strongest heat.")
	notices[MAKER] = "You scrape the resin into a stone cup and set the spent knot aside."
	return true

func set_resin(id: int) -> bool:
	var parcel: Parcel = parcels.get(id)
	if resin != null or cup_fill != 0 or parcel == null or parcel.kind != "resin" or parcel.rest != MAKER or reserved.has(id):
		return false
	var cup := parcels[cup_id]
	_load_cup(parcel)
	_heat_cup(cup, 0)
	return true

func _load_cup(parcel: Parcel) -> void:
	_cool_since_lift(parcel)
	var cup := parcels[cup_id]
	resin = parcel
	cup_fill = parcel.id
	parcel.rest = CUP
	parcel.at = cup.at
	resin_position = -1
	revision += 1

func _heat_cup(cup: Parcel, position: int) -> void:
	cup.rest = CUP
	cup.at = RESIN_POSITIONS[position]
	if resin != null:
		_cool_since_lift(resin)
		resin.at = cup.at
	resin_position = position
	revision += 1

func move_resin(position: int) -> void:
	if resin != null and position >= 0 and position < RESIN_POSITIONS.size():
		resin_position = position
		var cup := parcels[cup_id]
		cup.at = RESIN_POSITIONS[position]
		resin.at = cup.at
		revision += 1

func lift_resin() -> void:
	if resin == null:
		return
	_finish_resin()
	_set_cup_down(MAKER, find_rest(MAKER, "vessel"))

func _finish_resin() -> void:
	resin_position = -1
	if resin == null or resin.kind != "resin":
		return
	if resin.scorched >= 1.0:
		resin.kind = "ruined_pitch"
		lessons.note(MAKER, "scorch", "you overheated a cup and the resin went brittle",
			"That bitter smoke means we lost this cup. Take another lump and start on the warm stone.")
		notices[MAKER] = "The cup holds brittle, scorched resin."
	elif resin.cure >= 1.0:
		var loss := resin.grams / 5
		resin.grams -= loss
		evaporated += loss
		resin.kind = "pitch"
		techniques.practice(Techniques.RESIN, "Ina")
		_learn("Hearth Maker", "Draw a workable adhesive", "Draw the cup away when the resin runs evenly. Thick smoke means it is already too hot.")
		lessons.note(MAKER, "pitch", "you warmed the resin until it ran together",
			"See how it runs together? Put it beside the shaft while it is workable.")
		notices[MAKER] = "The cup holds usable adhesive."
	else:
		notices[MAKER] = "The resin is still gritty. You can heat this same cup again."
	resin.removed_at = fire.time
	resin_position = -1

func _set_cup_down(rest: String, at: Vector2) -> void:
	var cup := parcels[cup_id]
	_relocate(cup, rest, at)
	if resin != null:
		_relocate(resin, rest, find_rest(rest, resin.kind) if rest != FLOOR else at + Vector2(0.08, 0))
		resin = null
		cup_fill = 0

func can_haft(hunter: String, replace: bool, worker := false) -> bool:
	if not gear.has(hunter):
		return false
	var tool: Dictionary = gear[hunter]
	var condition: float = tool.condition
	var materials := _available("binding", MAKER) >= 12 and _available("pitch", MAKER) >= 10
	var parts := _available("point", MAKER) > 0 and _available("shaft", MAKER) > 0
	return (worker or not reserved.has(gear_id(hunter))) and tool.at in [HUNTER, MAKER] and materials \
		and ((replace and condition < 1.0 and parts) or (not replace and condition >= 0.20 and condition < 0.86))

func haft(hunter: String, replace: bool, player := true, parts: Array = []) -> bool:
	if not can_haft(hunter, replace, not player):
		return false
	var point := _component("point") if parts.is_empty() else parcels.get(parts[0]) as Parcel
	var shaft := _component("shaft") if parts.is_empty() else parcels.get(parts[1]) as Parcel
	if replace and (point == null or shaft == null or point.rest != MAKER or shaft.rest != MAKER):
		return false
	var tool: Dictionary = gear[hunter]
	var old_mass: int = tool.grams
	_consume("binding", MAKER, 12)
	_consume("pitch", MAKER, 10)
	if replace:
		tool.grams = 22 + point.grams + shaft.grams
		_take(point, point.grams)
		_take(shaft, shaft.grams)
		add("scrap", old_mass, MAKER)
	else:
		var removed := mini(old_mass, 18)
		add("scrap", removed, MAKER)
		tool.grams += 22 - removed
	tool.condition = 1.0 if replace else maxf(0.86, tool.condition)
	if player:
		techniques.practice(Techniques.HAFT, "Ina")
		_learn("Hearth Maker", "Seat a sound haft", "Test the point sideways before sending it out. A cracked shaft needs a new point and shaft fitted together.")
		lessons.note(MAKER, "haft", "you bound %s’s spear with adhesive and rawhide" % hunter.capitalize(),
			"Push the point gently sideways. If the binding holds, carry it to the rack so the hunter can take it.")
	notices[MAKER] = "You seat the point and bind the haft."
	revision += 1
	return true

func food_on_shelf() -> int:
	var grams := _available("roots", STORE)
	for parcel in portions_at(STORE):
		if parcel.kind in ["meat", "marrow"] and parcel.freshness > 0.0 and parcel.condition() in ["Roasted", "Overcooked"]:
			grams += parcel.grams
	return grams

func eat(need: int) -> int:
	var served := _consume("roots", STORE, need)
	for parcel in portions_at(STORE):
		if served >= need:
			break
		if parcel.kind in ["meat", "marrow"] and parcel.freshness > 0.0 and parcel.condition() in ["Roasted", "Overcooked"]:
			var bite := mini(need - served, parcel.grams)
			_take(parcel, bite)
			served += bite
	eaten += served
	return served

func discard_food(id: int) -> void:
	var parcel: Parcel = parcels.get(id)
	if parcel != null and parcel.rest == STORE and parcel.kind in ["meat", "marrow"] and parcel.condition() == "Charred":
		discarded += parcel.grams
		_take(parcel, parcel.grams)

func _available(kind: String, rest: String) -> int:
	var grams := 0
	for parcel in stock(kind, rest):
		grams += parcel.grams
	return grams

func _consume(kind: String, rest: String, grams: int) -> int:
	var left := grams
	for parcel in stock(kind, rest):
		var used := mini(left, parcel.grams)
		_take(parcel, used)
		left -= used
		if left == 0:
			break
	return grams - left

func _cool_since_lift(parcel: Parcel) -> void:
	var elapsed := fire.time - parcel.removed_at
	parcel.temperature = lerpf(fire.ambient(), parcel.temperature, exp(-elapsed / 14.0))
	parcel.core = lerpf(fire.ambient(), parcel.core, exp(-elapsed / 27.0))

func heat_target(at: Vector2, overhead: bool) -> float:
	var radiant := fire.heat_at(at)
	var plume := 0.0
	if overhead:
		for piece in fire.wood:
			plume += piece.flame * exp(-piece.at.distance_squared_to(at) * 8.0)
	return fire.ambient() + minf(800.0, radiant * (510.0 if overhead else 430.0) + plume * 18.0)

func step(dt: float) -> bool:
	var smoke_started := false
	if roast != null:
		smoke_started = cook_at(roast, ROAST_POSITIONS[roast_position], roast_position == 0, dt)
	if resin != null and resin.kind == "resin" and resin_position >= 0:
		smoke_started = soften_at(resin, RESIN_POSITIONS[resin_position], resin_position == 1, dt) or smoke_started
	return smoke_started

func cook_at(piece: Parcel, at: Vector2, overhead: bool, dt: float) -> bool:
	var target := heat_target(at, overhead)
	piece.temperature = lerpf(piece.temperature, target, 1.0 - exp(-dt / 3.0))
	piece.core = lerpf(piece.core, minf(101.0, piece.temperature), 1.0 - exp(-dt / 8.0))
	piece.dose[piece.face] += dt * clampf((piece.temperature - 62.0) / 410.0, 0.0, 0.65)
	if piece.core >= 65.0 and minf(piece.dose[0], piece.dose[1]) >= 1.0 and piece.cure < 1.0:
		piece.cure = 1.0
		var loss := maxi(1, piece.grams / 8)
		piece.grams -= loss
		evaporated += loss
		if piece.worked:
			lessons.reactions[COOK] = "Both faces have browned and the middle is warm. Lift it while it’s still good to eat."
			lessons.revision += 1
	piece.charred += dt * clampf((piece.temperature - 175.0) / 480.0, 0.0, 0.52)
	if piece.charred >= 1.0 and not piece.smoked:
		piece.smoked = true
		if piece.worked:
			lessons.note(COOK, "char", "a portion blackened over strong heat",
				"That face has blackened. Lift it clear of the red. Give the next cut a gentler place.")
		return true
	return false

func soften_at(piece: Parcel, at: Vector2, overhead: bool, dt: float) -> bool:
	var target := heat_target(at, overhead)
	piece.temperature = lerpf(piece.temperature, target, 1.0 - exp(-dt / 2.7))
	if piece.temperature >= 68.0 and piece.temperature < 166.0:
		piece.cure += dt * clampf((piece.temperature - 60.0) / 460.0, 0.0, 0.24)
	piece.scorched += dt * clampf((piece.temperature - 165.0) / 240.0, 0.0, 0.60)
	if piece.scorched >= 1.0 and not piece.smoked:
		piece.smoked = true
		if piece == resin:
			lessons.reactions[MAKER] = "The cup is smoking. Lift it off the red before the cave fills with that sharp smell."
			lessons.revision += 1
			notices[MAKER] = "The resin smokes sharply. Lift the cup away from the red."
		return true
	return false

func inherit_cut(part: Parcel, source: Parcel) -> void:
	part.origin = source.origin
	part.species = source.species
	part.freshness = source.freshness

func age_food(seconds: float) -> void:
	var changed := false
	for piece in parcels.values():
		if piece.freshness <= 0.0 or piece.kind not in ["carcass", "meat", "marrow"]:
			continue
		var cover := 0.50 if piece.rest == STORE else (1.33 if piece.rest == FLOOR else 0.87)
		var warmth := maxf(0.0, fire.ambient() - 6.0)
		if piece.rest in [SPIT, KIN_SPIT, COOK]:
			warmth += minf(16.0, fire.heat_at(piece.at) * 24.0)
		var preparation := 0.46 if piece.cure >= 1.0 else 1.0
		piece.freshness = maxf(0.0, piece.freshness - seconds / 360.0 * (0.32 + warmth * 0.024) * cover * preparation)
		changed = changed or piece.freshness <= 0.0
	if changed:
		revision += 1

func _learn(path: String, lesson: String, technique: String) -> void:
	if not record.has(path):
		record[path] = {}
	if not record[path].has(lesson):
		record[path][lesson] = technique
		lesson_revision += 1

func observe_fire(path: String, lesson: String, technique: String) -> void:
	_learn(path, lesson, technique)

func find_rest(rest: String, kind: String) -> Vector2:
	var centre: Vector2 = SURFACES.get(rest, Vector2.ZERO)
	var special := {
		"carcass": Vector2(-0.04, -0.12), "flake": Vector2(-0.26, -0.23),
		"scraper": Vector2(0.24, 0.11), "hammer": Vector2(0.16, 0.21),
		"vessel": Vector2(-0.19, -0.12), "shaft": Vector2(0.0, 0.18),
	}
	var wanted: Vector2 = centre + special.get(kind, Vector2.ZERO)
	if _free_at(wanted, rest):
		return wanted
	for z in range(5):
		for x in range(5):
			var at := centre + Vector2((x - 2) * 0.12, (z - 2) * 0.12)
			if _free_at(at, rest):
				return at
	var row := 0
	for parcel in parcels.values():
		if parcel.rest == rest:
			row += 1
	return centre + Vector2(-0.31 - (row / 5 - 5) * 0.11, (row % 5 - 2) * 0.12)

func _free_at(at: Vector2, rest: String) -> bool:
	for parcel in parcels.values():
		if parcel.rest == rest:
			var gap := 0.18 if parcel.kind == "carcass" else 0.105
			if parcel.at.distance_squared_to(at) < gap * gap:
				return false
	return true

func _relocate(parcel: Parcel, rest: String, at := Vector2.INF) -> void:
	parcel.at = find_rest(rest, parcel.kind) if at == Vector2.INF else at
	parcel.rest = rest
	revision += 1

func gear_id(name_text: String) -> int:
	return -1 - GEAR_IDS.find(name_text)

func gear_name(id: int) -> String:
	return GEAR_IDS[-id - 1] if id < 0 and -id <= GEAR_IDS.size() else ""

func object_rest(id: int) -> String:
	if id < 0:
		return gear[gear_name(id)].at if not gear_name(id).is_empty() else ""
	var parcel: Parcel = parcels.get(id)
	return parcel.rest if parcel != null else ""

func object_position(id: int) -> Vector2:
	return gear[gear_name(id)].point if id < 0 else parcels[id].at

func object_label(id: int) -> String:
	if id < 0:
		var name_text := gear_name(id)
		return name_text.capitalize() + "’s spear"
	var parcel: Parcel = parcels.get(id)
	if parcel == null:
		return ""
	if id == cup_id and resin != null:
		var state := "gritty resin"
		if resin.scorched >= 1.0 or resin.kind == "ruined_pitch":
			state = "scorched resin"
		elif resin.cure >= 1.0:
			state = "workable adhesive"
		elif resin.temperature >= 68.0:
			state = "softening resin"
		return "Stone cup · " + state
	return parcel.label()

func pick_up(id: int) -> bool:
	if held != 0 or reserved.has(id):
		return false
	var rest := object_rest(id)
	if rest.is_empty() or rest == IN_TRANSIT:
		return false
	if id < 0:
		if rest not in [HUNTER, MAKER, STORE, COOK, HIDE_RACK, FLOOR]:
			return false
		gear[gear_name(id)].at = HAND
	elif id == cup_fill:
		return false
	else:
		var parcel := parcels[id]
		if parcel == roast:
			_unspit()
			parcel.worked = true
		elif id == cup_id and resin_position >= 0:
			_finish_resin()
		parcel.rest = HAND
	held = id
	held_from = rest
	held_at = object_position(id)
	hand_note = "You lift " + object_label(id).to_lower() + "."
	revision += 1
	return true

func set_down(at: Vector2, rest := FLOOR, heat_slot := -1, target := 0) -> bool:
	if held == 0 or not at.is_finite() or not Fire.Shelter.YARD.grow(0.12).has_point(at):
		return false
	if held < 0:
		var tool: Dictionary = gear[gear_name(held)]
		tool.at = rest
		tool.point = at
		if rest == HUNTER and tool.condition >= 0.86 and lessons.has(MAKER, "haft"):
			lessons.note(MAKER, "rack", "you returned the sound spear to the hunters’ rack",
				"Now Ivo can take that spear when the elders call him.")
	elif not _drop_parcel(parcels[held], at, rest, heat_slot, target):
		return false
	hand_note = "You set down " + object_label(held).to_lower() + "."
	_clear_hand()
	return true

func _drop_parcel(parcel: Parcel, at: Vector2, rest: String, heat_slot: int, target: int) -> bool:
	if parcel.id == cup_id:
		if rest == CUP and heat_slot >= 0:
			_heat_cup(parcel, heat_slot)
		else:
			_set_cup_down(rest, at)
		return true
	if parcel.kind == "resin" and target == cup_id:
		if cup_fill != 0:
			hand_note = "The stone cup already has resin in it."
			return false
		_load_cup(parcel)
		var cup := parcels[cup_id]
		if cup.rest == CUP:
			_heat_cup(cup, _nearest_heat(cup.at, RESIN_POSITIONS))
		return true
	if rest == SPIT and parcel.kind in ["meat", "marrow"] and heat_slot >= 0:
		if parcel.freshness <= 0.0:
			hand_note = "That cut has spoiled. Keep it away from the food."
			return false
		if roast != null or parcel.grams > 180:
			hand_note = "The spit is occupied." if roast != null else "Cut a small portion on Nara’s board first."
			return false
		_set_roast(parcel, heat_slot)
		return true
	if rest == SPIT or rest == CUP:
		rest = FLOOR
	if SURFACES.has(rest) and not _free_at(at, rest):
		at = find_rest(rest, parcel.kind)
	_relocate(parcel, rest, at)
	if rest == COOK and (held_from == HUNTER or (held_from == FLOOR and not parcel.origin.is_empty())) and parcel.kind in ["meat", "marrow"]:
		_note_carry(parcel)
	if rest == HIDE_RACK and parcel.kind == "clean_hide":
		lessons.note(HUNTER, "hide", "you cleaned and stretched a hide at the rack",
			"Leave the clean hide here. Its long edge will make a strong binding.")
	if rest == FLOOR and held_from == HUNTER and parcel.kind in ["meat", "marrow", "fat"]:
		lessons.reactions[HUNTER] = "Keep what we can eat off the bare stone. Your mother’s board is just by the fire."
		lessons.revision += 1
	if rest == STORE and parcel.worked and parcel.kind in ["meat", "marrow"]:
		_note_food(parcel)
		parcel.worked = false
	return true

func cancel_hand() -> void:
	if held == 0:
		return
	var rest := held_from
	if rest == SPIT:
		if roast == null:
			_set_roast(parcels[held], _nearest_heat(held_at, ROAST_POSITIONS), true)
			nara_tending = false
			_clear_hand()
			return
		rest = COOK
	elif rest == CUP and held == cup_id:
		_heat_cup(parcels[cup_id], _nearest_heat(held_at, RESIN_POSITIONS))
		_clear_hand()
		return
	if held < 0:
		gear[gear_name(held)].at = rest
		gear[gear_name(held)].point = held_at
	elif held == cup_id:
		_set_cup_down(rest, held_at)
	else:
		_relocate(parcels[held], rest, held_at)
	_clear_hand()

func _clear_hand() -> void:
	held = 0
	held_from = ""
	held_at = Vector2.ZERO
	revision += 1

func _nearest_heat(at: Vector2, positions: Array) -> int:
	var best := 0
	for i in range(1, positions.size()):
		if at.distance_squared_to(positions[i]) < at.distance_squared_to(positions[best]):
			best = i
	return best

func _note_carry(parcel: Parcel) -> void:
	var kind := "marrow" if parcel.kind == "marrow" else "meat"
	lessons.note(HUNTER, "carry", "you brought %s to Nara’s board" % kind,
		"Nara can use that. Bring the remaining cuts over when she has room.")

func _note_food(parcel: Parcel) -> void:
	var condition := parcel.condition()
	if condition in ["Roasted", "Overcooked"] and parcel.freshness > 0.0:
		techniques.practice(Techniques.ROAST, "Nara")
		_learn("Kin’s Hearth", "Turn a portion and roast it through",
			"Read the two faces separately. Turn while the pale side is still cool and lift the spit once the centre has warmed.")
		lessons.note(COOK, "meal", "you left %s food on the covered shelf" % condition.to_lower(),
			"That will feed someone. Feel how the centre has warmed all the way through.")
	elif condition != "Charred":
		lessons.note(COOK, "early", "you lifted a portion while it was still %s" % condition.to_lower(),
			"The middle still needs warmth. Set it back on the spit when the red is steady.")

func _tool_at(kind: String, rest: String) -> bool:
	return stock(kind, rest).any(func(piece): return not reserved.has(piece.id)) or (held > 0 and parcels[held].kind == kind)

func _component(kind: String) -> Parcel:
	var parts := stock(kind, MAKER)
	var spare: Parcel
	for part in parts:
		if reserved.has(part.id):
			continue
		if part.prepared:
			return part
		if spare == null:
			spare = part
	return spare

func context_label(id: int) -> String:
	if id < 0:
		return "Fit or bind the haft" if object_rest(id) == MAKER else ""
	var parcel: Parcel = parcels.get(id)
	if parcel == null:
		return ""
	if parcel == roast:
		return "Turn the spit"
	match parcel.kind:
		"carcass": return "Separate a cut"
		"bone": return "Crack for marrow"
		"hide": return "Scrape the hide"
		"clean_hide": return "Cut a binding"
		"knot": return "Scrape the resin"
		"point": return "Dress the point" if not parcel.prepared else ""
		"shaft": return "Smooth the shaft" if not parcel.prepared else ""
		"meat":
			if parcel.condition() == "Charred":
				return "Discard the charred cut"
			if parcel.grams > 180:
				return "Cut a roasting portion"
	return ""

func held_can_work(target: int) -> bool:
	if held <= 0 or target <= 0 or held == target or not parcels.has(target):
		return false
	var kinds: Array = {"flake": ["carcass", "meat", "knot", "clean_hide"], "hammer": ["bone", "point"],
		"scraper": ["hide", "shaft", "knot", "clean_hide"]}.get(parcels[held].kind, [])
	return parcels[target].kind in kinds

func use_held_on(target: int) -> bool:
	if not held_can_work(target):
		return false
	work(target)
	return true

func work(id: int) -> bool:
	if reserved.has(id):
		hand_note = "A relative is working on that piece."
		return false
	if id < 0:
		return _fit_physical(id)
	var parcel: Parcel = parcels.get(id)
	if parcel == null:
		return false
	if parcel == roast:
		turn_spit()
		return true
	match parcel.kind:
		"carcass":
			if parcel.freshness <= 0.0:
				hand_note = "That flesh has spoiled. Keep it apart from the good cuts."
				return false
			if _tool_at("flake", HUNTER) and butcher(id, true, 540):
				return true
			hand_note = "Lay the carcass on the hunters’ board. Use the sharp flake."
		"bone":
			if _tool_at("hammer", HUNTER) and crack_bone(id):
				return true
			hand_note = "Lay the marrow bone on the hunters’ stone and use the hammerstone."
		"hide":
			if _tool_at("scraper", HUNTER) and clean_hide(id):
				hand_note = "The clean hide is ready to stretch on the rack."
				return true
			hand_note = "Use the scraper on the fresh hide at the hunters’ board."
		"clean_hide":
			if _tool_at("scraper", parcel.rest) or _tool_at("flake", parcel.rest):
				return cut_binding(id, false)
			hand_note = "Use a stone edge on the stretched hide."
		"knot":
			if (_tool_at("scraper", MAKER) or _tool_at("flake", MAKER)) and scrape_knot(id):
				return true
			hand_note = "Lay the knot on Ina’s stone. Scrape it with the stone edge."
		"point", "shaft":
			if parcel.rest == MAKER and not parcel.prepared and (_tool_at("scraper", MAKER) or _tool_at("hammer", MAKER)):
				parcel.prepared = true
				revision += 1
				lessons.note(MAKER, parcel.kind, "you prepared the " + parcel.kind, "Good. A clean seating face keeps the pitch from taking all the strain.")
				return true
			hand_note = "Prepare the point and shaft on Ina’s stone with a stone tool."
		"meat":
			if parcel.condition() == "Charred" and parcel.rest != HAND:
				discarded += parcel.grams
				_take(parcel, parcel.grams)
				return true
			if parcel.grams > 180 and parcel.rest in [HUNTER, COOK] and _tool_at("flake", parcel.rest):
				_take(parcel, 180)
				inherit_cut(add("meat", 180, parcel.rest), parcel)
				hand_note = "You cut a portion sized for the spit."
				return true
			hand_note = "Use a sharp flake to portion meat on a board."
	return false

func _fit_physical(id: int) -> bool:
	var hunter := gear_name(id)
	if hunter.is_empty() or gear[hunter].at != MAKER:
		hand_note = "Carry the spear to Ina’s stone first."
		return false
	var point := _component("point")
	var shaft := _component("shaft")
	var rebuild := point != null and point.prepared and shaft != null and shaft.prepared
	if haft(hunter, rebuild):
		return true
	hand_note = "Keep workable adhesive and a binding on the stone. A cracked shaft needs a prepared point and shaft."
	return false

func inspect_object(id: int) -> String:
	if id < 0:
		var hunter := gear_name(id)
		var condition: float = gear[hunter].condition
		if condition >= 0.86 and lessons.has(MAKER, "haft") and not lessons.has(MAKER, "inspect_tool"):
			lessons.note(MAKER, "inspect_tool", "you tested the finished point and found it held",
				"Aye. It holds against the hand. Leave it on the rack for the hunter.")
		return "%s · %s" % [object_label(id), "The haft holds." if condition >= 0.67 else (
			"The point shifts against its binding." if condition >= 0.2 else "The shaft is cracked.")]
	var parcel: Parcel = parcels.get(id)
	if parcel == null:
		return ""
	if parcel.kind == "carcass" and not lessons.has(HUNTER, "look"):
		lessons.note(HUNTER, "look", "you examined the flesh, fat, bone and skin of the carcass")
	if parcel == roast:
		var face := "First" if parcel.face == 0 else "Second"
		return "%s · %s face towards the red. %s" % [parcel.label(), face,
			"The centre is warm through." if parcel.core >= 65 else "The centre is still cool."]
	return "%s · %d g · %s" % [object_label(id), parcel.grams, parcel.rest]

func workplace_words(place: String) -> String:
	var things := PackedStringArray()
	match place:
		HUNTER:
			for kind: String in ["carcass", "meat", "bone", "spent_bone", "hide", "clean_hide"]:
				if not stock(kind, HUNTER).is_empty():
					things.append(LABELS[kind])
		COOK:
			if roast != null:
				things.append(roast.label() + " on the spit")
			if not stock("meat", COOK).is_empty():
				things.append("Cuts on the board")
		MAKER:
			for kind: String in ["knot", "resin", "pitch", "binding", "point", "shaft"]:
				if not stock(kind, MAKER).is_empty():
					things.append(LABELS[kind])
			for hunter: String in GEAR_IDS:
				if gear[hunter].at == MAKER:
					things.append(object_label(gear_id(hunter)))
		STORE:
			return "Food laid out to share" if food_on_shelf() > 0 else "No food ready to share"
		HIDE_RACK:
			return "Clean hide stretched for binding strips" if not stock("clean_hide", HIDE_RACK).is_empty() else "The rack is clear"
	return " · ".join(things) if not things.is_empty() else "The working surface is clear"
