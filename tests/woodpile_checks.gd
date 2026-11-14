extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Mentor := preload("res://sim/mentor.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	_transfers_and_supports()
	_exposure()
	_finite_sites()
	_teaching()
	print("Clan wood checks: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _transfers_and_supports() -> void:
	var story := _chapter_with_banked_bed()
	var fire := story.fire
	var opening_count := 25 # Includes the four leaf parcels used to teach tinder bundles.
	var opening_matches := fire.stored.size() == opening_count
	for kind: int in Chapter.OPENING_STOCK:
		opening_matches = opening_matches and fire.stored.filter(func(piece): return piece.kind == kind).size() == Chapter.OPENING_STOCK[kind]
	_check(fire.wood.is_empty() and opening_matches and fire.all_fuel().size() == opening_count,
		"The opening bundle is made of actual pieces outside the hearth")
	var site_before := story.remaining(2)
	_check(story.request(2) and fire.stored.size() == opening_count and story.remaining(2) == site_before,
		"Gathering creates no pieces or field debit at departure")
	var ids := story.carried_load.duplicate()
	_advance(story, story.pickup_at + Fire.STEP)
	_check(story.picked_up and story.remaining(2)[2] == site_before[2] - 8 and fire.stored.size() == opening_count,
		"The field debits the eight specific ridge pieces at pickup and the cave waits for the return")
	_advance(story, story.returns_at)
	var delivered_count := opening_count + 8
	var delivered_ids := {}
	for id in ids:
		var entry: Dictionary = story.gathering.records[2].pieces[id]
		var delivered := fire.fuel_by_id(entry.fuel_id)
		if delivered != null and delivered.kind == entry.kind:
			delivered_ids[delivered.id] = true
	_check(story.away == -1 and fire.stored.size() == delivered_count and delivered_ids.size() == 8,
		"A ridge armful removes eight pieces at source and delivers eight physical logs and branches")
	var original := fire.stock_piece(2)
	var initial_id := original.id
	var original_state := _material(original)
	var origin := original.at
	var placed := fire.add_fuel(2, Vector2(0.31, 0.08), PI * 0.5, 0.0, 0, true)
	_check(placed == original and original.id == initial_id and original not in fire.stored and original.at != origin and
		fire.all_fuel().size() == delivered_count and _material(original) == original_state,
		"Fuel bar placement picks up the actual stocked oak without altering its material")
	fire.uncover()
	_advance(story, fire.time + 6.0)
	var warmed := _material(original)
	var shelf := Vector2(-2.06, 0.67)
	_check(fire.pose_fuel(original, shelf, 0.0, 0.0, 0, true) and original.id == initial_id and
		_material(original) == warmed and fire.all_fuel().size() == delivered_count,
		"Putting a warmed piece back preserves its water, heat, mass and section wear")
	var top := fire.stock_piece(10)
	var total_before := fire.all_fuel().size()
	fire.pose_fuel(top, shelf, PI * 0.5, 0.0, 1, true)
	var raised := top.height
	_check(original.id in top.pose.supports and raised > top.radius + 0.045,
		"Crossing a split over the stockpile seats it on a real supporting piece")
	fire.pose_fuel(original, Vector2(-2.51, -0.13), PI * 0.5, 0.0, 0, true)
	var released := top.airborne
	fire.step()
	_check(released and top.height < raised - 0.035 and original.id not in top.pose.supports and fire.all_fuel().size() == total_before,
		"Taking the support away lets the stacked split fall to its new rest")

func _exposure() -> void:
	var story := Chapter.new(Fire.new())
	var fire := story.fire
	var dry := fire.stock_piece(7)
	var wet: Fire.Piece
	for piece in fire.stored:
		if piece.kind == 7 and piece != dry:
			wet = piece
			break
	fire.move_fuel(dry, Vector2(-1.72, -1.28))
	fire.move_fuel(wet, Vector2(-1.72, 1.13))
	var initial := dry.water
	fire.time = 930.0
	fire.storage_sample = fire.time
	for i in range(128):
		fire.step()
	_check(dry in fire.stored and wet in fire.stored and is_equal_approx(dry.water, initial) and wet.water > dry.water + 0.0002,
		"Stored wood at the drip line takes up rain while the sheltered piece stays dry")
	var warm_story := Chapter.new(Fire.new())
	var model := warm_story.fire
	var coal := model.coals[0]
	model.lift_coal(coal)
	model.deposit_coal(coal, Vector2(-0.87, 0.0))
	coal.char_mass = 0.19
	var near := model.stock_piece(4)
	var far := model.stock_piece(5)
	var cold := near.temperature
	model.move_fuel(near, Vector2(-0.97, 0.0))
	_check(near in model.wood and far in model.stored, "A parcel outside the ring joins combustion calculations when set near live heat")
	for i in range(16):
		model.step()
	_check(near.temperature > cold + 20.0 or not model.has_fuel(near), "The exposed parcel can warm or burn from the real coal")

func _finite_sites() -> void:
	var story := _chapter_with_banked_bed()
	var fire := story.fire
	var before := story.remaining(1)
	var before_stock := fire.stored.size()
	_check("plenty" in story.remaining_words(1) and not story.request(1, 1),
		"The scout describes the pine's actual supplies and declines a priority it lacks")
	_check(story.request(1, 2) and not story.request(0), "A focused trip reserves one armful and one journey at a time")
	_advance(story, story.returns_at)
	var after := story.remaining(1)
	_check(after[1] < before[1] and after[2] == before[2] and fire.stored.size() - before_stock == before[1] - after[1],
		"Kindling priority debits only small wood and creates the same number of pieces")
	_check(story.request(5, 3), "Damp branches are a separate reachable supply")
	_advance(story, story.returns_at)
	var damp := fire.stock_piece(13)
	_check(damp != null and damp.material == Fire.Materials.WILLOW and damp.water / damp.original > 0.50,
		"The hollow delivers genuine willow with its source moisture")
	while story.can_request(1):
		story.request(1)
		_advance(story, story.returns_at)
	_check(story.route_status(1) == "Picked clean" and "taken what I can reach" in story.remaining_words(1),
		"Taking the last reachable wood changes the report and prevents another trip")
	fire.time = 248.0
	story.weather.sample(fire.time)
	_check(story.route_status(2) == "Too little daylight for the return" and not story.can_request(2),
		"The ridge closes in time to bring a heavy load back before night")
	story.weather.sample(330.0)
	_check(story.route_status(2) == "Wait for daylight" and not story.can_request(2), "The far ridge closes after dusk")

func _teaching() -> void:
	var story := _chapter_with_banked_bed()
	var fire := story.fire
	var elder := Mentor.new()
	elder.begin_chapter(story)
	_ask(elder, fire, "Who are our people?")
	_ask(elder, fire, "Will the Torch Bearer find dry wood?")
	_check(story.consultations.is_empty(), "Ordinary questions leave the teaching opportunities available")
	var first := _ask(elder, fire, "What should my cousin bring?")
	_check(story.consultations.size() == 1 and "fallen pine" in first and "thin fuel" in first and story.away == -1,
		"The first choice recommends an available source and explains the fire's need without dispatching the scout")
	_ask(elder, fire, "Why?")
	story.request(1)
	_ask(elder, fire, "What should the Torch Bearer seek next?")
	_check(story.consultations.size() == 1, "Clarifying advice or asking while the scout is out leaves the second choice available")
	_advance(story, story.returns_at)
	var second := _ask(elder, fire, "What should the Torch Bearer go for now?")
	_check(story.consultations.size() == 2 and "larger wood" in second and story.consultations[0].route != story.consultations[1].route,
		"The second choice responds to the stock just brought home")
	var third := _ask(elder, fire, "What would you have him bring next?")
	_check(third == Chapter.HANDOFF and story.consultations.size() == 2 and story.away == -1,
		"The third consultation transfers responsibility to the Ember Tender")
	elder.conversation.reset_hearth()
	_check(_ask(elder, fire, "What should my cousin fetch?") == Chapter.HANDOFF and story.consultations.size() == 2,
		"Rephrasing and resetting short-term dialogue cannot reset chapter mentorship")
	_check("ash" in _ask(elder, fire, "What should I do before the storm?") and
		"dry" in _ask(elder, fire, "What should I feed it?") and story.consultations.size() == 2,
		"The elder continues to discuss storm preparation and fuel")

func _chapter_with_banked_bed() -> Chapter:
	# A stable live bed isolates storage and travel behavior in these fixtures.
	var story := Chapter.new(Fire.new())
	story.fire.coals[0].char_mass = 0.55
	story.fire.coals[0].cover = 0.025
	return story

func _advance(story: Chapter, until: float) -> void:
	while story.fire.time < until and story.outcome.is_empty():
		story.step()

func _material(piece: Fire.Piece) -> Array:
	return [piece.id, piece.kind, piece.original, piece.wood, piece.water, piece.temperature, piece.char_mass, piece.integrity,
		piece.sections.map(func(section): return [section.wood, section.water, section.temperature, section.integrity])]

func _ask(elder: Mentor, fire: Fire, words: String) -> String:
	elder.ask(fire, words, Vector3.ZERO, null, 0.0)
	return elder.text

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)
