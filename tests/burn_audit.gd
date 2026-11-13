extends SceneTree

const Fire := preload("res://sim/fire.gd")
const LIMIT_SECONDS := 1200.0

func _initialize() -> void:
	print("fuel,dry_g,water_pct,length_cm,diameter_cm,first_flame_s,last_flame_s,flaming_s,half_wood_s,90_pct_converted_s,wood_left_pct")
	for kind in range(Fire.SPECIES.size()):
		_measure(kind)
	print("\ncharcoal,initial_carbon_g,seconds_above_370_c")
	_measure_glow("One Ember", Fire.new(Fire.ONE_EMBER))
	var exposed := Fire.new(1)
	exposed.rake()
	_measure_glow("Exposed raked bed", exposed)
	var banked := Fire.new(1)
	banked.rake()
	banked.bank()
	_measure_glow("Banked raked bed", banked)
	quit()

func _measure(kind: int) -> void:
	var fire := Fire.new(Fire.COLD)
	fire.coals.clear()
	fire.cells.clear()
	fire._trial_bed(0.145, 700.0)
	var fuel := fire.add_fuel(kind, Vector2.ZERO, 0.0, 0.0, 0, true)
	var mass := fuel.original
	var water := fuel.water
	var length := fuel.size * 2.0
	var diameter := fuel.radius * 2.0
	var threshold := clampf(mass * 20.0, 0.25, 2.0)
	var first := -1.0
	var last := -1.0
	var duration := 0.0
	var half := -1.0
	var converted := -1.0
	var remaining := mass
	while fire.time < LIMIT_SECONDS and not fire.wood.is_empty():
		fire.step()
		var flame := 0.0
		remaining = 0.0
		for piece in fire.wood:
			flame += piece.flame
			remaining += piece.wood
		if flame >= threshold:
			if first < 0.0:
				first = fire.time
			last = fire.time
			duration += Fire.STEP
		if half < 0.0 and remaining <= mass * 0.50:
			half = fire.time
		if converted < 0.0 and remaining <= mass * 0.10:
			converted = fire.time
	print("%s,%.1f,%.1f,%.1f,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f" % [Fire.SPECIES[kind].label,
		mass * 1000.0, water / mass * 100.0, length * 100.0, diameter * 100.0, first, last, duration,
		half, converted, remaining / mass * 100.0])

func _measure_glow(label: String, fire: Fire) -> void:
	var carbon := fire.coal_reserve()
	while fire.time < 2400.0 and fire.coals.any(func(coal): return coal.temperature > 370.0):
		fire.step()
	print("%s,%.1f,%.2f" % [label, carbon * 1000.0, fire.time])
