extends RefCounted

const Family := preload("res://sim/red_hollow_family.gd")
const Work := Family.Workshop
const Roster := Family.Roster
const Land := Family.Land
const Portraits := preload("res://hearth/family_portraits.gd")
const MindCave := preload("res://hearth/mind_cave.gd")
const MAP_PAGE := 3
const TECH_PAGE := 4
const Techniques := Work.Techniques
const PATHS := ["Quick Hand", "Deep Red", "Hearth Maker", "Kin’s Hearth"]
const PATH_GUIDES := [
	"Wake a flame from weak red with fine dry fuel and a little breath.",
	"Keep part of a living bed covered with ash for a sustained rest.",
	"Draw usable pitch from a warm cup, then seat and bind a sound haft.",
	"Turn a portion over the coals and roast both faces through.",
]
const CARDS := {
	"sela": Vector2(22, 0), "oren": Vector2(159, 0), "dena": Vector2(726, 0),
	"fire_speaker": Vector2(22, 72), "tavi": Vector2(159, 72), "ivo": Vector2(284, 72),
	"nara": Vector2(409, 72), "bera": Vector2(534, 72), "kett": Vector2(659, 72), "ina": Vector2(784, 72),
	"torch_bearer": Vector2(82, 144), "mira": Vector2(207, 144), "suri": Vector2(332, 144),
	"ember_tender": Vector2(481, 144), "lio": Vector2(606, 144),
}
const CARD_SIZE := Vector2(110, 34)

class TreeLines extends Control:
	func _draw() -> void:
		var ink := Color("#9c7452")
		for pair: Array in Roster.PARTNERS:
			var left: Vector2 = CARDS[pair[0]] + Vector2(CARD_SIZE.x, CARD_SIZE.y / 2.0)
			var right: Vector2 = CARDS[pair[1]] + Vector2(0, CARD_SIZE.y / 2.0)
			draw_line(left, right, ink, 2.0)
		_branch("sela", "oren", ["fire_speaker", "tavi", "nara"], ink)
		_branch("dena", "dena", ["bera", "kett", "ina"], ink)
		_branch("tavi", "ivo", ["torch_bearer", "mira", "suri"], ink)
		_branch("nara", "bera", ["ember_tender", "lio"], ink)

	func _branch(a: String, b: String, children: Array, ink: Color) -> void:
		var from: Vector2 = (CARDS[a] + CARDS[b]) / 2.0 + CARD_SIZE / 2.0
		if a == b:
			from.y += CARD_SIZE.y / 2.0
		var junction_y := float(CARDS[a].y) + 52.0
		var ends := PackedVector2Array()
		for id: String in children:
			var end: Vector2 = CARDS[id] + Vector2(CARD_SIZE.x / 2.0, 0)
			ends.append(end)
			draw_line(Vector2(end.x, junction_y), end, ink, 1.5)
		draw_line(from, Vector2(from.x, junction_y), ink, 1.5)
		draw_line(Vector2(minf(from.x, ends[0].x), junction_y),
			Vector2(maxf(from.x, ends[-1].x), junction_y), ink, 1.5)

var lab: Control
var family: Family
var station := ""
var page := 0
var person := Roster.APPRENTICE
var work_panel: Panel
var teaching_panel: Panel
var teacher_art: TextureRect
var teacher_name: Label
var teacher_words: Label
var teacher_task: Label
var recipe_picker: OptionButton
var learn_button: Button
var help_button: Button
var observe_button: Button
var seen_mode := ""
var last_coach := -1
var coach_line := ""
var bench_button: Button
var lesson_revision := -1
var teacher_id := ""
var lesson_complete := false
var last_work_sighting := -1
var family_panel: Panel
var station_title: Label
var work_status: Label
var work_notice: Label
var choice: OptionButton
var choose_action: Button
var secondary: Button
var operations: Array[Button] = []
var options: Array[Dictionary] = []
var detail: RichTextLabel
var ledger: RichTextLabel
var tree: TreeLines
var cards: Dictionary[String, Button] = {}
var page_tabs: Array[Button] = []
var station_tabs: Array[Button] = []
var path_picker: OptionButton
var heading: Label
var portraits_by_person: Dictionary[String, TextureRect] = {}
var mind_cave: MindCave
var show_on_map: Button
var news_map: Button
var news_portrait: TextureRect
var news_caption: Label
var person_stale := false
var reading := -INF
var last_revision := -1

func _init(scene: Control) -> void:
	lab = scene
	_build_work()
	_build_teaching()
	_build_family()

func _build_work() -> void:
	work_panel = lab._panel(Rect2(-432, 386, 404, 301), lab.RIGHT)
	station_title = lab._label(work_panel, "", Rect2(16, 8, 307, 34), 23, lab.GOLD, lab.serif)
	lab._button(work_panel, "Close", Rect2(330, 12, 58, 28), close_work)
	for i in range(3):
		var name: String = Work.STATIONS.keys()[i]
		var tab: Button = lab._button(work_panel, ["Cooking", "Game", "Hafting"][i], Rect2(16 + 126 * i, 49, 120, 29),
			open_station.bind(name), name)
		tab.toggle_mode = true
		station_tabs.append(tab)
	work_status = lab._label(work_panel, "", Rect2(16, 83, 372, 54), 15, lab.TEXT, lab.serif)
	work_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	work_status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	choice = lab._picker(work_panel, Rect2(16, 142, 372, 29), _choose_item)
	choice.focus_mode = Control.FOCUS_ALL
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choose_action = lab._button(work_panel, "", Rect2(16, 179, 182, 31), _act.bind(false))
	secondary = lab._button(work_panel, "", Rect2(206, 179, 182, 31), _act.bind(true))
	for i in range(2):
		operations.append(lab._button(work_panel, "", Rect2(16 + i * 190, 179, 182, 31), _operate.bind(i)))
	work_notice = lab._label(work_panel, "", Rect2(16, 219, 372, 64), 14, lab.MUTED, lab.serif)
	work_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	work_notice.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	work_panel.hide()

func _build_teaching() -> void:
	teaching_panel = lab._panel(Rect2(-277, 57, 554, 123), Vector2(0.5, 0))
	teacher_art = TextureRect.new()
	teacher_art.position = Vector2(12, 12)
	teacher_art.size = Vector2(94, 70)
	teacher_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	teacher_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	teacher_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	teaching_panel.add_child(teacher_art)
	teacher_name = lab._label(teaching_panel, "", Rect2(120, 7, 163, 29), 22, lab.GOLD, lab.serif)
	observe_button = lab._button(teaching_panel, "Observe", Rect2(253, 10, 73, 26), _work_mode.bind("observe"))
	learn_button = lab._button(teaching_panel, "Learn", Rect2(331, 10, 61, 26), _work_mode.bind("learn"))
	help_button = lab._button(teaching_panel, "Help", Rect2(397, 10, 60, 26), _work_mode.bind("help"))
	bench_button = lab._button(teaching_panel, "Bench", Rect2(462, 10, 79, 26), _toggle_bench)
	var again: Button = lab._button(teaching_panel, "Ask again", Rect2(12, 86, 94, 26), _repeat_teaching)
	for button: Button in [observe_button, learn_button, help_button, bench_button, again]:
		button.focus_mode = Control.FOCUS_ALL
	recipe_picker = lab._picker(teaching_panel, Rect2(120, 39, 215, 26), func(_slot: int) -> void: pass)
	recipe_picker.add_item("Resin adhesive")
	recipe_picker.add_item("Repair a haft")
	teacher_task = lab._label(teaching_panel, "", Rect2(120, 39, 416, 26), 14, lab.GOLD, lab.serif)
	teacher_task.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	teacher_words = lab._label(teaching_panel, "", Rect2(120, 65, 420, 52), 16, lab.TEXT, lab.serif)
	teacher_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	teacher_words.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	teaching_panel.hide()

func _toggle_bench() -> void:
	work_panel.visible = not work_panel.visible
	if work_panel.visible:
		_refresh_work()

func _recipe() -> String:
	if station == Work.HUNTER:
		return Techniques.MARROW
	if station == Work.COOK:
		return Techniques.ROAST
	return Techniques.HAFT if recipe_picker.selected == 1 else Techniques.RESIN

func _work_mode(mode: String) -> void:
	if family == null or station.is_empty():
		return
	if not family.craft.request(family, station, mode, _recipe()):
		if mode == "help":
			teacher_words.text = "Practice this technique a little more before taking a piece on your own."
		elif mode == "learn":
			teacher_words.text = "Give your teacher a little time before asking for a lesson."
		return
	seen_mode = ""
	match mode:
		"learn":
			teacher_words.text = "Watch my hands when the material is ready. Let time pass and I’ll show you."
		"help":
			teacher_words.text = "Take a piece that is free and work alongside me." if not teacher_id.is_empty() else \
				"Choose a piece and use the tools at the bench."
		"observe":
			_repeat_teaching()

func _repeat_teaching() -> void:
	if family != null and not teacher_id.is_empty():
		teacher_words.text = family.workshop.lessons.guidance(station)

func _teach() -> void:
	teacher_id = family.instructor(station)
	teaching_panel.show()
	learn_button.disabled = teacher_id.is_empty()
	teacher_art.texture = Portraits.read(teacher_id) if not teacher_id.is_empty() else null
	teacher_name.text = Roster.person_name(teacher_id) if not teacher_id.is_empty() else "Work bench"
	teacher_words.text = "The bench is unattended. There may be work you can do here." if teacher_id.is_empty() else \
		family.workshop.lessons.greet(station, teacher_id)
	lesson_complete = family.workshop.lessons.complete(station)
	lesson_revision = family.workshop.lessons.revision
	seen_mode = ""
	coach_line = ""
	recipe_picker.visible = station == Work.MAKER
	teacher_task.position.x = 343 if recipe_picker.visible else 120
	teacher_task.size.x = 197 if recipe_picker.visible else 416
	_teaching_tick()

func _teaching_tick() -> void:
	var activity := family.craft.active_text(station)
	var session: Dictionary = family.craft.sessions.get(station, {})
	var mode: String = session.get("mode", "")
	teacher_task.text = activity
	teacher_task.tooltip_text = activity
	learn_button.button_pressed = mode in ["waiting", "demonstrating", "supervised"]
	help_button.button_pressed = mode == "help"
	if family.craft.heat_needs.has(station) and not teacher_id.is_empty():
		teacher_words.text = family.craft.heat_needs[station]
		return
	if mode != seen_mode:
		seen_mode = mode
		if mode == "supervised" and teacher_id == session.teacher:
			teacher_words.text = "Now try it with a fresh piece. " + str(Techniques.BOOK[session.technique][6])
		elif mode == "demonstrating":
			teacher_words.text = str(Techniques.BOOK[session.technique][5])
	if mode != "supervised" or teacher_id != session.teacher:
		return
	var now := Time.get_ticks_msec()
	if now - last_coach < 3600:
		return
	var line := family.craft.coaching(family, station, lab.view.material_hover, lab.view.workbench.focus_target,
		lab.view.tool == lab.View.Tool.WOOD and lab.view.placing < 0)
	if not line.is_empty() and line != coach_line:
		last_coach = now
		coach_line = line
		teacher_words.text = line

func _build_family() -> void:
	family_panel = lab._panel(Rect2(-528, -305, 1056, 610), lab.CENTER)
	heading = lab._label(family_panel, "Stone Mountain’s kin", Rect2(24, 15, 550, 45), 32, lab.GOLD, lab.serif)
	lab._button(family_panel, "Close  [Esc]", Rect2(936, 23, 96, 32), close_family)
	for i in range(5):
		var tab: Button = lab._button(family_panel, ["Family Tree", "News at the shelter", "Ember Tender", "Mind Cave", "Techniques"][i],
			Rect2(24 + i * 173, 72, 164, 33), _set_page.bind(i))
		tab.focus_mode = Control.FOCUS_ALL
		tab.toggle_mode = true
		page_tabs.append(tab)
	tree = TreeLines.new()
	tree.position = Vector2(67, 129)
	tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	family_panel.add_child(tree)
	for id: String in CARDS:
		var card: Button = lab._button(tree, Roster.person_name(id), Rect2(CARDS[id], CARD_SIZE), _select_person.bind(id))
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_ALL
		card.tooltip_text = "%s · %s" % [Roster.PEOPLE[id][1], Roster.PEOPLE[id][2]]
		cards[id] = card
	detail = _reader(Rect2(32, 327, 704, 211), 18)
	show_on_map = lab._button(family_panel, "Find in Mind Cave", Rect2(32, 548, 177, 32), _map_from_person)
	show_on_map.focus_mode = Control.FOCUS_ALL
	news_portrait = _portrait_box(Rect2(794, 133, 219, 219))
	news_caption = lab._label(family_panel, "", Rect2(794, 354, 219, 32), 19, lab.GOLD, lab.serif)
	news_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_map = lab._button(family_panel, "Find report in Mind Cave", Rect2(794, 399, 219, 32), _map_from_news)
	news_map.focus_mode = Control.FOCUS_ALL
	ledger = _reader(Rect2(32, 128, 726, 451), 18)
	path_picker = lab._picker(family_panel, Rect2(30, 125, 220, 32), _change_focus)
	path_picker.focus_mode = Control.FOCUS_ALL
	for path: String in PATHS:
		path_picker.add_item(path)
	mind_cave = MindCave.new()
	mind_cave.position = Vector2(25, 123)
	mind_cave.size = Vector2(1005, 461)
	family_panel.add_child(mind_cave)
	mind_cave.build(lab)
	mind_cave.person_selected.connect(_show_person)
	mind_cave.focus_requested.connect(_focus_place)
	family_panel.hide()

func _portrait_box(bounds: Rect2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.position = bounds.position
	portrait.size = bounds.size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	family_panel.add_child(portrait)
	return portrait

func _load_portraits() -> void:
	for id: String in cards:
		if id == Roster.APPRENTICE:
			continue
		var portrait := _portrait_box(Rect2(788, 327, 232, 232))
		portrait.texture = Portraits.read(id)
		portrait.hide()
		portraits_by_person[id] = portrait
		var card := cards[id]
		card.icon = portrait.texture
		card.add_theme_constant_override("icon_max_width", 24)
		card.expand_icon = true

func _reader(rect: Rect2, points: int) -> RichTextLabel:
	var reader := RichTextLabel.new()
	reader.position = rect.position
	reader.size = rect.size
	reader.bbcode_enabled = true
	reader.focus_mode = Control.FOCUS_ALL
	reader.selection_enabled = true
	reader.add_theme_font_override("normal_font", lab.serif)
	reader.add_theme_font_size_override("normal_font_size", points)
	reader.add_theme_color_override("default_color", lab.TEXT)
	family_panel.add_child(reader)
	return reader

func attach(model: Family) -> void:
	close()
	family = model
	if family != null and portraits_by_person.is_empty():
		_load_portraits()
	mind_cave.attach(model)
	person = Roster.APPRENTICE
	page = 0
	last_revision = -1
	reading = -INF

func open_station(name: String, bench := true) -> void:
	if family == null or not Work.SURFACES.has(name):
		return
	if not Work.STATIONS.has(name):
		var rest: Vector2 = Work.SURFACES[name]
		lab.view.workbench.focus_on(Vector3(rest.x, 0.12, rest.y))
		family.remember_workplace(name)
		return
	close_family()
	lab._close_torch()
	lab._close_ask()
	lab.history_panel.hide()
	lab.settings_panel.hide()
	lab.palette.hide()
	lab.debug.hide()
	if not station.is_empty() and station != name:
		family.craft.request(family, station, "observe")
	station = name
	work_panel.visible = bench
	station_title.text = station
	_teach()
	family.remember_workplace(station)
	last_work_sighting = family.workshop.revision
	lab.hint.text = "Click or drag to lift and place materials · I inspects · V works the object"
	for i in range(station_tabs.size()):
		station_tabs[i].set_pressed_no_signal(Work.STATIONS.keys()[i] == station)
	if name == Work.COOK or (name == Work.MAKER and family.workshop.resin != null and family.workshop.resin_position >= 0):
		_focus_fire()
	else:
		var at: Vector2 = Work.STATIONS[name]
		lab.view.workbench.focus_on(Vector3(at.x, 0.32, at.y))
	last_revision = -1
	_refresh_work()
	lab._update_speaker()

func _focus_fire() -> void:
	lab.view.workbench.focus_on(Vector3(-0.52, 0.14, -0.04))

func close_work() -> void:
	if station.is_empty():
		return
	if family != null:
		family.craft.request(family, station, "observe")
	station = ""
	teaching_panel.hide()
	work_panel.hide()
	lab._update_speaker()

func toggle_family(tab := 0) -> void:
	if family == null and (tab != MAP_PAGE or not lab._after_storm()):
		return
	if family_panel.visible and page == tab:
		close_family()
		return
	close_work()
	lab._close_torch()
	lab._close_ask()
	lab.history_panel.hide()
	lab.settings_panel.hide()
	lab.palette.hide()
	lab.debug.hide()
	family_panel.show()
	lab.view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if family == null and mind_cave.field_land != lab.chapter.land:
		mind_cave.attach_field(lab.chapter.land)
	_set_page(tab)
	lab._update_speaker()

func close_family() -> void:
	if family_panel.visible:
		family_panel.hide()
		lab.view.mouse_filter = Control.MOUSE_FILTER_STOP
		lab._update_speaker()

func close() -> void:
	close_work()
	close_family()

func update() -> void:
	if family == null:
		if family_panel.visible and page == MAP_PAGE:
			mind_cave.update_map()
		return
	if not station.is_empty():
		if last_work_sighting != family.workshop.revision:
			family.remember_workplace(station)
			last_work_sighting = family.workshop.revision
		if work_panel.visible:
			_refresh_work()
		if teacher_id != family.instructor(station):
			_teach()
		elif teaching_panel.visible and lesson_revision != family.workshop.lessons.revision:
			lesson_revision = family.workshop.lessons.revision
			var finished := family.workshop.lessons.complete(station)
			var reaction: String = family.workshop.lessons.reactions.get(station, "")
			if finished and not lesson_complete:
				teacher_words.text = family.workshop.lessons.guidance(station)
			elif not reaction.is_empty():
				teacher_words.text = reaction
			lesson_complete = finished
		_teaching_tick()
	elif not lab._hearth_overlay_open():
		for area: String in Work.STATIONS:
			if not family.workshop.lessons.seen.has(area):
				var at: Vector2 = Work.STATIONS[area]
				var focus: Vector3 = lab.view.workbench.focus_target
				if Vector2(focus.x, focus.z).distance_to(at) < 0.23 and not family.instructor(area).is_empty():
					open_station(area, false)
					break
	if not family_panel.visible:
		return
	if page == MAP_PAGE:
		mind_cave.update_map()
		return
	var revision := family.news_revision if page == 1 else family.knowledge_revision
	var timestamp := float(family.workshop.techniques.revision if page == TECH_PAGE else (family.workshop.lesson_revision if page == 2 else revision))
	if timestamp != reading or (page == 0 and person_stale != _stale_person()):
		_refresh_family()

func _set_page(index: int) -> void:
	page = index
	for i in range(page_tabs.size()):
		page_tabs[i].visible = family != null
		page_tabs[i].set_pressed_no_signal(i == page)
	tree.visible = page == 0
	detail.visible = page == 0
	ledger.visible = page in [1, 2, TECH_PAGE]
	path_picker.visible = page == 2
	show_on_map.visible = page == 0
	mind_cave.visible = page == MAP_PAGE
	heading.text = "Mind Cave" if page == MAP_PAGE else "Stone Mountain’s kin"
	news_portrait.visible = page == 1
	news_caption.visible = page == 1
	news_map.visible = family != null and page == 1 and not family.latest.get("place", "").is_empty()
	ledger.position.y = 171 if page == 2 else 128
	ledger.size = Vector2(985, 408) if page == 2 else (Vector2(985, 451) if page == TECH_PAGE else Vector2(726, 451))
	if family != null:
		_refresh_family()
	else:
		mind_cave.update_map()

func _select_person(id: String) -> void:
	person = id
	mind_cave.mark_person(id)
	_refresh_family()

func _show_person(id: String) -> void:
	person = id
	mind_cave.mark_person(id)
	_set_page(0)
	cards[id].grab_focus()

func _map_from_person() -> void:
	mind_cave.mark_person(person)
	_set_page(MAP_PAGE)

func _map_from_news() -> void:
	mind_cave.show_place(family.latest.place)
	_set_page(MAP_PAGE)

func _focus_place(place: String, close_map: bool) -> void:
	var at: Vector2 = Land.INSIDE[place][4]
	lab.view.workbench.focus_on(Vector3(at.x, 0.10, at.y))
	if close_map and family != null and Work.SURFACES.has(place):
		family.remember_workplace(place)
	if close_map:
		close_family()

func _stale_person() -> bool:
	return person != Roster.APPRENTICE and Land.stale(family.known[person].seen, family.fire.time)

func _refresh_family() -> void:
	for id: String in portraits_by_person:
		portraits_by_person[id].visible = page == 0 and person == id
	match page:
		0:
			reading = family.knowledge_revision
			for id: String in cards:
				cards[id].set_pressed_no_signal(id == person)
			var relative: Array = Roster.PEOPLE[person]
			var seen: Dictionary = family.known[person]
			person_stale = _stale_person()
			var learned := ("Older sighting · " if person_stale else "") + "%s · %s" % [seen.source, Land.stamp(seen.learned)]
			if seen.seen < seen.learned:
				learned += " · observed " + Land.stamp(seen.seen)
			var condition := ""
			if person != Roster.APPRENTICE:
				condition = "\nLast seen injured" if seen.injury >= 0.26 else ("\nLast seen tired" if seen.fatigue >= 0.30 else "\nLast seen well")
			var words: String = Roster.SAYINGS.get(person, "")
			if not seen.away and not words.is_empty():
				condition += "\n\n[color=#d1bba4]“%s”[/color]" % words
			detail.text = "[font_size=26][color=#f0b77b]%s[/color][/font_size]     %s · %s\n%s\n\n%s · %s\n%s%s" % [
				relative[0], relative[1], relative[2], relative[3], seen.activity, seen.place, learned, condition]
		1:
			reading = family.news_revision
			var entries := PackedStringArray()
			for i in range(family.news.size() - 1, -1, -1):
				var entry: Dictionary = family.news[i]
				var when := Land.stamp(entry.heard)
				if entry.happened < entry.heard:
					when += " · happened " + Land.stamp(entry.happened)
				entries.append("[color=#f0b77b]%s[/color]     %s\n%s" % [Roster.person_name(entry.by), when, entry.text])
			ledger.text = "\n\n".join(entries)
			var reporter: String = family.latest.by
			news_portrait.texture = portraits_by_person[reporter].texture
			news_caption.text = Roster.person_name(reporter) + " · Latest news"
			news_map.visible = not family.latest.get("place", "").is_empty()
		2:
			reading = family.workshop.lesson_revision
			var focus_index := PATHS.find(family.workshop.focus)
			path_picker.select(focus_index)
			var lines := PackedStringArray(["[color=#f0b77b]%s[/color]\n%s" % [PATHS[focus_index], PATH_GUIDES[focus_index]]])
			for path: String in PATHS:
				if not family.workshop.record.has(path):
					continue
				var lessons: Dictionary = family.workshop.record[path]
				for lesson: String in lessons:
					lines.append("[color=#f0b77b]%s[/color] · %s\n%s" % [path, lesson, lessons[lesson]])
			ledger.text = "\n\n".join(lines)
		TECH_PAGE:
			reading = family.workshop.techniques.revision
			ledger.text = family.workshop.techniques.reading()
		MAP_PAGE:
			mind_cave.update_map()

func _change_focus(index: int) -> void:
	family.workshop.focus = PATHS[index]
	_refresh_family()

func _option(label: String, action: String, value, alt := "") -> void:
	options.append({"label": label, "action": action, "value": value, "alt": alt})

func _refresh_work() -> void:
	var model := family.workshop
	var operating := (station == Work.COOK and model.roast != null) or (station == Work.MAKER and model.resin != null and model.resin_position >= 0)
	choice.visible = not operating
	choose_action.visible = not operating
	if operating:
		secondary.hide()
	for operation in operations:
		operation.visible = operating
	match station:
		Work.COOK: _cooking_status(model)
		Work.HUNTER: work_status.text = "Bera · “Lay the good cuts on Nara’s board. Leave Mira a piece of hide for the bindings.”"
		Work.MAKER: _maker_status(model)
	work_notice.text = model.notices.get(station, "")
	if operating or last_revision == model.revision:
		return
	last_revision = model.revision
	var previous: Dictionary = options[choice.selected] if choice.selected >= 0 and choice.selected < options.size() else {}
	options.clear()
	choice.clear()
	match station:
		Work.COOK:
			for parcel in model.portions_at(Work.COOK):
				if parcel.kind not in ["meat", "marrow"]:
					continue
				_option("%s · %d g · board" % [parcel.label(), parcel.grams], "Set on spit", parcel.id)
			for parcel in model.portions_at(Work.STORE):
				var action := "Discard charred food" if parcel.kind in ["meat", "marrow"] and parcel.condition() == "Charred" else ""
				var label := "%s · %d g · shelf" % [parcel.label(), parcel.grams]
				if parcel.kind in ["meat", "marrow"] and parcel.condition() in ["Raw", "Undercooked", "Dried"]:
					action = "Return to board"
				_option(label, action, parcel.id)
		Work.HUNTER:
			var actions := {"carcass": "Separate cuts", "bone": "Crack for marrow", "hide": "Cut a binding strip",
				"meat": "Carry to Nara", "marrow": "Carry to Nara"}
			for parcel in model.portions_at(Work.HUNTER):
				var origin := " · " + parcel.origin if not parcel.origin.is_empty() else ""
				_option("%s · %d g%s" % [parcel.label(), parcel.grams, origin], actions.get(parcel.kind, ""), parcel.id)
			_gear_options(model, false)
		Work.MAKER:
			for parcel in model.portions_at(Work.MAKER):
				var action := "Scrape resin" if parcel.kind == "knot" else ("Warm the cup" if parcel.kind == "resin" else "")
				_option("%s · %d g" % [parcel.label(), parcel.grams], action, parcel.id)
			_gear_options(model, true)
	var selected := 0
	for i in range(options.size()):
		choice.add_item(options[i].label)
		if options[i] == previous:
			selected = i
	if options.is_empty():
		choice.add_item("Nothing laid here")
	choice.select(selected)
	choice.disabled = options.is_empty()
	_work_buttons()

func _gear_options(model: Work, at_maker: bool) -> void:
	for id: String in model.gear:
		var tool: Dictionary = model.gear[id]
		var condition := "sound" if tool.condition >= 0.67 else ("loose" if tool.condition >= 0.20 else "cracked")
		var status := condition if tool.at == Work.HUNTER else "away"
		_option("%s’s spear · %s" % [Roster.person_name(id), status], "Bind the haft" if at_maker else "Inspect spear",
			id, "Fit new shaft and point" if at_maker else "")

func _choose_item(index: int) -> void:
	if station == Work.COOK and family.workshop.roast != null:
		family.workshop.move_spit(index)
	else:
		_work_buttons()

func _work_buttons() -> void:
	var entry: Dictionary = options[choice.selected] if choice.selected >= 0 and choice.selected < options.size() else {}
	var action: String = entry.get("action", "")
	choose_action.text = action if not action.is_empty() else "Inspect the stock"
	choose_action.disabled = action.is_empty()
	secondary.visible = not entry.get("alt", "").is_empty()
	if action == "Bind the haft":
		choose_action.disabled = not family.workshop.can_haft(entry.value, false)
		secondary.text = entry.alt
		secondary.disabled = not family.workshop.can_haft(entry.value, true)
		var requirements := "A spear on the rack, 12 g rawhide and 10 g resin adhesive."
		choose_action.tooltip_text = requirements
		secondary.tooltip_text = requirements + " Also uses a spare point and shaft."
	else:
		choose_action.tooltip_text = ""

func _cooking_status(model: Work) -> void:
	if model.roast == null:
		work_status.text = "Food on the covered shelf  ·  %d g ready to share\nCarry meat here from the hunters’ board." % model.food_on_shelf()
		return
	var roast := model.roast
	operations[0].text = "Turn spit"
	operations[1].text = "Lift to shelf"
	choice.show()
	if choice.item_count != Work.ROAST_RESTS.size() or choice.get_item_text(0) != Work.ROAST_RESTS[0]:
		choice.clear()
		for rest: String in Work.ROAST_RESTS:
			choice.add_item(rest)
	choice.disabled = false
	choice.select(model.roast_position)
	work_status.text = "%s · %s facing the heat\nFirst face %s · Second face %s" % [
		roast.condition(), "First face" if roast.face == 0 else "Second face", _face(roast.dose[0]), _face(roast.dose[1])]
	if model.record.has("Kin’s Hearth"):
		work_status.text += "\nCentre " + ("warm through" if roast.core >= 65.0 else "still cool")

func _face(dose: float) -> String:
	if dose >= 2.9:
		return "dry"
	if dose >= 1.0:
		return "browned"
	return "colouring" if dose >= 0.15 else "pale"

func _maker_status(model: Work) -> void:
	if model.resin == null:
		work_status.text = "Ina · “Scrape a sticky knot into the cup. Warm it gently and lift it when the resin runs evenly.”"
		return
	if model.resin_position < 0:
		work_status.text = "The cup is away from the heat. Carry it to the warm stone or set it down with Ina’s materials."
		return
	var cup := model.resin
	operations[0].text = "Lift cup"
	operations[1].text = "Closer to red" if model.resin_position == 0 else "To warm stone"
	var state := "Scorched" if cup.scorched >= 1.0 else ("Runs evenly" if cup.cure >= 1.0 else (
		"Softening" if cup.temperature >= 68.0 else "Still gritty"))
	if cup.temperature > 165.0 and cup.scorched < 1.0:
		state = "Too hot · lift the cup"
	work_status.text = "%s · %s" % [Work.RESIN_RESTS[model.resin_position], state]

func _operate(index: int) -> void:
	var model := family.workshop
	if station == Work.COOK and model.roast != null:
		match index:
			0: model.turn_spit()
			1: model.lift_spit()
	elif station == Work.MAKER and model.resin != null:
		if index == 0:
			model.lift_resin()
		elif index == 1:
			model.move_resin(1 - model.resin_position)
	_refresh_work()

func _act(alt: bool) -> void:
	if choice.selected < 0 or choice.selected >= options.size():
		return
	var entry := options[choice.selected]
	var model := family.workshop
	if (entry.value is int and model.reserved.has(entry.value)) or \
			(entry.action == "Bind the haft" and model.reserved.has(model.gear_id(entry.value))):
		teacher_words.text = "Someone is already working on that piece."
		return
	match entry.action:
		"Separate cuts": model.butcher(entry.value)
		"Crack for marrow": model.crack_bone(entry.value)
		"Cut a binding strip": model.cut_binding(entry.value)
		"Carry to Nara": model.carry_to_cook(entry.value)
		"Set on spit": model.put_on_spit(entry.value)
		"Discard charred food": model.discard_food(entry.value)
		"Return to board": model.return_to_board(entry.value)
		"Scrape resin": model.scrape_knot(entry.value)
		"Warm the cup":
			if model.set_resin(entry.value):
				_focus_fire()
		"Bind the haft": model.haft(entry.value, alt)
		"Inspect spear":
			var tool: Dictionary = model.gear[entry.value]
			model.notices[Work.HUNTER] = "%s’s spear · %d%% sound. %s" % [Roster.person_name(entry.value), roundi(tool.condition * 100.0),
				"On the hunters’ rack." if tool.at == Work.HUNTER else "Carried out on the path."]
	_refresh_work()
