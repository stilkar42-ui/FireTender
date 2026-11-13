extends RefCounted
## Camera-facing marks drawn in the world so wood and stone occlude them.

static func ribbon(mesh: ImmediateMesh, from: Vector3, to: Vector3, view: Vector3,
		start_width: float, end_width: float, ink: Color) -> void:
	var across := view.cross(to - from).normalized()
	var a := across * start_width
	var b := across * end_width
	_triangle(mesh, from - a, from + a, to + b, ink)
	_triangle(mesh, from - a, to + b, to - b, ink)

static func cinder(mesh: ImmediateMesh, point: Vector3, axis: Vector3, view: Vector3,
		size: float, heat: float, opacity: float, curl: float) -> void:
	var side := view.cross(axis).normalized() * size
	var up := axis * size
	var red := Color(Color("#db4325").lerp(Color("#ff9c33"), heat), opacity)
	var gold := Color(Color("#e96528").lerp(Color("#fff3b1"), heat), opacity)
	var base := point - up * 0.43
	var left := point - side * 0.61 + up * 0.20
	var right := point + side * 0.62
	var bend := point + up * 0.85 - side * 0.28
	var tip := point + up * 1.75 + side * curl
	_triangle(mesh, base, left, right, red)
	_triangle(mesh, left, bend, right, red)
	_triangle(mesh, bend, tip, right, red)
	var center := point + side * 0.08
	_triangle(mesh, base.lerp(center, 0.24), center - side * 0.30, center + side * 0.30, gold)
	_triangle(mesh, center - side * 0.30, center + up * 0.92 + side * 0.11, center + side * 0.30, gold)

static func _triangle(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, ink: Color) -> void:
	mesh.surface_set_color(ink)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
