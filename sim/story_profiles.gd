extends RefCounted
## Numbered directories keep profile names separate from save paths.

const Save := preload("res://sim/chapter_save.gd")
const PROFILES := 5
const SLOTS := 10

var folder := "user://profiles"
var legacy_path := "user://chapter-iii.sav"
var active := 0
var names := PackedStringArray()

func _init() -> void:
	for profile in range(PROFILES):
		names.append("Profile %d" % (profile + 1))

func read_preferences() -> void:
	var data := ConfigFile.new()
	if data.load(folder.path_join("profiles.cfg")) != OK:
		return
	active = clampi(int(data.get_value("profiles", "active", 0)), 0, PROFILES - 1)
	var saved: Variant = data.get_value("profiles", "names", [])
	if saved is PackedStringArray and saved.size() == PROFILES:
		for profile in range(PROFILES):
			var name: String = saved[profile].strip_edges().left(24)
			if not name.is_empty():
				names[profile] = name

func select(profile: int) -> Error:
	if profile < 0 or profile >= PROFILES:
		return ERR_INVALID_PARAMETER
	active = profile
	return _store_preferences()

func rename_active(words: String) -> Error:
	var name := words.strip_edges().left(24)
	if name.is_empty():
		return ERR_INVALID_PARAMETER
	names[active] = name
	return _store_preferences()

func _store_preferences() -> Error:
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if result != OK:
		return result
	var data := ConfigFile.new()
	data.set_value("profiles", "active", active)
	data.set_value("profiles", "names", names)
	return data.save(folder.path_join("profiles.cfg"))

func slot_path(slot: int) -> String:
	if slot < 0 or slot >= SLOTS:
		return ""
	return folder.path_join("profile-%d/slot-%02d.sav" % [active + 1, slot + 1])

func load_path(slot: int) -> String:
	var path := slot_path(slot)
	if not legacy_path.is_empty() and active == 0 and slot == 0 \
			and not FileAccess.file_exists(path) and FileAccess.file_exists(legacy_path):
		return legacy_path
	return path

func first_empty() -> int:
	for slot in range(SLOTS):
		if not FileAccess.file_exists(load_path(slot)):
			return slot
	return -1

func list_slots() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for slot in range(SLOTS):
		var path := load_path(slot)
		var present := FileAccess.file_exists(path)
		var entry := {"slot": slot, "present": present, "act": 0, "time": 0.0, "saved_at": 0.0, "legacy": path == legacy_path}
		if present:
			var state := Save.read_slot(path)
			entry.act = Save.saved_act(state)
			var saved_fire: Variant = state.get("fire")
			if entry.act > 0 and saved_fire is Dictionary:
				entry.time = float(saved_fire.get("time", 0.0))
				entry.saved_at = float(state.get("saved_at", FileAccess.get_modified_time(path)))
			else:
				entry.act = 0
		entries.append(entry)
	return entries

static func newest_first(entries: Array[Dictionary]) -> Array[Dictionary]:
	var readable := entries.filter(func(entry: Dictionary) -> bool: return entry.act > 0)
	readable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved_at > b.saved_at)
	return readable
