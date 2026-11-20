extends SceneTree
const Lab := preload("res://hearth/hearth.tscn")
const Save := preload("res://sim/chapter_save.gd")
const Chapter := preload("res://sim/red_hollow.gd")
var failed := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, words: String) -> void:
	print("PASS " if ok else "FAIL ", words)
	if not ok: failed += 1
func _run() -> void:
	var lab := Lab.instantiate()
	lab.settings_path = "res://outputs/bulk-firewood/render-settings.cfg"
	root.add_child(lab)
	await process_frame
	lab._start_family_trial()
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_B
	shortcut.ctrl_pressed = true
	shortcut.pressed = true
	lab._unhandled_key_input(shortcut)
	check(lab.fuel_store_panel != null and lab.fuel_store_panel.visible, "Ctrl+B opens stores without replacing breath")
	lab.fuel_store_types.item_selected.emit(1)
	lab.fuel_store_types.item_selected.emit(0)
	check(lab.fuel_store_kind == -1, "Any useful piece remains available after selecting a type")
	lab._unload_cold_stock()
	var story: Chapter = lab.chapter
	var fire := story.fire
	for i in 36:
		story._store_piece([0, 1, 7, 10, 12][i % 5], 0.12 if i % 3 else 0.65, false, 12.0)
	check(story.request(5), "Rusk heads for waterlogged deadwood")
	fire.time = story.pickup_at
	story._pick_up()
	story._arrive()
	check(fire.bulk_pieces("drying").size() > 0, "Returned wet load is unloaded together")
	lab._draw_store("reserve", 1)
	var dry: Chapter.Fire.Piece = fire.all_fuel().filter(func(piece): return not fire.is_bulk(piece) and piece.kind == 1)[0]
	check(dry.pose != null and fire.pose_fuel(dry, Vector2(0.15, 0.1), 0, 0, 0), "Draw dry kindling and feed the physical fire")
	for i in 3:
		var wet := fire.draw_bulk("drying")
		check(wet != null and fire.pose_fuel(wet, Vector2(-0.8 + i * 0.28, -0.7), PI * 0.5, 0, 0), "Place a damp piece for targeted heat")
	for i in 8:
		story.step()
	# Exercise mouse press/motion/release through the actual view, not just the model API.
	lab.fuel_store_panel.hide()
	lab.family_page.close()
	lab.view.workbench.focus_on(Vector3(-1.8, 0.1, -1.8))
	for i in 40: await process_frame
	var returned := fire.draw_bulk("reserve", 1)
	check(returned != null, "A cold stock piece can be drawn for the drag test")
	if returned != null:
		for zone in ["reserve", "drying"]:
			fire.pose_fuel(returned, Vector2(-1.15, -1.5), 0, 0, 0)
			for i in 3: await process_frame
			var from: Vector2 = lab.view.workbench.project(returned.pose.point(0))
			var site: Vector2 = fire.storage_sites[zone]
			var to: Vector2 = lab.view.workbench.project(Vector3(site.x, site.y, 0))
			var press := InputEventMouseButton.new()
			press.position = from
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			lab.view._gui_input(press)
			check(lab.view.dragging == returned, "Mouse picks up the individual piece")
			var motion := InputEventMouseMotion.new()
			motion.position = to
			lab.view._gui_input(motion)
			check(lab.view.workbench.family_props.fuel_stores.hovered == zone, "Drag highlights " + zone)
			var release := InputEventMouseButton.new()
			release.position = to
			release.button_index = MOUSE_BUTTON_LEFT
			lab.view._gui_input(release)
			check(fire.bulk_stock.get(returned.id) == zone and returned.pose == null, "Dropping wood stores it in " + zone)
	if returned != null:
		fire.pose_fuel(returned, Vector2(-1.15, -1.5), 0, 0, 0)
		returned.temperature = 220.0
		var before := returned.at
		lab.view.dragging = returned
		var site: Vector2 = fire.storage_sites.reserve
		lab.view.pointer = lab.view.workbench.project(Vector3(site.x, site.y, 0))
		check(lab.view._drop_in_storage() and not fire.is_bulk(returned) and returned.at == before, "Hot wood is rejected by the actual drop handler")
	var click := InputEventMouseButton.new()
	var site: Vector2 = fire.storage_sites.reserve
	click.position = lab.view.workbench.project(Vector3(site.x, site.y, 0))
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	lab.view._gui_input(click)
	check(lab.fuel_store_panel.visible, "Clicking a pile opens its readable inventory")
	lab.fuel_store_panel.hide()
	var display = lab.view.workbench.family_props.fuel_stores
	var empty := Chapter.new(Chapter.Fire.new())
	empty.fire.storage_revision = fire.storage_revision
	display.sync(empty.fire)
	check(display.labels.reserve.text.begins_with("DRY RESERVE · 0"), "A different camp refreshes even with the same revision")
	display.sync(fire)
	check(display.labels.reserve.text.begins_with("DRY RESERVE · %d" % fire.bulk_pieces("reserve").size()), "Returning to this camp restores its visible inventory")
	var state := Save.capture(story)
	var restored := Chapter.new(Chapter.Fire.new())
	check(Save.restore(restored, bytes_to_var(var_to_bytes(state))), "Rendered loop saves and reloads")
	check(restored.fire.bulk_stock == fire.bulk_stock, "Rendered stores survive reload")
	var path := "res://outputs/bulk-firewood/Rendered-loop.sav"
	check(Save.write_state(path, state) == OK and lab._load_story(path), "Actual workbench load replaces the live scene")
	if lab.story_menu.visible: lab.story_menu.hide()
	# Examine camera access along entrance, hearth, work areas, reserve and shelf.
	var capture := 0
	for at in [Vector3(0.64, 0.1, 0.8), Vector3(0, 0.1, 0), Vector3(0.83, 0.1, -2.47), Vector3(-0.85, 0.1, -2.83), Vector3(-2.05, 0.15, -2.65)]:
		lab.view.workbench.focus_on(at)
		for i in 30: await process_frame
		var bench = lab.view.workbench
		var pixel: Vector2 = bench.camera.unproject_position(Vector3(at.x, 0.0, at.z))
		var hit = bench.hit(pixel / bench.raster_scale)
		check(not bench.camera.is_position_behind(at) and hit.ground.distance_to(Vector2(at.x, at.z)) < 0.02,
			"Camera and floor picking reach approach " + str(at))
		root.get_texture().get_image().save_png("res://outputs/bulk-firewood/approach-%d.png" % capture)
		capture += 1
	lab._update_fuel_stores("Returned load unloaded; dry kindling fed; three damp pieces placed.")
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("res://outputs/bulk-firewood/cave-stores.png")
	print("Bulk rendered failures ", failed)
	quit(1 if failed else 0)

