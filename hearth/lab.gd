extends Control

const Fire := preload("res://sim/fire.gd")
const Observe := preload("res://sim/observe.gd")
const View := preload("res://hearth/fire_view.gd")
const Audio := preload("res://hearth/fire_audio.gd")
const Mentor := preload("res://sim/mentor.gd")
const FuelIcons := preload("res://hearth/fuel_icons.gd")
const Heat := preload("res://sim/felt_heat.gd")
const Touch := preload("res://sim/felt_touch.gd")
const HeatHand := preload("res://hearth/heat_hand.gd")
const AmbientFigure := preload("res://hearth/ambient_figure.gd")
const FeltWeather := preload("res://sim/felt_weather.gd")
const Advice := preload("res://sim/speaker_advice.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const ChapterSave := preload("res://sim/chapter_save.gd")
const StoryMenu := preload("res://hearth/story_menu.gd")
const Profiles := StoryMenu.Profiles
const Blueprints := preload("res://sim/fire_blueprints.gd")
const Crafting := preload("res://hearth/crafting_page.gd")
const FamilyPage := preload("res://hearth/family_page.gd")
const Scenery := preload("res://hearth/hearth_scenery.gd")
const SHADE := preload("res://hearth/overlay_shade.gdshader")
const PANEL := Color("#221b17")
const LINE := Color("#544032")
const TEXT := Color("#eee0c9")
const MUTED := Color("#d1bba4")
const GOLD := Color("#f0b77b")
const RIGHT := Vector2(1.0, 0.0)
const LOWER_LEFT := Vector2(0.0, 1.0)
const LOWER_RIGHT := Vector2.ONE
const LOWER_CENTER := Vector2(0.5, 1.0)
const CENTER := Vector2(0.5, 0.5)
const SPEEDS := [1, 4, 16, 64]
const SMOOTH_TURN_RATE := PI * 0.5
const SMOOTH_TAP := PI / 90.0
const FUEL_GROUPS := [
	["Tinder", [4, 5, Fire.LEAVES, Fire.TINDER_BUNDLE]], ["Starter", [0, 1]], ["Small", [6, 7]],
	["Medium", [8, 11, 12, 13]], ["Large", [9, 2, 10]], ["Waterlogged", [3]],
]
const FUEL_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "U", "J", "K", ",", "."]
const WET_KINDS := [2, 8, 11, 12, 13]
const SHELTER_AREAS := ["Hearth", "Dry shelf · back left", "Tinder alcove · left", "Warming edge", "Seep · back right", "Air passage · right"]
const AREA_FOCUS := [Vector2.ZERO, Vector2(-1.89, -3.21), Vector2(-1.94, -2.28), Vector2(-1.02, -0.20),
	Chapter.Shelter.SEEP, Chapter.Shelter.PASSAGE]
const FUEL_DESCRIPTIONS := [
	"Thin, curled birch bark that catches from a small flame.",
	"A fan of pine twigs for carrying flame to kindling.",
	"A dense oak split that burns slowly once hot.",
	"Saturated wood that draws heat as its water evaporates.",
	"Light, dry bark fibres that can take a glow from a coal.",
	"Loose dry grass blades. Leave room for air between them.",
	"Thin splinters that take the first flame quickly.",
	"Finger-sized sticks for building the next layer.",
	"A split branch with exposed wood along its length.",
	"A thick branch for bridging or leaning.",
	"A long, heavy split for a sustained fire.",
	"A relatively light pine branch with twisting grain.",
	"A pale, denser birch branch with a close grain.",
	"A light willow branch that starts with more moisture.",
	"Loose tinder. Combine it with another parcel in Crafting [P].",
	"Worked tinder with a hollow for a small ember.",
]

var fire := Fire.new(Fire.OPENING)
var mentor := Mentor.new()
var view: View
var edge_shade: ShaderMaterial
var hearth_hud: Control
@export var scenery: Scenery = preload("res://hearth/art/red_hollow.tres")
var sound: Audio
var warmth: Label
var ambient_overlay: Control
var ambient_figure: AmbientFigure
var ambient_words: Label
var journal: Control
var heat_title: Label
var note_title: Label
var heat_hand: HeatHand
var heat_clock := 0.0
var mode_buttons: Dictionary
var accumulator := 0.0
var jump_steps := 0
var speed := 1
var paused := false
var fuel_buttons: Array[Button] = []
var group_buttons: Array[Button] = []
var fuel_icons: Array[Texture2D] = []
var fuel_group := 1
var last_fuel := 4
var last_wet := false
var wet_buttons: Dictionary = {}
var wet_tray_buttons: Dictionary = {}
var return_tool := View.Tool.WOOD
var recall_button: Button
var hint: Label
var time_label: Label
var note: Label
var pause_button: Button
var weather_picker: OptionButton
var rate: OptionButton
var trials: OptionButton
var debug: Panel
var report: TextEdit
var debug_clock := 0.0
var serif: SystemFont
var mono: SystemFont
var speech: Panel
var speech_text: Label
var practice_line: Label
var history_panel: Panel
var tale_button: Button
var showing_tale := false
var history_text: RichTextLabel
var retry_button: Button
var history_version := -1
var ask_panel: Panel
var ask_entry: LineEdit
var ask_picker: OptionButton
var fuel_bar: Control
var ask_topics: Array[String] = []
var ask_hand := Vector3.ZERO
var ask_clock := 0.0
var palette: Panel
var workbench_tools: Control
var snap_button: Button
var settings_path := "user://settings.cfg"
var chapter_save_path := "user://chapter-iii.sav"
var profiles_path := "user://profiles"
var profiles := Profiles.new()
var story_menu: StoryMenu
var story_profile := -1
var story_slot := -1
var blueprints := Blueprints.new()
var blueprints_path := "user://fire-blueprints.cfg"
var blueprint_panel: Panel
var blueprint_picker: OptionButton
var blueprint_name: LineEdit
var blueprint_details: Label
var blueprint_status: Label
var blueprint_rebuild: Button
var blueprint_overwrite: ConfirmationDialog
var bundle_known := false
var crafting := Crafting.new()
var craft_notice := ""
var save_family_button: Button
var load_family_button: Button
var preferences := ConfigFile.new()
var settings_panel: Panel
var rotation_hint: Label
var smooth_rotation := false
var invert_wind := false
var invert_wind_button: Button
var held_turns := {}
var held_camera_keys := {}
var tending_controls: Control
var start_in_story := true
@export var launch_at_title := false
var chapter: Chapter
var chapter_controls: Control
var chapter_note: Label
var chapter_weather: Label
var chapter_ash: Label
var quest_button: Button
var quest_panel: Panel
var quest_heading: Label
var quest_words: Label
var quest_rows: Array[Label] = []
var quest_footer: Label
var quest_locations: Array[Button] = []
var ash_button: Button
var site_picker: OptionButton
var shelter_area_start := 0
var family_page: FamilyPage
var family_button: Button
var family_news_button: Button
var mind_cave_button: Button
var heat_request_button: Button
var family_area_start := 0
var family_news_seen := -1
var torch_button: Button
var torch_panel: Panel
var torch_report: Label
var torch_site: OptionButton
var torch_priority: OptionButton
var torch_detail: Label
var torch_status: Label
var torch_send: Button
var fuel_tray_buttons: Array[Button] = []
var supply_revision := -1
var stock_revision := -1
var stock_read_at := -INF

func _ready() -> void:
	serif = _font(["Georgia", "Cambria"])
	mono = _font(["Consolas", "Courier New"])
	_make_theme()
	view = View.new()
	view.fire = fire
	view.scenery = scenery
	add_child(view)
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_shade = ShaderMaterial.new()
	edge_shade.shader = SHADE
	shade.material = edge_shade
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit_scene)
	_fit_scene()
	sound = Audio.new()
	sound.fire = fire
	sound.set_active(not launch_at_title)
	add_child(sound)
	fire.structure_event.connect(sound.structure_event)
	fire.tinder_finished.connect(_on_tinder_finished)
	view.placed.connect(_placed)
	view.cancelled.connect(_cancel)
	view.moved.connect(func(piece: Fire.Piece) -> void:
		sound.contact(piece.at, false, piece.core != null)
		mentor.tend("move", fire)
		_build_status(piece))
	view.arranged.connect(func(piece: Fire.Piece) -> void:
		sound.contact(piece.at, false, piece.core != null)
		mentor.tend("arrange", fire)
		_build_status(piece))
	view.rolled.connect(func(piece: Fire.Piece) -> void:
		sound.contact(piece.at, false, true)
		mentor.tend("roll", fire)
		hint.text = "Wood rolled. Its underside now faces the air.")
	view.raked.connect(func(count: int, at: Vector2) -> void:
		if count > 0:
			sound.contact(at, true)
			mentor.tend("rake", fire)
		hint.text = "You draw charcoal and ash to a new spot." if count else "Start the rake over a patch of coals.")
	view.breathed.connect(func(_at: Vector2, forceful: bool) -> void:
		mentor.tend("breathe", fire)
		if paused:
			hint.text = "Breath ready. Resume or advance time to see the coals respond."
		else:
			hint.text = ("Hard gust" if forceful else "Gentle breath") + "   ·   Watch the red   ·   B repeats when the aim turns ochre")
	view.speaker_selected.connect(_toggle_history)
	view.torch_selected.connect(_toggle_torch)
	view.coal_moved.connect(func(at: Vector2) -> void:
		sound.contact(at, true)
		mentor.tend("move ember", fire)
		hint.text = "The same live coal rests in its new place. Give the fibres room for breath.")
	view.blocked.connect(func() -> void: hint.text = "Solid wood blocks that path. Try a thinner piece, a lower angle, or an open side.")
	view.full.connect(func() -> void: hint.text = "The hearth is crowded. Let some of the fuel burn down.")
	view.ash_swept.connect(func(mass: float) -> void:
		if mass > 0.0:
			mentor.tend("sweep ash", fire)
		hint.text = "You move the ash. Drop it over red to cover the coals." if mass > 0.0 else "Sweep from a pale patch or a loose pile of ash.")
	hearth_hud = _hud_layer()
	_header()
	_build_tools()
	_controls()
	_fuel_bar()
	_mentor_ui()
	_fuel_palette()
	_debug_view()
	_settings_view()
	_chapter_ui()
	_build_blueprints()
	crafting.build(self)
	family_page = FamilyPage.new(self)
	view.station_selected.connect(func(station: String) -> void: family_page.open_station(station, false))
	view.material_feedback.connect(func(words: String) -> void:
		if not words.is_empty():
			hint.text = words)
	view.material_placed.connect(_material_placed)
	story_menu = StoryMenu.new(self, profiles)
	story_menu.visibility_changed.connect(func(): sound.set_active(not story_menu.visible))
	settings_panel.move_to_front()
	if launch_at_title:
		profiles.folder = profiles_path
		profiles.legacy_path = chapter_save_path
		profiles.read_preferences()
		_pause()
		show_title()
	elif start_in_story:
		_start_chapter()
	else:
		mentor.enter(fire, true)
	_default_hint()
	_update_speaker()
	_inspect()
	_update_time()

func _fit_scene() -> void:
	view.fit_scene(size)
	edge_shade.set_shader_parameter("canvas_size", size)
	_layout_consultation()

func _layout_consultation() -> void:
	if fuel_bar == null or ask_panel == null:
		return
	if chapter != null:
		var right := size.x - (354.0 if ask_panel.visible else 28.0)
		var width := minf(824.0, right - 322.0)
		var left := clampf((size.x - width) * 0.5, 322.0, right - width)
		var factor := width / 824.0
		fuel_bar.scale = Vector2.ONE * factor
		fuel_bar.offset_left = left - size.x * 0.5
		fuel_bar.offset_right = fuel_bar.offset_left + 824.0
		fuel_bar.offset_top = -21.0 - 114.0 * factor
		fuel_bar.offset_bottom = fuel_bar.offset_top + 114.0
		hint.visible = not ask_panel.visible
		return
	var shift := minf(0.0, size.x - 342.0 - 12.0 - (size.x * 0.5 + 412.0)) if ask_panel.visible else 0.0
	fuel_bar.scale = Vector2.ONE
	fuel_bar.offset_left = -412.0 + shift
	fuel_bar.offset_right = 412.0 + shift
	fuel_bar.offset_top = -135.0
	fuel_bar.offset_bottom = -21.0
	hint.show()

func _header() -> void:
	_label(hearth_hud, "Firetender", Rect2(28, 13, 250, 35), 28, TEXT, serif)
	if launch_at_title:
		var menu_bar := _overlay(Rect2(165, 19, 90, 28))
		_button(menu_bar, "Menu", Rect2(0, 0, 82, 28), show_title)
	practice_line = _label(hearth_hud, "", Rect2(29, 50, 440, 22), 14, MUTED)
	practice_line.mouse_filter = Control.MOUSE_FILTER_PASS
	var header := _overlay(Rect2(-516, 19, 488, 34), RIGHT)
	_button(header, "Red Hollow  [F1]", Rect2(0, 0, 138, 34), _replay_story, "Begin the opening chapter again.")
	_button(header, "Practice  [F2]", Rect2(146, 0, 109, 34), _restart_practice,
		"Start a fresh apprenticeship at the inherited fire.")
	var challenge := _button(header, "One Ember  [F4]", Rect2(263, 0, 132, 34), _start_ember)
	challenge.add_theme_color_override("font_color", GOLD)
	_button(header, "Settings", Rect2(403, 0, 85, 34), _toggle_settings)

func _build_tools() -> void:
	var tools := _overlay(Rect2(28, 106, 285, 133))
	_label(tools, "W O R K B E N C H", Rect2(0, 0, 190, 19), 12, GOLD)
	snap_button = _button(tools, "Snap on  [N]", Rect2(0, 25, 108, 32), _toggle_snap)
	_mode_button(tools, "Feed sticks  [X]", Rect2(116, 25, 169, 32), View.Tool.FEED)
	_mode_button(tools, "Roll  [T]", Rect2(0, 63, 64, 32), View.Tool.ROLL)
	_mode_button(tools, "Move coals  [R]", Rect2(70, 63, 113, 32), View.Tool.RAKE)
	_mode_button(tools, "Breathe  [B]", Rect2(189, 63, 96, 32), View.Tool.BREATH)
	_mode_button(tools, "Carry ember  [C]", Rect2(0, 101, 151, 32), View.Tool.COAL)
	_mode_button(tools, "Sweep ash  [Y]", Rect2(157, 101, 128, 32), View.Tool.ASH)
	ash_button = mode_buttons[View.Tool.ASH]
	ash_button.hide()
	workbench_tools = _overlay(Rect2(28, 245, 285, 32))
	_button(workbench_tools, "Focus  [F]", Rect2(0, 0, 82, 32), view.focus_camera,
		"Focus on the selected wood or on the ground beneath the cursor.")
	_button(workbench_tools, "Reset view", Rect2(88, 0, 91, 32), _reset_camera,
		"Home restores the full hearth view.")
	_button(workbench_tools, "+2 seconds", Rect2(185, 0, 100, 32), func() -> void: _advance(2.0))
	_button(tools, "Blueprints  [F12]", Rect2(298, 25, 147, 32), _toggle_blueprints)
	_button(tools, "Crafting  [P]", Rect2(298, 63, 147, 32), _toggle_crafting)

func _build_blueprints() -> void:
	blueprints.path = blueprints_path
	blueprints.read()
	blueprint_panel = _panel(Rect2(-287, -151, 574, 302), CENTER)
	blueprint_panel.visibility_changed.connect(func():
		if not blueprint_panel.visible:
			view.mouse_filter = Control.MOUSE_FILTER_STOP)
	_label(blueprint_panel, "Fire blueprints", Rect2(20, 13, 440, 42), 30, GOLD, serif)
	_button(blueprint_panel, "Close", Rect2(462, 18, 92, 32), _toggle_blueprints)
	blueprint_picker = _picker(blueprint_panel, Rect2(20, 65, 534, 35), _choose_blueprint)
	blueprint_details = _label(blueprint_panel, "", Rect2(20, 104, 534, 65), 15, TEXT)
	blueprint_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blueprint_name = LineEdit.new()
	blueprint_name.position = Vector2(20, 175)
	blueprint_name.size = Vector2(249, 34)
	blueprint_name.max_length = 48
	blueprint_name.placeholder_text = "Name this layout"
	blueprint_name.text_submitted.connect(func(_words: String): _save_blueprint())
	blueprint_panel.add_child(blueprint_name)
	_button(blueprint_panel, "Save layout", Rect2(280, 175, 126, 34), _save_blueprint)
	blueprint_rebuild = _button(blueprint_panel, "Rebuild", Rect2(415, 175, 139, 34), _rebuild_blueprint)
	blueprint_status = _label(blueprint_panel, "", Rect2(20, 218, 534, 67), 15, MUTED)
	blueprint_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blueprint_overwrite = ConfirmationDialog.new()
	blueprint_overwrite.title = "Replace blueprint?"
	blueprint_overwrite.ok_button_text = "Replace"
	blueprint_overwrite.confirmed.connect(_write_blueprint)
	blueprint_panel.add_child(blueprint_overwrite)
	blueprint_panel.hide()

func _toggle_blueprints() -> void:
	if blueprint_panel.visible:
		blueprint_panel.hide()
		return
	_freeze_story_ui()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint_panel.show()
	_refresh_blueprints()
	blueprint_status.text = "Save a cold layout before lighting. Rebuild on a clear hearth."

func _refresh_blueprints(chosen := "") -> void:
	blueprint_picker.clear()
	var names := blueprints.plans.keys()
	names.sort()
	for title: String in names:
		blueprint_picker.add_item(title)
	if not chosen.is_empty() and chosen in names:
		blueprint_picker.select(names.find(chosen))
	_choose_blueprint(blueprint_picker.selected)

func _choose_blueprint(index: int) -> void:
	blueprint_rebuild.disabled = index < 0
	blueprint_details.text = "No saved layouts." if index < 0 else \
		Blueprints.material_list(blueprints.plans[blueprint_picker.get_item_text(index)])

func _save_blueprint() -> void:
	var title := blueprint_name.text.strip_edges()
	if title.is_empty():
		blueprint_status.text = "Name your layout first."
	elif Blueprints.capture(fire).is_empty():
		blueprint_status.text = "Lay out intact, cold fuel before saving a blueprint."
	elif blueprints.plans.has(title):
		blueprint_overwrite.dialog_text = "Replace “%s” with the current layout?" % title
		blueprint_overwrite.popup_centered()
	else:
		_write_blueprint()

func _write_blueprint() -> void:
	var title := blueprint_name.text.strip_edges()
	var result := blueprints.save(title, Blueprints.capture(fire))
	if result != OK:
		blueprint_status.text = "The layout could not be saved. " + error_string(result)
		return
	_refresh_blueprints(title)
	blueprint_status.text = "Saved “%s”." % title

func _rebuild_blueprint() -> void:
	if blueprint_picker.selected < 0:
		return
	if chapter != null and not chapter.outcome.is_empty():
		blueprint_status.text = "Continue the story or load an earlier hearth before building."
		return
	var title := blueprint_picker.get_item_text(blueprint_picker.selected)
	var result := Blueprints.rebuild(fire, blueprints.plans[title])
	if not result.is_empty():
		blueprint_status.text = result
		return
	blueprint_panel.hide()
	_refresh_fuel_bar()
	hint.text = "Rebuilt “%s”. Carry a live ember to the tinder when you are ready." % title

func _toggle_crafting() -> void:
	if crafting.panel.visible:
		_close_crafting()
	else:
		_freeze_story_ui()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crafting.panel.show()
		crafting.refresh(fire, true)

func _close_crafting() -> void:
	if crafting.panel.visible:
		crafting.panel.hide()
		view.mouse_filter = Control.MOUSE_FILTER_STOP

func _can_start_crafting() -> bool:
	return jump_steps == 0 and (chapter == null or chapter.outcome.is_empty())

func _start_crafting() -> void:
	if not _can_start_crafting() or not fire.tinder_job.is_empty():
		return
	var first := crafting.selected_input(0)
	var second := crafting.selected_input(1)
	if first < 0 or second < 0 or (first < 100000 and first == second):
		return
	var practice_count := int(first >= 100000) + int(second >= 100000)
	if fire.wood.size() + practice_count > Fire.MAX_WOOD:
		craft_notice = "Clear a little space before setting out practice tinder."
		return
	var inputs: Array[Fire.Piece] = []
	for index in range(2):
		var id := first if index == 0 else second
		if id >= 100000 and fire.shelter == null:
			inputs.append(fire.add_fuel(id - 100000, Vector2(-0.67, -0.16 + index * 0.17)))
		else:
			inputs.append(fire.fuel_by_id(id))
	if fire.queue_tinder_bundle(inputs[0], inputs[1]):
		accumulator = 0.0
		craft_notice = ""
		_refresh_fuel_bar()
	else:
		craft_notice = "Choose two separate parcels of cool tinder."
	crafting.refresh(fire, true)

func _wait_for_crafting() -> void:
	if fire.tinder_job.is_empty() or not _can_start_crafting():
		return
	if not paused:
		_pause()
	_advance(float(fire.tinder_job.remaining))

func _cancel_crafting() -> void:
	fire.cancel_tinder_work()
	jump_steps = 0
	accumulator = 0.0
	craft_notice = "You set the tinder aside."
	_refresh_fuel_bar()

func _ready_bundle() -> Fire.Piece:
	for piece in fire.all_fuel():
		if piece.kind == Fire.TINDER_BUNDLE and piece.temperature < 75.0 and piece.charred_wood < 0.000001:
			return piece
	return null

func _take_crafted_bundle() -> void:
	var bundle := _ready_bundle()
	if bundle != null:
		_close_crafting()
		_choose_tool_for_bundle(bundle)
		hint.text = "Set the bundle at the base of the build, then carry in the ember [C]."

func _on_tinder_finished(bundle: Fire.Piece) -> void:
	if bundle == null:
		craft_notice = "The tinder changed before you could finish it. Choose two cool parcels."
		return
	var learned := not bundle_known if chapter == null else not chapter.tinder_bundle_known
	bundle_known = true
	if chapter != null:
		chapter.tinder_bundle_known = true
		if chapter.family != null:
			chapter.family.workshop.techniques.practice(chapter.family.workshop.Techniques.TINDER, "Eren")
	if learned:
		mentor.story_line("Work the tinder loose and cup it in your hands. Put the red in the hollow and give it a soft breath.", "tinder_bundle")
	craft_notice = ("Learned Tinder Bundle. " if learned else "") + \
		("The bundle is damp. Warm it gently before using it." if bundle.water / bundle.original > 0.24 else "Your bundle is ready to place.")

func _choose_tool_for_bundle(bundle: Fire.Piece) -> void:
	_select_fuel(-1)
	fuel_group = 0
	last_fuel = Fire.TINDER_BUNDLE
	last_wet = false
	view.select_material(Fire.TINDER_BUNDLE, bundle)
	_refresh_fuel_bar()

func _journal() -> void:
	var reading := _overlay(Rect2(28, -336, 300, 222), LOWER_LEFT)
	journal = reading
	heat_hand = HeatHand.new()
	heat_hand.position = Vector2(0, 5)
	heat_hand.size = Vector2(82, 91)
	reading.add_child(heat_hand)
	heat_title = _label(reading, "H E A T   A T   H A N D", Rect2(91, 22, 209, 19), 12, GOLD)
	warmth = _label(reading, "", Rect2(91, 44, 209, 40), 16, TEXT, serif)
	warmth.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	warmth.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_title = _label(reading, "L A S T   I N S P E C T I O N", Rect2(0, 100, 282, 19), 11, MUTED)
	note = _label(reading, "", Rect2(0, 120, 282, 84), 15, TEXT, serif)
	note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _controls() -> void:
	_journal()
	_ambient_weather()
	var tools := _overlay(Rect2(-274, 76, 246, 304), RIGHT)
	tending_controls = tools
	_label(tools, "T E N D", Rect2(0, 0, 246, 20), 12, GOLD)
	_button(tools, "Rake coals", Rect2(0, 25, 118, 30), _rake, "Gather the coals and stir their ash back to the rim.")
	_button(tools, "Bank with ash", Rect2(124, 25, 122, 30), _bank, "Spread a layer of loose ash over the coals. Each press adds more.")
	_button(tools, "Expose coals", Rect2(0, 61, 118, 30), _uncover, "Brush the ash away to let air reach the bed.")
	_button(tools, "Inspect  [I]", Rect2(124, 61, 122, 30), _inspect, "Record a reading at the hearth.")

	_label(tools, "W E A T H E R   &   T I M E", Rect2(0, 110, 148, 21), 11, MUTED)
	time_label = _label(tools, "", Rect2(124, 109, 122, 21), 14, TEXT)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weather_picker = _picker(tools, Rect2(0, 136, 246, 30), _weather_changed)
	for weather in Fire.WEATHER:
		weather_picker.add_item(weather.label)
	chapter_weather = _label(tools, "", Rect2(0, 130, 246, 39), 13, TEXT)
	chapter_weather.hide()
	pause_button = _button(tools, "Pause  [Space]", Rect2(0, 172, 134, 30), _pause)
	rate = _picker(tools, Rect2(140, 172, 106, 30), _speed_changed)
	for value in SPEEDS:
		rate.add_item("%d× speed" % value)
	_button(tools, "+30 seconds", Rect2(0, 208, 118, 30), func() -> void: _advance(30.0))
	_button(tools, "+5 minutes", Rect2(124, 208, 122, 30), func() -> void: _advance(300.0))

	_label(tools, "E X P E R I M E N T", Rect2(0, 253, 246, 19), 11, MUTED)
	trials = _picker(tools, Rect2(0, 275, 159, 29), _load_trial)
	trials.add_item("Test hearths…")
	trials.set_item_disabled(0, true)
	for title in Fire.SCENARIOS:
		trials.add_item(title)
	trials.add_item("Chapter II · After the storm")
	trials.add_item("Chapter III · " + Chapter.Family.TITLE)
	trials.select(0)
	trials.tooltip_text = "Start a fresh experiment and replace the current hearth."
	var readings := _button(tools, "Readings", Rect2(166, 275, 80, 29), _toggle_debug, "Developer readings [F3]")
	readings.add_theme_color_override("font_color", MUTED)

func _ambient_weather() -> void:
	ambient_overlay = _overlay(Rect2(28, -466, 108, 118), LOWER_LEFT)
	var title := _label(ambient_overlay, "A I R   H E R E", Rect2(0, 0, 108, 17), 11, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ambient_figure = AmbientFigure.new()
	ambient_figure.position = Vector2(0, 17)
	ambient_figure.size = Vector2(108, 70)
	ambient_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ambient_overlay.add_child(ambient_figure)
	ambient_words = _label(ambient_overlay, "", Rect2(-12, 87, 132, 31), 12, TEXT)
	ambient_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ambient_words.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _fuel_bar() -> void:
	var bar := _overlay(Rect2(-412, -135, 824, 114), LOWER_CENTER)
	fuel_bar = bar
	hint = _label(bar, "", Rect2(8, 0, 808, 25), 14, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_default_hint()
	for kind in range(Fire.SPECIES.size()):
		fuel_icons.append(FuelIcons.make(kind))
		fuel_buttons.append(null)
	for group in range(FUEL_GROUPS.size()):
		var tab := _button(bar, FUEL_GROUPS[group][0], Rect2(12 + group * 112, 33, 108, 28),
			func() -> void: _switch_fuel_group(group))
		tab.toggle_mode = true
		tab.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var active := _style(Color(Color("#4b3022"), 0.50), GOLD)
		active.set_border_width_all(0)
		active.border_width_bottom = 2
		tab.add_theme_stylebox_override("pressed", active)
		tab.add_theme_stylebox_override("hover_pressed", active)
		group_buttons.append(tab)
		var kinds: Array = FUEL_GROUPS[group][1]
		var stride := 166 if kinds.size() > 3 else 219
		for slot in range(kinds.size()):
			var kind: int = kinds[slot]
			var button := _fuel_button(bar, kind, Rect2(12 + slot * stride, 68, stride - 7, 46))
			button.toggle_mode = true
			fuel_buttons[kind] = button
	for slot in range(WET_KINDS.size()):
		var kind: int = WET_KINDS[slot]
		var button := _fuel_button(bar, kind, Rect2(12 + slot * 134, 68, 129, 46), 1)
		button.toggle_mode = true
		wet_buttons[kind] = button
	_button(bar, "All fuel  [M]", Rect2(687, 33, 125, 28), _toggle_palette)
	recall_button = _button(bar, "Last fuel  [Tab]", Rect2(687, 68, 125, 46), _recall_fuel,
		"Recall the last material or return to the previous tool.")
	_refresh_fuel_bar()

func _fuel_button(parent: Control, kind: int, bounds: Rect2, wet_mode := -1) -> Button:
	var button := _button(parent, "%s  [%s]" % [Fire.SPECIES[kind].label, FUEL_KEYS[kind]], bounds,
		func() -> void: _select_fuel(kind, wet_mode), "%s [%s]\n%s" % [
			Fire.SPECIES[kind].label, FUEL_KEYS[kind], FUEL_DESCRIPTIONS[kind]])
	button.icon = fuel_icons[kind]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 32 if bounds.size.x < 180 else 47)
	if bounds.size.x < 180:
		button.add_theme_font_size_override("font_size", 13)
	return button

func _switch_fuel_group(group: int) -> void:
	fuel_group = group
	var kinds: Array = WET_KINDS if group == 5 and _after_storm() else FUEL_GROUPS[group][1]
	if view.placing >= 0 and (view.placing not in kinds or (group == 5 and _after_storm() and not last_wet)):
		_return_from_fuel()
	_refresh_fuel_bar()

func _refresh_fuel_bar() -> void:
	var stock := fire.fuel_stock
	var after_storm := _after_storm()
	for group in range(FUEL_GROUPS.size()):
		group_buttons[group].set_pressed_no_signal(group == fuel_group)
		if group == 5:
			group_buttons[group].text = "Wet wood" if after_storm else FUEL_GROUPS[group][0]
		for kind in FUEL_GROUPS[group][1]:
			var button := fuel_buttons[kind]
			button.visible = group == fuel_group and not (group == 5 and after_storm)
			button.set_pressed_no_signal(view.placing == kind)
			_fuel_supply(button, kind, stock)
	for kind: int in wet_buttons:
		var button: Button = wet_buttons[kind]
		button.visible = after_storm and fuel_group == 5
		button.set_pressed_no_signal(view.placing == kind and last_wet)
		var tray_button: Button = wet_tray_buttons.get(kind)
		if tray_button != null:
			tray_button.visible = after_storm
		if after_storm:
			var piece := fire.stock_piece(kind, true)
			_wet_supply(button, kind, piece)
			if tray_button != null:
				_wet_supply(tray_button, kind, piece)
	for button in fuel_tray_buttons:
		var kind := int(button.get_meta("kind"))
		button.visible = not (after_storm and kind == 3)
		_fuel_supply(button, kind, stock)
	recall_button.text = "Tool  [Tab]" if view.placing >= 0 else "Last fuel  [Tab]"

func _fuel_palette() -> void:
	palette = _panel(Rect2(-396, -243, 792, 486), CENTER)
	_label(palette, "F U E L   T R A Y", Rect2(19, 12, 500, 30), 16, GOLD)
	_button(palette, "Close", Rect2(684, 9, 90, 27), _toggle_palette)
	for group in range(FUEL_GROUPS.size()):
		var x := 19 + (group % 3) * 255
		var y := 52 + floori(group / 3.0) * 198
		_label(palette, FUEL_GROUPS[group][0], Rect2(x, y, 230, 27), 15, GOLD)
		var kinds: Array = FUEL_GROUPS[group][1]
		for slot in range(kinds.size()):
			var button := _fuel_button(palette, kinds[slot], Rect2(x, y + 32 + slot * 47, 238, 42), 0)
			button.set_meta("kind", kinds[slot])
			fuel_tray_buttons.append(button)
	for slot in range(WET_KINDS.size()):
		var kind: int = WET_KINDS[slot]
		var button := _fuel_button(palette, kind, Rect2(529, 282 + slot * 39, 238, 36), 1)
		button.hide()
		wet_tray_buttons[kind] = button
	palette.hide()

func _toggle_palette() -> void:
	family_page.close()
	_close_torch()
	palette.visible = not palette.visible
	if palette.visible:
		_close_ask()
		history_panel.hide()
		debug.hide()
		settings_panel.hide()
	_update_speaker()

func _toggle_snap() -> void:
	view.toggle_snap()
	snap_button.text = "Snap on  [N]" if view.snapping else "Snap off  [N]"

func _reset_camera() -> void:
	view.workbench.reset_camera()

func _mentor_ui() -> void:
	var caption_tint := Color(Color("#251a13"), 0.88)
	speech = _panel(Rect2(-302, -429, 274, 123), LOWER_RIGHT, caption_tint)
	speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech.add_child(tail)
	speech.resized.connect(tail.queue_redraw)
	tail.draw.connect(func() -> void:
		tail.draw_colored_polygon(PackedVector2Array([Vector2(speech.size.x - 77, 122), Vector2(speech.size.x - 58, 122),
			Vector2(speech.size.x - 68, 134)]), caption_tint))
	_label(speech, "F I R E   S P E A K E R", Rect2(13, 6, 235, 22), 12, GOLD)
	speech_text = _label(speech, "", Rect2(13, 32, 248, 87), 15, TEXT, serif)
	speech_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var speaker_link := _overlay(Rect2(-294, -167, 266, 29), LOWER_RIGHT)
	_button(speaker_link, "Ask Speaker  [G]", Rect2(0, 0, 140, 29), _toggle_ask)
	_button(speaker_link, "Speaker  [H]", Rect2(148, 0, 118, 29), _toggle_history,
		"Read the Fire Speaker’s words or retry the current practice.")
	history_panel = _panel(Rect2(-396, -243, 792, 486), CENTER)
	_label(history_panel, "T H E   F I R E   S P E A K E R ’ S   W O R D S", Rect2(16, 10, 625, 29), 15, GOLD)
	retry_button = _button(history_panel, "Retry this practice", Rect2(509, 9, 159, 27), _retry_practice,
		"Set up a fresh exercise while keeping your current place and the Speaker’s words.")
	tale_button = _button(history_panel, "Read the tale", Rect2(509, 9, 159, 27), _toggle_tale)
	tale_button.hide()
	_button(history_panel, "Close", Rect2(684, 9, 90, 27), _toggle_history)
	history_text = RichTextLabel.new()
	history_text.position = Vector2(17, 50)
	history_text.size = Vector2(749, 414)
	history_text.scroll_following = true
	history_text.add_theme_color_override("default_color", TEXT)
	history_text.add_theme_font_override("normal_font", serif)
	history_text.add_theme_font_size_override("normal_font_size", 19)
	history_panel.add_child(history_text)
	history_panel.hide()
	_consult_ui()

func _consult_ui() -> void:
	ask_panel = _panel(Rect2(-342, -137, 314, 126), LOWER_RIGHT)
	_label(ask_panel, "Your question", Rect2(14, 9, 213, 27), 18, GOLD, serif)
	_button(ask_panel, "Close", Rect2(234, 10, 66, 26), _toggle_ask)
	ask_picker = _picker(ask_panel, Rect2(14, 40, 286, 30),
		func(index: int) -> void:
			if index > 0:
				var topic: String = ask_topics[index - 1]
				var story_questions := chapter.questions() if chapter != null else {}
				if story_questions.has(topic):
					_submit_question(story_questions[topic])
				else:
					_submit_question(Advice.PROMPTS[topic], topic))
	ask_picker.tooltip_text = "Choose a question about the current fire, or type your own below."
	ask_entry = LineEdit.new()
	ask_entry.position = Vector2(14, 82)
	ask_entry.size = Vector2(218, 30)
	ask_entry.placeholder_text = "Or ask in your own words"
	ask_entry.max_length = 120
	ask_entry.add_theme_stylebox_override("normal", _style(Color("#181310"), LINE))
	ask_entry.add_theme_stylebox_override("focus", _style(Color("#201811"), GOLD))
	ask_entry.add_theme_color_override("font_color", TEXT)
	ask_entry.text_submitted.connect(_submit_question)
	ask_panel.add_child(ask_entry)
	_button(ask_panel, "Ask", Rect2(239, 82, 61, 30), func() -> void: _submit_question(ask_entry.text))
	ask_panel.hide()

func _toggle_ask() -> void:
	family_page.close()
	_close_torch()
	if ask_panel.visible:
		_close_ask()
	else:
		ask_hand = _hand_point(view.workbench.touch_at(view.pointer).contact)
		ask_entry.clear()
		history_panel.hide()
		debug.hide()
		palette.hide()
		settings_panel.hide()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ask_panel.show()
		_layout_consultation()
		_refresh_questions()
	_update_speaker()

func _close_ask() -> void:
	if ask_panel.visible:
		ask_entry.release_focus()
		ask_panel.hide()
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		_layout_consultation()

func _refresh_questions() -> void:
	ask_clock = 0.0
	if ask_picker.get_popup().visible:
		return
	ask_topics = Advice.suggestions(fire, ask_hand, view.selected, mentor.lesson if mentor.training else -1)
	var story_questions := chapter.questions() if chapter != null else {}
	if chapter != null:
		for topic in story_questions:
			ask_topics.append(topic)
	ask_picker.clear()
	ask_picker.add_item("Suggested questions…")
	ask_picker.set_item_disabled(0, true)
	for topic in ask_topics:
		ask_picker.add_item(story_questions[topic] if story_questions.has(topic) else Advice.PROMPTS[topic])
	ask_picker.select(0)

func _submit_question(words: String, topic := "") -> void:
	if not ask_panel.visible or words.strip_edges().is_empty():
		return
	mentor.ask(fire, words, ask_hand, view.selected, view.workbench.yaw, topic)
	_close_ask()
	_update_speaker()

func _update_speaker() -> void:
	speech.visible = mentor.conversation.living_available and not mentor.text.is_empty() and not _hearth_overlay_open() and \
		(family_page == null or family_page.station.is_empty())
	if speech_text.text != mentor.text:
		speech_text.text = mentor.text
		# Make long composed answers wider, keeping both the seat and bubble
		# bottom fixed. This leaves weather controls above and questions below.
		var width := 274.0
		speech_text.size = Vector2(width - 26.0, 87.0)
		while speech_text.get_minimum_size().y > 87.0 and width < 434.0:
			width += 40.0
			speech_text.size = Vector2(width - 26.0, 87.0)
		speech_text.size.y = 87.0
		speech.offset_left = -28.0 - width
		speech.offset_right = -28.0
	view.speaker_talking = speech.visible
	if _living_family():
		practice_line.text = "Chapter III · " + Chapter.Family.TITLE
	elif _after_storm():
		practice_line.text = "Chapter II · %s  /  %s" % [Chapter.AfterStorm.TITLE, chapter.weather.day_words(fire.time)]
	elif chapter != null:
		practice_line.text = "Red Hollow · " + chapter.weather.day_words(fire.time)
	elif not mentor.training:
		practice_line.text = "Free experiment · F2 to begin practice"
	elif mentor.lesson < 4:
		practice_line.text = "Practice %d of 5 · %s" % [mentor.lesson + 1, Mentor.TITLES[mentor.lesson]]
	elif mentor.lesson == 4:
		practice_line.text = "Practice 5 of 5 · Build from one ember" if mentor.ember_training else "Ready for One Ember · F4 to begin"
	else:
		practice_line.text = "Apprenticeship complete · Tend freely"
	practice_line.tooltip_text = Chapter.AfterStorm.STAGES[chapter.sequel.stage] if _after_storm() and not _living_family() else (
		Mentor.TASKS[mentor.lesson] if mentor.training and mentor.lesson < Mentor.TASKS.size() else "")
	if history_panel.visible and history_version != mentor.history_version:
		_write_history()
	retry_button.visible = mentor.training and (mentor.lesson < 4 or mentor.ember_training and mentor.lesson == 4)
	tale_button.visible = _after_storm()

func _write_history() -> void:
	history_version = mentor.history_version
	history_text.scroll_following = not showing_tale
	tale_button.text = "Dialogue history" if showing_tale else "Read the tale"
	if showing_tale:
		history_text.text = Chapter.AfterStorm.TITLE + "\n\n" + "\n\n".join(Chapter.AfterStorm.TALE)
		history_text.scroll_to_line(0)
		return
	var lines := PackedStringArray()
	if mentor.training and mentor.lesson < Mentor.TITLES.size():
		lines.append(Mentor.TITLES[mentor.lesson] + "\n" + Mentor.TASKS[mentor.lesson])
	lines.append_array(mentor.history)
	history_text.text = "\n\n".join(lines) if not lines.is_empty() else "The Fire Speaker is watching quietly."

func _toggle_history() -> void:
	family_page.close()
	_close_torch()
	history_panel.visible = not history_panel.visible
	if history_panel.visible:
		showing_tale = false
		_close_ask()
		debug.hide()
		palette.hide()
		settings_panel.hide()
		_write_history()
	_update_speaker()

func _toggle_tale() -> void:
	showing_tale = not showing_tale
	_write_history()

func _debug_view() -> void:
	debug = _panel(Rect2(-396, -243, 792, 486), CENTER)
	_label(debug, "D E V E L O P E R   R E A D I N G S", Rect2(14, 7, 530, 25), 13, GOLD)
	_button(debug, "3D heat overlay", Rect2(528, 9, 147, 27), _toggle_thermal_overlay,
		"Show local surface temperatures and incoming radiation in the workbench. Shift+F3 toggles it.")
	_button(debug, "Close", Rect2(684, 9, 90, 27), _toggle_debug)
	report = TextEdit.new()
	report.position = Vector2(12, 45)
	report.size = Vector2(766, 425)
	report.editable = false
	report.focus_mode = Control.FOCUS_NONE
	report.add_theme_font_override("font", mono)
	report.add_theme_font_size_override("font_size", 14)
	report.add_theme_color_override("font_readonly_color", TEXT)
	report.add_theme_stylebox_override("read_only", _style(Color("#161310"), LINE))
	debug.add_child(report)
	debug.hide()

func _settings_view() -> void:
	preferences.load(settings_path)
	smooth_rotation = preferences.get_value("controls", "smooth_rotation", false) == true
	invert_wind = preferences.get_value("display", "invert_wind", false) == true
	settings_panel = _panel(Rect2(-426, 66, 398, 338), RIGHT)
	_label(settings_panel, "S E T T I N G S", Rect2(15, 9, 250, 25), 15, GOLD)
	_button(settings_panel, "Close", Rect2(303, 9, 80, 26), _toggle_settings)
	_label(settings_panel, "Q / E rotation", Rect2(15, 47, 151, 33), 17, TEXT, serif)
	var picker := _picker(settings_panel, Rect2(168, 47, 215, 33), _rotation_changed)
	picker.add_item("Fixed increments")
	picker.add_item("Smooth while held")
	picker.select(1 if smooth_rotation else 0)
	rotation_hint = _label(settings_panel, "", Rect2(15, 84, 368, 42), 14, MUTED)
	rotation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	invert_wind_button = _button(settings_panel, "Invert wind indicator", Rect2(15, 130, 368, 34), _wind_display_changed,
		"Point the wind marks toward the source. Wind and rain in the world keep their direction.")
	invert_wind_button.toggle_mode = true
	invert_wind_button.button_pressed = invert_wind
	_label(settings_panel, "S O U N D", Rect2(15, 185, 180, 20), 12, GOLD)
	sound.fire_volume = clampf(float(preferences.get_value("sound", "fire", sound.fire_volume)), 0.0, 1.0)
	sound.weather_volume = clampf(float(preferences.get_value("sound", "weather", sound.weather_volume)), 0.0, 1.0)
	_volume(settings_panel, "Fire", Rect2(15, 214, 368, 25), sound.fire_volume,
		func(value: float) -> void:
			sound.fire_volume = value
			preferences.set_value("sound", "fire", value)
			preferences.save(settings_path))
	_volume(settings_panel, "Weather", Rect2(15, 250, 368, 25), sound.weather_volume,
		func(value: float) -> void:
			sound.weather_volume = value
			preferences.set_value("sound", "weather", value)
			preferences.save(settings_path))
	save_family_button = _button(settings_panel, "Save game  [F5]", Rect2(15, 289, 180, 31), _save_family)
	load_family_button = _button(settings_panel, "Load game  [F11]", Rect2(204, 289, 179, 31), _load_family)
	_update_rotation_hint()
	settings_panel.hide()

func _toggle_settings() -> void:
	family_page.close()
	_close_torch()
	settings_panel.visible = not settings_panel.visible
	var from_title := story_menu != null and story_menu.mode == "title"
	if from_title:
		story_menu.settings_shade.visible = settings_panel.visible
	save_family_button.visible = not from_title
	load_family_button.visible = not from_title
	held_turns.clear()
	if settings_panel.visible:
		save_family_button.disabled = chapter == null
		load_family_button.disabled = not launch_at_title and not FileAccess.file_exists(chapter_save_path)
		_close_ask()
		history_panel.hide()
		debug.hide()
		palette.hide()
	_update_speaker()

func _rotation_changed(index: int) -> void:
	smooth_rotation = index == 1
	held_turns.clear()
	preferences.set_value("controls", "smooth_rotation", smooth_rotation)
	_update_rotation_hint()
	if preferences.save(settings_path) != OK:
		rotation_hint.text += " Applied for this session. Could not save settings."

func _update_rotation_hint() -> void:
	rotation_hint.text = "Hold to turn continuously. Alt slows the turn." if smooth_rotation else (
		"Each press turns 15°. Hold Alt for 5° turns.")

func _wind_display_changed() -> void:
	invert_wind = invert_wind_button.button_pressed
	preferences.set_value("display", "invert_wind", invert_wind)
	if preferences.save(settings_path) != OK:
		invert_wind_button.tooltip_text = "Applied for this session. Could not save settings."
	_update_ambient_weather()

func _hearth_overlay_open() -> bool:
	if quest_panel != null and quest_panel.visible:
		return true
	if crafting.panel != null and crafting.panel.visible:
		return true
	if blueprint_panel != null and blueprint_panel.visible:
		return true
	if story_menu != null and story_menu.visible:
		return true
	if family_page != null and family_page.family_panel.visible:
		return true
	return history_panel.visible or debug.visible or palette.visible or settings_panel.visible or ask_panel.visible or (torch_panel != null and torch_panel.visible)

func _process(delta: float) -> void:
	if story_menu != null and story_menu.visible:
		return
	_rotate_held(delta)
	_pan_held(delta)
	view.workbench.set_acceleration(64 if jump_steps > 8 else (speed if not paused else 1))
	if jump_steps > 0:
		jump_steps -= _step_budgeted(jump_steps)
		if jump_steps == 0:
			hint.text = "Time passes. Inspect the hearth to see what changed."
	elif not paused or (crafting.panel.visible and not fire.tinder_job.is_empty() and _can_start_crafting()):
		var step_speed := 1 if crafting.panel.visible else speed
		accumulator = minf(accumulator + delta * step_speed, step_speed * 0.25 + Fire.STEP)
		accumulator -= _step_budgeted(int(accumulator / Fire.STEP)) * Fire.STEP
	_update_chapter()
	family_page.update()
	if crafting.panel.visible:
		crafting.refresh(fire)
	_update_time()
	mentor.tick(delta)
	_update_speaker()
	sound.listener = view.probe
	heat_clock += delta
	if heat_clock >= 0.075:
		_update_hand()
		_update_ambient_weather()
	if ask_panel.visible:
		ask_clock += delta
		if ask_clock >= 0.6:
			_refresh_questions()
	if debug.visible:
		debug_clock += delta
		if debug_clock > 0.25:
			_update_debug()

func _step_budgeted(ticks: int) -> int:
	# Fast-forward should keep the renderer and audio buffer serviced.
	var deadline := Time.get_ticks_usec() + 8500
	for i in range(ticks):
		if chapter == null:
			fire.step()
		else:
			chapter.step()
			if not chapter.outcome.is_empty():
				return i + 1
		mentor.observe(fire)
		if Time.get_ticks_usec() >= deadline:
			return i + 1
	return ticks

func _input(event: InputEvent) -> void:
	if ask_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_ask()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.pressed:
		held_turns.erase(event.keycode)
		held_camera_keys.erase(event.keycode)
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		held_turns.clear()
	if jump_steps > 0 and not crafting.panel.visible and (event is InputEventMouseButton or event is InputEventKey):
		if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode in [KEY_ESCAPE, KEY_SPACE]:
			jump_steps = 0
			accumulator = 0.0
			if not paused:
				_pause()
			hint.text = "Time jump stopped. The hearth is paused."
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held_turns.clear()
		held_camera_keys.clear()

func _pan_held(delta: float) -> void:
	if held_camera_keys.is_empty():
		return
	if jump_steps > 0 or _hearth_overlay_open():
		held_camera_keys.clear()
		return
	var direction := Vector2(int(held_camera_keys.has(KEY_D)) - int(held_camera_keys.has(KEY_A)),
		int(held_camera_keys.has(KEY_S)) - int(held_camera_keys.has(KEY_W)))
	if direction != Vector2.ZERO:
		view.workbench.pan_direction(direction.normalized(), delta)

func _rotate_held(delta: float) -> void:
	if held_turns.is_empty():
		return
	if jump_steps > 0 or _hearth_overlay_open():
		held_turns.clear()
		return
	if held_turns.size() == 1:
		var key: int = held_turns.keys()[0]
		if not view.adjust_build(1 if key == KEY_E else -1, false, false, held_turns[key],
				SMOOTH_TURN_RATE * delta, false):
			held_turns.clear()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if quest_panel.visible:
		if event.keycode in [KEY_ESCAPE, KEY_O]:
			quest_panel.hide()
		get_viewport().set_input_as_handled()
		return
	if blueprint_panel.visible:
		if event.keycode in [KEY_ESCAPE, KEY_F12]:
			_toggle_blueprints()
		get_viewport().set_input_as_handled()
		return
	if crafting.panel.visible:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			_close_crafting()
		get_viewport().set_input_as_handled()
		return
	if story_menu != null and story_menu.visible:
		if event.keycode == KEY_F5 and story_menu.mode == "results":
			_save_family()
		elif event.keycode == KEY_F11 and story_menu.mode == "results":
			_load_family()
		elif event.keycode == KEY_ESCAPE:
			if settings_panel.visible:
				_toggle_settings()
			else:
				story_menu.back()
		get_viewport().set_input_as_handled()
		return
	if ask_panel.visible:
		if event.keycode == KEY_G:
			_toggle_ask()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_W, KEY_A, KEY_S, KEY_D:
			if _hearth_overlay_open() or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
				return
			held_camera_keys[event.keycode] = true
		KEY_SPACE: _pause()
		KEY_I: _inspect()
		KEY_V:
			if not _hearth_overlay_open():
				view.context_material()
		KEY_B:
			if _hearth_overlay_open():
				return
			if view.tool == View.Tool.BREATH and view.placing < 0:
				view.repeat_breath()
			else:
				_choose_tool(View.Tool.BREATH)
		KEY_R: _choose_tool(View.Tool.RAKE)
		KEY_T: _choose_tool(View.Tool.ROLL)
		KEY_C: _choose_tool(View.Tool.COAL)
		KEY_Y:
			if chapter != null:
				_choose_tool(View.Tool.ASH)
		KEY_X: _choose_tool(View.Tool.FEED)
		KEY_UP, KEY_DOWN:
			if view.tool != View.Tool.FEED or _hearth_overlay_open():
				return
			view.slide_feed(1 if event.keycode == KEY_UP else -1, event.alt_pressed)
		KEY_H: _toggle_history()
		KEY_G: _toggle_ask()
		KEY_F1: _replay_story()
		KEY_F2: _restart_practice()
		KEY_F3:
			if event.shift_pressed:
				_toggle_thermal_overlay()
			else:
				_toggle_debug()
		KEY_F4: _start_ember()
		KEY_F5: _save_family()
		KEY_F6: _toggle_torch()
		KEY_F7: _start_after_storm_trial()
		KEY_F8: _start_family_trial()
		KEY_F9: family_page.toggle_family()
		KEY_F10: family_page.toggle_family(FamilyPage.MAP_PAGE)
		KEY_F11: _load_family()
		KEY_F12: _toggle_blueprints()
		KEY_P: _toggle_crafting()
		KEY_O: _toggle_quests()
		KEY_L: _focus_woodpile()
		KEY_M: _toggle_palette()
		KEY_N: _toggle_snap()
		KEY_F:
			if not _hearth_overlay_open():
				view.focus_camera()
		KEY_HOME: _reset_camera()
		KEY_TAB:
			if not _hearth_overlay_open():
				_recall_fuel()
		KEY_Q, KEY_E:
			if _hearth_overlay_open():
				return
			var continuous: bool = smooth_rotation and not event.shift_pressed and not event.ctrl_pressed
			if not view.adjust_build(1 if event.keycode == KEY_E else -1, event.shift_pressed,
					event.ctrl_pressed, event.alt_pressed, SMOOTH_TAP if continuous else PI / 12.0):
				return
			if continuous:
				held_turns[event.keycode] = event.alt_pressed
		KEY_ESCAPE:
			if view.cancel_material():
				pass
			elif family_page.family_panel.visible or not family_page.station.is_empty():
				family_page.close()
			elif torch_panel.visible:
				_toggle_torch()
			elif settings_panel.visible:
				_toggle_settings()
			elif debug.visible:
				_toggle_debug()
			elif history_panel.visible:
				_toggle_history()
			elif palette.visible:
				_toggle_palette()
			elif launch_at_title and view.placing < 0 and view.carried_coal == null and view.tool == View.Tool.WOOD:
				show_title()
			else:
				_cancel()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			_select_fuel(event.keycode - KEY_1)
		KEY_0:
			_select_fuel(9)
		KEY_MINUS:
			_select_fuel(10)
		KEY_U:
			_select_fuel(11)
		KEY_J:
			_select_fuel(12)
		KEY_K:
			_select_fuel(13)
		KEY_COMMA:
			_select_fuel(Fire.LEAVES)
		KEY_PERIOD:
			_select_fuel(Fire.TINDER_BUNDLE)
		_: return
	get_viewport().set_input_as_handled()

func _select_fuel(index: int, wet_mode := -1) -> void:
	palette.hide()
	if index == Fire.TINDER_BUNDLE:
		var bundle: Fire.Piece
		for piece in fire.all_fuel():
			if piece.kind == Fire.TINDER_BUNDLE and piece.temperature < 85.0:
				bundle = piece
				break
		if bundle != null:
			_choose_tool_for_bundle(bundle)
		else:
			hint.text = "Open Crafting [P] to work two tinder parcels into a bundle."
		return
	var wet := _after_storm() and index in WET_KINDS and (wet_mode == 1 or (wet_mode == -1 and fuel_group == 5))
	var parcel := fire.stock_piece(index, wet) if chapter != null and index >= 0 else null
	if chapter != null and index >= 0 and (parcel == null or not chapter.outcome.is_empty()):
		hint.text = "No matching %s in the pile. Ask your cousin about supplies." % Fire.SPECIES[index].label.to_lower()
		return
	var feed := view.tool == View.Tool.FEED and index >= 0
	if index >= 0:
		if index == view.placing and wet == last_wet:
			_return_from_fuel()
			return
		if view.placing < 0:
			return_tool = view.tool
		last_fuel = index
		last_wet = wet
		if wet:
			fuel_group = 5
		else:
			for group in range(FUEL_GROUPS.size()):
				if index in FUEL_GROUPS[group][1]:
					fuel_group = group
					break
	if not _set_tool(View.Tool.FEED if feed else View.Tool.WOOD):
		return
	view.select_material(index, parcel)
	_refresh_fuel_bar()
	if view.placing < 0:
		_default_hint()
	elif view.tool == View.Tool.FEED:
		hint.text = "Aim the stick’s leading tip   ·   Wheel slides inward   ·   Ctrl adjusts height   ·   Shift tilts   ·   Q/E turns"
	else:
		hint.text = "Set %s   ·   Q/E turns   ·   Shift tilts   ·   Ctrl changes the layer" % (
			_wood_condition(parcel) if _after_storm() else Fire.SPECIES[index].label.to_lower() + " in the ring")

func _recall_fuel() -> void:
	if view.placing >= 0:
		_return_from_fuel()
	else:
		_select_fuel(last_fuel, int(last_wet))

func _return_from_fuel() -> void:
	var tool := return_tool
	_select_fuel(-1)
	if tool != View.Tool.WOOD:
		_choose_tool(tool)

func _material_placed(rest: String, at: Vector2) -> void:
	sound.contact(at, false, false)
	if not _living_family():
		return
	var work := Chapter.Family.Workshop
	var place := work.COOK if rest == work.SPIT else (work.MAKER if rest == work.CUP else rest)
	if work.SURFACES.has(place):
		chapter.family.remember_workplace(place)

func _placed(piece: Fire.Piece) -> void:
	_return_from_fuel()
	sound.contact(piece.at, false, piece.core != null)
	mentor.tend("place", fire)
	_build_status(piece)
	if view.tool == View.Tool.FEED:
		view.selected = piece
		view._begin_adjustment(piece)
		hint.text = "Stick rests in the opening   ·   Wheel feeds or withdraws   ·   Ctrl adjusts height   ·   Q/E turns"

func _build_status(piece: Fire.Piece) -> void:
	if chapter != null and not fire.in_hearth(piece.at):
		var label: String = _wood_condition(piece) if _after_storm() else Fire.SPECIES[piece.kind].label
		hint.text = "%s   ·   Drag to move   ·   Drop over wood to stack" % label
		return
	var on_wood := false
	for support in piece.pose.supports:
		on_wood = on_wood or support > 0
	var rest := "resting against the wood below" if on_wood else "resting on the bed"
	hint.text = "%s %s   ·   Q/E turns   ·   Shift tilts   ·   Ctrl changes the layer" % [Fire.SPECIES[piece.kind].label, rest]

func _default_hint() -> void:
	hint.text = "WASD or middle-drag pans   ·   Right-drag orbits   ·   Wheel zooms   ·   F focuses   ·   Home resets"

func _cancel() -> void:
	if view.cancel_material():
		return
	if view.placing >= 0:
		_return_from_fuel()
	else:
		_select_fuel(-1)

func _choose_tool(tool: int) -> void:
	view.cancel_material()
	if view.tool == tool:
		_cancel()
		return
	_select_fuel(-1)
	if not _set_tool(tool):
		return
	match tool:
		View.Tool.ROLL:
			hint.text = "Click a log or branch to roll it. T or Esc returns to moving wood."
		View.Tool.RAKE:
			hint.text = "Drag to move coals   ·   Shift-drag to split one glowing patch   ·   Esc cancels"
		View.Tool.BREATH:
			hint.text = "Drag to aim   ·   Hold longer for a long breath   ·   Shift for a gust   ·   B or click repeats"
		View.Tool.COAL:
			hint.text = "Drag a live coal into loose tinder. Release over open ground to put it down. Esc returns it safely."
		View.Tool.ASH:
			hint.text = "Drag ash to a dry spot beside the bed, or drop it over a coal to cover it."
		View.Tool.FEED:
			hint.text = "Choose a stick and aim its tip   ·   Wheel feeds   ·   Ctrl adjusts height   ·   Shift tilts   ·   Q/E turns"

func _set_tool(tool: int) -> bool:
	held_turns.clear()
	if not view.set_tool(tool):
		return false
	for key in mode_buttons:
		mode_buttons[key].set_pressed_no_signal(key == tool)
	return true

func _rake() -> void:
	fire.rake()
	mentor.tend("rake", fire)
	sound.contact(Vector2.ZERO, true)
	hint.text = "You draw the coals together and brush their ash aside."

func _bank() -> void:
	if fire.bank():
		mentor.tend("bank", fire)
		hint.text = "You sift loose ash over the coals."
	else:
		hint.text = "Sweep powder from burned fuel to make a loose pile first." if chapter != null and fire.ash < 0.001 else "There is too little loose ash or charcoal to bank."

func _uncover() -> void:
	fire.uncover()
	mentor.tend("expose", fire)
	sound.contact(Vector2.ZERO, true)
	hint.text = "You brush ash away from the bed."

func _inspect() -> void:
	_update_hand()
	_update_ambient_weather()
	var material := view.inspect_material()
	note.text = material if not material.is_empty() else Observe.read(fire, view.probe, view.workbench.yaw, warmth.text)
	if material.is_empty() and _after_storm() and view.selected != null and fire.has_fuel(view.selected):
		note.text = _wood_condition(view.selected) + ". " + note.text
	if chapter != null:
		note.size.y = maxf(89.0, note.get_minimum_size().y)
		note.position.y = minf(19.0, heat_title.position.y - note.size.y - 8.0)
		note_title.position.y = note.position.y - 19.0

func _hand_point(contact := Vector3.INF) -> Vector3:
	if view.drop_pose != null:
		return view.workbench.world(view.drop_pose.point(0.0)) + Vector3.UP * Heat.HEIGHT
	if contact.is_finite():
		return contact + Vector3.UP * 0.035
	return Heat.ground(view.probe)

func _update_hand() -> void:
	heat_clock = 0.0
	var hit := view.workbench.touch_at(view.pointer)
	var radiant := 0.0
	if ask_panel.visible or hit.contact.is_finite() or hit.ground.is_finite() or view.drop_pose != null:
		radiant = Heat.sample(fire, ask_hand if ask_panel.visible else _hand_point(hit.contact))
	var reading: Touch.Reading
	if view.dragging != null and view.drop_pose != null and hit.piece != view.dragging and fire.has_fuel(view.dragging):
		reading = Touch.fuel(view.dragging, view.dragging.cross_section(0.0), 0, radiant)
	elif hit.piece == null:
		reading = Touch.ground(fire, hit.ground, radiant)
	elif hit.piece.kind < 0:
		reading = Touch.coal(hit.piece, fire.ambient(), radiant)
	else:
		reading = Touch.fuel(hit.piece, hit.section, hit.face, radiant)
	heat_hand.show_touch(reading.heat, Heat.level(reading.heat), reading.edge, reading.palm)
	warmth.text = reading.words

func _update_ambient_weather() -> void:
	var camera := view.workbench.camera
	var air := FeltWeather.sample(fire, camera.global_position)
	var relative := FeltWeather.relative_wind(air.wind, camera.global_basis)
	ambient_figure.show_air(relative, air.rain, air.chill, invert_wind)
	var words := "Still air"
	if relative.length() >= 0.035:
		if absf(relative.x) > absf(relative.y):
			words = "From the left" if relative.x > 0.0 else "From the right"
		else:
			words = "From behind" if relative.y < 0.0 else "From ahead"
	var felt := PackedStringArray()
	if air.chill > 0.18:
		felt.append("Cold" if air.chill > 0.54 else "Cool")
	if air.rain > 0.04:
		felt.append("Soaking" if air.rain > 0.56 else "Rain")
	if not felt.is_empty():
		words += "\n" + " · ".join(felt)
	ambient_words.text = words

func _pause() -> void:
	if chapter != null and not chapter.outcome.is_empty() and paused:
		return
	paused = not paused
	pause_button.text = "Resume  [Space]" if paused else "Pause  [Space]"

func _weather_changed(index: int) -> void:
	if chapter != null:
		return
	fire.weather = index
	hint.text = "Weather set to %s." % Fire.WEATHER[index].label.to_lower()

func _speed_changed(index: int) -> void:
	speed = SPEEDS[index]

func _advance(duration: float) -> void:
	if chapter != null and not chapter.outcome.is_empty():
		return
	jump_steps = int(duration / Fire.STEP)
	hint.text = "Time is passing…"

func _load_trial(index: int) -> void:
	if index == Fire.SCENARIOS.size() + 2:
		_start_family_trial()
		return
	if index == Fire.SCENARIOS.size() + 1:
		_start_after_storm_trial()
		return
	var scenario := index - 1
	if scenario == Fire.ONE_EMBER:
		_start_ember()
		return
	_leave_chapter()
	fire.setup(scenario)
	mentor.enter(fire, false)
	_reset_hearth_controls()
	if scenario >= Fire.HEAT_EMBER and not paused:
		_pause()
	_inspect()
	hint.text = "Fresh experiment loaded · %s" % Fire.SCENARIOS[scenario]
	if scenario == Fire.GRAIN_END:
		hint.text = "Watch the near end dry and char   ·   T rolls the log   ·   Shift+F3 shows the grain layers"
	elif scenario == Fire.GRAIN_CABIN:
		hint.text = "Watch the crossings as the lower rails thin   ·   Space runs the fire   ·   F3 reads the load"
	elif scenario == Fire.GRAIN_BREAK:
		hint.text = "Watch the charred middle give way   ·   Space runs the fire   ·   +2 seconds steps through it"
	elif scenario == Fire.NURSE_EMBER:
		hint.text = "A little red remains   ·   B aims a gentle breath   ·   Hold and release, then let it rest"
	elif scenario == Fire.CARRY_EMBER:
		hint.text = "C lifts the live ember   ·   Carry it into the loose fibres on the right   ·   B gives a gentle breath"
	elif scenario == Fire.FEED_FIRE:
		hint.text = "X feeds sticks under the log   ·   Try finger sticks [8]   ·   Wheel slides   ·   Ctrl adjusts height"
	elif scenario == Fire.COLD_CABIN:
		hint.text = "Open Crafting [P] to work a tinder bundle. Place it inside the cabin, then carry the ember into it [C]."

func _start_ember() -> void:
	_leave_chapter()
	fire.setup(Fire.ONE_EMBER)
	mentor.enter(fire, true, 4)
	_reset_hearth_controls()
	_switch_fuel_group(0)
	rate.select(0)
	_speed_changed(0)
	if not paused:
		_pause()
	_inspect()
	hint.text = "One Ember · Paused while you build. Try bark fibres [5] or dry grass [6]."

func _restart_practice() -> void:
	_leave_chapter()
	fire.setup(Fire.OPENING)
	mentor.enter(fire, true)
	_reset_hearth_controls()
	rate.select(0)
	_speed_changed(0)
	if paused:
		_pause()
	_inspect()

func _retry_practice() -> void:
	var lesson := mentor.lesson
	if not mentor.training or lesson >= Mentor.TITLES.size():
		return
	if lesson == 4:
		_start_ember()
		return
	fire.setup([1, 10, 6, 1][lesson])
	mentor.enter(fire, true, lesson)
	_reset_hearth_controls()
	rate.select(0)
	_speed_changed(0)
	if not paused:
		_pause()
	_inspect()
	hint.text = "Fresh practice hearth · %s. Space when ready." % Mentor.TITLES[lesson]

func _reset_hearth_controls() -> void:
	_close_crafting()
	craft_notice = ""
	quest_panel.hide()
	blueprint_panel.hide()
	trials.select(0)
	_select_fuel(-1)
	return_tool = View.Tool.WOOD
	held_camera_keys.clear()
	accumulator = 0.0
	jump_steps = 0
	story_menu.dismiss()
	pause_button.disabled = false
	pause_button.text = "Resume  [Space]" if paused else "Pause  [Space]"
	weather_picker.select(0)
	view.reset_scene()
	_close_ask()
	_close_torch()
	debug.hide()
	history_panel.hide()
	palette.hide()
	settings_panel.hide()
	_update_speaker()

func _chapter_ui() -> void:
	chapter_controls = _overlay(Rect2(28, 291, 263, 175))
	_label(chapter_controls, "R E D   H O L L O W", Rect2(0, 0, 250, 21), 12, GOLD)
	site_picker = _picker(chapter_controls, Rect2(0, 25, 228, 30), _choose_site)
	for title in Chapter.Shelter.SITES:
		site_picker.add_item(title)
	site_picker.add_separator("Focus camera")
	shelter_area_start = site_picker.item_count
	for title in SHELTER_AREAS:
		site_picker.add_item(title)
	site_picker.tooltip_text = "Choose where to build before tending, or center the camera on any area."
	_button(chapter_controls, "Woodpile  [L]", Rect2(0, 62, 105, 30), _focus_woodpile)
	quest_button = _button(chapter_controls, "Quests  [O]", Rect2(112, 62, 136, 30), _toggle_quests)
	family_area_start = site_picker.item_count
	family_button = _button(chapter_controls, "Family Tree  [F9]", Rect2(112, 62, 136, 30),
		func() -> void: family_page.toggle_family())
	family_news_button = _button(chapter_controls, "Shelter news", Rect2(0, 99, 116, 32),
		func() -> void: family_page.toggle_family(1))
	mind_cave_button = _button(chapter_controls, "Mind Cave  [F10]", Rect2(122, 99, 126, 32),
		func() -> void: family_page.toggle_family(FamilyPage.MAP_PAGE))
	heat_request_button = _button(chapter_controls, "Heat request", Rect2(0, 137, 248, 29), _open_heat_request)
	heat_request_button.hide()
	mind_cave_button.hide()
	family_button.hide()
	family_news_button.hide()
	var scout := _overlay(Rect2(24, -51, 133, 30), LOWER_LEFT)
	torch_button = _button(scout, "Torch Bearer  [F6]", Rect2(0, 0, 133, 30), _toggle_torch)
	chapter_note = _label(chapter_controls, "", Rect2(0, 102, 248, 47), 15, TEXT, serif)
	chapter_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	chapter_ash = _label(chapter_controls, "", Rect2(0, 150, 253, 21), 13, MUTED)
	chapter_controls.hide()
	torch_panel = _panel(Rect2(-246, -175, 492, 350), CENTER)
	_label(torch_panel, "Torch Bearer", Rect2(20, 10, 295, 32), 21, GOLD, serif)
	_button(torch_panel, "Close", Rect2(391, 12, 81, 29), _toggle_torch)
	torch_report = _label(torch_panel, "", Rect2(20, 47, 452, 80), 16, TEXT, serif)
	torch_report.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	torch_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	torch_site = _picker(torch_panel, Rect2(20, 134, 452, 32), func(_index: int) -> void: _update_torch())
	for route: Dictionary in Chapter.ROUTES:
		torch_site.add_item(route.place)
	torch_detail = _label(torch_panel, "", Rect2(20, 175, 452, 76), 15, TEXT, serif)
	torch_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	torch_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	torch_priority = _picker(torch_panel, Rect2(20, 266, 244, 32), func(_index: int) -> void: _update_torch())
	for priority in Chapter.PRIORITIES:
		torch_priority.add_item(priority)
	torch_send = _button(torch_panel, "Ask him to go", Rect2(274, 266, 198, 32), _request_trip)
	torch_status = _label(torch_panel, "", Rect2(20, 307, 452, 26), 13, MUTED)
	torch_panel.hide()
	_build_quest_journal()

func _build_quest_journal() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.035, 0.025, 0.02, 0.39)
	hearth_hud.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.hide()
	quest_panel = _panel(Rect2(-320, -222, 640, 444), CENTER)
	quest_panel.visibility_changed.connect(func() -> void: backdrop.visible = quest_panel.visible)
	_label(quest_panel, "QUEST JOURNAL", Rect2(24, 16, 420, 26), 15, GOLD)
	_button(quest_panel, "Close  [O]", Rect2(513, 16, 103, 32), _toggle_quests)
	quest_heading = _label(quest_panel, "", Rect2(24, 51, 592, 42), 30, TEXT, serif)
	quest_words = _label(quest_panel, "", Rect2(24, 104, 592, 77), 17, TEXT, serif)
	quest_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(5):
		quest_rows.append(_label(quest_panel, "", Rect2(24, 189 + index * 31, 592, 30), 17, TEXT))
	quest_footer = _label(quest_panel, "", Rect2(24, 352, 592, 37), 15, MUTED)
	for area in [1, 3]:
		quest_locations.append(_button(quest_panel, SHELTER_AREAS[area],
			Rect2(24 + quest_locations.size() * 198, 395, 186, 30), func() -> void:
				quest_panel.hide()
				_choose_site(shelter_area_start + area)))
	quest_panel.hide()

func _toggle_quests() -> void:
	if quest_panel.visible:
		quest_panel.hide()
		return
	if chapter == null or _living_family() or not chapter.outcome.is_empty() or _hearth_overlay_open():
		return
	held_turns.clear()
	held_camera_keys.clear()
	quest_panel.show()
	_refresh_quests()

func _refresh_quests() -> void:
	var aftermath := _after_storm()
	quest_heading.text = "Chapter II · Season the stormfall" if aftermath else "Chapter I · Before the rain"
	quest_words.text = ("Pick logs from Wet wood. Space one medium and one large log on the back-left shelf. Dry another pair faster just outside the fire ring. Pull back any log that starts to scorch."
		if aftermath else "Stock dry fuel under cover before the rain arrives. Send your cousin to the fallen pine for medium wood and to the far oak ridge for large splits. Keep a flame or living coals until Day 3 ends.")
	var rows := chapter.quest_rows()
	for index in range(quest_rows.size()):
		var line := quest_rows[index]
		line.visible = index < rows.size()
		if line.visible:
			var entry: Dictionary = rows[index]
			var status := "Done" if entry.done else ("Missed" if entry.ended else "%d / %d" % [entry.count, entry.target])
			line.text = "%s   ·   %s" % [entry.label, status]
			line.add_theme_color_override("font_color", GOLD if entry.done else TEXT)
	for button in quest_locations:
		button.visible = aftermath
	if aftermath:
		quest_footer.text = "Inspect [I] for moisture. Keep living coals while the shelf pair dries."
	elif chapter.storm_reserve.is_empty():
		quest_footer.text = "Rain arrives in %d sec of hearth time." % ceili(maxf(0.0, Chapter.Quests.RESERVE_AT - fire.time))
	else:
		quest_footer.text = "Reserve recorded when the rain arrived."

func can_return_to_story() -> bool:
	return chapter != null

func return_to_hearth() -> void:
	if chapter == null:
		return
	if story_profile >= 0 and story_profile != profiles.active:
		profiles.select(story_profile)
	if not chapter.outcome.is_empty():
		story_menu.show_results(chapter)
	else:
		story_menu.dismiss()

func show_title() -> void:
	if not launch_at_title:
		return
	_freeze_story_ui()
	story_menu.show_title()

func _freeze_story_ui() -> void:
	_close_crafting()
	quest_panel.hide()
	blueprint_panel.hide()
	_close_ask()
	_close_torch()
	family_page.close()
	history_panel.hide()
	palette.hide()
	debug.hide()
	settings_panel.hide()
	held_turns.clear()
	held_camera_keys.clear()
	jump_steps = 0
	accumulator = 0.0
	if not paused:
		_pause()

func _replay_story() -> void:
	if not launch_at_title:
		_start_chapter()
	else:
		start_story_from_menu()

func _retry_ended_chapter() -> void:
	if _after_storm():
		if launch_at_title:
			open_story_slots("load")
			return
		_start_after_storm_trial()
	else:
		_replay_story()

func start_story_from_menu(slot := -1) -> void:
	if slot == -1:
		slot = profiles.first_empty()
		if slot == -1:
			open_story_slots("new")
			return
	_start_chapter()
	story_profile = profiles.active
	story_slot = slot
	var result := _write_story(profiles.slot_path(slot))
	story_menu.show_chapter(1)
	if result != OK:
		story_menu.chapter_words.text = "The story is ready. Its first save could not be written. You can try saving again with F5."

func continue_profile_story() -> void:
	for entry in Profiles.newest_first(profiles.list_slots()):
		if _load_story(profiles.load_path(entry.slot)):
			story_profile = profiles.active
			story_slot = entry.slot
			return
	story_menu.show_title("No readable save was found for this profile.")

func open_story_slots(kind: String) -> void:
	var from_title := story_menu.mode == "title"
	if kind == "save" and (chapter == null or (story_profile >= 0 and story_profile != profiles.active)):
		return
	_freeze_story_ui()
	story_menu.show_slots(kind, from_title)

func save_profile_slot(slot: int) -> void:
	if chapter == null or (story_profile >= 0 and story_profile != profiles.active):
		return
	var result := _write_story(profiles.slot_path(slot))
	if result != OK:
		story_menu.show_slots("save", false, "The save could not be written. " + error_string(result))
		return
	story_profile = profiles.active
	story_slot = slot
	story_menu.dismiss()
	hint.text = "Saved to slot %02d · %s" % [slot + 1, profiles.names[profiles.active]]

func load_profile_slot(slot: int) -> void:
	if _load_story(profiles.load_path(slot)):
		story_profile = profiles.active
		story_slot = slot
	else:
		story_menu.show_slots("load", story_menu.return_to_title, "This slot could not be restored. Choose another save.")

func _start_chapter() -> void:
	story_profile = -1
	story_slot = -1
	_reset_family()
	chapter = Chapter.new(fire)
	mentor.begin_chapter(chapter)
	supply_revision = -1
	stock_revision = -1
	stock_read_at = -INF
	last_wet = false
	torch_site.select(1)
	torch_priority.select(0)
	_story_journal(true)
	chapter_controls.show()
	torch_button.show()
	chapter_weather.show()
	ash_button.show()
	weather_picker.hide()
	site_picker.select(chapter.weather.site)
	_reset_hearth_controls()
	_switch_fuel_group(0)
	rate.select(0)
	_speed_changed(0)
	if not paused:
		_pause()
	_inspect()
	_update_chapter()
	hint.text = "Send your cousin for branches [F6]. Prepare the nest while paused, then let the hearth run [Space]."

func _after_storm() -> bool:
	return chapter != null and chapter.sequel != null

func _living_family() -> bool:
	return chapter != null and chapter.family != null

func _continue_story() -> void:
	if chapter != null and chapter.begin_family():
		if chapter.tinder_bundle_known:
			chapter.family.workshop.techniques.teach(chapter.family.workshop.Techniques.TINDER, "Eren")
		_open_family()
		story_menu.show_chapter(3)
		_checkpoint_story()
	else:
		_continue_after_storm()

func _start_family_trial() -> void:
	_start_chapter()
	chapter.set_up_family_trial()
	_open_family()

func _open_family() -> void:
	pause_button.disabled = false
	pause_button.text = "Resume  [Space]"
	if not paused:
		_pause()
	for name: String in Chapter.Family.Workshop.STATIONS:
		site_picker.add_item(name)
	family_page.attach(chapter.family)
	view.workbench.family_props.show_workshop(chapter.family.workshop, chapter.family)
	family_button.show()
	family_news_button.show()
	mind_cave_button.show()
	family_news_seen = chapter.family.news_revision
	_update_chapter()
	_update_speaker()
	hint.text = "Find Bera at the hunters’ board. Click or drag materials · I inspects · V works the object."

func _save_family() -> void:
	if launch_at_title:
		open_story_slots("save")
		return
	if chapter == null:
		return
	var result := _write_story(chapter_save_path)
	hint.text = "Game saved." if result == OK else "The save could not be written. " + error_string(result)
	load_family_button.disabled = not FileAccess.file_exists(chapter_save_path)

func _write_story(path: String) -> Error:
	var bench := view.workbench
	var scene := {"focus": bench.focus_target, "yaw": bench.yaw, "tilt": bench.tilt,
		"zoom": bench.zoom_target, "coal_origin": view.coal_origin}
	return ChapterSave.write_slot(path, chapter, mentor, scene)

func _load_family() -> void:
	if launch_at_title:
		open_story_slots("load")
	elif not _load_story(chapter_save_path):
		hint.text = "No readable save was found."

func _load_story(path: String) -> bool:
	var state := ChapterSave.read_slot(path)
	if state.is_empty():
		return false
	var loaded := Chapter.new(Fire.new())
	var loaded_mentor := Mentor.new()
	if not ChapterSave.restore(loaded, state, loaded_mentor):
		return false
	_reset_family()
	fire.structure_event.disconnect(sound.structure_event)
	fire.tinder_finished.disconnect(_on_tinder_finished)
	chapter = loaded
	fire = loaded.fire
	fire.tinder_finished.connect(_on_tinder_finished)
	mentor = loaded_mentor
	view.fire = fire
	view.workbench.replace_fire(fire)
	sound.fire = fire
	fire.structure_event.connect(sound.structure_event)
	stock_revision = -1
	supply_revision = -1
	stock_read_at = -INF
	history_version = -1
	if not paused:
		_pause()
	_story_journal(true)
	chapter_controls.show()
	torch_button.show()
	chapter_weather.show()
	ash_button.show()
	weather_picker.hide()
	site_picker.select(chapter.weather.site)
	_reset_hearth_controls()
	if _living_family():
		_open_family()
	else:
		_update_chapter()
	_restore_family_view(state.get("view", {}))
	_inspect()
	_update_time()
	hint.text = "Game restored. Resume when you are ready."
	if not chapter.outcome.is_empty():
		story_menu.show_results(chapter)
	elif launch_at_title:
		story_menu.show_chapter(ChapterSave.act(chapter), true)
	return true

func _restore_family_view(state: Dictionary) -> void:
	var bench := view.workbench
	var focus: Vector3 = state.get("focus", bench.focus_target)
	if focus.is_finite():
		bench.focus_on(focus)
	bench.yaw = float(state.get("yaw", bench.yaw))
	bench.tilt = float(state.get("tilt", bench.tilt))
	bench.zoom_target = float(state.get("zoom", bench.zoom_target))
	bench._update_camera()
	for coal in fire.coals:
		if coal.carried:
			_set_tool(View.Tool.COAL)
			view.carried_coal = coal
			view.coal_origin = state.get("coal_origin", coal.at)
			break

func _reset_family() -> void:
	if family_page == null:
		return
	family_page.attach(null)
	view.workbench.family_props.show_workshop(null)
	while site_picker.item_count > family_area_start:
		site_picker.remove_item(site_picker.item_count - 1)
	family_button.hide()
	family_news_button.hide()
	mind_cave_button.hide()
	heat_request_button.hide()
	chapter_ash.show()
	family_news_button.text = "Shelter news"

func _continue_after_storm() -> void:
	if chapter != null and chapter.begin_after_storm():
		_open_after_storm()
		story_menu.show_chapter(2)
		_checkpoint_story()

func _checkpoint_story() -> void:
	if not launch_at_title or story_profile != profiles.active or story_slot < 0:
		return
	var result := _write_story(profiles.slot_path(story_slot))
	if result != OK:
		var words := "The chapter is ready. Its checkpoint could not be written. Use F5 to save."
		if story_menu.mode == "chapter":
			story_menu.chapter_words.text = words
		else:
			hint.text = words

func _start_after_storm_trial() -> void:
	_start_chapter()
	chapter.set_up_after_storm_trial()
	_open_after_storm()
	if launch_at_title:
		story_menu.show_chapter(2)

func _open_after_storm() -> void:
	pause_button.disabled = false
	pause_button.text = "Resume  [Space]"
	held_camera_keys.clear()
	held_turns.clear()
	if not paused:
		_pause()
	view.workbench._refresh(0.0)
	mentor.story_line(Chapter.AfterStorm.DRYING_LESSON, "wood_methods")
	chapter.last_notice = chapter.guidance()
	_inspect()
	_update_chapter()
	hint.text = "Open Quests [O] to find both drying areas. Start the shelf pair first."

func _wood_condition(piece: Fire.Piece) -> String:
	if piece == null:
		return ""
	var name: String = Fire.SPECIES[piece.kind].label
	if _after_storm() and not _living_family():
		var detail := chapter.sequel.drying_detail(piece)
		if not detail.is_empty():
			return name + " · " + detail
	var wet := piece.water / piece.original
	if piece.vapor > 0.00006 and piece.temperature > 35.0:
		return name + " · Steaming"
	if piece.core != null and piece.core.water > piece.core.original * 0.36 and piece.faces[0].water < piece.faces[0].original * 0.24:
		return name + " · Dry skin, wet heart"
	return name + (" · Soaked" if wet >= 0.68 else (" · Damp" if wet >= 0.26 else " · Ready to burn"))

func _leave_chapter() -> void:
	if chapter == null:
		return
	_reset_family()
	chapter = null
	chapter_controls.hide()
	torch_button.hide()
	chapter_weather.hide()
	ash_button.hide()
	weather_picker.show()
	view.torch_present = false
	_story_journal(false)
	_close_torch()

func _choose_site(index: int) -> void:
	if chapter == null:
		return
	if _living_family() and index >= family_area_start:
		family_page.open_station(site_picker.get_item_text(index))
		site_picker.select(chapter.weather.site)
		return
	if index >= shelter_area_start and index < shelter_area_start + AREA_FOCUS.size():
		var at: Vector2 = AREA_FOCUS[index - shelter_area_start]
		view.workbench.focus_on(Vector3(at.x, 0.10, at.y))
		return
	if chapter.choose_site(index):
		hint.text = ["The rock keeps rain off here, but smoke has farther to travel.",
			"There is some cover with a way out for smoke.", "The mouth has more air. An inward wind can drive rain across the bed."][index]
	else:
		site_picker.select(chapter.weather.site)

func _story_journal(story: bool) -> void:
	ambient_overlay.offset_top = -345 if story else -466
	ambient_overlay.offset_bottom = ambient_overlay.offset_top + 118
	journal.offset_left = 174 if story else 28
	journal.offset_right = journal.offset_left + (246 if story else 300)
	journal.offset_top = -244 if story else -336
	journal.offset_bottom = -17 if story else -114
	heat_hand.position = Vector2(0, 157) if story else Vector2(0, 5)
	heat_hand.size = Vector2(66, 70) if story else Vector2(82, 91)
	heat_title.position = Vector2(0, 103) if story else Vector2(91, 22)
	warmth.position = Vector2(0, 123) if story else Vector2(91, 44)
	heat_title.size.x = 145 if story else 209
	warmth.size = Vector2(145, 34) if story else Vector2(209, 40)
	warmth.add_theme_font_size_override("font_size", 15 if story else 16)
	note_title.position.y = 0 if story else 100
	note.position.y = 19 if story else 120
	note.size = Vector2(245, 89) if story else Vector2(282, 84)
	_layout_consultation()

func _focus_woodpile() -> void:
	if chapter == null or _hearth_overlay_open():
		return
	view.workbench.focus_on(Vector3(-1.92, 0.12, clampf(-0.88 - float(Chapter.Shelter.DEPTHS[chapter.weather.site]), -1.32, 0.5)))

func _fuel_supply(button: Button, kind: int, stock: PackedInt32Array) -> void:
	var label := "%s  [%s]" % [Fire.SPECIES[kind].label, FUEL_KEYS[kind]]
	var count := -1 if stock.is_empty() else stock[kind]
	button.disabled = count == 0
	if kind == Fire.TINDER_BUNDLE:
		button.disabled = not fire.all_fuel().any(func(piece): return piece.kind == kind and piece.temperature < 85.0)
	button.text = label
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = label + "\n" + FUEL_DESCRIPTIONS[kind]
	if count >= 0:
		button.tooltip_text += "\n%d available in the woodpile" % count
		if _after_storm() and count > 0:
			button.tooltip_text += "\n" + _wood_condition(fire.stock_piece(kind))

func _wet_supply(button: Button, kind: int, piece: Fire.Piece) -> void:
	button.disabled = piece == null
	var wood_name: String = "branch" if kind == 8 else Fire.Materials.PROFILES[Fire.FUEL_MATERIAL[kind]].name.to_lower()
	button.text = "Wet %s  [%s]" % [wood_name, FUEL_KEYS[kind]]
	var size := "Large log" if Chapter.Quests.size_group(kind) == 3 else "Medium log"
	button.tooltip_text = "%s · %s" % [size, _wood_condition(piece)] if piece != null else "No wet piece of this species in storage."

func _toggle_torch() -> void:
	if chapter == null:
		return
	if torch_panel.visible:
		_close_torch()
	else:
		family_page.close()
		_close_ask()
		palette.hide()
		settings_panel.hide()
		history_panel.hide()
		debug.hide()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		torch_panel.show()
		_update_torch()
	_update_speaker()

func _close_torch() -> void:
	if torch_panel != null and torch_panel.visible:
		torch_panel.hide()
		view.mouse_filter = Control.MOUSE_FILTER_STOP

func _update_torch() -> void:
	torch_report.text = chapter.report
	if _living_family() and chapter.away < 0:
		for i in range(chapter.family.news.size() - 1, -1, -1):
			var entry: Dictionary = chapter.family.news[i]
			if entry.by == Chapter.Family.Roster.SCOUT:
				torch_report.text = entry.text
				break
		if torch_report.text.length() > 184:
			torch_report.text = torch_report.text.left(182).rsplit(" ", true, 1)[0] + "…"
		torch_report.tooltip_text = "Full reports are in News at the shelter."
	else:
		torch_report.tooltip_text = ""
	if chapter.away >= 0:
		torch_report.text += "\nBack in about %d sec of hearth time." % maxi(0, ceili(chapter.returns_at - fire.time))
	var route := torch_site.selected
	var priority := torch_priority.selected
	torch_detail.text = "%s %s" % [chapter.route_description(route), chapter.remaining_words(route)]
	torch_status.text = chapter.route_status(route, priority)
	torch_priority.disabled = route == Chapter.SCOUT
	torch_send.disabled = not chapter.can_request(route, priority)

func _request_trip() -> void:
	if chapter != null and chapter.request(torch_site.selected, torch_priority.selected):
		_close_torch()
		hint.text = chapter.report

func _open_heat_request() -> void:
	if _living_family() and not chapter.family.craft.heat_needs.is_empty():
		family_page.open_station(chapter.family.craft.heat_needs.keys()[0], false)

func _update_chapter() -> void:
	if chapter == null:
		return
	quest_button.visible = not _living_family()
	if quest_panel.visible:
		_refresh_quests()
	view.torch_present = chapter.away < 0
	if _living_family():
		view.workbench.family_props.show_workshop(chapter.family.workshop, chapter.family)
		var needs := chapter.family.craft.heat_needs
		heat_request_button.visible = not needs.is_empty()
		chapter_ash.visible = needs.is_empty()
		if not needs.is_empty():
			heat_request_button.text = "Nara needs steady red" if needs.keys()[0] == Chapter.Family.Workshop.COOK else "Ina needs indirect warmth"
			heat_request_button.tooltip_text = str(needs.values()[0])
		if family_news_seen != chapter.family.news_revision:
			family_news_seen = chapter.family.news_revision
			family_news_button.text = "News · " + Chapter.Family.Roster.person_name(chapter.family.latest.by)
			family_news_button.tooltip_text = chapter.family.latest.text
	chapter_note.text = chapter.objective()
	chapter_note.visible = chapter.outcome.is_empty() and not _living_family()
	chapter_weather.text = chapter.weather.weather_words() + "\n" + chapter.weather.local_words()
	chapter_weather.tooltip_text = chapter.weather.day_words(fire.time)
	chapter_ash.text = "Loose ash ready to sift" if fire.ash >= 0.001 else "Sweep ash when fuel burns down"
	var site_locked := not chapter.can_choose_site()
	if site_picker.is_item_disabled(0) != site_locked:
		for index in range(Chapter.Shelter.SITES.size()):
			site_picker.set_item_disabled(index, site_locked)
	torch_button.text = "Torch Bearer  [F6]" if chapter.away < 0 else "Cousin away  [F6]"
	if stock_revision != fire.storage_revision or (_after_storm() and fire.time - stock_read_at >= 1.0):
		stock_revision = fire.storage_revision
		stock_read_at = fire.time
		_refresh_fuel_bar()
	if supply_revision != chapter.supply_revision:
		supply_revision = chapter.supply_revision
		if chapter.supply_revision > 0:
			hint.text = chapter.report
	if torch_panel.visible:
		_update_torch()
	if not chapter.outcome.is_empty():
		_freeze_story_ui()
		pause_button.disabled = true
		pause_button.text = "Hearth lost" if chapter.outcome == "lost" else "Chapter complete"
		if not story_menu.visible:
			story_menu.show_results(chapter)
	if _living_family():
		return
	var line := chapter.guidance()
	if chapter.outcome.is_empty() and mentor.text.is_empty() and not _hearth_overlay_open():
		var teaching := chapter.weather_lesson()
		if not teaching.is_empty():
			var topic := "after_storm_tale_%d" % chapter.sequel.passage if _after_storm() else "red_hollow_weather"
			mentor.story_line(teaching, topic)
	if (mentor.text.is_empty() or not chapter.outcome.is_empty()) and line != chapter.last_notice:
		chapter.last_notice = line
		mentor.story_line(line, "red_hollow_tending")

func _toggle_debug() -> void:
	family_page.close()
	_close_torch()
	debug.visible = not debug.visible
	if debug.visible:
		_close_ask()
		history_panel.hide()
		palette.hide()
		settings_panel.hide()
		_update_debug()
	_update_speaker()

func _toggle_thermal_overlay() -> void:
	view.thermal_overlay = not view.thermal_overlay
	debug.hide()
	_update_speaker()
	hint.text = "Developer overlay · Surface, inner grain, core and integrity · Shift+F3 hides it" if view.thermal_overlay else ""
	if not view.thermal_overlay:
		_default_hint()

func _update_time() -> void:
	var elapsed := int(fire.time)
	var caption := "Paused" if paused else "%d×" % speed
	if chapter != null and not chapter.outcome.is_empty():
		caption = "Lost" if chapter.outcome == "lost" else "Complete"
	elif jump_steps > 0:
		caption = "Advancing"
	elif not paused and accumulator > maxf(0.4, speed * 0.05):
		caption += " · busy"
	time_label.text = "%02d:%02d  /  %s" % [floori(elapsed / 60.0), elapsed % 60, caption]

func _update_debug() -> void:
	debug_clock = 0.0
	var lines := PackedStringArray([
		"t = %.2f s    fixed step %.2f s    draft %.2f    oxygen %.0f%% of fresh air" %
			[fire.time, Fire.STEP, fire.airflow(), fire.oxygen * 100],
		"Ambient %.0f °C    Loose ash %.3f kg    Bed char %.3f kg    Flame %.1f kW" %
			[fire.ambient(), fire.ash, fire.coal_reserve(), fire.total_flame()],
		"Probe (%+.2f, %+.2f)    radiant index %.2f    local draft %s" %
			[view.probe.x, view.probe.y, fire.heat_at(view.probe), fire.wind_at(view.probe)],
		"Radiation kW   emitted %.2f   absorbed %.2f   to surroundings %.2f" %
			[fire.radiated, fire.absorbed, fire.radiated - fire.absorbed],
		"",
	])
	var focus := _thermal_focus()
	if focus != null:
		lines.append("Local heat ledger  •  %s %d" % ["Charcoal" if focus.kind < 0 else Fire.SPECIES[focus.kind].label, focus.id])
		if focus.sections.is_empty():
			_append_heat(lines, "Patch", focus)
		else:
			for i in range(focus.sections.size()):
				var region := focus.sections[i]
				lines.append("Region %d  •  integrity %.0f%%   load %.1f / %.1f N   grain tilt %.0f°" %
					[i + 1, region.integrity * 100.0, region.contact_load, region.bearing_limit(), rad_to_deg(region.grain_tilt)])
				_append_heat(lines, "Upper", region.faces[0])
				_append_heat(lines, "Lower", region.faces[1])
				for lane in range(region.inner.size()):
					_append_heat(lines, "Inner %d" % (lane + 1), region.inner[lane])
				_append_heat(lines, "Core ", region.core)
	lines.append("")
	lines.append("Material         °C   wood g  H2O g  char g  ash g   O2%  flame  air  dT/s")
	for piece: Fire.Piece in fire.coals + fire.wood:
		var title := "Bed %02d" % piece.id if piece.kind < 0 else "%s %02d" % [Fire.SPECIES[piece.kind].label, piece.id]
		lines.append(_reading(title, piece))
		if piece.core != null:
			lines.append(_reading("  Upper face", piece.faces[0]))
			lines.append(_reading("  Underside", piece.faces[1]))
			lines.append(_reading("  Core", piece.core))
			for i in range(piece.sections.size()):
				var section := piece.sections[i]
				lines.append(_reading("  Region %d" % (i + 1), section))
				lines.append(_reading("    Upper", section.faces[0]))
				lines.append(_reading("    Underside", section.faces[1]))
				lines.append(_reading("    Core", section.core))
		if piece.pose != null:
			lines.append("  Rest %.3f   pitch %+.1f°   yaw %+.1f°   supports %s (floor 0, coal −ID)" % [
				piece.height, rad_to_deg(atan(piece.pose.slope)), rad_to_deg(piece.axis.angle()), piece.pose.supports,
			])
	var scroll := report.scroll_vertical
	report.text = "\n".join(lines)
	report.scroll_vertical = scroll

func _thermal_focus() -> Fire.Piece:
	if view.selected in fire.wood:
		return view.selected
	var nearest: Fire.Piece
	var distance := INF
	for piece: Fire.Piece in fire.coals + fire.wood:
		var gap := piece.at.distance_squared_to(view.probe)
		if gap < distance:
			nearest = piece
			distance = gap
	return nearest

func _append_heat(lines: PackedStringArray, label: String, piece: Fire.Piece) -> void:
	var state := "flaming" if piece.flame > 1.0 else ("approaching" if piece.ignition > 0.08 else "below ignition")
	if piece.flame <= 1.0 and piece.trend < -4.0:
		state = "cooling"
	lines.append("  %s %4.0f°C   stored %6.1f kJ   water %5.1f g   char %5.1f g   %s" %
		[label, piece.temperature, piece.stored_heat(fire.ambient()), piece.water * 1000.0, piece.char_mass * 1000.0, state])
	lines.append("    kW  cond %+.2f   plume +%.2f   air %+.2f   radiation +%.2f / -%.2f" %
		[piece.conduction + piece.internal_heat, piece.plume_heat, -piece.convection_loss,
			piece.radiation_in, piece.radiation_out + piece.flame_radiation])
	lines.append("        drying %.2f   decomposition %.2f   reaction %.2f   char used %.2f g" %
		[piece.drying_heat, piece.decomposition_heat, piece.reaction_heat, piece.charcoal_used * 1000.0])
	if piece.kind < 0:
		lines.append("        charcoal %.0f kg/m³   porosity %.0f%%   bulk volume %.0f cm³" %
			[piece.char_density, piece.char_porosity * 100.0, piece.charcoal_volume() * 1_000_000.0])

func _reading(title: String, piece: Fire.Piece) -> String:
	return "%-15s %5.0f %7.1f %6.1f %7.1f %6.1f %5.0f %6.1f %4.2f %5.1f" % [
		title, piece.temperature, piece.wood * 1000, piece.water * 1000, piece.char_mass * 1000,
		(piece.cover + piece.mineral) * 1000, piece.oxygen * 100, piece.flame, piece.draft.length(), piece.trend,
	]

func _mode_button(parent: Control, title: String, bounds: Rect2, tool: int) -> void:
	var button := _button(parent, title, bounds, func() -> void: _choose_tool(tool))
	button.toggle_mode = true
	mode_buttons[tool] = button

func _volume(parent: Control, title: String, bounds: Rect2, value: float, action: Callable) -> void:
	var width := 76.0
	_label(parent, title, Rect2(bounds.position, Vector2(width, bounds.size.y)), 14, MUTED)
	var slider := HSlider.new()
	slider.position = bounds.position + Vector2(width + 4.0, 0)
	slider.size = Vector2(bounds.size.x - width - 4.0, bounds.size.y)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.025
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = "%s sound volume" % title
	slider.value_changed.connect(action)
	parent.add_child(slider)

func _make_theme() -> void:
	var interface := Theme.new()
	interface.default_font = _font(["Segoe UI", "Arial"])
	interface.default_font_size = 15
	for name in ["Button", "OptionButton"]:
		interface.set_color("font_color", name, TEXT)
		interface.set_color("font_hover_color", name, TEXT.lightened(0.12))
		interface.set_color("font_pressed_color", name, GOLD)
		interface.set_color("font_hover_pressed_color", name, GOLD)
		interface.set_stylebox("normal", name, _style(Color(0.09, 0.061, 0.045, 0.33), Color(0.76, 0.57, 0.42, 0.28)))
		interface.set_stylebox("hover", name, _style(Color(0.26, 0.16, 0.10, 0.75), Color(0.81, 0.55, 0.33, 0.80)))
		var selected := _style(Color(0.32, 0.17, 0.085, 0.90), GOLD)
		interface.set_stylebox("pressed", name, selected)
		interface.set_stylebox("hover_pressed", name, selected)
	interface.set_color("font_shadow_color", "Label", Color(0.035, 0.022, 0.015, 0.86))
	interface.set_constant("shadow_offset_y", "Label", 1)
	interface.set_constant("shadow_outline_size", "Label", 2)
	interface.set_stylebox("panel", "PopupMenu", _style(PANEL, LINE))
	interface.set_stylebox("hover", "PopupMenu", _style(Color("#4a3022"), LINE))
	interface.set_color("font_color", "PopupMenu", TEXT)
	interface.set_color("font_hover_color", "PopupMenu", GOLD)
	theme = interface

func _font(names: Array[String]) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	return font

func _label(parent: Control, words: String, bounds: Rect2, points: int, ink: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = bounds.position
	label.size = bounds.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ink)
	label.add_theme_font_size_override("font_size", points)
	if font != null:
		label.add_theme_font_override("font", font)
	parent.add_child(label)
	return label

func _button(parent: Control, title: String, bounds: Rect2, action: Callable, tip := "") -> Button:
	var button := Button.new()
	button.text = title
	button.position = bounds.position
	button.size = bounds.size
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _picker(parent: Control, bounds: Rect2, action: Callable) -> OptionButton:
	var picker := OptionButton.new()
	picker.position = bounds.position
	picker.size = bounds.size
	picker.fit_to_longest_item = false
	picker.focus_mode = Control.FOCUS_NONE
	parent.add_child(picker)
	picker.item_selected.connect(action)
	return picker

func _hud_layer() -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer

func _overlay(bounds: Rect2, align := Vector2.ZERO) -> Control:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock(overlay, bounds, align)
	return overlay

func _panel(bounds: Rect2, align := Vector2.ZERO, tint := PANEL) -> Panel:
	var panel := Panel.new()
	var backing := _style(tint, LINE)
	backing.shadow_color = Color(0.045, 0.029, 0.022, 0.5)
	backing.shadow_size = 9
	backing.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", backing)
	_dock(panel, bounds, align)
	return panel

func _dock(control: Control, bounds: Rect2, align: Vector2) -> void:
	hearth_hud.add_child(control)
	control.anchor_left = align.x
	control.anchor_right = align.x
	control.anchor_top = align.y
	control.anchor_bottom = align.y
	control.offset_left = bounds.position.x
	control.offset_top = bounds.position.y
	control.offset_right = bounds.end.x
	control.offset_bottom = bounds.end.y

func _style(tint: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style



