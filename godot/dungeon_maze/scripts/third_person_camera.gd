class_name ThirdPersonCamera
extends Node3D

var target: PlayerAvatar
var yaw := 0.0
var pitch := deg_to_rad(-9.0)
var pitch_root: Node3D
var camera: Camera3D
var spring: SpringArm3D
var shake_strength := 0.0
var shake_left := 0.0

func _ready() -> void:
	pitch_root = Node3D.new()
	add_child(pitch_root)
	spring = SpringArm3D.new()
	spring.spring_length = 5.8
	spring.margin = 0.28
	spring.collision_mask = 1
	pitch_root.add_child(spring)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.22, 0)
	camera.fov = 67.0
	camera.current = true
	spring.add_child(camera)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var horizontal := Input.get_axis("camera_left", "camera_right")
	var vertical := Input.get_axis("camera_up", "camera_down")
	yaw -= horizontal * delta * 1.75
	pitch = clampf(pitch - vertical * delta * 1.2, deg_to_rad(-30.0), deg_to_rad(-3.0))
	global_position = target.global_position + Vector3.UP * 1.55
	rotation.y = yaw
	pitch_root.rotation.x = pitch
	target.camera_yaw = yaw
	if shake_left > 0.0:
		shake_left -= delta
		camera.position = Vector3(randf_range(-shake_strength, shake_strength), 0.22 + randf_range(-shake_strength, shake_strength), 0)
	else:
		camera.position = camera.position.lerp(Vector3(0, 0.22, 0), delta * 12.0)

func shake(strength := 0.16, duration := 0.28) -> void:
	shake_strength = strength
	shake_left = duration
