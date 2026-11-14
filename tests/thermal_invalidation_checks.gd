extends SceneTree

const Chapter := preload("res://sim/red_hollow.gd")
const Fire := Chapter.Fire
var failures := 0

func _initialize() -> void:
	var story := Chapter.new(Fire.new())
	story.set_up_after_storm_trial()
	var fire := story.fire
	fire.coals.clear()
	fire.wood.clear()
	fire.stored.clear()
	var coal := fire._new_coal(Vector2.ZERO, 0.04, 650.0, 0.04)
	var first := fire.receive_fuel(10, Vector2(0.20, 0.10), 0.0, 0)
	var second := fire.receive_fuel(10, Vector2(0.20, 0.26), 0.0, 0)
	var remote := fire.receive_fuel(10, Vector2(-2.3, -3.4), 0.0, 0)
	fire._refresh_storage_membership()
	fire._settle()
	fire._prepare_network()
	var links := fire.links.duplicate()
	fire.move_fuel(remote, remote.at + Vector2(0.15, 0.0))
	_check(remote in fire.stored and not fire.network_dirty and fire.links == links,
		"Remote stored movement leaves the active graph intact")
	fire.move_fuel(second, Vector2(0.20, 0.39))
	_check(fire.network_dirty, "Moving an active contact invalidates the graph")
	fire._prepare_network()
	_check(fire.links != links, "Contact rebuild replaces the old links")

	# Place a non-endpoint body over the midpoint used by the radiation model.
	var occluder := fire.receive_fuel(10, Vector2(0.90, 0.10), 0.0, 0)
	fire._refresh_storage_membership()
	_check(fire.network_dirty and occluder in fire.wood, "Promotion invalidates membership")
	fire._settle()
	fire._prepare_network()
	var start := Vector3(0.0, 0.065, -0.28)
	var finish := Vector3(0.4, 0.065, -0.28)
	var before := fire._radiation_visibility(start, finish, first, second)
	fire.move_fuel(occluder, Vector2(0.20, -0.28))
	start.y = occluder.height
	finish.y = occluder.height
	_check(fire.network_dirty, "Moving a radiation blocker invalidates geometry")
	fire._prepare_network()
	_check(before == 1.0 and fire._radiation_visibility(start, finish, first, second) == 0.16,
		"Radiation between stationary endpoints sees the moved occluder")
	fire.move_fuel(occluder, Vector2(-2.4, -3.1))
	_check(fire.network_dirty and occluder in fire.stored, "Demotion invalidates membership")
	fire._prepare_network()

	_check(fire.lift_coal(coal) and fire.network_dirty, "Coal lift invalidates contact geometry")
	fire._prepare_network()
	fire.carry_coal(coal, Vector2(0.15, -0.18))
	_check(fire.network_dirty, "Coal translation invalidates contact geometry")
	fire._prepare_network()
	fire._mix(coal, 0.016, 0.0, 0.0, 0.0, 0.0, 500.0)
	_check(fire.network_dirty, "Changed coal material invalidates sampled conductance")
	fire._prepare_network()
	var section := first.sections[0]
	section.upper_radius *= 0.75
	fire.wear_dirty = true
	fire._settle()
	_check(fire.network_dirty, "Section wear invalidates contact geometry")
	quit(1 if failures else 0)

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		printerr("FAIL: ", description)
