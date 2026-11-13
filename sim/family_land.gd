extends RefCounted
## The map keeps small, dated recollections. Nothing here reads field state.

const Work := preload("res://sim/family_workshop.gd")
const Shelter := preload("res://sim/red_hollow_shelter.gd")
const HOME := "Red Hollow"
const SHELF := "Rocky shelf"
const PINE := "Fallen pine in the lee"
const WOODS := "Sheltered woodland"
const STREAM := "Stream"
const TRAIL := "Deer trail"
const MEADOW := "Open grazing ground"
const RIDGE := "Far oak ridge"
const ROUTE_PLACES := [SHELF, PINE, RIDGE, SHELF, WOODS, STREAM]
const FADING_AFTER := 105.0
const TERRITORY := {
	HOME: [Vector2(309, 201), "shelter", "Red Hollow", "Stone Mountain’s kin keep their fire under this limestone lip."],
	SHELF: [Vector2(208, 280), "ridge", "Rocky shelf", "The bark ledge shelters loose fibres. The sky path looks out over the valley."],
	PINE: [Vector2(131, 117), "wood", "Fallen pine", "The old pine lies in the lee of the slope."],
	WOODS: [Vector2(110, 205), "wood", "Sheltered woodland", "Standing dead birch breaks up the cover. Hunters look for hare here."],
	STREAM: [Vector2(315, 314), "water", "Stream", "Willows bend over the water. Tavi knows where to wash edible roots."],
	TRAIL: [Vector2(471, 208), "tracks", "Deer trail", "A worn path crosses the slope within sight of the rocky shelf."],
	MEADOW: [Vector2(494, 119), "animal", "Open grazing ground", "Deer may move across the open ground between the trail and the ridge."],
	RIDGE: [Vector2(311, 79), "ridge", "Far oak ridge", "The long climb leads to the oaks. Rain and poor light make the way back harder."],
}
const INSIDE := {
	HOME: [Vector2(305, 320), "shelter", "Family shelter", "Kin gather under the limestone lip, where the paths meet the shelter.", Vector2(0, 1.1)],
	"Hearth": [Vector2(305, 236), "fire", "Hearth", "The living hearth gives warmth to the shelter and its working stones.", Vector2.ZERO],
	"Dry shelf": [Vector2(105, 80), "wood", "Dry shelf", "The back-left shelf protects seasoned wood under the stone.", Vector2(-1.89, -3.21)],
	"Tinder alcove": [Vector2(104, 161), "wood", "Tinder alcove", "Dry fibres stay under cover here, well away from jumping cinders.", Vector2(-1.94, -2.28)],
	"Warming edge": [Vector2(107, 245), "fire", "Warming edge", "Wet branches can borrow heat here before they are put on the fire.", Vector2(-1.02, -0.20)],
	"Seep": [Vector2(493, 80), "water", "Seep", "The back-right rock sweats after rain.", Shelter.SEEP],
	"Air passage": [Vector2(507, 159), "wind", "Air passage", "Air moves through the gap. A turning wind can pull smoke this way.", Shelter.PASSAGE],
	Work.MAKER: [Vector2(311, 147), "point", "Maker’s Stone", "Ina sorts points, binds hafts and warms resin near the red.", Work.MAKER_AT],
	Work.HUNTER: [Vector2(489, 240), "bone", "Hunter’s Working Place", "The hunters lay down their catch and spears. Mira scrapes hides at the board.", Work.HUNTER_AT],
	Work.COOK: [Vector2(108, 326), "food", "Cooking Place", "Nara prepares cuts here and watches the spits beside the coals.", Work.COOK_AT],
	Work.STORE: [Vector2(300, 73), "food", "Covered food shelf", "Roasts and roots go here to be shared.", Work.STORE_AT],
	Work.HIDE_RACK: [Vector2(489, 320), "bone", "Hide rack", "Cleaned hides stretch here. Their edges can be cut into bindings.", Work.HIDE_AT],
}
const PATHS := [
	[HOME, SHELF], [HOME, PINE], [PINE, WOODS], [PINE, RIDGE], [HOME, TRAIL],
	[SHELF, STREAM], [STREAM, TRAIL], [TRAIL, MEADOW], [MEADOW, RIDGE],
]

var places: Dictionary = {}
var revision := 0

func remember(place: String, kind: String, words: String, source: String, seen: float, learned: float, mark := "") -> void:
	if not TERRITORY.has(place) and not INSIDE.has(place):
		return
	if not places.has(place):
		places[place] = {}
	var entries: Dictionary = places[place]
	if entries.has(kind) and seen < entries[kind].seen:
		return
	var note := {"text": words, "source": source, "seen": seen, "learned": learned, "mark": mark}
	if entries.get(kind) == note:
		return
	entries[kind] = note
	revision += 1

static func stale(at: float, now: float) -> bool:
	return now - at >= FADING_AFTER

static func stamp(at: float) -> String:
	var elapsed := int(fposmod(at, Shelter.DAY))
	return "Day %d · %d:%02d" % [floori(at / Shelter.DAY) + 1, elapsed / 60, elapsed % 60]

static func weather_mark(rain: float, wind: float) -> String:
	if rain >= 0.08:
		return "rain"
	return "wind" if wind >= 0.25 else "sky"

static func weather_words(rain: float, wind: float) -> String:
	match weather_mark(rain, wind):
		"rain": return "Rain on the path"
		"wind": return "Wind across the path"
	return "Clear air along the path"
