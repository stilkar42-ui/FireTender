extends "res://tests/physical_work_scene_checks.gd"

const T := Work.Techniques

func _run() -> void:
	lab = Lab.instantiate()
	lab.settings_path = OS.get_environment("TEMP").path_join("firetender-stormfall-review-%d.cfg" % OS.get_process_id())
	root.add_child(lab)
	await _settle()
	_key(KEY_F8)
	await _settle()
	var kin = lab.chapter.family
	var props: Props = lab.view.workbench.family_props
	var page = lab.family_page
	await _elapse(22.0)
	await _view_station(Work.HUNTER)
	var job: Dictionary = kin.craft.jobs.get(Work.HUNTER, {})
	var bera = props.actors.bera
	_check(job.get("kind") == "carve" and bera.visible and bera.pose % 3 != 0
		and props.animated_ids.has(job.get("id")), "Bera and the same cut are animated by an autonomous job")
	await _capture("01-autonomous-processing")
	var start_pose: int = bera.pose
	var changed_pose := false
	for step in range(5):
		await _elapse(0.25)
		changed_pose = changed_pose or bera.pose != start_pose
	_check(changed_pose, "Advancing the job changes the painted pose")
	await _elapse(7.0)
	_check(kin.transfer.get("person") == "bera" and bera.walking and bera.travel.visible,
		"Bera's carry animation follows the actual transfer to Nara")
	await _elapse(47.0)
	await _view_station(Work.COOK)
	job = kin.craft.jobs.get(Work.COOK, {})
	_check(job.get("phase") == "warming" and props.actors.nara.visible
		and kin.workshop.parcels.get(job.get("id")).rest == Work.KIN_SPIT,
		"Nara is at her own spit with a portion undergoing actual cooking")
	await _capture("02-nara-cooking")
	await _elapse(13.75)
	await _view_station(Work.MAKER)
	job = kin.craft.jobs.get(Work.MAKER, {})
	_check(job.get("kind") == T.HAFT and props.actors.ina.visible and not job.get("parts", []).is_empty(),
		"Ina works the shaft, point and actual hunting tool")
	await _capture("03-ina-fitting-a-haft")

	_key(KEY_F8)
	await _settle()
	kin = lab.chapter.family
	var model: Work = kin.workshop
	var bone := model.add("bone", 180, Work.HUNTER)
	var learner := model.add("bone", 180, Work.HUNTER)
	var spare := model.add("bone", 180, Work.HUNTER)
	var alongside := model.add("bone", 180, Work.HUNTER)
	var game := model.stock("carcass", Work.HUNTER)[0]
	model._relocate(game, Work.HUNTER, Work.HUNTER_AT + Vector2(0.17, 0.15))
	model._relocate(bone, Work.HUNTER, Work.HUNTER_AT + Vector2(-0.14, 0.12))
	model._relocate(learner, Work.HUNTER, Work.HUNTER_AT + Vector2(0.13, -0.08))
	model._relocate(spare, Work.HUNTER, Work.HUNTER_AT + Vector2(-0.14, -0.10))
	model._relocate(alongside, Work.HUNTER, Work.HUNTER_AT + Vector2(0.10, 0.03))
	page.open_station(Work.HUNTER, false)
	await create_timer(0.55).timeout
	_click(page.learn_button.get_global_rect().get_center())
	await _elapse(4)
	_check(kin.craft.jobs.get(Work.HUNTER, {}).get("demo") and model.parcels.has(bone.id)
		and model.techniques.rank(T.MARROW) == 0, "The Learn button starts a demonstration using a real marrow bone")
	await _capture("04-demonstration")
	await _elapse(16)
	_check(page.teaching_panel.visible and page.teaching_panel.position.y < 150 and page.teacher_art.texture != null
		and page.teacher_name.text == "Bera" and kin.craft.sessions[Work.HUNTER].mode == "supervised",
		"The physically present instructor's portrait appears at the top")
	page.last_coach = -10000
	_hover_item(game.id)
	await _settle()
	_check(page.teacher_words.text.contains("long marrow bone"), "Hovering the wrong physical object prompts corrective guidance")
	await _capture("05-supervision")

	model.techniques.player[T.MARROW] = 18
	_click(page.help_button.get_global_rect().get_center())
	# The regular starting cut is reserved by Bera; set it aside for a matched
	# side-by-side marrow comparison with the same work surface and camera.
	kin.craft.starts_at = lab.chapter.fire.time
	if kin.craft.jobs.has(Work.HUNTER):
		kin.craft._cancel(kin, Work.HUNTER, kin.craft.jobs[Work.HUNTER])
	model._relocate(game, Work.STORE)
	model._relocate(learner, Work.HUNTER, Work.HUNTER_AT + Vector2(0.13, 0.11))
	model._relocate(spare, Work.HUNTER, Work.HUNTER_AT + Vector2(-0.11, -0.09))
	model._relocate(alongside, Work.HUNTER, Work.HUNTER_AT + Vector2(0.10, -0.08))
	await _elapse(7)
	_hover_item(spare.id)
	_key(KEY_V)
	await _elapse(2)
	_check(kin.craft.helper.get("id") == spare.id and kin.craft.jobs.has(Work.HUNTER)
		and page.teacher_task.text.contains("You are helping"), "The Help button and V start independent work alongside Bera")
	await _capture("06-skilled-help")

	kin.people.bera.away = true
	kin.people.mira.away = true
	await _elapse(1)
	_check(not props.actors.bera.visible and not props.actors.mira.visible and page.learn_button.disabled
		and page.teacher_art.texture == null, "An unattended bench has no actor or supervising portrait")
	await _elapse(9)
	_check(not model.parcels.has(spare.id), "Independent work finishes after the teacher leaves")
	_click(page.observe_button.get_global_rect().get_center())
	_move(Vector2(800, 550))
	await _settle()
	await _capture("07-unattended")
	page.toggle_family(4)
	_check(page.family_panel.visible and page.page == 4, "The technique collection is accessible from the family overlay")
	print("Stormfall rendered work: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _view_station(area: String) -> void:
	lab.family_page.open_station(area, false)
	await create_timer(0.55).timeout
	lab.family_page.close_work()
	await _settle()
