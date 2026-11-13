extends RefCounted
## Perception at a hand-sized point above a working surface. The solver never
## reads this estimate, and the estimate uses the same poses in headless play.

const Fire := preload("res://sim/fire.gd")
const HEIGHT := 0.075
const LEVELS := ["No warmth", "Faint warmth", "Warm", "Strong heat", "Very hot", "Too hot to hold there"]
const BANDS := [0.05, 0.18, 0.55, 1.35, 2.8]

static func level(heat: float) -> int:
	var band := 0
	for threshold: float in BANDS:
		if heat < threshold:
			break
		band += 1
	return band

static func sample(fire: Fire, hand: Vector3) -> float:
	var heat := 0.0
	for coal in fire.coals:
		var origin := Vector3(coal.at.x, maxf(0.016, coal.height), coal.at.y)
		heat += _reach(fire, origin, hand, fire.radiant_power(coal), 14.0, null)
	for wood in fire.wood:
		if wood.sections.is_empty():
			heat += _wood_heat(fire, wood, wood, hand)
		else:
			for section in wood.sections:
				heat += _wood_heat(fire, section, wood, hand)
	return heat

static func _wood_heat(fire: Fire, source: Fire.Piece, owner: Fire.Piece, hand: Vector3) -> float:
	var origin := Vector3(source.at.x, source.height, source.at.y)
	var flame := source.flame * 0.024
	var solid := _reach(fire, origin, hand, fire.radiant_power(source) - flame, 9.0, owner)
	var lift := 0.08 + 0.16 * smoothstep(0.0, 35.0, source.flame)
	return solid + _reach(fire, origin + Vector3.UP * lift, hand, flame, 10.0, owner)

static func _reach(fire: Fire, origin: Vector3, hand: Vector3, power: float, falloff: float, owner: Fire.Piece) -> float:
	if power < 0.0001:
		return 0.0
	var gap := origin.distance_squared_to(hand)
	var heat := power / (1.0 + gap * falloff) * (1.0 - smoothstep(1.5, 3.4, sqrt(gap)))
	if heat < 0.0005 or gap < 0.0001:
		return heat
	# A shortened segment leaves the emitter and the hand outside the obstruction test.
	var from := origin.lerp(hand, 0.04)
	var to := hand.lerp(origin, 0.04)
	for screen in fire.wood:
		if screen == owner or screen.pose == null or screen.radius < 0.013:
			continue
		var center := Vector3(screen.at.x, screen.height, screen.at.y)
		var axis := screen.heat_axis
		var nearest := Geometry3D.get_closest_points_between_segments(from, to, center - axis, center + axis)
		var along := (nearest[1] - center).dot(axis) / maxf(0.000001, axis.length_squared())
		var profile := screen.cross_section(along)
		var radius := profile.upper_radius if nearest[0].y >= nearest[1].y else profile.lower_radius
		var gap_to_wood := nearest[0].distance_to(nearest[1])
		if gap_to_wood < radius:
			var shade := 0.38 if screen.fibre else 0.87
			heat *= 1.0 - shade * (1.0 - smoothstep(radius * 0.54, radius, gap_to_wood))
	return heat

static func ground(at: Vector2) -> Vector3:
	return Vector3(at.x, HEIGHT, at.y)
