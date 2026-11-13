extends Control
## A technique painted on the same stone as the Mind Cave map.

const Mind := preload("res://hearth/mind_cave.gd")
const Fire := preload("res://sim/fire.gd")

class Drawing extends Control:
	func _draw() -> void:
		var ink := Mind.INK
		var ochre := Mind.OCHRE
		var points := [Vector2(112, 160), Vector2(298, 160), Vector2(495, 160)]
		Mind.Marks.paint(self, "wood", points[0] + Vector2(-22, -23), 1.65, ink)
		Mind.Marks.paint(self, "wood", points[0] + Vector2(20, 24), 1.50, ochre)
		Mind.Marks.paint(self, "tinder", points[1], 2.20, ink)
		Mind.Marks.paint(self, "tinder", points[2] + Vector2(0, 12), 1.75, ink)
		Mind.Marks.paint(self, "fire", points[2] + Vector2(0, -20), 1.35, ochre)
		for i in range(2):
			var start: Vector2 = points[i] + Vector2(61, 0)
			var finish: Vector2 = points[i + 1] - Vector2(58, 0)
			for dot in range(5):
				draw_circle(start.lerp(finish, dot / 4.0), 2.0, Color(ochre, 0.72), true, -1, true)

var lab: Control
var panel: Panel
var pickers: Array[OptionButton] = []
var work: Button
var finish_now: Button
var cancel: Button
var place: Button
var progress: ProgressBar
var status: Label
var stock_revision := -1
var fire: Fire

func build(owner: Control) -> void:
	lab = owner
	panel = lab._panel(Rect2(-528, -288, 1056, 576), lab.CENTER)
	panel.add_child(self)
	size = panel.size
	lab._label(self, "Crafting", Rect2(24, 15, 550, 45), 32, lab.GOLD, lab.serif)
	_button(self, "Close  [Esc]", Rect2(936, 23, 96, 32), lab._close_crafting)
	var stone := Mind.Stone.new()
	stone.plain = true
	stone.position = Vector2(24, 100)
	stone.size = Mind.MAP_SIZE
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stone.ensure_surface()
	add_child(stone)
	var drawing := Drawing.new()
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stone.add_child(drawing)
	stone_label(stone, "Tinder Bundle", Rect2(22, 16, 572, 45), 30)
	for i in range(3):
		var bounds := Rect2(21 + i * 191, 239, 191, 28)
		stone_label(stone, ["Choose two tinder parcels", "Work them loose", "Nestle the ember"][i], bounds, 17)
	stone_label(stone, "Keep the bundle loose so the glow can spread.", Rect2(30, 292, 556, 32), 18)
	var details := Panel.new()
	details.position = Vector2(658, 100)
	details.size = Vector2(374, 426)
	details.add_theme_stylebox_override("panel", lab._style(Color("#2c2118"), lab.LINE))
	add_child(details)
	lab._label(details, "Materials", Rect2(17, 12, 333, 34), 22, lab.GOLD, lab.serif)
	for i in range(2):
		lab._label(details, "Tinder %d" % (i + 1), Rect2(17, 53 + 58 * i, 84, 33), 15, lab.MUTED)
		var picker: OptionButton = lab._picker(details, Rect2(102, 53 + 58 * i, 254, 34), _selection_changed)
		picker.focus_mode = FOCUS_ALL
		pickers.append(picker)
	work = _button(details, "Work bundle · %.0f s" % Fire.TINDER_WORK_TIME, Rect2(17, 174, 339, 35), lab._start_crafting)
	progress = ProgressBar.new()
	progress.position = Vector2(17, 222)
	progress.size = Vector2(339, 10)
	progress.max_value = Fire.TINDER_WORK_TIME
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", lab._style(Color("#211811"), lab.LINE))
	progress.add_theme_stylebox_override("fill", lab._style(Color("#aa6032"), Color("#da9a64")))
	details.add_child(progress)
	status = lab._label(details, "", Rect2(17, 244, 339, 61), 16, lab.TEXT, lab.serif)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	finish_now = _button(details, "Wait for bundle", Rect2(17, 315, 208, 35), lab._wait_for_crafting)
	cancel = _button(details, "Stop work", Rect2(233, 315, 123, 35), lab._cancel_crafting)
	place = _button(details, "Take bundle to the hearth", Rect2(17, 315, 339, 35), lab._take_crafted_bundle)
	lab._label(self, "Time spent crafting also passes at the hearth.", Rect2(24, 480, 617, 30), 15, lab.MUTED)
	panel.hide()

func stone_label(parent: Control, words: String, bounds: Rect2, points: int) -> void:
	var label: Label = lab._label(parent, words, bounds, points, Mind.INK, lab.serif)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)

func _button(parent: Control, words: String, bounds: Rect2, action: Callable) -> Button:
	var button: Button = lab._button(parent, words, bounds, action)
	button.focus_mode = FOCUS_ALL
	return button

func refresh(model: Fire, force := false) -> void:
	if force or model != fire or model.storage_revision != stock_revision:
		var same_hearth := model == fire
		fire = model
		stock_revision = model.storage_revision
		_update_inputs(same_hearth)
	var working := not model.tinder_job.is_empty()
	var ready: Fire.Piece = lab._ready_bundle()
	for picker in pickers:
		picker.disabled = working
	progress.visible = working
	finish_now.visible = working
	cancel.visible = working
	place.visible = not working and ready != null
	work.disabled = working or not lab._can_start_crafting() or _choices_match()
	if working:
		var left := float(model.tinder_job.remaining)
		progress.value = Fire.TINDER_WORK_TIME - left
		status.text = "Working the tinder · %.1f s left" % left
	elif not lab.craft_notice.is_empty():
		status.text = lab.craft_notice
	elif ready != null:
		status.text = "A tinder bundle is ready."
	elif selected_input(0) < 0 or selected_input(1) < 0:
		status.text = "You need two separate parcels of tinder."
	else:
		status.text = "Bark fibres, dry grass, leaves and birch bark can be mixed."

func selected_input(index: int) -> int:
	var picker := pickers[index]
	return picker.get_selected_id() if picker.selected >= 0 else -1

func _choices_match() -> bool:
	return selected_input(0) < 0 or selected_input(1) < 0 or (selected_input(0) > 0 and selected_input(0) == selected_input(1))

func _selection_changed(_index: int) -> void:
	if fire != null:
		lab.craft_notice = ""
		refresh(fire)

func _update_inputs(keep_selection: bool) -> void:
	var available := fire.workable_tinder()
	for i in range(2):
		var picker := pickers[i]
		var previous := selected_input(i) if keep_selection else -1
		picker.clear()
		for piece in available:
			var label: String = Fire.SPECIES[piece.kind].label
			label += " · %.0f g" % (piece.wood * 1000.0)
			if piece.water / piece.original >= 0.24:
				label += " · damp"
			picker.add_item(label, piece.id)
		if fire.shelter == null:
			for kind: int in Fire.RAW_TINDER:
				picker.add_item(Fire.SPECIES[kind].label + " · practice", 100000 + kind)
		var selected := picker.get_item_index(previous) if previous >= 0 else -1
		if selected < 0 and picker.item_count > 0:
			selected = mini(i, picker.item_count - 1)
		picker.select(selected)
