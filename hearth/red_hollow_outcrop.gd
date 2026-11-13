extends Node3D
## The open limestone shelf beyond the level working floor.
const LIMESTONE := preload("res://hearth/limestone.gdshader")
const Paint := preload("res://hearth/painted_material.gd")
const WIDTHS := [-6.72, -5.29, -3.78, -2.52, -1.40, -0.41, 0.68, 1.71, 3.05, 4.32, 6.10]
const DEPTHS := [-0.85, 0.45, 1.29, 2.03, 2.86, 3.76, 4.66, 5.55, 6.45, 7.42, 8.35]
const HEIGHTS := [-0.73, -0.34, -0.06, -0.10, -0.16, -0.23, -0.34, -0.49, -0.84, -1.79, -3.15]
const ROCK := Color("#6d6256")
const DUST := Color("#67543f")
const CREVICE := Color("#493e33")

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 42051
	var limestone := ShaderMaterial.new()
	limestone.shader = LIMESTONE
	Paint.bind_brush(limestone, "limestone", 0.72, 0.29)
	_add_mesh("LimestoneShelf", _shelf(), limestone)
	var plants := Paint.style(Paint.Surface.ORGANIC, Color("#a7ac92"), true)
	_add_mesh("PinesAndScrub", _vegetation(), plants)

func _height(x: float, z: float) -> float:
	var index := 1
	while index < DEPTHS.size() - 1 and z > DEPTHS[index]:
		index += 1
	var weight := inverse_lerp(DEPTHS[index - 1], DEPTHS[index], z)
	var base := lerpf(HEIGHTS[index - 1], HEIGHTS[index], clampf(weight, 0.0, 1.0))
	var shoulders := smoothstep(1.3, 6.1, absf(x))
	var split := sin(x * 1.97 + z * 1.41) * 0.62 + cos(z * 2.43 - x * 0.63) * 0.38
	var chips := sin(x * 5.11 + z * 6.22) * 0.048
	return base + shoulders * (0.18 + 0.34 * split) + (split * 0.11 + chips) * smoothstep(1.30, 3.7, z)

func _shelf() -> SurfaceTool:
	var mesh := _surface()
	var rows: Array[PackedVector3Array] = []
	var row_count := DEPTHS.size() * 2 - 1
	var column_count := WIDTHS.size() * 2 - 1
	for row in range(row_count):
		var points := PackedVector3Array()
		for column in range(column_count):
			var x := _subdivide(WIDTHS, column) + 0.12 * sin(row * 1.72 + column * 2.28)
			var z := _subdivide(DEPTHS, row) + (0.03 if row < 5 else 0.14) * sin(row * 0.79 + column * 1.77)
			points.append(Vector3(x, _height(x, z), z))
		rows.append(points)
	for row in range(rows.size() - 1):
		for column in range(column_count - 1):
			var a := rows[row][column]
			var b := rows[row][column + 1]
			var c := rows[row + 1][column]
			var d := rows[row + 1][column + 1]
			var seam := rng.randf_range(0.0, 0.04)
			var path := 1.0 - smoothstep(0.45, 2.30, absf((a.x + d.x) * 0.5))
			var ink := ROCK.lerp(DUST, path * 0.65).darkened(seam)
			_face(mesh, a, b, c, ink)
			_face(mesh, c, b, d, ink)
		_edge(mesh, rows[row + 1][0], rows[row][0], -1.0)
		_edge(mesh, rows[row][-1], rows[row + 1][-1], 1.0)
	for column in range(column_count - 1):
		_edge(mesh, rows[-1][column + 1], rows[-1][column], 0.0)
	for crag: Vector3 in [
		Vector3(-3.30, 0.86, 1.76), Vector3(2.61, 0.69, 1.92),
		Vector3(-2.22, 0.43, 3.56), Vector3(1.97, 0.36, 4.52),
		Vector3(-4.62, 1.06, 4.27), Vector3(3.88, 0.83, 5.14),
		Vector3(-1.75, 0.57, 6.36), Vector3(2.32, 0.71, 6.81),
	]:
		var span := Vector3(crag.y * 1.33, crag.y * 0.51, crag.y * 0.77)
		_crown(mesh, _root(crag.x, crag.z) + Vector3.UP * 0.20, span, ROCK.darkened(0.08))
		_crown(mesh, _root(crag.x - span.x * 0.62, crag.z + span.z * 0.59), span * 0.56, CREVICE.lightened(0.16))
	for index in range(35):
		var x := rng.randf_range(-4.7, 4.7)
		var z := rng.randf_range(1.66, 7.30)
		var span := rng.randf_range(0.05, 0.19)
		_crown(mesh, _root(x, z) + Vector3.UP * 0.10, Vector3(span, span * 0.55, span * 0.78), ROCK)
	return mesh

func _subdivide(values: Array, index: int) -> float:
	var base := index >> 1
	return values[base] if index % 2 == 0 else (values[base] + values[base + 1]) * 0.5

func _edge(mesh: SurfaceTool, a: Vector3, b: Vector3, side: float) -> void:
	var overhang := Vector3(side * 0.32, -0.72, 0.40)
	var foot_a := Vector3(a.x * 0.93, minf(-5.30, a.y - 1.0), a.z + 0.15)
	var foot_b := Vector3(b.x * 0.93, minf(-5.30, b.y - 1.0), b.z + 0.15)
	var lip_a := a + overhang
	var lip_b := b + overhang
	var ink := ROCK.darkened(rng.randf_range(0.12, 0.28))
	_face(mesh, a, lip_a, b, ink)
	_face(mesh, b, lip_a, lip_b, ink.darkened(0.11))
	_face(mesh, lip_a, foot_a, lip_b, CREVICE)
	_face(mesh, lip_b, foot_a, foot_b, CREVICE.darkened(0.17))

func _vegetation() -> SurfaceTool:
	var mesh := _surface()
	for tree: Vector3 in [
		Vector3(-3.53, 3.45, 2.45), Vector3(3.02, 3.05, 2.84),
		Vector3(-4.46, 2.45, 5.18), Vector3(4.54, 2.68, 5.42),
		Vector3(-2.87, 1.58, 6.22),
	]:
		_pine(mesh, _root(tree.x, tree.z), tree.y)
	for index in range(54):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := rng.randf_range(1.64, 7.44)
		var x := side * rng.randf_range(1.49, 5.38)
		var at := _root(x, z)
		if index % 4 == 0:
			var span := rng.randf_range(0.19, 0.45)
			_crown(mesh, at + Vector3.UP * (span * 0.39), Vector3(span, span * 0.76, span * 0.82),
				Color("#566044").lerp(Color("#848459"), rng.randf()))
		else:
			_grass(mesh, at, rng.randf_range(0.11, 0.30))
	return mesh

func _root(x: float, z: float) -> Vector3:
	return Vector3(x, _height(x, z) - 0.09, z)

func _pine(mesh: SurfaceTool, at: Vector3, height: float) -> void:
	var mid := at + Vector3(-0.10, height * 0.52, 0.10)
	var top := at + Vector3(0.16, height, 0.04)
	var bark := Color("#5e4936")
	_branch(mesh, at, mid, height * 0.048, height * 0.028, bark)
	_branch(mesh, mid, top, height * 0.029, height * 0.008, bark.lightened(0.13))
	for limb in range(5):
		var angle := limb * 2.4 + rng.randf_range(-0.23, 0.23)
		var level := float(limb) / 5.0
		var start := mid.lerp(top, level * 0.76)
		var reach := height * (0.32 - level * 0.15)
		var tip := start + Vector3(cos(angle) * reach, height * 0.085, sin(angle) * reach)
		_branch(mesh, start, tip, height * 0.018, height * 0.005, bark)
		var needles := Color("#414b37").lerp(Color("#6a7351"), rng.randf())
		var foliage := Vector3(reach * 0.81, height * 0.17, reach * 0.75)
		var canopy := tip + Vector3.UP * height * 0.105
		_crown(mesh, canopy, foliage, needles)
		var spray := Vector3(-sin(angle), 0.02, cos(angle)) * reach * 0.44
		_crown(mesh, canopy + spray, foliage * 0.70, needles.lightened(0.08))
	_crown(mesh, top - Vector3.UP * height * 0.02, Vector3(height * 0.16, height * 0.21, height * 0.15), Color("#677354"))

func _branch(mesh: SurfaceTool, at: Vector3, tip: Vector3, base: float, end: float, ink: Color) -> void:
	var axis := (tip - at).normalized()
	var tangent := axis.cross(Vector3.FORWARD).normalized()
	var across := axis.cross(tangent)
	for side in range(6):
		var angle := TAU * side / 6.0
		var next := TAU * (side + 1) / 6.0
		var a := tangent * cos(angle) + across * sin(angle)
		var b := tangent * cos(next) + across * sin(next)
		var tone := ink.darkened(side * 0.055)
		_face(mesh, at + a * base, tip + a * end, at + b * base, tone)
		_face(mesh, at + b * base, tip + a * end, tip + b * end, tone)

func _crown(mesh: SurfaceTool, at: Vector3, span: Vector3, ink: Color) -> void:
	var middle := PackedVector3Array()
	var upper := PackedVector3Array()
	var phase := rng.randf_range(0.0, TAU)
	for side in range(7):
		var angle := phase + side * TAU / 7.0
		var width := rng.randf_range(0.77, 1.20)
		var x := cos(angle) * width
		var z := sin(angle) * width
		middle.append(at + Vector3(x, rng.randf_range(-0.26, 0.15), z) * span)
		upper.append(at + Vector3(x * 0.65 + 0.11, rng.randf_range(0.38, 0.68), z * 0.63) * span)
	var top := at + Vector3(0.22, 0.76, -0.10) * span
	var bottom := at + Vector3(-0.07, -0.51, 0.12) * span
	for side in range(middle.size()):
		var next := (side + 1) % middle.size()
		var shade := ink.lightened(rng.randf_range(0.01, 0.11))
		_face(mesh, middle[side], upper[side], middle[next], shade)
		_face(mesh, middle[next], upper[side], upper[next], shade.darkened(0.09))
		_face(mesh, upper[side], top, upper[next], shade.lightened(0.08))
		_face(mesh, middle[next], bottom, middle[side], shade.darkened(0.18))

func _grass(mesh: SurfaceTool, at: Vector3, height: float) -> void:
	for blade in range(6):
		var angle := TAU * blade / 6.0 + rng.randf_range(-0.2, 0.2)
		var sweep := Vector3(cos(angle), 0, sin(angle))
		var base := at + sweep * rng.randf_range(0.015, 0.09)
		var edge := sweep.cross(Vector3.UP) * 0.024
		var tip := base + sweep * height * 0.58 + Vector3.UP * height * rng.randf_range(0.7, 1.3)
		var ink := Color("#625939").lerp(Color("#95895c"), rng.randf())
		_face(mesh, base - edge, tip, base + edge, ink)

func _surface() -> SurfaceTool:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	return mesh

func _face(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ink: Color) -> void:
	for vertex in [a, b, c]:
		mesh.set_color(ink)
		mesh.add_vertex(vertex)

func _add_mesh(title: String, surface: SurfaceTool, ink: Material) -> void:
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = surface.commit()
	node.material_override = ink
	add_child(node)
