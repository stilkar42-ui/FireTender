extends RefCounted
## Read-only perception of a contacted surface, separate from the fire solver.

const Fire := preload("res://sim/fire.gd")
const Heat := preload("res://sim/felt_heat.gd")
const DRY := 0.18
const WET := 0.33
const SOAKED := 0.65
const HOT_TOUCH := 58.0

class Reading:
	var heat := 0.0
	var edge := 0.0
	var palm := 0.0
	var words := ""

static func fuel(piece: Fire.Piece, section: Fire.Piece, face: int, radiant: float) -> Reading:
	var skin := section if section.faces.is_empty() else section.faces[face]
	var surface := _water_ratio(skin)
	var inside := -1.0
	if section.core != null:
		var core := section.core
		var near := core if section.inner.is_empty() else section.inner[face]
		inside = (core.water + near.water) / (core.original + near.original)
	var reading := _contact(skin.temperature, radiant, surface)
	var inner_wet := inside >= WET and inside - surface >= 0.15
	if inner_wet:
		reading.palm = _ink(inside) * smoothstep(0.12, 0.38, inside - surface)
	if skin.temperature >= HOT_TOUCH:
		reading.words = "Too hot to touch."
		if skin.vapor > 0.00006:
			reading.words += "\nGiving off steam."
		elif inner_wet:
			reading.words += "\nWet within."
		elif surface >= DRY:
			reading.words += "\nStill " + _wet_word(surface) + "."
	elif skin.vapor > 0.00006 and skin.temperature >= 42.0:
		reading.words = "Hot and " + _wet_word(surface) + ".\nGiving off steam." if surface >= DRY else "Hot skin.\nGiving off steam."
	elif surface >= SOAKED and (inside < 0.0 or inside >= SOAKED):
		reading.words = "Soaked through."
		if skin.temperature >= 24.0:
			reading.words += "\n" + _temperature_word(skin.temperature).capitalize() + " on the skin."
	elif inner_wet and surface < WET:
		reading.words = "%s outside,\nwet within." % _temperature_word(skin.temperature).capitalize()
		if surface < DRY and skin.temperature >= 24.0 and skin.vapor > 0.000001:
			reading.words = "This face is drying.\nWet within."
	elif inside >= 0.0 and surface >= WET and surface - inside >= 0.18:
		var skin_name := "Bark" if piece.kind in [9, 11, 12, 13] else "Skin"
		reading.words = "%s is wet.\nDrier within." % skin_name
		if skin.temperature >= 24.0:
			reading.words = "%s, wet skin.\nDrier within." % _temperature_word(skin.temperature).capitalize()
	return reading

static func coal(piece: Fire.Piece, room: float, radiant: float) -> Reading:
	var covered := _ash_surface(piece)
	var temperature := coal_surface_temperature(piece, room)
	var reading := _contact(temperature, radiant, _water_ratio(piece))
	if temperature >= HOT_TOUCH:
		reading.words = "Ash is hot to touch." if covered else "Charcoal is hot to touch."
	elif covered and Heat.level(radiant) < 5:
		reading.words = "Ash feels %s\nand %s." % [_temperature_word(temperature), _wet_word(_water_ratio(piece))]
	return reading

static func coal_surface_temperature(piece: Fire.Piece, room: float) -> float:
	return lerpf(room, piece.temperature, exp(-2.85 * piece.depth())) if _ash_surface(piece) else piece.temperature

static func _ash_surface(piece: Fire.Piece) -> bool:
	return piece.cover >= 0.004 or piece.mineral > piece.char_mass

static func ground(fire: Fire, at: Vector2, radiant: float) -> Reading:
	var reading := Reading.new()
	reading.heat = radiant
	reading.words = Heat.LEVELS[Heat.level(radiant)]
	if not at.is_finite():
		return reading
	var rain := fire.rain_at(at)
	var seep := 0.0 if fire.shelter == null else fire.shelter.seepage_at(at)
	var exposed := rain > 0.08 or seep > 0.10
	if exposed:
		reading.edge = _ink(DRY + maxf(rain, seep) * 0.36)
	if Heat.level(radiant) == 5:
		return reading
	for cell: Vector2i in fire.ash_piles:
		var radius := Fire.ash_radius(fire.ash_piles[cell])
		var offset := (at - Vector2(cell) * Fire.CELL) / Vector2(radius, radius * 0.82)
		if offset.length_squared() <= 1.0:
			# Loose ash stores mass only. Active wetting describes the spot.
			reading.words = "Rain reaches this ash." if rain > 0.08 else ("Ash at the seep." if seep > 0.10 else
				("Ash is dry, but cool." if Heat.level(radiant) < 2 else "Dry ash.\nHeat reaches here."))
			return reading
	if exposed:
		reading.words = "Rain reaches here." if rain > 0.08 else "Damp at the seep."
	return reading

static func _contact(temperature: float, radiant: float, water: float) -> Reading:
	var reading := Reading.new()
	# Keep radiant danger and contact warmth on the same existing hand scale.
	var contact := 0.18 * smoothstep(9.0, 24.0, temperature) + 2.62 * smoothstep(24.0, HOT_TOUCH, temperature)
	reading.heat = maxf(radiant, contact)
	reading.edge = _ink(water)
	reading.words = "Too hot to touch." if temperature >= HOT_TOUCH else "%s and %s." % [
		_temperature_word(temperature).capitalize(), _wet_word(water)]
	if temperature < HOT_TOUCH and Heat.level(radiant) == 5:
		reading.words += "\nStrong heat nearby."
	return reading

static func _water_ratio(piece: Fire.Piece) -> float:
	return piece.water / maxf(0.000001, piece.original) * (1.28 if piece.fibre else 1.0)

static func _temperature_word(temperature: float) -> String:
	if temperature < 9.0:
		return "cold"
	if temperature < 24.0:
		return "cool"
	return "warm" if temperature < 43.0 else "hot"

static func _wet_word(water: float) -> String:
	if water < DRY:
		return "dry"
	if water < WET:
		return "damp"
	return "wet" if water < SOAKED else "soaked"

static func _ink(water: float) -> float:
	if water < DRY:
		return 0.0
	if water < WET:
		return lerpf(0.14, 0.38, inverse_lerp(DRY, WET, water))
	return lerpf(0.40, 1.0, smoothstep(WET, SOAKED, water))
