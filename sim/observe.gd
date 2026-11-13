extends RefCounted
## A read-only interpretation. A future remembered impression can keep
## the returned string and the inspection time without retaining live pieces.

static func read(fire, point := Vector2.INF, viewpoint := 0.0, felt := "") -> String:
	var flame: float = fire.total_flame()
	var visible_glow := 0.0
	var covered_warmth := 0.0
	var coal_warmth := 0.0
	var hot_wood := false
	var damp := false
	var steam := 0.0
	var smoke := 0.0
	var buried := 0
	var crowded := false
	var brightest = null
	var wet_spot = null
	var warmest_flame = null
	var strongest_glow := 0.0
	for coal in fire.coals:
		var glow: float = coal.glow() * exp(-3.8 * coal.depth())
		visible_glow += glow
		if glow > strongest_glow:
			strongest_glow = glow
			brightest = coal
		coal_warmth = maxf(coal_warmth, coal.temperature)
		if coal.cover > 0.004:
			buried += 1
			covered_warmth = maxf(covered_warmth, coal.temperature)
		steam += coal.vapor
	for piece in fire.wood:
		hot_wood = hot_wood or piece.temperature > 125.0
		damp = damp or piece.water / piece.original > 0.24
		steam += piece.vapor
		smoke += piece.smoke
		crowded = crowded or (piece.oxygen < 0.34 and piece.smoke > 0.00015)
		if piece.vapor > 0.0002 and (wet_spot == null or piece.vapor > wet_spot.vapor):
			wet_spot = piece
		if warmest_flame == null or piece.flame > warmest_flame.flame:
			warmest_flame = piece
	var lines := PackedStringArray()
	if flame > 28.0:
		lines.append("Flames curl high around the wood%s." % _where(warmest_flame.at.rotated(viewpoint)))
	elif flame > 2.0:
		lines.append("Small tongues of flame cling to the wood.")
	else:
		lines.append("There is no standing flame.")
	if buried > 0 and covered_warmth > 275.0:
		if not point.is_finite() or (fire.heat_at(point) > 0.07 if felt.is_empty() else felt != "No warmth"):
			lines.append("Heat reaches your hand through the ash.")
		else:
			lines.append("Ash blankets the bed.")
	elif visible_glow > 1.1:
		lines.append("The coal bed glows deep red%s." % _where(brightest.at.rotated(viewpoint)))
	elif visible_glow > 0.045:
		var place := _where(brightest.at.rotated(viewpoint))
		lines.append(("A single coal glows%s." if fire.coals.size() == 1 else "A few points of red linger%s.") % place)
	elif coal_warmth > 95.0 or hot_wood:
		lines.append("The bed still holds heat, with little red showing.")
	else:
		lines.append("The bed is dark and gives off no appreciable heat.")
	if damp and steam > 0.0005:
		lines.append("The damp wood%s hisses as pale vapor rises." %
			(_where(wet_spot.at.rotated(viewpoint)) if wet_spot != null else ""))
	elif crowded:
		lines.append("Smoke threads between tightly packed pieces.")
	elif smoke > 0.0015:
		lines.append("Thick smoke trails from the charring wood.")
	elif damp:
		lines.append("The wet wood feels heavy and slick.")
	elif fire.WEATHER[fire.weather].rain > 0.0:
		lines.append("Rain spatters on the hearth.")
	elif fire.airflow() > 0.85 and flame > 2.0:
		lines.append("The draft pushes the flame sideways.")
	if point.is_finite():
		var local := warmth(fire, point) if felt.is_empty() else felt
		if local not in ["No warmth here", "No warmth"]:
			local = local.replace("\n", " ")
			lines.append(local if local.ends_with(".") else local + ".")
		if not felt.is_empty():
			var draft := _draft_note(fire, point)
			if not draft.is_empty():
				lines.append(draft + ".")
	return " ".join(lines)

static func warmth(fire, point: Vector2) -> String:
	var draft := _draft_note(fire, point)
	if not draft.is_empty():
		return draft
	var heat: float = fire.heat_at(point)
	if heat > 1.25:
		return "Strong radiant heat here"
	if heat > 0.40:
		return "Steady warmth here"
	if heat > 0.07:
		return "Faint warmth here"
	return "No warmth here"

static func _draft_note(fire, point: Vector2) -> String:
	var nearest = null
	var distance := 0.27
	for coal in fire.coals:
		var gap: float = coal.at.distance_to(point)
		if gap < distance:
			distance = gap
			nearest = coal
	if nearest != null and nearest.pulse > 0.18:
		if nearest.breath_balance > 0.12 and nearest.char_heat > 0.25:
			return "The draft brightens these coals"
		if nearest.breath_balance < -0.14 and nearest.trend < -3.0 and nearest.temperature > 90.0:
			return "The draft draws heat away"
	return ""

static func _where(at: Vector2) -> String:
	if at.x < -0.22:
		return " on the left"
	if at.x > 0.22:
		return " on the right"
	if at.y < -0.23:
		return " at the back"
	return ""
