extends "res://tests/physical_work_scene_checks.gd"

const Launch := preload("res://hearth/launch.tscn")
const Profiles := preload("res://sim/story_profiles.gd")
const Shelter := Chapter.Shelter
var sandbox: String

func _run() -> void:
	sandbox = OS.get_environment("TEMP").path_join("firetender-launch-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(sandbox)
	var legacy := sandbox.path_join("old-chapter-iii.sav")
	var old := Chapter.new(Save.Fire.new())
	old.set_up_family_trial()
	var data := Save.capture(old)
	data.version = 2
	data.erase("act")
	data.erase("saved_at")
	data.erase("gathering")
	data.erase("field_land")
	data.chapter.sites = Chapter.ROUTES.map(func(route): return route.loads.duplicate(true))
	data.chapter.sites[1][0].clear()
	data.chapter.carried_load = []
	_check(Save.write_state(legacy, data) == OK, "A previous Chapter III save is available for migration")
	_attach_launch(legacy)
	await _settle()
	var menu = lab.story_menu
	_check(menu.visible and menu.mode == "title" and lab.chapter == null and lab.paused,
		"The project opens at the launch page with the simulation paused")
	_check(not lab.sound.active and (lab.sound.player == null or not lab.sound.player.playing),
		"The launch page starts without hearth audio")
	_check(menu.profile_picker.item_count == 5 and not menu.continue_button.disabled
		and lab.profiles.load_path(0) == legacy, "Five profiles and the old save under Profile 1")
	var settings: Button
	for node in menu.title_page.find_children("*", "Button", true, false):
		if node.text == "Settings":
			settings = node
			break
	_button_press(settings)
	await _settle()
	_check(lab.settings_panel.visible and menu.settings_shade.visible, "Settings opens from the launch page")
	_key(KEY_ESCAPE)
	await _settle()
	await _capture("launch-menu")
	_button_press(menu.load_button)
	await _settle()
	_check(menu.slot_buttons.size() == 10 and menu.slot_buttons[0].text.contains("Previous save"),
		"The Load page shows ten slots and labels the previous save")
	_button_press(menu.slot_buttons[0])
	await _settle()
	_check(menu.mode == "chapter" and lab.chapter.family != null, "The previous Chapter III save loads from the menu")
	_button_press(menu.chapter_button)
	_key(KEY_ESCAPE)
	await _settle()
	menu.profile_picker.item_selected.emit(1)
	_check(menu.continue_button.disabled and lab.profiles.first_empty() == 0 and not FileAccess.file_exists(lab.profiles.load_path(0)),
		"Switching to Profile 2 reveals a separate empty directory")
	menu.profile_name.text = "Storm Keeper"
	menu.profile_name.text_submitted.emit("Storm Keeper")
	_check(lab.profiles.names[1] == "Storm Keeper", "A profile can be renamed")
	_button_press(menu.back_to_hearth)
	await _settle()
	_check(lab.profiles.active == 0 and not menu.visible, "Back to hearth restores the open story’s own profile")
	lab.show_title()
	menu.profile_picker.item_selected.emit(1)
	_button_press(menu.start_button)
	await _settle()
	_check(menu.mode == "chapter" and menu.chapter_heading.text.contains("DAY 1") and lab.fire.time == 0.0
		and Save.saved_act(Save.read_slot(lab.profiles.slot_path(0))) == 1, "Start creates a Chapter I save in this profile")
	_check(not lab.sound.active and (lab.sound.player == null or not lab.sound.player.playing),
		"The loading page stays silent")
	await _capture("chapter-i-loading")
	_key(KEY_SPACE)
	await _settle()
	_check(lab.fire.time == 0.0 and lab.paused, "The hearth cannot advance behind the chapter card")
	_button_press(menu.chapter_button)
	_check(lab.sound.active and (lab.sound.player == null or lab.sound.player.playing),
		"Hearth audio starts when the player enters the cave")

	var fire: Save.Fire = lab.fire
	var bed := fire.coals[0]
	lab.chapter.request(1)
	fire.time = Shelter.END - Save.Fire.STEP * 2
	lab.chapter.sampled_at = fire.time - 0.5
	bed.temperature = 610
	lab.chapter.bed = true
	lab.chapter.preserved = true
	lab.chapter.step()
	_check(lab.chapter.outcome.is_empty() and fire.time < Shelter.END, "A prepared hearth cannot end Chapter I before Day 3 ends")
	lab.chapter.step()
	await _settle()
	_check(lab.chapter.outcome == "kept" and lab.chapter.weather.rain == 0.0 and lab.chapter.weather.thunder == 0.0
		and lab.chapter.weather.day_words(fire.time) == "Day 3 · End", "The Day 3 ending waits for the rain to clear")
	_check(menu.mode == "results" and menu.results_continue.visible and menu.supply_rows[1].text.contains("Dry tinder"),
		"The Day 3 results open automatically with the carryover supplies")
	_key(KEY_F5)
	await _settle()
	_check(menu.mode == "save" and menu.slot_buttons[9].text.contains("Empty"), "F5 opens ten slots in Chapter I")
	_button_press(menu.slot_buttons[9])
	await _settle()
	var chapter_one := Save.read_slot(lab.profiles.slot_path(9))
	_check(chapter_one.chapter.outcome == "kept" and chapter_one.fire.time == Shelter.END,
		"The tenth slot records the Day 3 completion")

	_check(menu.mode == "results", "Saving from the results returns to the handoff")
	_button_press(menu.results_continue)
	await _settle()
	_check(menu.mode == "chapter" and menu.chapter_heading.text.contains("DAY 4") and lab.chapter.sequel.begun == Shelter.END
		and fire.coals[0] == bed and lab.chapter.weather.day_words(fire.time).contains("Day 4")
		and Save.saved_act(Save.read_slot(lab.profiles.slot_path(9))) == 2,
		"Chapter II opens on Day 4 with the same coals and clock")
	await _capture("chapter-ii-loading")
	_button_press(menu.chapter_button)
	_key(KEY_F5)
	await _settle()
	_button_press(menu.slot_buttons[9])
	await _settle()
	_check(menu.overwrite.visible and Save.read_slot(lab.profiles.slot_path(9)).fire.time == Shelter.END,
		"Saving over an occupied slot requires confirmation")
	menu.overwrite.hide()
	menu.overwrite.confirmed.emit()
	await _settle()
	_check(Save.saved_act(Save.read_slot(lab.profiles.slot_path(9))) == 2, "Confirming overwrite updates only the chosen slot")
	_key(KEY_F11)
	await _settle()
	await _capture("profile-save-browser")
	_button_press(menu.slot_buttons[0])
	await _settle()
	_check(lab.chapter.sequel == null and lab.fire.time == 0.0 and menu.chapter_heading.text == "CHAPTER I",
		"Loading the first slot returns to the original Chapter I save")
	_button_press(menu.chapter_button)
	lab.show_title()
	_check(not lab.sound.active and lab.sound.playback == null and (lab.sound.player == null or not lab.sound.player.playing),
		"Returning to the title stops the hearth mixer and its audio buffer")
	_button_press(menu.continue_button)
	await _settle()
	_check(menu.chapter_heading.text == "CHAPTER II" and lab.chapter.sequel.begun == Shelter.END,
		"Continue restores the latest save in the active profile")
	_button_press(menu.chapter_button)
	var prior_result := Save.read_slot(lab.profiles.slot_path(0))
	_check(Save.write_state(lab.profiles.slot_path(0), chapter_one) == OK, "An earlier Chapter I result can be loaded")
	lab.show_title()
	_button_press(menu.load_button)
	await _settle()
	_button_press(menu.slot_buttons[0])
	await _settle()
	_check(menu.mode == "results" and menu.results_continue.visible and lab.chapter.sequel == null,
		"Loading a finished Chapter I returns directly to its results")
	_check(Save.write_state(lab.profiles.slot_path(0), prior_result) == OK, "The original test slot can be restored")

	var store := Profiles.new()
	store.folder = lab.profiles.folder
	store.legacy_path = legacy
	store.read_preferences()
	_check(store.active == 1 and store.names[1] == "Storm Keeper", "The profile selection and name persist")
	var filled := true
	var paths := {}
	for profile in range(Profiles.PROFILES):
		store.select(profile)
		for slot in range(Profiles.SLOTS):
			var path := store.slot_path(slot)
			filled = Save.write_state(path, chapter_one) == OK and filled
			paths[path] = true
		filled = store.first_empty() == -1 and filled
	_check(filled and paths.size() == 50, "All fifty save slots can coexist in five separate directories")
	var unprepared := Chapter.new(Save.Fire.new())
	unprepared.fire.time = Shelter.END - Save.Fire.STEP
	unprepared.step()
	_check(unprepared.outcome == "unprepared" and unprepared.begin_after_storm(),
		"A living fire carries into Day 4 even when the tending milestones are unfinished")
	var lost := Chapter.new(Save.Fire.new())
	lost.fire.coals.clear()
	lost.fire._reindex()
	lost.fire.network_dirty = true
	lost.fire.time = Shelter.END - Save.Fire.STEP
	lost.step()
	_check(lost.outcome == "lost" and not lost.begin_after_storm(),
		"An extinguished hearth still requires a retry or earlier save")
	print("Launch, chapter cards and profiles: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _attach_launch(legacy: String) -> void:
	lab = Launch.instantiate()
	lab.profiles_path = sandbox.path_join("profiles")
	lab.chapter_save_path = legacy
	lab.settings_path = sandbox.path_join("settings.cfg")
	root.add_child(lab)

func _button_press(button: Button) -> void:
	if DisplayServer.get_name() == "headless":
		button.pressed.emit()
	else:
		_click(button.get_global_rect().get_center())

func _capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await super._capture(name)
