class_name CartoonActor
extends Node3D

var actor_kind := "enemy"
var variant := 0
var player_target: Node3D
var body_root: Node3D
var head_root: Node3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_eye: MeshInstance3D
var right_eye: MeshInstance3D
var mouth: MeshInstance3D
var prompt: Label3D
var phase := 0.0
var blink_clock := 2.0
var reacting := false

func configure(kind: String, style: int, target: Node3D = null) -> void:
	actor_kind = kind
	variant = style
	player_target = target

func _ready() -> void:
	_build_actor()
	phase = float(variant) * 0.71
	blink_clock = 1.2 + fmod(float(variant) * 0.83, 2.8)

func _process(delta: float) -> void:
	phase += delta * (2.35 if actor_kind == "enemy" else 1.65)
	if not reacting:
		body_root.position.y = sin(phase) * 0.075
		body_root.rotation.z = sin(phase * 0.72) * 0.045
		left_arm.rotation.x = sin(phase) * (0.17 if actor_kind == "npc" else 0.27)
		right_arm.rotation.x = -left_arm.rotation.x
		head_root.rotation.y = sin(phase * 0.55) * 0.09
	blink_clock -= delta
	if blink_clock <= 0.0:
		blink_clock = 2.0 + fmod(float(variant) * 0.61, 2.7)
		_blink()
	if is_instance_valid(player_target) and global_position.distance_to(player_target.global_position) < 12.0:
		var toward := player_target.global_position
		toward.y = global_position.y
		look_at(toward, Vector3.UP)

func _build_actor() -> void:
	body_root = Node3D.new()
	body_root.name = "AnimatedBody"
	add_child(body_root)
	head_root = Node3D.new()
	head_root.name = "CartoonFace"
	head_root.position = Vector3(0, 1.62, 0)
	body_root.add_child(head_root)
	var palettes := [
		[Color("9f3858"), Color("d8665e"), Color("ffd36d")],
		[Color("633a91"), Color("9465c7"), Color("71e7db")],
		[Color("2f6688"), Color("54a8bd"), Color("ffd36d")],
		[Color("936027"), Color("d28b3f"), Color("b8f36b")],
	]
	var colors: Array = palettes[variant % palettes.size()]
	if actor_kind == "npc":
		colors = [Color("2e6880"), Color("5bb7b6"), Color("ffd985")]
	var dark := _material(colors[0], 0.72)
	var primary := _material(colors[1], 0.68, 0.13)
	var accent := _material(colors[2], 0.55, 0.28)
	var white := _material(Color("fff8e7"), 0.5)
	var ink := _material(Color("20172b"), 0.58)
	_part("Body", Vector3(0.82, 0.84, 0.48), Vector3(0, 0.98, 0), primary, body_root)
	_part("Belt", Vector3(0.88, 0.13, 0.52), Vector3(0, 0.82, 0), dark, body_root)
	left_arm = _part("LeftArm", Vector3(0.2, 0.68, 0.22), Vector3(-0.55, 1.06, 0), primary, body_root)
	right_arm = _part("RightArm", Vector3(0.2, 0.68, 0.22), Vector3(0.55, 1.06, 0), primary, body_root)
	_sphere("LeftHand", Vector3(0.14, 0.14, 0.14), Vector3(-0.55, 0.67, 0), accent, body_root)
	_sphere("RightHand", Vector3(0.14, 0.14, 0.14), Vector3(0.55, 0.67, 0), accent, body_root)
	_part("LeftFoot", Vector3(0.3, 0.28, 0.46), Vector3(-0.24, 0.22, -0.04), dark, body_root)
	_part("RightFoot", Vector3(0.3, 0.28, 0.46), Vector3(0.24, 0.22, -0.04), dark, body_root)
	_sphere("Head", Vector3(0.55, 0.5, 0.5), Vector3.ZERO, accent, head_root)
	left_eye = _sphere("LeftEye", Vector3(0.15, 0.19, 0.08), Vector3(-0.19, 0.08, -0.45), white, head_root)
	right_eye = _sphere("RightEye", Vector3(0.15, 0.19, 0.08), Vector3(0.19, 0.08, -0.45), white, head_root)
	_sphere("LeftPupil", Vector3(0.065, 0.09, 0.04), Vector3(-0.19, 0.07, -0.525), ink, head_root)
	_sphere("RightPupil", Vector3(0.065, 0.09, 0.04), Vector3(0.19, 0.07, -0.525), ink, head_root)
	mouth = _part("Mouth", Vector3(0.28, 0.055, 0.045), Vector3(0, -0.22, -0.49), ink, head_root)
	if actor_kind == "enemy":
		var brow_l := _part("AngryBrowL", Vector3(0.22, 0.045, 0.05), Vector3(-0.19, 0.27, -0.48), ink, head_root)
		var brow_r := _part("AngryBrowR", Vector3(0.22, 0.045, 0.05), Vector3(0.19, 0.27, -0.48), ink, head_root)
		brow_l.rotation.z = -0.25
		brow_r.rotation.z = 0.25
		_horn(-0.32, dark)
		_horn(0.32, dark)
	else:
		_part("HatBrim", Vector3(1.05, 0.12, 0.72), Vector3(0, 0.43, 0), dark, head_root)
		var hat := _part("ScholarHat", Vector3(0.52, 0.46, 0.5), Vector3(0, 0.67, 0.02), primary, head_root)
		hat.rotation.z = -0.12
	prompt = Label3D.new()
	prompt.name = "InteractionPrompt"
	prompt.text = "?" if actor_kind == "npc" else "!"
	prompt.font_size = 72
	prompt.modulate = colors[2]
	prompt.outline_size = 12
	prompt.position = Vector3(0, 2.55, 0)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	body_root.add_child(prompt)

func _horn(x: float, material: Material) -> void:
	var horn := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.12
	cone.height = 0.48
	cone.material = material
	horn.mesh = cone
	horn.position = Vector3(x, 0.53, 0)
	horn.rotation.z = -0.35 if x < 0 else 0.35
	_style_geometry(horn)
	head_root.add_child(horn)

func _part(label: String, size: Vector3, at: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	item.mesh = mesh
	item.position = at
	_style_geometry(item)
	parent.add_child(item)
	return item

func _sphere(label: String, size: Vector3, at: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	item.mesh = mesh
	item.scale = size * 2.0
	item.position = at
	_style_geometry(item)
	parent.add_child(item)
	return item

func _style_geometry(item: GeometryInstance3D) -> void:
	item.visibility_range_end = 38.0
	item.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

func _material(color: Color, roughness: float, glow := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color * glow
	return material

func _blink() -> void:
	var tween := create_tween()
	tween.tween_property(left_eye, "scale:y", 0.08, 0.07)
	tween.parallel().tween_property(right_eye, "scale:y", 0.08, 0.07)
	tween.tween_property(left_eye, "scale:y", 0.38, 0.1)
	tween.parallel().tween_property(right_eye, "scale:y", 0.38, 0.1)

func react_question() -> void:
	reacting = true
	prompt.text = "?"
	var tween := create_tween()
	tween.tween_property(body_root, "position:y", 0.3, 0.14).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(head_root, "rotation:z", -0.18, 0.14)
	tween.tween_property(body_root, "position:y", 0.0, 0.18)
	tween.parallel().tween_property(head_root, "rotation:z", 0.0, 0.18)
	tween.tween_callback(func(): reacting = false)

func cast_attack() -> void:
	reacting = true
	prompt.text = "✦"
	var tween := create_tween()
	tween.tween_property(left_arm, "rotation:x", -2.0, 0.18)
	tween.parallel().tween_property(right_arm, "rotation:x", -2.0, 0.18)
	tween.parallel().tween_property(body_root, "scale", Vector3(1.14, 0.9, 1.14), 0.18)
	tween.tween_property(body_root, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func(): reacting = false)

func defeat() -> void:
	reacting = true
	prompt.text = "★"
	mouth.rotation.z = PI
	var tween := create_tween().set_parallel(true)
	tween.tween_property(body_root, "rotation:y", body_root.rotation.y + TAU * 1.5, 0.62)
	tween.tween_property(body_root, "position:y", 1.15, 0.28).set_trans(Tween.TRANS_BACK)
	tween.tween_property(body_root, "scale", Vector3.ZERO, 0.62).set_delay(0.18)
