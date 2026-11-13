extends RefCounted
## Bounded smoke parcels. Mass is a proxy for the solver's smoke output.

const MAX_PARCELS := 48
const MIN_MASS := 0.000001

class Parcel:
	var id := 0
	var at := Vector3.ZERO
	var previous := Vector3.ZERO
	var mass := 0.0
	var radius := 0.09
	var warmth := 0.0

var parcels: Array[Parcel] = []
var emitted := 0.0
var escaped := 0.0
var dispersed := 0.0
var next_id := 1

func release(at: Vector3, amount: float, warmth: float) -> void:
	if amount <= 0.0:
		return
	emitted += amount
	if amount < 0.00000001:
		dispersed += amount
		return
	for parcel in parcels:
		if parcel.at.distance_squared_to(at) < 0.018:
			_merge(parcel, at, amount, warmth)
			return
	if parcels.size() >= MAX_PARCELS:
		var nearest := parcels[0]
		for parcel in parcels:
			if parcel.at.distance_squared_to(at) < nearest.at.distance_squared_to(at):
				nearest = parcel
		_merge(nearest, at, amount, warmth)
		return
	var parcel := Parcel.new()
	parcel.id = next_id
	next_id += 1
	parcel.at = at
	parcel.previous = at
	parcel.mass = amount
	parcel.warmth = warmth
	parcels.append(parcel)

func _merge(parcel: Parcel, at: Vector3, amount: float, warmth: float) -> void:
	var blend := amount / (parcel.mass + amount)
	parcel.at = parcel.at.lerp(at, blend)
	parcel.warmth = lerpf(parcel.warmth, warmth, blend)
	parcel.mass += amount

func advance(fire, dt: float) -> void:
	var cave = fire.shelter
	var trapped := 0.0
	for i in range(parcels.size() - 1, -1, -1):
		var parcel := parcels[i]
		parcel.previous = parcel.at
		var plan := Vector2(parcel.at.x, parcel.at.z)
		var air: Vector2 = fire.wind_at(plan, parcel.at.y)
		var rise := lerpf(0.095, 0.70, parcel.warmth)
		var movement := Vector3(air.x * 0.91, rise, air.y * 0.91)
		var sheltered: bool = cave != null and cave.depth_at(plan) < 0.0
		if sheltered:
			var under_roof := smoothstep(1.38, 2.03, parcel.at.y)
			# Buoyant smoke spreads along the roof toward the opening. An
			# inward draft can overwhelm that flow and retain it inside.
			movement.z += under_roof * lerpf(0.11, 0.53, cave.ventilation(plan))
		parcel.at += movement * dt
		if sheltered and cave.depth_at(Vector2(parcel.at.x, parcel.at.z)) < 0.0:
			parcel.at.x = clampf(parcel.at.x, -2.38, 1.62)
			parcel.at.y = minf(parcel.at.y, 2.12)
			parcel.at.z = maxf(parcel.at.z, -4.23)
		var outside: bool = cave == null or cave.depth_at(Vector2(parcel.at.x, parcel.at.z)) >= 0.0
		var loss := parcel.mass * (1.0 - exp(-dt * (0.62 if outside else 0.095)))
		parcel.mass -= loss
		if outside:
			escaped += loss
		else:
			dispersed += loss
		parcel.radius = minf(0.86, parcel.radius + dt * lerpf(0.04, 0.095, parcel.warmth))
		parcel.warmth *= exp(-dt * 0.20)
		if parcel.mass < MIN_MASS or parcel.at.y > 5.2 or parcel.at.length_squared() > 56.0:
			if outside:
				escaped += parcel.mass
			else:
				dispersed += parcel.mass
			parcels.remove_at(i)
		elif not outside:
			trapped += parcel.mass
	if cave != null:
		cave.smoke = trapped

func carried_mass() -> float:
	var total := 0.0
	for parcel in parcels:
		total += parcel.mass
	return total
