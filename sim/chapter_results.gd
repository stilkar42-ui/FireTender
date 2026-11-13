extends RefCounted
## Read the hearth as it stands at the end of a chapter.

const Story := preload("res://sim/red_hollow.gd")
const Fire := Story.Fire

static func collect(story: Story) -> Dictionary:
	var fire := story.fire
	var tinder := 0
	var dry_wood := 0
	var damp_wood := 0
	for piece in fire.all_fuel():
		if fire.in_hearth(piece.at) or piece.wood < 0.002:
			continue
		var moisture := piece.water / piece.original
		if piece.kind in Fire.RAW_TINDER or piece.kind == Fire.TINDER_BUNDLE:
			if moisture < 0.23:
				tinder += 1
		elif moisture <= 0.36:
			dry_wood += 1
		else:
			damp_wood += 1
	var living_mass := 0.0
	for coal in fire.coals:
		if coal.living_coal():
			living_mass += coal.char_mass
	var supplies := [
		["Living charcoal", "%d g" % roundi(living_mass * 1000.0)],
		["Dry tinder", "%d parcels" % tinder],
		["Dry wood", "%d pieces" % dry_wood],
		["Damp or wet wood", "%d pieces" % damp_wood],
		["Loose ash", "%d g" % roundi(fire.ash * 1000.0)],
	]
	if story.sequel == null:
		return {"heading": "The hearth went cold" if story.outcome == "lost" else "The storm has passed",
			"note": "The fire went out before the handoff. You can retry or load an earlier save." if story.outcome == "lost" else
				("You kept a banked, living bed through the storm." if story.outcome == "kept" else
					"You carried living fire through Day 3. A stronger bed and more time under ash would give it a better reserve."),
			"results": [
				["Stocked dry fuel before rain", story.reserve_ready()],
				["Kept fire through the storm", story.can_continue()],
				["Built a coal bed", story.bed],
				["Kept coals under ash", story.preserved],
			], "supplies": supplies}
	var sequel := story.sequel
	var drying := []
	for row: Dictionary in Story.Quests.drying_rows(sequel.drying_complete, true):
		drying.append([row.label, row.done])
	var legacy_completion := sequel.outcomes == "prepared" and sequel.drying_complete.is_empty()
	if legacy_completion:
		drying = [["Seasoned the reserve", true], ["Protected dry tinder", sequel.protected_tinder],
			["Set aside usable wood", sequel.ready_reserve >= 0.15], ["Kept living coals", sequel.hot_coals >= 0.009]]
	supplies.append(["Seasoned wood set aside", "%d g" % roundi(sequel.seasoned_reserve * 1000.0)])
	return {"heading": "The hearth went cold" if story.outcome == "lost" else "The reserve is ready",
		"note": "The hearth went out while you were preparing the reserve." if story.outcome == "lost" else
			("You made a dry reserve and kept living coals." if legacy_completion else
				"You dried medium and large logs both on the shelf and beside the fire, and kept living coals."),
		"results": drying, "supplies": supplies}
