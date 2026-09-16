class_name PlayerAvatar
extends CharacterBody3D

signal reached_encounter(encounter_id: int)

const WALK_SPEED := 4.0
const RUN_SPEED := 7.2
const ACCELERATION := 18.0
const DECELERATION := 24.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 19.0
var controls_enabled := true
var move_phase := 0.0
var camera_yaw := 0.0
var companion_id := "moss"
var body_root: Node3D
var head: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var action_locked := false
var accessory: Node3D
var left_hand: MeshInstance3D
var right_hand: MeshInstance3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	_build_body()

func _physics_process(delta: float) -> void:
	if not controls_enabled or action_locked:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)
		if not is_on_floor(): velocity.y -= GRAVITY * delta
		_animate_body(delta, 0.0, false)
		move_and_slide()
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw).normalized()
	var running := Input.is_action_pressed("run") and direction.length_squared() > 0.0
	var speed := RUN_SPEED if running else WALK_SPEED
	var change := ACCELERATION if direction.length_squared() > 0.0 else DECELERATION
	velocity.x = move_toward(velocity.x, direction.x * speed, change * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, change * delta)
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	if direction.length_squared() > 0.0:
		# Character art faces local -Z; this keeps the face toward travel instead of backward.
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 12.0)
	move_and_slide()
	_animate_body(delta, Vector2(velocity.x, velocity.z).length() / RUN_SPEED, running)

func _build_body() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	body_root = Node3D.new()
	body_root.name = "AnimatedBody"
	add_child(body_root)
	var palettes := {
		"moss": [Color("788a3b"), Color("f1dd9a")], "lumi": [Color("e4a93a"), Color("ffe7aa")],
		"coral": [Color("ee6455"), Color("fff0dc")], "sky": [Color("4b91df"), Color("d9efff")],
		"plum": [Color("7c4ea3"), Color("f8dccb")], "sunny": [Color("f5a42f"), Color("ffc34e")],
		"mint": [Color("58b993"), Color("f7dfc8")], "nova": [Color("263b83"), Color("f8ddc7")],
		"ember": [Color("e95b35"), Color("ffd0a1")], "bubbles": [Color("ee86a7"), Color("ffd2dc")],
		"byte": [Color("26999b"), Color("d8ffff")], "clover": [Color("65a84c"), Color("fff0d6")],
		"mochi": [Color("d7a86e"), Color("fff0cf")], "comet": [Color("6b8bc7"), Color("e9f4ff")],
		"pebble": [Color("6f7680"), Color("a9adb0")], "melody": [Color("e96f9d"), Color("ffd9e8")],
		"taro": [Color("7650a6"), Color("e9d7c3")], "sol": [Color("e9a52c"), Color("ffd47b")],
	}
	var palette: Array = palettes.get(companion_id, palettes.moss)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = palette[0]
	cloth.roughness = 0.72
	var skin := StandardMaterial3D.new()
	skin.albedo_color = palette[1]
	skin.roughness = 0.78
	var boot := StandardMaterial3D.new()
	boot.albedo_color = Color("342336")
	head = _sphere_part("Head", Vector3(0.7, 0.66, 0.63), Vector3(0, 1.78, 0), skin)
	var round_body := companion_id in ["moss", "sky", "sunny", "bubbles", "mochi", "pebble", "melody", "sol"]
	if round_body:
		_sphere_part("Body", Vector3(0.82, 0.86, 0.62), Vector3(0, 1.04, 0.08), cloth)
	else:
		_capsule_part("Body", 0.38, 0.9, Vector3(0, 1.06, 0), cloth)
	left_arm = _capsule_part("LeftArm", 0.115, 0.7, Vector3(-0.48, 1.18, 0), skin)
	right_arm = _capsule_part("RightArm", 0.115, 0.7, Vector3(0.48, 1.18, 0), skin)
	left_leg = _capsule_part("LeftLeg", 0.145, 0.74, Vector3(-0.2, 0.42, 0), boot)
	right_leg = _capsule_part("RightLeg", 0.145, 0.74, Vector3(0.2, 0.42, 0), boot)
	left_hand = _sphere_part("LeftHand", Vector3(0.14, 0.14, 0.13), Vector3(-0.48, 0.81, -0.01), skin)
	right_hand = _sphere_part("RightHand", Vector3(0.14, 0.14, 0.13), Vector3(0.48, 0.81, -0.01), skin)
	_attach_part(left_hand, left_arm, Vector3(0, -0.39, 0))
	_attach_part(right_hand, right_arm, Vector3(0, -0.39, 0))
	var left_foot := _sphere_part("LeftFoot", Vector3(0.18, 0.12, 0.25), Vector3(-0.2, 0.1, -0.08), boot)
	var right_foot := _sphere_part("RightFoot", Vector3(0.18, 0.12, 0.25), Vector3(0.2, 0.1, -0.08), boot)
	_attach_part(left_foot, left_leg, Vector3(0, -0.37, -0.08))
	_attach_part(right_foot, right_leg, Vector3(0, -0.37, -0.08))
	_build_face(skin, cloth, boot)
	_add_companion_identity(cloth, skin)

func _add_companion_identity(primary: Material, accent: Material) -> void:
	if companion_id in ["coral", "plum"]:
		var left_ear := _part("LeftEar", Vector3(0.22, 0.42, 0.18), Vector3(-0.22, 2.24, 0), primary)
		var right_ear := _part("RightEar", Vector3(0.22, 0.42, 0.18), Vector3(0.22, 2.24, 0), primary)
		left_ear.rotation.z = -0.25
		right_ear.rotation.z = 0.25
		_part("HairTop", Vector3(0.72, 0.28, 0.64), Vector3(0, 2.03, 0), primary)
		_part("HairLeft", Vector3(0.28, 0.7, 0.3), Vector3(-0.38, 1.72, 0.04), primary)
		_part("HairRight", Vector3(0.28, 0.7, 0.3), Vector3(0.38, 1.72, 0.04), primary)
		if companion_id == "coral":
			var flower := _sphere_part("Flower", Vector3(0.18, 0.18, 0.08), Vector3(0.42, 2.03, -0.33), _plain_material(Color("fff8e8")))
			flower.rotation.z = 0.3
		accessory = Node3D.new()
		accessory.name = "Tail"
		body_root.add_child(accessory)
		for i in 3:
			var tail_piece := _part("TailPiece%d" % i, Vector3(0.22, 0.58, 0.22), Vector3(0.58 + i * 0.18, 0.72 + i * 0.22, 0.25), primary)
			body_root.remove_child(tail_piece)
			accessory.add_child(tail_piece)
			tail_piece.position -= accessory.position
			tail_piece.rotation.z = -0.45 - i * 0.18
		if companion_id == "plum": _add_glasses()
	elif companion_id in ["moss", "sky"]:
		_part("LeftWing", Vector3(0.52, 0.52, 0.16), Vector3(-0.53, 1.1, 0.08), primary).rotation.z = -0.42
		_part("RightWing", Vector3(0.52, 0.52, 0.16), Vector3(0.53, 1.1, 0.08), primary).rotation.z = 0.42
		_add_graduation_cap(primary)
		_add_book(primary)
	elif companion_id == "mint":
		_part("Leaf", Vector3(0.18, 0.42, 0.12), Vector3(0.12, 2.27, 0), primary).rotation.z = 0.62
		_part("HairLeft", Vector3(0.24, 0.8, 0.28), Vector3(-0.38, 1.7, 0.08), primary)
		_part("HairRight", Vector3(0.24, 0.8, 0.28), Vector3(0.38, 1.7, 0.08), primary)
		_add_book(primary)
	elif companion_id == "nova":
		var star := _part("Star", Vector3(0.28, 0.28, 0.12), Vector3(0.34, 2.08, -0.2), accent)
		star.rotation.z = 0.7
		_add_wizard_hat(primary, accent)
		_part("Cape", Vector3(1.05, 1.05, 0.16), Vector3(0, 1.08, 0.3), primary)
	elif companion_id == "sunny":
		var shell := _sphere_part("Shell", Vector3(0.72, 0.76, 0.28), Vector3(0, 1.04, 0.48), primary)
		shell.rotation.x = 0.08
		_part("Neckerchief", Vector3(0.65, 0.14, 0.52), Vector3(0, 1.38, -0.15), accent).rotation.z = 0.12
	elif companion_id == "ember":
		_add_pointed_ears(primary)
		_add_horns(_plain_material(Color("fff0bf")))
		_add_wings(primary)
		_add_tail(primary)
		_part("ScholarScarf", Vector3(0.72, 0.15, 0.52), Vector3(0, 1.42, -0.16), _plain_material(Color("f6b83f")))
	elif companion_id == "bubbles":
		for side in [-1.0, 1.0]:
			for y in [1.68, 1.86, 2.04]:
				var gill := _part("Gill", Vector3(0.34, 0.1, 0.1), Vector3(side * 0.47, y, 0), _plain_material(Color("ff5f9d")))
				gill.rotation.z = side * (y - 1.86) * 1.2
		_add_tail(_plain_material(Color("e97ba6")))
		_add_glasses()
	elif companion_id == "byte":
		_part("ScreenFace", Vector3(0.72, 0.46, 0.08), Vector3(0, 1.82, -0.57), _plain_material(Color("153243")))
		_part("Antenna", Vector3(0.07, 0.42, 0.07), Vector3(0.18, 2.28, 0), primary).rotation.z = -0.18
		_sphere_part("AntennaLight", Vector3(0.12, 0.12, 0.12), Vector3(0.22, 2.49, 0), _plain_material(Color("63f4e6")))
		for side in [-1.0, 1.0]: _sphere_part("EarPod", Vector3(0.14, 0.24, 0.2), Vector3(side * 0.48, 1.84, 0), primary)
	elif companion_id == "clover":
		_add_long_ears(primary)
		_part("Satchel", Vector3(0.5, 0.55, 0.18), Vector3(0.35, 0.95, -0.36), _plain_material(Color("9a6236")))
		_add_book(_plain_material(Color("d9a537")))
	elif companion_id == "mochi":
		_add_round_ears(primary)
		_part("Neckerchief", Vector3(0.7, 0.15, 0.52), Vector3(0, 1.4, -0.15), _plain_material(Color("e46d4f")))
		_part("Backpack", Vector3(0.72, 0.7, 0.28), Vector3(0, 1.05, 0.4), _plain_material(Color("4e91a7")))
	elif companion_id == "comet":
		_add_pointed_ears(primary)
		_add_tail(_plain_material(Color("c7d6ef")))
		_part("SpacePack", Vector3(0.72, 0.72, 0.28), Vector3(0, 1.08, 0.4), _plain_material(Color("dce8f6")))
		_sphere_part("ChestStar", Vector3(0.13, 0.13, 0.05), Vector3(0, 1.18, -0.49), _plain_material(Color("ffd552")))
	elif companion_id == "pebble":
		for side in [-1.0, 1.0]: _sphere_part("RockShoulder", Vector3(0.28, 0.28, 0.25), Vector3(side * 0.5, 1.34, 0), primary)
		_sphere_part("AmberCore", Vector3(0.18, 0.18, 0.07), Vector3(0, 1.13, -0.48), _plain_material(Color("ffbd3e")))
	elif companion_id == "melody":
		_add_wings(primary)
		_add_round_ears(_plain_material(Color("784563")))
		for side in [-1.0, 1.0]: _sphere_part("Headphone", Vector3(0.15, 0.28, 0.2), Vector3(side * 0.48, 1.86, 0), _plain_material(Color("714e9b")))
		_part("Headband", Vector3(0.72, 0.1, 0.58), Vector3(0, 2.12, 0), _plain_material(Color("714e9b")))
	elif companion_id == "taro":
		_add_pointed_ears(primary)
		_add_tail(primary)
		_add_glasses()
		_part("ToolBelt", Vector3(0.86, 0.16, 0.5), Vector3(0, 0.9, 0), _plain_material(Color("9b6a38")))
	elif companion_id == "sol":
		_add_round_ears(primary)
		_sphere_part("Mane", Vector3(0.82, 0.78, 0.5), Vector3(0, 1.83, 0.08), _plain_material(Color("be6728")))
		head.position.z = -0.15
		_part("HeroCape", Vector3(1.0, 1.12, 0.16), Vector3(0, 1.06, 0.35), _plain_material(Color("d84a42")))
	else:
		_part("HairLeft", Vector3(0.25, 0.72, 0.3), Vector3(-0.38, 1.74, 0.05), primary)
		_part("HairRight", Vector3(0.25, 0.72, 0.3), Vector3(0.38, 1.74, 0.05), primary)
		_add_book(primary)

func _build_face(skin: Material, primary: Material, ink_material: Material) -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("fffaf1")
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color("211927")
	var blush := StandardMaterial3D.new()
	blush.albedo_color = Color("f39a9d")
	_sphere_part("LeftEye", Vector3(0.16, 0.2, 0.07), Vector3(-0.2, 1.82, -0.55), white)
	_sphere_part("RightEye", Vector3(0.16, 0.2, 0.07), Vector3(0.2, 1.82, -0.55), white)
	_sphere_part("LeftPupil", Vector3(0.075, 0.11, 0.035), Vector3(-0.2, 1.81, -0.62), ink)
	_sphere_part("RightPupil", Vector3(0.075, 0.11, 0.035), Vector3(0.2, 1.81, -0.62), ink)
	_sphere_part("LeftEyeHighlight", Vector3(0.026, 0.034, 0.014), Vector3(-0.225, 1.86, -0.657), white)
	_sphere_part("RightEyeHighlight", Vector3(0.026, 0.034, 0.014), Vector3(0.175, 1.86, -0.657), white)
	var left_brow := _part("LeftBrow", Vector3(0.25, 0.035, 0.035), Vector3(-0.2, 2.02, -0.57), ink)
	var right_brow := _part("RightBrow", Vector3(0.25, 0.035, 0.035), Vector3(0.2, 2.02, -0.57), ink)
	left_brow.rotation.z = -0.08
	right_brow.rotation.z = 0.08
	_sphere_part("LeftBlush", Vector3(0.1, 0.055, 0.025), Vector3(-0.36, 1.62, -0.57), blush)
	_sphere_part("RightBlush", Vector3(0.1, 0.055, 0.025), Vector3(0.36, 1.62, -0.57), blush)
	if companion_id in ["moss", "sky", "melody"]:
		var beak := _part("Beak", Vector3(0.18, 0.14, 0.16), Vector3(0, 1.61, -0.61), _plain_material(Color("efa82f")))
		beak.rotation.x = 0.25
	else:
		_sphere_part("Nose", Vector3(0.045, 0.04, 0.035), Vector3(0, 1.69, -0.64), skin)
		var mouth := _sphere_part("Smile", Vector3(0.13, 0.045, 0.025), Vector3(0, 1.57, -0.64), ink)
		mouth.scale.y = 0.55

func _add_pointed_ears(material: Material) -> void:
	for side in [-1.0, 1.0]:
		var ear := _part("PointedEar", Vector3(0.24, 0.42, 0.18), Vector3(side * 0.31, 2.2, 0), material)
		ear.rotation.z = side * 0.35

func _add_long_ears(material: Material) -> void:
	for side in [-1.0, 1.0]:
		var ear := _part("LongEar", Vector3(0.22, 0.72, 0.18), Vector3(side * 0.25, 2.42, 0.02), material)
		ear.rotation.z = side * 0.16

func _add_round_ears(material: Material) -> void:
	for side in [-1.0, 1.0]: _sphere_part("RoundEar", Vector3(0.23, 0.23, 0.16), Vector3(side * 0.42, 2.04, 0), material)

func _add_horns(material: Material) -> void:
	for side in [-1.0, 1.0]:
		var horn := _part("Horn", Vector3(0.13, 0.38, 0.13), Vector3(side * 0.22, 2.35, 0.04), material)
		horn.rotation.z = side * 0.25

func _add_wings(material: Material) -> void:
	_part("LeftWing", Vector3(0.55, 0.55, 0.14), Vector3(-0.58, 1.2, 0.18), material).rotation.z = -0.48
	_part("RightWing", Vector3(0.55, 0.55, 0.14), Vector3(0.58, 1.2, 0.18), material).rotation.z = 0.48

func _add_tail(material: Material) -> void:
	accessory = Node3D.new()
	accessory.name = "AnimatedTail"
	accessory.position = Vector3(0, 0.9, 0.3)
	body_root.add_child(accessory)
	for i in 3:
		var piece := MeshInstance3D.new()
		piece.name = "TailPiece%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.2, 0.5, 0.2)
		mesh.material = material
		piece.mesh = mesh
		piece.position = Vector3(0.2 + i * 0.17, i * 0.18, 0)
		piece.rotation.z = -0.55 - i * 0.12
		accessory.add_child(piece)

func _add_book(material: Material) -> void:
	var book := _part("Book", Vector3(0.62, 0.5, 0.12), Vector3(0, 1.03, -0.38), material)
	book.rotation.x = -0.18
	_part("BookPages", Vector3(0.05, 0.43, 0.14), Vector3(0, 1.03, -0.45), _plain_material(Color("fff8df")))

func _add_graduation_cap(material: Material) -> void:
	_part("CapTop", Vector3(1.0, 0.12, 0.82), Vector3(0, 2.23, 0), material).rotation.y = 0.1
	_part("CapBand", Vector3(0.68, 0.22, 0.62), Vector3(0, 2.1, 0), material)

func _add_wizard_hat(material: Material, accent: Material) -> void:
	_part("HatBrim", Vector3(1.05, 0.12, 0.82), Vector3(0, 2.19, 0), material)
	var cone := MeshInstance3D.new()
	cone.name = "WizardHat"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.38
	mesh.height = 0.9
	mesh.material = material
	cone.mesh = mesh
	cone.position = Vector3(0, 2.62, 0)
	cone.rotation.z = -0.16
	body_root.add_child(cone)

func _add_glasses() -> void:
	var ink := _plain_material(Color("24172c"))
	for x in [-0.2, 0.2]:
		_part("GlassesTop", Vector3(0.34, 0.035, 0.035), Vector3(x, 1.98, -0.65), ink)
		_part("GlassesBottom", Vector3(0.34, 0.035, 0.035), Vector3(x, 1.66, -0.65), ink)
		_part("GlassesLeft", Vector3(0.035, 0.32, 0.035), Vector3(x - 0.17, 1.82, -0.65), ink)
		_part("GlassesRight", Vector3(0.035, 0.32, 0.035), Vector3(x + 0.17, 1.82, -0.65), ink)
	_part("GlassesBridge", Vector3(0.12, 0.04, 0.04), Vector3(0, 1.82, -0.65), ink)

func _plain_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material

func _part(label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	item.mesh = mesh
	item.position = at
	body_root.add_child(item)
	return item

func _sphere_part(label: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	item.mesh = mesh
	item.scale = size * 2.0
	item.position = at
	body_root.add_child(item)
	return item

func _capsule_part(label: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	mesh.material = material
	item.mesh = mesh
	item.position = at
	body_root.add_child(item)
	return item

func _attach_part(item: Node3D, parent: Node3D, local_position: Vector3) -> void:
	body_root.remove_child(item)
	parent.add_child(item)
	item.position = local_position

func _animate_body(delta: float, amount: float, running: bool) -> void:
	if amount > 0.05:
		move_phase += delta * (13.0 if running else 8.0)
		var swing := sin(move_phase) * (0.88 if running else 0.52)
		left_arm.rotation.x = swing
		right_arm.rotation.x = -swing
		left_leg.rotation.x = -swing * 0.78
		right_leg.rotation.x = swing * 0.78
		head.rotation.y = 0.0
		if is_instance_valid(accessory): accessory.rotation.z = sin(move_phase * 1.4) * 0.28
		body_root.position.y = abs(sin(move_phase * 2.0)) * (0.09 if running else 0.045)
		body_root.rotation.z = sin(move_phase) * (0.045 if running else 0.02)
		body_root.rotation.x = lerp(body_root.rotation.x, -0.16 if running else -0.04, delta * 8.0)
	else:
		move_phase += delta * 1.7
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.0, delta * 7.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, delta * 7.0)
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 7.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 7.0)
		head.rotation.y = 0.0
		body_root.position.y = sin(move_phase) * 0.018
		body_root.rotation.z = 0.0
		body_root.rotation.x = lerp(body_root.rotation.x, 0.0, delta * 7.0)

func celebrate() -> void:
	var tween := create_tween()
	if companion_id in ["moss", "sky", "ember", "melody"]:
		for i in 3:
			tween.tween_property(left_arm, "rotation:z", -1.2, 0.1)
			tween.parallel().tween_property(right_arm, "rotation:z", 1.2, 0.1)
			tween.tween_property(left_arm, "rotation:z", -0.25, 0.1)
			tween.parallel().tween_property(right_arm, "rotation:z", 0.25, 0.1)
	elif companion_id == "sunny":
		for i in 3:
			tween.tween_property(right_arm, "rotation:z", 1.35, 0.1)
			tween.tween_property(right_arm, "rotation:z", 0.65, 0.1)
	else:
		tween.tween_property(body_root, "rotation:y", TAU, 0.55)
		tween.parallel().tween_property(body_root, "position:y", 0.65, 0.25)
		tween.tween_property(body_root, "position:y", 0.0, 0.25)
	tween.tween_callback(func(): body_root.rotation.y = 0.0; left_arm.rotation.z = 0.0; right_arm.rotation.z = 0.0)

func cast_skill(target_position: Vector3) -> void:
	action_locked = true
	var toward := target_position
	toward.y = global_position.y
	look_at(toward, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(body_root, "scale", Vector3(0.9, 1.1, 0.9), 0.12)
	tween.parallel().tween_property(left_arm, "rotation:x", -2.2, 0.12)
	tween.parallel().tween_property(right_arm, "rotation:x", -2.2, 0.12)
	tween.tween_property(body_root, "position:y", 0.42, 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_property(body_root, "position:y", 0.0, 0.18)
	tween.parallel().tween_property(body_root, "scale", Vector3.ONE, 0.18)
	tween.tween_callback(func(): action_locked = false)

func take_hit() -> void:
	var tween := create_tween()
	for offset in [-0.16, 0.16, -0.1, 0.1, 0.0]:
		tween.tween_property(body_root, "position:x", offset, 0.06)
