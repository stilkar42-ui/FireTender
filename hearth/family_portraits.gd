extends RefCounted
## Shared portrait lookup for family cards, dialogue and reports.

const Roster := preload("res://sim/family_roster.gd")
const LEGACY := {
	Roster.SPEAKER: "res://hearth/fire_speaker.svg",
	Roster.SCOUT: "res://hearth/torch_bearer.png",
}

static func path_for(id: String) -> String:
	if id == Roster.APPRENTICE or not Roster.PEOPLE.has(id):
		return ""
	return LEGACY.get(id, "res://hearth/art/family/%s.webp" % id)

static func read(id: String) -> Texture2D:
	var path := path_for(id)
	return load(path) as Texture2D if not path.is_empty() else null
