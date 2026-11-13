extends Resource
## Presentation assets for a location. Fire and shelter exposure live in the model.

@export var set_scene: PackedScene
@export var ground_scene: PackedScene
@export var panorama: Texture2D
@export var foreground: Texture2D
@export var ground: Material
@export_range(90.0, 360.0) var panorama_span := 270.0
@export_range(1.0, 2.5) var exterior_scale := 1.0
@export var home_eye := Vector3(-0.48, 1.42, -2.10)
@export var home_target := Vector3(-0.37, 0.10, 0.10)
@export var field_of_view := 68.0
@export var eye_bounds := AABB(Vector3(-2.42, 0.39, -2.45), Vector3(4.12, 1.40, 3.67))
@export var focus_bounds := AABB(Vector3(-2.32, 0.03, -1.42), Vector3(3.98, 1.12, 2.65))
@export var camera_obstacles: Array[AABB] = []
