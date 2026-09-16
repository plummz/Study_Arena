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
var smooth_anchor := Vector3.ZERO
var yaw_speed := 0.0
var pitch_speed := 0.0
var sensitivity := 1.0

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
	if is_instance_valid(target):
		smooth_anchor = target.global_position + Vector3.UP * 1.7

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var horizontal := Input.get_axis("camera_left", "camera_right")
	var vertical := Input.get_axis("camera_up", "camera_down")
	yaw_speed = move_toward(yaw_speed, -horizontal * 2.1 * sensitivity, delta * 8.0)
	pitch_speed = move_toward(pitch_speed, -vertical * 1.45 * sensitivity, delta * 7.0)
	yaw += yaw_speed * delta
	pitch = clampf(pitch + pitch_speed * delta, deg_to_rad(-32.0), deg_to_rad(-4.0))
	var wanted := target.global_position + Vector3.UP * 1.7
	var follow_weight := 1.0 - exp(-delta * 10.5)
	smooth_anchor = smooth_anchor.lerp(wanted, follow_weight)
	global_position = smooth_anchor
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 14.0))
	pitch_root.rotation.x = lerp_angle(pitch_root.rotation.x, pitch, 1.0 - exp(-delta * 12.0))
	target.camera_yaw = yaw
	var planar_speed := Vector2(target.velocity.x, target.velocity.z).length()
	# A continuous response avoids the visible zoom pulse caused by repeatedly
	# crossing the old walk/run threshold.
	var speed_ratio := clampf(planar_speed / PlayerAvatar.RUN_SPEED, 0.0, 1.0)
	var desired_fov := lerpf(67.0, 71.0, smoothstep(0.15, 1.0, speed_ratio))
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-delta * 4.0))
	if shake_left > 0.0:
		shake_left -= delta
		camera.position = Vector3(randf_range(-shake_strength, shake_strength), 0.22 + randf_range(-shake_strength, shake_strength), 0)
	else:
		camera.position = camera.position.lerp(Vector3(0, 0.22, 0), delta * 12.0)

func shake(strength := 0.16, duration := 0.28) -> void:
	shake_strength = strength
	shake_left = duration
