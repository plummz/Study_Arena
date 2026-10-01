class_name DungeonActor
extends Node3D
## Animated 3D encounter (KayKit skeleton enemies and adventurer NPCs, CC0).
## Skeletons lie dormant until the explorer comes close, then rise and taunt.

const CHAR_DIR := "res://assets/models/characters/"
const WEAPON_DIR := "res://assets/models/weapons/"
const ENEMIES := [
	{"model": "Skeleton_Warrior.glb", "title": "Skeleton Warrior", "right": "Skeleton_Blade.gltf", "left": "Skeleton_Shield_Small_A.gltf", "attack": "1H_Melee_Attack_Chop", "tint": Color("ff5a6e")},
	{"model": "Skeleton_Mage.glb", "title": "Skeleton Mage", "right": "Skeleton_Staff.gltf", "left": "", "attack": "Spellcast_Shoot", "tint": Color("b86bff")},
	{"model": "Skeleton_Rogue.glb", "title": "Skeleton Rogue", "right": "Skeleton_Blade.gltf", "left": "", "attack": "1H_Melee_Attack_Chop", "tint": Color("ff8a3c")},
	{"model": "Skeleton_Minion.glb", "title": "Skeleton Minion", "right": "Skeleton_Axe.gltf", "left": "", "attack": "2H_Melee_Attack_Spin", "tint": Color("9be35b")},
]
const NPCS := [
	{"model": "Mage.glb", "title": "Wise Wanderer", "right": "staff.gltf", "tint": Color("63d8ff")},
	{"model": "Rogue_Hooded.glb", "title": "Hooded Scholar", "right": "", "tint": Color("63ffc8")},
	{"model": "Knight.glb", "title": "Lost Knight", "right": "", "tint": Color("ffd36d")},
]
const DISSOLVE_CODE := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_tex = false;
uniform float dissolve = 0.0;
uniform float flash = 0.0;
uniform vec3 edge_color : source_color = vec3(0.5, 0.9, 1.0);
varying vec3 local_pos;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { local_pos = VERTEX; }
void fragment() {
	vec4 c = albedo;
	if (use_tex) { c *= texture(albedo_tex, UV); }
	float n = noise(local_pos * 7.0) * 0.6 + noise(local_pos * 19.0) * 0.4;
	// Burns from the head down: higher points reach the threshold first.
	float h = mix(n, 1.0 - clamp(local_pos.y / 2.4, 0.0, 1.0), 0.5) - dissolve * 1.15 + 0.08;
	if (h < 0.0) { discard; }
	float edge = (1.0 - smoothstep(0.0, 0.09, h)) * step(0.001, dissolve);
	ALBEDO = mix(c.rgb, vec3(1.0), flash);
	EMISSION = edge_color * edge * 5.0 + vec3(flash * 0.8);
	ROUGHNESS = 0.85;
}
"""
static var _prepared := {}

var actor_kind := "enemy"
var variant := 0
var player_target: Node3D
var model: Node3D
var anim: AnimationPlayer
var marker: MeshInstance3D
var nameplate: Label3D
var title := ""
var tint := Color.WHITE
var attack_animation := "1H_Melee_Attack_Chop"
var awake := false
var busy := false
var defeated := false
var near := false
var phase := 0.0
var taunt_clock := 4.0
var encounter_number := 0

func configure(kind: String, style: int, target: Node3D = null, number := 0) -> void:
	actor_kind = kind
	variant = style
	player_target = target
	encounter_number = number

func _ready() -> void:
	var data: Dictionary = (ENEMIES[variant % ENEMIES.size()] if actor_kind == "enemy" else NPCS[variant % NPCS.size()])
	title = data.title
	tint = data.tint
	attack_animation = data.get("attack", "Spellcasting")
	model = load(CHAR_DIR + data.model).instantiate()
	model.name = "Model"
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_prepare_loops(data.model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		_attach(skeleton, "handslot.r", String(data.get("right", "")))
		_attach(skeleton, "handslot.l", String(data.get("left", "")))
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 34.0
		mesh.visibility_range_end_margin = 3.0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_marker()
	phase = float(variant) * 0.9 + float(encounter_number) * 0.37
	taunt_clock = 3.0 + fmod(float(encounter_number) * 1.3, 5.0)
	if actor_kind == "enemy":
		_play("Skeleton_Inactive_Standing_Pose", 0.0)
	else:
		awake = true
		_play("Idle", 0.0)
	set_active(false)

func _prepare_loops(key: String) -> void:
	if anim == null or _prepared.has(key):
		return
	_prepared[key] = true
	for name in ["Idle", "Idle_B", "Idle_Combat", "Walking_A", "Walking_D_Skeletons", "Spellcasting", "Skeleton_Inactive_Standing_Pose", "Death_A_Pose"]:
		if anim.has_animation(name):
			anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR if not name.ends_with("_Pose") else Animation.LOOP_NONE

func _attach(skeleton: Skeleton3D, bone: String, file: String) -> void:
	if file.is_empty() or skeleton.find_bone(bone) < 0 or not ResourceLoader.exists(WEAPON_DIR + file):
		return
	var slot := BoneAttachment3D.new()
	slot.name = "Slot_" + bone.replace(".", "_")
	slot.bone_name = bone
	skeleton.add_child(slot)
	var item: Node3D = load(WEAPON_DIR + file).instantiate()
	slot.add_child(item)
	for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 30.0
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_marker() -> void:
	marker = MeshInstance3D.new()
	marker.name = "MarkerCrystal"
	var crystal := SphereMesh.new()
	crystal.radius = 0.16
	crystal.height = 0.46
	crystal.radial_segments = 4
	crystal.rings = 2
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crystal.material = material
	marker.mesh = crystal
	marker.position.y = 2.75
	marker.visibility_range_end = 30.0
	add_child(marker)
	nameplate = Label3D.new()
	nameplate.name = "Nameplate"
	nameplate.text = "%s\nEncounter %d" % [title, encounter_number]
	nameplate.font_size = 44
	nameplate.pixel_size = 0.0036
	nameplate.outline_size = 5
	nameplate.outline_modulate = Color(0.04, 0.03, 0.06, 0.0)
	nameplate.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.position.y = 3.2
	nameplate.no_depth_test = false
	add_child(nameplate)

## Called by the game's proximity manager so only nearby actors animate.
func set_active(value: bool) -> void:
	near = value
	set_process(value)
	if anim:
		anim.active = value

func _process(delta: float) -> void:
	if defeated or not is_instance_valid(player_target):
		return
	phase += delta
	marker.position.y = 2.75 + sin(phase * 2.2) * 0.12
	marker.rotation.y += delta * 1.6
	var to_player := player_target.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	nameplate.modulate.a = move_toward(nameplate.modulate.a, 1.0 if distance < 7.5 else 0.0, delta * 3.0)
	nameplate.outline_modulate.a = nameplate.modulate.a * 0.85
	if distance < 14.0:
		var wanted := atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, wanted, 1.0 - exp(-delta * (5.0 if awake else 0.0)))
	# A crouching (sneaking) explorer is noticed at half the distance.
	var notice := 5.2 if bool(player_target.get("crouching")) else 10.5
	if actor_kind == "enemy" and not awake and distance < notice:
		awaken()
	if awake and not busy:
		taunt_clock -= delta
		if taunt_clock <= 0.0 and distance < 9.0:
			taunt_clock = 6.0 + randf() * 5.0
			_one_shot("Taunt" if actor_kind == "enemy" else "Cheer", "Idle_Combat" if actor_kind == "enemy" else "Idle")

func awaken() -> void:
	if awake:
		return
	awake = true
	busy = true
	_play("Skeletons_Awaken_Standing", 0.15)
	get_tree().call_group("dungeon_audio", "play_at", "rattle", global_position)
	await _finished()
	busy = false
	_play("Idle_Combat", 0.3)

func react_question() -> void:
	if actor_kind == "enemy" and not awake:
		awaken()
		return
	_one_shot("Taunt" if actor_kind == "enemy" else "Interact", "Idle_Combat" if actor_kind == "enemy" else "Idle")

func cast_attack() -> void:
	_one_shot(attack_animation, "Idle_Combat" if actor_kind == "enemy" else "Idle")

## Correct answer: hit flash, stagger back, collapse, bones burst out and the body burns
## away from the top down while the soul rises. Scholars ascend in golden light instead.
func defeat() -> void:
	if defeated:
		return
	defeated = true
	busy = true
	set_process(true)
	if anim:
		anim.active = true
	marker.visible = false
	nameplate.visible = false
	var materials := _dissolve_materials(Color("7fe8ff") if actor_kind == "enemy" else Color("ffd36d"))
	_set_param(materials, "flash", 1.0)
	create_tween().tween_method(func(v: float): _set_param(materials, "flash", v), 1.0, 0.0, 0.35)
	if actor_kind == "enemy":
		_play("Hit_A", 0.05)
		var away := Vector3.FORWARD
		if is_instance_valid(player_target):
			var flat := (global_position - player_target.global_position) * Vector3(1, 0, 1)
			if flat.length() > 0.01:
				away = flat.normalized()
		var local_away := (global_basis.inverse() * away) * Vector3(1, 0, 1)
		var knock := create_tween()
		knock.tween_property(model, "position", model.position + local_away * 0.55, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.3).timeout
		_play("Death_A", 0.08)
		await get_tree().create_timer(0.55).timeout
		_bone_burst()
		_soul(Color("9ff3ff"), 1.6)
		await _dissolve(materials, 1.3)
	else:
		_play("Cheer", 0.1)
		await get_tree().create_timer(0.9).timeout
		_soul(Color("ffe39a"), 2.4)
		var rise := create_tween()
		rise.tween_property(model, "position:y", model.position.y + 1.2, 1.4).set_trans(Tween.TRANS_SINE)
		await _dissolve(materials, 1.4)
	model.visible = false

## Wrong answer: the enemy gloats, then melts into purple shadow.
func retreat() -> void:
	if defeated:
		return
	defeated = true
	busy = true
	set_process(true)
	if anim:
		anim.active = true
	marker.visible = false
	nameplate.visible = false
	var gloat := "Taunt" if actor_kind == "enemy" else "Interact"
	if anim and anim.has_animation(gloat):
		anim.play(gloat, 0.12)
	await get_tree().create_timer(0.7).timeout
	var materials := _dissolve_materials(Color("b35cff"))
	_soul(Color("7a3cff"), 1.2)
	var sink := create_tween()
	sink.tween_property(model, "position:y", model.position.y - 0.4, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _dissolve(materials, 1.1)
	model.visible = false

static var _dissolve_shader: Shader

func _dissolve_materials(edge: Color) -> Array[ShaderMaterial]:
	if _dissolve_shader == null:
		_dissolve_shader = Shader.new()
		_dissolve_shader.code = DISSOLVE_CODE
	var materials: Array[ShaderMaterial] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		mesh.visibility_range_end = 0.0
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			var material := ShaderMaterial.new()
			material.shader = _dissolve_shader
			material.set_shader_parameter("edge_color", edge)
			if source is BaseMaterial3D:
				var base := source as BaseMaterial3D
				material.set_shader_parameter("albedo", base.albedo_color)
				if base.albedo_texture:
					material.set_shader_parameter("albedo_tex", base.albedo_texture)
					material.set_shader_parameter("use_tex", true)
			mesh.set_surface_override_material(surface, material)
			materials.append(material)
	return materials

func _set_param(materials: Array[ShaderMaterial], key: String, value: float) -> void:
	for material in materials:
		material.set_shader_parameter(key, value)

func _dissolve(materials: Array[ShaderMaterial], seconds: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(v: float): _set_param(materials, "dissolve", v), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

## Rising wisps and a brief glow where the body was.
func _soul(color: Color, lifetime: float) -> void:
	var wisps := CPUParticles3D.new()
	wisps.amount = 22
	wisps.lifetime = lifetime
	wisps.one_shot = true
	wisps.explosiveness = 0.35
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wisps.emission_box_extents = Vector3(0.35, 0.8, 0.35)
	wisps.direction = Vector3.UP
	wisps.spread = 18.0
	wisps.initial_velocity_min = 0.8
	wisps.initial_velocity_max = 2.0
	wisps.gravity = Vector3(0, 0.6, 0)
	wisps.scale_amount_min = 0.03
	wisps.scale_amount_max = 0.08
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	var soft := Gradient.new()
	soft.set_color(0, Color.WHITE)
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	material.albedo_texture = dot
	quad.material = material
	wisps.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 1.0))
	fade.set_color(1, Color(color, 0.0))
	wisps.color_ramp = fade
	wisps.position = Vector3(0, 1.0, 0)
	add_child(wisps)
	wisps.emitting = true
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 1.6
	glow.omni_range = 4.0
	glow.position = Vector3(0, 1.2, 0)
	add_child(glow)
	create_tween().tween_property(glow, "light_energy", 0.0, lifetime)

## Skeletons scatter a handful of real, tumbling bones across the floor.
func _bone_burst() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var pieces := ["bone_A", "bone_B", "bone_C", "bone_A", "ribcage", "skull"]
	for i in pieces.size():
		var path := "res://assets/models/props/%s.gltf" % pieces[i]
		if not ResourceLoader.exists(path):
			continue
		var body := RigidBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 1
		body.mass = 0.4
		body.add_to_group("dungeon_generated")
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 0.25, 0.3) if pieces[i] == "ribcage" else Vector3(0.28, 0.14, 0.28)
		shape_node.shape = box
		body.add_child(shape_node)
		var piece: Node3D = load(path).instantiate()
		piece.scale = Vector3.ONE * 0.6
		body.add_child(piece)
		scene_root.add_child(body)
		body.global_position = global_position + Vector3(randf_range(-0.25, 0.25), 0.9 + i * 0.12, randf_range(-0.25, 0.25))
		var angle := randf() * TAU
		body.apply_central_impulse(Vector3(cos(angle) * randf_range(0.5, 1.2), randf_range(1.4, 2.4), sin(angle) * randf_range(0.5, 1.2)) * body.mass)
		body.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var cleanup := body.create_tween()
		cleanup.tween_interval(6.0 + i * 0.2)
		cleanup.tween_property(piece, "scale", Vector3.ONE * 0.01, 0.6)
		cleanup.tween_callback(body.queue_free)

func _one_shot(animation: String, then: String) -> void:
	if busy or anim == null or not anim.has_animation(animation):
		return
	busy = true
	_play(animation, 0.12)
	await _finished()
	busy = false
	if not defeated:
		_play(then, 0.25)

func _play(animation: String, blend: float) -> void:
	if anim and anim.has_animation(animation):
		anim.play(animation, blend)

func _finished() -> void:
	if anim == null:
		return
	var length := anim.current_animation_length if anim.current_animation != "" else 0.5
	await get_tree().create_timer(maxf(0.2, length - 0.05)).timeout
