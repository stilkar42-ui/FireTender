extends RefCounted
## Techniques are recollections. The workshop still owns every physical result.

const MARROW := "marrow"
const ROAST := "roast"
const RESIN := "resin"
const HAFT := "haft"
const TINDER := "tinder_bundle"
const BOOK := {
	TINDER: ["Tinder Bundle", "Eren", "Any two parcels of raw tinder", "Hands", "Dry tinder catches more easily.", "Work the tinder loose, cup it in your hands and carry a glowing ember into the hollow. Give it a soft breath.", "The glow spreads through the bundle and the kindling above begins to catch.", "Damp tinder draws away heat. A tightly packed bundle limits air."],
	MARROW: ["Extract marrow", "Bera", "Intact marrow bone", "Hammerstone and working stone", "A stable stone. No heat needed.", "Set the long bone down. Strike across the shaft, then pick the marrow clear of the splinters.", "The split opens along the bone and exposes pale, soft marrow.", "A loose rest scatters fragments into the marrow."],
	ROAST: ["Roast bison meat", "Nara", "A small, fresh portion of bison or other game", "Sharp flake and spit", "Steady red beside the coals, clear of high flame.", "Cut a small portion. Set it near the red, turn the pale face toward the heat and lift it to the shelf once the centre is warm.", "Two browned faces and a warm centre.", "High flame blackens the outside. Leaving one side down dries it before the centre warms."],
	RESIN: ["Prepare resin adhesive", "Ina", "Resin scraped from a sticky knot", "Stone edge and cup", "Indirect warmth. The resin should soften without smoking.", "Scrape the knot into the cup. Set the cup on the warm stone and lift it when the resin runs together.", "The gritty lumps soften and the adhesive runs evenly.", "Smoke and a brittle residue mean too much heat."],
	HAFT: ["Repair a hafted hunting tool", "Ina", "Loose spear, adhesive and rawhide binding. A broken haft also needs a prepared point and shaft.", "Scraper and maker’s stone", "Workable adhesive. Keep the haft clear of the fire.", "Dress the seating face. Seat the point, press in the adhesive and bind the haft. Test sideways before returning the spear.", "The point holds against sideways pressure.", "A rocking point or loose binding will shift on the trail."],
}
const LEVELS := ["Unfamiliar", "Learning", "Practiced", "Competent", "Skilled"]
var player: Dictionary = {}
var learned_from: Dictionary = {}
var specialists := {"bera": 7, "nara": 9, "ina": 10, "mira": 4}
var revision := 0

func rank(technique: String) -> int:
	var xp: int = player.get(technique, 0)
	return 4 if xp >= 15 else (3 if xp >= 9 else (2 if xp >= 5 else (1 if xp > 0 else 0)))

func teach(technique: String, by: String) -> void:
	if not player.has(technique):
		player[technique] = 1
		learned_from[technique] = by
		revision += 1

func practice(technique: String, by: String) -> void:
	teach(technique, by)
	player[technique] = mini(30, player[technique] + 2)
	revision += 1

func finish_job(worker: String) -> void:
	specialists[worker] = mini(80, int(specialists.get(worker, 0)) + 1)
	revision += 1

func reading() -> String:
	var lines := PackedStringArray()
	for key: String in BOOK:
		if not player.has(key):
			continue
		var recipe: Array = BOOK[key]
		lines.append("[color=#f0b77b][b]%s[/b][/color] · %s\nLearned from %s\n%s · %s\n%s\n%s\nWatch for %s\n%s" %
			[recipe[0], LEVELS[rank(key)], learned_from[key], recipe[2], recipe[3], recipe[4], recipe[5], recipe[6].left(1).to_lower() + recipe[6].substr(1), recipe[7]])
	return "\n\n".join(lines) if not lines.is_empty() else "Ask Bera, Nara or Ina to show you their work. Techniques you learn will be remembered here."
