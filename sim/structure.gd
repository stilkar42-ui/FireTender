extends RefCounted
## Support along the projected axis of a rigid fuel piece.
## Coordinates share the hearth's horizontal units. Height is independent of screen projection.

const MAX_SLOPE := 1.45
const SAMPLES := [-1.0, -0.67, -0.33, 0.0, 0.33, 0.67, 1.0]
const TOUCH := 0.016

class Pose:
	var at := Vector2.ZERO
	var axis := Vector2.RIGHT
	var slope := 0.0
	var height := 0.0
	var span := 0.0
	var contacts := PackedVector3Array()
	var supports := PackedInt32Array()
	var contact_ids := PackedInt32Array()

	func point(along: float, side := 0.0) -> Vector3:
		var plan := at + axis * along
		return Vector3(plan.x, plan.y, height + slope * along + side)

static func radius(kind: int) -> float:
	return [0.017, 0.028, 0.057, 0.066, 0.010, 0.012, 0.015, 0.021, 0.038, 0.049, 0.072, 0.051, 0.051, 0.051, 0.009, 0.024][kind]

static func coal_level(mass: float) -> int:
	return 0 if mass < 0.025 else clampi(int(mass / 0.025), 1, 4)

static func seat(at: Vector2, axis: Vector2, length: float, thickness: float,
		preferred: float, below: Array, coals: Array, precise := false, body = null, ceiling: Pose = null) -> Pose:
	var span := length
	if precise:
		span /= sqrt(1.0 + preferred * preferred)
	var pose := _fit(at, axis, span, thickness, preferred, below, coals, precise, body, ceiling)
	if precise:
		# Recheck the footprint when a requested lean meets a shallower rest.
		var actual_span := length / sqrt(1.0 + pose.slope * pose.slope)
		if absf(actual_span - span) > 0.008:
			pose = _fit(at, axis, actual_span, thickness, preferred, below, coals, precise, body, ceiling)
	return pose

static func _fit(at: Vector2, axis: Vector2, length: float, thickness: float, preferred: float,
		below: Array, coals: Array, precise: bool, body, ceiling: Pose) -> Pose:
	var pose := Pose.new()
	pose.at = at
	pose.axis = axis
	pose.span = length
	var grounds := PackedFloat64Array()
	var floors := PackedFloat64Array()
	var ids := PackedInt32Array()
	var offsets := PackedFloat64Array()
	var balance: float = body.centre_of_mass * length if body != null and precise else 0.0
	for fraction: float in SAMPLES:
		offsets.append(length * fraction)
	if precise:
		if absf(balance) > 0.006:
			_add_sample(offsets, balance)
		for piece in below:
			var relative: Vector2 = piece.at - at
			var other_span: float = piece.pose.span
			var reach: float = thickness + piece.radius
			if relative.length_squared() > pow(length + other_span + reach, 2.0):
				continue
			var cross: float = axis.cross(piece.axis)
			if absf(cross) > 0.001:
				var along := relative.cross(piece.axis) / cross
				var across := relative.cross(axis) / cross
				if absf(along) < length and absf(across) < other_span + reach:
					_add_sample(offsets, along)
			for endpoint in [-other_span, other_span]:
				var tip: Vector2 = relative + piece.axis * endpoint
				if absf(tip.cross(axis)) < reach:
					_add_sample(offsets, clampf(tip.dot(axis), -length, length))
		offsets.sort()
	for along in offsets:
		var plan := at + axis * along
		var underside: float = body.cross_section(along / length).lower_radius if body != null and precise else thickness
		var height := 0.0
		var support := 0
		for coal in coals:
			if coal.carried or plan.distance_squared_to(coal.at) > 0.0081:
				continue
			var ridge := coal_level(coal.char_mass) * 0.005
			if ridge > height:
				height = ridge
				support = -coal.id
		for piece in below:
			var distance: float = clampf((plan - piece.at).dot(piece.axis), -piece.pose.span, piece.pose.span)
			var gap: float = plan.distance_to(piece.at + piece.axis * distance)
			var region = piece.cross_section(distance / piece.pose.span)
			var crown: float = region.upper_radius
			if region.integrity < 0.10 or region.crushed:
				continue
			var width: float = underside + crown
			if gap > width * 0.91:
				continue
			var top: float = piece.pose.height + piece.pose.slope * distance + crown
			# Round sides contact lower than the crown of the support.
			top -= crown * 0.55 * pow(gap / width, 2.0)
			if ceiling != null and top + underside > ceiling.point(along).z + 0.003:
				continue
			if top > height:
				height = top
				support = piece.id
		floors.append(height)
		grounds.append(height + underside)
		ids.append(support)

	var desired := clampf(preferred, -MAX_SLOPE, MAX_SLOPE)
	var slopes := PackedFloat64Array([desired, 0.0, -MAX_SLOPE, MAX_SLOPE])
	for left in range(offsets.size() - 1):
		if offsets[left] > balance:
			break
		for right in range(left + 1, offsets.size()):
			if offsets[right] < balance:
				continue
			var slope := (grounds[right] - grounds[left]) / (offsets[right] - offsets[left])
			if absf(slope) <= MAX_SLOPE:
				slopes.append(slope)
	var best := INF
	for slope in slopes:
		var bottom := 0.0
		for i in range(offsets.size()):
			bottom = maxf(bottom, grounds[i] - offsets[i] * slope)
		var first := INF
		var last := -INF
		for i in range(offsets.size()):
			if bottom + offsets[i] * slope - grounds[i] <= TOUCH:
				first = minf(first, offsets[i])
				last = maxf(last, offsets[i])
		var overhang := maxf(0.0, maxf(first - balance, balance - last) - length * 0.15)
		var score := absf(slope - desired) + bottom * 0.18 + overhang * 100.0
		if score < best:
			best = score
			pose.slope = slope
			pose.height = bottom
	for i in range(offsets.size()):
		if pose.height + offsets[i] * pose.slope - grounds[i] <= TOUCH:
			var plan := at + axis * offsets[i]
			pose.contacts.append(Vector3(plan.x, plan.y, floors[i]))
			pose.contact_ids.append(ids[i])
			if not ids[i] in pose.supports:
				pose.supports.append(ids[i])
	return pose

static func _add_sample(offsets: PackedFloat64Array, along: float) -> void:
	for existing in offsets:
		if absf(existing - along) < 0.006:
			return
	offsets.append(along)
