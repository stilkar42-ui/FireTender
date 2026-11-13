extends Node3D
## Limestone and the woodpile ground treatment around the shared workbench.
const LIMESTONE := preload("res://hearth/limestone.gdshader")
const Paint := preload("res://hearth/painted_material.gd")
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
	Paint.bind_brush(stone_material, "limestone", 1.0, 0.39)
	rock.name = "LimestoneShell"
	add_child(rock)
	rock.add_child(_shelter_shell())
	_wood_ground()
	_add_cliff()
	_add_deep_interior()

func _shelter_shell() -> MeshInstance3D:
	# The wall foot, arch and rear close around the existing camera bounds.
	# These sections are visible scenery and carry no collision.
	const DEPTHS := [0.91, 0.49, -0.07, -0.72, -1.37, -2.08, -2.86, -3.64, -4.42, -4.98, -5.34]
	const SIDES := 38
	var rows: Array[PackedVector3Array] = []
	var color_rows: Array[PackedColorArray] = []
	for row in range(DEPTHS.size()):
		var z: float = DEPTHS[row]
		var ring := PackedVector3Array()
		var ink := PackedColorArray()
		for side in range(SIDES + 1):
			var angle := PI * side / SIDES
			var crown := sin(angle)
			var wall := cos(angle)
			var radius := lerpf(2.52, 2.78, smoothstep(-3.9, 0.91, z))
			var rumple := sin(angle * 9.0 + z * 1.1) * 0.066 + cos(angle * 17.0 - z * 1.7) * 0.047
			var bedding := sin(crown * 15.0 + z * 0.83 + wall) * 0.09
			var headroom := 2.62 + 0.18 * sin(z * 1.1) + 0.14 * smoothstep(-0.8, 0.86, z)
			var x := -0.31 + wall * (radius + rumple + bedding)
			var y := -0.17 + pow(crown, 0.63) * (headroom + rumple + bedding)
			var shelf := (sin(angle * 14.0 + z) * 0.065 + sin(z * 3.0 + angle * 5.4) * 0.042)
			ring.append(Vector3(x, y, z + shelf))
			var shade := 0.40 + 0.17 * sin(crown * 13.0 + z * 0.69) + 0.14 * sin(angle * 6.0 - z * 1.4)
			var tint := Color("#65594e").lerp(Color("#a4927c"), shade)
			var back := 1.0 - smoothstep(-5.15, -0.58, z)
			tint = tint.lerp(Color("#5b5753"), back * 0.47)
			ink.append(tint)
		rows.append(ring)
		color_rows.append(ink)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows.size() - 1):
		for side in range(SIDES):
			for key in [Vector2i(row, side), Vector2i(row, side + 1), Vector2i(row + 1, side),
					Vector2i(row + 1, side), Vector2i(row, side + 1), Vector2i(row + 1, side + 1)]:
				mesh.set_color(color_rows[key.x][key.y])
				mesh.add_vertex(rows[key.x][key.y])
	mesh.generate_normals()
	var skin := MeshInstance3D.new()
	skin.name = "ContinuousLimestone"
	skin.mesh = mesh.commit()
	skin.material_override = stone_material
	return skin

func _add_deep_interior() -> void:
	interior.name = "DeepInterior"
	stations.name = "ShelterStations"
	add_child(interior)
	add_child(stations)
	# Low limestone shelves break the long wall and mark the wet and dry bays.
	_slab(Vector3(-2.74, 0.21, -3.82), Vector3(0.28, 0.27, 0.88), Color("#7a6d60"), false, interior)
	_slab(Vector3(-2.83, 0.61, -2.74), Vector3(0.27, 0.19, 0.72), Color("#857361"), false, interior)
	_slab(Vector3(2.03, 0.27, -3.82), Vector3(0.32, 0.31, 0.98), Color("#6a6a60"), false, interior)
	_slab(Vector3(2.12, 0.53, -2.72), Vector3(0.28, 0.19, 0.64), Color("#726b60"), false, interior)

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
	for row in range(courses.size() - 1):
		for column in range(outline.size() - 1):
			var lower_left := _wall_point(outline[column], courses[row], row, column)
			var lower_right := _wall_point(outline[column + 1], courses[row], row, column + 1)
			var upper_left := _wall_point(outline[column], courses[row + 1], row + 1, column)
			var upper_right := _wall_point(outline[column + 1], courses[row + 1], row + 1, column + 1)
			var shade: Color = strata[row % strata.size()].darkened(random.randf_range(0.0, 0.055))
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
	_triangle(mesh, c, b, d, shade)

func _slab(at: Vector3, span: Vector3, ink: Color, ground := false, parent: Node3D = null) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
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
			var shade := ink.darkened(0.05 + 0.018 * sin(side * 1.7))
			_triangle(mesh, rings[level][side], rings[level + 1][side], rings[level][next], shade)
			_triangle(mesh, rings[level][next], rings[level + 1][side], rings[level + 1][next], shade)
	for side in range(1, 9):
		_triangle(mesh, rings[3][0], rings[3][side], rings[3][side + 1], ink.lightened(0.03))
		_triangle(mesh, rings[0][0], rings[0][side + 1], rings[0][side], ink.darkened(0.07))
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
