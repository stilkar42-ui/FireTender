extends RefCounted
## Story saves use data-only Variants. Object graphs are rebuilt
## explicitly and verified on a detached hearth before replacing the live one.

const Chapter := preload("res://sim/red_hollow.gd")
const Fire := Chapter.Fire
const Work := Chapter.Family.Workshop
const Mentor := preload("res://sim/mentor.gd")
const VERSION := 4
const MAX_BYTES := 24 * 1024 * 1024
const FIRE_SKIP := ["wood", "stored", "coals", "sparks", "breaths", "falling", "cells", "shelter", "smoke_field",
	"nodes", "links", "radiant_links", "fuel_stock"]
const PIECE_SKIP := ["sections", "faces", "inner", "core", "pose"]
const WORK_SKIP := ["fire", "parcels", "roast", "resin", "lessons", "techniques"]
const FAMILY_SKIP := ["fire", "weather", "workshop", "rng", "land", "craft", "stormfall"]
const CHAPTER_SKIP := ["fire", "weather", "sequel", "family", "gathering", "land"]

static func write_slot(path: String, chapter: Chapter, mentor: Mentor, view_state := {}) -> Error:
	var state := capture(chapter, mentor)
	state.view = view_state
	return write_state(path, state)

static func write_state(path: String, state: Dictionary) -> Error:
	var bytes := var_to_bytes(state)
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		return ERR_INVALID_DATA
	path = ProjectSettings.globalize_path(path)
	var folder := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if folder != OK:
		return folder
	var temp := "%s.%d.%d.writing" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var handle := FileAccess.open(temp, FileAccess.WRITE)
	if handle == null:
		return FileAccess.get_open_error()
	handle.store_buffer(_digest(bytes))
	handle.store_buffer(bytes)
	handle.flush()
	var status := handle.get_error()
	handle.close()
	if status == OK:
		status = DirAccess.rename_absolute(temp, path)
	if status != OK:
		DirAccess.remove_absolute(temp)
	return status

static func read_slot(path: String) -> Dictionary:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null or handle.get_length() <= 32 or handle.get_length() > MAX_BYTES + 32:
		return {}
	var digest := handle.get_buffer(32)
	var bytes := handle.get_buffer(handle.get_length() - 32)
	if _digest(bytes) != digest:
		return {}
	var state: Variant = bytes_to_var(bytes)
	if not state is Dictionary or state.get("version", -1) not in [1, 2, 3, VERSION]:
		return {}
	return state

static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()

static func capture(chapter: Chapter, mentor: Mentor = null) -> Dictionary:
	var state := {
		"version": VERSION,
		"act": act(chapter),
		"saved_at": Time.get_unix_time_from_system(),
		"chapter": _plain(chapter, CHAPTER_SKIP),
		"weather": _plain(chapter.weather),
		"fire": _capture_fire(chapter.fire),
		"gathering": _plain(chapter.gathering),
		"field_land": _plain(chapter.land),
		"mentor": {} if mentor == null else _plain(mentor, ["conversation"]),
		"conversation": {} if mentor == null else _plain(mentor.conversation, ["chapter", "knowledge"]),
	}
	if chapter.sequel != null:
		state.sequel = _plain(chapter.sequel, ["fire"])
	var family := chapter.family
	if family == null:
		return state
	var work := family.workshop
	var parcels: Array[Dictionary] = []
	for parcel in work.parcels.values():
		parcels.append(_plain(parcel))
	state.merge({
		"family": _plain(family, FAMILY_SKIP),
		"rng": family.rng.state,
		"land": _plain(family.land),
		"work": _plain(work, WORK_SKIP),
		"parcels": parcels,
		"roast": 0 if work.roast == null else work.roast.id,
		"resin": 0 if work.resin == null else work.resin.id,
		"lessons": _plain(work.lessons),
		"techniques": _plain(work.techniques),
		"craft": _plain(family.craft),
		"stormfall": _plain(family.stormfall),
	})
	return state

static func act(chapter: Chapter) -> int:
	if chapter.family != null:
		return 3
	return 2 if chapter.sequel != null else 1

static func saved_act(state: Dictionary) -> int:
	var value: Variant = state.get("act", 3 if state.get("version") in [1, 2] else 0)
	return value if value is int and value in [1, 2, 3] else 0

static func restore(chapter: Chapter, state: Dictionary, mentor: Mentor = null) -> bool:
	var saved_chapter := saved_act(state)
	if saved_chapter == 0:
		return false
	var required := ["chapter", "weather", "fire", "mentor", "conversation"]
	if saved_chapter >= 2:
		required.append("sequel")
	if saved_chapter == 3:
		required.append_array(["family", "land", "work", "lessons"])
	for key: String in required:
		if not state.get(key) is Dictionary:
			return false
	var legacy_gathering: bool = not state.has("gathering")
	var original_chapter: Dictionary = state.chapter
	if legacy_gathering:
		state = state.duplicate()
		state.chapter = original_chapter.duplicate()
		state.chapter.merge({"field_reports": {}, "pickup_at": 0.0, "picked_up": false,
			"trip_observation": {}}, true)
		state.chapter.carried_load = PackedInt32Array()
	if not state.chapter.has("tinder_bundle_known"):
		state = state.duplicate()
		state.chapter = state.chapter.duplicate()
		state.chapter.tinder_bundle_known = false
	var missing_storm_reserve: bool = not state.chapter.has("storm_reserve")
	if missing_storm_reserve:
		state = state.duplicate()
		state.chapter = state.chapter.duplicate()
		state.chapter.storm_reserve = []
	if not state.fire.has("starter_ventilation"):
		state = state.duplicate()
		state.fire = state.fire.duplicate()
		state.fire.starter_ventilation = PackedFloat64Array()
		state.fire.network_dirty = true
	if not state.fire.has("tinder_job"):
		state = state.duplicate()
		state.fire = state.fire.duplicate()
		state.fire.tinder_job = {}
	if not (_put(chapter, state.chapter, CHAPTER_SKIP) and _put(chapter.weather, state.weather) \
		and _restore_fire(chapter.fire, state.fire)):
		return false
	if legacy_gathering:
		if not _restore_legacy_gathering(chapter, original_chapter, saved_chapter):
			return false
	elif not (_put(chapter.gathering, state.get("gathering", {})) and _put(chapter.land, state.get("field_land", {}))):
		return false
	if missing_storm_reserve and saved_chapter == 1 and chapter.fire.time >= Chapter.Quests.RESERVE_AT:
		chapter.storm_reserve = Chapter.Quests.storm_reserve(chapter.fire)
	if saved_chapter >= 2:
		chapter.sequel = Chapter.AfterStorm.new(chapter.fire)
		var sequel_data: Dictionary = state.sequel
		var legacy_drying := not sequel_data.has("drying_records")
		if legacy_drying:
			sequel_data = sequel_data.duplicate()
			sequel_data.drying_records = {}
			sequel_data.drying_complete = {}
		if not _put(chapter.sequel, sequel_data, ["fire"]):
			return false
		if legacy_drying and saved_chapter == 2 and chapter.outcome.is_empty():
			chapter.lay_out_drying_logs()
			chapter.fire.receive_fuel(12, Vector2(0.60, 1.12), PI * 0.5, 0, 0.49)
			chapter.fire.seat_new_stock()
			for piece in chapter.fire.all_fuel():
				chapter.sequel.track(piece)
	if saved_chapter == 3 and not _restore_family(chapter, state):
		return false
	if chapter.family != null:
		if legacy_gathering:
			chapter.land = chapter.family.land
		else:
			chapter.family.land = chapter.land
	if mentor != null:
		mentor.begin_chapter(chapter)
		if not state.mentor.is_empty() and not (_put(mentor, state.mentor, ["conversation"]) \
			and _put(mentor.conversation, state.conversation, ["chapter", "knowledge"])):
			return false
	return true

static func _restore_legacy_gathering(chapter: Chapter, prior: Dictionary, saved_chapter: int) -> bool:
	var stock: Array = prior.get("sites", [])
	if stock.size() != Chapter.ROUTES.size():
		return false
	for patches in stock:
		if not patches is Array or not patches.all(func(patch): return patch is Dictionary):
			return false
	chapter.gathering.initialize(Chapter.ROUTES, stock)
	if saved_chapter >= 2:
		# Older games already received the shelter stormfall. Translate the
		# surviving field wood to its old delivery condition once.
		chapter.gathering.restore_legacy_aftermath(chapter.weather.temperature, Chapter.Shelter.END)
	if chapter.away >= 0:
		if chapter.away >= Chapter.ROUTES.size() or not prior.get("carried_load") is Array:
			return false
		var selected := PackedInt32Array()
		for key in prior.carried_load:
			if not key is Vector2i:
				return false
			for piece: Dictionary in chapter.gathering.records[chapter.away].pieces:
				if piece.patch == key.x and piece.kind == key.y and piece.state == "available" and not piece.id in selected:
					selected.append(piece.id)
					break
		chapter.carried_load = selected
		chapter.pickup_at = (chapter.fire.time + chapter.returns_at) * 0.5
	return true

static func _restore_family(chapter: Chapter, state: Dictionary) -> bool:
	if not state.get("parcels") is Array or not state.get("rng") is int:
		return false
	chapter.family = Chapter.Family.new(chapter.fire)
	var family := chapter.family
	var work := family.workshop
	var legacy: bool = state.get("version") == 1
	if legacy:
		state = state.duplicate(true)
		state.family.merge(_plain(family, FAMILY_SKIP))
		state.work.merge(_plain(work, WORK_SKIP))
		for parcel in state.parcels:
			parcel.merge({"species": "", "freshness": 1.0, "edge": 1.0})
	elif not (_put(work.techniques, state.get("techniques", {})) and _put(family.craft, state.get("craft", {}))
		and _put(family.stormfall, state.get("stormfall", {}))):
		return false
	if not (_put(family, state.family, FAMILY_SKIP) and _put(family.land, state.land) \
		and _put(work, state.work, WORK_SKIP) and _put(work.lessons, state.lessons)):
		return false
	family.rng.state = state.rng
	work.parcels.clear()
	for entry in state.parcels:
		var parcel := Work.Parcel.new()
		if not entry is Dictionary or not _put(parcel, entry) or parcel.id <= 0 or parcel.grams <= 0 			or not Work.LABELS.has(parcel.kind) or not parcel.at.is_finite() or work.parcels.has(parcel.id):
			return false
		work.parcels[parcel.id] = parcel
	if not state.get("roast") is int or not state.get("resin") is int:
		return false
	if legacy:
		family.craft.begin(chapter.fire.time)
		family.stormfall.begin(chapter.fire.time)
		family.next_spoil = chapter.fire.time + 6.0
		work.kin_cup_id = work.add("vessel", 153, Work.MAKER).id
		for pair in [[Work.HUNTER, "crack", Work.Techniques.MARROW, "Bera"], [Work.COOK, "meal", Work.Techniques.ROAST, "Nara"],
			[Work.MAKER, "pitch", Work.Techniques.RESIN, "Ina"], [Work.MAKER, "haft", Work.Techniques.HAFT, "Ina"]]:
			if work.lessons.has(pair[0], pair[1]):
				work.techniques.practice(pair[2], pair[3])
	work.roast = work.parcels.get(state.roast)
	work.resin = work.parcels.get(state.resin)
	if not work.parcels.has(work.cup_id) or work.parcels[work.cup_id].kind != "vessel":
		return false
	if (state.roast != 0 and work.roast == null) or (state.resin != 0 and work.resin == null) or work.cup_fill != state.resin:
		return false
	if work.held != 0 and work.object_rest(work.held) != Work.HAND:
		return false
	return true

static func _names(object: Object, skip: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for property in object.get_property_list():
		var key: String = property.name
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and key not in skip:
			names.append(key)
	return names

static func _plain(object: Object, skip: Array = []) -> Dictionary:
	var data := {}
	for key in _names(object, skip):
		var value: Variant = object.get(key)
		if value is Array or value is Dictionary:
			data[key] = value.duplicate(true)
		else:
			data[key] = value
	return data

static func _put(object: Object, data: Dictionary, skip: Array = []) -> bool:
	for key in _names(object, skip):
		if not data.has(key):
			return false
		var current: Variant = object.get(key)
		var saved: Variant = data[key]
		if typeof(current) != typeof(saved):
			return false
		if current is Array or current is Dictionary:
			# Assign through a copy to keep the slot detached and preserve typing.
			var typed: Variant = current.duplicate()
			typed.assign(saved.duplicate(true))
			object.set(key, typed)
		else:
			object.set(key, saved)
	return true

static func _capture_fire(fire: Fire) -> Dictionary:
	var indices := {}
	var fields := _plain(fire, FIRE_SKIP)
	for group: String in ["wood", "stored", "coals"]:
		var parts: Array[Dictionary] = []
		for piece: Fire.Piece in fire.get(group):
			parts.append(_piece(piece, indices))
		fields[group] = parts
	if not fire.network_dirty:
		fields.node_refs = fire.nodes.map(func(piece): return indices.get(piece, -1))
		fields.links = _objects(fire.links)
		fields.radiant_links = _objects(fire.radiant_links)
	fields.breaths = _objects(fire.breaths)
	fields.falling = _objects(fire.falling)
	fields.smoke = _plain(fire.smoke_field, ["parcels"])
	fields.smoke.parcels = _objects(fire.smoke_field.parcels)
	fields.sparks = []
	for spark in fire.sparks:
		var data := _plain(spark, ["receiver", "surface"])
		data.receiver = indices.get(spark.receiver, -1)
		data.surface = indices.get(spark.surface, -1)
		fields.sparks.append(data)
	return fields

static func _objects(items: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		result.append(_plain(item))
	return result

static func _piece(piece: Fire.Piece, indices: Dictionary) -> Dictionary:
	var data := _plain(piece, PIECE_SKIP)
	data.index = indices.size()
	indices[piece] = data.index
	for group in ["sections", "faces", "inner"]:
		data[group] = []
		for part: Fire.Piece in piece.get(group):
			data[group].append(_piece(part, indices))
	data.core = {} if piece.core == null else _piece(piece.core, indices)
	data.pose = {} if piece.pose == null else _plain(piece.pose)
	return data

static func _restore_fire(fire: Fire, data: Dictionary) -> bool:
	if not _put(fire, data, FIRE_SKIP) or not data.get("smoke") is Dictionary:
		return false
	var indices := {}
	for group: String in ["wood", "stored", "coals"]:
		var result: Variant = _parts(data.get(group), indices, 0)
		if result == null:
			return false
		var pieces: Array[Fire.Piece] = []
		pieces.assign(result)
		fire.set(group, pieces)
	fire.breaths.clear()
	fire.falling.clear()
	fire.sparks.clear()
	if not _put(fire.smoke_field, data.smoke, ["parcels"]):
		return false
	fire.smoke_field.parcels.clear()
	for descriptor in [
		[data.get("breaths"), fire.breaths, func(): return Fire.Breath.new()],
		[data.get("falling"), fire.falling, func(): return Fire.Residue.new()],
		[data.smoke.get("parcels"), fire.smoke_field.parcels, func(): return Fire.SmokeField.Parcel.new()],
	]:
		if not descriptor[0] is Array:
			return false
		for fields in descriptor[0]:
			var item: Object = descriptor[2].call()
			if not fields is Dictionary or not _put(item, fields):
				return false
			descriptor[1].append(item)
	if not data.get("sparks") is Array:
		return false
	for fields in data.sparks:
		var spark := Fire.Spark.new()
		if not fields is Dictionary or not _put(spark, fields, ["receiver", "surface"]):
			return false
		spark.receiver = indices.get(fields.get("receiver", -1))
		spark.surface = indices.get(fields.get("surface", -1))
		fire.sparks.append(spark)
	fire._reindex()
	fire.nodes.clear()
	fire.links.clear()
	fire.radiant_links.clear()
	if not fire.network_dirty and not _restore_topology(fire, data, indices):
		return false
	return true

static func _restore_topology(fire: Fire, data: Dictionary, indices: Dictionary) -> bool:
	if not data.get("node_refs") is Array:
		return false
	for id in data.node_refs:
		if not indices.has(id):
			return false
		fire.nodes.append(indices[id])
	for group: String in ["links", "radiant_links"]:
		if not data.get(group) is Array:
			return false
		var links: Array[Fire.Link] = []
		for fields in data[group]:
			var link := Fire.Link.new()
			if not fields is Dictionary or not _put(link, fields):
				return false
			if link.a < 0 or link.b < 0 or maxi(link.a, link.b) >= fire.nodes.size():
				return false
			links.append(link)
		fire.set(group, links)
	return true

static func _parts(data: Variant, indices: Dictionary, depth: int) -> Variant:
	if not data is Array or depth > 7:
		return null
	var pieces: Array[Fire.Piece] = []
	for fields in data:
		if not fields is Dictionary:
			return null
		var piece := _read_piece(fields, indices, depth)
		if piece == null:
			return null
		pieces.append(piece)
	return pieces

static func _read_piece(data: Dictionary, indices: Dictionary, depth: int) -> Fire.Piece:
	var piece := Fire.Piece.new()
	if depth > 7 or not _put(piece, data, PIECE_SKIP) or not data.get("index") is int 		or not data.get("pose") is Dictionary or not data.get("core") is Dictionary:
		return null
	indices[data.index] = piece
	for group: String in ["sections", "faces", "inner"]:
		var parts: Variant = _parts(data.get(group), indices, depth + 1)
		if parts == null:
			return null
		piece.set(group, parts)
	if not data.core.is_empty():
		piece.core = _read_piece(data.core, indices, depth + 1)
		if piece.core == null:
			return null
	if not data.pose.is_empty():
		piece.pose = Fire.Structure.Pose.new()
		if not _put(piece.pose, data.pose):
			return null
	return piece

