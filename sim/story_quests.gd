extends RefCounted
## Chapter objectives shared by the journal and the chapter results.
const Fire := preload("res://sim/fire.gd")
const Shelter := preload("res://sim/red_hollow_shelter.gd")

const RESERVE_AT := Shelter.STORM_BEGINS
const RESERVE_TARGETS := [3, 6, 2, 2]
const RESERVE_LABELS := ["Dry tinder", "Dry kindling", "Dry medium wood", "Dry large wood"]
const DRYING_LABELS := {
	"air_medium": "Air-dry a medium log",
	"air_large": "Air-dry a large log",
	"heat_medium": "Dry a medium log beside the fire",
	"heat_large": "Dry a large log beside the fire",
}

static func size_group(kind: int) -> int:
	if kind in Fire.RAW_TINDER or kind == Fire.TINDER_BUNDLE:
		return 0
	if kind in [1, 6, 7]:
		return 1
	if kind in [8, 11, 12, 13]:
		return 2
	return 3

static func storm_reserve(fire: Fire) -> Array:
	var counts := [0, 0, 0, 0]
	for piece in fire.all_fuel():
		if fire._in_stock(piece) and fire.shelter.exposure(piece.at) <= 0.35 \
			and piece.water <= piece.original * 0.26 and piece.wood >= piece.original * 0.90:
			counts[size_group(piece.kind)] += 1
	return counts

static func reserve_ready(counts: Array) -> bool:
	for index in range(RESERVE_TARGETS.size()):
		if counts[index] < RESERVE_TARGETS[index]:
			return false
	return true

static func reserve_rows(counts: Array, locked: bool, survived: bool, ended: bool) -> Array:
	var rows := []
	for index in range(RESERVE_TARGETS.size()):
		rows.append(row(RESERVE_LABELS[index], counts[index], RESERVE_TARGETS[index], locked))
	rows.append(row("Keep living fire through the storm", int(survived), 1, ended))
	return rows

static func drying_rows(completed: Dictionary, ended: bool) -> Array:
	var rows := []
	for key in DRYING_LABELS:
		rows.append(row(DRYING_LABELS[key], int(completed.has(key)), 1, ended))
	return rows

static func row(label: String, count: int, target: int, ended: bool) -> Dictionary:
	return {"label": label, "count": mini(count, target), "target": target, "done": count >= target, "ended": ended}
