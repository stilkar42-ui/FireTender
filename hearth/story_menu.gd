extends Control
## The launch page, chapter cards and save browser share the Red Hollow artwork.

const Profiles := preload("res://sim/story_profiles.gd")
const Chapter := Profiles.Save.Chapter
const Results := preload("res://sim/chapter_results.gd")
const VALLEY := preload("res://hearth/art/red-hollow-valley.png")
const STORM := preload("res://hearth/art/red-hollow-storm.png")
const ROMAN := ["", "I", "II", "III"]
const TITLES := ["", Chapter.TITLE, Chapter.AfterStorm.TITLE, Chapter.Family.TITLE]
const INK := Color("#f5e6cd")
const MUTED := Color("#d4bba2")
const GOLD := Color("#e9ab70")
const DARK := Color("#1a1411")

var lab: Control
var profiles: Profiles
var mode := ""
var return_to_title := false
var title_page: Control
var slot_page: Control
var chapter_page: Control
var results_page: Control
var settings_shade: ColorRect
var storm: TextureRect
var profile_picker: OptionButton
var profile_name: LineEdit
var start_button: Button
var continue_button: Button
var load_button: Button
var back_to_hearth: Button
var title_note: Label
var title_context: Label
var slots_heading: Label
var slots_profile: Label
var slots_note: Label
var slot_buttons: Array[Button] = []
var slots: Array[Dictionary] = []
var overwrite: ConfirmationDialog
var overwrite_slot := -1
var chapter_heading: Label
var chapter_title: Label
var chapter_words: Label
var chapter_button: Button
var results_heading: Label
var results_note: Label
var result_rows: Array[Label] = []
var supply_rows: Array[Label] = []
var results_continue: Button
var results_replay: Button
var results_menu: Button
var blocks: Array[Control] = []

func _init(owner: Control, store: Profiles) -> void:
	lab = owner
	profiles = store
	_build_art()
	_build_title()
	_build_slots()
	_build_chapter()
	_build_results()
	settings_shade = ColorRect.new()
	settings_shade.color = Color(0.04, 0.027, 0.022, 0.46)
	add_child(settings_shade)
	settings_shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	settings_shade.hide()
	hide()
	lab.hearth_hud.add_child(self)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	resized.connect(_layout_blocks)
	_layout_blocks()

func show_title(note := "") -> void:
	_show("title")
	_update_profiles()
	title_note.text = note
	if continue_button.disabled:
		start_button.grab_focus()
	else:
		continue_button.grab_focus()

func show_slots(kind: String, from_title: bool, note := "") -> void:
	return_to_title = from_title
	_show(kind)
	slots_heading.text = "Load game" if kind == "load" else ("Choose a slot for the new story" if kind == "new" else "Save game")
	slots_profile.text = profiles.names[profiles.active]
	slots_note.text = note
	_update_slots()
	if kind == "load" and note.is_empty() and Profiles.newest_first(slots).is_empty():
		slots_note.text = "This profile has no readable saves."
	for button in slot_buttons:
		if not button.disabled:
			button.grab_focus()
			break

func show_chapter(act: int, loading_save := false) -> void:
	_show("chapter")
	storm.visible = act == 1
	chapter_heading.text = "CHAPTER %s" % ROMAN[act]
	chapter_title.text = TITLES[act]
	if loading_save:
		chapter_words.text = "Your saved hearth is ready."
	else:
		var day := 1 if act == 1 else (4 if act == 2 else floori(lab.fire.time / Chapter.Shelter.DAY) + 1)
		chapter_heading.text += "  ·  DAY %d" % day
		chapter_words.text = [
			"",
			"The Fire Speaker has brought back a single coal. Stock wood before the rain and keep the fire alive through Day 3.",
			"The storm has passed. Air-dry one medium and one large log, then learn to dry another pair beside the fire.",
			"The dry reserve is ready. Keep the living hearth as the family returns to its work.",
		][act]
	chapter_button.text = "Return to the hearth" if loading_save or act > 1 else "Enter Red Hollow"
	chapter_button.grab_focus()

func show_results(story: Chapter) -> void:
	var act := Profiles.Save.act(story)
	var report := Results.collect(story)
	var can_continue := story.can_continue()
	_show("results")
	results_heading.text = "Chapter %s · %s" % [ROMAN[act], report.heading]
	results_note.text = report.note
	for index in range(result_rows.size()):
		var entry: Array = report.results[index]
		result_rows[index].text = "%s  ·  %s" % [entry[0], "Done" if entry[1] else "Unfinished"]
		result_rows[index].add_theme_color_override("font_color", INK if entry[1] else MUTED)
	for index in range(supply_rows.size()):
		var row := supply_rows[index]
		row.visible = index < report.supplies.size()
		if row.visible:
			var entry: Array = report.supplies[index]
			row.text = "%s  ·  %s" % [entry[0], entry[1]]
	results_continue.visible = can_continue
	if can_continue:
		results_continue.text = "Continue to Chapter " + ROMAN[act + 1]
	results_replay.visible = not can_continue
	results_replay.text = "Load an earlier save" if act == 2 and lab.launch_at_title else "Retry Chapter " + ROMAN[act]
	results_menu.visible = lab.launch_at_title
	if can_continue:
		results_continue.grab_focus()
	else:
		results_replay.grab_focus()

func dismiss() -> void:
	mode = ""
	hide()

func back() -> void:
	if mode in ["chapter", "results"]:
		return
	if mode == "title":
		if lab.can_return_to_story():
			lab.return_to_hearth()
		return
	if return_to_title:
		show_title()
	elif lab.chapter != null and not lab.chapter.outcome.is_empty():
		show_results(lab.chapter)
	else:
		dismiss()

func _show(page: String) -> void:
	mode = page
	title_page.visible = page == "title"
	slot_page.visible = page in ["save", "load", "new"]
	chapter_page.visible = page == "chapter"
	results_page.visible = page == "results"
	storm.hide()
	settings_shade.hide()
	show()

func _build_art() -> void:
	var valley := _art(VALLEY)
	valley.modulate = Color(0.86, 0.78, 0.70)
	storm = _art(STORM)
	storm.modulate = Color(0.82, 0.79, 0.77, 0.81)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.33, 0.72, 1])
	gradient.colors = PackedColorArray([Color("#17100df7"), Color("#21160eec"), Color("#23171040"), Color("#2317100a")])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.fill_from = Vector2.ZERO
	shade.fill_to = Vector2.RIGHT
	var overlay := _art(shade)
	overlay.stretch_mode = TextureRect.STRETCH_SCALE

func _art(texture: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return art

func _page() -> Control:
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return page

func _block(page: Control, anchor: Vector2, bounds: Rect2) -> Control:
	var block := Control.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(block)
	block.position = bounds.position
	block.size = bounds.size
	block.set_meta("page_anchor", anchor)
	block.set_meta("page_offset", bounds.position)
	blocks.append(block)
	return block

func _layout_blocks() -> void:
	for block in blocks:
		var anchor: Vector2 = block.get_meta("page_anchor")
		var offset: Vector2 = block.get_meta("page_offset")
		block.position = size * anchor + offset

func _rule(parent: Control, bounds: Rect2) -> void:
	var line := ColorRect.new()
	line.color = Color("#b78355a0")
	line.position = bounds.position
	line.size = bounds.size
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _button(parent: Control, words: String, bounds: Rect2, action: Callable, primary := false) -> Button:
	var button: Button = lab._button(parent, words, bounds, action)
	button.focus_mode = FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", lab._style(Color("#332219ed") if primary else Color("#201811e8"),
		Color("#b98051") if primary else Color("#7b5d44")))
	button.add_theme_stylebox_override("focus", lab._style(Color.TRANSPARENT, Color("#edbd83")))
	return button

func _build_title() -> void:
	title_page = _page()
	var left := _block(title_page, Vector2(0, 0.5), Rect2(82, -276, 570, 575))
	lab._label(left, "Firetender", Rect2(0, 0, 550, 111), 82, INK, lab.serif)
	_rule(left, Rect2(4, 119, 276, 1))
	start_button = _button(left, "Start", Rect2(4, 149, 276, 49), lab.start_story_from_menu, true)
	continue_button = _button(left, "Continue", Rect2(4, 210, 276, 49), lab.continue_profile_story)
	load_button = _button(left, "Load", Rect2(4, 271, 276, 49), lab.open_story_slots.bind("load"))
	_button(left, "Settings", Rect2(4, 332, 276, 49), lab._toggle_settings)
	_button(left, "Exit", Rect2(4, 393, 276, 49), func(): get_tree().quit())
	title_note = lab._label(left, "", Rect2(4, 455, 445, 57), 16, MUTED, lab.serif)
	title_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_context = lab._label(left, "", Rect2(4, 455, 445, 27), 16, MUTED, lab.serif)
	title_note.position.y = 480
	title_note.size.y = 42
	back_to_hearth = _button(left, "Back to hearth", Rect2(4, 522, 184, 40), lab.return_to_hearth)
	var right := _block(title_page, Vector2(1, 0), Rect2(-382, 44, 326, 141))
	var backing := Panel.new()
	backing.size = right.size
	backing.add_theme_stylebox_override("panel", lab._style(Color("#1c1512ef"), Color("#76543c")))
	right.add_child(backing)
	lab._label(right, "PLAYER PROFILE", Rect2(17, 10, 260, 27), 13, GOLD)
	profile_picker = lab._picker(right, Rect2(16, 39, 294, 35), _select_profile)
	profile_picker.focus_mode = FOCUS_ALL
	profile_name = LineEdit.new()
	profile_name.position = Vector2(16, 88)
	profile_name.size = Vector2(207, 35)
	profile_name.max_length = 24
	profile_name.tooltip_text = "Name for this profile"
	profile_name.add_theme_stylebox_override("normal", lab._style(DARK, Color("#846043")))
	profile_name.add_theme_color_override("font_color", INK)
	profile_name.text_submitted.connect(func(_words: String) -> void: _rename_profile())
	right.add_child(profile_name)
	_button(right, "Rename", Rect2(232, 88, 78, 35), _rename_profile)

func _build_slots() -> void:
	slot_page = _page()
	var box := _block(slot_page, Vector2(0.5, 0.5), Rect2(-463, -291, 926, 582))
	var backing := Panel.new()
	backing.size = box.size
	backing.add_theme_stylebox_override("panel", lab._style(Color("#1b1511fa"), Color("#977152")))
	box.add_child(backing)
	slots_heading = lab._label(box, "", Rect2(29, 20, 630, 54), 40, INK, lab.serif)
	slots_profile = lab._label(box, "", Rect2(647, 28, 247, 35), 18, GOLD, lab.serif)
	slots_profile.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slots_profile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rule(box, Rect2(30, 81, 866, 1))
	for slot in range(Profiles.SLOTS):
		var x := 30 + 443 * floori(slot / 5.0)
		var y := 105 + 77 * (slot % 5)
		var button := _button(box, "", Rect2(x, y, 423, 64), _pick_slot.bind(slot))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_buttons.append(button)
	slots_note = lab._label(box, "", Rect2(29, 504, 679, 50), 16, MUTED, lab.serif)
	slots_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(box, "Back", Rect2(765, 515, 131, 38), back)
	overwrite = ConfirmationDialog.new()
	overwrite.title = "Replace save?"
	overwrite.ok_button_text = "Replace"
	overwrite.confirmed.connect(func(): _use_slot(overwrite_slot))
	add_child(overwrite)

func _build_chapter() -> void:
	chapter_page = _page()
	var left := _block(chapter_page, Vector2(0, 0.5), Rect2(88, -190, 620, 437))
	chapter_heading = lab._label(left, "", Rect2(3, 0, 595, 35), 18, GOLD)
	_rule(left, Rect2(3, 49, 108, 1))
	chapter_title = lab._label(left, "", Rect2(0, 61, 598, 159), 61, INK, lab.serif)
	chapter_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_words = lab._label(left, "", Rect2(3, 227, 455, 81), 22, MUTED, lab.serif)
	chapter_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_button = _button(left, "", Rect2(3, 332, 260, 51), dismiss, true)

func _build_results() -> void:
	results_page = _page()
	var box := _block(results_page, Vector2(0.5, 0.5), Rect2(-473, -249, 946, 498))
	var backing := Panel.new()
	backing.size = box.size
	backing.add_theme_stylebox_override("panel", lab._style(Color("#1b1511f8"), Color("#977152")))
	box.add_child(backing)
	results_heading = lab._label(box, "", Rect2(32, 20, 880, 60), 39, INK, lab.serif)
	results_note = lab._label(box, "", Rect2(33, 83, 864, 64), 19, MUTED, lab.serif)
	results_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule(box, Rect2(34, 154, 878, 1))
	lab._label(box, "Your tending", Rect2(33, 170, 395, 38), 25, GOLD, lab.serif)
	lab._label(box, "On hand", Rect2(496, 170, 398, 38), 25, GOLD, lab.serif)
	for index in range(4):
		result_rows.append(lab._label(box, "", Rect2(35, 216 + index * 32, 438, 27), 17, INK))
	for index in range(6):
		supply_rows.append(lab._label(box, "", Rect2(498, 216 + index * 32, 405, 27), 17, INK))
	_rule(box, Rect2(34, 419, 878, 1))
	results_continue = _button(box, "", Rect2(654, 438, 258, 39), lab._continue_story, true)
	results_replay = _button(box, "", Rect2(654, 438, 258, 39), lab._retry_ended_chapter, true)
	results_menu = _button(box, "Main menu", Rect2(33, 438, 152, 39), lab.show_title)

func _select_profile(index: int) -> void:
	var result := profiles.select(index)
	_update_profiles()
	if result != OK:
		title_note.text = "Profile selected for this session. Its selection could not be saved."

func _rename_profile() -> void:
	var result := profiles.rename_active(profile_name.text)
	_update_profiles()
	if result != OK:
		title_note.text = "Enter a profile name." if result == ERR_INVALID_PARAMETER else "The profile name could not be saved."

func _update_profiles() -> void:
	profile_picker.clear()
	for name in profiles.names:
		profile_picker.add_item(name)
	profile_picker.select(profiles.active)
	profile_name.text = profiles.names[profiles.active]
	var available := Profiles.newest_first(profiles.list_slots())
	continue_button.disabled = available.is_empty()
	continue_button.tooltip_text = "" if available.is_empty() else _slot_description(available[0])
	title_context.text = "No saved story" if available.is_empty() else \
		"Latest save · " + _slot_description(available[0]).get_slice("\n", 0)
	back_to_hearth.visible = lab.can_return_to_story()
	title_note.text = ""

func _update_slots() -> void:
	slots = profiles.list_slots()
	for entry in slots:
		var button := slot_buttons[int(entry.slot)]
		button.text = "%02d   %s" % [int(entry.slot) + 1, _slot_description(entry)]
		button.disabled = mode == "load" and entry.act == 0

func _slot_description(entry: Dictionary) -> String:
	if not entry.present:
		return "Empty"
	if entry.act == 0:
		return "Unreadable save"
	var day := floori(entry.time / Chapter.Shelter.DAY) + 1
	if entry.act == 1:
		day = mini(3, day)
	var local: float = entry.saved_at + Time.get_time_zone_from_system().bias * 60
	var date := Time.get_datetime_string_from_unix_time(int(local), true).left(16)
	return "Chapter %s  ·  Day %d\n       %s%s" % [ROMAN[entry.act], day, date, "  ·  Previous save" if entry.legacy else ""]

func _pick_slot(slot: int) -> void:
	if mode != "load" and slots[slot].present:
		overwrite_slot = slot
		overwrite.dialog_text = "Replace slot %02d in %s?" % [slot + 1, profiles.names[profiles.active]]
		overwrite.popup_centered()
		return
	_use_slot(slot)

func _use_slot(slot: int) -> void:
	match mode:
		"new": lab.start_story_from_menu(slot)
		"save": lab.save_profile_slot(slot)
		"load": lab.load_profile_slot(slot)
