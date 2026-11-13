extends RefCounted
## A read-only impression of the air at the player's viewpoint.

const Fire := preload("res://sim/fire.gd")
const Heat := preload("res://sim/felt_heat.gd")

class Reading:
	var wind := Vector2.ZERO
	var rain := 0.0
	var chill := 0.0

static func sample(fire: Fire, eye: Vector3) -> Reading:
	var at := Vector2(eye.x, eye.z)
	var reading := Reading.new()
	reading.wind = fire.background_wind(at, eye.y)
	reading.rain = fire.rain_at(at)
	var air := fire.ambient() if fire.shelter == null else fire.shelter.air_temperature(at)
	var radiant := minf(7.0, Heat.sample(fire, eye) * 3.8)
	var felt := air + radiant - reading.wind.length() * 4.5 - reading.rain * 3.5
	reading.chill = 1.0 - smoothstep(-4.0, 10.5, felt)
	return reading

static func relative_wind(wind: Vector2, camera_basis: Basis) -> Vector2:
	# A ground-plane view keeps the forward component even when looking at
	# the horizon, the sky, or straight down at the fire.
	var right := Vector2(camera_basis.x.x, camera_basis.x.z).normalized()
	var forward := Vector2(right.y, -right.x)
	return Vector2(wind.dot(right), -wind.dot(forward))
