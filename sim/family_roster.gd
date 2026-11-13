extends RefCounted
## The names are fictional English renderings. Parents and partners are the
## only links needed to describe the living household.

const APPRENTICE := "ember_tender"
const SCOUT := "torch_bearer"
const SPEAKER := "fire_speaker"
const ELDERS := ["sela", "oren", "dena"]
const PEOPLE := {
	"sela": ["Sela", "Maternal grandmother", "Elder", "Rations, plant foods and keeping children well", "Counting the food laid aside", "Red Hollow"],
	"oren": ["Oren", "Maternal grandfather", "Elder", "Reading tracks, judging ground and teaching hunters", "Showing Suri how to read a hoofprint", "Red Hollow"],
	"dena": ["Dena", "Paternal grandmother", "Elder", "First aid, shelter and judging when people need rest", "Checking Eren’s leg", "Red Hollow"],
	"nara": ["Nara", "Mother", "Cook", "Roasting meat, judging coals and sharing food", "Setting out the roasting spits", "Cooking Place"],
	"bera": ["Bera", "Father", "Hunter", "Stalking in woodland and carrying heavy game", "Checking his hunting spear", "Hunter’s Working Place"],
	"tavi": ["Tavi", "Mother’s sister", "Carer and gatherer", "Roots, clean water and caring for the children", "Sorting roots with Lio", "Red Hollow"],
	"ivo": ["Ivo", "Mother’s sister’s partner", "Hunter", "Flushing small game and following blood trails", "Preparing a carrying thong", "Hunter’s Working Place"],
	SPEAKER: ["Eren", "Mother’s brother", "Fire Speaker", "Keeping fire, reading wind and telling the old stories", "Resting his injured leg", "Red Hollow"],
	"kett": ["Kett", "Father’s brother", "Hunter", "Reading deer trails and hunting on open ground", "Feeling the edge of his point", "Hunter’s Working Place"],
	"ina": ["Ina", "Father’s sister", "Maker", "Choosing stone points, preparing pitch and hafting tools", "Sorting points and shafts", "Maker’s Stone"],
	APPRENTICE: ["You", "Yourself", "Ember Tender", "Keeping the living fire and learning to work with its heat", "Keeping the hearth", "Red Hollow"],
	"lio": ["Lio", "Younger sibling", "Child", "Learning to sort kindling and recognize edible roots", "Helping Tavi sort roots", "Red Hollow"],
	SCOUT: ["Rusk", "Mother’s sister’s son", "Torch Bearer", "Scouting paths, gathering wood and bringing news", "Listening for news by the mouth", "Red Hollow"],
	"mira": ["Mira", "Mother’s sister’s daughter", "Hide worker", "Scraping hides and cutting binding strips", "Laying out her scraping tools", "Hunter’s Working Place"],
	"suri": ["Suri", "Mother’s sister’s younger daughter", "Child", "Learning tracks and carrying small things for the elders", "Listening to Oren", "Red Hollow"],
}
const PARTNERS := [["sela", "oren"], ["nara", "bera"], ["tavi", "ivo"]]
const DESCENT := {
	"sela": ["nara", "tavi", SPEAKER],
	"oren": ["nara", "tavi", SPEAKER],
	"dena": ["bera", "kett", "ina"],
	"nara": [APPRENTICE, "lio"],
	"bera": [APPRENTICE, "lio"],
	"tavi": [SCOUT, "mira", "suri"],
	"ivo": [SCOUT, "mira", "suri"],
}

static func person_name(id: String) -> String:
	return PEOPLE[id][0]

const SAYINGS := {
	"sela": "Give the children their share before we talk about how far to send the hunters.",
	"oren": "A sharp point matters. So does a print with rainwater still running into it.",
	"dena": "Sit where the stone is warm. Tell me which step hurt.",
	"nara": "See the pale face? Turn that one toward the red. We can wait for the middle.",
	"bera": "Put your thumb against the haft. If the point moves under it, I’ll leave the spear here.",
	"tavi": "Lio can tell the good roots from the bitter ones now. Let him show you.",
	"ivo": "A hare can sit under a branch and watch you step over it.",
	SPEAKER: "I’ll sit here a while. Show me where the red is before you move a coal.",
	"kett": "A deer on open ground has already seen you by the time you see its ears.",
	"ina": "The pitch will run when it is ready. Take the cup off before it smokes.",
	"lio": "I put the little sticks where they’d stay dry. Did I put them far enough back?",
	SCOUT: "I’ll tell you what I saw, cousin. Ask me about the path before you spend your good wood.",
	"mira": "Leave the long edge of the hide for me. I can cut a binding that won’t split there.",
	"suri": "Oren says that print is from a deer. I thought it was two little stones.",
}
