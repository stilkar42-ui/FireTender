extends Control
## A view of dated knowledge. The field simulation is never read here.

const Family := preload("res://sim/red_hollow_family.gd")
const Land := Family.Land
const Roster := Family.Roster
const Marks := preload("res://hearth/mind_marks.gd")
const Portraits := preload("res://hearth/family_portraits.gd")
const INK := Color("#41281b")
const OCHRE := Color("#85421f")
const OLD := Color("#6a5141")
const MAP_SIZE := Vector2(616, 366)
const PERSON_SIZE := Vector2(38, 24)

signal person_selected(id: String)
signal focus_requested(place: String, close_map: bool)

class Stone extends Control:
	var inside := false
	var plain := false
	var route := ""
	var surface: ImageTexture

	func ensure_surface() -> void:
		if surface != null:
			return
		var texture := Image.create(328, 194, false, Image.FORMAT_RGB8)
		var grain := FastNoiseLite.new()
		grain.seed = 761
		grain.frequency = 0.024
		var dust := RandomNumberGenerator.new()
		dust.seed = 712
		for y in range(texture.get_height()):
			for x in range(texture.get_width()):
				var mottling := grain.get_noise_2d(x, y) * 0.17 + dust.randf_range(-0.028, 0.028)
				var rim := Vector2(x / 328.0 - 0.50, y / 194.0 - 0.48).length()
				var stone := Color("#c9a376").lerp(Color("#7c503a"), smoothstep(0.28, 0.74, rim) * 0.40)
				texture.set_pixel(x, y, stone.lightened(mottling) if mottling >= 0.0 else stone.darkened(-mottling))
		surface = ImageTexture.create_from_image(texture)

	func _draw() -> void:
		if surface == null:
			return
		draw_texture_rect(surface, Rect2(Vector2.ZERO, size), false)
		var rand := RandomNumberGenerator.new()
		rand.seed = 279 if inside else 712
		for i in range(180):
			var at := Vector2(rand.randf_range(5, 610), rand.randf_range(5, 359))
			draw_circle(at, rand.randf_range(0.4, 1.8), Color(INK, rand.randf_range(0.02, 0.15)), true)
		if not plain:
			if inside:
				_draw_cave_wall()
			else:
				_draw_land()
		draw_rect(Rect2(Vector2.ONE * 1.0, size - Vector2.ONE * 2.0), Color(INK, 0.58), false, 2.0)

	func _draw_cave_wall() -> void:
		var wall := PackedVector2Array([Vector2(236, 350), Vector2(158, 334), Vector2(64, 294), Vector2(42, 208),
			Vector2(55, 126), Vector2(44, 63), Vector2(134, 29), Vector2(244, 28), Vector2(334, 33),
			Vector2(416, 24), Vector2(551, 46), Vector2(573, 111), Vector2(557, 214), Vector2(563, 269),
			Vector2(477, 306), Vector2(377, 345)])
		for i in range(2):
			var edge := PackedVector2Array()
			for j in range(wall.size()):
				var point := wall[j].lerp(Vector2(305, 180), i * 0.07)
				edge.append(point + Vector2(sin(j * 2.3), sin(j * 1.1)) * (2 + i * 3))
			draw_polyline(edge, Color(INK, 0.33 - i * 0.13), 5.0 - i * 2.0, true)
		draw_arc(Vector2(305, 220), 41.0, 0.14, TAU - 0.2, 30, Color(OCHRE, 0.20), 2.0, true)

	func _draw_land() -> void:
		for i in range(2):
			var offset := Vector2(0, i * 9)
			var ridge := PackedVector2Array([Vector2(12, 63), Vector2(74, 33), Vector2(108, 37),
				Vector2(155, 19), Vector2(197, 33), Vector2(228, 25), Vector2(272, 37), Vector2(329, 21),
				Vector2(375, 31), Vector2(414, 22), Vector2(465, 40), Vector2(510, 29), Vector2(604, 59)])
			for j in range(ridge.size()):
				ridge[j] += offset + Vector2(0, sin(j * 1.7) * (2 + i * 3))
			draw_polyline(ridge, Color(INK, 0.25 - i * 0.08), 3.1 - i, true)
		var water := PackedVector2Array([Vector2(5, 306), Vector2(46, 317), Vector2(103, 314),
			Vector2(153, 329), Vector2(215, 322), Vector2(264, 340), Vector2(330, 339),
			Vector2(379, 329), Vector2(434, 340), Vector2(503, 322), Vector2(556, 318), Vector2(609, 302)])
		draw_polyline(water, Color("#624c43", 0.45), 2.4, true)
		for edge: Array in Land.PATHS:
			var from: Vector2 = Land.TERRITORY[edge[0]][0]
			var to: Vector2 = Land.TERRITORY[edge[1]][0]
			_trace(from, to, Color(INK, 0.44), 1.25)
		if not route.is_empty() and Land.TERRITORY.has(route) and route != Land.HOME:
			_trace(Land.TERRITORY[Land.HOME][0], Land.TERRITORY[route][0], Color(OCHRE, 0.78), 2.7)

	func _trace(from: Vector2, to: Vector2, ink: Color, width: float) -> void:
		var distance := from.distance_to(to)
		var direction := (to - from).normalized()
		var normal := direction.orthogonal()
		for step in range(25, floori(distance) - 24, 11):
			var at := from + direction * step + normal * sin(step * 0.048) * 5.5
			draw_line(at, at + direction * 4.2, ink, width, true)

class PlaceMark extends Button:
	var glyph := ""
	var caption := ""
	var selected := false
	var weather := ""
	var weather_old := false
	var event_mark := ""
	var event_old := false
	var lettering: Font

	func _draw() -> void:
		var centre := Vector2(size.x / 2.0, 22)
		var ink := OCHRE if selected else INK
		if selected or is_hovered() or has_focus():
			draw_circle(centre, 26, Color("#e7c096", 0.52), true, -1.0, true)
			draw_arc(centre, 25, 0.12, TAU + 0.02, 32, ink, 2.0, true)
		Marks.paint(self, glyph, centre, 0.90, ink)
		var text_width := lettering.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var baseline := Vector2((size.x - text_width) / 2.0, 54)
		draw_rect(Rect2(baseline + Vector2(-4, -13), Vector2(text_width + 8, 17)), Color("#c8a071", 0.92))
		draw_string(lettering, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
		if not weather.is_empty():
			_badge(weather, centre + Vector2(-31, -11), weather_old)
		if not event_mark.is_empty():
			_badge(event_mark, centre + Vector2(-32, 11), event_old)

	func _badge(symbol: String, at: Vector2, faded: bool) -> void:
		draw_circle(at, 9.0, Color("#d7ae82"), true, -1.0, true)
		if faded:
			draw_arc(at, 9.0, 0, PI * 1.2, 10, OLD, 1.3, true)
		Marks.paint(self, symbol, at, 0.36, OLD if faded else OCHRE)

class KinMark extends Button:
	var count := 0
	var uncertain := false
	var lettering: Font

	func _draw() -> void:
		if count == 0:
			return
		var centre := Vector2(12, 12)
		var ink := OLD if uncertain else OCHRE
		draw_circle(centre, 11, Color("#e1bb8d"), true, -1.0, true)
		if uncertain:
			for i in range(5):
				draw_arc(centre, 10.5, i * TAU / 5.0, (i + 0.63) * TAU / 5.0, 8, ink, 1.5, true)
		else:
			draw_arc(centre, 10.5, 0, TAU, 22, ink, 1.5, true)
		Marks.paint(self, "kin", centre + Vector2(0, 1), 0.67, ink)
		if count > 1:
			draw_string(lettering, Vector2(24, 17), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		if is_hovered() or has_focus():
			draw_line(Vector2(1, 24), Vector2(34, 24), ink, 2.0, true)

var lab: Control
var family: Family
var inside := false
var chosen := Land.HOME
var chart: Stone
var area_tabs: Array[Button] = []
var place_buttons: Dictionary[String, PlaceMark] = {}
var kin_buttons: Dictionary[String, KinMark] = {}
var related: Dictionary = {}
var place_list: ScrollContainer
var notes: VBoxContainer
var look_button: Button
var person_buttons: Dictionary[String, Button] = {}
var next_fade := INF
var revision := Vector2i(-1, -1)
var person_highlight := ""

func build(scene: Control) -> void:
	lab = scene
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(2):
		var tab: Button = lab._button(self, ["Territory", "Inside Red Hollow"][i], Rect2(142 * i, 0, 134, 30), _switch_chart.bind(i == 1))
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_ALL
		area_tabs.append(tab)
	chart = Stone.new()
	chart.position = Vector2(0, 40)
	chart.size = MAP_SIZE
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chart)
	var border: Panel = Panel.new()
	border.position = Vector2(634, 0)
	border.size = Vector2(369, 459)
	border.add_theme_stylebox_override("panel", lab._style(Color("#2c2118"), lab.LINE))
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	place_list = ScrollContainer.new()
	place_list.position = Vector2(648, 14)
	place_list.size = Vector2(341, 389)
	place_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(place_list)
	notes = VBoxContainer.new()
	notes.custom_minimum_size.x = 322
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_theme_constant_override("separation", 6)
	place_list.add_child(notes)
	look_button = lab._button(self, "Look here in the cave", Rect2(648, 413, 235, 31), _look)
	look_button.focus_mode = Control.FOCUS_ALL
	var hint: Label = lab._label(self, "Solid ring · recent sighting    Broken ring · older sighting or someone seen leaving",
		Rect2(0, 410, 616, 20), 14, lab.MUTED)
	hint.tooltip_text = "A traveller’s destination is marked by a trail of dots."
	var legend: Label = lab._label(self, "Branches · fuel    Hoofprints · game    Curl or rain · weather    Triangle · concern",
		Rect2(0, 433, 616, 20), 14, lab.MUTED)
	legend.tooltip_text = "The place details name the observer and the time."

func attach(model: Family) -> void:
	family = model
	inside = false
	chosen = Land.HOME
	person_highlight = ""
	revision = Vector2i(-1, -1)
	next_fade = INF
	if family != null:
		_rebuild_chart()

func show_place(place: String, id := "") -> void:
	if family == null:
		return
	person_highlight = id
	var interior_place := Land.INSIDE.has(place) and place != Land.HOME
	var show_inside := interior_place or (inside and place == Land.HOME)
	var changed := inside != show_inside
	inside = show_inside
	chosen = place if _places().has(place) else Land.HOME
	if changed:
		_rebuild_chart()
	_refresh(true)

func mark_person(id: String) -> void:
	var seen: Dictionary = family.known[id]
	if seen.away and seen.place == Land.HOME and inside:
		_switch_chart(false)
	show_place(_linked_place(id), id)

func _linked_place(id: String) -> String:
	return "Hearth" if id == Roster.APPRENTICE else family.known[id].place

func _places() -> Dictionary:
	return Land.INSIDE if inside else Land.TERRITORY

func _switch_chart(show_inside: bool) -> void:
	if family == null:
		return
	if inside != show_inside:
		inside = show_inside
		chosen = Land.HOME
		person_highlight = ""
		_rebuild_chart()
	_refresh(true)

func _rebuild_chart() -> void:
	chart.ensure_surface()
	for button in place_buttons.values() + kin_buttons.values():
		chart.remove_child(button)
		button.queue_free()
	place_buttons.clear()
	kin_buttons.clear()
	var empty := StyleBoxEmpty.new()
	for place: String in _places():
		var spec: Array = _places()[place]
		var mark := PlaceMark.new()
		_style_mark(mark, empty)
		mark.position = spec[0] - Vector2(82, 23)
		mark.size = Vector2(164, 58)
		mark.glyph = spec[1]
		mark.caption = spec[2]
		mark.lettering = lab.serif
		mark.tooltip_text = place
		mark.pressed.connect(_select_place.bind(place))
		chart.add_child(mark)
		place_buttons[place] = mark
	for place: String in _places():
		var spec: Array = _places()[place]
		var mark := KinMark.new()
		_style_mark(mark, empty)
		mark.position = spec[0] + Vector2(21, -20)
		mark.size = PERSON_SIZE
		mark.lettering = lab.serif
		mark.pressed.connect(_select_kin.bind(place))
		chart.add_child(mark)
		kin_buttons[place] = mark

func _style_mark(button: Button, style: StyleBoxEmpty) -> void:
	for name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(name, style)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _select_place(place: String) -> void:
	chosen = place
	person_highlight = ""
	_refresh(true)
	if inside:
		focus_requested.emit(place, false)

func _look() -> void:
	if inside:
		focus_requested.emit(chosen, true)

func _select_kin(place: String) -> void:
	var members: Array = related.get(place, [])
	if members.size() == 1:
		person_selected.emit(members[0].id)
	elif not members.is_empty():
		chosen = place
		person_highlight = ""
		_refresh(true)
		person_buttons[members[0].id].grab_focus()
		place_list.ensure_control_visible(person_buttons[members[0].id])

func _person_place(id: String, seen: Dictionary) -> String:
	if id == Roster.APPRENTICE:
		return "Hearth" if inside else Land.HOME
	var place: String = seen.place
	if not inside and Land.INSIDE.has(place):
		return Land.HOME
	return place

func _index_people() -> void:
	related.clear()
	for id: String in family.known:
		var seen: Dictionary = family.known[id]
		var here := _person_place(id, seen)
		var destination: String = seen.get("destination", "")
		if _places().has(here):
			_add_kin(here, id, false)
		if not inside and not destination.is_empty() and destination != here:
			_add_kin(destination, id, true)

func _add_kin(place: String, id: String, travelling: bool) -> void:
	if not related.has(place):
		related[place] = []
	related[place].append({"id": id, "travelling": travelling})

func _person_uncertain(entry: Dictionary) -> bool:
	var seen: Dictionary = family.known[entry.id]
	return entry.id != Roster.APPRENTICE and (entry.travelling or seen.away or Land.stale(seen.seen, family.fire.time))

func update_map() -> void:
	if family == null:
		return
	var current := Vector2i(family.land.revision, family.knowledge_revision)
	if revision.y != current.y and not person_highlight.is_empty():
		var place := _linked_place(person_highlight)
		if place != chosen:
			mark_person(person_highlight)
			return
	if revision != current or family.fire.time >= next_fade:
		_refresh()

func _schedule_fade() -> void:
	# Reports age even if no new observation arrives.
	next_fade = INF
	for seen in family.known.values():
		_include_fade(seen.seen)
	for entries in family.land.places.values():
		for note in entries.values():
			_include_fade(note.seen)

func _include_fade(seen: float) -> void:
	var expires := seen + Land.FADING_AFTER
	if expires > family.fire.time:
		next_fade = minf(next_fade, expires)

func _refresh(reset_scroll := false) -> void:
	if family == null:
		return
	revision = Vector2i(family.land.revision, family.knowledge_revision)
	_schedule_fade()
	_index_people()
	for i in range(area_tabs.size()):
		area_tabs[i].set_pressed_no_signal(inside == (i == 1))
	chart.inside = inside
	chart.route = _known_route()
	chart.queue_redraw()
	for place: String in place_buttons:
		var mark := place_buttons[place]
		var weather: Dictionary = family.land.places.get(place, {}).get("weather", {})
		var reports: Dictionary = family.land.places.get(place, {})
		var event: Dictionary = reports.get("concern", reports.get("sign", reports.get("fuel", reports.get("finding", {}))))
		mark.selected = place == chosen
		mark.weather = weather.get("mark", "")
		mark.weather_old = not weather.is_empty() and Land.stale(weather.seen, family.fire.time)
		mark.event_mark = event.get("mark", "")
		mark.event_old = not event.is_empty() and Land.stale(event.seen, family.fire.time)
		mark.queue_redraw()
		var kin := kin_buttons[place]
		var members: Array = related.get(place, [])
		kin.count = members.size()
		kin.visible = kin.count > 0
		kin.uncertain = members.any(_person_uncertain)
		var names := PackedStringArray()
		for entry: Dictionary in members:
			names.append(Roster.person_name(entry.id))
		kin.tooltip_text = ", ".join(names)
		kin.queue_redraw()
	_write_notes(reset_scroll)

func _known_route() -> String:
	if inside:
		return ""
	if not person_highlight.is_empty():
		return family.known[person_highlight].get("destination", "")
	for member: Dictionary in related.get(chosen, []):
		if member.travelling:
			return chosen
	return ""

func _write_notes(reset_scroll: bool) -> void:
	var scroll := 0 if reset_scroll else place_list.scroll_vertical
	var focused := ""
	for id: String in person_buttons:
		if person_buttons[id].has_focus():
			focused = id
	for child in notes.get_children():
		notes.remove_child(child)
		child.queue_free()
	person_buttons.clear()
	var spec: Array = _places()[chosen]
	_add_words(spec[2] if inside else chosen, 24, lab.GOLD)
	_add_words(spec[3], 16, lab.TEXT)
	var reports: Dictionary = family.land.places.get(chosen, {})
	if not reports.has("weather") and not inside and chosen != Land.HOME:
		_add_words("No word of the weather here.", 14, lab.MUTED)
	var members: Array = related.get(chosen, [])
	if not reports.is_empty():
		_add_words("What you heard or saw", 15, lab.GOLD)
		for topic: String in reports:
			_add_report(reports[topic])
	elif members.is_empty():
		_add_words("No one has brought word from here yet.", 14, lab.MUTED)
	if not members.is_empty():
		_add_words("Kin remembered here", 15, lab.GOLD)
		for entry: Dictionary in members:
			_add_person(entry)
	look_button.visible = inside
	place_list.scroll_vertical = scroll
	if person_buttons.has(focused):
		person_buttons[focused].grab_focus()

func _add_person(entry: Dictionary) -> void:
	var id: String = entry.id
	var seen: Dictionary = family.known[id]
	var button: Button = lab._button(notes, Roster.person_name(id), Rect2(), person_selected.emit.bind(id))
	button.custom_minimum_size.y = 28
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.icon = Portraits.read(id)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 22)
	button.tooltip_text = "%s · %s" % [seen.source, Land.stamp(seen.seen)]
	if id == person_highlight:
		button.add_theme_color_override("font_color", lab.GOLD)
	person_buttons[id] = button
	var status := ""
	if id == Roster.APPRENTICE:
		status = "Your place at the hearth"
	elif entry.travelling:
		status = "Seen leaving · " + str(seen.get("purpose", "On the path"))
	else:
		status = ("Older sighting · " if Land.stale(seen.seen, family.fire.time) else "") + str(seen.activity)
	_add_words(status, 14, lab.MUTED)

func _add_report(note: Dictionary) -> void:
	var old := Land.stale(note.seen, family.fire.time)
	_add_words(note.text, 16, lab.MUTED if old else lab.TEXT)
	var line := ("Older report · " if old else "") + str(note.source) + " · " + Land.stamp(note.seen)
	if note.learned > note.seen:
		line += " · heard " + Land.stamp(note.learned)
	_add_words(line, 13, lab.MUTED)

func _add_words(words: String, points: int, color: Color) -> void:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", lab.serif)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", points)
	notes.add_child(label)
