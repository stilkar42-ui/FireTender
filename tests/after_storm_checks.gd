extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Conversation := preload("res://sim/speaker_conversation.gd")
const Save := preload("res://sim/chapter_save.gd")
const Shelf := Vector2(-1.86, -3.19)
const Alcove := Vector2(-1.88, -2.27)

var passed := 0
var failed := 0

func _initialize() -> void:
	_continuity()
	_locations_and_water()
	_drying_stack()
	_cooling()
	_resin()
	_landings()
	_resources_and_words()
	_prepare_reserve()
	_quest_progress()
	print("After the storm: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _chapter() -> Chapter:
	var story := Chapter.new(Fire.new())
	story.set_up_after_storm_trial()
	return story

func _model() -> Fire:
	var fire := Fire.new(Fire.COLD)
	fire.coals.clear()
	fire._reindex()
	fire.shelter = Chapter.Shelter.new()
	fire.shelter.after_storm = true
	fire.time = Chapter.Shelter.END + 150.0
	fire.storage_sample = fire.time
	fire.shelter.sample(fire.time)
	return fire

func _fuel(fire: Fire, kind: int, at: Vector2, wet: float, yaw := 0.0) -> Fire.Piece:
	var piece := fire.receive_fuel(kind, at, yaw, 0, wet)
	fire.pose_fuel(piece, at, yaw, 0.0, 0, true)
	return piece

func _continuity() -> void:
	var story := Chapter.new(Fire.new())
	var fire := story.fire
	_check(not story.begin_after_storm(), "An unfinished Chapter I cannot skip directly into the live continuation")
	var original := fire.coals[0]
	var kept := fire.stock_piece(5)
	var wet := fire.receive_fuel(12, Vector2(-1.60, -0.20), 1.0, 0, 0.64)
	fire._settle()
	fire.time = Chapter.Shelter.END
	fire.storage_sample = fire.time
	fire.ash = 0.037
	original.cover = 0.008
	var saved := [original.char_mass, original.temperature, original.cover, kept.at, wet.water, wet.sections[0].core.water]
	story.gathering.take(1, PackedInt32Array([0, 1]), fire.time, 0.0, 10.0)
	var collected: Dictionary = story.gathering.records[1].pieces[0].duplicate(true)
	var queued := story.request(1)
	var load := story.carried_load.duplicate()
	var return_time := story.returns_at
	story.outcome = "kept"
	_check(story.begin_after_storm() and not story.begin_after_storm() and fire.time == Chapter.Shelter.END and
		fire.ash == 0.037 and fire.coals[0] == original and fire.has_fuel(wet) and fire.has_fuel(kept) and
		[original.char_mass, original.temperature, original.cover, kept.at, wet.water, wet.sections[0].core.water] == saved,
		"The live handoff preserves coal identity, ash, wood, water and the same clock")
	_check(queued and story.gathering.records[1].pieces[0] == collected and story.away == 1 and
		story.carried_load == load and story.returns_at == return_time,
		"Collected stock and an active trip carry across unchanged")

func _locations_and_water() -> void:
	var fire := _model()
	var seep := _fuel(fire, 12, Chapter.Shelter.SEEP, 0.64)
	var shelf := _fuel(fire, 12, Shelf, 0.64)
	var passage := _fuel(fire, 12, Chapter.Shelter.PASSAGE, 0.64)
	var birch := _fuel(fire, 12, Vector2(0.56, 0.05), 0.64)
	var coal := fire._new_coal(Vector2(0.15, 0.05), 0.098, 555.0, 0.32)
	var water := _total_water(fire)
	var mass := birch.wood
	var initial := birch.water
	var warmest := 0.0
	for tick in range(320):
		fire.step()
		warmest = maxf(warmest, birch.sections[0].faces[1].temperature)
	print("Drying fixture · warm loss %.4f kg, seep %.4f kg, shelf %.4f kg, passage %.4f kg · peak face %.1f C" % [
		initial - birch.water, initial - seep.water, initial - shelf.water, initial - passage.water, warmest])
	_check(initial - birch.water > 0.008 and birch.water < passage.water and passage.water < seep.water and shelf.water < seep.water,
		"Radiant warmth dries a branch faster than a draft alone, while the cool seep wets the wood")
	_check(birch.sections[0].water < birch.sections[2].water and
		birch.sections[0].faces[1].water / birch.sections[0].faces[1].original <
		birch.sections[0].core.water / birch.sections[0].core.original,
		"The near end and its skin dry ahead of the far end and core")
	_check(absf(water + fire.received_water - fire.evaporated_water - _total_water(fire)) < 1.0e-8 and
		is_equal_approx(mass, birch.wood) and coal.char_mass > 0.0,
		"Water balances against incoming moisture and evaporation without spending dry wood")
	var reading := [birch.water, birch.temperature, birch.sections[0].core.water, birch.sections[2].faces[0].water]
	_check(fire.pose_fuel(birch, Vector2(-1.66, -3.29), PI * 0.5, 0.0, 1, true) and
		birch.at.y < -3.0 and fire.has_fuel(birch) and
		reading == [birch.water, birch.temperature, birch.sections[0].core.water, birch.sections[2].faces[0].water],
		"Moving a partly dried branch into the extended shelf keeps its physical history")

func _drying_stack() -> void:
	var fire := _model()
	var left := _fuel(fire, 8, Vector2(-1.92, -3.37), 0.14)
	var right := _fuel(fire, 8, Vector2(-1.92, -3.04), 0.14)
	var wet := fire.receive_fuel(12, Vector2(-1.92, -3.20), PI * 0.5, 1, 0.72)
	fire._settle(true)
	_check(left.id in wet.pose.supports and right.id in wet.pose.supports and wet.height > wet.radius + 0.02,
		"Fuel stacked on two physical rails stays raised in the deep shelf")

func _cooling() -> void:
	var dry := _load_temperature(0.12)
	var soaked := _load_temperature(1.24)
	print("Wet load fixture · matched coal %.1f C dry, %.1f C soaked · latent %.3f kJ" % [dry.x, soaked.x, soaked.y])
	_check(soaked.x < dry.x - 6.0 and soaked.y > dry.y,
		"A soaked log over weak coals consumes more latent heat and leaves a colder bed")

func _load_temperature(moisture: float) -> Vector2:
	var fire := _model()
	var coal := fire._new_coal(Vector2.ZERO, 0.022, 480.0, 0.026)
	var oak := _fuel(fire, 2, Vector2(0.04, 0.01), moisture)
	var latent := 0.0
	for tick in range(84):
		fire.step()
		for section in oak.sections:
			for face in section.faces:
				latent += face.drying_heat * Fire.STEP
	return Vector2(coal.temperature, latent)

func _resin() -> void:
	var first := _hot_pine()
	var replay := _hot_pine()
	print("Pitch fixture · before %.6f kg, after %.6f kg · %d pops, %d ejections · max reach %.2f m" %
		[first.before, first.after, first.pops, first.ejections, first.reach])
	_check(first.before > 0.0 and first.without_pocket and first.regions == 1 and first.after < first.before and first.pops > 0,
		"Seeded pine has localized finite pitch, and some pieces have none")
	_check(first.ejections > 0 and first.reach > 0.18 and first.reach < 1.75 and first.rises and first.cools and
		first.spent and first.residue > 0.0 and first == replay,
		"An actual heated pocket ejects reproducible fragments that cool and land within a short reach")
	var wet_fire := _model()
	var wet := _fuel(wet_fire, 2, Vector2.ZERO, 1.05)
	for section in wet.sections:
		for region: Fire.Piece in section.faces + section.inner + [section.core]:
			region.temperature = 155.0
	wet_fire._sync_sections(wet)
	for tick in range(24):
		wet_fire.step()
	_check(wet.sections.any(func(section): return section.faces.any(func(face): return face.pops > 0 and face.resin == 0.0)),
		"Heating a soaked resin-free split can cause a steam pop")

func _hot_pine() -> Dictionary:
	var fire := _model()
	var source: Fire.Piece
	var pocket: Fire.Piece
	var without_pocket := false
	var regions := 0
	for index in range(5):
		var tree := _fuel(fire, 11, Vector2(-2.36 + index * 0.33, -2.31), 0.13)
		var pockets := 0
		for section in tree.sections:
			for face in section.faces:
				if face.resin > 0.0:
					pockets += 1
					if source == null:
						pocket = face
		if pockets == 0:
			without_pocket = true
		elif source == null:
			source = tree
			regions = pockets
	var before := pocket.resin
	fire.pose_fuel(source, Vector2.ZERO, 0.0, 0.0, 0, true)
	fire._prime(source, 650.0, 650.0, 225.0)
	pocket.char_mass = 0.007
	fire._new_coal(Vector2(0.0, -0.10), 0.10, 670.0, 0.20)
	var reach := 0.0
	var rises := false
	var cools := false
	var trail: Array = []
	for index in range(240):
		fire.step()
		for spark in fire.sparks:
			reach = maxf(reach, Vector2(spark.position.x, spark.position.y).distance_to(pocket.at))
			rises = rises or spark.position.z > pocket.height + 0.12
			cools = cools or spark.temperature < 410.0
		if not fire.sparks.is_empty():
			trail.append([fire.sparks[0].position, fire.sparks[0].temperature, fire.sparks[0].mass])
	return {"before": before, "after": pocket.resin, "pops": pocket.pops, "ejections": fire.spark_ejections,
		"reach": reach, "rises": rises, "cools": cools, "spent": fire.sparks.is_empty(), "residue": fire.spark_ground_carbon,
		"without_pocket": without_pocket, "regions": regions, "trail": trail}

func _landings() -> void:
	var dry := _landing(0.045, false)
	var wet := _landing(0.88, false)
	var separated := _landing(0.045, true)
	print("Landing fixture · dry %.3f kW smolder, wet %.3f, separated %.3f" % [dry.y, wet.y, separated.y])
	_check(dry.x == 1.0 and wet.x == 1.0 and separated.x == 0.0 and dry.y > 0.02 and wet.y < 0.004 and separated.y == 0.0 and
		dry.z == 1.0 and wet.z == 0.0 and separated.z == 0.0,
		"A hot fragment can light exposed dry storage, while soaked or separated tinder stays dark")

func _landing(moisture: float, separated: bool) -> Vector3:
	var fire := _model()
	var tinder := _fuel(fire, 4, Vector2(1.10, -0.02) if not separated else Alcove, moisture)
	var stage := Chapter.AfterStorm.new(fire)
	var spark := Fire.Spark.new()
	spark.position = Vector3(0.91, -0.02, 0.17)
	spark.velocity = Vector3(1.00, 0.0, 0.0)
	spark.temperature = 725.0
	spark.mass = 0.00123
	fire.sparks.append(spark)
	var heat := 0.0
	var hottest := 0.0
	var hazard := false
	for tick in range(40):
		fire.step()
		stage.update()
		heat = maxf(heat, tinder.smolder)
		hottest = maxf(hottest, tinder.temperature)
		hazard = hazard or (stage.hazard and tinder.smolder > 0.05)
	print("  landing %d, peak %.1f C, %.3f kJ received" % [fire.spark_landings, hottest, fire.spark_heat_delivered])
	_check(absf(spark.mass + fire.spark_oxidized - 0.00123) < 1.0e-9 and fire.sparks.is_empty() and
		absf(fire.spark_ground_carbon + fire.spark_oxidized - 0.00123) < 1.0e-9 and
		fire.spark_heat_delivered <= 0.00123 * 1.15 * (725.0 - fire.ambient()) + fire.spark_oxidized * 26_000.0 * 0.41,
		"Spark heat and carbon remain bounded by its sensible heat and consumed fuel")
	return Vector3(fire.spark_landings, heat, float(hazard))

func _resources_and_words() -> void:
	var story := _chapter()
	var fire := story.fire
	var before := story.remaining(5)
	var wood := fire.all_fuel().size()
	_check(story.request(5), "The cousin can gather finite storm-soaked willow")
	while story.away >= 0 and fire.time < Chapter.Shelter.END + 60.0:
		story.step()
	_check(story.remaining(5)[2] < before[2] and fire.all_fuel().size() > wood and fire.stock_piece(13, true) != null and
		story.route_description(1).contains("haven’t checked") and story.route_description(5).contains("waterlogged"),
		"Aftermath reports and deliveries reflect remaining patches, wet wood and actual physical stock")
	var talk := Conversation.new()
	talk.chapter = story
	var words := ["Who were the twins?", "Why did their mother fall into the Dark Waters?", "What made the sky thunder?",
		"Why do wolves come from the rain?", "What are the Flame Children?", "How do I dry a wet log?"]
	var terms := ["Keeping Hand", "Dark Waters", "lightning", "cave hyena", "charred wood", "warmth"]
	for index in range(words.size()):
		var answer := talk.reply(fire, words[index], Vector3.ZERO, null, 0.0)
		_check(answer.to_lower().contains(terms[index].to_lower()), "Offline reply about " + terms[index])
	var timing := talk.reply(fire, "How long does it take to dry wood?", Vector3.ZERO, null, 0.0)
	var shelf := talk.reply(fire, "What happens if I air-dry the logs?", Vector3.ZERO, null, 0.0)
	var edge := talk.reply(fire, "How do I dry wood around the fire?", Vector3.ZERO, null, 0.0)
	_check(timing.contains("ten minutes") and timing.contains("twenty") and timing.contains("few minutes"),
		"The Fire Speaker compares the chapter’s two drying times")
	_check(shelf.contains("safer") or (shelf.contains("risk of scorch") and shelf.contains("seep")),
		"The Fire Speaker explains the low risk and slower pace of the shelf")
	_check(edge.contains("outside the ring") and edge.contains("check the core") and edge.contains("heat from the coals"),
		"The Fire Speaker teaches placement, the core check and the risk to the fire")
	_check(Chapter.AfterStorm.TALE.size() >= 8 and Chapter.AfterStorm.TALE[2].contains("Chasm of the Cloud"),
		"The replayable myth is authored in separate passages")

func _prepare_reserve() -> void:
	var start := Time.get_ticks_usec()
	var first := _tend_reserve()
	var elapsed := (Time.get_ticks_usec() - start) / 1_000_000.0
	var replay := _tend_reserve()
	_check(first.loose_first, "The fuel bar takes loose supplies before spending protected tinder")
	_check(first.stashed and first.outcome.is_empty() and first.stage == 3 and first.protected_tinder and
		first.hot >= 0.009 and first.at == Shelf,
		"One dried medium log and a living bed alone cannot complete the four-log quest")
	_check(first == replay, "The same Chapter II drying actions replay deterministically")
	print("Preparation fixture · %.2f simulated seconds in %.3f wall seconds · wet %.3f to %.3f kg · reserve %.3f kg · hot coal %.3f kg" %
		[first.elapsed, elapsed, first.baseline, first.water, first.reserve, first.hot])

func _tend_reserve() -> Dictionary:
	var story := _chapter()
	var fire := story.fire
	var tinder := fire.stock_piece(4)
	var target := fire.stock_piece(12, true)
	var baseline := target.water
	fire.pose_fuel(tinder, Alcove, 0.0, 0.0, 0, true)
	var loose_first := fire.stock_piece(4) != tinder
	var coal_at := fire.coals[0].at
	for index in range(5):
		var angle := TAU * index / 5.0
		fire.pose_fuel(fire.stock_piece(4), coal_at + Vector2.from_angle(angle) * 0.046, angle, 0.0, 0, true)
	var stashed := false
	var peak := 0.0
	var flame := 0.0
	for tick in range(1500):
		if tick in [1, 11]:
			fire.send_breath(coal_at + Vector2(0, 0.43), coal_at, 0.84, 1.2)
		if tick in [12, 30, 66, 146, 300, 490, 640, 850, 1080]:
			var kind := 1 if tick == 12 else (8 if tick == 66 else (2 if tick == 146 else 7))
			var fuel := fire.stock_piece(kind)
			if fuel != null and fuel.water < fuel.original * 0.26:
				var spot := Vector2(-0.16, 0.05) if tick == 12 else Vector2(-0.30, 0.015 + 0.10 * sin(tick))
				fire.pose_fuel(fuel, spot, 0.3, 0.0, 0, true)
		if tick == 176:
			fire.pose_fuel(target, Vector2(-0.96, 0.08), 0.0, 0.0, 0, true)
		if not stashed and target.water < target.original * 0.355 and baseline - target.water >= baseline * 0.17:
			stashed = fire.pose_fuel(target, Shelf, PI * 0.5, 0.0, 0, true)
		story.step()
		peak = maxf(peak, target.sections[2].faces[1].temperature)
		flame = maxf(flame, fire.total_flame())
		if not story.outcome.is_empty():
			break
	return {"loose_first": loose_first, "stashed": stashed, "outcome": story.outcome, "stage": story.sequel.stage,
		"protected_tinder": story.sequel.protected_tinder, "hot": story.sequel.hot_coals, "at": target.at,
		"elapsed": fire.time - Chapter.Shelter.END, "baseline": baseline, "water": target.water, "reserve": story.sequel.seasoned_reserve,
		"peak_face": peak, "peak_flame": flame, "coals": fire.coals.map(func(coal): return [coal.at, coal.char_mass, coal.temperature])}

func _total_water(fire: Fire) -> float:
	var result := 0.0
	for piece in fire.all_fuel() + fire.coals:
		result += piece.water
	return result

func _quest_progress() -> void:
	var chapter := _chapter()
	var fire := chapter.fire
	var sequel := chapter.sequel
	var log := fire.stock_piece(8, true)
	fire.pose_fuel(log, Shelf, PI * 0.5, 0.0, 0, true)
	# A dry skin with a wet core remains unfinished.
	for section in log.sections:
		for region: Fire.Piece in section.faces + section.inner:
			region.water = region.original * 0.03
		section.core.water = section.core.original * 0.43
	fire._sync_sections(log)
	sequel.update()
	_check(log.water <= log.original * sequel.READY_MOISTURE and not sequel.dry_through(log)
		and sequel.drying_complete.is_empty(), "Dry faces alone do not complete a drying goal")
	var snapshot := Save.capture(chapter)
	var restored := Chapter.new(Fire.new())
	var reloaded := Save.restore(restored, snapshot)
	_check(reloaded and restored.sequel.drying_records == sequel.drying_records and
		restored.sequel.drying_complete == sequel.drying_complete, "Saving and loading preserves per-log method progress")
	var legacy := snapshot.duplicate(true)
	legacy.chapter.erase("storm_reserve")
	legacy.sequel.erase("drying_records")
	legacy.sequel.erase("drying_complete")
	_check(Save.restore(Chapter.new(Fire.new()), legacy), "An earlier Chapter II save migrates to the drying quest")
	var finishing := log.sections[0].core
	log.charred_wood = log.original * 0.04
	sequel._update_log(log, false)
	for section in log.sections:
		section.core.water = section.core.original * 0.12
	fire._sync_sections(log)
	sequel._update_log(log, false)
	_check(finishing.water < finishing.original * sequel.READY_CORE and sequel.dry_through(log) and
		sequel.drying_records[log.id].burned and sequel.drying_complete.is_empty(),
		"A scorched log stays disqualified after its core dries")

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
