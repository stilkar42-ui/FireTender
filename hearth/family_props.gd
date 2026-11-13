extends Node3D
## The geometry renders the workshop's physical objects, one root per id.

const Family := preload("res://sim/red_hollow_family.gd")
const Work := Family.Workshop
const Worker := preload("res://hearth/family_worker.gd")
const GOLD := Color("#d5a66d")
const HEIGHTS := {Work.HUNTER: 0.147, Work.COOK: 0.104, Work.MAKER: 0.19, Work.STORE: 0.145, Work.HIDE_RACK: 0.15}
const TEACHER_AT := {
	Work.HUNTER: Vector2(1.01, -1.89),
	Work.COOK: Vector2(-1.24, 0.70),
	Work.MAKER: Vector2(-0.61, -2.23),
}
const STYLES := {
	"carcass": [Vector3(0.245, 0.105, 0.17), "#913f32"],
	"meat": [Vector3(0.090, 0.034, 0.060), "#b65543"],
	"marrow": [Vector3(0.046, 0.016, 0.032), "#d1af78"],
	"bone": [Vector3(0.135, 0.027, 0.031), "#c5ae87"],
	"spent_bone": [Vector3(0.104, 0.021, 0.028), "#b49c79"],
	"bone_shard": [Vector3(0.058, 0.021, 0.043), "#c3a987"],
	"hide": [Vector3(0.145, 0.019, 0.099), "#87534b"],
	"clean_hide": [Vector3(0.149, 0.012, 0.104), "#bd9368"],
	"fat": [Vector3(0.061, 0.022, 0.057), "#ddc18a"],
	"trim": [Vector3(0.058, 0.019, 0.038), "#633a31"],
	"binding": [Vector3(0.073, 0.012, 0.028), "#a96f45"],
	"knot": [Vector3(0.065, 0.030, 0.043), "#784a2b"],
	"resin": [Vector3(0.044, 0.020, 0.035), "#b17032"],
	"pitch": [Vector3(0.043, 0.013, 0.033), "#64402b"],
	"ruined_pitch": [Vector3(0.041, 0.017, 0.032), "#342927"],
	"point": [Vector3(0.063, 0.015, 0.028), "#879294"],
	"shaft": [Vector3(0.185, 0.012, 0.018), "#a9815a"],
	"scrap": [Vector3(0.071, 0.024, 0.047), "#785437"],
	"roots": [Vector3(0.081, 0.023, 0.055), "#aa8750"],
	"flake": [Vector3(0.060, 0.014, 0.035), "#aca59a"],
	"scraper": [Vector3(0.058, 0.025, 0.047), "#877f76"],
	"hammer": [Vector3(0.070, 0.049, 0.065), "#77716b"],
	"vessel": [Vector3(0.073, 0.035, 0.060), "#9c856c"],
}
const FOOD_INK := {"Raw": "#b65543", "Undercooked": "#9d583e", "Dried": "#ad7651",
	"Roasted": "#744532", "Overcooked": "#51372c", "Charred": "#282221"}
var model: Work
var family: Family
var roast: Node3D
var cup: Node3D
var contents: MeshInstance3D
var traces: Node3D
var spears: Dictionary[String, Node3D] = {}
var labels: Dictionary[String, Label3D] = {}
var targets: Array[Label3D] = []
var items: Dictionary[int, Node3D] = {}
var actors: Dictionary[String, Worker] = {}
var camera: Camera3D
var vessel_layers: Dictionary[int, MeshInstance3D] = {}
var animated_ids: Dictionary = {}
var second_spit: Node3D
var revision := -1
var held_preview := Vector3.INF

func _ready() -> void:
	hide()
	var cook := _area(Work.COOK, Work.COOK_AT)
	_slab(cook, Vector3(0, 0.046, 0), Vector3(0.32, 0.065, 0.28), "#736051")
	_slab(cook, Vector3(0, 0.105, 0.01), Vector3(0.28, 0.020, 0.25), "#9a7254")
	var hunter := _area(Work.HUNTER, Work.HUNTER_AT)
	_slab(hunter, Vector3(0, 0.062, 0), Vector3(0.39, 0.08, 0.34), "#6a5647")
	_slab(hunter, Vector3(0.02, 0.139, 0), Vector3(0.36, 0.017, 0.31), "#9e7958")
	traces = Node3D.new()
	hunter.add_child(traces)
	_slab(traces, Vector3(0.04, 0.155, -0.02), Vector3(0.196, 0.002, 0.114), "#704338")
	_slab(traces, Vector3(-0.13, 0.155, 0.10), Vector3(0.10, 0.002, 0.058), "#815041")
	var rack_at := Vector3(Work.RACK_AT.x, 0.035, Work.RACK_AT.y)
	for z in [-0.22, 0.19]:
		_beam(self, rack_at + Vector3(-0.18, 0, z), rack_at + Vector3(0.18, 0, z), 0.022, "#775940")
	var maker := _area(Work.MAKER, Work.MAKER_AT)
	_slab(maker, Vector3(0, 0.095, 0), Vector3(0.36, 0.11, 0.30), "#77706a")
	var stored := _area(Work.STORE, Work.STORE_AT)
	_slab(stored, Vector3(0, 0.06, 0), Vector3(0.28, 0.074, 0.24), "#826349")
	_slab(stored, Vector3(0, 0.139, 0), Vector3(0.25, 0.022, 0.21), "#ac8861")
	var rack := _area(Work.HIDE_RACK, Work.HIDE_AT)
	for z in [-0.17, 0.16]:
		_beam(rack, Vector3(-0.28, 0.15, z), Vector3(0.26, 0.15, z), 0.017, "#8f6f4e")
	for x in [-0.24, 0.23]:
		_beam(rack, Vector3(x, 0.14, -0.2), Vector3(x, 0.14, 0.2), 0.017, "#8f6f4e")
	roast = Node3D.new()
	add_child(roast)
	_beam(roast, Vector3(-0.17, 0.19, 0), Vector3(0.18, 0.19, 0), 0.009, "#b38657")
	for x in [-0.13, 0.13]:
		_beam(roast, Vector3(x, 0.02, 0.025), Vector3(x, 0.18, 0), 0.009, "#90643d")
	for i in range(Work.GEAR_IDS.size()):
		var id: String = Work.GEAR_IDS[i]
		var spear := Node3D.new()
		add_child(spear)
		_beam(spear, Vector3(0, 0.025, 0.31), Vector3(0, 0.04, -0.33), 0.013, "#946949")
		_slab(spear, Vector3(0, 0.04, -0.355), Vector3(0.034, 0.020, 0.063), "#a2a8a3")
		_slab(spear, Vector3(0, 0.044, -0.290), Vector3(0.020, 0.013, 0.038), "#bb9573")
		spears[id] = spear
		items[-1 - i] = spear
	for i in range(2):
		targets.append(_name(Work.ROAST_RESTS[i], Work.ROAST_POSITIONS[i], 0.16, 0.0013))
	for i in range(Work.RESIN_RESTS.size()):
		targets.append(_name(Work.RESIN_RESTS[i], Work.RESIN_POSITIONS[i], 0.095, 0.0013))
	second_spit = roast.duplicate() as Node3D
	add_child(second_spit)
	for pair in [["bera", Work.HUNTER], ["mira", Work.HUNTER], ["nara", Work.COOK], ["ina", Work.MAKER]]:
		_actor(pair[0], pair[1])

func _actor(id: String, rest: String) -> void:
	var body := Worker.new()
	add_child(body)
	var at: Vector2 = TEACHER_AT[rest]
	body.position = Vector3(at.x, 0.01, at.y)
	body.heading = (Work.STATIONS[rest] - at).normalized()
	body.build(id)
	actors[id] = body

func _area(name_text: String, at: Vector2) -> Node3D:
	var area := Node3D.new()
	area.position = Vector3(at.x, 0, at.y)
	add_child(area)
	labels[name_text] = _name(name_text, at, 0.38, 0.00175)
	return area

func _name(words: String, at: Vector2, height: float, pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.pixel_size = pixel
	label.font_size = 32
	label.outline_size = 8
	label.modulate = GOLD
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(at.x, height, at.y)
	add_child(label)
	return label

func _material(color: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 1.0
	return mat

func _slab(parent: Node3D, at: Vector3, extent: Vector3, color: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 3
	var prop := MeshInstance3D.new()
	prop.mesh = mesh
	prop.material_override = _material(color)
	prop.position = at
	prop.scale = extent
	parent.add_child(prop)
	return prop

func _beam(parent: Node3D, from: Vector3, to: Vector3, radius: float, color: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.78
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 5
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = _material(color)
	beam.position = (from + to) / 2.0
	beam.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	parent.add_child(beam)
	return beam

func show_workshop(workshop: Work, household: Family = null) -> void:
	if workshop != model:
		_clear_items()
		model = workshop
		revision = -1
		held_preview = Vector3.INF
		visible = model != null
	family = household
	if model == null:
		return
	if model.revision != revision:
		revision = model.revision
		_sync_items()
	_update_hot_items()
	_update_people()

func _clear_items() -> void:
	for id: int in items.keys():
		if id > 0:
			remove_child(items[id])
			items[id].queue_free()
			items.erase(id)
	vessel_layers.clear()
	animated_ids.clear()

func _sync_items() -> void:
	for id: int in items.keys():
		if id > 0 and not model.parcels.has(id):
			remove_child(items[id])
			items[id].queue_free()
			items.erase(id)
	for parcel in model.parcels.values():
		var item: Node3D = items.get(parcel.id)
		if item == null or item.get_meta("kind", "") != parcel.kind:
			if item != null:
				remove_child(item)
				item.queue_free()
			item = _new_item(parcel)
			items[parcel.id] = item
		_pose_item(item, parcel)
	for id: String in spears:
		var tool: Dictionary = model.gear[id]
		var spear := spears[id]
		spear.visible = tool.at in [Work.HUNTER, Work.MAKER, Work.COOK, Work.STORE, Work.HIDE_RACK, Work.FLOOR, Work.HAND]
		var at: Vector2 = tool.point
		var height := 0.048 if tool.at == Work.HUNTER and at.distance_to(Work.RACK_AT) < 0.25 else _height(tool.at, at)
		spear.position = Vector3(at.x, height, at.y)
		spear.rotation.y = tool.yaw
		spear.get_child(1).rotation.z = 0.0 if tool.condition >= 0.67 else 0.18
	traces.visible = not model.stock("trim", Work.HUNTER).is_empty()
	for i in range(targets.size()):
		targets[i].visible = model.held == model.cup_id if i >= 2 else (
			model.held > 0 and model.parcels[model.held].kind in ["meat", "marrow"] and model.parcels[model.held].grams <= 180)
	_sync_hand()

func _new_item(parcel: Work.Parcel) -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", parcel.kind)
	add_child(root)
	var spec: Array = STYLES[parcel.kind]
	var extent: Vector3 = spec[0]
	_slab(root, Vector3(0, extent.y, 0), extent, spec[1])
	match parcel.kind:
		"carcass":
			_slab(root, Vector3(0.03, 0.166, 0.025), Vector3(0.182, 0.034, 0.087), "#bd755b")
			_slab(root, Vector3(0.179, 0.105, -0.067), Vector3(0.101, 0.031, 0.035), "#cdb08c")
		"bone", "spent_bone":
			for end in [-1, 1]:
				_slab(root, Vector3(extent.x * end * 0.76, extent.y, 0), extent * Vector3(0.25, 1.2, 1.65), "#d1b995")
		"bone_shard":
			for offset in [Vector3(-0.052, 0.009, 0.030), Vector3(0.037, 0.012, -0.045)]:
				_slab(root, offset, Vector3(0.024, 0.014, 0.023), "#d1b995")
		"vessel":
			_slab(root, Vector3(0, 0.054, 0), Vector3(0.055, 0.008, 0.046), "#443831")
			var fill := _slab(root, Vector3(0, 0.062, 0), Vector3(0.047, 0.009, 0.038), "#b87f37")
			vessel_layers[parcel.id] = fill
			fill.hide()
			if parcel.id == model.cup_id:
				contents = fill
				cup = root
	return root

func _pose_item(item: Node3D, parcel: Work.Parcel) -> void:
	item.visible = parcel.id != model.cup_fill and (parcel.rest != Work.KIN_CUP or parcel.id == model.kin_cup_id)
	item.rotation.y = parcel.yaw
	var height := _height(parcel.rest, parcel.at)
	if parcel.rest == Work.HIDE_RACK and parcel.kind == "clean_hide":
		item.scale = Vector3(1.64, 1, 1.43)
	elif parcel.kind == "carcass":
		var size_factor := clampf(pow(parcel.grams / 1080.0, 0.32), 0.47, 1.52)
		item.scale = Vector3.ONE * size_factor
	elif parcel.kind in ["meat", "hide", "clean_hide"]:
		item.scale = Vector3.ONE * clampf(pow(parcel.grams / 160.0, 0.25), 0.64, 1.55)
	if parcel == model.roast or parcel.rest == Work.KIN_SPIT:
		var extent: Vector3 = STYLES[parcel.kind][0]
		height = 0.18 + extent.y * item.scale.y * 2.0 * parcel.face
		item.rotation.z = PI * parcel.face
	else:
		item.rotation.z = 0.0
	item.position = Vector3(parcel.at.x, height, parcel.at.y)
	if parcel.kind in ["meat", "marrow"]:
		item.get_child(0).material_override.albedo_color = Color("#4c5042" if parcel.freshness <= 0.0 else FOOD_INK[parcel.condition()])
	elif parcel.prepared and parcel.kind in ["point", "shaft"]:
		item.get_child(0).material_override.albedo_color = Color("#a7b4b0" if parcel.kind == "point" else "#b99a72")

func _height(rest: String, at: Vector2) -> float:
	if rest == Work.IN_TRANSIT:
		return 0.54
	if Work.SURFACES.has(rest):
		var centre: Vector2 = Work.SURFACES[rest]
		if at.distance_to(centre) <= 0.43:
			return HEIGHTS[rest]
	return 0.0

func _update_hot_items() -> void:
	roast.visible = model.roast != null
	if roast.visible:
		var parcel := model.roast
		roast.position = Vector3(parcel.at.x, 0, parcel.at.y)
		_pose_item(items[parcel.id], parcel)
	if cup != null:
		contents.visible = model.cup_fill != 0
		if contents.visible:
			contents.material_override.albedo_color = Color("#382b24" if model.resin.scorched >= 1.0 else (
				"#d6a053" if model.resin.temperature >= 68.0 else "#ad763c"))
	_sync_hand()

func _update_people() -> void:
	if family == null or camera == null:
		return
	var teacher := family.instructor(Work.HUNTER)
	var hunt_job: Dictionary = family.craft.jobs.get(Work.HUNTER, {})
	var cook_job: Dictionary = family.craft.jobs.get(Work.COOK, {})
	var maker_job: Dictionary = family.craft.jobs.get(Work.MAKER, {})
	actors.bera.visible = (teacher == "bera" or family.transfer.get("person", "") == "bera") and not family.people.bera.away
	actors.mira.visible = teacher == "mira" and not family.people.mira.away
	actors.nara.visible = not family.people.nara.away
	actors.ina.visible = not family.people.ina.away
	_worker_pose("bera", Work.HUNTER, hunt_job)
	_worker_pose("mira", Work.HUNTER, hunt_job)
	_worker_pose("nara", Work.COOK, cook_job)
	_worker_pose("ina", Work.MAKER, maker_job)
	if not family.transfer.is_empty():
		var parcel: Work.Parcel = model.parcels.get(family.transfer.id)
		if parcel != null:
			_pose_item(items[parcel.id], parcel)
			var carrier: String = family.transfer.person
			if actors.has(carrier):
				var actor := actors[carrier]
				actor.position = Vector3(parcel.at.x - 0.08, 0.025, parcel.at.y - 0.15)
				actor.carry_at(model.fire.time, 0.56, (family.transfer.to - family.transfer.from).normalized(), camera)
	second_spit.visible = cook_job.get("phase") == "warming"
	if second_spit.visible:
		var cut := model.parcels[int(cook_job.id)]
		second_spit.position = Vector3(cut.at.x, 0, cut.at.y)
		_pose_item(items[cut.id], cut)
	var fill: MeshInstance3D = vessel_layers.get(model.kin_cup_id)
	if fill != null:
		fill.visible = maker_job.get("phase") == "warming"
		if fill.visible:
			var pitch := model.parcels[int(maker_job.id)]
			fill.material_override.albedo_color = Color("#d39b50" if pitch.temperature > 68.0 else "#a9743d")
	_animate_work_objects()

func _worker_pose(id: String, area: String, job: Dictionary) -> void:
	var body := actors[id]
	if not body.visible:
		return
	var spot: Vector2 = TEACHER_AT[area]
	if area in [Work.COOK, Work.MAKER] and job.get("phase") == "warming" and model.parcels.has(job.id):
		spot = model.parcels[int(job.id)].at + (Vector2(0.25, 0.45) if area == Work.COOK else Vector2(0.32, 0.19))
	body.position = Vector3(spot.x, 0.01, spot.y)
	if not camera.is_position_in_frustum(body.position + Vector3.UP * 0.40):
		return
	var light := clampf(model.fire.shelter.light * 0.48 + model.fire.heat_at(spot) * 0.84 + 0.32, 0.0, 1.0)
	var helper: Dictionary = family.craft.helper
	var coaching: bool = helper.get("mode") == "supervised" and helper.get("teacher") == id \
		and model.fire.time - helper.get("began", 0.0) < 1.25
	body.pose_at(camera, job if job.get("worker") == id else {}, model.fire.time, light, coaching)

func _animate_work_objects() -> void:
	for id: int in animated_ids:
		if items.has(id) and model.parcels.has(id):
			_pose_item(items[id], model.parcels[id])
		elif id < 0 and items.has(id):
			var gear: Dictionary = model.gear[model.gear_name(id)]
			var at: Vector2 = gear.point
			items[id].position = Vector3(at.x, _height(gear.at, at), at.y)
			items[id].rotation.z = 0.0
	animated_ids.clear()
	for job: Dictionary in family.craft.jobs.values():
		if job.phase != "preparing" or not items.has(job.id):
			continue
		var id: int = job.id
		if not job.parts.is_empty() and not job.prepared:
			id = job.parts[0] if job.progress < 3.5 else job.parts[1]
		var item := items[id]
		if not camera.is_position_in_frustum(item.position):
			continue
		var stroke := sin(float(job.progress) * 5.1)
		item.position.y += maxf(0.0, stroke) * (0.025 if job.kind == "carve" else 0.054)
		item.rotation.z = stroke * 0.077
		animated_ids[id] = true
		var tool: int = job.get("tool", 0)
		if tool != 0 and items.has(tool) and model.parcels.has(tool):
			items[tool].position = item.position + Vector3(0.075, 0.06 + maxf(0.0, -stroke) * 0.10, -0.065)
			items[tool].rotation.z = stroke * 0.46
			animated_ids[tool] = true

func pointer_item(bench, point: Vector2) -> int:
	if model == null:
		return 0
	var pixel: Vector2 = point * bench.raster_scale
	var origin: Vector3 = bench.camera.project_ray_origin(pixel)
	var direction: Vector3 = bench.camera.project_ray_normal(pixel)
	var best := INF
	var id_found := 0
	for id: int in items:
		var item := items[id]
		if not item.visible or id == model.held:
			continue
		var shape: Vector3
		if id < 0:
			shape = Vector3(0.040, 0.046, 0.39)
		else:
			shape = STYLES[model.parcels[id].kind][0] * item.scale + Vector3(0.012, 0.014, 0.012)
		var local := item.global_basis.orthonormalized().transposed()
		var at := item.global_position + Vector3.UP * shape.y * 0.75
		var contact: Variant = AABB(-shape, shape * 2).intersects_ray(local * (origin - at), local * direction)
		if contact is Vector3:
			var distance: float = contact.distance_to(local * (origin - at))
			if distance < best:
				best = distance
				id_found = id
	return id_found

func teacher_at(bench, screen: Vector2) -> String:
	if family == null:
		return ""
	for rest: String in TEACHER_AT:
		var id := family.instructor(rest)
		if id.is_empty():
			continue
		var body := actors[id]
		var projected: Vector2 = bench.project(Vector3(body.position.x, body.position.z, 0.55))
		if screen.distance_to(projected) < 35.0:
			return rest
	return ""

func destination(bench, screen: Vector2) -> Dictionary:
	var pixel: Vector2 = screen * bench.raster_scale
	var origin: Vector3 = bench.camera.project_ray_origin(pixel)
	var ray: Vector3 = bench.camera.project_ray_normal(pixel)
	if ray.y >= -0.001:
		return {}
	for i in range(targets.size()):
		if not targets[i].visible:
			continue
		var label := targets[i]
		var at := Vector2(label.position.x, label.position.z)
		var point: Vector2 = bench.project(Vector3(at.x, at.y, label.position.y))
		if screen.distance_to(point) < 25.0:
			return {"at": at, "rest": Work.SPIT if i < 2 else Work.CUP, "heat": i if i < 2 else i - 2}
	for rest: String in Work.SURFACES:
		var height: float = HEIGHTS[rest]
		var intersection := origin + ray * ((height - origin.y) / ray.y)
		var at := Vector2(intersection.x, intersection.z)
		var centre: Vector2 = Work.SURFACES[rest]
		if centre.distance_to(at) <= (0.37 if rest == Work.HUNTER else 0.28):
			return {"at": at, "rest": rest, "heat": -1}
	var floor_at: Vector3 = bench.ground_at(screen)
	if floor_at.is_finite():
		var at := Vector2(floor_at.x, floor_at.z)
		var rest := Work.HUNTER if model.held < 0 and at.distance_to(Work.RACK_AT) <= 0.27 else Work.FLOOR
		return {"at": at, "rest": rest, "heat": -1}
	return {}

func preview(bench, screen: Vector2) -> void:
	held_preview = Vector3.INF
	if model == null or model.held == 0:
		return
	var target := destination(bench, screen)
	if not target.is_empty():
		var at: Vector2 = target.at
		held_preview = Vector3(at.x, _height(target.rest, at) + 0.16, at.y)
	_sync_hand()

func _sync_hand() -> void:
	if model.held == 0 or not items.has(model.held):
		return
	var item := items[model.held]
	item.visible = held_preview.is_finite()
	if item.visible:
		item.position = held_preview
