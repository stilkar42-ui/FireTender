extends SceneTree

const Bench := preload("res://tools/stockpile_benchmark.gd")
const Chapter := preload("res://sim/red_hollow.gd")
const Fire := Chapter.Fire
const Save := preload("res://sim/chapter_save.gd")
const Lab := preload("res://hearth/hearth.tscn")
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var benchmark := Bench.new()
	var story := Chapter.new(Fire.new())
	benchmark._setup(story, {"stock": 100, "drying": 72, "speed": 1,
		"state": "flame", "layout": "bonfire", "mode": "normal"})
	benchmark.free()
	var fire := story.fire
	_check(fire.wood.size() >= 72 and fire.total_flame() > 1.0,
		"A 72-log bonfire burns beside a 100-piece woodpile")
	var state := Save.capture(story)
	var bytes := var_to_bytes(state)
	print("Bonfire snapshot bytes ", bytes.size(), ", nodes ", fire.nodes.size(), ", links ", fire.thermal_link_count())
	_check(bytes.size() < Save.MAX_BYTES, "The large burning fire fits inside a normal save")
	var path := OS.get_environment("TEMP").path_join("firetender-bonfire-%d.sav" % OS.get_process_id())
	_check(Save.write_state(path, state) == OK and not Save.read_slot(path).is_empty(),
		"The bonfire writes and reads through the normal save-slot API")
	print("Compressed bonfire save bytes ", FileAccess.get_file_as_bytes(path).size())
	DirAccess.remove_absolute(path)
	var restored := Chapter.new(Fire.new())
	_check(Save.restore(restored, bytes_to_var(bytes)), "The bonfire restores from a binary save")
	for i in 4:
		story.step()
		restored.step()
	var expected := Save.capture(story)
	var actual := Save.capture(restored)
	expected.erase("saved_at")
	actual.erase("saved_at")
	_check(expected == actual, "Bonfire save continuation preserves every physical and structural field")
	var corrupt: Dictionary = bytes_to_var(bytes)
	var packed: PackedFloat64Array = corrupt.fire.packed_links.duplicate()
	packed[0] = 0.5
	corrupt.fire.packed_links = packed
	_check(not Save.restore(Chapter.new(Fire.new()), corrupt), "Malformed packed topology is rejected")
	_legacy_save()
	_placement()
	_fracture()
	_capacity_limit()
	if DisplayServer.get_name() != "headless":
		await _camera()
	print("Bonfire checks failed ", failed)
	quit(1 if failed else 0)

func _placement() -> void:
	var story := Chapter.new(Fire.new())
	story.set_up_after_storm_trial()
	var fire := story.fire
	fire.wood.clear()
	fire.stored.clear()
	fire.coals.clear()
	var placed := 0
	for i in 48:
		var piece := fire.receive_fuel(10, Vector2(-2.4, -3.0), 0, 0, 0.12)
		var tier: int = i / 6
		var across: float = (i % 6 - 2.5) * 0.105
		var at := Vector2(0, across) if tier % 2 == 0 else Vector2(across, 0)
		if fire.pose_fuel(piece, at, 0.0 if tier % 2 == 0 else PI * 0.5, 0.0, tier, true):
			placed += 1
	_check(placed == 48 and fire.wood.size() == 48, "Normal player placement accepts 48 individual logs")

func _legacy_save() -> void:
	var story := Chapter.new(Fire.new())
	var snapshot := Save.capture(story)
	snapshot.version = 4
	snapshot.fire.erase("packed_links")
	snapshot.fire.links = Save._objects(story.fire.links)
	snapshot.fire.radiant_links = Save._objects(story.fire.radiant_links)
	var path := OS.get_environment("TEMP").path_join("firetender-old-bonfire-%d.sav" % OS.get_process_id())
	var bytes := var_to_bytes(snapshot)
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_buffer(Save._digest(bytes))
	handle.store_buffer(bytes)
	handle.close()
	var saved := Save.read_slot(path)
	_check(not saved.is_empty() and Save.restore(Chapter.new(Fire.new()), saved),
		"Version 4 saves with object-based links still restore")
	DirAccess.remove_absolute(path)

func _capacity_limit() -> void:
	var benchmark := Bench.new()
	var story := Chapter.new(Fire.new())
	benchmark._setup(story, {"stock": 0, "drying": Fire.MAX_WOOD, "speed": 1,
		"state": "flame", "layout": "bonfire", "mode": "normal"})
	benchmark.free()
	_check(story.fire.nodes.size() > 1024 and story.fire.packed_topology,
		"The full placement capacity stays on the native graph path above 1024 nodes")
	var path := OS.get_environment("TEMP").path_join("firetender-max-bonfire-%d.sav" % OS.get_process_id())
	var snapshot := Save.capture(story)
	var error := Save.write_state(path, snapshot)
	print("Full capacity nodes ", story.fire.nodes.size(), ", snapshot bytes ", var_to_bytes(snapshot).size(),
		", file bytes ", FileAccess.get_file_as_bytes(path).size() if error == OK else 0)
	_check(error == OK and not Save.read_slot(path).is_empty(), "A fire at full placement capacity can be saved")
	DirAccess.remove_absolute(path)

func _fracture() -> void:
	var fire := Fire.new(Fire.GRAIN_END)
	var beam: Fire.Piece = fire.wood.back()
	for i in 40:
		fire.receive_fuel(7, Vector2(0.7, 0.7), 0, i, 0.1)
	fire.wood.append_array(fire.stored)
	fire.stored.clear()
	var region := beam.sections[1]
	for cell: Fire.Piece in region.faces + region.inner + [region.core]:
		cell.wood = cell.original * 0.025
		cell.water *= 0.1
		cell.charred_wood = cell.original * 0.975
		cell.char_mass = cell.original * 0.07
		cell.temperature = 610.0
	fire._sync_sections(beam)
	fire._update_section_shape(beam)
	var mass := beam.mass()
	var before := fire.wood.size()
	var split := fire._fracture_weak_section(beam)
	_check(split and fire.wood.size() == before + 1 and
		is_equal_approx(mass, beam.mass() + fire.wood.back().mass()),
		"Sectional fracture still conserves material in a large active fire")

func _camera() -> void:
	var lab := Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-bonfire-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	lab.paused = true
	lab.chapter.set_up_after_storm_trial()
	await process_frame
	var view = lab.view.workbench
	for site in Fire.Shelter.DEPTHS.size():
		lab.fire.shelter.site = site
		view._update_shelter()
		view.camera_dirty = false
		for i in 12:
			view._update_shelter()
		_check(not view.camera_dirty, "Idle camera stays clean at cave site %d" % site)
	view.orbit(Vector2(5, 2))
	_check(view.camera_dirty, "Player camera movement still requests an immediate refresh")
	var changed := {"count": 0}
	view.geometry_changed.connect(func(): changed.count += 1)
	var parcel: Fire.Piece = lab.fire.receive_fuel(10, Vector2(-2.0, -3.0), 0.0, 0, 0.12)
	lab.fire.move_fuel(parcel, Vector2(0.14, 0.12))
	view._refresh(0.0)
	_check(changed.count == 1, "Changed fuel geometry refreshes picking and placement previews")
	lab.queue_free()
	await process_frame

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failed += 1
		printerr("FAIL ", message)
