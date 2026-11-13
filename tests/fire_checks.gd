extends SceneTree

const Fire := preload("res://sim/fire.gd")
const Observe := preload("res://sim/observe.gd")
const Audio := preload("res://hearth/fire_audio.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	_moisture()
	_combustion()
	_refuel_bed()
	_banking()
	_draft_and_weather()
	_arrangement()
	_cold_hearth()
	_local_deposits()
	_turning()
	_concentrate()
	_breathing()
	_senses()
	_extended_run()
	print("Firetender: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS  ", title)
	else:
		failed += 1
		printerr("FAIL  ", title)

func _moisture() -> void:
	var dry := Fire.new(1)
	var wet := Fire.new(1)
	# Match everything except water load.
	dry.add_fuel(1, Vector2.ZERO)
	var wet_log := wet.add_fuel(1, Vector2.ZERO)
	wet_log.water = wet_log.wood * 0.86
	var dry_peak := _advance(dry, 40.0)
	var wet_peak := _advance(wet, 40.0)
	print("      Matched logs, peak flame %.1f kW dry / %.1f kW wet" % [dry_peak, wet_peak])
	_check(dry_peak > 8.0 and wet_peak < dry_peak * 0.3,
		"Water delays ignition and reduces peak flaming in matched fuel")

	var weak := Fire.new(2)
	var loaded := Fire.new(2)
	loaded.add_fuel(3, Vector2.ZERO)
	_advance(weak, 12.0)
	_advance(loaded, 12.0)
	_check(_hottest(loaded) < 345.0 and _hottest(weak) > 345.0,
		"Cold wet oak quenches weak coals that would otherwise still glow")
	_check("hisses" in Observe.read(loaded), "Inspection describes visible evaporation from wet wood")

func _combustion() -> void:
	var hearth := Fire.new(1)
	var twig := hearth.add_fuel(1, Vector2.ZERO)
	var unlit_note := Observe.read(hearth)
	var peak := 0.0
	var peak_char := 0.0
	for tick in range(160):
		hearth.step()
		peak = maxf(peak, twig.flame)
		peak_char = maxf(peak_char, twig.char_mass)
	_check("no standing flame" in unlit_note and "glows" in unlit_note,
		"Inspection distinguishes a glowing bed from flames")
	_check(peak > 8.0, "Healthy coals naturally ignite room-temperature twigs")
	_check(peak_char > 0.006, "Wood pyrolysis yields a solid charcoal residue")
	_check(not twig in hearth.wood and _hottest(hearth) > 400.0 and hearth.total_flame() < 0.5,
		"Burned-down twigs leave the bed glowing after the flames disappear")
	hearth.rake()
	hearth.add_fuel(0, Vector2.ZERO)
	_check(_advance(hearth, 18.0) > 3.0, "Dry bark can rekindle from the post-flame bed")

func _refuel_bed() -> void:
	var single := Fire.new(1)
	var open := Fire.new(1)
	var packed := Fire.new(1)
	var cold := Fire.new(Fire.COLD)
	single.add_fuel(1, Vector2.ZERO, 0.0, 0.0, 0, true)
	for i in range(3):
		var at := Vector2(0.0, (i - 1) * 0.27)
		open.add_fuel(1, at, 0.0, 0.0, 0, true)
		packed.add_fuel(1, Vector2.ZERO, 0.0, 0.0, i, true)
		cold.add_fuel(1, at, 0.0, 0.0, 0, true)
	var single_peak := _advance(single, 30.0)
	var open_peak := _advance(open, 30.0)
	var packed_peak := _advance(packed, 30.0)
	print("      Refuel a 3D coal bed: %.1f kW one bundle, %.1f kW three spaced, %.1f kW three stacked" %
		[single_peak, open_peak, packed_peak])
	_check(single_peak > 8.0 and open_peak > single_peak * 1.5,
		"Several spaced bundles of kindling can catch and strengthen the fire")
	_check(packed_peak < 5.0 and _hottest(packed) > 450.0,
		"Packing the same kindling suppresses flame even while the bed stays hot")
	_check(_advance(cold, 30.0) == 0.0, "An equally open load gets no ignition energy from a cold bed")

	var staged := Fire.new(1)
	staged.add_fuel(1, Vector2.ZERO, 0.0, 0.0, 0, true)
	_advance(staged, 7.5)
	staged.add_fuel(2, Vector2(0.0, -0.105), PI * 0.5, 0.0, 1, true)
	_advance(staged, 17.5)
	var second := staged.add_fuel(2, Vector2(-0.18, 0.0), PI * 0.5, 0.0, 1, true)
	_advance(staged, 35.0)
	_check(second.flame > 10.0 and staged.total_flame() > 60.0,
		"Adding two splits in stages carries flame from the kindling into larger wood")

func _banking() -> void:
	var exposed := Fire.new(1)
	var covered := Fire.new(1)
	exposed.rake()
	covered.rake()
	var reserve := covered.ash
	_check(covered.bank() and covered.ash < reserve, "Banking consumes real loose ash")
	covered.step()
	_check(covered.coals[3].oxygen < 0.45 and "through the ash" in Observe.read(covered),
		"Ash reduces oxygen and produces a covered-heat observation")
	var exposed_duration := _glow_duration(exposed)
	var banked_duration := _glow_duration(covered)
	print("      Glow survival %.0f s exposed / %.0f s banked" % [exposed_duration, banked_duration])
	_check(banked_duration > exposed_duration * 3.0, "Banking extends glowing survival by at least threefold")

	var rested := Fire.new(3)
	_advance(rested, 300.0)
	rested.uncover()
	rested.add_fuel(1, Vector2.ZERO)
	_check(_advance(rested, 25.0) > 8.0, "Uncovered coals can light kindling after a five-minute bank")
	var ash_total := rested.ash
	for p in rested.coals:
		ash_total += p.cover
	rested.bank()
	rested.uncover()
	_check(is_equal_approx(rested.ash, ash_total), "Banking and exposing preserve the ash supply")

func _draft_and_weather() -> void:
	var calm := Fire.new(1)
	var gentle := Fire.new(1)
	var blast := Fire.new(1)
	gentle.blow()
	blast.weather = 2
	for pulse in range(5):
		blast.blow()
	_advance(calm, 1.0)
	_advance(gentle, 1.0)
	_advance(blast, 1.0)
	_check(gentle.coals[3].char_heat > calm.coals[3].char_heat,
		"A short moderate draft increases charcoal oxidation")
	_advance(calm, 35.0)
	_advance(blast, 35.0)
	_check(_hottest(blast) < _hottest(calm) - 70.0, "A hard crosswind and strong fanning cool the bed")

	var rain := Fire.new(1)
	var cold := Fire.new(1)
	var sheltered := Fire.new(1)
	rain.weather = 3
	cold.weather = 1
	var rain_fuel := rain.add_fuel(2, Vector2(0.88, 0.0))
	var dry_fuel := sheltered.add_fuel(2, Vector2(0.88, 0.0))
	for fire in [rain, cold, sheltered]:
		_advance(fire, 90.0)
	_check(rain_fuel.water > dry_fuel.water + 0.02 and _hottest(rain) < _hottest(sheltered),
		"Rain wets exposed fuel and drains heat from the bed")
	_check(_hottest(cold) < _hottest(sheltered), "Cold air increases net heat loss")

func _arrangement() -> void:
	var near := Fire.new(1)
	var far := Fire.new(1)
	var moved := far.add_fuel(1, Vector2.ZERO)
	near.add_fuel(1, Vector2.ZERO)
	far.move_fuel(moved, Vector2(-0.87, 0.0))
	_check(_advance(near, 25.0) > 8.0 and _advance(far, 25.0) < 0.5,
		"Moving kindling out of contact prevents ignition")

	var packed := Fire.new(0)
	var open := Fire.new(0)
	for i in range(8):
		packed.add_fuel(2, packed.wood[0].at)
	packed.step()
	open.step()
	_check(packed.wood[0].oxygen < open.wood[0].oxygen * 0.6 and packed.total_flame() < open.total_flame(),
		"Packing wood tightly cuts local oxygen and flame output")

func _cold_hearth() -> void:
	var hearth := Fire.new(2)
	hearth.add_fuel(3, Vector2.ZERO)
	_advance(hearth, 900.0)
	_check("dark" in Observe.read(hearth) and _hottest(hearth) < 20.0, "An untended quenched hearth eventually cools")
	hearth.rake()
	hearth.bank()
	hearth.uncover()
	hearth.blow()
	hearth.add_fuel(0, Vector2.ZERO)
	hearth.add_fuel(1, Vector2.ZERO)
	_check(_advance(hearth, 300.0) == 0.0 and _hottest(hearth) < 20.0,
		"Tending and dry fuel cannot resurrect an extinguished bed")

func _extended_run() -> void:
	var first := Fire.new()
	var second := Fire.new()
	var valid := true
	var matched := true
	for tick in range(28800):
		if tick % 2400 == 0:
			for hearth in [first, second]:
				hearth.weather = (tick / 2400) % 4
				hearth.add_fuel(3, Vector2.ZERO)
				hearth.add_fuel(1, Vector2(0.12, -0.05))
				hearth.blow()
				hearth.send_breath(Vector2(0.0, 0.9), Vector2.ZERO, 0.84, 1.6)
				if tick % 4800 == 0:
					hearth.bank()
				else:
					hearth.rake()
		first.step()
		second.step()
		if tick % 40 != 0:
			continue
		matched = matched and first.total_flame() == second.total_flame() and first.ash == second.ash
		valid = valid and first.oxygen >= 0.0 and first.oxygen <= 1.0 and first.ash >= 0.0
		var others := second.coals + second.wood
		var pieces := first.coals + first.wood
		matched = matched and pieces.size() == others.size()
		for i in range(pieces.size()):
			var p := pieces[i]
			# A cold core does not snap up to the new ambient when weather changes.
			valid = valid and is_finite(p.temperature) and p.temperature <= 1160.0 and p.temperature >= -14.0001
			valid = valid and minf(p.wood, minf(p.char_mass, minf(p.water, p.gas))) >= 0.0
			matched = matched and p.temperature == others[i].temperature and p.char_mass == others[i].char_mass
			matched = matched and p.at == others[i].at and p.mineral == others[i].mineral and p.oxygen == others[i].oxygen
			if p.core != null:
				for j in range(p.faces.size()):
					matched = matched and p.faces[j].temperature == others[i].faces[j].temperature
	_check(valid and first.time == 7200.0, "Two simulated hours of batched steps keep masses and temperatures bounded")
	_check(matched, "Identical action sequences produce identical simulation states")

func _local_deposits() -> void:
	var hearth := Fire.new(4)
	var log := hearth.wood[0]
	var deposit: Fire.Piece = hearth.coals.back()
	var initial_char := deposit.char_mass
	var initial_ash := deposit.mineral
	var opposite := hearth._new_coal(Vector2(0.64, 0.10), 0.035, 410.0, 0.040)
	var original_opposite := opposite.char_mass
	_advance(hearth, 45.0)
	_check(deposit in hearth.coals and deposit.at.distance_to(log.at) < 0.35 and
		deposit.char_mass > initial_char + 0.003 and deposit.mineral > initial_ash + 0.0001 and
		opposite.char_mass <= original_opposite,
		"A · Charcoal and mineral ash develop under the log's footprint")
	_check(opposite.temperature < 350.0 and hearth.heat_at(log.at) > hearth.heat_at(opposite.at) * 3.0,
		"A · An isolated patch cools while the burning side stays hot")
	var neighbor := hearth.add_fuel(0, log.at + Vector2(0.22, -0.04))
	_advance(hearth, 8.0)
	_check(neighbor.charred_wood > 0.001, "A · A burning zone ignites adjacent fresh bark")

func _turning() -> void:
	var hearth := Fire.new(5)
	var control := Fire.new(5)
	var log := hearth.wood[0]
	var top := log.faces[0]
	var underside := log.faces[1]
	var core_temp := log.core.temperature
	var wood_mass := log.wood
	var water := log.water
	var char_mass := log.char_mass
	var sensible := log.temperature * log.capacity()
	_check(underside.charred_wood > top.charred_wood + 0.01 and underside.temperature > top.temperature + 100.0,
		"B · Oak chars unevenly while its core stays cooler")
	_check(hearth.turn_fuel(log) and log.faces[0] == underside and log.faces[1] == top
		and is_equal_approx(log.wood, wood_mass) and is_equal_approx(log.water, water)
		and is_equal_approx(log.char_mass, char_mass) and log.core.temperature == core_temp
		and is_equal_approx(log.temperature * log.capacity(), sensible),
		"B · Rolling swaps actual faces and preserves mass and sensible heat")
	_advance(hearth, 4.0)
	_advance(control, 4.0)
	_check(absf(log.faces[0].temperature - control.wood[0].faces[0].temperature) > 35.0,
		"B · The newly exposed face follows a different thermal trajectory")

func _concentrate() -> void:
	var gathered := Fire.new(6)
	var scattered := Fire.new(6)
	gathered.coals[0].mineral = 0.007
	var reserve := gathered.coal_reserve()
	var initial := _bed_energy(gathered)
	var source := gathered.coals[0].at
	var remote := gathered.coals[3].at
	var ash := gathered.coals[0].mineral
	_check(gathered.rake_at(source, Vector2.ZERO, 0.24) == 1
		and gathered.coals[0].at.is_equal_approx(Vector2.ZERO) and gathered.coals[3].at == remote
		and gathered.coals[0].mineral == ash and gathered.coal_reserve() == reserve
		and is_equal_approx(_bed_energy(gathered), initial), "C · Raking moves only the selected coals and carries their heat")
	for coal in gathered.coals:
		if coal.at.length() > 0.25:
			gathered.rake_at(coal.at, coal.at.normalized() * 0.15, 0.18)
	gathered.add_fuel(1, Vector2.ZERO)
	scattered.add_fuel(1, Vector2.ZERO)
	var lit := _advance(gathered, 24.0)
	var diffuse := _advance(scattered, 24.0)
	print("      Peak flame after raking %.1f kW / scattered %.1f kW" % [lit, diffuse])
	_check(lit > 8.0 and diffuse < 1.0, "C · Concentrated embers ignite kindling that scattered coals do not")

func _bed_energy(hearth: Fire) -> float:
	var heat := 0.0
	for coal in hearth.coals:
		heat += coal.temperature * coal.capacity()
	return heat

func _breathing() -> void:
	var calm := Fire.new(7)
	var paced := Fire.new(7)
	var blast := Fire.new(7)
	var aim := paced.coals[0].at
	var start := aim + Vector2(0.0, 0.45)
	var gentle_peak := 0.0
	var hard_peak := 0.0
	var calm_peak := 0.0
	var helped := false
	for tick in range(72):
		if tick % 7 == 0:
			paced.send_breath(start, aim, 0.84, 1.30)
			blast.send_breath(start, aim, 3.05, 1.30)
		paced.step()
		blast.step()
		calm.step()
		if tick == 2:
			helped = paced.coals[0].oxygen > calm.coals[0].oxygen and paced.coals[0].char_heat > calm.coals[0].char_heat
			_check(paced.coals[0].pulse > 0.3 and paced.coals[1].pulse < 0.01,
				"D · Aimed airflow reaches the target without reaching the opposite patch")
			_check("brightens" in Observe.warmth(paced, aim) and "draws heat away" in Observe.warmth(blast, aim),
				"D · Local feedback distinguishes increased oxidation from a cooling gust")
		gentle_peak = maxf(gentle_peak, paced.total_flame())
		hard_peak = maxf(hard_peak, blast.total_flame())
		calm_peak = maxf(calm_peak, calm.total_flame())
	_check(helped, "D · Moderate breath raises oxygen and oxidation where the bed was limited")
	print("      Breath trial peak flame %.1f kW paced / %.1f kW hard / %.1f kW calm" % [gentle_peak, hard_peak, calm_peak])
	_check(gentle_peak > 8.0 and calm_peak < 2.0, "D · Repeated moderate breaths ignite adjacent dry tinder")
	_check(blast.coals[0].temperature < 345.0 and hard_peak < 2.0 and blast.coals[0].cover < calm.coals[0].cover,
		"D · Repeated hard gusts disturb ash and cool the bed below useful ignition")

func _senses() -> void:
	var living := Fire.new(4)
	var damp := Fire.new(8)
	var banked := Fire.new(3)
	var dying := Fire.new(9)
	var spot := living.wood[0].at
	_check(living.heat_at(spot) > living.heat_at(Vector2(1.35, 1.35)) * 6.0
		and "left" in Observe.read(living, spot) and "radiant" in Observe.warmth(living, spot),
		"E · Radiant warmth falls with distance and inspection identifies the active side")
	var fire_sound := Audio.measure(living, Vector2.ZERO)
	var wet_sound := Audio.measure(damp, Vector2.ZERO)
	var bank_sound := Audio.measure(banked, Vector2.ZERO)
	var dying_sound := Audio.measure(dying, Vector2.ZERO)
	_check(fire_sound.roar > wet_sound.roar and wet_sound.hiss > fire_sound.hiss
		and fire_sound.pan < -0.2 and bank_sound.bed < 0.15 and dying_sound.roar == 0.0,
		"E · The mixer distinguishes active wood, wet hiss, banked coals and a fading bed")
	_check("hisses" in Observe.read(damp) and "through the ash" in Observe.read(banked)
		and "no standing flame" in Observe.read(dying), "E · Damp, banked and dying observations are distinct")
	var mixer := Audio.new()
	mixer.rng.seed = 1703
	mixer.target = fire_sound
	var samples := mixer.render(Audio.RATE)
	var energy := 0.0
	var finite := true
	for sample in samples:
		energy += sample.length_squared()
		finite = finite and sample.is_finite() and absf(sample.x) <= 1.0 and absf(sample.y) <= 1.0
	_check(finite and energy > 0.5, "E · Procedural fire audio produces bounded non-silent stereo samples")
	mixer.fire_volume = 0.0
	_check(mixer.render(512).count(Vector2.ZERO) == 512, "E · Fire volume can mute fire while weather is quiet")
	damp.weather = 3
	mixer.target = Audio.measure(damp, Vector2.ZERO)
	_check(mixer.render(512).count(Vector2.ZERO) < 512, "E · Weather volume remains audible with fire muted")
	mixer.free()

func _glow_duration(hearth: Fire) -> float:
	while _hottest(hearth) > 370.0 and hearth.time < 2400.0:
		hearth.step()
	return hearth.time

func _hottest(hearth: Fire) -> float:
	var t := hearth.ambient()
	for p in hearth.coals:
		t = maxf(t, p.temperature)
	return t

func _advance(hearth: Fire, seconds: float) -> float:
	var peak := 0.0
	for tick in range(int(seconds / Fire.STEP)):
		hearth.step()
		peak = maxf(peak, hearth.total_flame())
	return peak

