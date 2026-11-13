extends RefCounted
## Representative material profiles. Conductivity and strength are relative
## model coefficients. Fuel forms supply the volume and initial water load.

const OAK := 0
const PINE := 1
const BIRCH := 2
const WILLOW := 3
const GRASS := 4

const PROFILES := [
	{"name": "Oak", "density": 690.0, "specific_heat": 1.55, "longitudinal": 1.00, "radial": 1.00, "tangent": 0.89,
		"twist": 0.24, "water_capacity": 1.65, "drying": 1.00, "char_yield": 0.29, "char_oxidation": 1.00,
		"strength": 1.24, "crumble": 0.78, "color": Color("#ad754c")},
	{"name": "Pine", "density": 485.0, "specific_heat": 1.56, "longitudinal": 1.11, "radial": 0.88, "tangent": 0.76,
		"twist": 0.57, "water_capacity": 1.70, "drying": 1.02, "char_yield": 0.23, "char_oxidation": 1.04,
		"strength": 0.94, "crumble": 1.12, "color": Color("#b38654")},
	{"name": "Birch", "density": 625.0, "specific_heat": 1.53, "longitudinal": 1.04, "radial": 1.06, "tangent": 0.95,
		"twist": 0.36, "water_capacity": 1.57, "drying": 0.98, "char_yield": 0.26, "char_oxidation": 0.98,
		"strength": 1.11, "crumble": 0.93, "color": Color("#c7ad87")},
	{"name": "Willow", "density": 430.0, "specific_heat": 1.61, "longitudinal": 0.96, "radial": 0.83, "tangent": 0.73,
		"twist": 0.72, "water_capacity": 1.92, "drying": 0.87, "char_yield": 0.21, "char_oxidation": 1.10,
		"strength": 0.83, "crumble": 1.20, "color": Color("#a09b6f")},
	{"name": "Grass", "density": 270.0, "specific_heat": 1.55, "longitudinal": 1.0, "radial": 1.0, "tangent": 0.88,
		"twist": 0.0, "water_capacity": 1.60, "drying": 1.0, "char_yield": 0.13, "char_oxidation": 1.0,
		"strength": 0.20, "crumble": 1.4, "color": Color("#bca05d")},
]

static func coupling(material: int, tilt: float, azimuth: float, direction: int) -> float:
	var profile: Dictionary = PROFILES[material]
	var across := lerpf(profile.radial, profile.tangent, pow(sin(azimuth), 2.0))
	if direction == 2:
		return lerpf(profile.tangent, profile.radial, pow(sin(azimuth), 2.0))
	var aligned := pow(cos(tilt), 2.0)
	var along := 1.64 * float(profile.longitudinal)
	if direction == 0:
		return lerpf(across, along, aligned)
	return lerpf(along, across, aligned)
