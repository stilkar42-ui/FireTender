extends SceneTree

const Blueprints := preload("res://sim/fire_blueprints.gd")
const Save := preload("res://sim/chapter_save.gd")
const Fire := Blueprints.Fire
var passed := 0
var failed := 0

func _initialize() -> void:
	var dry := _trial(0, false)
	var cold := _trial(1, false)
	var soaked := _trial(0, true)
	var rain := _trial(3, false)
	_check(dry.bundle > 6.0 and dry.kindling > 25.0 and dry.branch > 40.0 and dry.sustained >= 15.0,
		"Dry tinder hands fire to kindling and sustained branch flame in a fully cold cabin")
	_check(cold.branch > 35.0 and cold.sustained >= 5.0, "Dry kindling can carry the ember to the rails in cold air")
	_check(soaked.branch < 1.0 and rain.sustained < dry.sustained, "Soaking or driving rain can defeat the same layout")
	_blueprints()
	_timed_crafting()
	print("Cold builds and tinder bundle: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _trial(weather: int, wet: bool) -> Dictionary:
	var fire := Fire.new(Fire.COLD_CABIN)
	fire.weather = weather
	var leaves := fire.workable_tinder()
	if weather == 1 and not wet:
		# Start with dry kindling that has been kept under cover.
		for piece in fire.wood:
			if piece.kind in [6, 7]:
				piece.water *= 0.40
	var original := leaves[0].wood + leaves[1].wood
	var water := leaves[0].water + leaves[1].water
	var bundle := fire.prepare_tinder_bundle(leaves[0], leaves[1])
	_check(is_equal_approx(bundle.wood, original) and is_equal_approx(bundle.water, water) \
		and not fire.has_fuel(leaves[0]) and not fire.has_fuel(leaves[1]),
		"Working leaves conserves material and consumes two parcels")
	fire.pose_fuel(bundle, Vector2.ZERO, 0, 0, -1, true)
	if wet:
		bundle.water = bundle.original * 0.9
	var ember := fire.coals[0]
	var original_heat := ember.temperature
	_check(fire.total_flame() == 0.0 and bundle.temperature < 75.0, "A cold build does not ignite before the ember arrives")
	fire.lift_coal(ember)
	_check(fire.deposit_coal(ember, Vector2(0.019, 0)) and ember.at == bundle.at and ember.height == bundle.height \
		and ember.temperature <= original_heat, "The same finite ember settles into the bundle")
	var result := {"bundle": 0.0, "kindling": 0.0, "branch": 0.0, "sustained": 0.0}
	for tick in range(320):
		if tick in [1, 14, 32]:
			fire.send_breath(Vector2(0, 0.43), Vector2.ZERO, 0.84, 1.2)
		fire.step()
		result.bundle = maxf(result.bundle, bundle.flame)
		var branch := 0.0
		var starter := 0.0
		for piece in fire.wood:
			if piece.kind in [6, 7]:
				starter += piece.flame
			elif piece.kind in [8, 9, 10]:
				branch += piece.flame
		result.kindling = maxf(result.kindling, starter)
		result.branch = maxf(result.branch, branch)
		if branch > 10.0:
			result.sustained += Fire.STEP
	print("weather %d wet %s · %s" % [weather, wet, result])
	return result

func _blueprints() -> void:
	var fire := Fire.new(Fire.COLD_CABIN)
	var leaves := fire.workable_tinder()
	var bundle := fire.prepare_tinder_bundle(leaves[0], leaves[1])
	fire.pose_fuel(bundle, Vector2.ZERO, 0, 0, -1, true)
	var layout := Blueprints.capture(fire)
	var library := Blueprints.new()
	library.path = OS.get_environment("TEMP").path_join("firetender-blueprint-model-%d.cfg" % OS.get_process_id())
	_check(library.save("Cabin with a leaf bundle", layout) == OK, "The cold layout saves with a name")
	var loaded := Blueprints.new()
	loaded.path = library.path
	loaded.read()
	var replay := Fire.new(Fire.ONE_EMBER)
	var ember := replay.coals[0]
	replay.lift_coal(ember)
	replay.deposit_coal(ember, Vector2(0.54, 0.03))
	_check(Blueprints.rebuild(replay, loaded.plans["Cabin with a leaf bundle"]).is_empty() and replay.wood.size() == layout.size() \
		and replay.coals == [ember] and replay.total_flame() == 0.0, "Blueprint rebuild restores only the layout")
	var rebuilt := Blueprints.capture(replay)
	_check(rebuilt == layout, "Blueprints round-trip all relative placements and orientations")
	var story := Save.Chapter.new(Fire.new())
	var stock := story.fire.fuel_stock
	_check(not Blueprints.rebuild(story.fire, layout).is_empty() and story.fire.fuel_stock == stock \
		and story.fire.wood.is_empty(), "An unaffordable plan leaves the live hearth and stock intact")
	var owned := story.fire.stock_piece(6)
	owned.water *= 2
	var minimal: Array = [layout.filter(func(entry): return entry.kind == 6)[0].duplicate()]
	minimal[0].at = Vector2(-0.22, 0)
	minimal[0].height = owned.radius
	_check(Blueprints.rebuild(story.fire, minimal).is_empty() and story.fire.wood[0] == owned \
		and owned.water > owned.original * 0.10, "Story rebuilding moves actual wood and keeps its moisture")
	story.tinder_bundle_known = true
	var restored := Save.Chapter.new(Fire.new())
	_check(Save.restore(restored, Save.capture(story)) and restored.tinder_bundle_known,
		"Tinder Bundle knowledge survives a story save")
	DirAccess.remove_absolute(library.path)

func _timed_crafting() -> void:
	var story := Save.Chapter.new(Fire.new())
	var fire := story.fire
	var bark := fire.stock_piece(4)
	var grass := fire.stock_piece(5)
	var mass := bark.wood + grass.wood
	bark.water = bark.original * 0.30
	var moisture := bark.water + grass.water
	_check(not fire.queue_tinder_bundle(bark, bark) and fire.queue_tinder_bundle(bark, grass),
		"The recipe accepts two different raw tinders and requires separate parcels")
	_check(not fire.pose_fuel(bark, Vector2.ZERO, 0.0, 0.0, 0) and fire.tinder_in_use(grass),
		"Ingredients in use cannot be placed into the hearth")
	for tick in range(12):
		story.step()
	_check(fire.has_fuel(bark) and fire.has_fuel(grass) and fire.stock_piece(Fire.TINDER_BUNDLE) == null,
		"No bundle appears before eight seconds of hearth time")
	var restored := Save.Chapter.new(Fire.new())
	_check(Save.restore(restored, Save.capture(story)) and restored.fire.tinder_job == fire.tinder_job,
		"Saving and loading preserves the unfinished bundle")
	for tick in range(20):
		story.step()
		restored.step()
	var bundle := fire.stock_piece(Fire.TINDER_BUNDLE)
	_check(bundle != null and is_equal_approx(bundle.wood, mass) and is_equal_approx(bundle.water, moisture)
		and not fire.has_fuel(bark) and not fire.has_fuel(grass) and restored.fire.stock_piece(Fire.TINDER_BUNDLE) != null,
		"The completed bundle conserves both tinder mass and moisture")
	var birch := fire.stock_piece(0)
	var leaf := fire.stock_piece(Fire.LEAVES)
	_check(fire.queue_tinder_bundle(birch, leaf), "Birch bark and leaves also work together")
	fire.cancel_tinder_work()
	_check(fire.tinder_job.is_empty() and fire.has_fuel(birch) and fire.has_fuel(leaf),
		"Stopping work releases both parcels intact")

func _check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", name)
	else:
		failed += 1
		printerr("FAIL  ", name)
