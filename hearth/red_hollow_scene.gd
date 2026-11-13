extends Node3D
## Limestone and the woodpile ground treatment around the shared workbench.
const LIMESTONE := preload("res://hearth/limestone.gdshader")
const REAR_OFFSET := -1.85

var rock := Node3D.new()
var cliff := Node3D.new()
var interior := Node3D.new()
var stations := Node3D.new()
var rear_wall: MeshInstance3D
var random := RandomNumberGenerator.new()
var stone_material := ShaderMaterial.new()

func _ready() -> void:
	random.seed = 7021
	stone_material.shader = LIMESTONE
	add_child(rock)
	var strata := [Color("#51423a"), Color("#65574b"), Color("#827364"), Color("#706158")]
	for layer in range(8):
		for section in range(5):
			_slab(Vector3(-2.7 + section * 1.32 + random.randf_range(-0.18, 0.18), 0.13 + layer * 0.33, -3.40 + REAR_OFFSET),
				Vector3(random.randf_range(0.71, 0.98), 0.24, random.randf_range(0.31, 0.53)), strata[layer % strata.size()])
	for side in [-1.0, 1.0]:
		var shoulder: float = -3.12 if side < 0.0 else 2.37
		for layer in range(7):
			_slab(Vector3(shoulder + side * (0.03 * layer), 0.15 + layer * 0.34, -1.98 - layer * 0.074),
				Vector3(0.60, 0.28, 2.61 - layer * 0.095), strata[layer % strata.size()])
		_slab(Vector3(side * 3.28, 0.08, 0.35), Vector3(0.54, 0.18, 0.48), strata[0], true)
	_slab(Vector3(-0.38, 2.65, -1.23), Vector3(3.43, 0.36, 1.25), Color("#756758"))
	_slab(Vector3(-0.38, 3.02, -2.08), Vector3(3.40, 0.47, 1.55), Color("#918171"))
	_slab(Vector3(-0.28, 3.09, -3.64), Vector3(3.27, 0.49, 1.67), Color("#6c6054"))
	_wood_ground()
	# Continuous limestone behind the projecting beds keeps the shoulders
	# rooted and closes the small gaps between individually shaped strata.
	_slab(Vector3(-3.33, 1.37, -2.05), Vector3(0.62, 1.60, 2.82), strata[0])
	_slab(Vector3(2.58, 1.37, -2.05), Vector3(0.62, 1.60, 2.82), strata[0])
	_add_cliff()
	_add_deep_interior()

func _add_deep_interior() -> void:
	interior.name = "DeepInterior"
	stations.name = "ShelterStations"
	add_child(interior)
	add_child(stations)
	for layer in range(7):
		var y := 0.19 + layer * 0.33
		var strata := Color("#5d544a").lerp(Color("#82766b"), 0.28 + 0.26 * cos(layer * 2.2))
		_slab(Vector3(-3.02, y, -3.94 - layer * 0.06), Vector3(0.71, 0.25, 1.72), strata, false, interior)
		_slab(Vector3(2.22, y, -4.10 + 0.09 * sin(layer * 1.7)), Vector3(0.54, 0.25, 1.40), strata.darkened(0.12), false, interior)
	_slab(Vector3(-0.43, 2.66, -4.62), Vector3(3.12, 0.38, 1.42), Color("#665b51"), false, interior)
	_slab(Vector3(-0.33, 3.02, -5.17), Vector3(3.02, 0.48, 1.24), Color("#82766d"), false, interior)
	# Low borders mark the two dry bays without introducing a false support.
	for x in [-2.42, -1.39]:
		for z in [-3.51, -3.27, -2.52, -2.25]:
			_slab(Vector3(x, -0.026, z), Vector3(0.15, 0.08, 0.15), Color("#776756"), false, stations)
	for z in [-3.62, -3.44, -3.28]:
		_slab(Vector3(1.08, -0.01, z), Vector3(0.22, 0.12, 0.17), Color("#3d494b"), false, stations)
	_slab(Vector3(1.39, 0.38, -1.90), Vector3(0.27, 0.45, 0.35), Color("#66625a"), false, stations)

func align_floor() -> void:
	# The hearth is the floor coordinate origin even when a site choice
	# changes the shelter's depth relative to it.
	stations.position.z = -position.z

func _add_cliff() -> void:
	cliff.name = "LimestoneMassif"
	add_child(cliff)
	_slab(Vector3(-5.22, 1.88, -3.02), Vector3(2.16, 3.1, 4.14), Color("#574a40"), false, cliff)
	_slab(Vector3(4.53, 2.15, -3.10), Vector3(2.20, 3.50, 4.19), Color("#5e5043"), false, cliff)
	_slab(Vector3(-4.47, 4.13, -4.28), Vector3(3.19, 2.18, 3.53), Color("#76695a"), false, cliff)
	_slab(Vector3(3.77, 4.56, -4.68), Vector3(3.59, 2.23, 3.57), Color("#7a6a5b"), false, cliff)
	_slab(Vector3(-0.35, 4.37, -5.24), Vector3(4.09, 2.61, 2.78), Color("#6f6051"), false, cliff)
	_slab(Vector3(-0.94, 6.49, -5.89), Vector3(4.79, 2.38, 2.90), Color("#88796a"), false, cliff)
	_build_rear_wall()

func _build_rear_wall() -> void:
	# Join the rear and both returns continuously behind the projecting
	# limestone courses. The shoulders overlap the ends of the valley arc.
	var outline := [
		Vector2(-7.2, 0.65), Vector2(-6.2, -1.85), Vector2(-4.9, -3.51),
		Vector2(-3.4, -3.42), Vector2(-1.65, -3.23), Vector2(0.0, -3.19),
		Vector2(1.75, -3.15), Vector2(3.52, -3.45), Vector2(4.95, -3.49),
		Vector2(6.07, -1.75), Vector2(6.85, 0.65),
	]
	var courses := [-6.4, -0.42, 0.05, 0.53, 1.16, 1.77, 2.46, 3.16, 4.40, 6.90, 9.7]
	var strata := [Color("#453931"), Color("#57473d"), Color("#68574a"), Color("#51443b")]
	var depth := Vector3(0.0, 0.0, -4.05)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	for row in range(courses.size() - 1):
		for column in range(outline.size() - 1):
			var lower_left := _wall_point(outline[column], courses[row], row, column)
			var lower_right := _wall_point(outline[column + 1], courses[row], row, column + 1)
			var upper_left := _wall_point(outline[column], courses[row + 1], row + 1, column)
			var upper_right := _wall_point(outline[column + 1], courses[row + 1], row + 1, column + 1)
			var shade: Color = strata[row % strata.size()].darkened(random.randf_range(0.0, 0.15))
			_wall_quad(mesh, lower_left, upper_left, lower_right, upper_right, shade)
			# Give the massif a closed back and returns, including below the
			# shelf, where an oblique view can begin inside the near face.
			_wall_quad(mesh, lower_right + depth, upper_right + depth, lower_left + depth, upper_left + depth, shade)
			if column == 0:
				_wall_quad(mesh, lower_left + depth, upper_left + depth, lower_left, upper_left, shade)
			if column == outline.size() - 2:
				_wall_quad(mesh, lower_right, upper_right, lower_right + depth, upper_right + depth, shade)
			if row == 0:
				_wall_quad(mesh, lower_left + depth, lower_left, lower_right + depth, lower_right, shade)
			if row == courses.size() - 2:
				_wall_quad(mesh, upper_left, upper_left + depth, upper_right, upper_right + depth, shade)
	mesh.generate_normals()
	rear_wall = MeshInstance3D.new()
	rear_wall.name = "ContinuousRearFace"
	rear_wall.mesh = mesh.commit()
	rear_wall.material_override = stone_material
	rear_wall.position.z = REAR_OFFSET
	cliff.add_child(rear_wall)

func _wall_point(at: Vector2, height: float, row: int, column: int) -> Vector3:
	var seam := sin(column * 1.73 + row * 0.89)
	var face := cos(column * 1.20 - row * 1.93)
	return Vector3(at.x + face * 0.13, height + seam * 0.11, at.y + face * 0.22)

func _wall_quad(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, shade: Color) -> void:
	_triangle(mesh, a, b, c, shade)
	_triangle(mesh, c, b, d, shade.lightened(0.04))

func _slab(at: Vector3, span: Vector3, ink: Color, ground := false, parent: Node3D = null) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	var rings: Array[PackedVector3Array] = []
	var profile := [Vector2(0.74, -1.0), Vector2(1.0, -0.44), Vector2(0.97, 0.68), Vector2(0.68, 1.0)]
	var outline := PackedFloat32Array()
	for side in range(10):
		outline.append(random.randf_range(0.84, 1.18))
	for course in profile:
		var points := PackedVector3Array()
		for side in range(10):
			var angle := TAU * side / 10.0
			points.append(Vector3(cos(angle) * course.x * outline[side], course.y + random.randf_range(-0.17, 0.17),
				sin(angle) * course.x * outline[side]) * span)
		rings.append(points)
	for level in range(rings.size() - 1):
		for side in range(10):
			var next := (side + 1) % 10
			var shade := ink.darkened(random.randf_range(0.0, 0.17) + (0.10 if level == 0 else 0.0))
			_triangle(mesh, rings[level][side], rings[level + 1][side], rings[level][next], shade)
			_triangle(mesh, rings[level][next], rings[level + 1][side], rings[level + 1][next], shade)
	for side in range(1, 9):
		_triangle(mesh, rings[3][0], rings[3][side], rings[3][side + 1], ink.lightened(0.07))
		_triangle(mesh, rings[0][0], rings[0][side + 1], rings[0][side], ink.darkened(0.25))
	mesh.generate_normals()
	var slab := MeshInstance3D.new()
	slab.mesh = mesh.commit()
	slab.material_override = stone_material
	slab.position = at
	if parent != null:
		parent.add_child(slab)
	elif ground:
		add_child(slab)
	else:
		rock.add_child(slab)

func _triangle(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ink: Color) -> void:
	mesh.set_color(ink)
	mesh.add_vertex(a)
	mesh.add_vertex(b)
	mesh.add_vertex(c)

func _wood_ground() -> void:
	for edge in [-2.64, -1.28]:
		for index in range(5):
			_slab(Vector3(edge, 0.016, -1.62 + index * 0.36), Vector3(0.07, 0.034, 0.14), Color("#6e5944"), true)
