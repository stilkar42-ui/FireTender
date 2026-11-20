extends Node3D
## Reusable storage display and picking: placements come from the fire's saved sites.
const Fire := preload("res://sim/fire.gd")
const Paint := preload("res://hearth/painted_material.gd")
const FOOTPRINT := Vector2(0.94, 0.72)
const TITLES := {"reserve": "DRY RESERVE", "drying": "DRYING RAILS"}
const GROUPS := ["Tinder", "Sticks", "Limbs"]
@export var ready_at := Vector2(-1.02, -0.68)
var fire: Fire
var signature := ""
var roots := {}
var slots := {}
var labels := {}
var highlights := {}
var hovered := ""

static func category(piece: Fire.Piece) -> int:
	if piece.kind in [0, 4, 5, 6, Fire.LEAVES, Fire.TINDER_BUNDLE]: return 0
	return 1 if piece.kind in [1, 7, 8] else 2

func sync(model: Fire) -> void:
	if fire != model:
		signature = ""
	fire = model
	var stamp := str(fire.storage_revision) + str(fire.storage_sites)
	if stamp == signature: return
	signature = stamp
	for zone in TITLES:
		if not roots.has(zone): _make_zone(zone)
		var at: Vector2 = fire.storage_sites[zone]
		roots[zone].position = Vector3(at.x, 0, at.y)
		var groups := [[], [], []]
		for piece in fire.bulk_pieces(zone): groups[category(piece)].append(piece)
		for group in 3:
			var key: String = zone + str(group)
			var visuals: Array = slots[key]
			var count := mini(groups[group].size(), 16)
			while visuals.size() < count:
				var limb := Node3D.new()
				roots[zone].add_child(limb)
				# Crooked natural wood, laid parallel in three readable bays.
				_beam(limb, Vector3(0, 0, -0.5), Vector3(0.025, 0.012, 0), 0.025, Color("#805e3d"))
				_beam(limb, Vector3(0.025, 0.012, 0), Vector3(0, 0, 0.5), 0.022, Color("#805e3d"))
				if visuals.size() % 4 == 0:
					_beam(limb, Vector3.ZERO, Vector3(0.11, 0.025, 0.28), 0.008, Color("#9a754c"))
				visuals.append(limb)
			for i in visuals.size():
				var limb: Node3D = visuals[i]
				limb.visible = i < count
				if i >= count: continue
				limb.position = Vector3((group - 1) * 0.29 + (i % 2 - 0.5) * 0.095,
					0.12 + (i / 2) * [0.022, 0.037, 0.052][group], sin(i * 1.9) * 0.012)
				limb.rotation.y = sin(i * 2.3) * 0.045
				limb.scale = Vector3([0.42, 0.72, 1.0][group], [0.35, 0.6, 0.85][group], [0.30, 0.49, 0.61][group])
		var total: int = groups[0].size() + groups[1].size() + groups[2].size()
		labels[zone].text = "%s · %d\nTinder %d   Sticks %d   Limbs %d" % [TITLES[zone], total, groups[0].size(), groups[1].size(), groups[2].size()]
		labels[zone].position = Vector3(0, 0.36, 0.30)
		# Bounded silhouettes represent large stocks; the exact count remains readable.
		for group in 3:
			for i in mini(groups[group].size(), 16):
				var limb: Node3D = slots[zone + str(group)][i]
				limb.position.y *= clampf(sqrt(groups[group].size() / 16.0), 1.0, 1.5)

func _make_zone(zone: String) -> void:
	var body := Node3D.new()
	add_child(body)
	roots[zone] = body
	for group in 3: slots[zone + str(group)] = []
	# Ground rails define the drop footprint and keep the bundles visibly off damp earth.
	for z in [-0.28, 0.28]:
		_beam(body, Vector3(-0.46, 0.075, z), Vector3(0.46, 0.075, z), 0.021, Color("#a08056"))
	for x in [-0.46, -0.145, 0.145, 0.46]:
		_beam(body, Vector3(x, 0.04, -0.32), Vector3(x, 0.16, -0.32), 0.018, Color("#98724b"))
	var label := Label3D.new()
	label.font_size = 26
	label.pixel_size = 0.00115
	label.outline_size = 7
	label.no_depth_test = true
	label.fixed_size = true
	label.modulate = Color("#f3d7a3")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.add_child(label)
	labels[zone] = label
	var mark := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = FOOTPRINT
	mark.mesh = plane
	var ink := StandardMaterial3D.new()
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.85, 0.66, 0.26, 0.35)
	mark.material_override = ink
	mark.position.y = 0.025
	mark.visible = false
	body.add_child(mark)
	highlights[zone] = mark

func _beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = a.distance_to(b)
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.radial_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = Paint.style(Paint.Surface.BARK, color)
	node.position = (a + b) * 0.5
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	parent.add_child(node)

func zone_at(bench, screen: Vector2) -> String:
	if fire == null or not is_visible_in_tree(): return ""
	var point: Vector3 = bench.ground_at(screen)
	if not point.is_finite(): return ""
	for zone in TITLES:
		var at: Vector2 = fire.storage_sites[zone]
		if Rect2(at - FOOTPRINT * 0.5, FOOTPRINT).has_point(Vector2(point.x, point.z)):
			return zone
	return ""

func highlight(zone: String) -> void:
	hovered = zone
	for key in highlights: highlights[key].visible = key == zone

func _ready() -> void:
	var tray := MeshInstance3D.new()
	var base := BoxMesh.new()
	base.size = Vector3(0.30, 0.018, 0.22)
	tray.mesh = base
	tray.position = Vector3(ready_at.x, 0.035, ready_at.y)
	tray.material_override = Paint.style(Paint.Surface.BARK, Color("#a27b4e"))
	add_child(tray)
	for z in [-0.11, 0.11]:
		_beam(self, tray.position + Vector3(-0.15, 0.025, z), tray.position + Vector3(0.15, 0.025, z), 0.015, Color("#8d673f"))


func keep_labels_in_view(camera: Camera3D, safe_area: Rect2) -> void:
	if camera == null: return
	for label: Label3D in labels.values():
		label.visible = not camera.is_position_behind(label.global_position) and safe_area.has_point(camera.unproject_position(label.global_position))
