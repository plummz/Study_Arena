class_name FirstPersonController
extends CharacterBody3D
## First-person explorer for the Dungeon of Knowledge.
## Mouse / arrow keys / touch-drag look, WASD movement, run, jump, head bob,
## a warm hand-lantern and a spell staff view model.

signal footstep(running: bool)

const WALK_SPEED := 3.6
const RUN_SPEED := 6.2
const ACCELERATION := 22.0
const DECELERATION := 26.0
const JUMP_VELOCITY := 6.2
const GRAVITY := 19.0
const EYE_HEIGHT := 1.62
const STAFF_PATH := "res://assets/models/weapons/staff.gltf"

var controls_enabled := true
var mouse_sensitivity := 0.0022
var key_look_speed := 2.2
var invert_y := false
var reduced_motion := false
var base_fov := 74.0
var yaw := 0.0
var pitch := 0.0
var head: Node3D
var camera: Camera3D
var lantern: OmniLight3D
var view_model: Node3D
var staff_gem: MeshInstance3D
var bob_phase := 0.0
var step_distance := 0.0
var shake_strength := 0.0
var shake_left := 0.0
var kick := 0.0
var touch_look := Vector2.ZERO
var action_locked := false
var dead := false
var speed_multiplier := 1.0
var jump_multiplier := 1.0
var lantern_boost := 1.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.72
	collider.shape = capsule
	collider.position.y = 0.86
	add_child(collider)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = base_fov
	camera.near = 0.05
	camera.far = 90.0
	camera.current = true
	head.add_child(camera)
	lantern = OmniLight3D.new()
	lantern.name = "HandLantern"
	lantern.light_color = Color("ffc98a")
	lantern.light_energy = 1.25
	lantern.omni_range = 8.5
	lantern.omni_attenuation = 1.4
	lantern.position = Vector3(0.28, -0.18, -0.35)
	camera.add_child(lantern)
	_build_view_model()

func _build_view_model() -> void:
	view_model = Node3D.new()
	view_model.name = "StaffViewModel"
	view_model.position = Vector3(0.3, -0.34, -0.55)
	view_model.rotation_degrees = Vector3(12, -8, -18)
	camera.add_child(view_model)
	if ResourceLoader.exists(STAFF_PATH):
		var staff: Node3D = load(STAFF_PATH).instantiate()
		staff.name = "Staff"
		staff.scale = Vector3.ONE * 0.2
		view_model.add_child(staff)
		for mesh: MeshInstance3D in staff.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.layers = 1
	staff_gem = MeshInstance3D.new()
	staff_gem.name = "StaffGem"
	var gem := SphereMesh.new()
	gem.radius = 0.03
	gem.height = 0.06
	gem.radial_segments = 8
	gem.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8fe9ff")
	material.emission_enabled = true
	material.emission = Color("59d8ff")
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gem.material = material
	staff_gem.mesh = gem
	staff_gem.position = Vector3(0.02, 0.2, 0.0)
	view_model.add_child(staff_gem)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func add_touch_look(delta_pixels: Vector2) -> void:
	if controls_enabled:
		_apply_look(delta_pixels * mouse_sensitivity * 1.6)

func _apply_look(amount: Vector2) -> void:
	yaw -= amount.x
	pitch -= amount.y * (-1.0 if invert_y else 1.0)
	pitch = clampf(pitch, deg_to_rad(-78.0), deg_to_rad(76.0))

func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)
		if not is_on_floor(): velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var look_keys := Vector2(Input.get_axis("camera_left", "camera_right"), Input.get_axis("camera_up", "camera_down"))
	if controls_enabled and look_keys.length_squared() > 0.0:
		_apply_look(look_keys * key_look_speed * delta)
	rotation.y = yaw
	head.rotation.x = pitch
	var input := Vector2.ZERO
	var wants_run := false
	if controls_enabled and not action_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wants_run = Input.is_action_pressed("run")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y))
	direction.y = 0.0
	direction = direction.normalized() * minf(1.0, input.length())
	var speed := (RUN_SPEED if wants_run else WALK_SPEED) * speed_multiplier
	var change := ACCELERATION if direction.length_squared() > 0.0 else DECELERATION
	velocity.x = move_toward(velocity.x, direction.x * speed, change * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, change * delta)
	if is_on_floor():
		if controls_enabled and not action_locked and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY * jump_multiplier
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_feel(delta, wants_run)

func _update_feel(delta: float, running: bool) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	var moving := planar > 0.4 and is_on_floor()
	if moving:
		step_distance += planar * delta
		var stride := 2.3 if running else 1.7
		if step_distance >= stride:
			step_distance = 0.0
			footstep.emit(running)
	var bob_amount := 0.0 if reduced_motion else (0.055 if running else 0.035)
	if moving:
		bob_phase += delta * planar * 2.05
	var bob := Vector3(cos(bob_phase * 0.5) * bob_amount * 0.6, absf(sin(bob_phase * 0.5)) * bob_amount, 0.0) if moving else Vector3.ZERO
	var camera_target := bob
	if shake_left > 0.0 and not reduced_motion:
		shake_left -= delta
		camera_target += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_strength
	camera.position = camera.position.lerp(camera_target, 1.0 - exp(-delta * 14.0))
	kick = move_toward(kick, 0.0, delta * 2.6)
	camera.rotation.x = kick * (0.0 if reduced_motion else 0.12)
	var wanted_fov := base_fov + (4.0 if running and moving and not reduced_motion else 0.0) + (5.0 if speed_multiplier > 1.0 and moving and not reduced_motion else 0.0)
	camera.fov = lerpf(camera.fov, wanted_fov, 1.0 - exp(-delta * 5.0))
	if not action_locked:
		var sway := Vector3(bob.x * 0.9, -bob.y * 0.7, 0.0)
		view_model.position = view_model.position.lerp(Vector3(0.3, -0.34, -0.55) + sway, 1.0 - exp(-delta * 10.0))
	var t := Time.get_ticks_msec() * 0.001
	lantern.light_energy = 1.25 * (1.0 + (lantern_boost - 1.0) * 0.6) + (0.0 if reduced_motion else sin(t * 7.3) * 0.05 + sin(t * 13.1) * 0.035)
	lantern.omni_range = lerpf(lantern.omni_range, 8.5 * lantern_boost, 1.0 - exp(-delta * 3.0))
	staff_gem.scale = Vector3.ONE * (1.0 + sin(t * 3.0) * 0.08)

func shake(strength := 0.06, duration := 0.25) -> void:
	shake_strength = strength
	shake_left = duration

func take_hit() -> void:
	kick = 1.0
	shake(0.07, 0.3)

func celebrate() -> void:
	var tween := create_tween()
	tween.tween_property(view_model, "rotation_degrees:z", 8.0, 0.14).set_trans(Tween.TRANS_BACK)
	tween.tween_property(view_model, "position:y", -0.22, 0.14)
	tween.tween_property(view_model, "rotation_degrees:z", -18.0, 0.22)
	tween.parallel().tween_property(view_model, "position:y", -0.34, 0.22)

## Thrusts the staff toward the target and returns the gem position for the spell beam.
func cast_skill(_target_position: Vector3) -> Vector3:
	action_locked = true
	var tween := create_tween()
	tween.tween_property(view_model, "position", Vector3(0.18, -0.2, -0.72), 0.1).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(view_model, "rotation_degrees:x", -8.0, 0.1)
	tween.tween_interval(0.12)
	tween.tween_property(view_model, "position", Vector3(0.3, -0.34, -0.55), 0.22)
	tween.parallel().tween_property(view_model, "rotation_degrees:x", 12.0, 0.22)
	tween.tween_callback(func(): action_locked = false)
	return staff_gem.global_position

func look_toward(target: Vector3) -> void:
	var flat := target - global_position
	yaw = atan2(-flat.x, -flat.z)

## Recolours the staff gem (used to show the most recent buff).
func set_gem_color(color: Color) -> void:
	var material := (staff_gem.mesh as SphereMesh).material as StandardMaterial3D
	material.albedo_color = color.lightened(0.3)
	material.emission = color

## Knocked down: the staff falls away, the view drops and rolls onto the floor.
func die(gentle := false) -> void:
	dead = true
	controls_enabled = false
	action_locked = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(view_model, "position", Vector3(0.5, -1.2, -0.3), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(view_model, "rotation_degrees", Vector3(75, -35, -85), 0.55)
	tween.tween_property(lantern, "light_energy", 0.3, 1.6)
	tween.tween_property(camera, "position", Vector3.ZERO, 0.2)
	if gentle:
		tween.tween_property(head, "position:y", 0.7, 1.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(head, "rotation:x", 0.0, 1.2)
	else:
		tween.tween_property(head, "rotation:x", -0.35, 0.25)
		tween.tween_property(head, "position:y", 0.3, 0.85).set_delay(0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(head, "rotation:z", 1.3, 0.8).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(head, "rotation:x", 0.12, 0.8).set_delay(0.35)
		tween.tween_property(camera, "fov", base_fov + 12.0, 1.6).set_delay(0.3)
