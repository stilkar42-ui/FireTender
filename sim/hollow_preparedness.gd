extends RefCounted
## Practical estimates for the Speaker. This reads the model and never spends supplies.
const Fire := preload("res://sim/fire.gd")
const Shelter := preload("res://sim/red_hollow_shelter.gd")

const WOOD := ["tinder", "small", "medium", "large"]
const Groups := preload("res://sim/story_quests.gd")
const BASE := [0.014, 0.105, 0.28, 0.55]
const LONG_WET := [0.012, 0.17, 0.48, 1.05]
const ENOUGH := [
	"There are dry fibres enough to wake the red again. Keep them loose and save a little under cover.",
	"We have enough dry twigs and sticks to build the flame back if it weakens.",
	"There are enough sound branches to keep a useful flame once the small wood catches.",
	"The dry splits should carry a living bed through this stretch, if you feed them as the fire takes them.",
]
const SHORT := [
	"We’re short of dry tinder to wake a faint coal. Keep the finest dry fibres under cover.",
	"There’s too little dry small wood to build the flame back. A cold split will ask too much of it.",
	"We have too few dry branches to keep a useful flame for long. Give the small wood time to make red underneath.",
	"We’re short of sound larger wood. A few dry splits would give us something to feed the bed.",
]
const SHORT_RAIN := [
	"The dry tinder might wake the red once. Keep more under cover in case the rain makes you wake it again.",
	"The small dry wood could carry us through a short rain. A long wet spell will ask for more.",
	"The branches could keep a flame through a passing shower. There’s too little dry wood for rain that sits.",
	"The larger wood would carry us through a short rain. We have too little dry reserve for this long stretch.",
]

static func answer(fire: Fire, weather: Shelter, topic: String) -> String:
	var wet := weather.wet_watch()
	var reserve := _dry_wood(fire, weather, wet)
	var group := WOOD.find(topic)
	if group >= 0:
		return _wood_line(group, reserve[group], wet)
	var red := 0.0
	var ash_needed := 0.0
	var hot_patches := 0
	for coal in fire.coals:
		if coal.carried or coal.char_mass < 0.0007 or coal.temperature < 338.0 or not fire.in_hearth(coal.at):
			continue
		var live := smoothstep(325.0, 540.0, coal.temperature)
		var damp := clampf(coal.water / maxf(0.001, coal.char_mass), 0.0, 1.0)
		red += coal.char_mass * live * (1.0 - 0.55 * damp)
		hot_patches += 1
		ash_needed += maxf(0.0, lerpf(0.003, 0.008, wet) - coal.cover)
	var bed_ready := red >= lerpf(0.035, 0.085, wet)
	if topic == "ash":
		if hot_patches == 0:
			return "Save the loose ash for when we have red to cover. Ash alone won’t carry a cold hearth through the night."
		if ash_needed <= 0.0001:
			return "There is already enough ash over the red. Let it rest, and leave it a little breath."
		if fire.ash >= ash_needed:
			return "There is enough loose ash to hide the red%s. Sift it over once the flames settle." % (" through the wet" if wet > 0.52 else " for a rest")
		return "There is too little loose ash to cover the living patches. Sweep up what the wood leaves before you try to bank them."
	if topic == "coals":
		if bed_ready:
			return "The bed has deep red enough to try a rest%s. Cover it lightly and look in on it when the wind turns." % (" through the rain" if wet > 0.52 else "")
		if red > 0.035:
			return "That red can take a short rest. It needs a deeper bed before I would leave it through rain that stays."
		return "There’s too little living red for a long rest. Grow the bed with small dry wood before you cover it."
	if wet < 0.52 and not bed_ready and fire.total_flame() < 3.0:
		return "The red is still slight. " + _wood_line(0, reserve[0], wet)
	var order := [3, 2, 1, 0] if wet > 0.52 else [1, 2, 0, 3]
	for index: int in order:
		if reserve[index] < BASE[index] + wet * LONG_WET[index]:
			return ("The coal bed is strong. " if bed_ready else "") + _wood_line(index, reserve[index], wet)
	return "The dry wood looks enough for this stretch. " + ("Keep the ash ready and check the red when the wind turns." if bed_ready else "Grow a deeper bed of red before you settle it under ash.")

static func _dry_wood(fire: Fire, weather: Shelter, wet: float) -> PackedFloat32Array:
	var dry := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for piece in fire.all_fuel():
		if fire.in_hearth(piece.at) or piece.airborne or piece.flame > 0.2 or piece.wood <= 0.0:
			continue
		var group := Groups.size_group(piece.kind)
		var moisture := piece.water / maxf(0.00001, piece.wood)
		var usable := 1.0 - smoothstep(0.14, 0.31, moisture)
		var exposed := maxf(weather.rain_at(piece.at), wet * smoothstep(0.54, 0.96, weather.exposure(piece.at)))
		var mass := minf(0.010, piece.wood) if piece.kind == 0 else piece.wood
		dry[group] += mass * usable * (1.0 - 0.63 * exposed)
	return dry

static func _wood_line(group: int, dry: float, wet: float) -> String:
	if dry >= BASE[group] + wet * LONG_WET[group]:
		return ENOUGH[group]
	if dry >= BASE[group]:
		return SHORT_RAIN[group]
	return SHORT[group]
