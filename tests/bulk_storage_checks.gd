extends SceneTree
const Chapter := preload("res://sim/red_hollow.gd")
const Fire := Chapter.Fire
const Save := preload("res://sim/chapter_save.gd")
var failed := 0
var passed := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, words: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("PASS " if ok else "FAIL ", words)
func _run() -> void:
	var story := Chapter.new(Fire.new())
	story.set_up_family_trial()
	var fire := story.fire
	var original_hearth := fire.wood.duplicate()
	var dry := story._store_piece(10, 0.12, false, 12.0)
	var wet := story._store_piece(12, 0.65, true, 9.0)
	check(fire.bulk_stock.get(dry.id) == "reserve" and fire.bulk_stock.get(wet.id) == "drying", "Mixed condition sorts into separate stores")
	var mass := dry.wood + wet.wood
	var water := dry.water + wet.water
	check(dry.pose == null and wet.pose == null and fire.wood == original_hearth, "Delivery preserves the hearth and uses no individual support geometry")
	check(fire.transfer_bulk("reserve", "drying", 1) == 1, "Small load transfer")
	check(fire.store_bulk(dry, "reserve"), "Return dry record to reserve")
	check(fire.draw_bulk("reserve", 10) == dry and not fire.is_bulk(dry) and dry.pose != null, "Draw activates exactly the same useful piece")
	check(fire.store_bulk(dry), "Unused cold piece returns")
	check(is_equal_approx(mass, dry.wood + wet.wood) and is_equal_approx(water, dry.water + wet.water), "Transfers conserve wood and water")
	check(fire.draw_bulk("reserve", 999) == null, "Missing type has no substitute")
	var state := Save.capture(story)
	var restored := Chapter.new(Fire.new())
	check(Save.restore(restored, state), "Bulk save reload")
	check(restored.fire.bulk_stock == fire.bulk_stock, "Bulk identities and zones survive reload")
	fire._weather_storage(10.0)
	restored.fire._weather_storage(10.0)
	check(Save.capture(story).fire == Save.capture(restored).fire, "Regional environmental drying continues deterministically")
	var legacy := Save.capture(story)
	legacy.fire.erase("bulk_stock")
	legacy.fire.erase("storage_sites")
	check(Save.restore(Chapter.new(Fire.new()), legacy), "Older snapshots without bulk metadata still load")
	# Save after pickup, before arrival; deliver the identical finite field records once.
	for piece in fire.stored.duplicate():
		if not fire.is_bulk(piece): fire.store_bulk(piece)
	check(story.request(5), "Rusk departs for wet deadwood")
	story.fire.time = story.pickup_at
	story._pick_up()
	# Mixed return fixture: one sheltered dry piece among waterlogged limbs.
	var entry: Dictionary = story.gathering.records[5].pieces[story.carried_load[0]]
	entry.moisture = 0.12
	entry.skin = false
	var load_counts := PackedInt32Array([0, 0, 0, 0])
	for id in story.carried_load:
		load_counts[Chapter.Gathering.condition(story.gathering.records[5].pieces[id])] += 1
	story.trip_observation.load = load_counts
	story.returns_at = story.fire.time + 8.0
	var transit := Save.capture(story)
	check(Save.restore(restored, bytes_to_var(var_to_bytes(transit))), "Rusk saves and reloads in transit")
	DirAccess.make_dir_recursive_absolute("res://outputs/bulk-firewood")
	check(Save.write_state("res://outputs/bulk-firewood/Before-fuel-delivery.sav", transit) == OK, "Pre-delivery playtest save")
	story._arrive()
	restored._arrive()
	var a: Dictionary = Save.capture(story).fire
	var b: Dictionary = Save.capture(restored).fire
	check(a == b, "In-transit reload delivers identical fuel once")
	var skin := story._store_piece(10, 0.30, true, 12.0)
	check(not fire.bulk_ready(skin) and fire.bulk_stock.get(skin.id) == "drying", "Dry core with wet skin still belongs on the rails")
	check(fire.store_bulk(skin, "reserve") and not fire.bulk_ready(skin), "Transferring a wet surface into reserve does not make it ready")
	fire.storage_sites["drying"] = Vector2(-1.8, -3.0)
	check(fire.store_bulk(skin, "drying") and skin.at == Vector2(-1.8, -3.0), "Another camp can configure its storage location")
	check(Save.restore(restored, bytes_to_var(var_to_bytes(Save.capture(story)))) and restored.fire.storage_sites == fire.storage_sites, "Storage layout survives save and reload")
	print("Bulk storage: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

