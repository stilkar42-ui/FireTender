extends RefCounted
## Discrete labor and continuous heat share the physical workshop. Jobs hold
## actual parcel IDs. Animation reads these records and cannot advance them.

const W := preload("res://sim/family_workshop.gd")
const T := W.Techniques
const AREAS := [W.HUNTER, W.COOK, W.MAKER]
const DIFFICULTY := {"carve": 10.0, "hide": 8.0, T.MARROW: 7.0, T.ROAST: 7.0, T.RESIN: 9.0, T.HAFT: 14.0}
const WORDS := {"carve": "Separating cuts", "hide": "Working hide", T.MARROW: "Splitting a marrow bone",
	T.ROAST: "Tending the roast", T.RESIN: "Working the resin", T.HAFT: "Fitting a haft"}
const ROAST_BAND := Vector2(80, 153)
const RESIN_BAND := Vector2(74, 150)
const COOK_RESTS := [W.KIN_ROAST_AT, Vector2(0.43, 0.13), Vector2(0.65, 0.14)]
const CUP_RESTS := [W.KIN_RESIN_AT, Vector2(0.44, -0.22), Vector2(0.65, -0.23)]

var starts_at := 0.0
var jobs: Dictionary = {}
var sessions: Dictionary = {}
var heat_needs: Dictionary = {}
var heat_announced: Dictionary = {}
var rests_until: Dictionary = {}
var helper: Dictionary = {}
var last_attempt: Dictionary = {}
var completed: Dictionary = {}
var last_result := ""
var revision := 0

static func rate(experience: int, fatigue: float, injury: float, quality: float, tool: float, attention: float) -> float:
	var experience_rate := 0.72 + minf(0.46, experience * 0.027)
	var physical_condition := (1.0 - 0.48 * fatigue) * (1.0 - 0.55 * injury)
	return experience_rate * physical_condition * lerpf(0.61, 1.0, quality) * tool * attention

func begin(now: float) -> void:
	starts_at = now + 46.0

func request(family, area: String, mode: String, technique: String = "") -> bool:
	if area not in AREAS:
		return false
	if mode == "observe":
		sessions.erase(area)
		if not jobs.get(area, {}).is_empty():
			jobs[area].demo = false
	elif mode == "learn":
		var worker: String = family.instructor(area)
		if worker.is_empty() or not _available_worker(family, worker) or not T.BOOK.has(technique):
			return false
		sessions[area] = {"mode": "waiting", "technique": technique, "teacher": worker}
	elif mode == "help":
		if family.workshop.techniques.rank(technique) < 2:
			return false
		sessions[area] = {"mode": "help", "technique": technique, "teacher": ""}
	else:
		return false
	revision += 1
	return true

func step(family, dt: float) -> void:
	var now: float = family.fire.time
	_advance_helper(family, dt)
	for area: String in AREAS:
		var job: Dictionary = jobs.get(area, {})
		var session: Dictionary = sessions.get(area, {})
		if family.instructor(area).is_empty() and heat_needs.erase(area):
			heat_announced.erase(area)
			revision += 1
		if not job.is_empty():
			if not _available_worker(family, job.worker):
				_cancel(family, area, job)
			else:
				_advance(family, area, job, dt)
		elif (now >= starts_at - (28.0 if area == W.HUNTER else 0.0) or session.get("mode") == "waiting") and int(now / dt) % 4 == 0:
			_choose(family, area)

func _available_worker(family, id: String) -> bool:
	var person: Dictionary = family.people[id]
	return not person.away and person.fatigue < 0.84 and person.injury < 0.55 and family.transfer.get("person", "") != id

func _choose(family, area: String) -> void:
	var worker: String = family.instructor(area)
	if worker.is_empty() or not _available_worker(family, worker) or family.fire.time < rests_until.get(worker, 0.0):
		return
	var model: W = family.workshop
	var session: Dictionary = sessions.get(area, {})
	var demo: bool = session.get("mode") == "waiting" and session.teacher == worker
	var recipe: String = session.technique if demo else ""
	var source: W.Parcel
	var task := ""
	var id := 0
	match area:
		W.HUNTER:
			var carcass := _first(model, "carcass", area)
			var bone := _first(model, "bone", area)
			var hide := _first(model, "hide", area)
			if worker == "mira" and recipe == T.MARROW and bone != null and _tool_id(model, "hammer", area) != 0:
				source = bone
				task = T.MARROW
			elif worker == "mira" and hide != null and _tool_id(model, "scraper", area) != 0:
				source = hide
				task = "hide"
			elif worker == "bera":
				if bone != null and _tool_id(model, "hammer", area) != 0 and (recipe == T.MARROW or carcass == null):
					source = bone
					task = T.MARROW
				elif carcass != null and _tool_id(model, "flake", area) != 0:
					source = carcass
					task = "carve"
				elif hide != null and _tool_id(model, "scraper", area) != 0:
					source = hide
					task = "hide"
		W.COOK:
			source = _first(model, "meat", area)
			if source == null:
				source = _first(model, "marrow", area)
			if source != null and _tool_id(model, "flake", area) != 0 and (demo or model.food_on_shelf() < 1400):
				task = T.ROAST
		W.MAKER:
			var cup := model.parcels[model.kin_cup_id]
			var knot := _first(model, "knot", area)
			var resin := _first(model, "resin", area)
			if (recipe == T.RESIN or model._available("pitch", area) < 10) and cup.rest == area \
					and _tool_id(model, "scraper", area) != 0 and (resin != null or knot != null):
				source = resin if resin != null else knot
				task = T.RESIN
			elif _tool_id(model, "scraper", area) != 0:
				var spare_parts := _first(model, "point", area) != null and _first(model, "shaft", area) != null
				for hunter: String in ["ivo", "kett", "bera"]:
					var broken: bool = model.gear[hunter].condition < 0.20
					if not model.reserved.has(model.gear_id(hunter)) and (not broken or spare_parts) \
							and model.can_haft(hunter, broken, true):
						task = T.HAFT
						id = model.gear_id(hunter)
						break
	if source != null:
		id = source.id
	if task.is_empty() or id == 0:
		heat_needs.erase(area)
		return
	var animated_demo := demo and task == recipe
	if task in [T.ROAST, T.RESIN]:
		var at := _heat_rest(model, task)
		if at == Vector2.INF:
			_need_heat(family, area, worker, task)
			return
	heat_needs.erase(area)
	heat_announced.erase(area)
	var tool := _tool_id(model, _required_tool(area, task), area)
	if tool == 0:
		return
	model.reserved[tool] = worker
	model.reserved[id] = worker
	jobs[area] = {"kind": task, "worker": worker, "id": id, "tool": tool, "phase": "preparing", "demo": animated_demo,
		"progress": 0.0, "began": family.fire.time, "phase_at": family.fire.time, "face_at": 0.0,
		"parts": [], "prepared": false}
	if task == T.HAFT:
		var point := _first(model, "point", area)
		var shaft := _first(model, "shaft", area)
		if point != null and shaft != null:
			jobs[area].parts = [point.id, shaft.id]
			model.reserved[point.id] = worker
			model.reserved[shaft.id] = worker
	if animated_demo:
		session.mode = "demonstrating"
	if id < 0:
		model.gear[model.gear_name(id)].at = W.MAKER
		model.gear[model.gear_name(id)].point = W.MAKER_AT + Vector2(0.06, 0.06)
		model.revision += 1
	family._set_activity(worker, WORDS[task], area)
	revision += 1

func _first(model: W, kind: String, area: String) -> W.Parcel:
	for piece in model.stock(kind, area):
		if piece.freshness > 0.0 and not model.reserved.has(piece.id):
			return piece
	return null

func _heat_rest(model: W, task: String) -> Vector2:
	var band := ROAST_BAND if task == T.ROAST else RESIN_BAND
	var rests := COOK_RESTS if task == T.ROAST else CUP_RESTS
	for at: Vector2 in rests:
		var heat := model.heat_target(at, false)
		if heat >= band.x and heat <= band.y and not model.fire.wood.any(func(piece): return piece.flame > 0.7 and piece.at.distance_to(at) < 0.15):
			return at
	return Vector2.INF

func _need_heat(family, area: String, worker: String, task: String) -> void:
	var words := "The meat needs steady red. Can you give me a place beside the coals?" if task == T.ROAST else \
		"The resin needs indirect warmth. Give my cup enough heat to run without smoking."
	heat_needs[area] = words
	if not heat_announced.has(area):
		heat_announced[area] = true
		family._publish(worker, words, -1.0, area, "heat request", "fire")
		revision += 1

func _advance(family, area: String, job: Dictionary, dt: float) -> void:
	var model: W = family.workshop
	var id: int = job.id
	if id > 0 and not model.parcels.has(id):
		_cancel(family, area, job)
		return
	var kind: String = job.kind
	if id > 0 and model.parcels[id].freshness <= 0.0:
		_cancel(family, area, job)
		return
	if job.phase == "warming":
		_advance_heat(family, area, job, dt)
		return
	var worker: Dictionary = family.people[job.worker]
	var mode: String = sessions.get(area, {}).get("mode", "")
	var attention := 0.28 if mode == "supervised" else (0.55 if job.demo else 1.0)
	var quality: float = model.parcels[id].freshness if id > 0 else 1.0
	job.progress += dt * rate(model.techniques.specialists.get(job.worker, 0), worker.fatigue, worker.injury,
		quality, _edge(model, job.tool, area), attention)
	if kind == T.HAFT and not job.parts.is_empty() and not job.prepared and job.progress >= DIFFICULTY[kind] * 0.49:
		for part: int in job.parts:
			model.parcels[part].prepared = true
		job.prepared = true
		model.revision += 1
	if job.progress < DIFFICULTY[kind]:
		return
	var made := false
	match kind:
		"carve":
			if _edge(model, job.tool, area) > 0.0:
				var new_id := model.next_id
				made = model.butcher(id, false, 540)
				if made:
					family._carry_cut(job.worker, new_id)
		"hide":
			if _edge(model, job.tool, area) > 0.0:
				made = model.clean_hide(id)
				if made and model.parcels.has(id):
					if model._available("binding", W.MAKER) < 24:
						model.cut_binding(id, true, false)
					if model.parcels.has(id):
						model._relocate(model.parcels[id], W.HIDE_RACK)
		T.MARROW:
			if _edge(model, job.tool, area) > 0.0:
				made = model.crack_bone(id, false)
		T.ROAST, T.RESIN:
			var at := _heat_rest(model, kind)
			if at == Vector2.INF:
				_need_heat(family, area, job.worker, kind)
				return
			if _start_heat(model, job, at):
				job.phase = "warming"
				job.phase_at = family.fire.time
				heat_needs.erase(area)
				heat_announced.erase(area)
				revision += 1
				return
		T.HAFT:
			if _edge(model, job.tool, area) > 0.0:
				made = model.haft(model.gear_name(id), not job.parts.is_empty(), false, job.parts)
	_end(family, area, job, made)

func _start_heat(model: W, job: Dictionary, at: Vector2) -> bool:
	var id: int = job.id
	var piece := model.parcels[id]
	if job.kind == T.ROAST:
		if _edge(model, job.tool, W.COOK) <= 0.0:
			return false
		if piece.grams > 180:
			model._take(piece, 180)
			var part := model.add(piece.kind, 180, W.COOK)
			model.inherit_cut(part, piece)
			piece = part
		model._relocate(piece, W.KIN_SPIT, at)
	else:
		if model.parcels[model.kin_cup_id].rest != W.MAKER or _edge(model, job.tool, W.MAKER) <= 0.0:
			return false
		if piece.kind == "knot":
			var new_id := model.next_id
			if not model.scrape_knot(id, false):
				return false
			piece = model.parcels[new_id]
		model._relocate(model.parcels[model.kin_cup_id], W.KIN_CUP, at)
		model._relocate(piece, W.KIN_CUP, at)
		model.reserved[model.kin_cup_id] = job.worker
	model._cool_since_lift(piece)
	model.reserved.erase(id)
	model.reserved[piece.id] = job.worker
	job.id = piece.id
	model.reserved.erase(job.tool)
	job.tool = 0
	return true

func _advance_heat(family, area: String, job: Dictionary, dt: float) -> void:
	var model: W = family.workshop
	var piece := model.parcels[job.id]
	var hot := model.heat_target(piece.at, false)
	var band := ROAST_BAND if job.kind == T.ROAST else RESIN_BAND
	if hot > band.y + 18.0 or (family.fire.time - job.phase_at > 11.0 and hot < band.x - 10.0):
		_need_heat(family, area, job.worker, job.kind)
		_end(family, area, job, false)
		return
	if job.kind == T.ROAST:
		model.cook_at(piece, piece.at, false, dt)
		if piece.dose[piece.face] >= 1.14 and piece.dose[1 - piece.face] < 1.0:
			piece.face = 1 - piece.face
			job.face_at = family.fire.time
			model.revision += 1
		if piece.condition() in ["Roasted", "Overcooked", "Charred"]:
			_end(family, area, job, piece.condition() != "Charred")
	else:
		model.soften_at(piece, piece.at, false, dt)
		if piece.scorched >= 1.0:
			piece.kind = "ruined_pitch"
			_end(family, area, job, false)
		elif piece.cure >= 1.0:
			var loss := piece.grams / 5
			model._take(piece, loss)
			model.evaporated += loss
			piece.kind = "pitch"
			_end(family, area, job, true)

func _cancel(family, area: String, job: Dictionary) -> void:
	_end(family, area, job, false, false)

func _end(family, area: String, job: Dictionary, success: bool, present := true) -> void:
	var model: W = family.workshop
	var id: int = job.id
	var piece: W.Parcel = model.parcels.get(id)
	if id < 0 and model.gear[model.gear_name(id)].at == W.MAKER and present:
		model.gear[model.gear_name(id)].at = W.HUNTER
		model.gear[model.gear_name(id)].point = W.RACK_AT + Vector2((-id - 2) * 0.095, 0)
	if piece != null and piece.rest in [W.KIN_CUP, W.KIN_SPIT]:
		piece.removed_at = family.fire.time
		model._relocate(piece, W.STORE if success and job.kind == T.ROAST else area)
	if job.kind == T.RESIN:
		model.reserved.erase(model.kin_cup_id)
		if model.parcels[model.kin_cup_id].rest == W.KIN_CUP:
			model._relocate(model.parcels[model.kin_cup_id], W.MAKER)
	model.reserved.erase(id)
	model.reserved.erase(job.tool)
	for part: int in job.parts:
		model.reserved.erase(part)
	model.revision += 1
	if success:
		model.techniques.finish_job(job.worker)
		completed[area] = int(completed.get(area, 0)) + 1
		family.people[job.worker].fatigue = minf(1.0, family.people[job.worker].fatigue + 0.018)
		family.remember_workplace(area, family.Roster.person_name(job.worker))
	var session: Dictionary = sessions.get(area, {})
	if job.demo and session.get("mode") == "demonstrating":
		if success:
			model.techniques.teach(job.kind, family.Roster.person_name(job.worker))
			session.mode = "supervised"
		else:
			session.mode = "waiting"
	if present and family.transfer.get("person", "") != job.worker:
		family._set_activity(job.worker, "Taking a short rest at the bench", area)
	rests_until[job.worker] = family.fire.time + (3.0 if success else 6.0)
	jobs.erase(area)
	revision += 1

func _required_tool(area: String, kind: String) -> String:
	return "scraper" if area == W.MAKER or kind == "hide" else ("hammer" if kind == T.MARROW else "flake")

func _tool_id(model: W, kind: String, area: String) -> int:
	var best := 0
	for tool in model.stock(kind, area):
		if not model.reserved.has(tool.id) and (best == 0 or model.parcels[best].edge < tool.edge):
			best = tool.id
	return best

func _edge(model: W, tool: int, area: String) -> float:
	var piece: W.Parcel = model.parcels.get(tool)
	return piece.edge if piece != null and piece.rest in [area, W.HAND] else 0.0

func active_text(area: String) -> String:
	var job: Dictionary = jobs.get(area, {})
	if heat_needs.has(area):
		return heat_needs[area]
	var title := "Between jobs"
	if not job.is_empty():
		title = ("Showing the technique · " if job.demo else "") + WORDS[job.kind]
	if helper.get("area") == area:
		title = "Working on your own" if job.is_empty() else title + " · You are helping"
	return title

func attempt(family, id: int) -> bool:
	var model: W = family.workshop
	if id == 0 or model.reserved.has(id):
		return false
	var area := model.object_rest(id)
	var technique := _player_technique(model, id)
	last_attempt = {"area": area, "technique": technique, "at": family.fire.time}
	if area in [W.SPIT, W.CUP]:
		return model.work(id)
	var session: Dictionary = sessions.get(area, {})
	var mode: String = session.get("mode", "")
	if mode not in ["help", "supervised"] or technique.is_empty():
		return model.work(id)
	if not helper.is_empty():
		model.hand_note = "Finish the work already in your hands."
		return false
	if mode == "supervised" and not _available_worker(family, session.teacher):
		model.hand_note = "Your teacher has stepped away. You can wait or try the work on your own."
		return false
	if mode == "supervised" and technique != session.technique:
		model.hand_note = "Set that aside for now. Use the same material your teacher just worked."
		return false
	if mode == "help" and technique != session.technique:
		return model.work(id)
	if model.held != 0 and not _holds_tool(model, area, technique):
		model.hand_note = "Set down what you’re holding and use the right tool for this piece."
		return false
	model.reserved[id] = "apprentice"
	helper = {"id": id, "area": area, "kind": technique, "progress": 0.0, "tool": model.held, "mode": mode,
		"teacher": session.teacher, "began": family.fire.time}
	model.hand_note = "You start working the piece. Keep it steady and let time pass."
	revision += 1
	return true

func _holds_tool(model: W, area: String, kind: String) -> bool:
	if model.held <= 0:
		return false
	var held: String = model.parcels[model.held].kind
	return held == _required_tool(area, kind) or (kind == T.HAFT and held == "hammer")

func _player_technique(model: W, id: int) -> String:
	if id < 0:
		return T.HAFT
	var piece: W.Parcel = model.parcels.get(id)
	if piece == null:
		return ""
	return {"bone": T.MARROW, "carcass": "carve", "hide": "hide", "knot": T.RESIN, "meat": T.ROAST,
		"point": T.HAFT, "shaft": T.HAFT}.get(piece.kind, "")

func _advance_helper(family, dt: float) -> void:
	if helper.is_empty():
		return
	var model: W = family.workshop
	var id: int = helper.id
	var area: String = helper.area
	var session: Dictionary = sessions.get(area, {})
	var rank := model.techniques.rank(helper.kind)
	if model.object_rest(id) != area or (helper.tool != 0 and model.held != helper.tool) or session.is_empty():
		model.reserved.erase(id)
		helper.clear()
		last_result = "The piece was set aside before the work was finished."
		revision += 1
		return
	if helper.mode == "supervised" and not _available_worker(family, helper.teacher):
		return
	var attention: float = [0.34, 0.48, 0.72, 1.00, 1.24][rank]
	if helper.mode == "supervised":
		attention *= 0.75
	var tool: int = helper.tool if helper.tool != 0 else _tool_id(model, _required_tool(area, helper.kind), area)
	var quality: float = model.parcels[id].freshness if id > 0 else 1.0
	helper.progress += dt * rate(rank * 3, 0.04, 0.0, quality, _edge(model, tool, area), attention)
	if helper.progress >= DIFFICULTY[helper.kind]:
		model.reserved.erase(id)
		model.hand_note = ""
		var done := model.work(id)
		last_result = "Your part is done." if done else model.hand_note
		helper.clear()
		revision += 1

func coaching(family, area: String, target: int, focus: Vector3, wood_tool: bool) -> String:
	var model: W = family.workshop
	var session: Dictionary = sessions.get(area, {})
	if session.get("mode") != "supervised" or family.instructor(area) != session.teacher:
		return ""
	var known: String = session.technique
	var station: Vector2 = W.STATIONS[area]
	if Vector2(focus.x, focus.z).distance_to(station) > (3.5 if area == W.MAKER else 1.65):
		return "Come back to my stone when you’re ready. I need to see where you set your hands."
	if known == T.ROAST and model.roast != null:
		if model.roast.temperature > 168:
			return "Pull it back. You want the heat beside the red. The face in the flame will blacken."
		if model.roast.dose[model.roast.face] > 1.25 and model.roast.dose[1 - model.roast.face] < 0.9:
			return "Look at the lower face. Turn it before it dries through on that side."
		if model.roast.condition() == "Roasted":
			return "Both faces are brown and the middle is warm. Lift it to the covered shelf."
	if known == T.RESIN and model.resin != null:
		if model.resin.temperature > 165.0:
			return "Lift the cup away. That sharp smoke is taking away the resin we need."
		if model.resin.cure >= 1.0:
			return "See how it runs together? Lift the cup while it is still sound."
	if not wood_tool:
		return "Put the hearth tool down for a moment. I need to see your hand on the material."
	if last_attempt.get("area") == area and family.fire.time - last_attempt.get("at", -INF) < 5.0 \
			and last_attempt.get("technique") != known:
		return "Set that piece aside. Start with the same material I used when I showed you."
	if known == T.MARROW and target > 0 and model.parcels.has(target) and model.parcels[target].kind != "bone":
		return "Look for the long marrow bone. Set it steady on the stone beside the hammerstone."
	if known == T.MARROW and model.held > 0 and model.parcels[model.held].kind == "bone":
		return "Set the long bone on the stone so it won’t roll when you strike it."
	if target != 0 and model.held != 0 and _player_technique(model, target) == known and not _holds_tool(model, area, known):
		return "Set that down first. Use the " + W.LABELS[_required_tool(area, known)].to_lower() + " for this piece."
	if not helper.is_empty():
		return "Good. Keep the piece steady. Let the tool do the work."
	return ""

