extends RefCounted
## Geometry-only feeding paths. Coordinates follow Structure.Pose.
const Structure := preload("res://sim/structure.gd")

static func pose(at: Vector2, length: float, yaw: float, slope: float, height: float) -> Structure.Pose:
	var result := Structure.Pose.new()
	result.at = at
	result.axis = Vector2.from_angle(yaw)
	result.slope = clampf(slope, -Structure.MAX_SLOPE, Structure.MAX_SLOPE)
	result.span = length / sqrt(1.0 + result.slope * result.slope)
	result.height = height
	return result

static func clear(fire, proposed: Structure.Pose, radius: float, ignored = null) -> bool:
	if minf(proposed.point(-proposed.span).z, proposed.point(proposed.span).z) < radius - 0.002:
		return false
	if (proposed.at / fire.LIMIT).length_squared() > 1.00001:
		return false
	var a := proposed.point(-proposed.span)
	var b := proposed.point(proposed.span)
	for wood in fire.wood:
		if wood == ignored or wood.fibre or wood.pose == null:
			continue
		var count := maxi(1, wood.sections.size())
		for i in range(count):
			var section = wood if wood.sections.is_empty() else wood.sections[i]
			var first: Vector3 = wood.pose.point(wood.pose.span * (2.0 * i / count - 1.0))
			var last: Vector3 = wood.pose.point(wood.pose.span * (2.0 * (i + 1) / count - 1.0))
			var points := Geometry3D.get_closest_points_between_segments(a, b, first, last)
			var offset := points[0] - points[1]
			var crown: float = section.upper_radius if offset.z >= 0.0 else section.lower_radius
			var width: float = maxf(0.001, radius + section.radius - 0.002)
			var thickness := maxf(0.001, radius + crown - 0.002)
			if (offset.x * offset.x + offset.y * offset.y) / (width * width) + offset.z * offset.z / (thickness * thickness) < 1.0:
				return false
	return true

static func sweep(fire, start: Structure.Pose, goal: Structure.Pose, radius: float, ignored = null) -> Structure.Pose:
	var angle := angle_difference(start.axis.angle(), goal.axis.angle())
	var reach := start.at.distance_to(goal.at) + absf(start.height - goal.height)
	reach += start.span * (absf(angle) + absf(start.slope - goal.slope))
	var steps := clampi(ceili(reach / maxf(0.004, radius * 0.55)), 1, 768)
	var safe: Structure.Pose = start if clear(fire, start, radius, ignored) else null
	for i in range(1, steps + 1):
		var part := float(i) / steps
		var candidate := pose(start.at.lerp(goal.at, part),
			lerpf(start.span * sqrt(1.0 + start.slope * start.slope), goal.span * sqrt(1.0 + goal.slope * goal.slope), part),
			start.axis.angle() + angle * part, lerpf(start.slope, goal.slope, part), lerpf(start.height, goal.height, part))
		if not clear(fire, candidate, radius, ignored):
			break
		safe = candidate
	return safe

static func rest(fire, proposed: Structure.Pose, radius: float, ignored = null) -> Structure.Pose:
	if not clear(fire, proposed, radius, ignored):
		return null
	var supports := []
	for wood in fire.wood:
		if wood != ignored and wood.can_support and not wood.airborne:
			supports.append(wood)
	var result := Structure.seat(proposed.at, proposed.axis, proposed.span * sqrt(1.0 + proposed.slope * proposed.slope),
		radius, proposed.slope, supports, fire.coals, true, ignored, proposed)
	if not clear(fire, result, radius, ignored):
		return null
	var safe := sweep(fire, proposed, result, radius, ignored)
	return result if (safe != null and is_equal_approx(safe.height, result.height) and safe.at.distance_to(result.at) < 0.00001 and
		safe.axis.is_equal_approx(result.axis) and is_equal_approx(safe.slope, result.slope)) else null

static func opening(fire, hot: Vector2) -> bool:
	var sheltered := false
	for wood in fire.wood:
		if wood.pose == null or wood.height < 0.10:
			continue
		var along: float = clampf((hot - wood.at).dot(wood.axis), -wood.pose.span, wood.pose.span)
		if hot.distance_to(wood.at + wood.axis * along) < wood.radius + 0.09:
			sheltered = true
			break
	if not sheltered:
		return false
	for i in range(4):
		var yaw := TAU * i / 4.0
		var axis := Vector2.from_angle(yaw)
		var goal := pose(hot - axis * 0.10, 0.137, yaw, 0.0, 0.055)
		if rest(fire, goal, 0.021) == null:
			continue
		var start := pose(hot - axis * 0.50, 0.137, yaw, 0.0, 0.055)
		var path := sweep(fire, start, goal, 0.021)
		if path != null and path.at.distance_to(goal.at) < 0.001:
			return true
	return false
