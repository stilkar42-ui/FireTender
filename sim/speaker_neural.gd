extends RefCounted
## 24 learned hidden units over word/bigram/subword features, then softmax.
## No network, Python, GPU, process, RNG, or simulation mutation at inference.

static var model: Dictionary = {}
static var weights := PackedFloat32Array()
static var attempted := false
static var ready := false
static var separator := RegEx.create_from_string("[^a-z0-9]+")

static func _load_model() -> void:
	if attempted:
		return
	attempted = true
	var metadata := "res://sim/speaker_model/model.json"
	var binary := "res://sim/speaker_model/weights.bin"
	if not FileAccess.file_exists(metadata) or not FileAccess.file_exists(binary):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata))
	if not parsed is Dictionary or parsed.get("version", 0) != 1 or parsed.get("dim", 0) != 24:
		return
	model = parsed
	var bytes := FileAccess.get_file_as_bytes(binary)
	var checksum := HashingContext.new()
	checksum.start(HashingContext.HASH_SHA256)
	checksum.update(bytes)
	if checksum.finish().hex_encode() != model.get("weights_sha256", ""):
		return
	weights = bytes.to_float32_array()
	ready = weights.size() == (model.vocab.size() + model.labels.size()) * 24 + model.labels.size()

static func features(question: String) -> Array[String]:
	var words := separator.sub(question.left(120).to_lower(), " ", true).split(" ", false)
	var result: Array[String] = []
	for word in words:
		for repeat in range(3):
			result.append("w:" + word)
		var padded := "<" + word + ">"
		for length in [3, 4, 5]:
			for i in range(maxi(0, padded.length() - length + 1)):
				result.append("c:" + padded.substr(i, length))
	for i in range(words.size() - 1):
		result.append("b:" + words[i] + "_" + words[i + 1])
	return result

static func infer(question: String) -> Dictionary:
	_load_model()
	var result := {"intent": "", "raw": "", "secondary": "", "confidence": 0.0,
		"margin": 0.0, "coverage": 0.0, "reason": "model_unavailable"}
	if not ready:
		return result
	var raw := features(question)
	var ids := PackedInt32Array()
	for feature in raw:
		if model.vocab.has(feature):
			ids.append(int(model.vocab[feature]))
	result.coverage = float(ids.size()) / maxf(1.0, raw.size())
	if ids.is_empty():
		result.reason = "unfamiliar"
		return result
	var hidden := PackedFloat32Array()
	hidden.resize(24)
	var scale := 1.0 / sqrt(float(ids.size()))
	for id in ids:
		for j in range(24):
			hidden[j] += weights[id * 24 + j] * scale
	for j in range(24):
		hidden[j] = tanh(hidden[j])
	var scores: Array[float] = []
	var start: int = model.vocab.size() * 24
	var bias: int = start + model.labels.size() * 24
	for k in range(model.labels.size()):
		var score: float = weights[bias + k]
		for j in range(24):
			score += weights[start + k * 24 + j] * hidden[j]
		scores.append(score)
	var peak: float = scores.max()
	var total := 0.0
	for k in range(scores.size()):
		scores[k] = exp(scores[k] - peak)
		total += scores[k]
	var order := range(scores.size())
	order.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	result.raw = model.labels[order[0]]
	result.secondary = model.labels[order[1]]
	result.confidence = scores[order[0]] / total
	result.margin = (scores[order[0]] - scores[order[1]]) / total
	result.reason = "accepted"
	if result.coverage < model.coverage:
		result.reason = "unfamiliar"
	elif result.confidence < model.confidence or result.margin < model.margin:
		result.reason = "uncertain"
	elif result.raw == "unknown":
		result.reason = "unsupported"
	else:
		result.intent = result.raw
	return result
