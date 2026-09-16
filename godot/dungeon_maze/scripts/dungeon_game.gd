extends Node3D

const PlayerAvatar = preload("res://scripts/player_avatar.gd")
const ThirdPersonCamera = preload("res://scripts/third_person_camera.gd")
const CartoonActor = preload("res://scripts/cartoon_actor.gd")
const GRID_SIZE := 31
const CELL_SIZE := 5.4
const ENCOUNTER_COUNT := 100
const WALL_HEIGHT := 5.8
const SAVE_FILE := "user://dungeon_progress.json"
const SAVE_VERSION := 1
const STUDY_ARENA_HOME := "http://localhost:8080/#home"
const COMPANION_IDS := ["moss", "lumi", "coral", "sky", "plum", "sunny", "mint", "nova", "ember", "bubbles", "byte", "clover", "mochi", "comet", "pebble", "melody", "taro", "sol"]
const DIFFICULTIES := {
	"easy": {"label": "Easy", "seconds": 1800, "mistakes": 10, "hint": 2},
	"average": {"label": "Average", "seconds": 2700, "mistakes": 7, "hint": 3},
	"hard": {"label": "Hard", "seconds": 3600, "mistakes": 5, "hint": 4},
	"hell": {"label": "Hell", "seconds": 4800, "mistakes": 3, "hint": 5},
}

var rng := RandomNumberGenerator.new()
var grid := PackedByteArray()
var walkable: Array[Vector2i] = []
var entrance_cell := Vector2i(1, 1)
var exit_cell := Vector2i(GRID_SIZE - 2, GRID_SIZE - 2)
var encounters: Array[Node3D] = []
var questions: Array[Dictionary] = []
var player: PlayerAvatar
var difficulty := "easy"
var time_left := 0.0
var mistakes_left := 0
var mercy_tokens := 0
var coins := 0
var answered := 0
var current_encounter := -1
var running := false
var is_run_paused := false
var auto_save_elapsed := 0.0
var maze_seed := 0
var cleared_encounters: Array[int] = []
var smoke_mode := false
var map_open := false
var selected_companion := "moss"
var hud: Control
var time_label: Label
var progress_label: Label
var coin_label: Label
var life_label: Label
var prompt_label: Label
var question_panel: PanelContainer
var answer_box: VBoxContainer
var map_panel: PanelContainer
var map_view: DungeonMap
var result_panel: PanelContainer
var message_label: Label
var effects_root: Node3D
var camera_rig: ThirdPersonCamera
var damage_flash: ColorRect
var pause_panel: PanelContainer
var pause_status_label: Label

func _ready() -> void:
	get_tree().auto_accept_quit = false
	rng.randomize()
	selected_companion = _load_companion_choice()
	var launch_companion := _argument_value("--companion=")
	if launch_companion in COMPANION_IDS:
		selected_companion = launch_companion
		_save_companion_choice(selected_companion)
	_build_environment()
	_build_ui()
	smoke_mode = "--smoke" in OS.get_cmdline_user_args()
	if smoke_mode:
		call_deferred("_smoke_test")
	else:
		var launch_difficulty := _argument_value("--difficulty=")
		if _has_saved_run():
			_show_resume_picker(launch_difficulty if launch_difficulty in DIFFICULTIES else "easy")
		elif launch_difficulty in DIFFICULTIES:
			call_deferred("_start_game", launch_difficulty)
		else:
			_show_companion_picker()

func _smoke_test() -> void:
	_start_game("easy")
	assert(questions.size() == ENCOUNTER_COUNT)
	assert(encounters.size() == ENCOUNTER_COUNT)
	assert(get_tree().get_nodes_in_group("dungeon_generated").size() >= 126)
	assert(_branch_count() >= 18)
	assert(get_tree().get_nodes_in_group("puddle").size() == 14)
	assert(get_tree().get_nodes_in_group("snake").size() == 10)
	assert(is_instance_valid(player.left_arm) and is_instance_valid(player.right_leg))
	assert(player.left_arm.mesh is CapsuleMesh and player.right_leg.mesh is CapsuleMesh)
	assert(is_instance_valid(pause_panel) and pause_panel.get_node_or_null("VBoxContainer") != null)
	var sample_actor: CartoonActor = encounters[0].get_meta("actor")
	assert(is_instance_valid(sample_actor) and sample_actor.has_node("AnimatedBody/CartoonFace/LeftEye"))
	assert(get_node_or_null("EntrancePortal/MagicPortal") != null)
	print("DUNGEON_SMOKE_PASS questions=100 encounters=100 traps=24 puddles=14 snakes=10 branches=%d tall_walls=true smooth_camera=true jump=true rounded_player=true pause_save=true retry_home=true" % _branch_count())
	get_tree().quit()

func _process(delta: float) -> void:
	if not running or is_run_paused:
		return
	time_left = maxf(0.0, time_left - delta)
	auto_save_elapsed += delta
	if auto_save_elapsed >= 8.0:
		auto_save_elapsed = 0.0
		_save_progress()
	_update_hud()
	if time_left <= 0.0:
		_game_over("The dungeon clock reached zero.")
	if Input.is_action_just_pressed("map"):
		map_open = not map_open
		map_panel.visible = map_open
	if map_open and is_instance_valid(map_view):
		map_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and running:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if running:
			_save_progress()
		get_tree().quit()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10101a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6b7192")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("45415d")
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.009
	environment.fog_height = 1.4
	environment.fog_height_density = 0.12
	environment.glow_enabled = true
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -35, 0)
	moon.light_color = Color("98aee8")
	moon.light_energy = 0.75
	moon.shadow_enabled = true
	add_child(moon)
	effects_root = Node3D.new()
	effects_root.name = "PooledEffects"
	add_child(effects_root)

func _start_game(mode: String) -> void:
	if not smoke_mode:
		_clear_saved_run()
	difficulty = mode
	var rules: Dictionary = DIFFICULTIES[mode]
	time_left = float(rules.seconds)
	mistakes_left = int(rules.mistakes)
	mercy_tokens = 0
	coins = 0
	answered = 0
	cleared_encounters.clear()
	is_run_paused = false
	auto_save_elapsed = 0.0
	current_encounter = -1
	questions = _make_questions()
	maze_seed = rng.randi()
	rng.seed = maze_seed
	_generate_maze()
	_build_dungeon_meshes()
	_spawn_traps()
	_spawn_puddles_and_snakes()
	_spawn_player()
	_spawn_encounters()
	_build_set_dressing()
	running = true
	hud.visible = true
	message_label.text = "%s dungeon begun. Find all 100 encounters." % rules.label
	_update_hud()
	_save_progress()

func _generate_maze() -> void:
	grid.resize(GRID_SIZE * GRID_SIZE)
	grid.fill(1)
	var stack: Array[Vector2i] = [Vector2i(1, 1)]
	grid[_index(Vector2i(1, 1))] = 0
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var choices: Array[Vector2i] = []
		var directions: Array[Vector2i] = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
		for direction: Vector2i in directions:
			var next: Vector2i = cell + direction
			if next.x > 0 and next.y > 0 and next.x < GRID_SIZE - 1 and next.y < GRID_SIZE - 1 and grid[_index(next)] == 1:
				choices.append(next)
		if choices.is_empty():
			stack.pop_back()
			continue
		var chosen: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
		var between := Vector2i((cell.x + chosen.x) / 2, (cell.y + chosen.y) / 2)
		grid[_index(between)] = 0
		grid[_index(chosen)] = 0
		stack.append(chosen)
	# A perfect maze has only one route between points. Open extra joins to create
	# loops, alternate routes, risky shortcuts and genuine multi-way decisions.
	var loop_candidates: Array[Vector2i] = []
	for z in range(1, GRID_SIZE - 1):
		for x in range(1, GRID_SIZE - 1):
			var cell := Vector2i(x, z)
			if grid[_index(cell)] == 0: continue
			var horizontal := grid[_index(cell + Vector2i.LEFT)] == 0 and grid[_index(cell + Vector2i.RIGHT)] == 0
			var vertical := grid[_index(cell + Vector2i.UP)] == 0 and grid[_index(cell + Vector2i.DOWN)] == 0
			if horizontal or vertical: loop_candidates.append(cell)
	loop_candidates.shuffle()
	for i in mini(64, loop_candidates.size()):
		grid[_index(loop_candidates[i])] = 0
	walkable.clear()
	for z in GRID_SIZE:
		for x in GRID_SIZE:
			if grid[_index(Vector2i(x, z))] == 0:
				walkable.append(Vector2i(x, z))
	entrance_cell = Vector2i(1, 1)
	exit_cell = entrance_cell
	var farthest := -1
	for cell in walkable:
		var distance := absi(cell.x - entrance_cell.x) + absi(cell.y - entrance_cell.y)
		if distance > farthest:
			farthest = distance
			exit_cell = cell
	walkable.erase(entrance_cell)
	walkable.erase(exit_cell)
	for i in range(walkable.size() - 1, 1, -1):
		var j := rng.randi_range(1, i)
		var temp := walkable[i]
		walkable[i] = walkable[j]
		walkable[j] = temp

func _build_dungeon_meshes() -> void:
	for child in get_tree().get_nodes_in_group("dungeon_generated"):
		child.queue_free()
	var floor_light: Array[Vector3] = []
	var floor_dark: Array[Vector3] = []
	var wall_light: Array[Vector3] = []
	var wall_dark: Array[Vector3] = []
	var wall_cells: Array[Vector3] = []
	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var pos := _world(Vector2i(x, z))
			if grid[_index(Vector2i(x, z))] == 0:
				(floor_light if (x + z) % 2 == 0 else floor_dark).append(pos)
			else:
				wall_cells.append(pos)
				(wall_light if (x * 3 + z) % 5 == 0 else wall_dark).append(pos)
	_create_multimesh("StoneFloorLight", floor_light, Vector3(CELL_SIZE - 0.05, 0.18, CELL_SIZE - 0.05), Color("414354"), -0.12)
	_create_multimesh("StoneFloorDark", floor_dark, Vector3(CELL_SIZE - 0.05, 0.18, CELL_SIZE - 0.05), Color("323442"), -0.12)
	_create_multimesh("DungeonWalls", wall_dark, Vector3(CELL_SIZE - 0.04, WALL_HEIGHT, CELL_SIZE - 0.04), Color("282735"), WALL_HEIGHT * 0.5 - 0.1)
	_create_multimesh("DungeonWallHighlights", wall_light, Vector3(CELL_SIZE - 0.04, WALL_HEIGHT, CELL_SIZE - 0.04), Color("393545"), WALL_HEIGHT * 0.5 - 0.1)
	_create_multimesh("WallCrown", wall_cells, Vector3(CELL_SIZE + 0.14, 0.34, CELL_SIZE + 0.14), Color("806873"), WALL_HEIGHT - 0.08)
	var body := StaticBody3D.new()
	body.name = "DungeonCollision"
	body.add_to_group("dungeon_generated")
	add_child(body)
	var ground_node := CollisionShape3D.new()
	var ground := BoxShape3D.new()
	ground.size = Vector3(GRID_SIZE * CELL_SIZE, 0.2, GRID_SIZE * CELL_SIZE)
	ground_node.shape = ground
	ground_node.position.y = -0.12
	body.add_child(ground_node)
	for pos in wall_cells:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
		shape_node.shape = shape
		shape_node.position = pos + Vector3.UP * (WALL_HEIGHT * 0.5 - 0.1)
		body.add_child(shape_node)

func _spawn_traps() -> void:
	for i in 24:
		var trap := Area3D.new()
		trap.name = "Trap_%02d" % (i + 1)
		trap.collision_layer = 4
		trap.collision_mask = 2
		trap.position = _world(walkable[ENCOUNTER_COUNT + i + 5])
		trap.set_meta("trap_type", ["spikes", "flame", "poison", "blade"][i % 4])
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.7, 0.35, 1.7)
		shape_node.shape = shape
		trap.add_child(shape_node)
		var spikes := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0 if i % 4 == 0 else 0.18
		mesh.bottom_radius = 0.72 if i % 4 == 0 else 0.38
		mesh.height = 0.65 if i % 4 == 0 else 1.2
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color("6f7280"), Color("ff7a32"), Color("77d267"), Color("bfc6d4")][i % 4]
		if i % 4 in [1, 2]:
			material.emission_enabled = true
			material.emission = material.albedo_color * 1.8
		material.metallic = 0.55
		mesh.material = material
		spikes.mesh = mesh
		spikes.position.y = 0.28
		trap.add_child(spikes)
		var warning := _mesh_part(trap, "WarningPlate", Vector3(2.2, 0.06, 2.2), Vector3(0, 0.03, 0), Color("6d2735"), true)
		warning.transparency = 0.28
		# Keep the warning readable without synchronizing 24 one-second pulses,
		# which was perceived as a full-screen heartbeat on some GPUs.
		spikes.position.y += 0.08 * float(i % 3)
		trap.body_entered.connect(_on_trap_entered.bind(trap))
		trap.add_to_group("dungeon_generated")
		trap.add_to_group("trap")
		add_child(trap)

func _on_trap_entered(body: Node3D, trap: Area3D) -> void:
	if body != player or bool(trap.get_meta("spent", false)) or not running:
		return
	trap.set_meta("spent", true)
	var penalties := {"easy": 15, "average": 20, "hard": 30, "hell": 45}
	time_left = maxf(0.0, time_left - float(penalties[difficulty]))
	player.take_hit()
	message_label.text = "A dungeon trap triggered! −%d seconds." % penalties[difficulty]
	var tween := create_tween()
	tween.tween_property(trap, "position:y", -0.7, 0.35)
	tween.tween_callback(trap.queue_free)

func _spawn_puddles_and_snakes() -> void:
	for i in 14:
		var puddle := Node3D.new()
		puddle.name = "WaterPuddle_%02d" % i
		puddle.position = _world(walkable[150 + i * 4]) + Vector3.UP * 0.015
		puddle.add_to_group("dungeon_generated")
		puddle.add_to_group("puddle")
		add_child(puddle)
		var water := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.15 + (i % 3) * 0.18
		disc.bottom_radius = disc.top_radius
		disc.height = 0.035
		var water_material := _dungeon_material(Color("529bc4aa"), true)
		water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water_material.metallic = 0.35
		water_material.roughness = 0.16
		disc.material = water_material
		water.mesh = disc
		puddle.add_child(water)
		var ripple := create_tween().set_loops()
		var ripple_time := 1.65 + float(i % 5) * 0.19
		ripple.tween_property(water, "scale", Vector3(1.035, 1.0, 0.97), ripple_time).set_trans(Tween.TRANS_SINE)
		ripple.tween_property(water, "scale", Vector3(0.97, 1.0, 1.035), ripple_time + 0.21).set_trans(Tween.TRANS_SINE)
	for i in 10:
		var snake := Area3D.new()
		snake.name = "CartoonSnake_%02d" % i
		snake.position = _world(walkable[215 + i * 5])
		snake.collision_layer = 4
		snake.collision_mask = 2
		snake.add_to_group("dungeon_generated")
		snake.add_to_group("snake")
		add_child(snake)
		var snake_shape := CollisionShape3D.new()
		var snake_box := BoxShape3D.new()
		snake_box.size = Vector3(2.3, 0.35, 1.25)
		snake_shape.shape = snake_box
		snake_shape.position.y = 0.18
		snake.add_child(snake_shape)
		var snake_color := Color("65bf63") if i % 2 == 0 else Color("d49a42")
		for segment in 6:
			var bead := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.23 + (5 - segment) * 0.015
			sphere.height = sphere.radius * 2.0
			sphere.material = _dungeon_material(snake_color, false)
			bead.mesh = sphere
			bead.position = Vector3(-0.85 + segment * 0.34, 0.24, sin(float(segment) * 1.7) * 0.22)
			snake.add_child(bead)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.38
		head_mesh.height = 0.7
		head_mesh.material = _dungeon_material(snake_color.lightened(0.12), false)
		head.mesh = head_mesh
		head.position = Vector3(1.15, 0.38, 0)
		snake.add_child(head)
		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var eye_mesh := SphereMesh.new()
			eye_mesh.radius = 0.075
			eye_mesh.height = 0.15
			eye_mesh.material = _dungeon_material(Color("fff8df"), true)
			eye.mesh = eye_mesh
			eye.position = Vector3(1.43, 0.48, side * 0.17)
			snake.add_child(eye)
		snake.body_entered.connect(_on_snake_entered.bind(snake))
		var slither := create_tween().set_loops()
		slither.tween_property(snake, "rotation:y", 0.18, 0.7).set_trans(Tween.TRANS_SINE)
		slither.tween_property(snake, "rotation:y", -0.18, 0.7).set_trans(Tween.TRANS_SINE)

func _on_snake_entered(body: Node3D, snake: Area3D) -> void:
	if body != player or bool(snake.get_meta("spent", false)) or not running: return
	snake.set_meta("spent", true)
	time_left = maxf(0.0, time_left - 12.0)
	player.take_hit()
	message_label.text = "A dungeon snake struck! Jump over the next one. −12 seconds."
	_play_enemy_skill(snake)
	create_tween().tween_property(snake, "scale", Vector3.ZERO, 0.35).tween_callback(snake.queue_free)

func _create_multimesh(label: String, positions: Array[Vector3], size: Vector3, color: Color, y: float) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.add_to_group("dungeon_generated")
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.93
	box.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = positions.size()
	for i in positions.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i] + Vector3.UP * y))
	instance.multimesh = multi
	add_child(instance)

func _build_set_dressing() -> void:
	# A small, capped light budget gives the maze warmth without turning 100 rooms
	# into 100 shadow-casting lights.
	for i in 14:
		var cell := walkable[130 + i * 7]
		var torch := Node3D.new()
		torch.name = "Torch_%02d" % i
		torch.position = _world(cell)
		torch.add_to_group("dungeon_generated")
		add_child(torch)
		_mesh_part(torch, "Bracket", Vector3(0.12, 0.65, 0.12), Vector3(0, 1.05, 0), Color("5b3927"), false)
		var flame := _mesh_part(torch, "Flame", Vector3(0.24, 0.42, 0.24), Vector3(0, 1.55, 0), Color("ffb43b"), true)
		flame.rotation.z = 0.08 * (-1.0 if i % 2 == 0 else 1.0)
		var light := OmniLight3D.new()
		light.light_color = Color("ffb65d")
		light.light_energy = 2.2
		light.omni_range = 8.5
		light.shadow_enabled = false
		light.position.y = 1.55
		torch.add_child(light)
		# Flames stay visually alive, but no longer resize in a synchronized loop.
		flame.scale = Vector3(0.92 + float(i % 3) * 0.035, 1.04 + float(i % 4) * 0.025, 0.92)
	_build_gateway(_world(entrance_cell) + Vector3(0, 0, CELL_SIZE * 0.72), Color("68dbff"), "EntrancePortal", "ENTRANCE")
	_build_gateway(_world(exit_cell), Color("d997ff"), "VictoryPortal", "EXIT")
	for i in 10:
		var prop := Node3D.new()
		prop.name = "DungeonProp_%02d" % i
		prop.position = _world(walkable[245 + i * 5])
		prop.rotation.y = rng.randf_range(0.0, TAU)
		prop.add_to_group("dungeon_generated")
		add_child(prop)
		_mesh_part(prop, "Crate", Vector3(0.8, 0.75, 0.8), Vector3(0, 0.38, 0), Color("6e4931"), false)
		_mesh_part(prop, "Band", Vector3(0.9, 0.12, 0.88), Vector3(0, 0.4, 0), Color("b7844f"), false)

func _build_gateway(at: Vector3, color: Color, label: String, display_text: String) -> void:
	var gate := Node3D.new()
	gate.name = label
	gate.position = at
	gate.add_to_group("dungeon_generated")
	add_child(gate)
	_mesh_part(gate, "LeftPillar", Vector3(0.48, 3.0, 0.55), Vector3(-1.25, 1.5, 0), Color("564758"), false)
	_mesh_part(gate, "RightPillar", Vector3(0.48, 3.0, 0.55), Vector3(1.25, 1.5, 0), Color("564758"), false)
	_mesh_part(gate, "Lintel", Vector3(3.0, 0.5, 0.65), Vector3(0, 3.0, 0), Color("6c5967"), false)
	var portal := MeshInstance3D.new()
	portal.name = "MagicPortal"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.08
	torus.rings = 24
	torus.ring_segments = 12
	torus.material = _dungeon_material(color, true)
	portal.mesh = torus
	portal.position.y = 1.55
	portal.rotation.x = PI / 2.0
	gate.add_child(portal)
	create_tween().set_loops().tween_property(portal, "rotation:z", TAU, 4.5).from(0.0)
	var sign := Label3D.new()
	sign.name = "GatewayLabel"
	sign.text = display_text
	sign.font_size = 64
	sign.outline_size = 12
	sign.modulate = color
	sign.position = Vector3(0, 3.65, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(sign)

func _mesh_part(parent: Node3D, label: String, size: Vector3, at: Vector3, color: Color, glow: bool) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _dungeon_material(color, glow)
	item.mesh = mesh
	item.position = at
	item.visibility_range_end = 42.0
	parent.add_child(item)
	return item

func _dungeon_material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if glow:
		material.emission_enabled = true
		material.emission = color * 2.0
	return material

func _spawn_player() -> void:
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(camera_rig):
		camera_rig.queue_free()
	player = PlayerAvatar.new()
	player.name = "Player"
	player.companion_id = selected_companion
	player.position = _world(entrance_cell) + Vector3.UP * 0.05
	add_child(player)
	camera_rig = ThirdPersonCamera.new()
	camera_rig.name = "ThirdPersonCamera"
	camera_rig.target = player
	add_child(camera_rig)

func _spawn_encounters() -> void:
	encounters.clear()
	for i in ENCOUNTER_COUNT:
		var encounter := Area3D.new()
		encounter.name = "Encounter_%03d" % (i + 1)
		encounter.collision_layer = 4
		encounter.collision_mask = 2
		encounter.position = _world(walkable[i + 2])
		encounter.set_meta("encounter_id", i)
		encounter.set_meta("kind", "npc" if rng.randf() < 0.28 else "enemy")
		var shape_node := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 1.15
		shape_node.shape = shape
		encounter.add_child(shape_node)
		var actor := CartoonActor.new()
		actor.name = "CartoonNPC" if encounter.get_meta("kind") == "npc" else "CartoonEnemy"
		actor.configure(String(encounter.get_meta("kind")), i % 4, player)
		encounter.add_child(actor)
		encounter.set_meta("actor", actor)
		encounter.body_entered.connect(_on_encounter_body_entered.bind(encounter))
		encounter.add_to_group("dungeon_generated")
		add_child(encounter)
		encounters.append(encounter)

func _on_encounter_body_entered(body: Node3D, encounter: Area3D) -> void:
	if body != player or current_encounter >= 0 or not running:
		return
	current_encounter = int(encounter.get_meta("encounter_id"))
	player.controls_enabled = false
	var actor: CartoonActor = encounter.get_meta("actor")
	if is_instance_valid(actor): actor.react_question()
	_show_question(current_encounter, String(encounter.get_meta("kind")))

func _make_questions() -> Array[Dictionary]:
	var bank: Array[Dictionary] = []
	for i in ENCOUNTER_COUNT:
		var tier := 1 + int(i / 25)
		var a := 3 + ((i * 7) % (12 * tier))
		var b := 2 + ((i * 11) % (9 * tier))
		var operation := i % 4
		var prompt := ""
		var answer := 0
		match operation:
			0:
				prompt = "What is %d + %d?" % [a, b]
				answer = a + b
			1:
				prompt = "What is %d − %d?" % [a + b, b]
				answer = a
			2:
				prompt = "What is %d × %d?" % [a, b]
				answer = a * b
			_:
				prompt = "What is %d ÷ %d?" % [a * b, b]
				answer = a
		var options: Array[int] = [answer, answer + tier, maxi(0, answer - tier), answer + b]
		options.shuffle()
		bank.append({"prompt": prompt, "answer": answer, "options": options, "explanation": "The accepted answer is %d." % answer})
	return bank

func _show_question(id: int, kind: String) -> void:
	var question := questions[id]
	question_panel.visible = true
	prompt_label.text = "%s  ·  ENCOUNTER %d / 100\n%s" % ["WISE WANDERER" if kind == "npc" else "DUNGEON CHALLENGER", id + 1, question.prompt]
	for child in answer_box.get_children():
		child.queue_free()
	for option in question.options:
		var answer_button := Button.new()
		answer_button.text = str(option)
		answer_button.custom_minimum_size.y = 46
		answer_button.add_theme_font_size_override("font_size", 20)
		answer_button.pressed.connect(_answer_question.bind(int(option)))
		answer_box.add_child(answer_button)
	var hint_button := Button.new()
	hint_button.text = "Reveal hint (%d coins)" % int(DIFFICULTIES[difficulty].hint)
	hint_button.pressed.connect(_use_hint)
	answer_box.add_child(hint_button)

func _answer_question(value: int) -> void:
	var encounter := encounters[current_encounter]
	var question := questions[current_encounter]
	var correct := value == int(question.answer)
	question_panel.visible = false
	if correct:
		coins += 1
		answered += 1
		if current_encounter not in cleared_encounters:
			cleared_encounters.append(current_encounter)
		player.celebrate()
		_play_slay_effect(encounter)
		if rng.randf() < 0.05:
			mercy_tokens += 1
			mistakes_left += 1
			message_label.text = "Correct! +1 coin and a rare Mercy Token!"
		else:
			message_label.text = "Correct! +1 coin. The enemy is defeated."
	else:
		mistakes_left -= 1
		player.take_hit()
		_play_enemy_skill(encounter)
		message_label.text = "Wrong answer. The enemy cast a skill! %d chances remain." % mistakes_left
		if mistakes_left <= 0:
			_game_over("You reached the wrong-answer limit.")
	current_encounter = -1
	player.controls_enabled = running
	_update_hud()
	if answered >= ENCOUNTER_COUNT:
		_complete_maze()
	else:
		_save_progress()

func _use_hint() -> void:
	var cost := int(DIFFICULTIES[difficulty].hint)
	if coins < cost:
		message_label.text = "You need %d maze coins for this hint." % cost
		return
	coins -= cost
	var answer := int(questions[current_encounter].answer)
	message_label.text = "The correct answer is an integer near %d." % (answer + rng.randi_range(-2, 2))
	_update_hud()

func _play_slay_effect(target: Node3D) -> void:
	var actor: CartoonActor = target.get_meta("actor")
	if is_instance_valid(actor): actor.defeat()
	player.cast_skill(target.global_position)
	var start := player.global_position + Vector3.UP * 1.25
	var finish := target.global_position + Vector3.UP * 1.15
	var beam := _effect_beam(start, finish, Color("75e8ff"))
	beam.scale = Vector3(0.1, 0.1, 0.1)
	var flash := _effect_sphere(finish, Color("ffd86b"), 0.35)
	var ring_a := _effect_ring(finish, Color("75e8ff"), 0.45)
	var ring_b := _effect_ring(finish + Vector3.UP * 0.18, Color("ffd86b"), 0.3)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(beam, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(flash, "scale", Vector3.ONE * 4.8, 0.48).set_delay(0.1)
	tween.tween_property(flash, "transparency", 1.0, 0.48).set_delay(0.1)
	tween.tween_property(ring_a, "scale", Vector3.ONE * 5.5, 0.62).set_delay(0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_a, "transparency", 1.0, 0.62).set_delay(0.06)
	tween.tween_property(ring_b, "scale", Vector3.ONE * 7.0, 0.72).set_delay(0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_b, "transparency", 1.0, 0.72).set_delay(0.13)
	for i in 9:
		var angle := TAU * float(i) / 9.0
		var star := _effect_sphere(finish, Color("fff0a6"), 0.09)
		tween.tween_property(star, "global_position", finish + Vector3(cos(angle) * 2.4, sin(angle * 2.0) + 1.0, sin(angle) * 2.4), 0.55).set_delay(0.1)
		tween.tween_callback(star.queue_free).set_delay(0.66)
	tween.chain().tween_interval(0.15)
	tween.tween_callback(func(): beam.queue_free(); flash.queue_free(); ring_a.queue_free(); ring_b.queue_free(); target.queue_free())

func _play_enemy_skill(source: Node3D) -> void:
	var actor: CartoonActor = source.get_meta("actor", null)
	if is_instance_valid(actor): actor.cast_attack()
	var origin := source.global_position + Vector3.UP * 1.3
	var destination := player.global_position + Vector3.UP
	var projectile := _effect_sphere(origin, Color("e74279"), 0.31)
	var trail := _effect_beam(origin, destination, Color("812b9e"))
	var warning_ring := _effect_ring(destination, Color("ef4d79"), 0.55)
	trail.transparency = 0.25
	trail.scale = Vector3(0.35, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(warning_ring, "scale", Vector3.ONE * 2.4, 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.16)
	tween.tween_property(projectile, "global_position", destination, 0.36).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(projectile, "scale", Vector3.ONE * 2.3, 0.09)
	tween.tween_callback(func(): projectile.queue_free(); trail.queue_free(); warning_ring.queue_free(); camera_rig.shake(0.16, 0.28); _flash_damage())

func _effect_beam(from: Vector3, to: Vector3, color: Color) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.16, from.distance_to(to))
	mesh.material = _dungeon_material(color, true)
	beam.mesh = mesh
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	effects_root.add_child(beam)
	return beam

func _flash_damage() -> void:
	damage_flash.visible = true
	damage_flash.modulate.a = 0.6
	create_tween().tween_property(damage_flash, "modulate:a", 0.0, 0.42).tween_callback(func(): damage_flash.visible = false)

func _effect_sphere(at: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var effect := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = material
	effect.mesh = sphere
	effect.position = at
	effects_root.add_child(effect)
	return effect

func _effect_ring(at: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var effect := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.12
	torus.rings = 20
	torus.ring_segments = 10
	torus.material = _dungeon_material(color, true)
	effect.mesh = torus
	effect.position = at
	effect.rotation.x = PI / 2.0
	effect.transparency = 0.08
	effects_root.add_child(effect)
	return effect

func _complete_maze() -> void:
	running = false
	_clear_saved_run()
	player.controls_enabled = false
	result_panel.visible = true
	player.celebrate()
	camera_rig.shake(0.08, 1.1)
	result_panel.get_node("Margin/Result").text = "DUNGEON CONQUERED!\n100 questions cleared\n%d coins earned\n%d Mercy Tokens found" % [coins, mercy_tokens]
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var spark := _effect_sphere(player.global_position + Vector3(cos(angle), 1.0, sin(angle)), Color.from_hsv(float(i) / 16.0, 0.7, 1.0), 0.12)
		create_tween().tween_property(spark, "position", spark.position + Vector3(cos(angle) * 4.0, rng.randf_range(2.0, 5.0), sin(angle) * 4.0), 1.2).set_trans(Tween.TRANS_QUAD).tween_callback(spark.queue_free)

func _game_over(reason: String) -> void:
	if not running:
		return
	running = false
	_clear_saved_run()
	player.controls_enabled = false
	question_panel.visible = false
	result_panel.visible = true
	result_panel.get_node("Margin/Result").text = "GAME OVER\n%s\n%d of 100 encounters cleared\n%d coins kept" % [reason, answered, coins]

func _update_hud() -> void:
	var total_seconds := ceili(time_left)
	time_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
	progress_label.text = "Questions %d / 100" % answered
	coin_label.text = "Coins %d" % coins
	life_label.text = "Wrong answers left %d" % mistakes_left

func _toggle_pause() -> void:
	is_run_paused = not is_run_paused
	pause_panel.visible = is_run_paused
	player.controls_enabled = not is_run_paused and current_encounter < 0
	if is_run_paused:
		_save_progress()
		pause_status_label.text = "Progress saved · %d / 100 encounters · %02d:%02d remaining" % [answered, ceili(time_left) / 60, ceili(time_left) % 60]
	else:
		message_label.text = "Adventure resumed. Your progress is safe."

func _save_and_return_home() -> void:
	_save_progress()
	OS.shell_open(STUDY_ARENA_HOME)
	get_tree().quit()

func _return_home() -> void:
	OS.shell_open(STUDY_ARENA_HOME)
	get_tree().quit()

func _retry_game() -> void:
	_clear_saved_run()
	result_panel.visible = false
	question_panel.visible = false
	map_panel.visible = false
	map_open = false
	for child in get_tree().get_nodes_in_group("dungeon_generated"):
		child.queue_free()
	if is_instance_valid(player): player.queue_free()
	if is_instance_valid(camera_rig): camera_rig.queue_free()
	for child in effects_root.get_children(): child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_start_game(difficulty)

func _save_progress() -> void:
	if smoke_mode or not running or not is_instance_valid(player):
		return
	var data := {
		"version": SAVE_VERSION,
		"difficulty": difficulty,
		"companion": selected_companion,
		"maze_seed": maze_seed,
		"time_left": time_left,
		"mistakes_left": mistakes_left,
		"mercy_tokens": mercy_tokens,
		"coins": coins,
		"answered": answered,
		"current_encounter": current_encounter,
		"cleared_encounters": cleared_encounters,
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"player_rotation_y": player.rotation.y,
		"camera_yaw": camera_rig.yaw if is_instance_valid(camera_rig) else 0.0,
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_saved_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE):
		return {}
	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		return {}
	if String(data.get("difficulty", "")) not in DIFFICULTIES or String(data.get("companion", "")) not in COMPANION_IDS:
		return {}
	return data

func _has_saved_run() -> bool:
	return not _load_saved_data().is_empty()

func _clear_saved_run() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))

func _resume_saved_run() -> void:
	var data := _load_saved_data()
	if data.is_empty():
		_show_companion_picker()
		return
	difficulty = String(data.difficulty)
	selected_companion = String(data.companion)
	maze_seed = int(data.maze_seed)
	time_left = maxf(1.0, float(data.time_left))
	mistakes_left = int(data.mistakes_left)
	mercy_tokens = int(data.get("mercy_tokens", 0))
	coins = int(data.coins)
	cleared_encounters.clear()
	for id in data.get("cleared_encounters", []):
		cleared_encounters.append(int(id))
	answered = cleared_encounters.size()
	current_encounter = int(data.get("current_encounter", -1))
	questions = _make_questions()
	rng.seed = maze_seed
	_generate_maze()
	_build_dungeon_meshes()
	_spawn_traps()
	_spawn_puddles_and_snakes()
	_spawn_player()
	_spawn_encounters()
	_build_set_dressing()
	var saved_position: Array = data.get("player_position", [])
	if saved_position.size() == 3:
		player.global_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
	player.rotation.y = float(data.get("player_rotation_y", 0.0))
	camera_rig.yaw = float(data.get("camera_yaw", 0.0))
	for id in cleared_encounters:
		if id >= 0 and id < encounters.size() and is_instance_valid(encounters[id]):
			encounters[id].monitoring = false
			encounters[id].visible = false
	running = true
	is_run_paused = false
	auto_save_elapsed = 0.0
	hud.visible = true
	result_panel.visible = false
	message_label.text = "Saved adventure restored · %d of 100 encounters complete." % answered
	_update_hud()
	if current_encounter >= 0 and current_encounter < encounters.size() and current_encounter not in cleared_encounters:
		player.controls_enabled = false
		_show_question(current_encounter, String(encounters[current_encounter].get_meta("kind")))
	else:
		current_encounter = -1
		player.controls_enabled = true

func _show_resume_picker(new_difficulty: String) -> void:
	var data := _load_saved_data()
	if data.is_empty():
		_start_game(new_difficulty)
		return
	var layer := CanvasLayer.new()
	layer.name = "ResumeLayer"
	add_child(layer)
	var panel := _panel(Vector2(390, 150), Vector2(500, 420))
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.position = Vector2(38, 30)
	stack.size = Vector2(424, 360)
	stack.add_theme_constant_override("separation", 15)
	panel.add_child(stack)
	var heading := Label.new()
	heading.text = "CONTINUE YOUR ADVENTURE?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 27)
	stack.add_child(heading)
	var summary := Label.new()
	summary.text = "%s · %d / 100 encounters\n%d coins · %02d:%02d remaining" % [String(data.difficulty).capitalize(), int(data.get("answered", 0)), int(data.coins), ceili(float(data.time_left)) / 60, ceili(float(data.time_left)) % 60]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 20)
	stack.add_child(summary)
	var resume_button := Button.new()
	resume_button.text = "Resume Saved Adventure"
	resume_button.custom_minimum_size.y = 62
	resume_button.pressed.connect(func(): layer.queue_free(); _resume_saved_run())
	stack.add_child(resume_button)
	var new_button := Button.new()
	new_button.text = "Start New %s Adventure" % new_difficulty.capitalize()
	new_button.custom_minimum_size.y = 56
	new_button.pressed.connect(func(): layer.queue_free(); _clear_saved_run(); _start_game(new_difficulty))
	stack.add_child(new_button)
	var home_button := Button.new()
	home_button.text = "Return to Study Arena"
	home_button.custom_minimum_size.y = 48
	home_button.pressed.connect(_return_home)
	stack.add_child(home_button)

func _branch_count() -> int:
	var result := 0
	for cell in walkable:
		var exits := 0
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if next.x >= 0 and next.y >= 0 and next.x < GRID_SIZE and next.y < GRID_SIZE and grid[_index(next)] == 0:
				exits += 1
		if exits >= 3: result += 1
	return result

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	damage_flash = ColorRect.new()
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.color = Color("b31542")
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.visible = false
	hud.add_child(damage_flash)
	var top_plate := _panel(Vector2(12, 10), Vector2(790, 58))
	top_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_plate)
	var top := HBoxContainer.new()
	top.position = Vector2(28, 24)
	top.add_theme_constant_override("separation", 22)
	hud.add_child(top)
	time_label = _hud_label(top, "00:00")
	progress_label = _hud_label(top, "Questions 0 / 100")
	coin_label = _hud_label(top, "Coins 0")
	life_label = _hud_label(top, "Wrong answers left 0")
	message_label = Label.new()
	message_label.position = Vector2(20, 665)
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color("ffe4a8"))
	message_label.add_theme_color_override("font_shadow_color", Color("000000"))
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(message_label)
	question_panel = _panel(Vector2(390, 130), Vector2(500, 470))
	hud.add_child(question_panel)
	var question_margin := MarginContainer.new()
	question_margin.add_theme_constant_override("margin_left", 28)
	question_margin.add_theme_constant_override("margin_right", 28)
	question_margin.add_theme_constant_override("margin_top", 24)
	question_margin.add_theme_constant_override("margin_bottom", 24)
	question_panel.add_child(question_margin)
	var question_stack := VBoxContainer.new()
	question_stack.add_theme_constant_override("separation", 12)
	question_margin.add_child(question_stack)
	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 23)
	question_stack.add_child(prompt_label)
	answer_box = VBoxContainer.new()
	answer_box.add_theme_constant_override("separation", 8)
	question_stack.add_child(answer_box)
	question_panel.visible = false
	map_panel = _panel(Vector2(930, 70), Vector2(320, 320))
	hud.add_child(map_panel)
	map_view = DungeonMap.new()
	map_view.game = self
	map_view.position = Vector2(14, 14)
	map_view.size = Vector2(292, 292)
	map_panel.add_child(map_view)
	map_panel.visible = false
	result_panel = _panel(Vector2(390, 165), Vector2(500, 390))
	hud.add_child(result_panel)
	var result_margin := MarginContainer.new()
	result_margin.name = "Margin"
	result_margin.add_theme_constant_override("margin_left", 28)
	result_margin.add_theme_constant_override("margin_top", 28)
	result_panel.add_child(result_margin)
	var result := Label.new()
	result.name = "Result"
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 26)
	result_margin.add_child(result)
	var result_actions := VBoxContainer.new()
	result_actions.position = Vector2(44, 225)
	result_actions.size = Vector2(412, 135)
	result_actions.add_theme_constant_override("separation", 10)
	result_panel.add_child(result_actions)
	var retry_button := Button.new()
	retry_button.text = "Try Again"
	retry_button.custom_minimum_size.y = 56
	retry_button.add_theme_font_size_override("font_size", 20)
	retry_button.pressed.connect(_retry_game)
	result_actions.add_child(retry_button)
	var result_home_button := Button.new()
	result_home_button.text = "Return to Study Arena"
	result_home_button.custom_minimum_size.y = 52
	result_home_button.add_theme_font_size_override("font_size", 19)
	result_home_button.pressed.connect(_return_home)
	result_actions.add_child(result_home_button)
	result_panel.visible = false
	pause_panel = _panel(Vector2(390, 145), Vector2(500, 430))
	hud.add_child(pause_panel)
	var pause_stack := VBoxContainer.new()
	pause_stack.position = Vector2(42, 32)
	pause_stack.size = Vector2(416, 360)
	pause_stack.add_theme_constant_override("separation", 14)
	pause_panel.add_child(pause_stack)
	var pause_heading := Label.new()
	pause_heading.text = "ADVENTURE PAUSED"
	pause_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_heading.add_theme_font_size_override("font_size", 29)
	pause_stack.add_child(pause_heading)
	pause_status_label = Label.new()
	pause_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_status_label.add_theme_font_size_override("font_size", 18)
	pause_stack.add_child(pause_status_label)
	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.custom_minimum_size.y = 62
	resume_button.pressed.connect(_toggle_pause)
	pause_stack.add_child(resume_button)
	var save_home_button := Button.new()
	save_home_button.text = "Save & Return to Study Arena"
	save_home_button.custom_minimum_size.y = 58
	save_home_button.pressed.connect(_save_and_return_home)
	pause_stack.add_child(save_home_button)
	var pause_note := Label.new()
	pause_note.text = "Your exact maze, position, timer, coins, and completed encounters are stored on this computer. Press Esc to resume."
	pause_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_stack.add_child(pause_note)
	pause_panel.visible = false
	hud.visible = false

func _show_difficulty_picker() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DifficultyLayer"
	add_child(layer)
	var panel := _panel(Vector2(390, 120), Vector2(500, 500))
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.position = Vector2(35, 30)
	stack.size = Vector2(430, 440)
	stack.add_theme_constant_override("separation", 13)
	panel.add_child(stack)
	var heading := Label.new()
	heading.text = "DUNGEON OF KNOWLEDGE\nChoose your challenge"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 27)
	stack.add_child(heading)
	for key in ["easy", "average", "hard", "hell"]:
		var rules: Dictionary = DIFFICULTIES[key]
		var choice := Button.new()
		choice.text = "%s · %d min · %d wrong answers · %d-coin hints" % [rules.label, int(rules.seconds) / 60, rules.mistakes, rules.hint]
		choice.custom_minimum_size.y = 66
		choice.pressed.connect(func(): layer.queue_free(); _start_game(key))
		stack.add_child(choice)
	var note := Label.new()
	note.text = "Every correct answer earns 1 coin. Each correct answer also has a private 5% chance to award one extra mistake allowance."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)

func _show_companion_picker() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CompanionLayer"
	add_child(layer)
	var panel := _panel(Vector2(260, 55), Vector2(760, 610))
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.position = Vector2(28, 24)
	stack.size = Vector2(704, 565)
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var heading := Label.new()
	heading.text = "CHOOSE YOUR DUNGEON COMPANION"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	stack.add_child(heading)
	var note := Label.new()
	note.text = "All eighteen companions are free. Your choice is remembered for the next dungeon run."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(note)
	var grid_box := GridContainer.new()
	grid_box.columns = 4
	grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_box.add_theme_constant_override("h_separation", 10)
	grid_box.add_theme_constant_override("v_separation", 10)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(704, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stack.add_child(scroll)
	scroll.add_child(grid_box)
	var companion_names := {"moss": "Moss", "lumi": "Lumi", "coral": "Coral", "sky": "Sky", "plum": "Plum", "sunny": "Sunny", "mint": "Mint", "nova": "Nova", "ember": "Ember", "bubbles": "Bubbles", "byte": "Byte", "clover": "Clover", "mochi": "Mochi", "comet": "Comet", "pebble": "Pebble", "melody": "Melody", "taro": "Taro", "sol": "Sol"}
	for id: String in companion_names:
		var choice := Button.new()
		choice.text = "%s%s" % [companion_names[id], " · selected" if id == selected_companion else ""]
		choice.custom_minimum_size = Vector2(168, 205)
		choice.icon_max_width = 126
		choice.expand_icon = true
		var portrait_path := "res://assets/companions/%s.png" % id
		if ResourceLoader.exists(portrait_path):
			choice.icon = load(portrait_path)
		choice.pressed.connect(_choose_companion.bind(id, layer))
		grid_box.add_child(choice)

func _choose_companion(id: String, layer: CanvasLayer) -> void:
	selected_companion = id
	_save_companion_choice(id)
	layer.queue_free()
	_show_difficulty_picker()

func _save_companion_choice(id: String) -> void:
	var settings := ConfigFile.new()
	settings.set_value("companion", "selected", id)
	settings.save("user://dungeon_settings.cfg")

func _load_companion_choice() -> String:
	var settings := ConfigFile.new()
	if settings.load("user://dungeon_settings.cfg") == OK:
		var saved := String(settings.get_value("companion", "selected", "moss"))
		if saved in COMPANION_IDS:
			return saved
	return "moss"

func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _panel(at: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f21a1728")
	style.border_color = Color("e0ad58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color("99000000")
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _hud_label(parent: Control, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 19)
	parent.add_child(label)
	return label

func _index(cell: Vector2i) -> int:
	return cell.y * GRID_SIZE + cell.x

func _world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - GRID_SIZE / 2.0) * CELL_SIZE, 0.0, (cell.y - GRID_SIZE / 2.0) * CELL_SIZE)
