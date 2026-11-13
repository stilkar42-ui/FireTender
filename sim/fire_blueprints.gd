extends RefCounted
## A blueprint describes geometry. Rebuilding resolves supports in the current hearth.

const Fire := preload("res://sim/fire.gd")
const VERSION := 1

var path := "user://fire-blueprints.cfg"
var plans: Dictionary = {}

func read() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK or file.get_value("blueprints", "version", 0) != VERSION:
		return
	var saved: Variant = file.get_value("blueprints", "plans", {})
	if saved is Dictionary:
		for name: Variant in saved:
			if name is String and valid(saved[name]):
				plans[name] = saved[name]

func save(title: String, layout: Array) -> Error:
	if title.is_empty() or not valid(layout):
		return ERR_INVALID_DATA
	var updated := plans.duplicate()
	updated[title] = layout.duplicate(true)
	var file := ConfigFile.new()
	file.set_value("blueprints", "version", VERSION)
	file.set_value("blueprints", "plans", updated)
	var destination := ProjectSettings.globalize_path(path)
	var folder := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if folder != OK:
		return folder
	var temporary := "%s.%d.writing" % [destination, OS.get_process_id()]
	var result := file.save(temporary)
	if result == OK:
		result = DirAccess.rename_absolute(temporary, destination)
	if result == OK:
		plans = updated
	elif FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	return result

static func capture(fire: Fire) -> Array[Dictionary]:
	var pieces := fire.wood.filter(func(piece: Fire.Piece) -> bool: return fire.in_hearth(piece.at))
	pieces.sort_custom(func(a: Fire.Piece, b: Fire.Piece) -> bool:
		return fire._rest_order(a) < fire._rest_order(b) if a.tier == b.tier else a.tier < b.tier)
	var layout: Array[Dictionary] = []
	for piece: Fire.Piece in pieces:
		if not _cold_whole(piece) or piece.pose == null:
			return []
		var amount: float = piece.original / float(Fire.SPECIES[piece.kind].mass) if piece.fibre else 1.0
		layout.append({"kind": piece.kind, "at": piece.at, "yaw": piece.axis.angle(), "lean": piece.lean,
			"tier": piece.tier, "height": piece.pose.height, "slope": piece.pose.slope, "fed": piece.fed,
			"roll": piece.roll_travel, "amount": amount})
	return layout

static func valid(layout: Variant) -> bool:
	if not layout is Array or layout.is_empty() or layout.size() > Fire.MAX_WOOD:
		return false
	for entry in layout:
		if not entry is Dictionary or not entry.get("kind") is int or not entry.get("at") is Vector2 \
				or not entry.get("tier") is int or not entry.get("fed") is bool:
			return false
		if entry.kind < 0 or entry.kind >= Fire.SPECIES.size() or not entry.at.is_finite() \
				or (entry.at / Fire.LIMIT).length_squared() > 1.00001 or absi(entry.tier) > 64:
			return false
		for key in ["yaw", "lean", "height", "slope", "roll", "amount"]:
			var value: Variant = entry.get(key)
			if not (value is float or value is int) or not is_finite(float(value)):
				return false
		if absf(entry.lean) > Fire.Structure.MAX_SLOPE or absf(entry.slope) > Fire.Structure.MAX_SLOPE \
				or entry.height < 0.0 or entry.height > 4.0 \
				or entry.amount < 0.09 or entry.amount > 12.01:
			return false
	return true

static func material_list(layout: Array) -> String:
	var counts := {}
	for item in layout:
		counts[item.kind] = int(counts.get(item.kind, 0)) + 1
	var lines := PackedStringArray()
	for kind in counts:
		lines.append("%d × %s" % [counts[kind], Fire.SPECIES[kind].label])
	return "  ·  ".join(lines)

static func rebuild(fire: Fire, layout: Array) -> String:
	if not valid(layout):
		return "This blueprint could not be read."
	if not fire.wood.is_empty():
		return "Clear the hearth of wood before rebuilding. A carried ember can stay outside the layout."
	var parcels: Array[Fire.Piece] = []
	if fire.shelter != null:
		for item in layout:
			var parcel: Fire.Piece
			for candidate in fire.stored:
				if candidate.kind == item.kind and candidate not in parcels and fire._in_stock(candidate) and _cold_whole(candidate):
					parcel = candidate
					break
			if parcel == null:
				return "The woodpile needs more %s. The layout and your stock are untouched." % Fire.SPECIES[item.kind].label.to_lower()
			parcels.append(parcel)
	# Validate rests in a detached hearth before transferring any real parcels.
	var trial := Fire.new(Fire.COLD)
	trial.coals.assign(fire.coals)
	var test_layout := _place_layout(trial, layout, [])
	if not test_layout.is_empty():
		return test_layout
	for index in range(trial.wood.size()):
		var actual := trial.wood[index]
		if absf(actual.height - float(layout[index].height)) > 0.026:
			return "A rest has changed. Move the ember or clear the support beneath the layout."
	return _place_layout(fire, layout, parcels)

static func _place_layout(fire: Fire, layout: Array, parcels: Array[Fire.Piece]) -> String:
	for index in range(layout.size()):
		var item: Dictionary = layout[index]
		var parcel: Fire.Piece
		var landing: Fire.Structure.Pose
		if item.fed:
			var ceiling := Fire.Feeding.pose(item.at, Fire.SPECIES[item.kind].size, item.yaw, item.slope, item.height)
			landing = Fire.Feeding.rest(fire, ceiling, Fire.Structure.radius(item.kind))
			if landing == null:
				return "A fed stick no longer fits beneath its supports. The layout is untouched."
		if fire.shelter != null:
			parcel = parcels[index]
			if landing != null:
				fire.feed_stock(parcel, landing)
			else:
				fire.pose_fuel(parcel, item.at, item.yaw, item.lean, item.tier, true)
		elif item.kind == Fire.TINDER_BUNDLE:
			# Free experiments provide the layout's material at room temperature.
			parcel = fire._make_fuel(Fire.TINDER_BUNDLE, item.at, item.yaw, item.lean, item.tier, true, item.amount)
			fire.wood.append(parcel)
		else:
			parcel = fire.add_fuel(item.kind, item.at, item.yaw, item.lean, item.tier, true, item.amount, landing)
		parcel.roll_travel = item.roll
	fire._settle()
	return ""

static func _cold_whole(piece: Fire.Piece) -> bool:
	return not piece.airborne and not piece.rolling and not piece.split_start and not piece.split_end \
		and piece.wood >= piece.original * 0.98 and piece.charred_wood <= 0.000001 and piece.temperature < 85.0
