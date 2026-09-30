extends Node3D
## Study Arena: Dungeon of Knowledge — first-person crawl through a KayKit stone maze.
## Signed-in runs are authoritative on the Study Arena server (questions, answers, coins);
## without a run ticket the game plays an offline practice run whose coins are not saved.

const CELL_SIZE := 4.0
const WALL_HEIGHT := 4.0
const SAVE_FILE := "user://dungeon_progress.json"
const SETTINGS_FILE := "user://dungeon_settings.cfg"
const SAVE_VERSION := 3
const STUDY_ARENA_HOME := "http://localhost:8080/#home"
const COMPANION_IDS := ["moss", "lumi", "coral", "sky", "plum", "sunny", "mint", "nova", "ember", "bubbles", "byte", "clover", "mochi", "comet", "pebble", "melody", "taro", "sol"]
## Question count drives the maze: grid (odd, in 4 m cells), chambers and hazards all scale
## with it so every run is a compact crawl rather than a long walk. Runs are capped at 50.
const MAX_QUESTIONS := 50
const DIFFICULTIES := {
	"easy": {"label": "Easy", "questions": 20, "grid": 15, "rooms": 2, "seconds": 480, "mistakes": 5, "hint": 2, "trap": 10, "serpent": 8, "traps": 6, "serpents": 3, "puddles": 6, "boosts": 6, "npc": 0.34, "enemies": [3, 3, 2, 2, 0, 1]},
	"average": {"label": "Average", "questions": 30, "grid": 17, "rooms": 3, "seconds": 720, "mistakes": 5, "hint": 3, "trap": 15, "serpent": 10, "traps": 9, "serpents": 4, "puddles": 8, "boosts": 7, "npc": 0.28, "enemies": [3, 2, 0, 1, 2, 3]},
	"hard": {"label": "Hard", "questions": 40, "grid": 19, "rooms": 4, "seconds": 960, "mistakes": 4, "hint": 4, "trap": 20, "serpent": 14, "traps": 12, "serpents": 5, "puddles": 10, "boosts": 8, "npc": 0.22, "enemies": [0, 1, 2, 3, 0, 1]},
	"hell": {"label": "Hell", "questions": 50, "grid": 21, "rooms": 5, "seconds": 1200, "mistakes": 3, "hint": 5, "trap": 30, "serpent": 20, "traps": 16, "serpents": 6, "puddles": 12, "boosts": 8, "npc": 0.16, "enemies": [0, 1, 0, 1, 2, 1]},
}
const BOOSTS := {
	"swift": {"label": "Swiftness Draught", "short": "Swift", "color": Color("7dff76"), "seconds": 30.0, "text": "+40% move speed for 30 s"},
	"ward": {"label": "Bone Ward", "short": "Ward", "color": Color("68dbff"), "seconds": 0.0, "text": "blocks the next trap or serpent"},
	"sight": {"label": "Scholar's Lens", "short": "Lens", "color": Color("c58bff"), "seconds": 60.0, "text": "traps and relics shown on your map for 60 s"},
	"spring": {"label": "Spring Step", "short": "Spring", "color": Color("ffd36d"), "seconds": 30.0, "text": "higher jumps for 30 s"},
	"radiance": {"label": "Radiant Lantern", "short": "Light", "color": Color("ffb35c"), "seconds": 60.0, "text": "your lantern lights twice as far for 60 s"},
	"time": {"label": "Hourglass Shard", "short": "Time", "color": Color("edc383"), "seconds": 0.0, "text": "+45 seconds on the clock"},
}
const BOOST_ORDER := ["swift", "ward", "sight", "spring", "radiance", "time"]
const ROOM_TYPES := ["crypt", "library", "treasure", "shrine", "armory"]
const TRAP_TYPES := ["spikes", "flame", "poison", "rune"]
const CAPTIONS := {"boost": "[A relic hums with power]", "rattle": "[Bones rattle nearby]", "trap": "[A trap mechanism clanks]", "hit": "[You take a hit]", "spell": "[Your staff crackles with a spell]", "chime": "[Bright chime — correct]", "wrong": "[Low buzz — wrong answer]", "portal": "[The victory portal hums]"}
# Study Arena dark-theme tokens (web/tokens.css) used by the dungeon HUD.
const C_CARD := Color("20322aee")
const C_CARD_SOLID := Color("20322a")
const C_INK := Color("edf1e7")
const C_MUTED := Color("b5c4b9")
const C_SAGE := Color("b8d6ae")
const C_ON_SAGE := Color("193322")
const C_BORDER := Color("40533f")
const C_SOFT := Color("2b4033")
const C_PEACH := Color("524432")
const C_DANGER := Color("ffa99f")
const C_FOCUS := Color("edc383")

var rng := RandomNumberGenerator.new()
var grid_size := 15
var encounter_count := 20
var grid := PackedByteArray()
var walkable: Array[Vector2i] = []
var rooms: Array[Dictionary] = []
var entrance_cell := Vector2i(1, 1)
var entrance_dir := Vector2i(0, -1)
var exit_cell := Vector2i(grid_size - 2, grid_size - 2)
var exit_dir := Vector2i(0, 1)
var encounters: Array[Node3D] = []
var questions: Array[Dictionary] = []
var player: FirstPersonController
var pet: PlayerAvatar
var kit: DungeonKit
var audio: AudioDirector
var run_client: RunClient
var difficulty := "easy"
var time_left := 0.0
var mistakes_left := 0
var mercy_tokens := 0
var coins := 0
var correct_count := 0
var current_encounter := -1
var running := false
var is_run_paused := false
var awaiting_server := false
var feedback_pending := false
var exit_open := false
var auto_save_elapsed := 0.0
var proximity_clock := 0.0
var maze_seed := 0
var resolved_encounters: Array[int] = []
var triggered_traps: Array[int] = []
var triggered_snakes: Array[int] = []
var traps_revealed_until := 0.0
var collected_boosts: Array[int] = []
var active_buffs := {}
var ward_charges := 0
var buff_row: HBoxContainer
var buff_chips := {}
var death_fade: ColorRect
var smoke_mode := false
var map_open := false
var selected_companion := "moss"
var linked := false
var launch_difficulty := ""
var settings := {"sensitivity": 1.0, "touch_sensitivity": 1.0, "touch_size": 1.0, "invert_y": false, "fov": 74.0, "reduced_motion": false, "captions": true, "quality": "high", "volume": 0.8}
var world_env: Environment
var effects_root: Node3D
var hud: Control
var time_label: Label
var difficulty_chip: Label
var progress_label: Label
var progress_bar: ProgressBar
var coin_label: Label
var life_label: Label
var practice_badge: PanelContainer
var toast_label: Label
var caption_label: Label
var crosshair: Control
var look_hint: Label
var question_panel: PanelContainer
var question_title: Label
var question_meta: Label
var prompt_label: Label
var answer_grid: GridContainer
var answer_buttons: Array[Button] = []
var hint_button: Button
var feedback_label: Label
var continue_button: Button
var map_panel: PanelContainer
var map_view: DungeonMap
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var retry_button: Button
var pause_panel: PanelContainer
var pause_status_label: Label
var loading_panel: PanelContainer
var loading_label: Label
var post_fx: ShaderMaterial
var mobile_controls: MobileControls
var damage_amount := 0.0
var heal_amount := 0.0
var toast_clock := 0.0
var caption_clock := 0.0
var exit_area: Area3D
var arch: Node3D

func _ready() -> void:
	get_tree().auto_accept_quit = false
	rng.randomize()
	_load_settings()
	selected_companion = _load_companion_choice()
	var launch_companion := _argument_value("--companion=")
	if launch_companion in COMPANION_IDS:
		selected_companion = launch_companion
		_save_companion_choice(selected_companion)
	launch_difficulty = _argument_value("--difficulty=")
	audio = AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	audio.sound_played.connect(_on_sound_played)
	run_client = RunClient.new()
	run_client.name = "RunClient"
	add_child(run_client)
	run_client.configure(_argument_value("--api="), _argument_value("--run="), _argument_value("--ticket="))
	linked = run_client.is_linked()
	_build_environment()
	_build_ui()
	mobile_controls = MobileControls.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.game = self
	hud.get_parent().add_child(mobile_controls)
	# Phones show the 720-unit-tall interface only a few centimetres high; enlarge menus,
	# questions and HUD text when touch controls are active (visible is decided in their _ready).
	if mobile_controls.visible:
		get_window().content_scale_factor = 1.3
	_apply_settings()
	smoke_mode = "--smoke" in OS.get_cmdline_user_args()
	var shot_dir := _argument_value("--screenshots=")
	if not shot_dir.is_empty() and not OS.has_feature("web"):
		linked = false
		call_deferred("_capture_screenshots", shot_dir)
	elif "--size-report" in OS.get_cmdline_user_args():
		call_deferred("_size_report")
	elif smoke_mode:
		linked = false
		call_deferred("_smoke_test")
	elif linked and "--linked-smoke" in OS.get_cmdline_user_args():
		call_deferred("_linked_smoke")
	elif linked:
		call_deferred("_start_linked_run")
	elif _has_saved_run():
		_show_resume_picker(launch_difficulty if launch_difficulty in DIFFICULTIES else "easy")
	elif launch_difficulty in DIFFICULTIES:
		call_deferred("_start_game", launch_difficulty)
	else:
		_show_companion_picker()

# ---------------------------------------------------------------- smoke test
func _smoke_test() -> void:
	_start_game("easy")
	await get_tree().process_frame
	assert(questions.size() == encounter_count)
	assert(encounters.size() == encounter_count)
	assert(get_tree().get_nodes_in_group("dungeon_kit").size() >= 20)
	assert(kit.torch_sockets.size() >= 6)
	assert(_branch_count() >= 4)
	assert(grid_size == int(DIFFICULTIES.easy.grid) and encounter_count == int(DIFFICULTIES.easy.questions))
	assert(walkable.size() >= encounter_count + _hazard_cells())
	assert(rooms.size() >= 1)
	assert(get_tree().get_nodes_in_group("puddle").size() == int(DIFFICULTIES.easy.puddles))
	assert(get_tree().get_nodes_in_group("snake").size() == int(DIFFICULTIES.easy.serpents))
	assert(get_tree().get_nodes_in_group("trap").size() == int(DIFFICULTIES.easy.traps))
	assert(player is FirstPersonController and player.camera.current)
	assert(is_instance_valid(pet) and pet.left_arm.mesh is CapsuleMesh)
	assert(kit.get_node_or_null("EntrancePortal") != null and kit.get_node_or_null("VictoryArch/MagicPortal") != null)
	assert(is_instance_valid(pause_panel) and is_instance_valid(question_panel))
	# Spawn the nearest actors and check a real 3D skeleton / adventurer loaded.
	_update_proximity(true)
	var actors := get_tree().get_nodes_in_group("dungeon_actor")
	assert(actors.size() >= 1)
	var sample: DungeonActor = actors[0]
	assert(sample.anim != null and sample.model.find_child("Skeleton3D", true, false) != null)
	# Answer one question correctly and one wrongly through the real flow.
	_open_encounter(0)
	var right := int(questions[0].answer_index)
	await _submit_answer(right)
	assert(correct_count == 1 and coins == 1 and resolved_encounters.has(0))
	_continue_after_feedback()
	_open_encounter(1)
	var wrong := (int(questions[1].answer_index) + 1) % (questions[1].options as Array).size()
	var before := mistakes_left
	await _submit_answer(wrong)
	assert(mistakes_left == before - 1 and resolved_encounters.has(1))
	_continue_after_feedback()
	var hint_id := 2
	while (questions[hint_id].options as Array).size() < 3:
		hint_id += 1
	_open_encounter(hint_id)
	coins = 10
	await _use_hint()
	assert((questions[hint_id].removed as Array).size() == 2 and coins == 10 - int(DIFFICULTIES.easy.hint))
	_continue_after_feedback()
	_close_question()
	var boosts := get_tree().get_nodes_in_group("boost")
	assert(boosts.size() == int(DIFFICULTIES.easy.boosts))
	var by_kind := {}
	for boost in boosts:
		if not by_kind.has(boost.get_meta("boost")): by_kind[boost.get_meta("boost")] = boost
	assert(by_kind.has("swift") and by_kind.has("ward") and by_kind.has("time"))
	_collect_boost(by_kind.swift)
	assert(player.speed_multiplier > 1.0 and active_buffs.has("swift"))
	_collect_boost(by_kind.ward)
	assert(ward_charges == 1)
	var clock := time_left
	_collect_boost(by_kind.time)
	assert(is_equal_approx(time_left, clock + 45.0))
	clock = time_left
	var sample_trap: Area3D = get_tree().get_nodes_in_group("trap")[0]
	_on_trap_entered(player, sample_trap)
	assert(ward_charges == 0 and is_equal_approx(time_left, clock))
	_tick_buffs(31.0)
	assert(is_equal_approx(player.speed_multiplier, 1.0) and not active_buffs.has("swift"))
	var dying := DungeonActor.new()
	dying.configure("enemy", 0, player, 999)
	add_child(dying)
	dying.defeat()
	await get_tree().create_timer(0.2).timeout
	assert(dying.defeated and get_tree().get_nodes_in_group("dungeon_generated").size() > 0)
	print("DUNGEON_SMOKE_PASS boosts=%d buffs=ok ward=ok death_fx=ok first_person=true encounters=%d actors_3d=%d kit_batches=%d torches=%d rooms=%d traps=%d serpents=%d grid=%d branches=%d" % [boosts.size(), encounters.size(), actors.size(), get_tree().get_nodes_in_group("dungeon_kit").size(), kit.torch_sockets.size(), rooms.size(), get_tree().get_nodes_in_group("trap").size(), get_tree().get_nodes_in_group("snake").size(), grid_size, _branch_count()])
	get_tree().quit()

## Developer check: maze capacity, chambers and exit distance per difficulty over 40 seeds.
func _size_report() -> void:
	for key in ["easy", "average", "hard", "hell"]:
		difficulty = key
		var rules: Dictionary = DIFFICULTIES[key]
		var min_walk := 9999
		var min_rooms := 99
		var path_total := 0
		for seed_value in 40:
			rng.seed = seed_value * 7919 + 17
			_configure_size(int(rules.questions))
			_generate_maze()
			min_walk = mini(min_walk, walkable.size())
			min_rooms = mini(min_rooms, rooms.size())
			path_total += int(_distances_from(entrance_cell).get(exit_cell, 0))
		var needed := encounter_count + _hazard_cells()
		print("SIZE %s questions=%d grid=%d (%dm) walkable_min=%d needed=%d rooms_min=%d/%d exit_path_avg=%.0f cells (%.0fm)" % [key, encounter_count, grid_size, grid_size * int(CELL_SIZE), min_walk, needed, min_rooms, int(rules.rooms), path_total / 40.0, path_total / 40.0 * CELL_SIZE])
		assert(min_walk >= needed)
	get_tree().quit()

## End-to-end check against a local Study Arena demo server with a real run ticket.
func _linked_smoke() -> void:
	await _start_linked_run()
	assert(running and questions.size() == encounter_count and int(questions[0].answer_index) == -1)
	assert(encounters.size() == encounter_count and grid_size == int(DIFFICULTIES[difficulty].grid))
	print("LINKED size: questions=%d grid=%d" % [encounter_count, grid_size])
	await get_tree().create_timer(1.7).timeout
	var first := 0
	while resolved_encounters.has(first): first += 1
	_open_encounter(first)
	await _submit_answer(0)
	assert(resolved_encounters.has(first) and feedback_pending)
	print("LINKED answer: ", feedback_label.text.split("
")[0], " coins=", coins, " mistakes_left=", mistakes_left)
	_continue_after_feedback()
	var second := first + 1
	while resolved_encounters.has(second) or (questions[second].options as Array).size() < 3: second += 1
	_open_encounter(second)
	await _use_hint()
	print("LINKED hint: ", feedback_label.text)
	_close_question()
	var resumed := await run_client.fetch_questions()
	var answered: Array[int] = []
	for index in resumed.data.get("state", {}).get("answered_indexes", []): answered.append(int(index))
	assert(answered.has(first))
	print("LINKED_SMOKE_PASS run_questions=%d server_answered=%s" % [questions.size(), str(answered)])
	get_tree().quit()

## Developer visual check: renders a few fixed views to PNG files, then quits.
func _capture_screenshots(dir: String) -> void:
	smoke_mode = true
	_start_game("average")
	var views: Array[Dictionary] = []
	var corridor := entrance_cell
	views.append({"name": "01_entrance", "at": _world(entrance_cell), "look": _world(entrance_cell) + Vector3(0, 0, 8)})
	var enemy_id := -1
	for i in encounters.size():
		if String(encounters[i].get_meta("kind")) == "enemy":
			enemy_id = i
			break
	var npc_id := -1
	for i in encounters.size():
		if String(encounters[i].get_meta("kind")) == "npc":
			npc_id = i
			break
	for id in [enemy_id, npc_id]:
		var cell: Vector2i = walkable[id]
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _is_open(cell + d) and _is_open(cell + d * 2):
				corridor = cell + d * 2
				break
		views.append({"name": "02_encounter_%d" % id, "at": _world(corridor), "look": _world(cell) + Vector3.UP * 1.0})
	for room: Dictionary in rooms.slice(0, 3):
		var center := _world(room.center)
		views.append({"name": "03_room_%s" % room.type, "at": center + Vector3(-5.0, 0, -5.0), "look": center + Vector3.UP * 0.6})
	for trap in get_tree().get_nodes_in_group("trap").slice(0, 2):
		var at: Vector3 = (trap as Node3D).global_position
		trap.monitoring = false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c := Vector2i(roundi(at.x / CELL_SIZE + grid_size / 2.0), roundi(at.z / CELL_SIZE + grid_size / 2.0)) + d
			if _is_open(c):
				views.append({"name": "04_trap_%s" % trap.get_meta("trap_type"), "at": _world(c), "look": at})
				break
	for boost in get_tree().get_nodes_in_group("boost").slice(0, 3):
		var at: Vector3 = (boost as Node3D).global_position
		boost.monitoring = false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c := Vector2i(roundi(at.x / CELL_SIZE + grid_size / 2.0), roundi(at.z / CELL_SIZE + grid_size / 2.0)) + d
			if _is_open(c):
				views.append({"name": "04b_relic_%s" % boost.get_meta("boost"), "at": _world(c), "look": at + Vector3.UP * 1.1})
				break
	for encounter in encounters:
		encounter.monitoring = false
	for view: Dictionary in views:
		player.global_position = view.at + Vector3.UP * 0.05
		var flat: Vector3 = view.look - player.global_position
		player.yaw = atan2(-flat.x, -flat.z)
		player.pitch = atan2(view.look.y - 1.62, Vector2(flat.x, flat.z).length())
		pet.global_position = player.global_position + Basis(Vector3.UP, player.yaw) * Vector3(1.15, 0, -2.3)
		_update_proximity(false)
		kit.light_clock = 0.0
		for f in 90:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir.path_join(view.name + ".png"))
		print("VIEW %s fps=%d draw_calls=%d objects=%d" % [view.name, Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	var close: Dictionary = views[1]
	player.global_position = close.at + Vector3.UP * 0.05
	pet.global_position = player.global_position + Vector3(1, 0, 0)
	_update_proximity(false)
	for f in 60: await get_tree().process_frame
	_open_encounter(enemy_id)
	for f in 40: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join("05_question.png"))
	await _submit_answer(int(questions[enemy_id].answer_index))
	question_panel.visible = false
	for shot in [["06_death_a_hit", 0.12], ["06_death_b_collapse", 0.75], ["06_death_c_bones", 0.45], ["06_death_d_dissolve", 0.55]]:
		await get_tree().create_timer(float(shot[1])).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join(String(shot[0]) + ".png"))
	question_panel.visible = true
	for f in 10: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join("06_feedback.png"))
	_continue_after_feedback()
	var npc_view: Dictionary = views[2]
	player.global_position = npc_view.at + Vector3.UP * 0.05
	_update_proximity(false)
	for f in 45: await get_tree().process_frame
	_open_encounter(npc_id)
	await _submit_answer((int(questions[npc_id].answer_index) + 1) % (questions[npc_id].options as Array).size())
	_continue_after_feedback()
	await get_tree().create_timer(1.3).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("06_retreat_purple.png"))
	var boosts := get_tree().get_nodes_in_group("boost")
	for i in 3:
		boosts[i].set_meta("spent", false)
		_collect_boost(boosts[i])
	map_panel.visible = true
	for f in 60: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join("07_map_after_slay.png"))
	_game_over("Screenshot check.", "lost")
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("08_player_falls.png"))
	await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("09_game_over.png"))
	print("SCREENSHOTS_DONE %d" % (views.size() + 9))
	get_tree().quit()

# ---------------------------------------------------------------- frame loop
func _process(delta: float) -> void:
	_update_post_fx(delta)
	if toast_clock > 0.0:
		toast_clock -= delta
		if toast_clock <= 0.0:
			create_tween().tween_property(toast_label, "modulate:a", 0.0, 0.4)
	if caption_clock > 0.0:
		caption_clock -= delta
		if caption_clock <= 0.0:
			caption_label.visible = false
	if not running or not is_instance_valid(player):
		return
	var nearest_torch := kit.update_lights(player.global_position, delta)
	audio.set_torch_proximity(1.0 - clampf(nearest_torch / 8.0, 0.0, 1.0))
	_update_pet(delta)
	proximity_clock -= delta
	if proximity_clock <= 0.0:
		proximity_clock = 0.25
		_update_proximity(false)
	look_hint.visible = not OS.has_feature("mobile") and not mobile_controls.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _ui_blocking()
	if is_run_paused:
		return
	time_left = maxf(0.0, time_left - delta)
	_tick_buffs(delta)
	auto_save_elapsed += delta
	if auto_save_elapsed >= 8.0:
		auto_save_elapsed = 0.0
		_save_progress()
	_update_hud()
	if time_left <= 0.0:
		_game_over("The dungeon clock reached zero.", "timeout")
	if Input.is_action_just_pressed("map"):
		map_open = not map_open
		map_panel.visible = map_open
	if map_open and is_instance_valid(map_view):
		map_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and running:
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if not question_panel.visible or is_run_paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if feedback_pending:
			if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
				_continue_after_feedback()
				get_viewport().set_input_as_handled()
		elif key >= KEY_1 and key <= KEY_4:
			var choice := key - KEY_1
			if choice < answer_buttons.size() and not answer_buttons[choice].disabled:
				_submit_answer(choice)
				get_viewport().set_input_as_handled()
		elif key == KEY_H and not hint_button.disabled:
			_use_hint()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if running:
			_save_progress()
		get_tree().quit()

func _ui_blocking() -> bool:
	return question_panel.visible or pause_panel.visible or result_panel.visible or loading_panel.visible or get_node_or_null("PickerLayer") != null

# ---------------------------------------------------------------- environment
func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world_env = Environment.new()
	world_env.background_mode = Environment.BG_COLOR
	world_env.background_color = Color("050408")
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color("4a4262")
	world_env.ambient_light_energy = 0.42
	world_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.tonemap_exposure = 1.05
	world_env.fog_enabled = true
	world_env.fog_light_color = Color("140f1c")
	world_env.fog_light_energy = 1.0
	world_env.fog_density = 0.055
	world_env.fog_sky_affect = 0.0
	world_env.glow_enabled = true
	world_env.glow_intensity = 0.9
	world_env.glow_strength = 1.1
	world_env.glow_bloom = 0.06
	world_env.glow_hdr_threshold = 0.9
	world_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	world_env.adjustment_enabled = true
	world_env.adjustment_contrast = 1.08
	world_env.adjustment_saturation = 1.06
	world.environment = world_env
	add_child(world)
	effects_root = Node3D.new()
	effects_root.name = "PooledEffects"
	add_child(effects_root)

# ---------------------------------------------------------------- run lifecycle
func _start_linked_run() -> void:
	difficulty = launch_difficulty if launch_difficulty in DIFFICULTIES else "easy"
	_show_loading("Opening your dungeon run…")
	var response := await run_client.fetch_questions()
	if not response.ok:
		_show_loading("Could not reach Study Arena (%s)." % response.error, true)
		return
	var data: Dictionary = response.data
	var list: Array = data.get("questions", [])
	if list.is_empty():
		_show_loading("This dungeon run has no questions yet.", true)
		return
	_configure_size(list.size())
	questions.clear()
	for item: Dictionary in list.slice(0, encounter_count):
		questions.append(_normalize_question(item, -1, ""))
	var state: Dictionary = data.get("state", {})
	var rules: Dictionary = DIFFICULTIES[difficulty]
	resolved_encounters.clear()
	for index in state.get("answered_indexes", []):
		resolved_encounters.append(int(index))
	coins = int(state.get("coins_awarded", 0))
	mistakes_left = maxi(1, int(rules.mistakes) - int(state.get("mistakes_used", 0)))
	loading_panel.visible = false
	maze_seed = _seed_from(run_client.run_id)
	var saved := _load_saved_data()
	var resume: bool = String(saved.get("run_id", "")) == run_client.run_id
	time_left = maxf(1.0, float(saved.time_left)) if resume else float(rules.seconds)
	triggered_traps.clear()
	triggered_snakes.clear()
	correct_count = int(saved.get("correct_count", 0)) if resume else 0
	if resume:
		for id in saved.get("triggered_traps", []): triggered_traps.append(int(id))
		for id in saved.get("triggered_snakes", []): triggered_snakes.append(int(id))
	_restore_boost_state(saved if resume else {})
	_build_run()
	if resume:
		_restore_pose(saved)
	_begin("Signed-in run · coins are saved to your Study Arena wallet.")

func _start_game(mode: String) -> void:
	if not smoke_mode:
		_clear_saved_run()
	difficulty = mode
	var rules: Dictionary = DIFFICULTIES[mode]
	time_left = float(rules.seconds)
	mistakes_left = int(rules.mistakes)
	mercy_tokens = 0
	coins = 0
	correct_count = 0
	resolved_encounters.clear()
	triggered_traps.clear()
	triggered_snakes.clear()
	_restore_boost_state({})
	maze_seed = rng.randi()
	_configure_size(int(rules.questions))
	questions = PracticeBank.build(maze_seed, encounter_count)
	for i in questions.size():
		questions[i] = _normalize_question(questions[i], int(questions[i].answer_index), String(questions[i].explanation))
	_build_run()
	_begin("%s practice dungeon begun. Resolve all %d encounters, then reach the Victory Arch." % [rules.label, encounter_count])

func _normalize_question(item: Dictionary, answer_index: int, explanation: String) -> Dictionary:
	var options: Array[String] = []
	for option in item.get("options", []):
		options.append(String(option))
	return {"prompt": String(item.get("prompt", "")), "options": options, "subject": String(item.get("subject", "Study")), "source": String(item.get("source", "practice")), "answer_index": answer_index, "explanation": explanation, "removed": []}

## Sets the question count and maze size for the current difficulty.
func _configure_size(question_count: int) -> void:
	var rules: Dictionary = DIFFICULTIES[difficulty]
	encounter_count = clampi(question_count, 1, MAX_QUESTIONS)
	grid_size = int(rules.grid)
	exit_cell = Vector2i(grid_size - 2, grid_size - 2)

## Walkable-cell slots: encounters first, then traps, serpents, puddles and relics.
func _slot(kind: String, i: int) -> Vector2i:
	var rules: Dictionary = DIFFICULTIES[difficulty]
	var offsets := {"trap": 0, "serpent": int(rules.traps), "puddle": int(rules.traps) + int(rules.serpents), "boost": int(rules.traps) + int(rules.serpents) + int(rules.puddles)}
	var index := encounter_count + int(offsets[kind]) + i
	return walkable[mini(index, walkable.size() - 1)]

func _hazard_cells() -> int:
	var rules: Dictionary = DIFFICULTIES[difficulty]
	return int(rules.traps) + int(rules.serpents) + int(rules.puddles) + int(rules.boosts)

func _build_run() -> void:
	_clear_world()
	is_run_paused = false
	auto_save_elapsed = 0.0
	current_encounter = -1
	exit_open = false
	rng.seed = maze_seed
	_generate_maze()
	_spawn_player()
	_spawn_encounters()
	_spawn_traps()
	_spawn_puddles_and_snakes()
	_spawn_boosts()
	kit = DungeonKit.new()
	kit.name = "DungeonKit"
	kit.setup(self, grid_size, CELL_SIZE, WALL_HEIGHT)
	kit.rooms = rooms
	kit.gate_cell = entrance_cell
	kit.gate_dir = entrance_dir
	# Keep hazard floors clear of clutter; encounter cells may still get wall-side props.
	for i in range(encounter_count, mini(walkable.size(), encounter_count + _hazard_cells())):
		kit.reserved[walkable[i]] = true
	kit.quality_high = settings.quality == "high"
	kit.reduced_motion = bool(settings.reduced_motion)
	add_child(kit)
	kit.build()
	arch = kit.build_gates(entrance_cell, entrance_dir, exit_cell, exit_dir)
	_set_portal_open(false)
	_build_collision()
	_build_exit_trigger()
	for id in resolved_encounters:
		if id >= 0 and id < encounters.size() and is_instance_valid(encounters[id]):
			encounters[id].queue_free()

func _begin(message: String) -> void:
	running = true
	death_fade.color.a = 0.0
	_apply_buffs()
	hud.visible = true
	practice_badge.visible = not linked
	result_panel.visible = false
	audio.listener_target = player
	audio.start()
	_update_hud()
	_toast(message, 5.0)
	if resolved_encounters.size() >= encounter_count:
		_open_exit()
	_capture_mouse()
	_save_progress()

func _clear_world() -> void:
	for child in get_tree().get_nodes_in_group("dungeon_generated"):
		child.queue_free()
	if is_instance_valid(kit): kit.queue_free()
	if is_instance_valid(player): player.queue_free()
	if is_instance_valid(pet): pet.queue_free()
	for child in effects_root.get_children(): child.queue_free()
	encounters.clear()

# ---------------------------------------------------------------- maze
func _generate_maze() -> void:
	grid.resize(grid_size * grid_size)
	grid.fill(1)
	var stack: Array[Vector2i] = [Vector2i(1, 1)]
	grid[_index(Vector2i(1, 1))] = 0
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var choices: Array[Vector2i] = []
		for direction: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var next: Vector2i = cell + direction
			if next.x > 0 and next.y > 0 and next.x < grid_size - 1 and next.y < grid_size - 1 and grid[_index(next)] == 1:
				choices.append(next)
		if choices.is_empty():
			stack.pop_back()
			continue
		var chosen: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
		grid[_index(Vector2i((cell.x + chosen.x) / 2, (cell.y + chosen.y) / 2))] = 0
		grid[_index(chosen)] = 0
		stack.append(chosen)
	# Extra joins create loops, alternate routes and genuine multi-way decisions.
	var loop_candidates: Array[Vector2i] = []
	for z in range(1, grid_size - 1):
		for x in range(1, grid_size - 1):
			var cell := Vector2i(x, z)
			if grid[_index(cell)] == 0: continue
			var horizontal := grid[_index(cell + Vector2i.LEFT)] == 0 and grid[_index(cell + Vector2i.RIGHT)] == 0
			var vertical := grid[_index(cell + Vector2i.UP)] == 0 and grid[_index(cell + Vector2i.DOWN)] == 0
			if horizontal or vertical: loop_candidates.append(cell)
	_shuffle(loop_candidates, 0)
	var joins := int(pow((grid_size - 1) / 2.0, 2.0) * 0.22)
	for i in mini(joins, loop_candidates.size()):
		grid[_index(loop_candidates[i])] = 0
	entrance_cell = Vector2i(1, 1)
	entrance_dir = Vector2i(0, -1)
	var distances := _distances_from(entrance_cell)
	exit_cell = entrance_cell
	var farthest := -1
	for key: Vector2i in distances:
		if int(distances[key]) > farthest:
			farthest = int(distances[key])
			exit_cell = key
	exit_dir = Vector2i.ZERO
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_open(exit_cell + d):
			exit_dir = d
			break
	# Carve themed chambers: crypt, library, treasure vault, candle shrine, armory.
	rooms.clear()
	var room_types: Array = ROOM_TYPES.duplicate()
	_shuffle(room_types, 0)
	var room_goal := mini(int(DIFFICULTIES[difficulty].rooms), ROOM_TYPES.size())
	var entrance_gap := mini(8, grid_size / 2)
	var attempts := 0
	while rooms.size() < room_goal and attempts < 400:
		attempts += 1
		var center := Vector2i(rng.randi_range(2, (grid_size - 3) / 2) * 2 - 1, rng.randi_range(2, (grid_size - 3) / 2) * 2 - 1)
		if center.x < 3 or center.y < 3 or center.x > grid_size - 4 or center.y > grid_size - 4: continue
		if _manhattan(center, entrance_cell) < entrance_gap or _manhattan(center, exit_cell) < 5: continue
		var clear := true
		for room: Dictionary in rooms:
			if _manhattan(center, room.center) < 7: clear = false
		if not clear: continue
		var rect := Rect2i(center - Vector2i.ONE, Vector2i(3, 3))
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				grid[_index(Vector2i(x, z))] = 0
		rooms.append({"center": center, "rect": rect, "type": room_types[rooms.size()]})
	walkable.clear()
	for z in grid_size:
		for x in grid_size:
			var c := Vector2i(x, z)
			if grid[_index(c)] == 0 and c != entrance_cell and c != exit_cell and not _in_room(c) and _manhattan(c, entrance_cell) > 1:
				walkable.append(c)
	_shuffle(walkable, 0)

func _distances_from(start: Vector2i) -> Dictionary:
	var result := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if _is_open(n) and not result.has(n):
				result[n] = int(result[c]) + 1
				queue.append(n)
	return result

func _in_room(c: Vector2i) -> bool:
	for room: Dictionary in rooms:
		if (room.rect as Rect2i).has_point(c): return true
	return false

func _shuffle(list: Array, from: int) -> void:
	for i in range(list.size() - 1, from, -1):
		var j := rng.randi_range(from, i)
		var temp = list[i]
		list[i] = list[j]
		list[j] = temp

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "DungeonCollision"
	body.collision_layer = 1
	body.add_to_group("dungeon_generated")
	add_child(body)
	var ground_node := CollisionShape3D.new()
	var ground := BoxShape3D.new()
	ground.size = Vector3(grid_size * CELL_SIZE, 0.2, grid_size * CELL_SIZE)
	ground_node.shape = ground
	ground_node.position = Vector3(-CELL_SIZE * 0.5, -0.1, -CELL_SIZE * 0.5)
	body.add_child(ground_node)
	var ceiling_node := CollisionShape3D.new()
	ceiling_node.shape = ground
	ceiling_node.position = ground_node.position + Vector3.UP * (WALL_HEIGHT + 0.2)
	body.add_child(ceiling_node)
	# Wall meshes sit on cell edges and are 1 m thick, so solid cells grow by half a metre.
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(CELL_SIZE + 1.0, WALL_HEIGHT, CELL_SIZE + 1.0)
	for z in grid_size:
		for x in grid_size:
			var c := Vector2i(x, z)
			if _is_open(c): continue
			var touches := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _is_open(c + d): touches = true
			if not touches: continue
			var shape_node := CollisionShape3D.new()
			shape_node.shape = wall_shape
			shape_node.position = _world(c) + Vector3.UP * WALL_HEIGHT * 0.5
			body.add_child(shape_node)

# ---------------------------------------------------------------- player & companion
func _spawn_player() -> void:
	player = FirstPersonController.new()
	player.name = "Player"
	player.position = _world(entrance_cell) + Vector3.UP * 0.05
	add_child(player)
	player.yaw = PI if entrance_dir == Vector2i(0, -1) else 0.0
	player.footstep.connect(_on_footstep)
	pet = PlayerAvatar.new()
	pet.name = "Companion"
	pet.companion_id = selected_companion
	pet.scale = Vector3.ONE * 0.27
	add_child(pet)
	pet.collision_layer = 0
	pet.collision_mask = 0
	pet.set_physics_process(false)
	pet.global_position = player.global_position + Vector3(0.8, 0, 0.8)
	_apply_settings()

func _update_pet(delta: float) -> void:
	if not is_instance_valid(pet):
		return
	var basis := Basis(Vector3.UP, player.yaw)
	var target := player.global_position + basis * Vector3(1.15, 0.0, -2.3)
	target.y = 0.0
	var before := pet.global_position
	pet.global_position = pet.global_position.lerp(target, 1.0 - exp(-delta * 4.5))
	var travel := pet.global_position - before
	travel.y = 0.0
	var speed := travel.length() / maxf(delta, 0.0001)
	if speed > 0.3:
		pet.rotation.y = lerp_angle(pet.rotation.y, atan2(-travel.x, -travel.z), 1.0 - exp(-delta * 10.0))
	elif not pet.action_locked:
		pet.rotation.y = lerp_angle(pet.rotation.y, player.yaw, 1.0 - exp(-delta * 3.0))
	pet._animate_body(delta, clampf(speed / 6.0, 0.0, 1.0), speed > 4.5)

func _on_footstep(running_step: bool) -> void:
	var splash := false
	for puddle in get_tree().get_nodes_in_group("puddle"):
		if (puddle as Node3D).global_position.distance_to(player.global_position) < 1.4:
			splash = true
	if splash:
		audio.play("drip", 0.55, -2.0)
	audio.play("step_run" if running_step else "step", randf_range(0.9, 1.1), -6.0)

# ---------------------------------------------------------------- encounters
func _spawn_encounters() -> void:
	encounters.clear()
	var rules: Dictionary = DIFFICULTIES[difficulty]
	var enemy_mix: Array = rules.enemies
	for i in encounter_count:
		var encounter := Area3D.new()
		encounter.name = "Encounter_%03d" % (i + 1)
		encounter.collision_layer = 4
		encounter.collision_mask = 2
		encounter.position = _world(walkable[i])
		encounter.set_meta("encounter_id", i)
		var npc := rng.randf() < float(rules.npc)
		encounter.set_meta("kind", "npc" if npc else "enemy")
		encounter.set_meta("style", rng.randi_range(0, 2) if npc else int(enemy_mix[rng.randi_range(0, enemy_mix.size() - 1)]))
		var shape_node := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 1.9
		shape_node.shape = shape
		shape_node.position.y = 0.9
		encounter.add_child(shape_node)
		encounter.body_entered.connect(_on_encounter_body_entered.bind(encounter))
		encounter.add_to_group("dungeon_generated")
		add_child(encounter)
		encounters.append(encounter)

## Streams 3D actors in around the explorer so only nearby skeletons exist and animate.
func _update_proximity(force_spawn: bool) -> void:
	if not is_instance_valid(player):
		return
	var at := player.global_position
	var spawn_radius := 26.0 if settings.quality == "high" else 20.0
	for encounter in encounters:
		if not is_instance_valid(encounter) or encounter.is_queued_for_deletion():
			continue
		var distance := encounter.global_position.distance_to(at)
		var actor := _actor_of(encounter)
		if actor == null and (distance < spawn_radius or (force_spawn and distance < 60.0)):
			actor = DungeonActor.new()
			actor.configure(String(encounter.get_meta("kind")), int(encounter.get_meta("style")), player, int(encounter.get_meta("encounter_id")) + 1)
			actor.name = "Actor"
			actor.add_to_group("dungeon_actor")
			encounter.add_child(actor)
			actor.rotation.y = rng.randf_range(0.0, TAU)
			encounter.set_meta("actor", actor)
			if force_spawn: break
		elif actor != null and distance > spawn_radius + 8.0 and not actor.busy and int(encounter.get_meta("encounter_id")) != current_encounter:
			actor.queue_free()
			encounter.remove_meta("actor")
			continue
		if actor != null:
			actor.set_active(distance < 18.0 or int(encounter.get_meta("encounter_id")) == current_encounter)
	for trap in get_tree().get_nodes_in_group("trap"):
		if not bool(trap.get_meta("seen", false)) and (trap as Node3D).global_position.distance_to(at) < 7.0:
			trap.set_meta("seen", true)
	for boost in get_tree().get_nodes_in_group("boost"):
		if not bool(boost.get_meta("seen", false)) and (boost as Node3D).global_position.distance_to(at) < 12.0:
			boost.set_meta("seen", true)

func _actor_of(encounter: Node) -> DungeonActor:
	if not is_instance_valid(encounter) or not encounter.has_meta("actor"):
		return null
	var value = encounter.get_meta("actor")
	if is_instance_valid(value) and not (value as Node).is_queued_for_deletion():
		return value as DungeonActor
	return null

func _on_encounter_body_entered(body: Node3D, encounter: Area3D) -> void:
	if body != player or current_encounter >= 0 or not running or is_run_paused:
		return
	_open_encounter(int(encounter.get_meta("encounter_id")))

func _open_encounter(id: int) -> void:
	if id < 0 or id >= encounters.size() or not is_instance_valid(encounters[id]) or resolved_encounters.has(id):
		return
	current_encounter = id
	var encounter := encounters[id]
	if _actor_of(encounter) == null:
		_update_proximity(false)
		if _actor_of(encounter) == null:
			var actor := DungeonActor.new()
			actor.configure(String(encounter.get_meta("kind")), int(encounter.get_meta("style")), player, id + 1)
			actor.add_to_group("dungeon_actor")
			encounter.add_child(actor)
			encounter.set_meta("actor", actor)
	var actor := _actor_of(encounter)
	actor.set_active(true)
	actor.react_question()
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	player.look_toward(encounter.global_position)
	player.pitch = deg_to_rad(-6.0)
	_release_mouse()
	_show_question(id, String(encounter.get_meta("kind")), actor.title)

func _show_question(id: int, kind: String, title: String) -> void:
	var question := questions[id]
	question_panel.visible = true
	feedback_pending = false
	awaiting_server = false
	question_title.text = title.to_upper()
	question_title.add_theme_color_override("font_color", C_SAGE if kind == "npc" else C_DANGER)
	question_meta.text = "%s · Encounter %d / %d · %s" % ["Friendly scholar" if kind == "npc" else "Hostile", id + 1, encounter_count, String(question.subject)]
	prompt_label.text = String(question.prompt)
	var options: Array = question.options
	answer_grid.columns = 2
	for i in answer_buttons.size():
		var button := answer_buttons[i]
		button.visible = i < options.size()
		if i < options.size():
			button.text = "%d   %s" % [i + 1, String(options[i])]
			button.disabled = (question.removed as Array).has(i)
			_style_answer(button, "normal")
	hint_button.visible = options.size() > 2
	hint_button.disabled = not (question.removed as Array).is_empty()
	var touch := is_instance_valid(mobile_controls) and mobile_controls.visible
	hint_button.text = ("Hint · remove two wrong answers  (%d coins)" if touch else "Hint · remove two wrong answers  (%d coins · H)") % int(DIFFICULTIES[difficulty].hint)
	var how := "Tap an answer." if touch else "Keys 1–%d choose." % options.size()
	feedback_label.text = "The Wise Wanderer's kin mark nearby traps on your map when you answer correctly." if kind == "npc" else "Answer to banish the %s. %s" % [title.to_lower(), how]
	feedback_label.add_theme_color_override("font_color", C_MUTED)
	continue_button.visible = false
	if answer_buttons[0].is_inside_tree() and not smoke_mode:
		answer_buttons[0].grab_focus()

func _submit_answer(choice: int) -> void:
	if current_encounter < 0 or awaiting_server or feedback_pending:
		return
	var id := current_encounter
	var question := questions[id]
	awaiting_server = true
	for button in answer_buttons: button.disabled = true
	hint_button.disabled = true
	var correct := false
	var correct_choice := -1
	var explanation := ""
	var mercy := false
	var coin_note := ""
	if linked:
		feedback_label.text = "Checking with Study Arena…"
		var response := await run_client.answer(id, choice)
		if not response.ok:
			awaiting_server = false
			feedback_label.text = "Could not send your answer (%s). Try again." % response.error
			feedback_label.add_theme_color_override("font_color", C_DANGER)
			if response.error == "RUN_CLOSED":
				_game_over("This dungeon run has ended on Study Arena.", "")
				return
			for i in answer_buttons.size(): answer_buttons[i].disabled = (question.removed as Array).has(i)
			return
		var data: Dictionary = response.data
		correct = bool(data.get("correct", false))
		correct_choice = int(data.get("correct_choice", -1))
		explanation = String(data.get("explanation", ""))
		mercy = bool(data.get("mercy_token", false))
		var state: Dictionary = data.get("state", {})
		coins = int(state.get("coins_total_this_run", coins))
		mistakes_left = int(state.get("mistakes_left", mistakes_left))
		if bool(data.get("flagged_fast", false)): coin_note = " (answered too fast — no coin)"
		elif bool(data.get("cap_reached", false)): coin_note = " (daily coin cap reached)"
		elif int(data.get("coins_awarded", 0)) > 0: coin_note = " +1 coin"
	else:
		correct_choice = int(question.answer_index)
		correct = choice == correct_choice
		explanation = String(question.explanation)
		if correct:
			coins += 1
			coin_note = " +1 coin (practice)"
			if rng.randf() < 0.05:
				mercy = true
				mistakes_left += 1
		else:
			mistakes_left -= 1
	awaiting_server = false
	if not resolved_encounters.has(id):
		resolved_encounters.append(id)
	for i in answer_buttons.size():
		if i == correct_choice: _style_answer(answer_buttons[i], "correct")
		elif i == choice and not correct: _style_answer(answer_buttons[i], "wrong")
	var encounter := encounters[id]
	if correct:
		correct_count += 1
		feedback_label.text = "Correct!%s%s\n%s" % [coin_note, "  ✦ Rare Mercy Token: +1 wrong-answer allowance!" if mercy else "", explanation]
		feedback_label.add_theme_color_override("font_color", C_SAGE)
		audio.play("chime")
		heal_amount = 1.0
		_play_slay_effect(encounter)
		if coin_note.begins_with(" +1"):
			_float_text(encounter.global_position + Vector3.UP * 2.3, "+1 ◉", C_FOCUS, 0.9)
		if mercy:
			_float_text(encounter.global_position + Vector3.UP * 2.8, "+1 ♥ Mercy", C_SAGE, 1.3)
		if String(encounter.get_meta("kind")) == "npc":
			traps_revealed_until = Time.get_ticks_msec() * 0.001 + 45.0
	else:
		var answer_text := String((question.options as Array)[correct_choice]) if correct_choice >= 0 and correct_choice < (question.options as Array).size() else "?"
		feedback_label.text = "Not quite — the answer was “%s”. %d wrong answers left.\n%s" % [answer_text, mistakes_left, explanation]
		feedback_label.add_theme_color_override("font_color", C_DANGER)
		audio.play("wrong")
		_play_enemy_skill(encounter)
	feedback_pending = true
	continue_button.visible = true
	if not smoke_mode:
		continue_button.grab_focus()
	_update_hud()
	_save_progress()

func _continue_after_feedback() -> void:
	if not feedback_pending:
		return
	feedback_pending = false
	var id := current_encounter
	_close_question()
	if id >= 0 and id < encounters.size() and is_instance_valid(encounters[id]):
		var encounter := encounters[id]
		var actor := _actor_of(encounter)
		encounter.set_deferred("monitoring", false)
		var linger := 3.6
		if actor != null and not actor.defeated:
			actor.retreat()
			linger = 2.4
		get_tree().create_timer(linger).timeout.connect(func(): if is_instance_valid(encounter): encounter.queue_free())
	if mistakes_left <= 0:
		_game_over("You reached the wrong-answer limit.", "lost")
	elif resolved_encounters.size() >= encounter_count:
		_open_exit()

func _close_question() -> void:
	question_panel.visible = false
	current_encounter = -1
	feedback_pending = false
	if running and not is_run_paused:
		player.controls_enabled = true
		_capture_mouse()

func _use_hint() -> void:
	if current_encounter < 0 or awaiting_server or feedback_pending:
		return
	var id := current_encounter
	var question := questions[id]
	var cost := int(DIFFICULTIES[difficulty].hint)
	var removed: Array = []
	if linked:
		awaiting_server = true
		hint_button.disabled = true
		var response := await run_client.hint(id)
		awaiting_server = false
		if not response.ok:
			hint_button.disabled = false
			feedback_label.text = "You need %d coins in your wallet for a hint." % cost if response.error == "INSUFFICIENT_COINS" else "Hint unavailable (%s)." % response.error
			feedback_label.add_theme_color_override("font_color", C_DANGER)
			return
		removed = response.data.get("removed_choices", [])
		feedback_label.text = "Two wrong answers fade away. Wallet: %d coins." % int(response.data.get("wallet_balance", 0))
	else:
		if coins < cost:
			feedback_label.text = "You need %d coins for a hint — you have %d." % [cost, coins]
			feedback_label.add_theme_color_override("font_color", C_DANGER)
			return
		coins -= cost
		var wrong: Array[int] = []
		for i in (question.options as Array).size():
			if i != int(question.answer_index): wrong.append(i)
		wrong.shuffle()
		removed = wrong.slice(0, mini(2, wrong.size() - 1))
		feedback_label.text = "Two wrong answers fade away. −%d coins." % cost
	feedback_label.add_theme_color_override("font_color", C_FOCUS)
	question.removed = removed
	hint_button.disabled = true
	for index in removed:
		var i := int(index)
		if i >= 0 and i < answer_buttons.size():
			answer_buttons[i].disabled = true
			_style_answer(answer_buttons[i], "removed")
	audio.play("spell", 1.4, -8.0)
	_update_hud()

# ---------------------------------------------------------------- exit / victory
func _build_exit_trigger() -> void:
	exit_area = Area3D.new()
	exit_area.name = "VictoryPortal"
	exit_area.collision_layer = 4
	exit_area.collision_mask = 2
	exit_area.position = _world(exit_cell)
	exit_area.add_to_group("dungeon_generated")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 2.0, 2.6)
	shape_node.shape = shape
	shape_node.position.y = 1.0
	exit_area.add_child(shape_node)
	exit_area.body_entered.connect(func(body: Node3D): if body == player and exit_open and running: _complete_maze())
	add_child(exit_area)

func _set_portal_open(open: bool) -> void:
	if not is_instance_valid(arch):
		return
	var portal := arch.get_node_or_null("MagicPortal") as MeshInstance3D
	if portal:
		portal.visible = open
	for child in arch.get_children():
		if child is OmniLight3D:
			(child as OmniLight3D).light_energy = 2.4 if open else 0.5
		elif child is CPUParticles3D:
			(child as CPUParticles3D).emitting = open

func _open_exit() -> void:
	if exit_open:
		return
	exit_open = true
	_set_portal_open(true)
	audio.play_at("portal", arch.global_position, 1.0, -4.0)
	_toast("All %d encounters resolved! The Victory Arch is open — press M and head for the EXIT." % encounter_count, 7.0)

func _complete_maze() -> void:
	running = false
	_clear_saved_run()
	player.controls_enabled = false
	player.celebrate()
	pet.celebrate()
	audio.play("chime", 0.8)
	var outcome := ""
	if linked:
		var response := await run_client.finish("victory")
		outcome = "\nRun saved to Study Arena." if response.ok else "\nCould not confirm the run with Study Arena (%s)." % response.error
	_show_result("DUNGEON CONQUERED!", "%d of %d correct · %d coins %s\n%d Mercy Tokens found%s" % [correct_count, encounter_count, coins, "earned" if linked else "(practice — not saved)", mercy_tokens, outcome])
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var spark := _effect_sphere(player.global_position + Vector3(cos(angle), 1.2, sin(angle)), Color.from_hsv(float(i) / 16.0, 0.6, 1.0), 0.08)
		create_tween().tween_property(spark, "position", spark.position + Vector3(cos(angle) * 3.0, rng.randf_range(1.5, 3.0), sin(angle) * 3.0), 1.2).set_trans(Tween.TRANS_QUAD).finished.connect(spark.queue_free)

func _game_over(reason: String, outcome: String) -> void:
	if not running:
		return
	running = false
	_clear_saved_run()
	player.controls_enabled = false
	question_panel.visible = false
	if outcome in ["lost", "timeout"]:
		await _player_death()
	var note := ""
	if linked and not outcome.is_empty():
		var response := await run_client.finish(outcome)
		note = "" if response.ok else "\nCould not confirm the run with Study Arena (%s)." % response.error
	_show_result("THE DUNGEON WINS", "%s\n%d of %d resolved · %d correct · %d coins %s%s" % [reason, resolved_encounters.size(), encounter_count, correct_count, coins, "kept" if linked else "(practice)", note])

func _show_result(title: String, body: String) -> void:
	_release_mouse()
	result_title.text = title
	result_body.text = body
	retry_button.text = "Start a new run in Study Arena" if linked else "Try Again"
	result_panel.visible = true
	retry_button.grab_focus()

# ---------------------------------------------------------------- traps & hazards
func _spawn_traps() -> void:
	var count := int(DIFFICULTIES[difficulty].traps)
	for i in count:
		var cell := _slot("trap", i)
		var trap := Area3D.new()
		trap.name = "Trap_%02d" % (i + 1)
		trap.collision_layer = 4
		trap.collision_mask = 2
		trap.position = _world(cell)
		trap.set_meta("trap_type", TRAP_TYPES[i % 4])
		trap.set_meta("hazard_id", i)
		trap.add_to_group("dungeon_generated")
		trap.add_to_group("trap")
		add_child(trap)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.2, 0.4, 2.2)
		shape_node.shape = shape
		shape_node.position.y = 0.2
		trap.add_child(shape_node)
		var spent := i in triggered_traps
		match TRAP_TYPES[i % 4]:
			"spikes":
				var tile := _model("res://assets/models/kit/floor_tile_big_spikes.glb", trap)
				tile.name = "Spikes"
				tile.scale = Vector3(0.55, 0.45, 0.55)
				tile.position.y = -0.05 if spent else -0.62
			"flame", "poison":
				var grate := _model("res://assets/models/kit/floor_tile_big_grate.gltf.glb", trap)
				grate.scale = Vector3(0.55, 1.0, 0.55)
				grate.position.y = 0.03
				var glow := _glow_disc(Color("ff6a1f") if i % 4 == 1 else Color("6dff6a"), 0.9)
				glow.position.y = 0.06
				trap.add_child(glow)
				var wisps := _particle_node(Color("ff7a32") if i % 4 == 1 else Color("7dff76"), 6, 1.6, Vector3(0.6, 0.05, 0.6), Vector3.UP * 0.4)
				wisps.name = "Wisps"
				trap.add_child(wisps)
			"rune":
				var rune := _rune_disc()
				rune.position.y = 0.05
				trap.add_child(rune)
		if spent:
			trap.set_meta("spent", true)
			trap.monitoring = false
		else:
			trap.body_entered.connect(_on_trap_entered.bind(trap))

func _on_trap_entered(body: Node3D, trap: Area3D) -> void:
	if body != player or bool(trap.get_meta("spent", false)) or not running:
		return
	trap.set_meta("spent", true)
	trap.set_meta("seen", true)
	var hazard_id := int(trap.get_meta("hazard_id", -1))
	if hazard_id >= 0 and hazard_id not in triggered_traps:
		triggered_traps.append(hazard_id)
	var penalty := int(DIFFICULTIES[difficulty].trap)
	var kind := String(trap.get_meta("trap_type"))
	var labels := {"spikes": "Spike trap", "flame": "Flame vent", "poison": "Poison cloud", "rune": "Hex rune"}
	audio.play_at("trap", trap.global_position)
	if _consume_ward(trap.global_position):
		_toast("%s sprang — your Bone Ward absorbed it!" % labels[kind])
	else:
		time_left = maxf(0.0, time_left - float(penalty))
		player.take_hit()
		damage_amount = 1.0
		_toast("%s! −%d seconds. Watch the floor — you can jump over traps." % [labels[kind], penalty])
	match kind:
		"spikes":
			var spikes := trap.get_node_or_null("Spikes") as Node3D
			if spikes: create_tween().tween_property(spikes, "position:y", -0.05, 0.08).set_trans(Tween.TRANS_BACK)
		"flame":
			_burst(trap.global_position + Vector3.UP * 0.2, Color("ff8a2a"), 60, 1.0).direction = Vector3.UP
		"poison":
			_burst(trap.global_position + Vector3.UP * 0.4, Color("7cff5e"), 50, 2.2)
		"rune":
			_burst(trap.global_position + Vector3.UP * 0.2, Color("c58bff"), 40, 0.9)
	var wisps := trap.get_node_or_null("Wisps") as CPUParticles3D
	if wisps: wisps.emitting = false

func _spawn_puddles_and_snakes() -> void:
	var water := _water_material()
	for i in int(DIFFICULTIES[difficulty].puddles):
		var puddle := MeshInstance3D.new()
		puddle.name = "WaterPuddle_%02d" % i
		var plane := PlaneMesh.new()
		var radius := 1.1 + float(i % 3) * 0.25
		plane.size = Vector2(radius * 2.0, radius * 1.6)
		plane.material = water
		puddle.mesh = plane
		puddle.position = _world(_slot("puddle", i)) + Vector3(rng.randf_range(-0.6, 0.6), 0.06, rng.randf_range(-0.6, 0.6))
		puddle.rotation.y = rng.randf_range(0.0, TAU)
		puddle.add_to_group("dungeon_generated")
		puddle.add_to_group("puddle")
		add_child(puddle)
	var serpents := int(DIFFICULTIES[difficulty].serpents)
	for i in serpents:
		if i in triggered_snakes:
			continue
		var snake := Area3D.new()
		snake.name = "BoneSerpent_%02d" % i
		snake.position = _world(_slot("serpent", i))
		snake.collision_layer = 4
		snake.collision_mask = 2
		snake.set_meta("hazard_id", i)
		snake.add_to_group("dungeon_generated")
		snake.add_to_group("snake")
		add_child(snake)
		var snake_shape := CollisionShape3D.new()
		var snake_box := BoxShape3D.new()
		snake_box.size = Vector3(2.6, 0.45, 1.3)
		snake_shape.shape = snake_box
		snake_shape.position.y = 0.22
		snake.add_child(snake_shape)
		var body := Node3D.new()
		body.name = "Coils"
		snake.add_child(body)
		for segment in 7:
			var bone := _model("res://assets/models/props/%s.gltf" % ["bone_A", "bone_B", "bone_C"][segment % 3], body)
			bone.scale = Vector3.ONE * (0.75 - segment * 0.04)
			bone.position = Vector3(-1.1 + segment * 0.33, 0.12, sin(float(segment) * 1.3) * 0.25)
			bone.rotation = Vector3(0, float(segment) * 0.9, PI * 0.5 * float(segment % 2))
		var skull := _model("res://assets/models/props/skull.gltf", body)
		skull.name = "Skull"
		skull.scale = Vector3.ONE * 0.85
		skull.position = Vector3(1.25, 0.22, 0)
		skull.rotation.y = PI * 0.5
		var eyes := OmniLight3D.new()
		eyes.light_color = Color("7dff76")
		eyes.light_energy = 0.9
		eyes.omni_range = 2.4
		eyes.position = Vector3(1.5, 0.45, 0)
		body.add_child(eyes)
		snake.body_entered.connect(_on_snake_entered.bind(snake))
		var slither := body.create_tween().set_loops()
		var sway := 0.1 if settings.reduced_motion else 0.35
		slither.tween_property(body, "rotation:y", sway, 0.8 + i * 0.03).set_trans(Tween.TRANS_SINE)
		slither.tween_property(body, "rotation:y", -sway, 0.8 + i * 0.03).set_trans(Tween.TRANS_SINE)

func _on_snake_entered(body: Node3D, snake: Area3D) -> void:
	if body != player or bool(snake.get_meta("spent", false)) or not running: return
	snake.set_meta("spent", true)
	var hazard_id := int(snake.get_meta("hazard_id", -1))
	if hazard_id >= 0 and hazard_id not in triggered_snakes:
		triggered_snakes.append(hazard_id)
	var penalty := int(DIFFICULTIES[difficulty].serpent)
	audio.play_at("rattle", snake.global_position, 0.7)
	if _consume_ward(snake.global_position):
		_toast("A bone serpent lunged — your Bone Ward shattered it!")
	else:
		time_left = maxf(0.0, time_left - float(penalty))
		player.take_hit()
		damage_amount = 0.9
		audio.play("hit")
		_toast("A bone serpent lunged! −%d seconds. Jump over the next one." % penalty)
	_burst(snake.global_position + Vector3.UP * 0.3, Color("e8e0c8"), 30, 0.8)
	create_tween().tween_property(snake, "scale", Vector3(1.2, 0.05, 1.2), 0.3).finished.connect(snake.queue_free)

# ---------------------------------------------------------------- boosts & buffs
func _spawn_boosts() -> void:
	var count := int(DIFFICULTIES[difficulty].boosts)
	for i in count:
		if i in collected_boosts:
			continue
		var kind: String = BOOST_ORDER[i % BOOST_ORDER.size()]
		if kind == "time" and linked:
			kind = "ward" # the server enforces signed-in time limits
		var info: Dictionary = BOOSTS[kind]
		var color: Color = info.color
		var pickup := Area3D.new()
		pickup.name = "Relic_%02d_%s" % [i, kind]
		pickup.collision_layer = 4
		pickup.collision_mask = 2
		pickup.position = _world(_slot("boost", i))
		pickup.set_meta("boost", kind)
		pickup.set_meta("boost_id", i)
		pickup.add_to_group("dungeon_generated")
		pickup.add_to_group("boost")
		add_child(pickup)
		var shape_node := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.95
		shape_node.shape = shape
		shape_node.position.y = 0.9
		pickup.add_child(shape_node)
		var pedestal := _model("res://assets/models/kit/column.gltf.glb", pickup)
		pedestal.scale = Vector3(0.7, 0.55, 0.7)
		var glow := _glow_disc(color, 1.1)
		glow.position.y = 0.05
		pickup.add_child(glow)
		var icon := Node3D.new()
		icon.name = "Icon"
		icon.position.y = 1.3
		pickup.add_child(icon)
		_boost_icon(kind, icon)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.36
		torus.outer_radius = 0.4
		torus.rings = 24
		torus.ring_segments = 6
		torus.material = _glow_material(Color(color, 0.8))
		ring.mesh = torus
		ring.rotation.x = 0.35
		icon.add_child(ring)
		var sparkles := _particle_node(color, 10, 1.8, Vector3(0.3, 0.2, 0.3), Vector3.UP * 0.5)
		sparkles.position.y = 1.0
		pickup.add_child(sparkles)
		var spin := icon.create_tween().set_loops()
		spin.tween_property(icon, "rotation:y", TAU, 4.0 if not settings.reduced_motion else 12.0).from(0.0)
		if not settings.reduced_motion:
			var bob := icon.create_tween().set_loops()
			bob.tween_property(icon, "position:y", 1.42, 1.1).set_trans(Tween.TRANS_SINE)
			bob.tween_property(icon, "position:y", 1.3, 1.1).set_trans(Tween.TRANS_SINE)
		pickup.body_entered.connect(func(body: Node3D): if body == player and running: _collect_boost(pickup))

func _boost_icon(kind: String, parent: Node3D) -> void:
	var paths := {"swift": "res://assets/models/kit/bottle_A_green.gltf.glb", "ward": "res://assets/models/weapons/Skeleton_Shield_Small_A.gltf", "sight": "res://assets/models/weapons/spellbook_open.gltf", "radiance": "res://assets/models/kit/torch_lit.gltf.glb"}
	var color: Color = BOOSTS[kind].color
	if paths.has(kind) and ResourceLoader.exists(paths[kind]):
		var model := _model(paths[kind], parent)
		_fit(model, parent, 0.5)
		return
	# Procedural relics: a faceted crystal (spring) or a glowing hourglass (time).
	if kind == "time":
		for side in [-1.0, 1.0]:
			var cone := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.0 if side > 0 else 0.16
			mesh.bottom_radius = 0.16 if side > 0 else 0.0
			mesh.height = 0.22
			mesh.radial_segments = 8
			mesh.material = _glow_material(color)
			cone.mesh = mesh
			cone.position.y = side * 0.11
			cone.rotation.x = PI if side > 0 else 0.0
			parent.add_child(cone)
	else:
		var crystal := MeshInstance3D.new()
		var gem := SphereMesh.new()
		gem.radius = 0.16
		gem.height = 0.5
		gem.radial_segments = 5
		gem.rings = 2
		gem.material = _glow_material(color)
		crystal.mesh = gem
		parent.add_child(crystal)

## Scales and centres an imported model so its largest side is `size` metres.
func _fit(model: Node3D, parent: Node3D, size: float) -> void:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := parent.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first or bounds.get_longest_axis_size() <= 0.0:
		return
	var factor := size / bounds.get_longest_axis_size()
	model.scale *= factor
	model.position -= bounds.get_center() * factor

func _collect_boost(pickup: Area3D) -> void:
	if not is_instance_valid(pickup) or bool(pickup.get_meta("spent", false)):
		return
	pickup.set_meta("spent", true)
	pickup.set_deferred("monitoring", false)
	var id := int(pickup.get_meta("boost_id"))
	if not collected_boosts.has(id):
		collected_boosts.append(id)
	var kind := String(pickup.get_meta("boost"))
	var info: Dictionary = BOOSTS[kind]
	match kind:
		"ward":
			ward_charges += 1
		"time":
			time_left += 45.0
		_:
			var seconds := float(info.seconds)
			active_buffs[kind] = minf(float(active_buffs.get(kind, 0.0)) + seconds, seconds * 2.0)
			if kind == "sight":
				traps_revealed_until = Time.get_ticks_msec() * 0.001 + float(active_buffs[kind])
	_apply_buffs()
	player.set_gem_color(info.color)
	audio.play("boost")
	heal_amount = 0.7
	_burst(pickup.global_position + Vector3.UP * 1.3, info.color, 40, 0.9)
	_toast("%s — %s." % [info.label, info.text])
	var icon := pickup.get_node_or_null("Icon") as Node3D
	var tween := create_tween()
	if icon:
		tween.tween_property(icon, "scale", Vector3.ONE * 1.8, 0.18).set_trans(Tween.TRANS_BACK)
		tween.tween_property(icon, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(pickup.queue_free)
	_update_hud()
	_save_progress()

func _consume_ward(at: Vector3) -> bool:
	if ward_charges <= 0:
		return false
	ward_charges -= 1
	_burst(at + Vector3.UP * 0.8, BOOSTS.ward.color, 45, 0.7)
	var ring := _effect_ring(player.global_position + Vector3.UP * 0.9, BOOSTS.ward.color, 0.5)
	var pulse := create_tween().set_parallel(true)
	pulse.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	pulse.tween_property(ring, "transparency", 1.0, 0.45)
	pulse.chain().tween_callback(ring.queue_free)
	heal_amount = 0.6
	player.shake(0.03, 0.15)
	_update_hud()
	return true

func _tick_buffs(delta: float) -> void:
	if active_buffs.is_empty():
		return
	var expired: Array[String] = []
	for key: String in active_buffs:
		active_buffs[key] = float(active_buffs[key]) - delta
		if float(active_buffs[key]) <= 0.0:
			expired.append(key)
	for key in expired:
		active_buffs.erase(key)
		_toast("%s wore off." % BOOSTS[key].label, 2.0)
	if not expired.is_empty():
		_apply_buffs()

func _apply_buffs() -> void:
	if not is_instance_valid(player):
		return
	player.speed_multiplier = 1.4 if active_buffs.has("swift") else 1.0
	player.jump_multiplier = 1.3 if active_buffs.has("spring") else 1.0
	player.lantern_boost = 2.0 if active_buffs.has("radiance") else 1.0

func _restore_boost_state(data: Dictionary) -> void:
	collected_boosts.clear()
	for id in data.get("collected_boosts", []): collected_boosts.append(int(id))
	active_buffs.clear()
	var saved: Dictionary = data.get("active_buffs", {})
	for key: String in saved:
		if BOOSTS.has(key): active_buffs[key] = float(saved[key])
	ward_charges = int(data.get("ward_charges", 0))
	if active_buffs.has("sight"):
		traps_revealed_until = Time.get_ticks_msec() * 0.001 + float(active_buffs.sight)

func _update_buff_hud() -> void:
	if buff_row == null:
		return
	var wanted := {}
	for key: String in active_buffs: wanted[key] = "%s %ds" % [BOOSTS[key].short, ceili(float(active_buffs[key]))]
	if ward_charges > 0: wanted["ward"] = "Ward ×%d" % ward_charges
	for key: String in buff_chips.keys():
		if not wanted.has(key):
			(buff_chips[key] as Control).queue_free()
			buff_chips.erase(key)
	for key: String in wanted:
		if not buff_chips.has(key):
			var chip := _card(Color(C_CARD_SOLID, 0.92), 999, 10, 4)
			var style := chip.get_theme_stylebox("panel") as StyleBoxFlat
			style.border_color = BOOSTS[key].color
			style.set_border_width_all(2)
			chip.add_child(_label("", 14, BOOSTS[key].color))
			buff_row.add_child(chip)
			buff_chips[key] = chip
		((buff_chips[key] as Control).get_child(0) as Label).text = wanted[key]

func _float_text(at: Vector3, text: String, color: Color, delay: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.fixed_size = true
	label.pixel_size = 0.0016
	label.outline_size = 12
	label.modulate = Color(color, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	effects_root.add_child(label)
	label.global_position = at
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(label, "global_position", at + Vector3.UP * 1.1, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)

## The explorer falls: the view drops to the floor, the screen reddens and fades.
func _player_death() -> void:
	audio.play("hit", 0.6)
	damage_amount = 1.0
	player.die(bool(settings.reduced_motion))
	if is_instance_valid(pet):
		pet.take_hit()
	await get_tree().create_timer(1.3).timeout
	var fade := create_tween()
	fade.tween_property(death_fade, "color:a", 0.72, 1.0)
	await fade.finished

# ---------------------------------------------------------------- effects
func _play_slay_effect(target: Node3D) -> void:
	var actor := _actor_of(target)
	var finish := target.global_position + Vector3.UP * 1.2
	var start := player.cast_skill(finish)
	pet.celebrate()
	audio.play("spell")
	if actor: actor.defeat()
	var beam := _effect_beam(start, finish, Color("75e8ff"))
	beam.scale = Vector3(0.1, 0.1, 1.0)
	var flash := _effect_sphere(finish, Color("ffd86b"), 0.3)
	var ring := _effect_ring(finish, Color("75e8ff"), 0.4)
	_burst(finish, Color("fff0a6"), 40, 0.8)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(beam, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(beam, "transparency", 1.0, 0.35).set_delay(0.18)
	tween.tween_property(flash, "scale", Vector3.ONE * 4.0, 0.45).set_delay(0.08)
	tween.tween_property(flash, "transparency", 1.0, 0.45).set_delay(0.08)
	tween.tween_property(ring, "scale", Vector3.ONE * 5.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, 0.6)
	tween.chain().tween_callback(func(): beam.queue_free(); flash.queue_free(); ring.queue_free())

func _play_enemy_skill(source: Node3D) -> void:
	var actor := _actor_of(source)
	if actor: actor.cast_attack()
	var origin := source.global_position + Vector3.UP * 1.4
	var destination := player.camera.global_position - player.camera.global_basis.z * 0.6
	var projectile := _effect_sphere(origin, Color("e74279"), 0.22)
	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_property(projectile, "global_position", destination, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		projectile.queue_free()
		player.take_hit()
		audio.play("hit")
		damage_amount = 1.0)

func _burst(at: Vector3, color: Color, amount: int, lifetime: float) -> CPUParticles3D:
	var p := _particle_node(color, amount, lifetime, Vector3(0.3, 0.3, 0.3), Vector3.UP * 2.2)
	p.one_shot = true
	p.explosiveness = 0.9
	p.spread = 70.0
	p.gravity = Vector3(0, -2.0, 0)
	p.position = at
	effects_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)
	return p

func _particle_node(color: Color, amount: int, lifetime: float, box: Vector3, velocity: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = velocity.normalized()
	p.spread = 30.0
	p.initial_velocity_min = velocity.length() * 0.4
	p.initial_velocity_max = velocity.length()
	p.gravity = Vector3(0, 0.2, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.08
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.albedo_texture = _soft_dot()
	mesh.material = material
	p.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 1.0))
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	return p

var _dot_texture: GradientTexture2D
func _soft_dot() -> GradientTexture2D:
	if _dot_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_dot_texture = GradientTexture2D.new()
		_dot_texture.gradient = gradient
		_dot_texture.fill = GradientTexture2D.FILL_RADIAL
		_dot_texture.fill_from = Vector2(0.5, 0.5)
		_dot_texture.fill_to = Vector2(0.5, 0.0)
		_dot_texture.width = 32
		_dot_texture.height = 32
	return _dot_texture

func _effect_beam(from: Vector3, to: Vector3, color: Color) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, from.distance_to(to))
	mesh.material = _glow_material(color)
	beam.mesh = mesh
	effects_root.add_child(beam)
	beam.global_position = (from + to) * 0.5
	if from.distance_to(to) > 0.01:
		beam.look_at(to, Vector3.UP)
	return beam

func _effect_sphere(at: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var effect := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = _glow_material(color)
	effect.mesh = sphere
	effect.position = at
	effects_root.add_child(effect)
	return effect

func _effect_ring(at: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var effect := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.08
	torus.rings = 20
	torus.ring_segments = 8
	torus.material = _glow_material(color)
	effect.mesh = torus
	effect.position = at
	effect.rotation.x = PI / 2.0
	effects_root.add_child(effect)
	return effect

func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _glow_disc(color: Color, radius: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = _soft_dot()
	material.albedo_color = Color(color, 0.55)
	plane.material = material
	disc.mesh = plane
	return disc

func _rune_disc() -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 tint = vec3(0.77, 0.45, 1.0);
uniform float pulse_speed = 1.2;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ring = smoothstep(0.03, 0.0, abs(r - 0.82)) + smoothstep(0.025, 0.0, abs(r - 0.62));
	float spokes = smoothstep(0.04, 0.0, abs(sin(a * 3.0)) * r) * step(r, 0.62) * step(0.2, r);
	float glyphs = step(0.62, r) * step(r, 0.82) * step(0.6, fract(a * 2.5 + 0.1)) * 0.5;
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed);
	ALBEDO = tint * (ring + spokes + glyphs) * pulse * 1.4;
	ALPHA = clamp((ring + spokes + glyphs) * pulse, 0.0, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("pulse_speed", 0.0 if settings.reduced_motion else 1.2)
	plane.material = material
	disc.mesh = plane
	return disc

func _water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform float motion = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = length(p + vec2(noise(UV * 3.0) - 0.5, noise(UV * 3.0 + 7.0) - 0.5) * 0.35);
	if (edge > 0.95) { discard; }
	float t = TIME * 0.6 * motion;
	float n1 = noise(UV * 9.0 + vec2(t, t * 0.7));
	float n2 = noise(UV * 13.0 - vec2(t * 0.8, t * 0.4));
	NORMAL_MAP = normalize(vec3(n1 - 0.5, n2 - 0.5, 2.2)) * 0.5 + 0.5;
	ALBEDO = vec3(0.03, 0.06, 0.09);
	ROUGHNESS = 0.04;
	METALLIC = 0.2;
	SPECULAR = 0.9;
	ALPHA = smoothstep(0.95, 0.7, edge) * 0.85;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("motion", 0.0 if settings.reduced_motion else 1.0)
	return material

func _model(path: String, parent: Node3D) -> Node3D:
	var node: Node3D = load(path).instantiate()
	parent.add_child(node)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = 30.0
	return node

# ---------------------------------------------------------------- HUD
func _update_hud() -> void:
	var total_seconds := ceili(time_left)
	time_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
	time_label.add_theme_color_override("font_color", C_DANGER if time_left < 120.0 else C_INK)
	difficulty_chip.text = String(DIFFICULTIES[difficulty].label).to_upper()
	progress_label.text = "Encounters %d / %d · %d correct" % [resolved_encounters.size(), encounter_count, correct_count]
	progress_bar.max_value = encounter_count
	progress_bar.value = resolved_encounters.size()
	coin_label.text = "◉ %d" % coins
	life_label.text = "♥ %d" % maxi(0, mistakes_left)
	life_label.add_theme_color_override("font_color", C_DANGER if mistakes_left <= 1 else C_INK)
	_update_buff_hud()

func _update_post_fx(delta: float) -> void:
	if post_fx == null:
		return
	damage_amount = move_toward(damage_amount, 0.0, delta * 1.6)
	heal_amount = move_toward(heal_amount, 0.0, delta * 1.2)
	var danger := 0.0
	if running and mistakes_left <= 1:
		danger = 0.18 + (0.0 if settings.reduced_motion else 0.1 * sin(Time.get_ticks_msec() * 0.004))
	post_fx.set_shader_parameter("damage", clampf(damage_amount * (0.5 if settings.reduced_motion else 0.8) + danger, 0.0, 1.0))
	post_fx.set_shader_parameter("heal", heal_amount * 0.6)

func _toast(text: String, seconds := 3.5) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	toast_clock = seconds

func _on_sound_played(sound: String) -> void:
	if not bool(settings.captions) or not CAPTIONS.has(sound):
		return
	caption_label.text = CAPTIONS[sound]
	caption_label.visible = true
	caption_clock = 2.2

func _capture_mouse() -> void:
	if smoke_mode or OS.has_feature("mobile") or (is_instance_valid(mobile_controls) and mobile_controls.visible and DisplayServer.is_touchscreen_available()):
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_mouse() -> void:
	if not smoke_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _toggle_pause() -> void:
	is_run_paused = not is_run_paused
	pause_panel.visible = is_run_paused
	player.controls_enabled = not is_run_paused and current_encounter < 0
	if is_run_paused:
		_release_mouse()
		_save_progress()
		pause_status_label.text = "Progress saved · %d / %d encounters · %02d:%02d remaining" % [resolved_encounters.size(), encounter_count, ceili(time_left) / 60, ceili(time_left) % 60]
	else:
		if current_encounter < 0: _capture_mouse()
		_toast("Adventure resumed.")

func _save_and_return_home() -> void:
	_save_progress()
	_open_study_arena()

func _return_home() -> void:
	_open_study_arena()

func _open_study_arena() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = '../#dungeon'", true)
	else:
		OS.shell_open(STUDY_ARENA_HOME)
		get_tree().quit()

func _retry_game() -> void:
	if linked:
		_open_study_arena()
		return
	_clear_saved_run()
	result_panel.visible = false
	question_panel.visible = false
	map_panel.visible = false
	map_open = false
	_clear_world()
	await get_tree().process_frame
	await get_tree().process_frame
	_start_game(difficulty)

# ---------------------------------------------------------------- save / resume
func _save_progress() -> void:
	if smoke_mode or not running or not is_instance_valid(player):
		return
	var data := {
		"version": SAVE_VERSION,
		"run_id": run_client.run_id if linked else "",
		"difficulty": difficulty,
		"companion": selected_companion,
		"maze_seed": maze_seed,
		"time_left": time_left,
		"mistakes_left": mistakes_left,
		"mercy_tokens": mercy_tokens,
		"coins": coins,
		"correct_count": correct_count,
		"resolved_encounters": resolved_encounters,
		"triggered_traps": triggered_traps,
		"triggered_snakes": triggered_snakes,
		"collected_boosts": collected_boosts,
		"active_buffs": active_buffs,
		"ward_charges": ward_charges,
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"yaw": player.yaw,
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
	var data := _load_saved_data()
	return not data.is_empty() and String(data.get("run_id", "")).is_empty()

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
	correct_count = int(data.get("correct_count", 0))
	resolved_encounters.clear()
	for id in data.get("resolved_encounters", []): resolved_encounters.append(int(id))
	triggered_traps.clear()
	for id in data.get("triggered_traps", []): triggered_traps.append(int(id))
	triggered_snakes.clear()
	for id in data.get("triggered_snakes", []): triggered_snakes.append(int(id))
	_restore_boost_state(data)
	_configure_size(int(DIFFICULTIES[difficulty].questions))
	questions = PracticeBank.build(maze_seed, encounter_count)
	for i in questions.size():
		questions[i] = _normalize_question(questions[i], int(questions[i].answer_index), String(questions[i].explanation))
	_build_run()
	_restore_pose(data)
	_begin("Saved adventure restored · %d of %d encounters resolved." % [resolved_encounters.size(), encounter_count])

func _restore_pose(data: Dictionary) -> void:
	var saved_position: Array = data.get("player_position", [])
	if saved_position.size() == 3:
		player.global_position = Vector3(float(saved_position[0]), float(saved_position[1]) + 0.05, float(saved_position[2]))
		pet.global_position = player.global_position
	player.yaw = float(data.get("yaw", player.yaw))

func _seed_from(text: String) -> int:
	return int(hash(text)) & 0x7fffffff

# ---------------------------------------------------------------- settings
func _load_settings() -> void:
	var file := ConfigFile.new()
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		settings.quality = "low"
	if file.load(SETTINGS_FILE) == OK:
		for key: String in settings:
			settings[key] = file.get_value("settings", key, settings[key])
	var forced := _argument_value("--quality=")
	if forced in ["high", "low"]:
		settings.quality = forced

func _save_settings() -> void:
	var file := ConfigFile.new()
	file.load(SETTINGS_FILE)
	for key: String in settings:
		file.set_value("settings", key, settings[key])
	file.save(SETTINGS_FILE)

func _apply_settings() -> void:
	if is_instance_valid(audio):
		audio.set_volume(float(settings.volume))
	if is_instance_valid(player):
		player.mouse_sensitivity = 0.0022 * float(settings.sensitivity)
		player.touch_sensitivity = float(settings.touch_sensitivity)
		player.invert_y = bool(settings.invert_y)
		player.base_fov = float(settings.fov)
		player.reduced_motion = bool(settings.reduced_motion)
	if is_instance_valid(mobile_controls):
		mobile_controls.set_scale_factor(float(settings.touch_size))
	var high: bool = settings.quality == "high"
	if is_instance_valid(kit):
		kit.quality_high = high
		kit.reduced_motion = bool(settings.reduced_motion)
		kit.light_clock = 0.0
	if world_env:
		world_env.glow_enabled = high
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	if post_fx:
		post_fx.set_shader_parameter("grain", 0.0 if settings.reduced_motion else 0.05)

# ---------------------------------------------------------------- UI construction
func _build_ui() -> void:
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 0
	add_child(fx_layer)
	var fx := ColorRect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx_shader := Shader.new()
	fx_shader.code = """
shader_type canvas_item;
uniform float damage = 0.0;
uniform float heal = 0.0;
uniform float grain = 0.05;
uniform float vignette = 0.62;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 p = UV - 0.5;
	float v = smoothstep(0.28, 0.8, length(p * vec2(1.3, 1.0)));
	float n = hash(floor(UV * vec2(640.0, 360.0)) + fract(TIME * 7.0) * 113.0) - 0.5;
	vec3 tint = mix(vec3(0.02, 0.0, 0.03), vec3(0.6, 0.02, 0.08), damage);
	tint = mix(tint, vec3(0.45, 0.9, 0.6), heal);
	float a = v * vignette + damage * (0.12 + 0.55 * v) + heal * 0.4 * v + abs(n) * grain;
	COLOR = vec4(tint + n * grain, clamp(a, 0.0, 0.95));
}
"""
	post_fx = ShaderMaterial.new()
	post_fx.shader = fx_shader
	fx.material = post_fx
	fx_layer.add_child(fx)
	death_fade = ColorRect.new()
	death_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_fade.color = Color(0.02, 0.0, 0.02, 0.0)
	fx_layer.add_child(death_fade)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	# Top-left: timer + difficulty.
	var timer_card := _card(C_CARD, 14)
	_anchor(timer_card, Control.PRESET_TOP_LEFT, Vector4(16, 14, 16, 14))
	hud.add_child(timer_card)
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 12)
	timer_card.add_child(timer_row)
	time_label = _label("00:00", 30, C_INK)
	timer_row.add_child(time_label)
	difficulty_chip = _label("EASY", 14, C_ON_SAGE)
	var chip := _card(C_SAGE, 999, 10, 4)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(difficulty_chip)
	timer_row.add_child(chip)
	buff_row = HBoxContainer.new()
	buff_row.add_theme_constant_override("separation", 6)
	buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(buff_row, Control.PRESET_TOP_LEFT, Vector4(16, 84, 16, 84))
	hud.add_child(buff_row)
	# Top-centre: progress.
	var progress_card := _card(C_CARD, 14)
	progress_card.custom_minimum_size = Vector2(360, 0)
	_anchor(progress_card, Control.PRESET_CENTER_TOP, Vector4(-180, 14, 180, 14))
	hud.add_child(progress_card)
	var progress_stack := VBoxContainer.new()
	progress_stack.add_theme_constant_override("separation", 6)
	progress_card.add_child(progress_stack)
	progress_label = _label("Encounters 0 / 20", 16, C_INK)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_stack.add_child(progress_label)
	progress_bar = ProgressBar.new()
	progress_bar.max_value = encounter_count
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(320, 8)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = C_SOFT
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = C_SAGE
	bar_fill.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", bar_bg)
	progress_bar.add_theme_stylebox_override("fill", bar_fill)
	progress_stack.add_child(progress_bar)
	# Top-right: coins + hearts.
	var stats_card := _card(C_CARD, 14)
	_anchor(stats_card, Control.PRESET_TOP_RIGHT, Vector4(-16, 14, -16, 14))
	hud.add_child(stats_card)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 18)
	stats_card.add_child(stats_row)
	coin_label = _label("◉ 0", 22, C_FOCUS)
	stats_row.add_child(coin_label)
	life_label = _label("♥ 0", 22, C_INK)
	stats_row.add_child(life_label)
	practice_badge = _card(C_PEACH, 10, 12, 6)
	practice_badge.custom_minimum_size = Vector2(300, 0)
	_anchor(practice_badge, Control.PRESET_CENTER_TOP, Vector4(-150, 88, 150, 88))
	var practice_text := _label("Practice run — coins are not saved", 14, C_FOCUS)
	practice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	practice_badge.add_child(practice_text)
	hud.add_child(practice_badge)
	# Crosshair + look hint.
	crosshair = Control.new()
	_anchor(crosshair, Control.PRESET_CENTER, Vector4.ZERO)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(func():
		crosshair.draw_circle(Vector2.ZERO, 3.0, Color(C_INK, 0.85))
		crosshair.draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24, Color(C_INK, 0.25), 1.5, true))
	hud.add_child(crosshair)
	look_hint = _label("Click to look around · WASD move · Shift run · Space jump · M map · Esc pause", 15, C_MUTED)
	look_hint.custom_minimum_size = Vector2(660, 0)
	_anchor(look_hint, Control.PRESET_CENTER, Vector4(-330, 30, 330, 30))
	look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	look_hint.visible = false
	hud.add_child(look_hint)
	# Toast + captions.
	toast_label = _label("", 17, C_FOCUS)
	toast_label.custom_minimum_size = Vector2(760, 0)
	_anchor(toast_label, Control.PRESET_CENTER_BOTTOM, Vector4(-380, -150, 380, -150))
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	toast_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(toast_label)
	caption_label = _label("", 16, C_INK)
	caption_label.custom_minimum_size = Vector2(480, 0)
	_anchor(caption_label, Control.PRESET_CENTER_BOTTOM, Vector4(-240, -92, 240, -92))
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var caption_bg := StyleBoxFlat.new()
	caption_bg.bg_color = Color(0, 0, 0, 0.62)
	caption_bg.set_corner_radius_all(6)
	caption_bg.content_margin_left = 10
	caption_bg.content_margin_right = 10
	caption_bg.content_margin_top = 4
	caption_bg.content_margin_bottom = 4
	caption_label.add_theme_stylebox_override("normal", caption_bg)
	caption_label.visible = false
	hud.add_child(caption_label)
	_build_question_panel()
	# Map.
	map_panel = _card(C_CARD, 14, 10, 10)
	_anchor(map_panel, Control.PRESET_TOP_RIGHT, Vector4(-16, 84, -16, 84))
	hud.add_child(map_panel)
	map_view = DungeonMap.new()
	map_view.game = self
	map_view.custom_minimum_size = Vector2(300, 300)
	map_panel.add_child(map_view)
	map_panel.visible = false
	_build_result_panel()
	_build_pause_panel()
	loading_panel = _center_panel(Vector2(460, 200))
	var loading_stack := _stack(loading_panel, 14)
	loading_label = _label("", 20, C_INK)
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_stack.add_child(loading_label)
	var loading_actions := HBoxContainer.new()
	loading_actions.name = "Actions"
	loading_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_actions.add_theme_constant_override("separation", 10)
	loading_stack.add_child(loading_actions)
	loading_actions.add_child(_button("Retry", "primary", func(): _start_linked_run()))
	loading_actions.add_child(_button("Play practice run", "secondary", func(): linked = false; loading_panel.visible = false; _show_companion_picker()))
	loading_actions.add_child(_button("Back to Study Arena", "secondary", _return_home))
	layer.add_child(loading_panel)
	loading_panel.visible = false
	hud.visible = false

func _build_question_panel() -> void:
	question_panel = _card(C_CARD_SOLID, 18, 26, 22)
	question_panel.custom_minimum_size = Vector2(760, 0)
	_anchor(question_panel, Control.PRESET_CENTER_BOTTOM, Vector4(-380, -24, 380, -24))
	hud.add_child(question_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	question_panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	question_title = _label("", 15, C_DANGER)
	header.add_child(question_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	question_meta = _label("", 14, C_MUTED)
	header.add_child(question_meta)
	prompt_label = _label("", 24, C_INK)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.custom_minimum_size = Vector2(700, 0)
	stack.add_child(prompt_label)
	answer_grid = GridContainer.new()
	answer_grid.columns = 2
	answer_grid.add_theme_constant_override("h_separation", 10)
	answer_grid.add_theme_constant_override("v_separation", 10)
	stack.add_child(answer_grid)
	answer_buttons.clear()
	for i in 4:
		var button := Button.new()
		button.custom_minimum_size = Vector2(349, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(_submit_answer.bind(i))
		answer_grid.add_child(button)
		answer_buttons.append(button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	stack.add_child(footer)
	hint_button = _button("Hint", "secondary", _use_hint)
	footer.add_child(hint_button)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	continue_button = _button("Continue  (Enter)", "primary", _continue_after_feedback)
	footer.add_child(continue_button)
	feedback_label = _label("", 16, C_MUTED)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(700, 0)
	stack.add_child(feedback_label)
	question_panel.visible = false

func _build_result_panel() -> void:
	result_panel = _center_panel(Vector2(520, 330))
	var stack := _stack(result_panel, 14)
	result_title = _label("", 30, C_FOCUS)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(result_title)
	result_body = _label("", 18, C_INK)
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(result_body)
	retry_button = _button("Try Again", "primary", _retry_game)
	stack.add_child(retry_button)
	stack.add_child(_button("Return to Study Arena", "secondary", _return_home))
	hud.add_child(result_panel)
	result_panel.visible = false

func _build_pause_panel() -> void:
	pause_panel = _center_panel(Vector2(560, 560))
	var stack := _stack(pause_panel, 10)
	var heading := _label("ADVENTURE PAUSED", 28, C_INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)
	pause_status_label = _label("", 16, C_MUTED)
	pause_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(pause_status_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(buttons)
	buttons.add_child(_button("Resume", "primary", _toggle_pause))
	buttons.add_child(_button("Save & return to Study Arena", "secondary", _save_and_return_home))
	stack.add_child(HSeparator.new())
	var settings_title := _label("Settings", 18, C_SAGE)
	stack.add_child(settings_title)
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 16)
	form.add_theme_constant_override("v_separation", 6)
	stack.add_child(form)
	_slider_row(form, "Look sensitivity (mouse)", "sensitivity", 0.3, 2.5, 0.05)
	_slider_row(form, "Touch look speed", "touch_sensitivity", 0.2, 2.5, 0.05)
	_slider_row(form, "Touch control size", "touch_size", 0.8, 1.5, 0.05)
	_slider_row(form, "Field of view", "fov", 60.0, 95.0, 1.0)
	_slider_row(form, "Volume", "volume", 0.0, 1.0, 0.05)
	_check_row(form, "Invert look (Y)", "invert_y")
	_check_row(form, "Reduced motion (no bob, shake or flicker)", "reduced_motion")
	_check_row(form, "Sound captions", "captions")
	form.add_child(_label("Graphics quality", 16, C_INK))
	var quality := OptionButton.new()
	quality.add_item("High — more torchlight, glow, embers")
	quality.add_item("Low — faster on phones and older laptops")
	quality.selected = 0 if settings.quality == "high" else 1
	quality.item_selected.connect(func(index: int): settings.quality = "high" if index == 0 else "low"; _save_settings(); _apply_settings())
	form.add_child(quality)
	var note := _label("Your maze, position, timer and resolved encounters are saved on this device. Signed-in runs keep coins on Study Arena.", 13, C_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)
	hud.add_child(pause_panel)
	pause_panel.visible = false

func _slider_row(form: GridContainer, text: String, key: String, low: float, high: float, step: float) -> void:
	form.add_child(_label(text, 16, C_INK))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(settings[key])
	slider.custom_minimum_size = Vector2(220, 28)
	slider.value_changed.connect(func(value: float): settings[key] = value; _apply_settings(); _save_settings())
	form.add_child(slider)

func _check_row(form: GridContainer, text: String, key: String) -> void:
	form.add_child(_label(text, 16, C_INK))
	var check := CheckButton.new()
	check.button_pressed = bool(settings[key])
	check.toggled.connect(func(value: bool): settings[key] = value; _apply_settings(); _save_settings())
	form.add_child(check)

func _show_loading(text: String, show_actions := false) -> void:
	loading_label.text = text
	loading_panel.visible = true
	loading_panel.get_node("Stack/Actions").visible = show_actions

func _card(color: Color, radius: int, pad_x := 16, pad_y := 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _center_panel(size: Vector2) -> PanelContainer:
	var panel := _card(C_CARD_SOLID, 18, 30, 26)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = size
	_anchor(panel, Control.PRESET_CENTER, Vector4(-size.x * 0.5, -size.y * 0.5, size.x * 0.5, size.y * 0.5))
	return panel

## Anchors a control and sets offsets (left, top, right, bottom); it grows away from the anchor.
func _anchor(control: Control, preset: int, offsets: Vector4) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w
	var anchor_x := control.anchor_left
	var anchor_y := control.anchor_top
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH if anchor_x == 0.5 else (Control.GROW_DIRECTION_BEGIN if anchor_x == 1.0 else Control.GROW_DIRECTION_END)
	control.grow_vertical = Control.GROW_DIRECTION_BOTH if anchor_y == 0.5 else (Control.GROW_DIRECTION_BEGIN if anchor_y == 1.0 else Control.GROW_DIRECTION_END)

func _stack(parent: Control, gap: int) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", gap)
	parent.add_child(stack)
	return stack

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, variant: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 17)
	_style_button(button, variant)
	button.pressed.connect(action)
	return button

func _style_button(button: Button, variant: String) -> void:
	var fill := C_SAGE if variant == "primary" else C_SOFT
	var text := C_ON_SAGE if variant == "primary" else C_INK
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.08) if state == "hover" else (fill.darkened(0.1) if state == "pressed" else fill)
		if state == "disabled": style.bg_color = Color(fill, 0.4)
		style.set_corner_radius_all(12)
		style.content_margin_left = 16
		style.content_margin_right = 16
		if state == "focus":
			style.draw_center = false
			style.border_color = C_FOCUS
			style.set_border_width_all(2)
		else:
			style.border_color = C_BORDER
			style.set_border_width_all(1)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_pressed_color", text)
	button.add_theme_color_override("font_focus_color", text)
	button.add_theme_color_override("font_disabled_color", Color(text, 0.5))

func _style_answer(button: Button, state_name: String) -> void:
	var fills := {"normal": C_SOFT, "correct": Color("2f5a3c"), "wrong": Color("5a2b2b"), "removed": Color(C_SOFT, 0.35)}
	var borders := {"normal": C_BORDER, "correct": C_SAGE, "wrong": C_DANGER, "removed": C_BORDER}
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fills[state_name]
		if state_name == "normal" and state == "hover": style.bg_color = C_SOFT.lightened(0.1)
		style.border_color = C_FOCUS if state == "focus" and state_name == "normal" else borders[state_name]
		style.set_border_width_all(2 if state_name in ["correct", "wrong"] or state == "focus" else 1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, style)
	var text := C_MUTED if state_name == "removed" else C_INK
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, text)
	button.add_theme_color_override("font_disabled_color", Color(text, 0.9 if state_name in ["correct", "wrong"] else 0.45))

# ---------------------------------------------------------------- pickers
func _picker_layer() -> CanvasLayer:
	var existing := get_node_or_null("PickerLayer")
	if existing: existing.free()
	var layer := CanvasLayer.new()
	layer.name = "PickerLayer"
	layer.layer = 3
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("050408")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	return layer

func _show_resume_picker(new_difficulty: String) -> void:
	var data := _load_saved_data()
	if data.is_empty():
		_start_game(new_difficulty)
		return
	var layer := _picker_layer()
	var panel := _center_panel(Vector2(500, 380))
	layer.add_child(panel)
	var stack := _stack(panel, 14)
	var heading := _label("CONTINUE YOUR ADVENTURE?", 26, C_INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)
	var summary := _label("%s practice · %d / %d encounters\n%d coins · %02d:%02d remaining" % [String(data.difficulty).capitalize(), (data.get("resolved_encounters", []) as Array).size(), int(DIFFICULTIES[String(data.difficulty)].questions), int(data.coins), ceili(float(data.time_left)) / 60, ceili(float(data.time_left)) % 60], 18, C_MUTED)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(summary)
	stack.add_child(_button("Resume saved adventure", "primary", func(): layer.queue_free(); _resume_saved_run()))
	stack.add_child(_button("Start new %s adventure" % new_difficulty.capitalize(), "secondary", func(): layer.queue_free(); _clear_saved_run(); _start_game(new_difficulty)))
	stack.add_child(_button("Return to Study Arena", "secondary", _return_home))

func _show_difficulty_picker() -> void:
	var layer := _picker_layer()
	var panel := _center_panel(Vector2(560, 520))
	layer.add_child(panel)
	var stack := _stack(panel, 12)
	var heading := _label("DUNGEON OF KNOWLEDGE", 28, C_FOCUS)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)
	var sub := _label("Choose your challenge", 18, C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(sub)
	for key in ["easy", "average", "hard", "hell"]:
		var rules: Dictionary = DIFFICULTIES[key]
		var choice := _button("%s · %d questions · %d min · %d wrong answers · %d-coin hints" % [rules.label, rules.questions, int(rules.seconds) / 60, rules.mistakes, rules.hint], "primary" if key == "easy" else "secondary", func(): layer.queue_free(); _start_game(key))
		choice.custom_minimum_size.y = 58
		stack.add_child(choice)
	var note := _label("Practice run — coins are not saved. Sign in to Study Arena and launch from the Dungeon page to earn real coins.", 14, C_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)

func _show_companion_picker() -> void:
	var layer := _picker_layer()
	var panel := _center_panel(Vector2(780, 620))
	layer.add_child(panel)
	var stack := _stack(panel, 12)
	var heading := _label("CHOOSE YOUR DUNGEON COMPANION", 26, C_INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)
	var note := _label("Your companion follows you through the crypts and casts with you.", 16, C_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var grid_box := GridContainer.new()
	grid_box.columns = 4
	grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_box.add_theme_constant_override("h_separation", 10)
	grid_box.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid_box)
	for id: String in COMPANION_IDS:
		var choice := _button("%s%s" % [id.capitalize(), " · selected" if id == selected_companion else ""], "primary" if id == selected_companion else "secondary", _choose_companion.bind(id, layer))
		choice.custom_minimum_size = Vector2(168, 200)
		choice.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		choice.expand_icon = true
		var portrait_path := "res://assets/companions/%s.png" % id
		if ResourceLoader.exists(portrait_path):
			choice.icon = load(portrait_path)
		grid_box.add_child(choice)

func _choose_companion(id: String, layer: CanvasLayer) -> void:
	selected_companion = id
	_save_companion_choice(id)
	layer.queue_free()
	_show_difficulty_picker()

func _save_companion_choice(id: String) -> void:
	var file := ConfigFile.new()
	file.load(SETTINGS_FILE)
	file.set_value("companion", "selected", id)
	file.save(SETTINGS_FILE)

func _load_companion_choice() -> String:
	var file := ConfigFile.new()
	if file.load(SETTINGS_FILE) == OK:
		var saved := String(file.get_value("companion", "selected", "moss"))
		if saved in COMPANION_IDS:
			return saved
	return "moss"

# ---------------------------------------------------------------- helpers
func _argument_value(prefix: String) -> String:
	if OS.has_feature("web"):
		var key := prefix.trim_prefix("--").trim_suffix("=")
		var web_value: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('%s') || ''" % key, true)
		if not String(web_value).is_empty():
			return String(web_value)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _branch_count() -> int:
	var result := 0
	for cell in walkable:
		var exits := 0
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _is_open(cell + direction):
				exits += 1
		if exits >= 3: result += 1
	return result

func _is_open(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid_size and c.y < grid_size and grid[_index(c)] == 0

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _index(cell: Vector2i) -> int:
	return cell.y * grid_size + cell.x

func _world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - grid_size / 2.0) * CELL_SIZE, 0.0, (cell.y - grid_size / 2.0) * CELL_SIZE)
