extends RefCounted
## A lumped thermal model. kg, seconds, degrees Celsius and kJ.
## Neither rendering nor the clock that schedules steps is part of this model.

const STEP := 0.25
const Structure := preload("res://sim/structure.gd")
const Feeding := preload("res://sim/feeding.gd")
const Materials := preload("res://sim/wood_materials.gd")
const Native := preload("res://sim/native_fire.gd")
const MAX_WOOD := 28
const MAX_FRAGMENTS := 6
const GRAVITY := 9.81
const LIMIT := Vector2(0.94, 0.87)
const LEAVES := 14
const TINDER_BUNDLE := 15
const RAW_TINDER := [4, 5, LEAVES, 0]
const TINDER_WORK_TIME := 8.0
const SPECIES := [
	{"label": "Birch bark", "mass": 0.021, "size": 0.095, "water": 0.045, "rate": 0.025, "yield": 0.16},
	{"label": "Pine twigs", "mass": 0.071, "size": 0.15, "water": 0.08, "rate": 0.016, "yield": 0.22},
	{"label": "Split oak", "mass": 0.38, "size": 0.245, "water": 0.13, "rate": 0.006, "yield": 0.29},
	{"label": "Wet oak", "mass": 0.46, "size": 0.265, "water": 0.86, "rate": 0.006, "yield": 0.29},
	{"label": "Bark fibres", "mass": 0.0032, "size": 0.044, "water": 0.035, "rate": 0.0045, "yield": 0.16, "inertia": 0.0011, "area": 0.42},
	{"label": "Dry grass", "mass": 0.0042, "size": 0.057, "water": 0.055, "rate": 0.0040, "yield": 0.13, "inertia": 0.0013, "area": 0.44},
	{"label": "Dry splinters", "mass": 0.0085, "size": 0.093, "water": 0.067, "rate": 0.005, "yield": 0.22, "inertia": 0.0018, "area": 0.55},
	{"label": "Finger sticks", "mass": 0.042, "size": 0.137, "water": 0.080, "rate": 0.008, "yield": 0.24, "inertia": 0.0045, "area": 0.84},
	{"label": "Split branch", "mass": 0.14, "size": 0.205, "water": 0.105, "rate": 0.006, "yield": 0.26, "segments": 2},
	{"label": "Thick branch", "mass": 0.26, "size": 0.293, "water": 0.13, "rate": 0.0055, "yield": 0.27, "segments": 3},
	{"label": "Long split", "mass": 0.54, "size": 0.347, "water": 0.15, "rate": 0.0058, "yield": 0.29, "segments": 4},
	{"label": "Pine branch", "volume": 0.00043, "size": 0.245, "water": 0.14, "rate": 0.0072, "segments": 3},
	{"label": "Birch branch", "volume": 0.00043, "size": 0.245, "water": 0.18, "rate": 0.0065, "segments": 3},
	{"label": "Willow branch", "volume": 0.00043, "size": 0.245, "water": 0.31, "rate": 0.0066, "segments": 3},
	{"label": "Dry leaves", "mass": 0.0034, "size": 0.058, "water": 0.075, "rate": 0.0039, "yield": 0.13, "inertia": 0.0013, "area": 0.42},
	{"label": "Tinder bundle", "mass": 0.0068, "size": 0.071, "water": 0.075, "rate": 0.0037, "yield": 0.15, "inertia": 0.0025, "area": 0.46},
]
const FUEL_MATERIAL := [Materials.BIRCH, Materials.PINE, Materials.OAK, Materials.OAK, Materials.BIRCH, Materials.GRASS,
	Materials.PINE, Materials.PINE, Materials.OAK, Materials.OAK, Materials.OAK, Materials.PINE, Materials.BIRCH, Materials.WILLOW,
	Materials.GRASS, Materials.GRASS]
const STARTERS := [0, 1, 4, 5, 6, 7, LEAVES, TINDER_BUNDLE]
const PLUME_FUEL := [1, 6, 7, 8, 11, 12, 13]
const WEATHER := [
	{"label": "Sheltered", "ambient": 12.0, "wind": 0.0, "rain": 0.0},
	{"label": "Cold", "ambient": -14.0, "wind": 0.0, "rain": 0.0},
	{"label": "Crosswind", "ambient": 5.0, "wind": 1.0, "rain": 0.0},
	{"label": "Driving rain", "ambient": 3.0, "wind": 0.65, "rain": 1.0},
]
const SCENARIOS := [
	"Living hearth", "Healthy coals", "Weak coals", "Banked coals",
	"A  •  Fire on one side", "B  •  Uneven oak", "C  •  Scattered embers",
	"D  •  A breath of air", "E  •  Damp and steaming", "E  •  Dying embers",
	"G  •  A wet end over flame", "H  •  Crossed rails", "H  •  Parallel rails",
	"H  •  Cone of kindling",
	"One Ember", "3D  •  Log cabin", "3D  •  Lean-to", "3D  •  Cone",
	"3D  •  Parallel rails", "3D  •  Tinder nest", "Cold hearth",
	"Heat A1  •  One ember and tinder", "Heat A2  •  Charcoal chunk and tinder",
	"Heat B1  •  Raised branch over small coals", "Heat B2  •  Raised branch over a deep bed",
	"Heat C1  •  Oak over a hot bed", "Heat C2  •  Oak over a cold bed",
	"Heat D1  •  Open cabin", "Heat D2  •  Tight cabin",
	"Heat E  •  Refuel the established hearth", "Heat F  •  Wet load on weak coals",
	"Grain A  •  A log burns from one end", "Grain B  •  A cabin settles", "Grain C  •  A log burns in two",
	"Keeping A  •  Nurse a faint ember", "Keeping B  •  Carry the ember", "Keeping C  •  Feed the inner fire",
	"Build  •  Cold log cabin",
]
const ONE_EMBER := 14
const CABIN := 15
const LEAN_TO := 16
const CONE := 17
const PARALLEL := 18
const NEST := 19
const COLD := 20
const HEAT_EMBER := 21
const HEAT_CHUNK := 22
const HEAT_SMALL_BED := 23
const HEAT_DEEP_BED := 24
const HEAT_GAP := 25
const HEAT_ISOLATED := 26
const HEAT_OPEN_CABIN := 27
const HEAT_TIGHT_CABIN := 28
const HEAT_REFUEL := 29
const HEAT_OVERLOAD := 30
const GRAIN_END := 31
const GRAIN_CABIN := 32
const GRAIN_BREAK := 33
const NURSE_EMBER := 34
const CARRY_EMBER := 35
const FEED_FIRE := 36
const COLD_CABIN := 37
const OPENING := -1
const CELL := 0.22
const MAX_PATCHES := 64
const FIBRE_MASS := 0.0032
const FIBRE_HEAT_CAPACITY := 0.0065
const FIBRE_OXIDATION_ENERGY := 7600.0 # kJ/kg of fibre oxidised, excluding residual char
const EMBER_FEEDBACK_LIMIT := 0.48
const STEFAN_BOLTZMANN := 5.670374419e-11 # kW m⁻² K⁻⁴
const RADIATION_CAPTURE_LIMIT := 0.70
const COAL_POINTS := [
	Vector2(-0.29, -0.21), Vector2(0.14, -0.30), Vector2(0.39, 0.08),
	Vector2(0.06, 0.02), Vector2(-0.41, 0.19), Vector2(-0.07, 0.31),
	Vector2(0.32, 0.36),
]

class Piece:
	var rest_order := 0
	var id: int
	var kind: int # -1 for the coal bed
	var at: Vector2
	var size: float
	var original: float
	var wood := 0.0
	var water := 0.0
	var char_mass := 0.0
	var gas := 0.0
	var cover := 0.0
	var temperature: float
	var oxygen := 1.0
	var flame := 0.0 # kW of gas combustion
	var char_heat := 0.0 # kW of char oxidation
	var vapor := 0.0 # kg/s
	var smoke := 0.0 # kg/s proxy
	var mineral := 0.0
	var base_capacity := 0.0
	var shed := 0.0
	var charred_wood := 0.0
	var axis := Vector2.RIGHT
	var faces: Array[Piece] = [] # upper, underside
	var sections: Array[Piece] = []
	var inner: Array[Piece] = [] # the sub-surface grain beneath each face
	var core: Piece
	var pose: Structure.Pose
	var tier := 0
	var lean := 0.0
	var height := 0.0
	var fraction := 1.0
	var inertia := 0.008
	var area_scale := 1.0
	var precise := false
	var heat_axis := Vector3.ZERO
	var radius := 0.0
	var wear := 8
	var can_support := true
	var fed := false
	var carried := false
	var footing := 0
	var owner := 0
	var layer := 0 # 1 upper, -1 underside, 0 unlayered
	var draft := Vector2.ZERO
	var pulse := 0.0
	var breath_balance := 0.0
	var trend := 0.0 # filtered degrees per second
	var fibre := false
	var fibre_spread := 0.0 # added variance of an effective porous bundle
	var fibre_shelter := 0.0
	var pore_density := 0.0
	var bed_shelter := 0.0
	var smolder := 0.0 # kW from low-temperature fibre oxidation
	var smoldered := 0.0 # cumulative mass committed to that reaction
	var conduction := 0.0 # signed kW exchanged with other solids
	var radiation_in := 0.0
	var radiation_out := 0.0
	var flame_radiation := 0.0
	var plume_heat := 0.0
	var internal_heat := 0.0
	var convection_loss := 0.0
	var drying_heat := 0.0
	var decomposition_heat := 0.0
	var reaction_heat := 0.0
	var charcoal_used := 0.0 # kg in the last step
	var gas_used := 0.0 # kg in the last step
	var char_density := 225.0 # effective particle density, kg/m³
	var char_porosity := 0.45
	var ignition := 0.0
	var pilot := 0.0
	var exposed_surface := 0.0
	var material := Materials.OAK
	var volume := 0.0
	var specific_heat := 1.55
	var original_radius := 0.0
	var upper_radius := 0.0
	var lower_radius := 0.0
	var integrity := 1.0
	var grain_tilt := 0.0
	var grain_angle := 0.0
	var axial_coupling := 1.0
	var radial_coupling := 1.0
	var tangent_coupling := 1.0
	var centre_of_mass := 0.0 # along the body, as a fraction of half span
	var roll_travel := 0.0
	var rolling := false
	var roll_velocity := Vector2.ZERO
	var carried_load := 0.0 # N
	var contact_load := 0.0 # N over a region's supporting cross-section
	var split_start := false
	var split_end := false
	var split_family := 0
	var airborne := false
	var fall_speed := 0.0
	var crushed := false
	var drying_factor := 1.0
	var oxidation_factor := 1.0
	var moisture_capacity := 1.6
	var yield_char := 0.0
	var crumbling := 1.0
	var resin := 0.0 # Included in wood, assigned to one physical region.
	var resin_seed := 0
	var pocket_pressure := 0.0
	var pops := 0

	func bearing_limit() -> float:
		return PI * upper_radius * lower_radius * 15_000.0 * float(Materials.PROFILES[material].strength) * integrity

	func mass() -> float:
		return wood + water + char_mass + mineral + cover

	func cross_section(along: float) -> Piece:
		if sections.is_empty():
			return self
		var index := floori((clampf(along, -1.0, 0.999999) + 1.0) * 0.5 * sections.size())
		return sections[index]

	func capacity() -> float:
		if kind == -1:
			return maxf(0.0001, base_capacity + char_mass * 1.15 + (cover + mineral) * 0.8 + water * 4.18)
		if not sections.is_empty():
			var total := 0.0
			for section in sections:
				total += section.capacity()
			return total
		if core != null:
			var total := faces[0].capacity() + faces[1].capacity() + core.capacity()
			for region in inner:
				total += region.capacity()
			return total
		return inertia * fraction + wood * specific_heat + char_mass * 1.15 + mineral * 0.8 + water * 4.18

	func depth() -> float:
		return (cover + mineral * 0.08) / (0.005 + original * 0.24)

	func charcoal_volume() -> float:
		return char_mass / (char_density * (1.0 - char_porosity))

	func stored_heat(room: float) -> float:
		return capacity() * (temperature - room)

	func living_coal() -> bool:
		return kind < 0 and char_mass > 0.0007 and temperature >= 338.0

	func glow() -> float:
		var char_glow := smoothstep(340.0, 740.0, temperature) * clampf(char_mass / 0.022, 0.0, 1.0)
		if fibre and smolder > 0.0:
			return maxf(char_glow, smoothstep(265.0, 500.0, temperature) * minf(1.0, smolder / 0.9))
		return char_glow

class Breath:
	var origin: Vector2
	var direction: Vector2
	var reach: float
	var strength: float
	var duration: float
	var age := 0.0

class Spark:
	var position: Vector3 # Model X/Y, height in Z.
	var flight := PackedVector3Array()
	var contact_offset := Vector3.ZERO
	var velocity: Vector3
	var source: int
	var temperature: float
	var mass: float
	var age := 0.0
	var contact_age := 0.0
	var receiver: Piece
	var surface: Piece

class Residue:
	var at: Vector2
	var height: float
	var speed := 0.0
	var carbon: float
	var mineral: float
	var water: float
	var temperature: float
	var density: float
	var pores: float
	var oxidation: float

class Link:
	var a: int
	var b: int
	var delta: Vector2
	var proximity: float
	var conductance: float
	var receive_a: float
	var receive_b: float
	var coal := -1
	var toward_wood := Vector2.ZERO
	var fibre_contact := false
	var ember_feedback := 0.0
	var view_a := 0.0
	var view_b := 0.0

var wood: Array[Piece] = []
var coals: Array[Piece] = []
var breaths: Array[Breath] = []
var falling: Array[Residue] = []
var cells := {}
const Shelter := preload("res://sim/red_hollow_shelter.gd")
const SmokeField := preload("res://sim/smoke_field.gd")
var shelter: Shelter
var smoke_field := SmokeField.new()
var ground_wetness := 0.0
var stored: Array[Piece] = []
var next_rest_order := 1
var storage_revision := 0
var storage_dirty := true
var storage_sample := 0.0
var fuel_stock: PackedInt32Array:
	get:
		var counts := PackedInt32Array()
		if shelter != null:
			counts.resize(SPECIES.size())
			for piece in all_fuel():
				if _in_stock(piece):
					counts[piece.kind] += 1
		return counts
var ash_piles: Dictionary = {}
var weather := 0
var time := 0.0
var ash := 0.0 # mineral ash available at the rim, in kg
var oxygen := 1.0 # fraction of fresh-air oxygen in the shared draft
var fan := 0.0
var next_id := 1
var revision := 0
var network_dirty := true
var supports_dirty := false
var wear_dirty := false
var last_settle := -INF
var seat_cache := {}
var support_geometry := {}
var support_geometry_serial := 0
var nodes: Array[Piece] = []
var links: Array[Link] = []
var radiant_links: Array[Link] = []
var exchange_links := PackedFloat64Array()
var exchange_nodes := PackedFloat64Array()
var exchange_fibre: Array[Link] = []
var exchange_bed: Array[Link] = []
var network_candidates := 0
var network_occluders: Array[Piece] = []
var occluder_centers := PackedVector3Array()
var occluder_axes := PackedVector3Array()
var occluder_inverse_axis := PackedFloat64Array()
var occluder_radius := PackedFloat64Array()
var occluder_lower := PackedVector3Array()
var occluder_upper := PackedVector3Array()
var radiation_cells := {}
var airflow_cells := {}
var wind_stock_cells := {}
var wind_stock_indexed := false
var crowding := PackedFloat64Array()
var starter_ventilation := PackedFloat64Array()
var tinder_job := {}
var capacities := PackedFloat64Array()
var insulations := PackedFloat64Array()
var changes := PackedFloat64Array()
var ember_heat := PackedFloat64Array()
var radiated := 0.0
var absorbed := 0.0
var evaporated_water := 0.0
var received_water := 0.0
var sparks: Array[Spark] = []
var spark_ejections := 0
var spark_landings := 0
var spark_ground_carbon := 0.0
var spark_oxidized := 0.0
var spark_heat_delivered := 0.0
var last_char_fall := -INF

signal structure_event(kind: String, at: Vector2, mass: float, height: float, temperature: float)
signal spark_grounded(fragment: Spark)
signal tinder_finished(bundle: Piece)

func _init(scenario: int = 0) -> void:
	setup(scenario)

func setup(scenario: int) -> void:
	smoke_field = SmokeField.new()
	ground_wetness = 0.0
	shelter = null
	stored.clear()
	storage_revision += 1
	storage_sample = 0.0
	storage_dirty = true
	next_rest_order = 1
	ash_piles.clear()
	revision += 1
	wood.clear()
	_invalidate_wind_stock()
	coals.clear()
	breaths.clear()
	falling.clear()
	last_char_fall = -INF
	cells.clear()
	network_dirty = true
	supports_dirty = false
	wear_dirty = false
	last_settle = -INF
	seat_cache.clear()
	support_geometry.clear()
	support_geometry_serial = 0
	weather = 0
	time = 0.0
	radiated = 0.0
	absorbed = 0.0
	evaporated_water = 0.0
	received_water = 0.0
	sparks.clear()
	spark_ejections = 0
	spark_landings = 0
	spark_ground_carbon = 0.0
	spark_oxidized = 0.0
	spark_heat_delivered = 0.0
	ash = 0.25 # ash left by previous fires
	oxygen = 1.0
	fan = 0.0
	next_id = 1
	tinder_job.clear()
	if scenario == COLD_CABIN:
		_build_cold_cabin()
		return
	if scenario >= NURSE_EMBER and scenario <= FEED_FIRE:
		_build_keeping_trial(scenario)
		return
	if scenario >= HEAT_EMBER and scenario <= HEAT_OVERLOAD:
		_build_heat_trial(scenario)
		return
	if scenario in [GRAIN_END, GRAIN_CABIN, GRAIN_BREAK]:
		_build_grain_trial(scenario)
		return
	if scenario == 4 or scenario == 5:
		var spot := Vector2(-0.56, 0.04)
		_new_coal(spot, 0.095, 708.0, 0.055)
		_new_coal(spot + Vector2(-0.17, -0.05), 0.065, 685.0, 0.044)
		var log := add_fuel(2, spot)
		_prime(log, 525.0 if scenario == 4 else 220.0, 620.0, 150.0)
		_warm_up(14.0 if scenario == 4 else 8.0)
		return
	if scenario == 6:
		for at: Vector2 in [Vector2(-0.70, 0.20), Vector2(-0.43, -0.48), Vector2(0.12, -0.59),
				Vector2(0.70, -0.21), Vector2(0.56, 0.41)]:
			_new_coal(at, 0.076, 625.0, 0.047)
		return
	if scenario == 7:
		var coal := _new_coal(Vector2(-0.24, 0.07), 0.12, 580.0, 0.055)
		coal.cover = 0.013
		ash -= coal.cover
		_new_coal(Vector2(0.55, 0.12), 0.033, 460.0, 0.036)
		add_fuel(0, Vector2(-0.23, 0.02))
		return
	if scenario >= ONE_EMBER and scenario < COLD:
		_build_workbench(scenario)
		return
	if scenario >= 10 and scenario < ONE_EMBER:
		_build_trial(scenario)
		return
	for at: Vector2 in COAL_POINTS:
		var weak := scenario == 2 or scenario == 9
		var heat := 470.0 - at.length() * 85.0 if weak else 695.0 - at.length() * 115.0
		_new_coal(at, 0.049 if weak else 0.095, ambient() if scenario == COLD else heat, 0.055)
	if scenario == OPENING:
		var old_oak := add_fuel(2, Vector2(-0.34, -0.13))
		_prime(old_oak, 300.0, 408.0, 240.0)
		var last_twigs := add_fuel(1, Vector2(0.35, -0.23))
		last_twigs.temperature = 404.0
		last_twigs.water *= 0.32
		_warm_up(2.0)
	elif scenario == 0:
		var split := add_fuel(2, Vector2(-0.25, 0.01))
		_prime(split, 500.0, 570.0, 280.0)
		var twigs := add_fuel(1, Vector2(0.24, -0.16))
		twigs.temperature = 485.0
		twigs.water = 0.0
		_warm_up(6.0)
	elif scenario == 3:
		rake()
		bank()
	elif scenario == 8:
		add_fuel(3, Vector2(-0.16, 0.03))
		_warm_up(7.0)
	elif scenario == 9:
		_warm_up(40.0)

func _build_cold_cabin() -> void:
	_build_workbench(ONE_EMBER)
	var ember := coals[0]
	lift_coal(ember)
	deposit_coal(ember, Vector2(0.54, 0.03))
	for side: int in [-1, 1]:
		add_fuel(10, Vector2(0, side * 0.23), 0, 0, 0, true)
		add_fuel(9, Vector2(side * 0.24, 0), PI * 0.5, 0, 1, true)
		add_fuel(9, Vector2(0, side * 0.18), 0, 0, 2, true)
	for side: int in [-1, 1]:
		add_fuel(6, Vector2(side * 0.039, 0), PI * 0.5, 0, 0, true)
		add_fuel(7, Vector2(0, side * 0.069), 0, 0, 1, true)
		add_fuel(8, Vector2(side * 0.094, 0), PI * 0.5, 0, 2, true)
	add_fuel(LEAVES, Vector2(-0.49, -0.18), 0, 0, 0, true)
	add_fuel(LEAVES, Vector2(-0.57, 0.02), 0, 0, 0, true)

func _build_workbench(scenario: int) -> void:
	if scenario == ONE_EMBER:
		ash = 0.036
		var ember := _new_coal(Vector2.ZERO, 0.0125, 770.0, 0.0035)
		ember.size = 0.061
		ember.original = 0.016
		ember.precise = true
		return
	if scenario == NEST:
		_build_workbench(ONE_EMBER)
		add_fuel(4, Vector2.ZERO, 0.0, 0.0, 0, true)
		add_fuel(4, Vector2(0.0, 0.085), 0.0, 0.0, 0, true)
		add_fuel(5, Vector2(0.0, -0.085), 0.0, 0.0, 0, true)
		for side in [-1, 1]:
			add_fuel(6, Vector2(side * 0.18, 0.0), 0.0, 0.0, 0, true)
		return
	if scenario == CABIN or scenario == CONE:
		_trial_bed(0.145 if scenario == CABIN else 0.105, 711.0)
	else:
		for p: Vector2 in [Vector2(-0.12, 0.03), Vector2(0.10, -0.06), Vector2(0.04, 0.16)]:
			_new_coal(p, 0.094, 711.0, 0.055)
	if scenario == CABIN or scenario == PARALLEL:
		for side in [-1, 1]:
			var rail := add_fuel(10, Vector2(0, side * 0.23), 0.0, 0.0, 0, true)
			_prime(rail, 235.0, 320.0, 150.0)
		if scenario == CABIN:
			# The demonstration starts with a lower course that has had time
			# to warm over the coals before the player adds upper fuel.
			_warm_up(10.0)
			for side in [-1, 1]:
				add_fuel(9, Vector2(side * 0.24, 0), PI * 0.5, 0.0, 1, true)
			for side in [-1, 1]:
				add_fuel(9, Vector2(0, side * 0.17), 0.0, 0.0, 2, true)
	elif scenario == LEAN_TO:
		add_fuel(9, Vector2(-0.19, 0.0), PI * 0.5, 0.0, 0, true)
		for offset in [-0.15, 0.02, 0.17]:
			add_fuel(8, Vector2(0.01, offset), 0.0, -0.50, 1, true)
	else:
		add_fuel(1, Vector2(0.06, -0.04), 0.3, 0.0, -2, true)
		_warm_up(5.0)
		add_fuel(8, Vector2.ZERO, PI * 0.5, 0.0, 0, true)
		add_fuel(8, Vector2.ZERO, PI * 0.5, 0.0, 1, true)
		for i in range(5):
			var angle := TAU * i / 5.0 + 0.17
			add_fuel(8, Vector2.from_angle(angle) * 0.228, angle, -0.82, 2, true)
	add_fuel(6, Vector2(0.02, 0.02), 0.18, 0.0, -1, true)

func _build_heat_trial(scenario: int) -> void:
	match scenario:
		HEAT_EMBER, HEAT_CHUNK:
			if scenario == HEAT_EMBER:
				_build_workbench(ONE_EMBER)
			else:
				_trial_coal(Vector2.ZERO, 0.115, 700.0, 310.0, 0.34)
			add_fuel(4, Vector2.ZERO, 0.0, 0.0, 0, true)
		HEAT_SMALL_BED, HEAT_DEEP_BED, HEAT_GAP, HEAT_ISOLATED:
			_trial_bed(0.016 if scenario == HEAT_SMALL_BED else 0.145,
				ambient() if scenario == HEAT_ISOLATED else 700.0)
			for side in [-1, 1]:
				add_fuel(10, Vector2(side * 0.25, 0), PI * 0.5, 0.0, 0, true)
			var kind := 2 if scenario in [HEAT_GAP, HEAT_ISOLATED] else 8
			add_fuel(kind, Vector2.ZERO, 0.0, 0.0, 1, true)
		HEAT_OPEN_CABIN, HEAT_TIGHT_CABIN:
			_trial_bed(0.095, 700.0)
			var gap := 0.09 if scenario == HEAT_TIGHT_CABIN else 0.23
			for tier in range(3):
				for side in [-1, 1]:
					var across := tier % 2 == 0
					add_fuel(8, Vector2(0, side * gap) if across else Vector2(side * gap, 0),
						0.0 if across else PI * 0.5, 0.0, tier, true)
		HEAT_REFUEL:
			setup(0)
			add_fuel(2, Vector2(0.18, -0.06), PI * 0.5, 0.0, 0, true)
		HEAT_OVERLOAD:
			setup(2)
			add_fuel(3, Vector2.ZERO, 0.0, 0.0, 0, true)

func _trial_bed(mass: float, temperature: float) -> void:
	for at: Vector2 in [Vector2(-0.17, -0.08), Vector2(0.0, -0.09), Vector2(0.17, -0.08),
			Vector2(-0.17, 0.12), Vector2(0.0, 0.11), Vector2(0.17, 0.12)]:
		_trial_coal(at, mass, temperature)

func _trial_coal(at: Vector2, mass: float, temperature: float, density := 225.0, pores := 0.45) -> void:
	var coal := _new_coal(at, mass, temperature, 0.0035 + 0.52 * mass, density, pores)
	coal.size = 0.17 * pow(mass / 0.095, 1.0 / 3.0)
	coal.original = mass
	coal.precise = true

func _build_grain_trial(scenario: int) -> void:
	if scenario == GRAIN_CABIN:
		setup(CABIN)
		return
	if scenario == GRAIN_BREAK:
		_build_burning_bridge()
		return
	setup(10)
	var rest: Piece = wood.back()
	var at := rest.at
	var yaw := rest.axis.angle()
	wood.erase(rest)
	add_fuel(10, at, yaw, -0.54, 1, true)

func _build_burning_bridge() -> void:
	for at: Vector2 in [Vector2(0.0, -0.065), Vector2(0.0, 0.065), Vector2(-0.09, 0.0), Vector2(0.09, 0.0)]:
		_trial_coal(at, 0.35, 755.0)
	for side in [-1, 1]:
		add_fuel(10, Vector2(side * 0.32, 0.0), PI * 0.5, 0.0, 0, true)
	var beam := add_fuel(10, Vector2.ZERO, 0.0, 0.0, 1, true)
	var hot := beam.sections[1]
	# Start the demonstration partway through a burn, with a charred web between sound ends.
	var converted := hot.original * 0.55
	for cell: Piece in hot.faces + hot.inner + [hot.core]:
		cell.wood *= 0.45
		cell.charred_wood = cell.original - cell.wood
		cell.water *= 0.45
	hot.faces[0].temperature = 420.0
	hot.faces[1].temperature = 660.0
	hot.core.temperature = 270.0
	hot.faces[0].char_mass = converted * hot.yield_char * 0.26
	hot.faces[1].char_mass = converted * hot.yield_char * 0.33
	_sync_sections(beam)
	_update_section_shape(beam)
	_settle()

func _build_keeping_trial(scenario: int) -> void:
	if scenario in [NURSE_EMBER, CARRY_EMBER]:
		ash = 0.036
		var coal := _new_coal(Vector2(-0.44, 0.0), 0.0135 if scenario == NURSE_EMBER else 0.018, 490.0, 0.0035)
		coal.original = 0.016
		coal.size = 0.061
		coal.precise = true
		if scenario == CARRY_EMBER:
			for i in range(5):
				add_fuel(4, Vector2(0.12, 0.0) + Vector2.from_angle(TAU * i / 5.0) * 0.043, 0.0, 0.0, 0, true)
		return
	setup(CABIN)

func _build_trial(scenario: int) -> void:
	if scenario == 10:
		var hot := Vector2(-0.53, 0.04)
		for offset: Vector2 in [Vector2(-0.09, -0.14), Vector2(-0.13, 0.08),
				Vector2(0.09, -0.07), Vector2(0.03, 0.12)]:
			_new_coal(hot + offset, 0.14, 765.0, 0.055)
		var firewood := add_fuel(2, hot + Vector2(-0.05, 0.05), PI * 0.49)
		_prime(firewood, 635.0, 710.0, 460.0)
		var prop := add_fuel(2, Vector2(-0.33, -0.15), PI * 0.5)
		_prime(prop, 285.0, 310.0, 220.0)
		_warm_up(1.0)
		var damp := add_fuel(3, Vector2(-0.12, 0.03), 0.0, -0.8)
		# A damp branch rather than a saturated trial log. Both ends start alike.
		for section in damp.sections:
			section.core.water *= 0.64
			for face in section.faces:
				face.water *= 0.64
		_sync_sections(damp)
		return
	for p: Vector2 in [Vector2(-0.13, 0.0), Vector2(0.08, -0.09), Vector2(0.01, 0.15),
			Vector2(-0.19, -0.15), Vector2(0.16, 0.10)]:
		_new_coal(p, 0.096, 715.0, 0.055)
	if scenario == 13:
		var fork := add_fuel(2, Vector2(0.02, 0.0), PI * 0.5)
		_prime(fork, 360.0, 520.0, 280.0)
		var top := add_fuel(2, fork.at, PI * 0.5, 0.0, 1)
		_prime(top, 290.0, 460.0, 220.0)
		for i in range(5):
			var angle := TAU * i / 5.0 + 0.2
			add_fuel(1, Vector2.from_angle(angle) * 0.21, angle, -0.86, 2)
		return
	var rail := add_fuel(2, Vector2(-0.04, -0.14 if scenario == 11 else -0.23), 0.0)
	_prime(rail, 355.0, 505.0, 260.0)
	var across := add_fuel(2, Vector2(-0.02, 0.02), PI * 0.52, 0.2) if scenario == 11 else add_fuel(2, Vector2(0.01, 0.27), 0.0)
	_prime(across, 355.0, 505.0, 260.0)
	add_fuel(1, Vector2(0.01, 0.0), PI * 0.23)

func _warm_up(seconds: float) -> void:
	for tick in range(int(seconds / STEP)):
		step()
	time = 0.0

func _new_coal(at: Vector2, mass: float, heat: float, base: float, density := 225.0, pores := 0.45) -> Piece:
	var coal := Piece.new()
	coal.id = next_id
	next_id += 1
	coal.kind = -1
	coal.at = at
	coal.size = 0.17
	coal.original = 0.095
	coal.char_mass = mass
	coal.temperature = heat
	coal.base_capacity = base
	coal.char_density = density
	coal.char_porosity = pores
	coals.append(coal)
	network_dirty = true
	cells[_cell(at)] = coal
	return coal

func ambient() -> float:
	return shelter.temperature if shelter != null else WEATHER[weather].ambient

func rain_at(at: Vector2) -> float:
	return shelter.rain_at(at) if shelter != null else WEATHER[weather].rain

func rain_landing_height(at: Vector2, fuel: Array[Piece]) -> float:
	var height := 0.0
	for piece in fuel:
		if piece.pose == null or piece.fibre or at.distance_squared_to(piece.at) > pow(piece.pose.span + piece.radius, 2.0):
			continue
		var along := clampf((at - piece.at).dot(piece.pose.axis), -piece.pose.span, piece.pose.span)
		var section := piece.cross_section(along / maxf(0.001, piece.pose.span))
		var gap := at.distance_squared_to(piece.at + piece.pose.axis * along)
		if gap < section.upper_radius * section.upper_radius:
			height = maxf(height, piece.pose.point(along, sqrt(section.upper_radius * section.upper_radius - gap)).z)
	return height

func weather_wind(at: Vector2) -> Vector2:
	return shelter.wind_at(at) if shelter != null else Vector2(WEATHER[weather].wind, 0.0)

func background_wind(at: Vector2, height := 0.05, owner := 0) -> Vector2:
	var flow := weather_wind(at) + Vector2(fan, 0.0)
	if flow.length_squared() < 0.000025 or height > 1.2:
		return flow
	var forward := flow.normalized()
	var across := forward.orthogonal()
	var probe_height := maxf(0.035, height)
	var remaining := 1.0
	if not wind_stock_indexed:
		_index_wind_stock()
	for piece: Piece in wind_stock_cells.get(_wind_stock_cell(at), []):
		if piece.id == owner or piece.radius < 0.032 or piece.pose == null or piece.airborne:
			continue
		var offset := at - piece.pose.at
		if offset.length_squared() > 1.44:
			continue
		var cross_axis := piece.pose.axis.dot(across)
		var along := 0.0
		if absf(cross_axis) > 0.015:
			along = clampf(offset.dot(across) / cross_axis, -piece.pose.span, piece.pose.span)
		var from_log := offset - piece.pose.axis * along
		var downstream := from_log.dot(forward)
		if downstream <= 0.0 or downstream >= 0.78:
			continue
		var section := piece.cross_section(along / maxf(0.01, piece.pose.span))
		var width := section.radius + downstream * 0.10
		var side := 1.0 - smoothstep(width * 0.63, width, absf(from_log.dot(across)))
		var center := piece.pose.height + along * piece.pose.slope
		var crown := section.upper_radius + downstream * 0.12
		var underside := section.lower_radius + downstream * 0.07
		var above := probe_height - center
		var vertical := 1.0 - smoothstep(0.65, 1.0, above / crown if above >= 0.0 else -above / underside)
		var wake := smoothstep(0.008, 0.09, downstream) * (1.0 - smoothstep(0.12, 0.78, downstream))
		remaining *= 1.0 - 0.78 * side * vertical * wake
	return flow * maxf(0.15, remaining)

static func _wind_stock_cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x * 2.0), floori(at.y * 2.0))

func _index_wind_stock() -> void:
	# Each query can only see centres within 1.2 m. Expanded bounds let
	# probes read a single bucket in the original wood/stored order.
	var extent := Vector2.ONE * 1.201
	for pieces in [wood, stored]:
		for piece: Piece in pieces:
			if piece.pose == null:
				continue
			var first := _wind_stock_cell(piece.pose.at - extent)
			var last := _wind_stock_cell(piece.pose.at + extent)
			for x in range(first.x, last.x + 1):
				for y in range(first.y, last.y + 1):
					wind_stock_cells.get_or_add(Vector2i(x, y), []).append(piece)
	wind_stock_indexed = true

func _invalidate_wind_stock() -> void:
	wind_stock_indexed = false
	wind_stock_cells.clear()

func airflow() -> float:
	var peak := background_wind(Vector2.ZERO).length()
	for breath in breaths:
		peak = maxf(peak, breath.strength * _envelope(breath))
	return peak

func breath_at(at: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for breath in breaths:
		var offset := at - breath.origin
		var along := offset.dot(breath.direction)
		if along <= 0.0 or along >= breath.reach + 0.34:
			continue
		var side := absf(offset.cross(breath.direction))
		var cone := 0.075 + along * 0.27
		var falloff := (1.0 - smoothstep(0.015, cone, side))
		falloff *= smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(breath.reach, breath.reach + 0.34, along))
		falloff /= 1.0 + along * along * 1.3
		result += breath.direction * (breath.strength * _envelope(breath) * falloff)
	return result.limit_length(3.2)

func _envelope(breath: Breath) -> float:
	return smoothstep(-0.18, 0.20, breath.age) * (1.0 - smoothstep(breath.duration * 0.70, breath.duration, breath.age))

func wind_at(at: Vector2, height := 0.05) -> Vector2:
	return background_wind(at, height) + breath_at(at)

func send_breath(origin: Vector2, target: Vector2, strength: float, duration: float) -> Breath:
	if origin.distance_squared_to(target) < 0.005 or breaths.size() >= 12:
		return null
	var breath := Breath.new()
	breath.origin = origin
	breath.direction = origin.direction_to(target)
	breath.reach = minf(2.4, origin.distance_to(target))
	breath.strength = clampf(strength, 0.0, 3.2)
	breath.duration = clampf(duration, 0.5, 3.5)
	breaths.append(breath)
	return breath

func add_fuel(kind: int, at: Vector2, yaw := INF, lean := 0.0, tier := 0, precise := false, quantity := 1.0,
		fed_pose: Structure.Pose = null) -> Piece:
	if kind < 0 or kind >= SPECIES.size() or wood.size() >= MAX_WOOD:
		return null
	if shelter != null:
		var parcel := stock_piece(kind)
		if parcel == null or quantity != 1.0:
			return null
		if fed_pose != null:
			return parcel if feed_stock(parcel, fed_pose) else null
		var angle := parcel.axis.angle() if is_inf(yaw) else yaw
		return parcel if pose_fuel(parcel, at, angle, lean, tier, precise) else null
	var amount := clampf(quantity, 0.1, 12.0) if kind in [4, 5] else 1.0
	if kind == TINDER_BUNDLE:
		return null
	var piece := _make_fuel(kind, at, yaw, lean, tier, precise, amount, fed_pose)
	wood.append(piece)
	_settle()
	_arm_roll(piece)
	return piece

func _make_fuel(kind: int, at: Vector2, yaw: float, lean: float, tier: int, precise: bool, amount: float,
		fed_pose: Structure.Pose = null, moisture := -1.0) -> Piece:
	var fuel: Dictionary = SPECIES[kind]
	var piece := Piece.new()
	piece.id = next_id
	next_id += 1
	piece.kind = kind
	piece.material = FUEL_MATERIAL[kind]
	var profile: Dictionary = Materials.PROFILES[piece.material]
	piece.specific_heat = profile.specific_heat
	piece.drying_factor = profile.drying
	piece.oxidation_factor = profile.char_oxidation
	piece.moisture_capacity = profile.water_capacity
	piece.yield_char = fuel.get("yield", profile.char_yield)
	piece.crumbling = profile.crumble
	piece.fibre = kind in [4, 5, LEAVES, TINDER_BUNDLE]
	piece.at = work_point(at)
	piece.volume = float(fuel.get("volume", float(fuel.get("mass", 0.0)) / float(profile.density))) * amount
	piece.original = piece.volume * float(profile.density)
	piece.wood = piece.original
	piece.size = fuel.size
	piece.radius = Structure.radius(kind)
	piece.original_radius = piece.radius
	piece.upper_radius = piece.radius
	piece.lower_radius = piece.radius
	var wood_density := piece.original / (TAU * piece.size * piece.radius * piece.radius)
	# Thick continuous fuel retains a denser char skeleton than loose fibres.
	# The density range is relative to the project's scaled fuel dimensions.
	var compactness := 0.28 * smoothstep(50.0, 135.0, wood_density)
	compactness += 0.72 * smoothstep(0.025, 0.065, piece.radius)
	piece.char_density = lerpf(185.0, 330.0, compactness)
	piece.char_porosity = lerpf(0.53, 0.34, compactness)
	piece.water = piece.wood * (float(fuel.water) if moisture < 0.0 else clampf(moisture, 0.0, piece.moisture_capacity))
	piece.temperature = ambient()
	piece.axis = Vector2.from_angle(default_yaw(piece.id) if is_inf(yaw) else yaw)
	piece.lean = lean
	piece.tier = tier
	piece.precise = precise or kind >= 4
	piece.inertia = float(fuel.get("inertia", 0.008)) * amount
	piece.fibre_spread = maxf(0.0, amount - 1.0) * 0.00115 if piece.fibre else 0.0
	if kind == TINDER_BUNDLE:
		var loft := sqrt(clampf(amount, 1.0, 7.0))
		piece.size *= loft
		piece.fibre_spread = 0.0048 * loft
	piece.area_scale = fuel.get("area", 1.0)
	var count: int = fuel.get("segments", 2 if kind in [2, 3] else 1)
	if fed_pose != null:
		piece.fed = true
		piece.pose = fed_pose
		if count == 1:
			count = 3
			piece.inertia /= 3.0
	if count > 1:
		_slice_wood(piece, count, kind >= 10 or (precise and piece.radius >= 0.05))
	if shelter != null and shelter.after_storm:
		_seed_resin(piece)
	return piece

func receive_fuel(kind: int, at: Vector2, yaw: float, tier: int, moisture := -1.0) -> Piece:
	var piece := _make_fuel(kind, at, yaw, 0.0, tier, true, 1.0, null, moisture)
	_mark_rest(piece)
	stored.append(piece)
	storage_dirty = true
	storage_revision += 1
	return piece

func seat_new_stock() -> void:
	_invalidate_wind_stock()
	# A new delivery needs a pose immediately. Existing pieces keep their
	# rests and any fall in progress until the simulation advances.
	var arrivals := stored.filter(func(piece: Piece): return piece.pose == null)
	arrivals.sort_custom(func(a: Piece, b: Piece):
		return a.tier < b.tier if a.tier != b.tier else a.rest_order < b.rest_order)
	for piece in arrivals:
		piece.pose = preview(piece.kind, piece.at, piece.axis.angle(), piece.lean, piece.tier, piece.id, piece.precise)
		_sync_seated_piece(piece)
	supports_dirty = true
	revision += 1

func all_fuel() -> Array[Piece]:
	if stored.is_empty():
		return wood
	return wood + stored

func has_fuel(piece: Piece) -> bool:
	return piece in wood or piece in stored

func workable_tinder() -> Array[Piece]:
	return all_fuel().filter(func(piece: Piece) -> bool:
		return _can_work_tinder(piece))

func tinder_in_use(piece: Piece) -> bool:
	return not tinder_job.is_empty() and (piece.id == tinder_job.first or piece.id == tinder_job.second)

func cancel_tinder_work() -> void:
	tinder_job.clear()

func _can_work_tinder(piece: Piece) -> bool:
	return piece != null and piece.kind in RAW_TINDER and not piece.airborne and not piece.rolling \
		and piece.wood >= piece.original * 0.85 and piece.charred_wood <= 0.000001 and piece.temperature < 75.0

func fuel_by_id(id: int) -> Piece:
	for piece in all_fuel():
		if piece.id == id:
			return piece
	return null

func queue_tinder_bundle(first: Piece, second: Piece) -> bool:
	if not tinder_job.is_empty() or first == second or not has_fuel(first) or not has_fuel(second) \
			or not _can_work_tinder(first) or not _can_work_tinder(second):
		return false
	tinder_job = {"first": first.id, "second": second.id, "remaining": TINDER_WORK_TIME}
	return true

func _step_tinder_work(dt: float) -> void:
	if tinder_job.is_empty():
		return
	tinder_job.remaining = maxf(0.0, float(tinder_job.remaining) - dt)
	if tinder_job.remaining > 0.0:
		return
	var first := fuel_by_id(tinder_job.first)
	var second := fuel_by_id(tinder_job.second)
	tinder_job.clear()
	tinder_finished.emit(prepare_tinder_bundle(first, second))

func prepare_tinder_bundle(first: Piece, second: Piece) -> Piece:
	if first == second or not _can_work_tinder(first) or not _can_work_tinder(second) \
			or not has_fuel(first) or not has_fuel(second):
		return null
	var combined := first.wood + second.wood
	var amount := combined / float(SPECIES[TINDER_BUNDLE].mass)
	var bundle := _make_fuel(TINDER_BUNDLE, first.at, first.axis.angle(), 0.0, first.tier, true, amount)
	bundle.water = first.water + second.water
	bundle.temperature = (first.temperature * first.capacity() + second.temperature * second.capacity()) \
		/ (first.capacity() + second.capacity())
	for piece in [first, second]:
		wood.erase(piece)
		stored.erase(piece)
	if shelter != null and not in_hearth(bundle.at):
		_mark_rest(bundle)
		stored.append(bundle)
		storage_dirty = true
	else:
		wood.append(bundle)
	storage_revision += 1
	_settle()
	return bundle

func in_hearth(at: Vector2) -> bool:
	return (at / LIMIT).length_squared() <= 1.000001

func work_point(at: Vector2) -> Vector2:
	if shelter == null:
		return (at / LIMIT).limit_length() * LIMIT
	return at.clamp(Shelter.YARD.position, Shelter.YARD.end)

func _in_stock(piece: Piece) -> bool:
	return not in_hearth(piece.at) and not piece.airborne and piece.wood > 0.000001 and not tinder_in_use(piece)

func stock_piece(kind: int, wet_only := false) -> Piece:
	var fallback: Piece
	var best_rank := 4
	var best_wetness := INF
	var after_storm := shelter != null and shelter.after_storm
	for piece in all_fuel():
		if piece.kind != kind or not _in_stock(piece):
			continue
		var wetness := piece.water / piece.original
		var wet := wetness >= 0.34
		if wet_only and not wet:
			continue
		var rank := int(after_storm and Shelter.protected_storage(piece.at)) + int(after_storm and wet and not wet_only) * 2
		if after_storm and wet_only and Shelter.warming_edge(piece.at):
			rank += 2
		if rank == 0 and not wet_only:
			return piece
		if rank < best_rank or (wet_only and rank == best_rank and wetness < best_wetness):
			best_rank = rank
			best_wetness = wetness
			fallback = piece
	return fallback

func _slice_wood(piece: Piece, count: int, granular: bool) -> void:
	var kind := piece.kind
	var profile: Dictionary = Materials.PROFILES[piece.material]
	_make_faces(piece, piece.id)
	for end in range(count):
		var section := Piece.new()
		section.id = piece.id * 5 + end
		section.kind = kind
		section.material = piece.material
		section.specific_heat = piece.specific_heat
		section.drying_factor = piece.drying_factor
		section.oxidation_factor = piece.oxidation_factor
		section.moisture_capacity = piece.moisture_capacity
		section.yield_char = piece.yield_char
		section.crumbling = piece.crumbling
		section.size = piece.size
		section.fraction = 1.0 / count
		section.original = piece.original * section.fraction
		section.volume = piece.volume * section.fraction
		section.wood = section.original
		section.water = piece.water * section.fraction
		section.temperature = piece.temperature
		section.inertia = piece.inertia
		section.char_density = piece.char_density
		section.char_porosity = piece.char_porosity
		section.original_radius = piece.original_radius
		section.radius = piece.original_radius
		section.upper_radius = piece.original_radius
		section.lower_radius = piece.original_radius
		var twist: float = profile.twist * (0.6 + 0.4 * sin(piece.id * 2.17))
		section.grain_angle = piece.id * 1.36 + end * twist
		section.grain_tilt = 0.12 + absf(twist) * (0.7 + 0.3 * sin(section.grain_angle))
		section.axial_coupling = Materials.coupling(piece.material, section.grain_tilt, section.grain_angle, 0) / 1.64
		section.radial_coupling = Materials.coupling(piece.material, section.grain_tilt, section.grain_angle, 1)
		section.tangent_coupling = Materials.coupling(piece.material, section.grain_tilt, section.grain_angle, 2)
		_make_faces(section, piece.id, granular)
		piece.sections.append(section)

func default_yaw(id: int) -> float:
	return (fposmod(sin(id * 83.0 * 12.9898 + 78.233) * 43758.5453, 1.0) - 0.5) * 1.07

func add_fed_fuel(kind: int, proposed: Structure.Pose) -> Piece:
	if kind not in [1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13]:
		return null
	var landing := Feeding.rest(self, proposed, Structure.radius(kind))
	if landing == null:
		return null
	return add_fuel(kind, landing.at, landing.axis.angle(), landing.slope, _feeding_tier(landing), true, 1.0, landing)

func feed_stock(piece: Piece, landing: Structure.Pose) -> bool:
	if not has_fuel(piece) or not _in_stock(piece) or not in_hearth(landing.at) or (piece in stored and wood.size() >= MAX_WOOD):
		return false
	if piece.sections.is_empty():
		_promote_stick(piece)
	if piece in stored:
		stored.erase(piece)
		wood.append(piece)
	piece.at = landing.at
	piece.axis = landing.axis
	piece.lean = landing.slope
	piece.tier = _feeding_tier(landing)
	piece.pose = landing
	piece.fed = true
	piece.precise = true
	piece.airborne = false
	_mark_rest(piece)
	storage_dirty = true
	storage_revision += 1
	_settle(true, 0.0, piece)
	return true

func feed_fuel(piece: Piece, proposed: Structure.Pose) -> bool:
	if piece not in wood or piece.fibre:
		return false
	var path := Feeding.sweep(self, piece.pose, proposed, piece.radius, piece)
	if (path == null or path.at.distance_to(proposed.at) > 0.0001 or absf(path.height - proposed.height) > 0.0001 or
			not path.axis.is_equal_approx(proposed.axis) or not is_equal_approx(path.slope, proposed.slope)):
		return false
	var landing := Feeding.rest(self, proposed, piece.radius, piece)
	if landing == null:
		return false
	if piece.sections.is_empty():
		_promote_stick(piece)
	piece.at = landing.at
	piece.axis = landing.axis
	piece.lean = landing.slope
	piece.tier = _feeding_tier(landing)
	piece.pose = landing
	piece.fed = true
	piece.precise = true
	piece.airborne = false
	_settle()
	return true

func _feeding_tier(landing: Structure.Pose) -> int:
	var tier := -64
	for support in wood:
		if support.id in landing.supports:
			tier = maxi(tier, support.tier)
	return tier

func _promote_stick(piece: Piece) -> void:
	var state := {}
	for property in ["wood", "water", "char_mass", "mineral", "gas", "shed", "charred_wood", "smoldered"]:
		state[property] = piece.get(property)
	piece.inertia /= 3.0
	_slice_wood(piece, 3, false)
	for section in piece.sections:
		for cell: Piece in section.faces + [section.core]:
			for property: String in state:
				var share := cell.original / piece.original
				if property not in ["wood", "water"]:
					share = cell.original / (piece.original * 0.54) if cell.layer != 0 else 0.0
				cell.set(property, float(state[property]) * share)
	if piece.resin_seed != 0:
		var pocket := piece.sections[posmod(piece.id * 7, piece.sections.size())].faces[posmod(piece.id, 2)]
		pocket.resin_seed = piece.resin_seed
		pocket.resin = piece.resin
		pocket.pocket_pressure = piece.pocket_pressure
		pocket.pops = piece.pops
		piece.resin = 0.0
	_sync_sections(piece)

func lift_coal(coal: Piece) -> bool:
	if coal not in coals or coal.carried:
		return false
	coal.carried = true
	coal.height = 0.12
	_reindex()
	_settle()
	return true

func carry_coal(coal: Piece, at: Vector2) -> void:
	if coal in coals and coal.carried:
		coal.at = (at / LIMIT).limit_length() * LIMIT
		coal.height = 0.12
		_reindex()
	_settle()

func deposit_coal(coal: Piece, at: Vector2) -> bool:
	if coal not in coals or not coal.carried:
		return false
	var radius := minf(0.025, coal.size * 0.40)
	var bundle := tinder_bundle_at(at)
	var landing := at if bundle == null else bundle.at
	var height := 0.0 if bundle == null else bundle.height
	var position := Feeding.pose(landing, 0.002, 0.0, 0.0, maxf(radius, height))
	if not Feeding.clear(self, position, radius):
		return false
	coal.at = landing
	coal.height = height
	coal.carried = false
	_reindex()
	_settle()
	return true

func tinder_bundle_at(at: Vector2) -> Piece:
	var nearest: Piece
	var distance := 0.058
	for piece in wood:
		if piece.kind != TINDER_BUNDLE or piece.airborne or piece.wood < piece.original * 0.10:
			continue
		var gap := piece.at.distance_to(at)
		if gap < distance:
			nearest = piece
			distance = gap
	return nearest

func _make_faces(piece: Piece, owner: int, granular := false) -> void:
	var slots := [1, -1, 0, 2, -2] if granular else [1, -1, 0]
	for slot in slots:
		var part := Piece.new()
		part.kind = piece.kind
		part.material = piece.material
		part.specific_heat = piece.specific_heat
		part.drying_factor = piece.drying_factor
		part.oxidation_factor = piece.oxidation_factor
		part.moisture_capacity = piece.moisture_capacity
		part.yield_char = piece.yield_char
		part.crumbling = piece.crumbling
		part.owner = owner
		part.layer = slot
		part.size = piece.size
		part.fraction = piece.fraction
		part.inertia = piece.inertia
		var ratio := 0.46 if slot == 0 else 0.27
		if granular and abs(slot) != 1:
			ratio = 0.28 if slot == 0 else 0.09
			part.inertia *= ratio / 0.46
		part.original = piece.original * ratio
		part.volume = piece.volume * ratio
		part.wood = part.original
		part.water = piece.water * (0.58 * ratio / 0.46 if abs(slot) != 1 else 0.21)
		part.temperature = piece.temperature
		part.char_density = piece.char_density
		part.char_porosity = piece.char_porosity
		if slot == 0:
			piece.core = part
		elif abs(slot) == 2:
			piece.inner.append(part)
		else:
			piece.faces.append(part)

func _prime(piece: Piece, top: float, bottom: float, center: float) -> void:
	for section in piece.sections:
		section.faces[0].temperature = top
		section.faces[1].temperature = bottom
		section.core.temperature = center
		for region in section.inner:
			region.temperature = center
		section.faces[0].water *= 0.13
		section.faces[1].water *= 0.08
	_sync_sections(piece)

func move_fuel(piece: Piece, at: Vector2) -> void:
	pose_fuel(piece, at, piece.axis.angle(), piece.lean, piece.tier, piece.precise)

func pose_fuel(piece: Piece, at: Vector2, yaw: float, lean: float, tier: int, precise := false) -> bool:
	if not has_fuel(piece) or tinder_in_use(piece):
		return false
	var next := work_point(at)
	var moved := not piece.at.is_equal_approx(next)
	if piece in stored and in_hearth(next):
		if wood.size() >= MAX_WOOD:
			return false
		stored.erase(piece)
		wood.append(piece)
	piece.at = next
	piece.axis = Vector2.from_angle(yaw)
	piece.lean = clampf(lean, -Structure.MAX_SLOPE, Structure.MAX_SLOPE)
	piece.tier = clampi(tier, -64, 64)
	piece.precise = precise or piece.precise
	piece.fed = false
	piece.airborne = false
	piece.fall_speed = 0.0
	piece.rolling = false
	piece.roll_velocity = Vector2.ZERO
	if shelter != null:
		if moved:
			_mark_rest(piece)
		storage_dirty = true
		storage_revision += 1
		_refresh_storage_membership()
	_settle(shelter != null, 0.0, piece)
	_arm_roll(piece)
	return true

func preview(kind: int, at: Vector2, yaw: float, lean: float, tier: int, id: int, precise := false) -> Structure.Pose:
	var below: Array[Piece] = []
	var thickness := Structure.radius(kind)
	var body: Piece
	var length: float = SPECIES[kind].size
	var bodies := all_fuel()
	var order := id
	for support in bodies:
		if support.id == id:
			thickness = support.radius
			length = support.size
			body = support
			if shelter != null:
				order = _rest_order(body) if body.at.is_equal_approx(work_point(at)) else next_rest_order
			break
	for support in bodies:
		if support != body and support.pose != null and support.can_support and not support.airborne and (support.tier < tier or (support.tier == tier and _rest_order(support) < order)):
			below.append(support)
	return Structure.seat(work_point(at), Vector2.from_angle(yaw),
		length, thickness, lean, below, coals, precise, body)

func _settle(gravity := false, fall_step := 0.0, moved_piece: Piece = null) -> void:
	_invalidate_wind_stock()
	revision += 1
	supports_dirty = false
	wear_dirty = false
	last_settle = time
	network_dirty = true
	var ordered := all_fuel().duplicate()
	ordered.sort_custom(func(a: Piece, b: Piece) -> bool:
		if a.tier != b.tier:
			return a.tier < b.tier
		var first := _rest_order(a)
		var second := _rest_order(b)
		return a.id < b.id if first == second else first < second)
	var below: Array[Piece] = []
	var next_seats := {}
	var next_geometry := {}
	var settle_pile := storage_dirty or stored.any(_moving_fuel) or (shelter != null and wood.any(func(piece: Piece): return not in_hearth(piece.at)))
	for piece: Piece in ordered:
		if not settle_pile and piece in stored and piece.pose != null and not _moving_fuel(piece):
			if seat_cache.has(piece.id):
				next_seats[piece.id] = seat_cache[piece.id]
			if piece.can_support:
				below.append(piece)
				_remember_support_geometry(piece, next_geometry)
			continue
		var thickness := piece.radius
		var previous := piece.pose
		var rests := below
		if shelter != null:
			rests = below.filter(func(support: Piece):
				return support.at.distance_squared_to(piece.at) <= pow(piece.size + support.size + piece.radius + support.radius, 2.0))
		if piece.airborne:
			# The freshly separated ends share an axis, but their rims cannot catch on each other.
			rests = rests.filter(func(support): return support.split_family != piece.split_family)
		var seat_inputs: Array = []
		if shelter != null and not piece.fed and not _moving_fuel(piece):
			# Reuse a stable seat only when every input to the fit agrees.
			# This includes potential supports in the original order, so changes
			# propagate upward through an entire stack in this same pass.
			seat_inputs = _seat_inputs(piece, rests, next_geometry)
			var cached: Array = seat_cache.get(piece.id, [])
			if not cached.is_empty() and cached[1] == previous and cached[0] == seat_inputs:
				next_seats[piece.id] = cached
				# Worn upper faces can need new thermal coordinates even when
				# the underside fits exactly as it did before.
				if piece in wood:
					_sync_seated_piece(piece)
				if piece.can_support:
					below.append(piece)
					_remember_support_geometry(piece, next_geometry)
				continue
		piece.pose = Structure.seat(piece.at, piece.axis, piece.size, thickness, piece.lean, rests, coals, piece.precise, piece,
			previous if piece.fed else null)
		if piece.airborne:
			var drop := piece.fall_speed * fall_step + 0.5 * GRAVITY * fall_step * fall_step
			piece.fall_speed += GRAVITY * fall_step
			if previous.height - drop > piece.pose.height + 0.004:
				previous.height -= drop
				piece.pose = previous
			else:
				piece.airborne = false
				piece.fall_speed = 0.0
				_arm_roll(piece, rests)
				if shelter != null and not in_hearth(piece.at):
					storage_revision += 1
		elif gravity and piece != moved_piece and previous != null and previous.height - piece.pose.height > 0.025:
			piece.airborne = true
			piece.pose = previous
			structure_event.emit("shift", piece.at, piece.mass(), previous.height, piece.temperature)
		if not piece.airborne and piece.rolling and fall_step > 0.0:
			_gravity_rest(piece, rests, ordered, fall_step)
		_sync_seated_piece(piece)
		if not seat_inputs.is_empty() and not _moving_fuel(piece):
			next_seats[piece.id] = [seat_inputs, piece.pose]
		if piece.can_support and not piece.airborne:
			below.append(piece)
			if shelter != null:
				_remember_support_geometry(piece, next_geometry)
	_apply_weight(ordered)
	seat_cache = next_seats
	support_geometry = next_geometry
	storage_dirty = false

func _seat_inputs(piece: Piece, rests: Array[Piece], current_geometry: Dictionary) -> Array:
	var lower_profile: Array = [piece.lower_radius]
	for section in piece.sections:
		lower_profile.append([section.id, section.lower_radius, section.faces[0].id])
	var neighbors := PackedInt32Array()
	for support in rests:
		neighbors.append(current_geometry[support.id][1])
	var ground := []
	# Samples never extend past the log's length. Coal support reaches 0.09 farther.
	var reach := piece.size + 0.091
	for coal in coals:
		if not coal.carried and coal.at.distance_squared_to(piece.at) <= reach * reach:
			ground.append([coal.id, coal.at, Structure.coal_level(coal.char_mass)])
	return [piece.at, piece.axis, piece.size, piece.radius, piece.lean, piece.precise,
		piece.centre_of_mass, lower_profile, neighbors, ground]

func _remember_support_geometry(piece: Piece, current_geometry: Dictionary) -> void:
	var pose := piece.pose
	var profile := [piece.at, piece.axis, pose.height, pose.slope, pose.span,
		piece.radius, piece.upper_radius, piece.integrity, piece.crushed]
	for section in piece.sections:
		profile.append([section.upper_radius, section.integrity, section.crushed])
	var cached: Array = support_geometry.get(piece.id, [])
	if not cached.is_empty() and cached[0] == profile:
		current_geometry[piece.id] = cached
		return
	support_geometry_serial += 1
	current_geometry[piece.id] = [profile, support_geometry_serial]

func _sync_seated_piece(piece: Piece) -> void:
	piece.height = piece.pose.height
	piece.heat_axis = _heat_axis(piece.pose, 1.0)
	for i in range(piece.sections.size()):
		var section := piece.sections[i]
		var center := piece.pose.point(piece.pose.span * 1.04 * ((2.0 * i + 1.0) / piece.sections.size() - 1.0))
		section.at = Vector2(center.x, center.y)
		section.axis = piece.axis
		section.height = center.z
		for face in section.faces:
			face.at = section.at
			face.axis = piece.axis
			var local_radius := section.upper_radius if face.layer > 0 else section.lower_radius
			face.height = section.height + face.layer * local_radius * 0.68
			face.heat_axis = _heat_axis(piece.pose, 1.0 / piece.sections.size())
			face.precise = piece.precise
			face.radius = local_radius

func _mark_rest(piece: Piece) -> void:
	piece.rest_order = next_rest_order
	next_rest_order += 1

func _rest_order(piece: Piece) -> int:
	return piece.rest_order if piece.rest_order > 0 else piece.id

func _moving_fuel(piece: Piece) -> bool:
	return piece.airborne or piece.rolling

func _arm_roll(piece: Piece, available: Array[Piece] = []) -> void:
	if not piece.precise or piece.fed or piece.radius < 0.045 or piece.pose.supports.size() != 1 or piece.pose.supports[0] <= 0:
		return
	var supports := all_fuel() if available.is_empty() else available
	for support in supports:
		if support.id != piece.pose.supports[0]:
			continue
		# Deliberately crossed and propped arrangements keep their placement.
		# Round, near-parallel logs are free to roll off a single crown.
		if available.is_empty() and (absf(piece.axis.dot(support.axis)) < 0.72 or absf(piece.pose.slope) > 0.18):
			return
		var weight := piece.at + piece.axis * (piece.pose.span * piece.centre_of_mass)
		var offset := weight - support.at
		var closest := support.axis * clampf(offset.dot(support.axis), -support.pose.span, support.pose.span)
		if (offset - closest).length() > maxf(0.009, piece.radius * 0.18):
			piece.rolling = true
		return

func _gravity_rest(piece: Piece, below: Array[Piece], bodies: Array[Piece], dt: float) -> void:
	var start := piece.pose
	var side := piece.axis.orthogonal()
	var inertia := piece.roll_velocity
	var travel := clampf((inertia.length() + dt * 0.38) * dt, 0.013, 0.045)
	var best := start
	var best_work := 0.00065
	var directions := [side, -side, piece.axis, -piece.axis,
		(side + piece.axis).normalized(), (side - piece.axis).normalized(),
		(-side + piece.axis).normalized(), (-side - piece.axis).normalized()]
	for direction: Vector2 in directions:
		var position := work_point(piece.at + direction * travel)
		if position.distance_squared_to(piece.at) < 0.000025:
			continue
		var yaw := direction.dot(side) * travel * piece.centre_of_mass * 1.8
		var candidate := Structure.seat(position, piece.axis.rotated(yaw),
			piece.size, piece.radius, start.slope, below, coals, true, piece)
		var drop := start.height - candidate.height + (start.slope * start.span - candidate.slope * candidate.span) * piece.centre_of_mass
		var work := drop + maxf(0.0, direction.dot(inertia) - dt * 0.22) * travel * 0.16
		if drop >= -0.001 and work > best_work and _roll_clear(piece, candidate, bodies):
			best = candidate
			best_work = work
	if best == start:
		piece.rolling = false
		piece.roll_velocity = Vector2.ZERO
		return
	var slide := best.at - piece.at
	piece.roll_velocity = slide / dt
	piece.roll_travel += slide.dot(side)
	if not piece.faces.is_empty() and absf(piece.roll_travel) >= piece.radius * PI * 0.5:
		_roll_faces(piece)
		piece.roll_travel -= signf(piece.roll_travel) * piece.radius * PI
		best = Structure.seat(best.at, best.axis, piece.size, piece.radius, best.slope, below, coals, true, piece)
	piece.pose = best
	if shelter != null and in_hearth(piece.at) != in_hearth(best.at):
		storage_revision += 1
	piece.at = best.at
	piece.axis = best.axis
	piece.lean = best.slope

func _roll_clear(piece: Piece, candidate: Structure.Pose, bodies: Array[Piece]) -> bool:
	for other in bodies:
		if other == piece or other.pose == null or other.airborne or other.id in candidate.supports:
			continue
		if candidate.at.distance_squared_to(other.at) > pow(piece.size + other.size + piece.radius + other.radius, 2.0):
			continue
		var target := other.pose
		var nearest := Geometry3D.get_closest_points_between_segments(candidate.point(-candidate.span), candidate.point(candidate.span),
			target.point(-target.span), target.point(target.span))
		var clearance := (piece.radius + other.radius) * 0.84
		if nearest[0].distance_squared_to(nearest[1]) >= clearance * clearance:
			continue
		var start := piece.pose
		var old := Geometry3D.get_closest_points_between_segments(start.point(-start.span), start.point(start.span),
			target.point(-target.span), target.point(target.span))
		if nearest[0].distance_squared_to(nearest[1]) < old[0].distance_squared_to(old[1]) - 0.000001:
			return false
	return true

func _apply_weight(ordered: Array[Piece]) -> void:
	var by_id := {}
	for piece in ordered:
		by_id[piece.id] = piece
		piece.carried_load = 0.0
		piece.contact_load = 0.0
		for section in piece.sections:
			section.contact_load = 0.0
	for i in range(ordered.size() - 1, -1, -1):
		var piece := ordered[i]
		if piece.airborne:
			continue
		var load := (piece.mass() * GRAVITY + piece.carried_load) / maxf(1.0, piece.pose.contacts.size())
		for j in range(piece.pose.contacts.size()):
			var support: Piece = by_id.get(piece.pose.contact_ids[j])
			if support == null:
				continue
			var contact := piece.pose.contacts[j]
			var along := (Vector2(contact.x, contact.y) - support.at).dot(support.axis) / support.pose.span
			var region := support.cross_section(along)
			region.contact_load += load
			support.carried_load += load
			if not region.crushed and region.integrity < 0.48 and region.contact_load > region.bearing_limit():
				region.crushed = true
				supports_dirty = true

func _heat_axis(pose: Structure.Pose, fraction: float) -> Vector3:
	var projected := pose.axis * pose.span * fraction
	return Vector3(projected.x, pose.span * fraction * pose.slope, projected.y)

func turn_fuel(piece: Piece) -> bool:
	if not has_fuel(piece) or piece.faces.is_empty():
		return false
	_roll_faces(piece)
	piece.roll_travel = 0.0
	if piece in stored:
		storage_dirty = true
	_settle()
	_sync_sections(piece)
	return true

func _roll_faces(piece: Piece) -> void:
	piece.faces.reverse()
	piece.faces[0].layer = 1
	piece.faces[1].layer = -1
	for section in piece.sections:
		section.faces.reverse()
		section.faces[0].layer = 1
		section.faces[1].layer = -1
		section.inner.reverse()
		section.grain_angle += PI
		var upper := section.upper_radius
		section.upper_radius = section.lower_radius
		section.lower_radius = upper

func rake() -> void:
	uncover()
	rake_at(Vector2.ZERO, Vector2.ZERO, 2.0)

func rake_at(source: Vector2, target: Vector2, radius := 0.35) -> int:
	var moved := 0
	for coal in coals:
		if coal.carried or coal.at.distance_to(source) > radius:
			continue
		var desired := target + (coal.at - source) * 0.59
		coal.at = (desired / LIMIT).limit_length() * LIMIT
		moved += 1
	if moved > 0:
		_reindex()
		_settle()
	return moved

func split_coal_at(at: Vector2, target: Vector2) -> int:
	var source: Piece
	var nearest := 0.18 * 0.18
	for coal in coals:
		if coal.carried:
			continue
		var distance := coal.at.distance_squared_to(at)
		if distance < nearest and coal.char_mass > 0.002:
			nearest = distance
			source = coal
	var destination := (target / LIMIT).limit_length() * LIMIT
	if source == null or source.at.distance_squared_to(destination) < 0.0144 or coals.size() >= MAX_PATCHES:
		return 0
	source.char_mass *= 0.5
	source.base_capacity *= 0.5
	source.cover *= 0.5
	source.mineral *= 0.5
	source.water *= 0.5
	source.original *= 0.5
	source.size *= 0.793700526
	source.char_heat *= 0.5
	var half := _new_coal(destination, source.char_mass, source.temperature, source.base_capacity,
		source.char_density, source.char_porosity)
	half.cover = source.cover
	half.mineral = source.mineral
	half.water = source.water
	half.original = source.original
	half.size = source.size
	half.char_heat = source.char_heat
	half.oxidation_factor = source.oxidation_factor
	half.trend = source.trend
	half.precise = source.precise
	_reindex()
	_settle()
	return 1

func _cell(at: Vector2) -> Vector2i:
	return Vector2i((at / CELL).round())

func _reindex() -> void:
	_invalidate_wind_stock()
	cells.clear()
	for coal in coals:
		if not coal.carried:
			cells[_cell(coal.at)] = coal

func bank() -> bool:
	var deposits := 0
	for coal in coals:
		if not coal.carried and coal.char_mass > 0.001:
			deposits += 1
	if deposits == 0 or ash < 0.001:
		return false
	var dose := minf(0.021, ash / deposits)
	for coal in coals:
		if not coal.carried and coal.char_mass > 0.001:
			_cover_coal(coal, dose)
			if shelter == null:
				ash -= dose
			else:
				_take_loose_ash(coal.at, dose)
	ash = maxf(0.0, ash)
	revision += 1
	return true

func uncover() -> void:
	revision += 1
	for coal in coals:
		if coal.carried:
			continue
		if shelter == null:
			ash += coal.cover
		else:
			_pile_ash(coal.at + Vector2(0.24, 0.12), coal.cover)
		coal.cover = 0.0

func _cover_coal(coal: Piece, dose: float) -> void:
	# The collected powder has cooled against the ground.
	var old_capacity := coal.capacity()
	coal.cover += dose
	coal.temperature = ambient() + (coal.temperature - ambient()) * old_capacity / coal.capacity()

static func ash_radius(mass: float) -> float:
	return clampf(0.07 + sqrt(mass) * 1.15, 0.08, 0.31)

func _pile_ash(at: Vector2, mass: float) -> void:
	if mass <= 0.0:
		return
	var cell := _cell(work_point(at))
	ash_piles[cell] = float(ash_piles.get(cell, 0.0)) + mass
	ash += mass

func _take_loose_ash(at: Vector2, mass: float, reach := INF) -> float:
	var cells_near: Array = ash_piles.keys()
	cells_near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) * CELL).distance_squared_to(at) < (Vector2(b) * CELL).distance_squared_to(at))
	var collected := 0.0
	for cell: Vector2i in cells_near:
		if (Vector2(cell) * CELL).distance_to(at) > reach or collected >= mass:
			break
		var take := minf(ash_piles[cell], mass - collected)
		collected += take
		ash_piles[cell] -= take
		if ash_piles[cell] <= 0.0:
			ash_piles.erase(cell)
	ash = maxf(0.0, ash - collected)
	return collected

func sweep_ash(from: Vector2, to: Vector2) -> float:
	if shelter == null or from.distance_to(to) < 0.05:
		return 0.0
	var collected := _take_loose_ash(from, INF, 0.22)
	for coal in coals:
		if not coal.carried and coal.at.distance_to(from) <= 0.22:
			collected += coal.mineral
			coal.mineral = 0.0
	var moved := collected
	var nearest: Piece
	var distance := 0.15
	for coal in coals:
		if not coal.carried and coal.char_mass > 0.001 and coal.at.distance_to(to) < distance:
			nearest = coal
			distance = coal.at.distance_to(to)
	if nearest != null and collected > 0.0:
		var dose := minf(0.021, collected)
		_cover_coal(nearest, dose)
		collected -= dose
	_pile_ash(to, collected)
	if moved > 0.0:
		revision += 1
	return moved

func blow() -> void:
	fan = minf(1.8, fan + 0.42)

func _prepare_network() -> void:
	network_dirty = false
	exchange_links.clear()
	nodes = coals.duplicate()
	for piece in wood:
		if piece.faces.is_empty():
			nodes.append(piece)
		else:
			for section in piece.sections:
				nodes.append_array(section.faces)
	_index_network_occluders()
	var pair_rows := _network_pair_rows()
	network_candidates = 0
	links.clear()
	radiant_links.clear()
	crowding.fill(0.0)
	crowding.resize(nodes.size())
	capacities.resize(nodes.size())
	insulations.resize(nodes.size())
	changes.resize(nodes.size())
	ember_heat.resize(coals.size())
	var loads := PackedFloat64Array()
	loads.resize(nodes.size())
	var flame_loads := PackedFloat64Array()
	flame_loads.resize(nodes.size())
	var fibre_contacts := PackedFloat64Array()
	fibre_contacts.resize(nodes.size())
	var ember_views := PackedFloat64Array()
	ember_views.resize(coals.size())
	var views := PackedFloat64Array()
	views.resize(nodes.size())
	var positions := PackedVector3Array()
	var area_weights := PackedFloat64Array()
	var caps := PackedFloat64Array()
	var span_squared := PackedFloat64Array()
	positions.resize(nodes.size())
	area_weights.resize(nodes.size())
	caps.resize(nodes.size())
	span_squared.resize(nodes.size())
	for i in nodes.size():
		var piece := nodes[i]
		positions[i] = _thermal_position(piece)
		area_weights[i] = _surface(piece) * 0.078
		caps[i] = 0.56 * piece.original / float(SPECIES[piece.kind].mass) if piece.fibre else 0.56
		span_squared[i] = maxf(0.0001, piece.heat_axis.length_squared())
	starter_ventilation.resize(nodes.size())
	starter_ventilation.fill(0.0)
	if wood.size() >= 5:
		for i in range(nodes.size()):
			var piece := nodes[i]
			if (piece.kind < 0 and piece.original <= 0.025 and not piece.carried) or piece.kind in STARTERS or piece.kind in PLUME_FUEL or piece.layer < 0:
				starter_ventilation[i] = _starter_passage(piece)
	for i in range(nodes.size()):
		var a := nodes[i]
		network_candidates += pair_rows[i].size()
		for j in pair_rows[i]:
			var b := nodes[j]
			if a.owner != 0 and a.owner == b.owner:
				continue
			var delta := b.at - a.at
			var distance := delta.length()
			var gap := absf(a.height - b.height)
			var reach := a.size + b.size + 0.17
			if a.kind < 0 and b.kind < 0:
				reach = 0.36
			elif distance > 0.0:
				var heading := delta / distance
				if a.layer != 0:
					reach -= a.size * 0.12 * absf(a.axis.cross(heading))
				if b.layer != 0:
					reach -= b.size * 0.12 * absf(b.axis.cross(heading))
			if distance >= reach or gap > 0.83:
				continue
			var link := Link.new()
			link.a = i
			link.b = j
			link.delta = delta
			link.proximity = 1.0 - distance / reach
			var contact := link.proximity * link.proximity
			link.conductance = contact * 0.43 / (1.0 + gap * gap * 14.0)
			var geometry := a.precise or b.precise
			if geometry:
				var solid := _solid_contact(a, b)
				if a.fibre and b.fibre:
					solid = maxf(solid, 0.28 * exp(-delta.length_squared() / 0.0072 - gap * gap / 0.0025))
				link.conductance *= solid
				if (starter_ventilation[i] > 0.0 or starter_ventilation[j] > 0.0) and (a.kind < 0 or b.kind < 0):
					var coal := a if a.kind < 0 else b
					var fuel := b if a.kind < 0 else a
					if coal.original <= 0.025 and not coal.carried and not fuel.fibre and not coal.at.is_equal_approx(fuel.at):
						# Across a real air gap, the little coal loses heat by radiation and gas flow.
						# The solid-contact approximation should not couple it to the entire cold stack.
						link.conductance *= lerpf(0.10, 1.0, smoothstep(0.12, 0.83, solid))
				elif a.fibre != b.fibre and a.kind >= 0 and b.kind >= 0 and (starter_ventilation[i] > 0.0 or starter_ventilation[j] > 0.0 \
						or a.kind == TINDER_BUNDLE or b.kind == TINDER_BUNDLE):
					link.conductance *= lerpf(0.0, 1.0, smoothstep(0.11, 0.78, solid))
					if a.kind == TINDER_BUNDLE or b.kind == TINDER_BUNDLE:
						# Loose folded leaves expose a small contact area to sticks.
						link.conductance *= 0.30
			if a.kind < 0 or b.kind < 0:
				var layer := a.layer + b.layer
				link.conductance *= 0.12 if layer > 0 else (1.22 if layer < 0 else 1.0)
				if a.kind != b.kind:
					link.coal = i if a.kind < 0 else j
					link.toward_wood = delta.normalized() if a.kind < 0 else -delta.normalized()
					if geometry:
						var fuel := b if link.coal == i else a
						var coal := a if link.coal == i else b
						if fuel.layer != 0:
							# A log rests on a few points. Its full face cannot conduct into the bed.
							link.conductance *= lerpf(1.0, 0.095, smoothstep(0.018, 0.061, coal.char_mass))
			elif a.layer != 0 and b.layer != 0:
				link.conductance *= 0.75 if a.layer != b.layer else 0.25
			elif a.layer != 0 or b.layer != 0:
				link.conductance *= 0.52
			var limit := link.conductance * (2.0 if link.coal >= 0 else 1.0)
			if a.fibre or b.fibre:
				var effective := _exchange_capacity(a, b, a.capacity(), b.capacity())
				loads[i] += limit * effective / a.capacity()
				loads[j] += limit * effective / b.capacity()
				link.fibre_contact = link.coal >= 0
				if link.fibre_contact:
					fibre_contacts[link.coal] += link.conductance * effective
			else:
				loads[i] += limit
				loads[j] += limit
			# Flames can reach upward through a gap. Downward feedback is weaker.
			var rise := b.height - a.height
			var passage_a := starter_ventilation[i]
			var passage_b := starter_ventilation[j]
			link.receive_a = (0.0756 * a.fraction if a.layer != 0 else 0.14) * _plume_reach(-rise)
			link.receive_b = (0.0756 * b.fraction if b.layer != 0 else 0.14) * _plume_reach(rise)
			if geometry:
				link.receive_a *= 1.72
				link.receive_b *= 1.72
				if passage_a > 0.0:
					link.receive_b *= 1.0 + passage_a * _rising_path(a, b)
				if passage_b > 0.0:
					link.receive_a *= 1.0 + passage_b * _rising_path(b, a)
				if (a.kind == TINDER_BUNDLE or (a.fibre and passage_a > 0.5)) and b.kind in [0, 6, 7, 1]:
					link.receive_b *= 1.0 + _starter_jet(a, b)
				elif (b.kind == TINDER_BUNDLE or (b.fibre and passage_b > 0.5)) and a.kind in [0, 6, 7, 1]:
					link.receive_a *= 1.0 + _starter_jet(b, a)
				if passage_a > 0.0 and a.kind in PLUME_FUEL and b.kind >= 0 and not b.fibre:
					link.receive_b *= 1.0 + 5.0 * passage_a * _nearby_flame_path(a, b)
				if passage_b > 0.0 and b.kind in PLUME_FUEL and a.kind >= 0 and not a.fibre:
					link.receive_a *= 1.0 + 5.0 * passage_b * _nearby_flame_path(b, a)
				if passage_a > 0.0 and a.kind in PLUME_FUEL and a.kind != 6 and b.layer < 0:
					link.receive_b *= 1.0 + 13.0 * passage_a * _upward_capture(a, b)
				if passage_b > 0.0 and b.kind in PLUME_FUEL and b.kind != 6 and a.layer < 0:
					link.receive_a *= 1.0 + 13.0 * passage_b * _upward_capture(b, a)
			if a.fibre:
				link.receive_a *= minf(3.0, a.original / float(SPECIES[a.kind].mass))
			if b.fibre:
				link.receive_b *= minf(3.0, b.original / float(SPECIES[b.kind].mass))
			if link.coal >= 0:
				var fuel := b if link.coal == i else a
				var coal := a if link.coal == i else b
				var receiving_area := (0.35 + fuel.size * 4.0) * fuel.area_scale
				if fuel.layer != 0:
					receiving_area *= fuel.fraction * (0.57 if fuel.layer < 0 else 0.14)
				if fuel.fibre:
					receiving_area *= fuel.original / float(SPECIES[fuel.kind].mass)
				link.ember_feedback = 0.34 * receiving_area * contact * (1.0 - smoothstep(0.08, 0.37, gap))
				if coal.original <= 0.025 and fuel.fibre and starter_ventilation[link.coal] > 0.0:
					var mass_scale: float = fuel.original / SPECIES[fuel.kind].mass
					link.ember_feedback += starter_ventilation[link.coal] * mass_scale * contact * (1.0 - smoothstep(0.025, 0.095, gap))
				if geometry and fuel.layer < 0:
					var lift := fuel.height - coal.height
					link.ember_feedback *= 1.0 + 11.0 * smoothstep(0.04, 0.11, lift) * (1.0 - smoothstep(0.24, 0.47, lift))
				ember_views[link.coal] += link.ember_feedback
			var from := positions[i]
			var to := positions[j]
			var direction := to - from
			if direction.length_squared() > 0.00000001:
				var visibility := _radiation_visibility(from, to, a, b) if geometry else 0.20
				var toward := direction.normalized()
				var nearest_a := direction - a.heat_axis * clampf(direction.dot(a.heat_axis) / span_squared[i], -0.85, 0.85)
				var nearest_b := -direction - b.heat_axis * clampf((-direction).dot(b.heat_axis) / span_squared[j], -0.85, 0.85)
				var facing_a := _facing(a, -toward)
				var facing_b := _facing(b, toward)
				link.view_a = minf(caps[i], area_weights[i] * 0.52 / (0.010 + nearest_a.length_squared())) * visibility * facing_b * facing_a
				link.view_b = minf(caps[j], area_weights[j] * 0.52 / (0.010 + nearest_b.length_squared())) * visibility * facing_a * facing_b
				views[i] += link.view_a
				views[j] += link.view_b
			# The greatest possible downwind reach bounds flame feedback for this link.
			var plume := link.proximity + distance * 0.324
			flame_loads[i] += plume * link.receive_b
			flame_loads[j] += plume * link.receive_a
			var parallel := 1.0 - absf(a.axis.cross(b.axis)) * 0.38 if a.kind >= 0 and b.kind >= 0 else 1.0
			var shielding := contact * parallel * (1.0 - smoothstep(0.18, 0.56, gap))
			if b.kind >= 0 and not b.fibre:
				crowding[i] += shielding * b.size * b.fraction * (1.75 if b.layer != 0 else 3.5)
			if a.kind >= 0 and not a.fibre:
				crowding[j] += shielding * a.size * a.fraction * (1.75 if a.layer != 0 else 3.5)
			if geometry and a.kind >= 0 and b.kind >= 0 and not a.fibre and not b.fibre and a.layer == 0 and b.layer == 0:
				# Stacked small pieces share the same narrow air path. Spaced rows do not.
				var overlap := 0.72 * exp(-delta.length_squared() / 0.006 - gap * gap / 0.021)
				crowding[i] += overlap
				crowding[j] += overlap
			links.append(link)
	for link in links:
		# Bound outgoing conduction even in a dense stack. Scale each link
		# symmetrically, and cap feedback to a fraction of each flame's energy.
		link.conductance /= maxf(1.0, 2.0 * STEP * maxf(loads[link.a], loads[link.b]))
		if link.fibre_contact:
			# The same coal surface cannot make full contact with every parcel.
			var coal := nodes[link.coal]
			link.conductance /= maxf(1.0, fibre_contacts[link.coal] / (coal.capacity() * 0.31))
		if link.ember_feedback > 0.0:
			# Only a fraction of the charcoal reaction's heat can reach fuel.
			link.ember_feedback /= maxf(1.0, ember_views[link.coal] / EMBER_FEEDBACK_LIMIT)
		link.view_a /= maxf(1.0, views[link.a] / RADIATION_CAPTURE_LIMIT)
		link.view_b /= maxf(1.0, views[link.b] / RADIATION_CAPTURE_LIMIT)
		if link.view_a > 0.0 or link.view_b > 0.0:
			radiant_links.append(link)
		link.receive_a /= maxf(1.0, flame_loads[link.b] / (0.69 if nodes[link.b].kind == TINDER_BUNDLE else 0.55))
		link.receive_b /= maxf(1.0, flame_loads[link.a] / (0.69 if nodes[link.a].kind == TINDER_BUNDLE else 0.55))
	for i in range(nodes.size()):
		# Open side inlets and an upward exit can ventilate a starter even
		# when several nearby surfaces contribute to the crowding estimate.
		crowding[i] *= lerpf(1.0, 0.25, starter_ventilation[i])

func _network_pair_rows() -> Array[PackedInt32Array]:
	if Native.enabled and nodes.size() >= 64 and nodes.size() <= 1024:
		var geometry := PackedFloat64Array()
		geometry.resize(nodes.size() * 6)
		var offset := 0
		for piece in nodes:
			geometry[offset] = piece.at.x
			geometry[offset + 1] = piece.at.y
			geometry[offset + 2] = piece.height
			geometry[offset + 3] = piece.size
			geometry[offset + 4] = piece.owner
			geometry[offset + 5] = piece.kind
			offset += 6
		var pairs: PackedFloat64Array = ClassDB.class_call_static(Native.KERNEL, &"candidate_pairs", geometry)
		if not pairs.is_empty():
			var rows: Array[PackedInt32Array] = []
			rows.resize(nodes.size())
			for i in range(0, pairs.size(), 2):
				rows[int(pairs[i])].append(int(pairs[i + 1]))
			return rows
	return _network_pair_rows_reference()

func _network_pair_rows_reference() -> Array[PackedInt32Array]:
	# The broad phase uses the largest possible reach before orientation
	# shortens it. Sort survivors by the original node index before exchange.
	var by_x: Array[int] = []
	var largest := 0.0
	for i in nodes.size():
		by_x.append(i)
		largest = maxf(largest, nodes[i].size)
	by_x.sort_custom(func(a, b): return nodes[a].at.x < nodes[b].at.x)
	var rows: Array[PackedInt32Array] = []
	rows.resize(nodes.size())
	for left in range(by_x.size()):
		var i := by_x[left]
		var a := nodes[i]
		var max_reach := maxf(0.36, a.size + largest + 0.17) + 0.00001
		for right in range(left + 1, by_x.size()):
			var j := by_x[right]
			var b := nodes[j]
			var dx := b.at.x - a.at.x
			if dx > max_reach:
				break
			if (a.owner != 0 and a.owner == b.owner) or absf(a.height - b.height) > 0.83:
				continue
			var reach := (0.36 if a.kind < 0 and b.kind < 0 else a.size + b.size + 0.17) + 0.00001
			if dx > reach or absf(a.at.y - b.at.y) > reach or a.at.distance_squared_to(b.at) > reach * reach:
				continue
			rows[mini(i, j)].append(maxi(i, j))
	for i in rows.size():
		rows[i].sort()
	return rows

const RADIATION_CELL := 0.25

func _index_network_occluders() -> void:
	network_occluders = wood.duplicate()
	occluder_centers.resize(wood.size())
	occluder_axes.resize(wood.size())
	occluder_inverse_axis.resize(wood.size())
	occluder_radius.resize(wood.size())
	occluder_lower.resize(wood.size())
	occluder_upper.resize(wood.size())
	radiation_cells.clear()
	airflow_cells.clear()
	for i in wood.size():
		var piece := wood[i]
		var center := _thermal_position(piece)
		var axis := piece.heat_axis
		var radius := piece.radius
		occluder_centers[i] = center
		occluder_axes[i] = axis
		occluder_inverse_axis[i] = maxf(0.0001, axis.length_squared())
		occluder_radius[i] = radius
		# The ray tests in the network use margins up to 0.012.
		var extent := axis.abs() + Vector3.ONE * (radius + 0.0121)
		occluder_lower[i] = center - extent
		occluder_upper[i] = center + extent
		if radius < 0.014:
			continue
		var first := _radiation_cell(center - extent)
		var last := _radiation_cell(center + extent)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if radius >= 0.025:
					radiation_cells.get_or_add(cell, []).append(i)
				if not piece.fibre and not piece.airborne:
					airflow_cells.get_or_add(cell, []).append(i)

static func _radiation_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / RADIATION_CELL), floori(point.z / RADIATION_CELL))

func _starter_passage(piece: Piece) -> float:
	var low_course := false
	var high_course := false
	for timber in wood:
		if timber.radius < 0.033 or timber.pose == null or timber.airborne or timber.at.distance_squared_to(piece.at) > 0.20:
			continue
		low_course = low_course or timber.height <= 0.116
		high_course = high_course or timber.height > 0.116
	if not low_course or not high_course:
		return 0.0
	var origin := Vector3(piece.at.x, minf(0.055, piece.height + 0.023), piece.at.y)
	var inlets := 0.0
	for i in range(8):
		var axis := Vector2.from_angle(TAU * i / 8.0)
		var reach := Vector3(axis.x, 0.045, axis.y) * 0.41
		if _fuel_ray_open(origin, origin + reach, piece, null, 0.012, 0.030):
			inlets += 1.0
	var outlets := 0.0
	for offset: Vector2 in [Vector2.ZERO, Vector2(0.073, 0), Vector2(-0.073, 0), Vector2(0, 0.073), Vector2(0, -0.073)]:
		var start := origin + Vector3(offset.x, 0, offset.y)
		if _fuel_ray_open(start, start + Vector3.UP * 0.62, piece, null, 0.008, 0.030):
			outlets += 1.0
	return smoothstep(0.0, 2.0, inlets) * smoothstep(0.5, 3.0, outlets)

func _rising_path(source: Piece, target: Piece) -> float:
	var offset := target.at.distance_to(source.at)
	var rise := target.height - source.height
	if offset > 0.38 or rise > 0.67 or rise < -0.06:
		return 0.0
	var from := _thermal_position(source) + Vector3.UP * 0.055
	var to := _thermal_position(target) + Vector3.UP * 0.012
	if not _fuel_ray_open(from, to, source, target, 0.0):
		return 0.0
	return 5.0 * (1.0 - smoothstep(0.095, 0.40, offset)) * (1.0 - smoothstep(0.32, 0.67, rise))

func _starter_jet(tinder: Piece, kindling: Piece) -> float:
	var offset := kindling.at.distance_to(tinder.at)
	var rise := kindling.height - tinder.height
	if offset > 0.17 or rise < -0.045 or rise > 0.15:
		return 0.0
	return (8.0 if kindling.kind == 6 else 2.8) * (1.0 - smoothstep(0.027, 0.17, offset))

func _nearby_flame_path(source: Piece, target: Piece) -> float:
	var rise := target.height - source.height
	if rise < -0.04 or rise > 0.26:
		return 0.0
	var from := _thermal_position(source)
	var to := _thermal_position(target)
	var near := Geometry3D.get_closest_points_between_segments(
		from - source.heat_axis, from + source.heat_axis, to - target.heat_axis, to + target.heat_axis)
	if not _fuel_ray_open(near[0] + Vector3.UP * 0.025, near[1] + Vector3.UP * 0.014, source, target, 0.0, 0.031):
		return 0.0
	return 1.0 - smoothstep(0.035, 0.18, near[0].distance_to(near[1]))

func _upward_capture(source: Piece, target: Piece) -> float:
	var rise := target.height - source.height
	if rise < 0.015 or rise > 0.48:
		return 0.0
	var from := Vector3(source.at.x, 0.0, source.at.y)
	var to := Vector3(target.at.x, 0.0, target.at.y)
	var a := Vector3(source.heat_axis.x, 0.0, source.heat_axis.z)
	var b := Vector3(target.heat_axis.x, 0.0, target.heat_axis.z)
	var near := Geometry3D.get_closest_points_between_segments(from - a, from + a, to - b, to + b)
	var drift := near[0].distance_to(near[1])
	return (1.0 - smoothstep(0.045, 0.23, drift)) * (1.0 - smoothstep(0.26, 0.48, rise))

func _fuel_ray_open(from: Vector3, to: Vector3, source: Piece, target: Piece, margin: float, minimum_radius := 0.014) -> bool:
	var lower := from.min(to)
	var upper := from.max(to)
	var first := _radiation_cell(lower)
	var last := _radiation_cell(upper)
	# A blocker spanning several cells only needs its segment test once.
	var seen := 0
	var overflow := {}
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			for i: int in airflow_cells.get(Vector2i(x, y), []):
				if i < 64:
					var bit := 1 << i
					if seen & bit:
						continue
					seen |= bit
				else:
					if overflow.has(i):
						continue
					overflow[i] = true
				if _fuel_ray_blocked(i, from, to, lower, upper, source, target, margin, minimum_radius):
					return false
	return true

func _fuel_ray_blocked(i: int, from: Vector3, to: Vector3, lower: Vector3, upper: Vector3,
		source: Piece, target: Piece, margin: float, minimum_radius: float) -> bool:
	var low := occluder_lower[i]
	var high := occluder_upper[i]
	if low.x > upper.x or low.y > upper.y or low.z > upper.z or high.x < lower.x or high.y < lower.y or high.z < lower.z:
		return false
	var piece := network_occluders[i]
	if occluder_radius[i] < minimum_radius or piece == source or piece.id == source.owner \
			or (target != null and (piece == target or piece.id == target.owner)):
		return false
	var axis := occluder_axes[i]
	var center := occluder_centers[i]
	var radius := occluder_radius[i] + margin
	var points := Geometry3D.get_closest_points_between_segments(from, to, center - axis, center + axis)
	return points[0].distance_squared_to(points[1]) < radius * radius

func _thermal_position(piece: Piece) -> Vector3:
	return Vector3(piece.at.x, piece.height, piece.at.y)

func _facing(piece: Piece, direction: Vector3) -> float:
	if piece.kind < 0:
		return 0.28 + 0.72 * maxf(0.0, direction.y)
	if piece.layer == 0:
		return 1.0
	return 0.28 + 0.72 * maxf(0.0, direction.y * piece.layer)

func _radiation_visibility(from: Vector3, to: Vector3, a: Piece, b: Piece) -> float:
	if from.distance_squared_to(to) < 0.012:
		return 1.0
	var middle := from.lerp(to, 0.5)
	for i in radiation_cells.get(_radiation_cell(middle), []):
		var piece := network_occluders[i]
		if piece.id == a.id or piece.id == b.id or piece.id == a.owner or piece.id == b.owner:
			continue
		var axis := occluder_axes[i]
		var offset := middle - occluder_centers[i]
		var across := offset - axis * clampf(offset.dot(axis) / occluder_inverse_axis[i], -1.0, 1.0)
		if across.length_squared() < occluder_radius[i] * occluder_radius[i]:
			return 0.16
	return 1.0

func _surface(p: Piece) -> float:
	var area := (0.35 + p.size * 4.0) * p.area_scale
	if p.fibre:
		area *= p.original / float(SPECIES[p.kind].mass)
	if p.layer != 0:
		area *= 0.57 * p.fraction
	if p.kind < 0:
		if p.base_capacity < 0.03:
			area *= clampf(0.12 + sqrt(p.char_mass / p.original), 0.12, 1.0)
		area *= 0.32 + 0.68 * pow(clampf(p.char_mass / p.original, 0.0, 1.5), 0.67)
	return area

func _exposed(p: Piece, air: float) -> float:
	var loft := maxf(0.0, p.fibre_shelter - (1.30 if p.fibre else 1.10))
	return 0.14 + 0.86 * exp(-1.05 * loft / (1.0 + 1.3 * air * air))

func _cooling(p: Piece, surface: float, room: float, air: float, insulation: float) -> float:
	var excess := p.temperature - room
	var exposed_sides := 1.0 / (1.0 + 1.25 * maxf(0.0, p.bed_shelter - 0.62))
	var convection := (0.0018 + 0.0035 * air * air) * exposed_sides
	return surface * insulation * _exposed(p, air) * excess * (convection + 0.0000042 * absf(excess))

func _emission(p: Piece, room_fourth: float, surface: float, air: float) -> float:
	var shield := exp(-4.0 * p.depth())
	var area := surface * 0.078 * (0.89 if p.kind < 0 else 0.78)
	if p.kind < 0:
		area *= minf(1.0, pow(p.size / 0.17, 2.0))
		area = minf(area, 0.085 * pow(p.charcoal_volume() / 0.00077, 0.667))
	var kelvin := p.temperature + 273.15
	var squared := kelvin * kelvin
	var excess := squared * squared - room_fourth
	return maxf(0.0, STEFAN_BOLTZMANN * area * excess * shield * _exposed(p, air))

func _plume_reach(rise: float) -> float:
	if rise < 0.0:
		return 1.0 - 0.80 * smoothstep(0.08, 0.60, -rise)
	return (1.0 + 0.48 * smoothstep(0.05, 0.28, rise)) * (1.0 - 0.82 * smoothstep(0.34, 0.83, rise))

func _solid_contact(a: Piece, b: Piece) -> float:
	var first := Vector3(a.at.x, a.height, a.at.y)
	var second := Vector3(b.at.x, b.height, b.at.y)
	var closest := Geometry3D.get_closest_points_between_segments(
		first - a.heat_axis, first + a.heat_axis, second - b.heat_axis, second + b.heat_axis)
	var radius_a := a.size * 0.49 if a.kind < 0 else a.radius
	var radius_b := b.size * 0.49 if b.kind < 0 else b.radius
	var contact := radius_a + radius_b
	return lerpf(1.0, 0.045, smoothstep(contact * 0.76, contact + 0.018, closest[0].distance_to(closest[1])))

func _exchange_capacity(a: Piece, b: Piece, cap_a: float, cap_b: float) -> float:
	if a.fibre and b.fibre:
		# Conducting fibre area scales with material at both ends of the link.
		return cap_a * cap_b / FIBRE_HEAT_CAPACITY
	return minf(cap_a, cap_b)

func _fibre_fill(source: Piece, target: Piece) -> void:
	var mass := (source.wood + source.char_mass) / FIBRE_MASS
	var rise := source.height - target.height
	var horizontal_gap := source.at.distance_squared_to(target.at)
	var gap := horizontal_gap + rise * rise * 2.6
	var shelter := 0.012 + source.fibre_spread
	var packing := 0.00086 + source.fibre_spread
	target.fibre_shelter += mass * exp(-gap / shelter) * 0.012 / shelter
	# A stack can restrict the upward air path beyond its immediate contact layer.
	var pore_gap := horizontal_gap + rise * rise * 0.32
	target.pore_density += mass * exp(-pore_gap / packing) * 0.00086 / packing

func step(dt := STEP) -> void:
	dt = clampf(dt, 0.0625, STEP)
	var after_storm := shelter != null and shelter.after_storm
	if shelter != null:
		shelter.sample(time)
		if time - storage_sample >= 1.0:
			_refresh_storage_membership()
			_weather_storage(time - storage_sample)
			storage_sample = time
	if not falling.is_empty():
		_land_residue(dt)
	if wood.any(_moving_fuel) or stored.any(_moving_fuel):
		_settle(true, dt)
	if network_dirty:
		_prepare_network()
	var rain: float = WEATHER[weather].rain
	var outside_rain := rain if shelter == null else shelter.rain
	ground_wetness = lerpf(ground_wetness, outside_rain, 1.0 - exp(-dt * (0.22 if outside_rain > ground_wetness else 0.012)))
	var room := ambient()
	for i in range(nodes.size()):
		var piece := nodes[i]
		capacities[i] = piece.capacity()
		insulations[i] = exp(-1.35 * piece.depth())
		changes[i] = 0.0
		piece.conduction = 0.0
		piece.radiation_in = 0.0
		piece.plume_heat = 0.0
		piece.internal_heat = 0.0
		piece.fibre_shelter = 0.0
		piece.pore_density = 0.0
		piece.bed_shelter = 0.0
		if piece.kind < 0:
			# Scattered grains couple less of their reaction heat to nearby wood
			# than a broad glowing patch does. Ash screens the glowing surface.
			var glowing_coverage := minf(1.0, piece.char_mass / 0.075)
			var radiation := smoothstep(400.0, 640.0, piece.temperature) * exp(-10.0 * piece.depth())
			ember_heat[i] = piece.char_heat * glowing_coverage * glowing_coverage * radiation
		if piece.fibre:
			_fibre_fill(piece, piece)
		var directed := Vector2.ZERO if breaths.is_empty() else breath_at(piece.at)
		piece.pulse = directed.length()
		var owner := piece.owner if piece.owner > 0 else piece.id
		piece.draft = background_wind(piece.at, piece.height, owner) + directed

	var native_exchange := Native.enabled and links.size() >= 64
	if native_exchange:
		if exchange_links.is_empty():
			_pack_exchange_links()
		for link in exchange_bed:
			_bed_overlap(link, nodes[link.a], nodes[link.b])
		for link in exchange_fibre:
			var a := nodes[link.a]
			var b := nodes[link.b]
			if a.fibre:
				_fibre_fill(a, b)
			if b.fibre:
				_fibre_fill(b, a)
	else:
		_exchange_links_reference()

	radiated = 0.0
	absorbed = 0.0
	var kelvin := room + 273.15
	var squared := kelvin * kelvin
	var room_fourth := squared * squared
	for p in nodes:
		var surface := _surface(p)
		p.exposed_surface = surface
		var air := p.draft.length()
		var local_room := shelter.air_temperature(p.at) if after_storm else room
		var room_loss := _cooling(p, surface, local_room, air, 0.065 + 0.935 * exp(-2.85 * p.depth()))
		# Divide the surface's environmental loss between convection and emission.
		p.radiation_out = minf(room_loss, _emission(p, room_fourth, surface, air)) if room_loss > 0.0 else 0.0
		p.convection_loss = room_loss - p.radiation_out
		p.flame_radiation = p.flame * 0.18
		radiated += p.radiation_out + p.flame_radiation
	if native_exchange:
		_exchange_links_native()
	else:
		_radiation_reference()

	var oxygen_used := 0.0
	for i in range(nodes.size()):
		var p := nodes[i]
		var wetting := rain if shelter == null else rain_at(p.at)
		if after_storm:
			wetting += shelter.seepage_at(p.at)
		var local_room := shelter.air_temperature(p.at) if after_storm else room
		oxygen_used += _react(p, changes[i] + p.plume_heat + p.radiation_in, crowding[i], local_room, wetting, dt, starter_ventilation[i])
		if p.smoke > 0.0:
			var lift := smoothstep(90.0, 620.0, p.temperature + p.flame * 2.0)
			smoke_field.release(Vector3(p.at.x, p.height + 0.04, p.at.y), p.smoke * dt, lift)
	smoke_field.advance(self, dt)
	var draft := 0.28 + (float(WEATHER[weather].wind) + fan) * 0.45
	if shelter != null:
		draft = (0.28 + background_wind(Vector2.ZERO).length() * 0.45) * lerpf(0.46, 1.25, shelter.ventilation(Vector2.ZERO))
	oxygen = clampf(oxygen + dt * (draft * (1.0 - oxygen) - oxygen_used / 0.055), 0.0, 1.0)

	for i in range(wood.size() - 1, -1, -1):
		var piece := wood[i]
		if piece.core == null:
			_shed(piece, piece, piece.wood == 0.0 and piece.gas < 0.000001)
		else:
			for section in piece.sections:
				section.core.internal_heat = 0.0
				for region in section.inner:
					region.internal_heat = 0.0
			for j in range(1, piece.sections.size()):
				var left := piece.sections[j - 1]
				var right := piece.sections[j]
				var along := (left.axial_coupling + right.axial_coupling) * 0.5
				for i_face in range(2):
					_exchange(left.faces[i_face], right.faces[i_face], 0.027 * along, dt)
					if after_storm:
						_exchange_water(left.faces[i_face], right.faces[i_face], 0.054 * along, dt)
				for lane in range(left.inner.size()):
					_exchange(left.inner[lane], right.inner[lane], 0.035 * along, dt)
				_exchange(left.core, right.core, 0.018 * along, dt)
				if after_storm:
					_exchange_water(left.core, right.core, 0.055 * along, dt)
			var remaining := 0.0
			var gases := 0.0
			for section in piece.sections:
				_exchange_core(section, dt)
				remaining += section.core.wood
				for region in section.inner:
					remaining += region.wood
				for face in section.faces:
					remaining += face.wood
					gases += face.gas
			var spent := remaining == 0.0 and gases < 0.000001
			for section in piece.sections:
				for face in section.faces:
					_shed(section, face, spent)
				if spent and section.core.water > 0.0:
					_deposit(section.at, 0.0, 0.0, section.core.water, section.core.temperature)
				if spent:
					for region in section.inner:
						if region.water > 0.0:
							_deposit(section.at, 0.0, 0.0, region.water, region.temperature)
			_sync_sections(piece)
		if piece.precise and not piece.sections.is_empty():
			_update_section_shape(piece)
			if _fracture_weak_section(piece):
				continue
		elif piece.precise and piece.can_support:
			var wear := clampi(ceili(piece.wood / piece.original * 8.0), 1, 8)
			if wear != piece.wear:
				piece.wear = wear
				piece.radius = Structure.radius(piece.kind) * (0.42 + wear * 0.0725)
				piece.upper_radius = piece.radius
				piece.lower_radius = piece.radius
				supports_dirty = true
		if piece.can_support and piece.wood < piece.original * 0.12:
			piece.can_support = false
			supports_dirty = true
		if piece.wood > 0.0 or piece.gas >= 0.000001:
			continue
		wood.remove_at(i)
		if shelter != null:
			storage_revision += 1
		supports_dirty = true
	for coal in coals:
		var level := Structure.coal_level(coal.char_mass)
		if level != coal.footing:
			coal.footing = level
			supports_dirty = true
		if not coal.carried and coal.char_mass < 0.02 and coal.cover < 0.002 and coal.pulse > 1.4:
			coal.at += coal.draft.normalized() * minf(0.025, (coal.pulse - 1.4) * 0.016) * dt
			coal.at = (coal.at / LIMIT).limit_length() * LIMIT
			_reindex()
			supports_dirty = true
	if supports_dirty or (wear_dirty and time - last_settle >= 0.5):
		_settle(true)
	if after_storm and not sparks.is_empty():
		_advance_sparks(dt, room)

	for i in range(breaths.size() - 1, -1, -1):
		breaths[i].age += dt
		if breaths[i].age >= breaths[i].duration:
			breaths.remove_at(i)
	fan *= exp(-dt / 7.5)
	time += dt
	_step_tinder_work(dt)
	revision += 1

func _bed_overlap(link: Link, a: Piece, b: Piece) -> void:
	var overlap := exp(-link.delta.length_squared() / 0.035) / 0.095
	a.bed_shelter += b.char_mass * overlap
	b.bed_shelter += a.char_mass * overlap

func _pack_exchange_links() -> void:
	exchange_links.resize(links.size() * 15)
	exchange_fibre.clear()
	exchange_bed.clear()
	var offset := 0
	for link in links:
		var a := nodes[link.a]
		var b := nodes[link.b]
		if a.fibre or b.fibre:
			exchange_fibre.append(link)
		if a.kind < 0 and b.kind < 0:
			exchange_bed.append(link)
		exchange_links[offset] = link.a
		exchange_links[offset + 1] = link.b
		exchange_links[offset + 2] = link.conductance
		exchange_links[offset + 3] = link.proximity
		exchange_links[offset + 4] = link.delta.x
		exchange_links[offset + 5] = link.delta.y
		exchange_links[offset + 6] = link.receive_a
		exchange_links[offset + 7] = link.receive_b
		exchange_links[offset + 8] = link.coal
		exchange_links[offset + 9] = link.toward_wood.x
		exchange_links[offset + 10] = link.toward_wood.y
		exchange_links[offset + 11] = link.ember_feedback
		exchange_links[offset + 12] = link.view_a
		exchange_links[offset + 13] = link.view_b
		offset += 15

func _exchange_links_native() -> void:
	exchange_nodes.resize(nodes.size() * 13)
	var offset := 0
	for i in nodes.size():
		var piece := nodes[i]
		var wind := piece.draft.limit_length(1.8)
		var breath := Vector2.ZERO
		var strength := 0.0
		if piece.kind < 0 and not breaths.is_empty() and piece.pulse > 0.12:
			breath = piece.draft.normalized()
			strength = smoothstep(0.12, 0.65, piece.pulse)
		exchange_nodes[offset] = piece.temperature
		exchange_nodes[offset + 1] = capacities[i]
		exchange_nodes[offset + 2] = insulations[i]
		exchange_nodes[offset + 3] = piece.flame + piece.smolder * 0.50
		exchange_nodes[offset + 4] = piece.radiation_out + piece.flame_radiation
		exchange_nodes[offset + 5] = ember_heat[i] if piece.kind < 0 else 0.0
		exchange_nodes[offset + 6] = piece.char_mass
		exchange_nodes[offset + 7] = wind.x
		exchange_nodes[offset + 8] = wind.y
		exchange_nodes[offset + 9] = breath.x
		exchange_nodes[offset + 10] = breath.y
		exchange_nodes[offset + 11] = strength
		exchange_nodes[offset + 12] = float(piece.fibre)
		offset += 13
	var result: PackedFloat64Array = ClassDB.class_call_static(Native.KERNEL, &"exchange", exchange_nodes, exchange_links)
	if result.size() != nodes.size() * 4 + 1:
		push_error("Firetender bridge rejected its thermal buffers. Continuing with the reference exchange.")
		for piece in nodes:
			piece.bed_shelter = 0.0
			piece.fibre_shelter = 0.0
			piece.pore_density = 0.0
			if piece.fibre:
				_fibre_fill(piece, piece)
		_exchange_links_reference()
		_radiation_reference()
		Native.enabled = false
		return
	for i in nodes.size():
		var piece := nodes[i]
		var read := i * 4
		changes[i] = result[read]
		piece.conduction = result[read]
		piece.plume_heat = result[read + 1]
		piece.radiation_in = result[read + 2]
	absorbed = result[-1]

func _exchange_links_reference() -> void:
	for link in links:
		var i := link.a
		var j := link.b
		var a := nodes[i]
		var b := nodes[j]
		var insulation := insulations[i] * insulations[j]
		if a.kind < 0 and b.kind < 0:
			_bed_overlap(link, a, b)
		if a.fibre:
			_fibre_fill(a, b)
		if b.fibre:
			_fibre_fill(b, a)
		var exchange := link.conductance * insulation * _exchange_capacity(a, b, capacities[i], capacities[j])
		if link.coal >= 0 and not breaths.is_empty():
			var coal := nodes[link.coal]
			if coal.pulse > 0.12:
				# A jet can carry heat into tinder immediately downstream of coals.
				var aligned := coal.draft.normalized().dot(link.toward_wood)
				exchange *= 1.0 + smoothstep(0.12, 0.65, coal.pulse) * (0.28 + 0.72 * maxf(0.0, aligned))
		var heat := exchange * (b.temperature - a.temperature)
		a.conduction += heat
		b.conduction -= heat
		changes[i] += heat
		changes[j] -= heat
		if link.ember_feedback > 0.0:
			var fuel_index := j if link.coal == i else i
			nodes[fuel_index].plume_heat += ember_heat[link.coal] * link.ember_feedback * insulation
		var power_a := a.flame + a.smolder * 0.50
		var power_b := b.flame + b.smolder * 0.50
		if power_a > 0.0:
			var lean := link.delta.dot(a.draft.limit_length(1.8)) * 0.18
			b.plume_heat += power_a * maxf(0.0, link.proximity + lean) * link.receive_b * insulation
		if power_b > 0.0:
			var lean := link.delta.dot(b.draft.limit_length(1.8)) * 0.18
			a.plume_heat += power_b * maxf(0.0, link.proximity - lean) * link.receive_a * insulation

func _radiation_reference() -> void:
	for link in radiant_links:
		var a := nodes[link.a]
		var b := nodes[link.b]
		var power_a := a.radiation_out + a.flame_radiation
		var power_b := b.radiation_out + b.flame_radiation
		if power_a == 0.0 and power_b == 0.0:
			continue
		var from_a := power_a * link.view_a * insulations[link.b]
		var from_b := power_b * link.view_b * insulations[link.a]
		a.radiation_in += from_b
		b.radiation_in += from_a
		absorbed += from_a + from_b

func _near_hot_fuel(piece: Piece) -> bool:
	for source in coals:
		if source.temperature > 100.0 and piece.at.distance_squared_to(source.at) < pow(piece.size + source.size + 0.65, 2.0):
			return true
	for source in wood:
		if source != piece and source.temperature > 100.0 and piece.at.distance_squared_to(source.at) < pow(piece.size + source.size + 0.65, 2.0):
			return true
	return false

func _quiet_stock(piece: Piece) -> bool:
	if piece.airborne or piece.temperature > 42.0 or piece.gas > 0.000001 or piece.flame > 0.01:
		return false
	for fragment in sparks:
		if fragment.receiver == piece:
			return false
	for section in piece.sections:
		for part in section.faces + section.inner + [section.core]:
			if part.temperature > 42.0 or part.gas > 0.000001:
				return false
	return true

func _refresh_storage_membership() -> void:
	for i in range(stored.size() - 1, -1, -1):
		var piece := stored[i]
		if in_hearth(piece.at) or _near_hot_fuel(piece):
			stored.remove_at(i)
			wood.append(piece)
			network_dirty = true
			_invalidate_wind_stock()
	for i in range(wood.size() - 1, -1, -1):
		var piece := wood[i]
		if not in_hearth(piece.at) and _quiet_stock(piece) and not _near_hot_fuel(piece):
			wood.remove_at(i)
			stored.append(piece)
			network_dirty = true
			_invalidate_wind_stock()

func _weather_storage(elapsed: float) -> void:
	# The remote pile has no combustion links. Catch rain on the same fuel
	# surfaces and let its temperature follow the air until it approaches heat.
	var room := ambient()
	var drift := 1.0 - exp(-elapsed * 0.06)
	var shelf_sections: Array[Piece] = []
	if shelter.after_storm:
		for piece in stored:
			if not piece.sections.is_empty():
				shelf_sections.append(piece)
	for piece in stored:
		var local_room := shelter.air_temperature(piece.at) if shelter.after_storm else room
		var air := wind_at(piece.at).length() if shelter.after_storm else 0.0
		var local_drift := 1.0 - exp(-elapsed * lerpf(0.032, 0.135, smoothstep(0.07, 0.62, air))) if shelter.after_storm else drift
		# Sheltered air can move between separated logs. A tight pile traps
		# moisture and recovers heat from the air more slowly.
		var shelf_air := 0.0
		if shelter.after_storm and not piece.sections.is_empty() and Shelter.DRY_SHELF.has_point(piece.at):
			shelf_air = 1.0
			for neighbor in shelf_sections:
				if neighbor != piece and piece.at.distance_squared_to(neighbor.at) < 0.20 * 0.20:
					shelf_air = 0.35
					break
			local_drift = maxf(local_drift, 1.0 - exp(-elapsed * 0.17 * shelf_air))
		if piece.sections.is_empty():
			_idle_surface(piece, local_room, local_drift, elapsed, air)
		else:
			for section in piece.sections:
				var face := section.faces[0]
				var wetting := rain_at(face.at)
				var humidity := 0.0
				if shelter.after_storm:
					wetting += shelter.seepage_at(face.at)
					humidity = shelter.humidity(face.at)
				_weather_surface(face, local_room, local_drift, elapsed, air, shelf_air, wetting, humidity)
				var underside := section.faces[1]
				# Air and rain are sampled in plan coordinates. The two
				# faces normally share them, including when one is turned.
				if underside.at == face.at:
					_weather_surface(underside, local_room, local_drift, elapsed, air, shelf_air, wetting, humidity)
				else:
					_idle_surface(underside, local_room, local_drift, elapsed, air, shelf_air)
				for part in section.inner:
					part.temperature = lerpf(part.temperature, local_room, local_drift * 0.32)
				section.core.temperature = lerpf(section.core.temperature, local_room, local_drift * 0.32)
				if shelter.after_storm:
					_diffuse_to_faces(section, elapsed)
			_sync_sections(piece)

func _idle_surface(piece: Piece, room: float, drift: float, elapsed: float, air: float, shelf_air := 0.0) -> void:
	var wetting := rain_at(piece.at)
	var humidity := 0.0
	if shelter.after_storm:
		wetting += shelter.seepage_at(piece.at)
		humidity = shelter.humidity(piece.at)
	_weather_surface(piece, room, drift, elapsed, air, shelf_air, wetting, humidity)

func _weather_surface(piece: Piece, room: float, drift: float, elapsed: float, air: float, shelf_air: float,
		wetting: float, humidity: float) -> void:
	piece.temperature = lerpf(piece.temperature, room, drift)
	var area := _surface(piece)
	if piece.layer >= 0:
		var incoming := _caught_rain(piece, area, wetting, elapsed, 1.0)
		piece.water += incoming
		if shelter.after_storm:
			received_water += incoming
			piece.temperature += (room - piece.temperature) * incoming * 4.18 / piece.capacity()
	if shelter.after_storm:
		var capacity := piece.capacity()
		var evaporated := _moisture_loss(piece, area * (1.0 + 0.13 * shelf_air), room, air, elapsed, capacity, humidity)
		piece.vapor = evaporated / elapsed
		piece.water -= evaporated
		piece.temperature -= evaporated * 2260.0 / capacity
		evaporated_water += evaporated

func _caught_rain(piece: Piece, surface: float, rain: float, dt: float, insulation: float) -> float:
	return minf(dt * rain * surface * 0.00072 * insulation, maxf(0.0, piece.original * piece.moisture_capacity - piece.water))

func _moisture_loss(piece: Piece, area: float, room: float, air: float, dt: float, capacity: float, humidity: float) -> float:
	var warm := maxf(0.0, piece.temperature - room)
	var equilibrium := lerpf(0.055, 0.24, humidity) * exp(-warm * 0.012)
	var available := maxf(0.0, piece.water - piece.wood * equilibrium)
	var ventilation := 0.56 + 0.48 * smoothstep(0.0, 0.60, air)
	var pressure := 1.0 - humidity * 0.91 * exp(-warm * 0.026)
	var evaporation := 0.041 + 0.36 * smoothstep(0.0, 80.0, warm) + smoothstep(42.0, 155.0, piece.temperature)
	var demand := dt * area * 0.0032 * piece.drying_factor * ventilation * pressure * evaporation
	var budget := maxf(0.0, (piece.temperature - room + 2.5) * capacity / 2260.0)
	return minf(available, minf(demand, budget))

func _diffuse_to_faces(section: Piece, dt: float) -> void:
	var thickness := maxf(0.023, section.original_radius)
	var grain := section.drying_factor * clampf(0.050 / thickness, 0.45, 1.7)
	for index in range(2):
		var face := section.faces[index]
		if section.inner.is_empty():
			_exchange_water(section.core, face, 0.094 * grain, dt)
		else:
			var inside := section.inner[index]
			_exchange_water(section.core, inside, 0.073 * grain, dt)
			_exchange_water(inside, face, 0.128 * grain, dt)

func set_wet_skin(piece: Piece) -> void:
	# A recently wetted branch can hold the same water mostly in its skin.
	for section in piece.sections:
		for interior: Piece in section.inner + [section.core]:
			var moved := interior.water * 0.62
			for face in section.faces:
				var amount := minf(moved * 0.5, maxf(0.0, face.original * face.moisture_capacity - face.water))
				face.water += amount
				interior.water -= amount
	if not piece.sections.is_empty():
		_sync_sections(piece)

func _exchange_water(a: Piece, b: Piece, coupling: float, dt: float) -> void:
	if a.wood <= 0.000001 or b.wood <= 0.000001:
		return
	var gradient := a.water / a.wood - b.water / b.wood
	var source := a if gradient > 0.0 else b
	var receiver := b if gradient > 0.0 else a
	var warmth := lerpf(0.14, 1.0, smoothstep(9.0, 82.0, maxf(a.temperature, b.temperature)))
	var flux := absf(gradient) * minf(a.wood, b.wood) * coupling * warmth * dt
	var amount := minf(flux, minf(source.water, maxf(0.0, receiver.wood * receiver.moisture_capacity - receiver.water)))
	source.water -= amount
	receiver.water += amount
	receiver.temperature += (source.temperature - receiver.temperature) * amount * 4.18 / receiver.capacity()

func _update_section_shape(piece: Piece) -> void:
	var first_moment := 0.0
	var largest := 0.0
	var count := piece.sections.size()
	for i in range(count):
		var section := piece.sections[i]
		var supported := section.integrity >= 0.10
		var solid := clampf((section.wood + section.char_mass * 1.45) / section.original, 0.0, 1.0)
		section.integrity = clampf(pow(section.wood / section.original, 0.72) + section.char_mass / section.original * 0.28, 0.0, 1.0)
		if supported and section.integrity < 0.10:
			supports_dirty = true
		var upper := _worn_radius(section, section.faces[0], solid)
		var lower := _worn_radius(section, section.faces[1], solid)
		if upper != section.upper_radius or lower != section.lower_radius:
			section.upper_radius = upper
			section.lower_radius = lower
			section.radius = maxf(upper, lower)
			wear_dirty = true
		if not section.crushed and section.integrity < 0.48 and section.contact_load > section.bearing_limit():
			section.crushed = true
			supports_dirty = true
		largest = maxf(largest, section.radius)
		first_moment += section.mass() * ((2.0 * i + 1.0) / count - 1.0)
	var centre := snappedf(first_moment / maxf(0.00001, piece.mass()), 0.05)
	if piece.centre_of_mass != centre:
		piece.centre_of_mass = centre
		wear_dirty = true
	piece.radius = largest

func _worn_radius(section: Piece, face: Piece, solid: float) -> float:
	var skin := sqrt(clampf((face.wood + face.char_mass * 1.5) / face.original, 0.0, 1.0))
	var ratio := 0.16 + 0.84 * (0.75 * sqrt(solid) + 0.25 * skin)
	return section.original_radius * clampf(ceilf(ratio * 12.0) / 12.0, 0.16, 1.0)

func _fracture_weak_section(piece: Piece) -> bool:
	if piece.sections.size() < 2 or piece.airborne or wood.size() >= MAX_WOOD + MAX_FRAGMENTS:
		return false
	if piece.pose == null:
		return false
	var count := piece.sections.size()
	var suspended := piece.height > piece.radius + 0.016
	var weight := piece.mass() * GRAVITY * 0.48 + piece.carried_load
	for i in range(count):
		var section := piece.sections[i]
		if section.integrity > 0.19 or section.charred_wood < section.original * 0.45:
			continue
		var bond := section.bearing_limit() * section.integrity
		if section.integrity > 0.06 and (not suspended or weight <= bond):
			continue
		var cut := i + 1 if i < count / 2.0 else i
		var left := piece.sections.slice(0, cut)
		var right := piece.sections.slice(cut)
		# Each side needs a surviving body. Loose ash is already handled by the coal bed.
		if (not left.any(_coherent_fragment) or not right.any(_coherent_fragment)):
			continue
		var fragment := Piece.new()
		fragment.id = next_id
		next_id += 1
		var old_pose := piece.pose
		var old_length := piece.size
		var detached_at := old_pose.point(old_pose.span * cut / count)
		var kept_at := old_pose.point(old_pose.span * (float(cut) / count - 1.0))
		fragment.kind = piece.kind
		fragment.material = piece.material
		fragment.specific_heat = piece.specific_heat
		fragment.char_density = piece.char_density
		fragment.char_porosity = piece.char_porosity
		fragment.precise = true
		fragment.fed = piece.fed
		fragment.original_radius = piece.original_radius
		fragment.axis = piece.axis
		fragment.tier = piece.tier
		fragment.split_start = true
		fragment.split_end = piece.split_end
		piece.split_end = true
		if piece.split_family == 0:
			piece.split_family = piece.id
		fragment.split_family = piece.split_family
		_fit_fragment(piece, left, kept_at, old_length * cut / count, old_pose)
		_fit_fragment(fragment, right, detached_at, old_length * (count - cut) / count, old_pose)
		wood.append(fragment)
		supports_dirty = true
		structure_event.emit("break", section.at, fragment.mass(), section.height, section.temperature)
		return true
	return false

func _coherent_fragment(section: Piece) -> bool:
	return section.wood > section.original * 0.13 or section.char_mass > 0.006

func _fit_fragment(piece: Piece, sections: Array[Piece], center: Vector3, length: float, previous: Structure.Pose) -> void:
	piece.sections = sections
	piece.at = Vector2(center.x, center.y)
	piece.size = length
	piece.lean = previous.slope
	piece.pose = Structure.Pose.new()
	piece.pose.at = piece.at
	piece.pose.height = center.z
	piece.height = center.z
	piece.pose.axis = piece.axis
	piece.pose.span = length / sqrt(1.0 + previous.slope * previous.slope)
	piece.pose.slope = previous.slope
	piece.airborne = true
	piece.original = 0.0
	piece.volume = 0.0
	for section in sections:
		piece.original += section.original
		piece.volume += section.volume
		for face in section.faces:
			face.owner = piece.id
	if piece.core == null:
		_make_faces(piece, piece.id)
	_sync_sections(piece)
	_update_section_shape(piece)
	piece.can_support = sections.any(func(section): return section.integrity >= 0.10 and not section.crushed)

func _exchange_core(piece: Piece, dt: float) -> void:
	var core := piece.core
	if shelter != null and shelter.after_storm:
		core.drying_heat = 0.0
		_diffuse_to_faces(piece, dt)
	if not piece.inner.is_empty():
		_exchange(piece.inner[0], piece.inner[1], 0.028 * piece.tangent_coupling, dt)
	for i in range(piece.faces.size()):
		var face := piece.faces[i]
		var reservoir := core
		if piece.inner.is_empty():
			_exchange(face, core, 0.13, dt)
		else:
			var lane := piece.inner[i]
			_exchange(face, core, 0.060 * piece.radial_coupling, dt)
			_exchange(face, lane, 0.23 * piece.radial_coupling, dt)
			_exchange(lane, core, 0.19 * piece.radial_coupling, dt)
			_vent_inner(lane, face, dt)
			if lane.wood > 0.000001:
				reservoir = lane
		if shelter != null and shelter.after_storm:
			_trapped_steam(reservoir, face, dt)
		var face_capacity := face.capacity()
		# A receding surface exposes fresh material from the next grain layer.
		var recess := maxf(0.0, face.original * 0.55 - face.wood)
		var revealed := minf(reservoir.wood, recess * smoothstep(130.0, 410.0, face.temperature) * dt * 0.18)
		if reservoir.wood - revealed < 0.000001:
			revealed = reservoir.wood
		if revealed <= 0.0:
			continue
		var wet := reservoir.water * revealed / reservoir.wood
		reservoir.water -= wet
		reservoir.wood -= revealed
		face.wood += revealed
		face.water += wet
		face.temperature += (reservoir.temperature - face.temperature) * (face.capacity() - face_capacity) / face.capacity()

func _vent_inner(lane: Piece, face: Piece, dt: float) -> void:
	lane.drying_heat = 0.0
	lane.vapor = 0.0
	if lane.water <= 0.0 or lane.temperature <= 95.0:
		return
	var opened := 1.0 - smoothstep(0.2, 0.78, face.wood / face.original)
	var evaporation := lane.original * 0.016 * opened * smoothstep(95.0, 210.0, lane.temperature) * dt
	var capacity := lane.capacity()
	evaporation = minf(lane.water, minf(evaporation, (lane.temperature - 95.0) * capacity / 2260.0))
	lane.temperature -= evaporation * 2260.0 / capacity
	lane.water -= evaporation
	if shelter != null and shelter.after_storm:
		evaporated_water += evaporation
	lane.vapor = evaporation / dt
	lane.drying_heat = lane.vapor * 2260.0
	face.vapor += lane.vapor

func _trapped_steam(interior: Piece, face: Piece, dt: float) -> void:
	var intact := smoothstep(0.40, 0.92, face.wood / face.original)
	var thick := smoothstep(0.030, 0.066, face.radius)
	var boiling := smoothstep(101.0, 141.0, interior.temperature)
	var wet := smoothstep(0.15, 0.56, interior.water / interior.original)
	var demand := dt * interior.original * 0.0053 * intact * thick * boiling * wet
	if demand <= 0.0:
		return
	var capacity := interior.capacity()
	var evaporated := minf(interior.water, minf(demand, (interior.temperature - 100.0) * capacity / 2260.0))
	var latent := evaporated * 2260.0
	interior.temperature -= latent / capacity
	interior.water -= evaporated
	interior.drying_heat += latent / dt
	face.vapor += evaporated / dt
	evaporated_water += evaporated
	# A small sealed pore needs less vapor to build the same pressure.
	face.pocket_pressure += evaporated * lerpf(72.0, 129.0, intact) / face.original
	_pop_if_pressurized(face)

func _exchange(a: Piece, b: Piece, coupling: float, dt: float) -> void:
	var capacity_a := a.capacity()
	var capacity_b := b.capacity()
	var power := (a.temperature - b.temperature) * minf(capacity_a, capacity_b) * coupling
	a.internal_heat -= power
	b.internal_heat += power
	var heat := power * dt
	a.temperature -= heat / capacity_a
	b.temperature += heat / capacity_b

func _sync_sections(piece: Piece) -> void:
	for section in piece.sections:
		_sync_log(section)
	for i in range(3):
		var result := piece.core if i == 2 else piece.faces[i]
		var readings: Array[Piece] = []
		for section in piece.sections:
			readings.append(section.core if i == 2 else section.faces[i])
			if i == 2:
				readings.append_array(section.inner)
		_merge_reading(result, readings)
	_sync_log(piece)

func _merge_reading(result: Piece, readings: Array[Piece]) -> void:
	result.wood = 0.0
	result.water = 0.0
	result.char_mass = 0.0
	result.mineral = 0.0
	result.gas = 0.0
	result.flame = 0.0
	result.char_heat = 0.0
	result.charred_wood = 0.0
	result.smoke = 0.0
	result.vapor = 0.0
	result.oxygen = 0.0
	result.trend = 0.0
	result.draft = Vector2.ZERO
	result.pulse = 0.0
	var heat := 0.0
	for reading in readings:
		result.wood += reading.wood
		result.water += reading.water
		result.char_mass += reading.char_mass
		result.mineral += reading.mineral
		result.gas += reading.gas
		result.flame += reading.flame
		result.char_heat += reading.char_heat
		result.charred_wood += reading.charred_wood
		result.smoke += reading.smoke
		result.vapor += reading.vapor
		heat += reading.temperature * reading.capacity()
		result.oxygen += reading.oxygen
		result.trend += reading.trend
		result.draft += reading.draft
		result.pulse = maxf(result.pulse, reading.pulse)
	result.temperature = heat / result.capacity()
	result.oxygen /= readings.size()
	result.trend /= readings.size()
	result.draft /= readings.size()

func _sync_log(piece: Piece) -> void:
	var top := piece.faces[0]
	var bottom := piece.faces[1]
	var core := piece.core
	piece.wood = top.wood + bottom.wood + core.wood
	piece.water = top.water + bottom.water + core.water
	piece.mineral = top.mineral + bottom.mineral + core.mineral
	piece.char_mass = top.char_mass + bottom.char_mass
	piece.charred_wood = top.charred_wood + bottom.charred_wood + core.charred_wood
	piece.gas = top.gas + bottom.gas
	piece.flame = top.flame + bottom.flame
	piece.smoke = top.smoke + bottom.smoke
	piece.vapor = top.vapor + bottom.vapor
	piece.char_heat = top.char_heat + bottom.char_heat
	piece.oxygen = (top.oxygen + bottom.oxygen) * 0.5
	var heat := top.temperature * top.capacity() + bottom.temperature * bottom.capacity() + core.temperature * core.capacity()
	for region in piece.inner:
		piece.wood += region.wood
		piece.water += region.water
		piece.char_mass += region.char_mass
		piece.mineral += region.mineral
		heat += region.temperature * region.capacity()
	piece.temperature = heat / piece.capacity()
	piece.draft = (top.draft + bottom.draft) * 0.5
	piece.pulse = maxf(top.pulse, bottom.pulse)
	piece.trend = (top.trend + bottom.trend) * 0.5

func _shed(piece: Piece, surface: Piece, spent: bool) -> void:
	var residue := surface.char_mass if spent else minf(surface.shed, surface.char_mass)
	if not spent and residue + surface.mineral < 0.00008:
		return
	var water := surface.water if spent else 0.0
	surface.char_mass -= residue
	surface.shed = maxf(0.0, surface.shed - residue)
	surface.water -= water
	if piece.core != null and not spent:
		for offset in [-0.28, 0.28]:
			var point: Vector2 = piece.at + piece.axis * piece.size * offset * (piece.fraction * 2.0)
			_deposit(point, residue * 0.5, surface.mineral * 0.5, water * 0.5,
				surface.temperature, surface.char_density, surface.char_porosity, surface.oxidation_factor)
	else:
		_drop_residue(piece.at, surface, residue, water)
	surface.mineral = 0.0

func _drop_residue(at: Vector2, surface: Piece, carbon: float, water: float) -> void:
	if surface.height < 0.09 or carbon < 0.0022 or falling.size() >= 12:
		_deposit(at, carbon, surface.mineral, water, surface.temperature,
			surface.char_density, surface.char_porosity, surface.oxidation_factor)
		return
	var debris := Residue.new()
	debris.at = at
	debris.height = surface.height
	debris.carbon = carbon
	debris.mineral = surface.mineral
	debris.water = water
	debris.temperature = surface.temperature
	debris.density = surface.char_density
	debris.pores = surface.char_porosity
	debris.oxidation = surface.oxidation_factor
	falling.append(debris)
	structure_event.emit("fall", at, carbon, debris.height, debris.temperature)

func _land_residue(dt: float) -> void:
	for i in range(falling.size() - 1, -1, -1):
		var debris := falling[i]
		debris.height -= debris.speed * dt + 0.5 * GRAVITY * dt * dt
		debris.speed += GRAVITY * dt
		if debris.height > 0.015:
			continue
		_deposit(debris.at, debris.carbon, debris.mineral, debris.water, debris.temperature,
			debris.density, debris.pores, debris.oxidation)
		last_char_fall = time
		structure_event.emit("land", debris.at, debris.carbon, 0.0, debris.temperature)
		falling.remove_at(i)

func _deposit(at: Vector2, carbon: float, mineral: float, water: float, heat: float,
		density := 225.0, pores := 0.45, oxidation := 1.0) -> void:
	if carbon + mineral + water <= 0.0:
		return
	var point := work_point(at)
	var coal: Piece = cells.get(_cell(point))
	if coal == null and coals.size() >= MAX_PATCHES:
		_compact_bed()
	if coal == null:
		coal = _new_coal(point, 0.0, ambient(), 0.003)
	_mix(coal, carbon, mineral, water, 0.0, 0.0, heat, density, pores, oxidation)

func _mix(coal: Piece, carbon: float, mineral: float, water: float, cover: float, base: float, heat: float,
		density := 225.0, pores := 0.45, oxidation := 1.0) -> void:
	var old_capacity := coal.capacity()
	if carbon > 0.0:
		coal.oxidation_factor = lerpf(coal.oxidation_factor, oxidation, carbon / (coal.char_mass + carbon))
		var solid_volume := coal.char_mass / coal.char_density + carbon / density
		var bulk_volume := coal.charcoal_volume() + carbon / (density * (1.0 - pores))
		coal.char_density = (coal.char_mass + carbon) / solid_volume
		coal.char_porosity = 1.0 - solid_volume / bulk_volume
	coal.char_mass += carbon
	coal.mineral += mineral
	coal.water += water
	coal.cover += cover
	coal.base_capacity += base
	coal.temperature += (heat - coal.temperature) * (coal.capacity() - old_capacity) / coal.capacity()

func _compact_bed() -> void:
	var a := 0
	var b := 1
	var closest := INF
	for i in range(coals.size()):
		if coals[i].carried:
			continue
		for j in range(i + 1, coals.size()):
			if coals[j].carried:
				continue
			var distance := coals[i].at.distance_squared_to(coals[j].at)
			if distance < closest:
				closest = distance
				a = i
				b = j
	var source := coals[b]
	_mix(coals[a], source.char_mass, source.mineral, source.water, source.cover, source.base_capacity,
		source.temperature, source.char_density, source.char_porosity, source.oxidation_factor)
	coals.remove_at(b)
	network_dirty = true
	_reindex()

func _react(p: Piece, transferred: float, crowd: float, room: float, rain: float, dt: float, ventilation := 0.0) -> float:
	var air := p.draft.length()
	if p.cover > 0.0 and p.pulse > 1.1:
		var scattered := minf(p.cover, dt * (p.pulse - 1.1) * 0.006)
		p.cover -= scattered
		p.mineral += scattered
	var cover := p.depth()
	var shield := exp(-1.67 * cover / (1.0 + p.pulse * 0.75))
	var insulation := 0.065 + 0.935 * exp(-2.85 * cover)
	var fresh := lerpf(oxygen, 1.0, smoothstep(0.0, 0.9, p.pulse) * 0.85)
	if p.kind >= 0:
		# Open sides replenish a little air without sharing the oxygen demand
		# of the whole hearth. Nearby shielding closes that path.
		fresh = lerpf(fresh, 1.0, 0.17 * (1.0 - smoothstep(0.08, 0.72, crowd)))
	var exposed_air := 0.83 + 0.17 * smoothstep(0.0, 1.0, air) if p.layer < 0 else 1.0
	p.oxygen = fresh * shield * exposed_air * (1.0 - 0.7 * smoothstep(0.12, 1.8, crowd))
	var pore_air := _pore_air(p.pore_density / (1.0 + p.pulse * 0.40))
	p.oxygen *= pore_air
	var t := p.temperature
	var is_coal := p.kind < 0
	var after_storm := shelter != null and shelter.after_storm
	var surface := p.exposed_surface
	var capacity := p.capacity()
	if rain > 0.0 and p.layer >= 0:
		var incoming := _caught_rain(p, surface, rain, dt, insulation)
		p.water += incoming
		if after_storm:
			received_water += incoming
		# A rain-soaked bed retains surface water as well as losing heat.
		capacity += incoming * 4.18
		transferred -= incoming * 4.18 * (t - room) / dt

	var water_demand := minf(p.water, dt * surface * 0.0028 * p.drying_factor * smoothstep(42.0, 155.0, t))
	var water_budget := maxf(0.0, (t - 44.0) * capacity / 2260.0)
	var evaporated := minf(water_demand, water_budget)
	if after_storm:
		evaporated = _moisture_loss(p, surface * (1.0 - 0.42 * smoothstep(0.12, 1.6, crowd)), room, air, dt, capacity, shelter.humidity(p.at))
		evaporated_water += evaporated
	p.water -= evaporated
	p.vapor = evaporated / dt

	var charred := 0.0
	var oxidised := 0.0
	var resin_vapor := 0.0
	p.smolder = 0.0
	if not is_coal:
		var fuel: Dictionary = SPECIES[p.kind]
		if p.fibre:
			# Oxygen-limited solid oxidation consumes dry fibres before they
			# can produce a flame. Its heat is paid for with that material.
			var dry := 1.0 - smoothstep(0.09, 0.45, p.water / p.original)
			var rate := p.original * 0.045 * smoothstep(157.0, 275.0, t) * dry
			if p.kind == TINDER_BUNDLE:
				rate = p.original * 0.075 * smoothstep(135.0, 260.0, t) * dry
			rate *= smoothstep(0.10, 0.68, p.oxygen) * (1.0 - smoothstep(390.0, 680.0, t) * 0.68)
			oxidised = minf(p.wood, rate * dt)
			p.wood -= oxidised
			p.smoldered += oxidised
			p.smolder = oxidised * (1.0 - p.yield_char) * FIBRE_OXIDATION_ENERGY / dt
		var conversion: float = fuel.rate * surface * smoothstep(220.0, 495.0, t)
		conversion /= 1.0 + 4.0 * p.water / p.original + 1.8 * p.char_mass / p.original
		if p.layer != 0:
			# As the burn front recedes, heat and gas must cross more of the charred shell.
			var depth := smoothstep(0.026, 0.071, Structure.radius(p.kind))
			var developed := smoothstep(0.18, 0.57, p.charred_wood / p.original)
			conversion /= 1.0 + developed * lerpf(0.30, 1.20, depth)
		charred = minf(p.wood, conversion * dt)
		p.wood -= charred
		p.charred_wood += charred + oxidised
		p.char_mass += (charred + oxidised) * p.yield_char
		var fragmentation := lerpf(1.0, 0.42, smoothstep(0.042, 0.071, p.radius))
		p.shed += charred * p.yield_char * (0.60 if p.layer < 0 else 0.30) * fragmentation * p.crumbling
		p.gas += charred * (1.0 - p.yield_char)
		if after_storm:
			resin_vapor = _release_resin(p, evaporated, dt)

	# Incoming hot gas pilots the volatiles from exposed log faces.
	p.pilot = minf(65.0, p.plume_heat * 6.0) if p.layer != 0 and p.precise else 0.0
	var hot_gas := smoothstep(278.0, 470.0, t + p.pilot)
	if p.kind >= 0 and not p.fibre and p.precise and p.plume_heat > 2.2 and p.height > 0.08:
		# Hot gases wash the exposed underside. Burning still requires
		# volatiles released by that wood, and sustained flame must pay for drying.
		hot_gas = smoothstep(254.0, 427.0, t + minf(86.0, p.plume_heat * 6.0))
	var mixing_loss := smoothstep(1.45, 2.05, crowd) if p.precise and p.layer == 0 else 0.0
	var flame_air := smoothstep(0.085 + 0.20 * mixing_loss, 0.48 + 0.28 * mixing_loss, p.oxygen)
	if p.fibre:
		flame_air = smoothstep(0.21, 0.68, p.oxygen)
	var dilution := 1.0 / (1.0 + 0.50 * air * air + 210.0 * p.vapor)
	var burned_gas := minf(p.gas, p.gas * dt * 2.5 * hot_gas * flame_air * dilution)
	p.gas_used = burned_gas
	p.ignition = hot_gas * flame_air * dilution * smoothstep(0.0, 0.0015, p.gas)
	p.gas -= burned_gas
	var vented := p.gas * (1.0 - exp(-dt * (0.65 + air * 0.58)))
	p.gas -= vented
	p.flame = burned_gas * 15_800.0 / dt
	p.smoke = (vented + oxidised * 0.09) / dt

	var char_air := minf(1.2, p.oxygen * (0.87 + air * 0.85))
	var char_rate := 0.00062 * surface * char_air * smoothstep(345.0, 650.0, t) * p.oxidation_factor
	if is_coal:
		char_rate *= 0.55 + p.char_porosity
	var burned_char := minf(p.char_mass, dt * char_rate * minf(1.0, p.char_mass / 0.028))
	p.char_mass -= burned_char
	p.shed = minf(p.shed, p.char_mass)
	p.char_heat = burned_char * 26_000.0 / dt
	p.charcoal_used = burned_char
	p.mineral += burned_char * 0.073

	var excess := t - room
	var exposed_to_air := _exposed(p, air)
	var cooling := p.convection_loss + p.radiation_out
	p.drying_heat = p.vapor * 2260.0
	p.decomposition_heat = (charred * 310.0 + resin_vapor * 230.0) / dt
	p.reaction_heat = p.flame + p.char_heat + p.smolder
	# Small charcoal has little cold backing. Keep a greater share of the
	# carbon reaction at its surface, paid entirely from the oxidised mass.
	var retained := 0.25
	if is_coal:
		var small_particle := 1.0 - smoothstep(0.018, 0.075, p.char_mass)
		var cold_backing := 1.0 - smoothstep(0.015, 0.045, p.base_capacity)
		retained += 0.34 * small_particle * cold_backing * (1.0 - smoothstep(550.0, 700.0, t))
	var fibre_heat := lerpf(0.021, 0.46, 1.0 - exposed_to_air)
	if p.kind == TINDER_BUNDLE:
		fibre_heat = lerpf(0.40, 0.58, 1.0 - exposed_to_air)
	elif p.fibre:
		fibre_heat += 0.40 * smoothstep(0.32, 0.95, ventilation)
	var flame_retained := 0.115
	if p.layer < 0 and p.precise and p.height > 0.08:
		flame_retained += 0.13 * smoothstep(0.0, 4.0, p.plume_heat)
	var local_heat := p.flame * flame_retained + p.char_heat * (retained if is_coal else 0.28) + p.smolder * fibre_heat
	p.breath_balance = 0.0
	if is_coal and p.pulse > 0.05:
		var background := background_wind(p.at, p.height, p.id).length()
		var still_pores := _pore_air(p.pore_density)
		var still_oxygen := oxygen * exp(-1.67 * cover) * still_pores * (1.0 - 0.7 * smoothstep(0.12, 1.8, crowd))
		var still_air := minf(1.2, still_oxygen * (0.87 + background * 0.85))
		var oxidation_gain := p.char_heat * retained * (1.0 - still_air / maxf(0.001, char_air))
		p.breath_balance = oxidation_gain - surface * insulation * exposed_to_air * excess * 0.0035 * (air * air - background * background)
	var net := transferred + local_heat - cooling - p.drying_heat - p.decomposition_heat
	p.temperature = clampf(t + net * dt / capacity, minf(t, room - (2.5 if after_storm else 0.0)), 1160.0)
	p.trend = lerpf(p.trend, (p.temperature - t) / dt, 1.0 - pow(0.83, dt / STEP))
	return (burned_gas * 1.45 + burned_char * 2.65 + oxidised * 0.91) / dt

func enable_after_storm_materials() -> void:
	for piece in all_fuel():
		_seed_resin(piece)

func _seed_resin(piece: Piece) -> void:
	if piece.material != Materials.PINE or piece.resin_seed != 0:
		return
	piece.resin_seed = piece.id
	var variation := posmod(piece.id * 37 + 11, 17)
	if variation < 6 or piece.original < 0.025:
		return
	var pocket := piece
	if not piece.sections.is_empty():
		var section := piece.sections[posmod(piece.id * 7, piece.sections.size())]
		pocket = section.faces[posmod(piece.id * 3, 2)]
	pocket.resin_seed = piece.id
	pocket.resin = pocket.wood * lerpf(0.024, 0.088, variation / 16.0)

func _release_resin(piece: Piece, evaporated: float, dt: float) -> float:
	var release := minf(piece.wood, minf(piece.resin,
		piece.original * 0.037 * smoothstep(128.0, 330.0, piece.temperature) * dt))
	piece.resin = minf(piece.wood - release, piece.resin - release)
	piece.wood -= release
	piece.gas += release
	piece.charred_wood += release
	# A smaller opening keeps more pressure behind a knot or a damp skin.
	var seal := smoothstep(0.030, 0.061, piece.radius) * (1.0 - smoothstep(0.10, 0.62, piece.charred_wood / piece.original))
	var trapped_steam := evaporated * seal * smoothstep(0.13, 0.65, piece.water / piece.original)
	piece.pocket_pressure *= exp(-dt * (0.82 + 1.55 * (1.0 - seal)))
	piece.pocket_pressure += (release * 13.0 + trapped_steam * 19.0) / piece.original
	if piece.temperature >= 88.0:
		_pop_if_pressurized(piece)
	return release

func _pop_if_pressurized(piece: Piece) -> void:
	var trigger := 0.090 + 0.049 * float(posmod(piece.id + piece.owner + piece.pops * 3, 11)) / 10.0
	if piece.pocket_pressure >= trigger:
		var pressure := piece.pocket_pressure
		piece.pocket_pressure *= 0.24
		piece.pops += 1
		structure_event.emit("pop", piece.at, pressure, piece.height, piece.temperature)
		_eject_spark(piece, pressure)

func _eject_spark(piece: Piece, pressure: float) -> void:
	if piece.temperature < 365.0 or piece.char_mass < 0.00013 or sparks.size() >= 20:
		return
	var fragment := Spark.new()
	fragment.source = piece.owner if piece.owner > 0 else piece.id
	var seed := fragment.source * 2.399963 + piece.pops * 1.73 + piece.layer * 0.67 + piece.at.x * 0.9
	var outward := Vector2.from_angle(seed)
	var speed := clampf(0.78 + pressure * 4.7, 0.9, 2.55)
	var horizontal := outward * speed + piece.draft.limit_length(0.55) * 0.35
	fragment.position = Vector3(piece.at.x, piece.at.y, maxf(0.04, piece.height + 0.024))
	fragment.velocity = Vector3(horizontal.x, horizontal.y, 2.0 + minf(1.42, pressure * 5.2))
	fragment.mass = minf(piece.char_mass * 0.30, clampf(pressure * 0.007, 0.00010, 0.00135))
	fragment.temperature = piece.temperature
	piece.char_mass -= fragment.mass
	piece.shed = minf(piece.shed, piece.char_mass)
	spark_ejections += 1
	sparks.append(fragment)

func _advance_sparks(dt: float, room: float) -> void:
	var fuel := all_fuel()
	for index in range(sparks.size() - 1, -1, -1):
		var fragment := sparks[index]
		if fragment.surface == null:
			_fly_spark(fragment, fuel, dt, room)
		else:
			_warm_spark_contact(fragment, dt, room)
		var settled := fragment.surface == null and (fragment.position.z <= 0.0 or fragment.age >= 1.18)
		var spent := fragment.mass < 0.000012 or fragment.temperature < room + 35.0 or fragment.contact_age >= 4.5
		if settled or spent:
			spark_ground_carbon += fragment.mass
			sparks.remove_at(index)

func _fly_spark(fragment: Spark, fuel: Array[Piece], dt: float, room: float) -> void:
	fragment.flight = PackedVector3Array([fragment.position])
	var remaining := dt
	while remaining > 0.00001 and fragment.surface == null and fragment.position.z > 0.0:
		var interval := minf(remaining, 0.05)
		remaining -= interval
		var before := fragment.position
		var air := background_wind(Vector2(before.x, before.y), before.z, fragment.source)
		var wind := Vector3(air.x, air.y, 0.0)
		var acceleration := (wind - fragment.velocity) * 0.63 - Vector3(0.0, 0.0, GRAVITY)
		fragment.position += fragment.velocity * interval + acceleration * (0.5 * interval * interval)
		fragment.velocity += acceleration * interval
		fragment.age += interval
		var small := 1.0 - smoothstep(0.00012, 0.00125, fragment.mass)
		fragment.temperature = lerpf(room, fragment.temperature, exp(-interval * (0.76 + 2.35 * small)))
		var end := fragment.position
		if end.z < 0.0:
			end = before.lerp(end, before.z / (before.z - end.z))
		_spark_hit(fragment, fuel, before, end)
		var touched_ground := fragment.surface == null and fragment.position.z <= 0.0
		if touched_ground:
			fragment.position = Vector3(end.x, end.y, 0.0)
		fragment.flight.append(fragment.position)
		if touched_ground:
			spark_grounded.emit(fragment)

func _spark_hit(fragment: Spark, fuel: Array[Piece], start: Vector3, end: Vector3) -> void:
	var nearest := INF
	for piece in fuel:
		if piece.id == fragment.source or piece.pose == null or piece.wood <= 0.0:
			continue
		var at := Vector2(end.x, end.y)
		if piece.at.distance_squared_to(at) > pow(piece.size + piece.radius + start.distance_to(end) + 0.04, 2.0):
			continue
		var span := piece.pose.span
		var closest := Geometry3D.get_closest_points_between_segments(start, end, piece.pose.point(-span), piece.pose.point(span))
		var along := (closest[1] - piece.pose.point(0.0)).dot(Vector3(piece.axis.x, piece.axis.y, piece.pose.slope).normalized())
		var section := piece.cross_section(along / maxf(0.01, span))
		var radius := section.radius + 0.014
		var depth := start.distance_squared_to(closest[0])
		if depth >= nearest or closest[0].distance_squared_to(closest[1]) > radius * radius:
			continue
		nearest = depth
		fragment.receiver = piece
		fragment.surface = section if section.faces.is_empty() else section.faces[0 if closest[0].z >= closest[1].z else 1]
		fragment.position = closest[0]
	if fragment.surface != null:
		spark_landings += 1
		var pose := fragment.receiver.pose
		var offset := Vector2(fragment.position.x, fragment.position.y) - pose.at
		var along := offset.dot(pose.axis)
		fragment.contact_offset = Vector3(along, offset.dot(pose.axis.orthogonal()), fragment.position.z - pose.point(along).z)
		if fragment.receiver in stored:
			stored.erase(fragment.receiver)
			wood.append(fragment.receiver)
			network_dirty = true
			_invalidate_wind_stock()

func _warm_spark_contact(fragment: Spark, dt: float, room: float) -> void:
	if not has_fuel(fragment.receiver):
		fragment.contact_age = 4.5
		return
	var target := fragment.surface
	var pose := fragment.receiver.pose
	var offset := fragment.contact_offset
	var side := pose.axis.orthogonal() * offset.y
	fragment.position = pose.point(offset.x, offset.z) + Vector3(side.x, side.y, 0.0)
	fragment.flight.clear()
	fragment.contact_age += dt
	var capacity := fragment.mass * 1.15
	var exposed_area := pow(clampf(fragment.mass / 0.0012, 0.01, 1.3), 0.67)
	var burned := minf(fragment.mass * 0.26, dt * 0.00027 * exposed_area *
		smoothstep(310.0, 565.0, fragment.temperature) * target.oxygen)
	fragment.mass -= burned
	spark_oxidized += burned
	# Part of the oxidation heat stays in the fragment and the contact.
	# Loose fibres screen it from the surroundings while air still reaches it.
	var retained := 0.41 if target.fibre else 0.29
	var own_heat := burned * 26_000.0 * retained
	var exposure := 0.49 if target.fibre else 0.72
	fragment.temperature = minf(1160.0, lerpf(room, fragment.temperature + own_heat / capacity, exp(-dt * exposure)))
	var target_capacity := target.capacity()
	var heat := maxf(0.0, fragment.temperature - target.temperature) * minf(capacity, target_capacity) * minf(0.48, dt * 1.15)
	fragment.temperature -= heat / capacity
	target.temperature += heat / target_capacity
	spark_heat_delivered += heat

func _pore_air(density: float) -> float:
	return 1.0 - 0.97 * smoothstep(0.94, 2.04, density)

func total_flame() -> float:
	var result := 0.0
	for piece in wood:
		result += piece.flame
	return result

func coal_reserve() -> float:
	var result := 0.0
	for coal in coals:
		result += coal.char_mass
	return result

func thermal_sources() -> Array[Piece]:
	var sources := coals.duplicate()
	for piece in wood:
		if piece.sections.is_empty():
			sources.append(piece)
		else:
			sources.append_array(piece.sections)
	return sources

func heat_at(at: Vector2) -> float:
	# Perceptual warmth used by the cursor and audio. The solver uses kW
	# from each surface's radiation ledger and its cached links.
	var radiant := 0.0
	for coal in coals:
		radiant += radiant_power(coal) / (1.0 + coal.at.distance_squared_to(at) * 14.0)
	for piece in wood:
		if piece.sections.is_empty():
			radiant += radiant_power(piece) / (1.0 + piece.at.distance_squared_to(at) * 9.0)
		else:
			for section in piece.sections:
				radiant += radiant_power(section) / (1.0 + section.at.distance_squared_to(at) * 9.0)
	return radiant

func radiant_power(p: Piece) -> float:
	var exposed: Piece = p.faces[0] if p.core != null else p
	var excess := maxf(0.0, exposed.temperature - ambient()) / 680.0
	var area := minf(1.0, (p.char_mass * 8.0 + p.mineral * 5.0 + p.cover * 8.0) if p.kind < 0 else p.size * 4.0)
	return p.flame * 0.024 + area * p.fraction * pow(excess, 2.4) * (0.12 + 0.88 * exp(-5.0 * p.depth()))





