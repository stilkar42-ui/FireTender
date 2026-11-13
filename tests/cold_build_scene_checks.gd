extends "res://tests/physical_work_scene_checks.gd"

const Fire := Save.Fire

func _run() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-cold-build-%d.cfg" % OS.get_process_id())
	lab.blueprints_path = lab.settings_path + ".blueprints"
	root.add_child(lab)
	await _settle()
	lab.trials.item_selected.emit(Fire.COLD_CABIN + 1)
	await _settle()
	_key(KEY_P)
	await _settle()
	_check(lab.crafting.panel.visible and lab.crafting.work.visible, "P opens Crafting with the Tinder Bundle recipe")
	await _capture("crafting-menu")
	var work_start: float = lab.fire.time
	_click(lab.crafting.work.get_global_rect().get_center())
	await _settle()
	_check(not lab.fire.tinder_job.is_empty() and lab.crafting.progress.visible and not lab.crafting.place.visible,
		"The crafting page shows work in progress before the bundle exists")
	_click(lab.crafting.finish_now.get_global_rect().get_center())
	for frame in range(120):
		if lab.fire.tinder_job.is_empty():
			break
		await process_frame
	_check(is_equal_approx(lab.fire.time - work_start, Fire.TINDER_WORK_TIME) and lab.crafting.place.visible,
		"Crafting advances the actual hearth clock before offering the bundle")
	_click(lab.crafting.place.get_global_rect().get_center())
	await _settle()
	var bundle: Fire.Piece = lab.view.placing_piece
	if bundle == null:
		_check(false, "Crafting prepares an actual tinder bundle")
		quit(1)
		return
	_check(bundle.kind == Fire.TINDER_BUNDLE and lab.bundle_known, "Taking the bundle selects the crafted fuel")
	var center := _screen(Vector2.ZERO, 0)
	_click(center)
	await _settle()
	_check(bundle.at.distance_to(Vector2.ZERO) < 0.026 and bundle.tier < 0, "The bundle can be placed beneath the built cabin")
	await _capture("cold-cabin")
	_key(KEY_F12)
	await _settle()
	_check(lab.blueprint_panel.visible and lab.paused, "F12 opens the blueprint library while the hearth is paused")
	lab.blueprint_name.text = "Cabin with tinder"
	lab.blueprint_name.text_submitted.emit("Cabin with tinder")
	_check(lab.blueprints.plans.has("Cabin with tinder"), "The named cold layout is saved through the interface")
	await _capture("blueprint-library")
	_key(KEY_ESCAPE)
	_key(KEY_F4)
	await _settle()
	var fire: Fire = lab.fire
	var ember := fire.coals[0]
	fire.lift_coal(ember)
	fire.deposit_coal(ember, Vector2(0.54, 0.03))
	_key(KEY_F12)
	await _settle()
	_click(lab.blueprint_rebuild.get_global_rect().get_center())
	await _settle()
	_check(not lab.blueprint_panel.visible and lab.fire.wood.size() >= 12, "Rebuild restores the cabin to an empty hearth")
	await _settle()
	_key(KEY_C)
	_move(_screen(ember.at, ember.height))
	_mouse(_screen(ember.at, ember.height), true)
	_move(center, MOUSE_BUTTON_MASK_LEFT)
	_mouse(center, false)
	await _settle()
	_check(not ember.carried and ember.at.distance_to(Vector2.ZERO) < 0.05 and ember.height > 0.009,
		"The carry tool places the same live ember inside the leaf bundle")
	var peak := 0.0
	var captured := false
	for tick in range(300):
		if tick in [1, 14, 32]:
			fire.send_breath(Vector2(0, 0.43), Vector2.ZERO, 0.84, 1.2)
		fire.step()
		peak = maxf(peak, fire.total_flame())
		if not captured and tick > 115 and fire.total_flame() > 40.0:
			captured = true
			await _settle()
			await _capture("cabin-burning")
	_check(peak > 80.0 and captured, "The rebuilt cold cabin develops into a sustained fire")
	DirAccess.remove_absolute(lab.blueprints_path)
	print("Cold builds rendered: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
