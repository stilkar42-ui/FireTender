extends Node3D
## Two aligned painted layers share the same pose atlas. The ground anchor
## and depth test remain in the 3D scene while the poses follow the job.

const TILE := 384
const HIP := 242
const PIXEL := 0.0020
const CONTACT_SHADOW := preload("res://hearth/painted_contact.gdshader")
var upper: Sprite3D
var lower: Sprite3D
var travel: Sprite3D
var heading := Vector2(0, -1)
var rear := false
var pose := -1
var walking := false

func build(id: String) -> void:
	var foot := MeshInstance3D.new()
	var patch := QuadMesh.new()
	patch.orientation = PlaneMesh.FACE_Y
	patch.size = Vector2(0.74, 0.49)
	var shadow := ShaderMaterial.new()
	shadow.shader = CONTACT_SHADOW
	foot.mesh = patch
	foot.position.y = 0.006
	foot.material_override = shadow
	foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foot)
	var art := load("res://hearth/art/workers/%s.webp" % id) as Texture2D
	upper = _painted_layer(art, 0.0)
	lower = _painted_layer(art, 0.0)
	if id == "bera" and ResourceLoader.exists("res://hearth/art/workers/bera-carry.webp"):
		travel = _painted_layer(load("res://hearth/art/workers/bera-carry.webp") as Texture2D, 0.003)
		travel.hide()
		travel.pixel_size = 0.00325
	_set_pose(0)

func _painted_layer(art: Texture2D, depth: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = art
	sprite.region_enabled = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.30
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = PIXEL
	sprite.position.z = depth
	add_child(sprite)
	return sprite

func pose_at(camera: Camera3D, job: Dictionary, now: float, light: Color, teaching := false) -> void:
	if upper == null or not visible:
		return
	walking = false
	if travel != null:
		travel.hide()
	upper.show()
	lower.show()
	var view := Vector2(camera.position.x - position.x, camera.position.z - position.z).normalized()
	var angle := view.dot(heading)
	if angle > 0.15:
		rear = false
	elif angle < -0.15:
		rear = true
	var mirror := view.cross(heading) < 0.0
	var frame := 0
	if not job.is_empty() and not teaching:
		if job.phase == "preparing":
			var beat := fposmod(float(job.progress) * 0.82, 1.0)
			frame = 1 if beat < 0.45 else 2
		elif now - maxf(job.phase_at, job.face_at) < 1.4:
			frame = 2 if fposmod(now - job.phase_at, 0.7) < 0.45 else 1
		else:
			frame = 1
	_set_pose(frame + (3 if rear else 0))
	upper.flip_h = mirror
	lower.flip_h = mirror
	_tint(light)

func carry_at(now: float, light: Color, direction: Vector2, camera: Camera3D) -> void:
	if travel == null:
		pose_at(camera, {}, now, light)
		return
	walking = true
	upper.hide()
	lower.hide()
	travel.show()
	var frame := floori(now * 4.7) % 3
	travel.region_rect = Rect2(frame * TILE, 0, TILE, TILE)
	travel.position.y = TILE * travel.pixel_size * 0.5 + 0.011 * sin(now * 13.0)
	travel.flip_h = camera.global_basis.x.dot(Vector3(direction.x, 0, direction.y)) < 0.0
	_tint(light)

func _set_pose(index: int) -> void:
	if pose == index:
		return
	pose = index
	var column := index % 3
	var row := index / 3
	upper.region_rect = Rect2(column * TILE, row * TILE, TILE, HIP)
	lower.region_rect = Rect2(column * TILE, row * TILE + HIP, TILE, TILE - HIP)
	upper.position.y = (TILE - HIP * 0.5) * PIXEL
	lower.position.y = (TILE - HIP) * PIXEL * 0.5

func _tint(ink: Color) -> void:
	upper.modulate = ink
	lower.modulate = ink
	if travel != null:
		travel.modulate = ink
