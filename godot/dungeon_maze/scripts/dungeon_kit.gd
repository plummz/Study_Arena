class_name DungeonKit
extends Node3D
## Builds the Dungeon of Knowledge from KayKit modular pieces (CC0) into chunked MultiMeshes,
## plus themed chambers, torches with flame billboards, and a pooled torch-light director.

const KIT := "res://assets/models/kit/"
const PROPS := "res://assets/models/props/"
const CHUNK := 7
const LIGHT_POOL := 12
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const WALL_VARIANTS := [
	["wall.gltf.glb", 58], ["wall_cracked.gltf.glb", 11], ["wall_broken.gltf.glb", 5], ["wall_arched.gltf.glb", 7],
	["wall_archedwindow_gated.gltf.glb", 5], ["wall_shelves.gltf.glb", 5], ["wall_gated.gltf.glb", 4], ["wall_window_closed.gltf.glb", 5],
]
const FLOOR_VARIANTS := [
	["floor_tile_large.gltf.glb", 62], ["floor_tile_large_rocks.gltf.glb", 18], ["floor_tile_small_broken_A.gltf.glb", 7],
	["floor_tile_small_weeds_A.gltf.glb", 6], ["floor_dirt_large_rocky.gltf.glb", 7],
]

var game: Node
var grid_size := 31
var cell := 4.0
var wall_height := 4.0
var batches := {}
var mesh_cache := {}
var torch_sockets: Array[Vector3] = []
var rooms: Array[Dictionary] = []
var lights: Array[OmniLight3D] = []
var embers: Array[CPUParticles3D] = []
var light_clock := 0.0
var quality_high := true
var reduced_motion := false
var flame_material: ShaderMaterial
var reserved := {}
var gate_cell := Vector2i(-1, -1)
var gate_dir := Vector2i.ZERO

func setup(owner_game: Node, size: int, cell_size: float, height: float) -> void:
	game = owner_game
	grid_size = size
	cell = cell_size
	wall_height = height

func is_open(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid_size and c.y < grid_size and game.grid[c.y * grid_size + c.x] == 0

func world(c: Vector2i) -> Vector3:
	return game._world(c)

func _h(a: int, b: int, salt: int) -> int:
	var v := (a * 73856093) ^ (b * 19349663) ^ (salt * 83492791) ^ int(game.maze_seed)
	v = (v ^ (v >> 13)) * 1274126177
	return absi(v ^ (v >> 16))

func _pick(table: Array, roll: int) -> String:
	var total := 0
	for entry in table: total += int(entry[1])
	var r := roll % total
	for entry in table:
		r -= int(entry[1])
		if r < 0: return String(entry[0])
	return String(table[0][0])

func build() -> void:
	for child in get_children():
		child.queue_free()
	batches.clear()
	torch_sockets.clear()
	lights.clear()
	embers.clear()
	_build_flame_material()
	var room_cells := {}
	for room: Dictionary in rooms:
		for z in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				room_cells[Vector2i(x, z)] = room.type
	for z in grid_size:
		for x in grid_size:
			var c := Vector2i(x, z)
			if not is_open(c):
				continue
			var base := world(c)
			var floor_name := "floor_tile_large.gltf.glb" if room_cells.has(c) else _pick(FLOOR_VARIANTS, _h(x, z, 1))
			_add(KIT + floor_name, Transform3D(Basis(Vector3.UP, float(_h(x, z, 2) % 4) * PI * 0.5), base))
			_add(KIT + "floor_tile_large.gltf.glb", Transform3D(Basis(Vector3.RIGHT, PI), base + Vector3.UP * wall_height))
			for d in DIRS:
				var n := c + d
				if is_open(n) or (c == gate_cell and d == gate_dir):
					continue
				var face_yaw := atan2(-float(d.x), -float(d.y))
				var edge := base + Vector3(d.x, 0, d.y) * cell * 0.5
				var roll := _h(x * 4 + d.x + 7, z * 4 + d.y + 7, 3)
				var wall_name := _pick(WALL_VARIANTS, roll)
				if room_cells.get(c, "") == "library" and roll % 3 != 0:
					wall_name = "wall_shelves.gltf.glb"
				var basis := Basis(Vector3.UP, face_yaw)
				_add(KIT + wall_name, Transform3D(basis, edge))
				var surface := edge - Vector3(d.x, 0, d.y) * 0.5
				if wall_name == "wall.gltf.glb":
					if roll % 7 == 0:
						_add_torch(surface, basis, d)
					elif roll % 11 == 1:
						_add(KIT + ["banner_patternA_red.gltf.glb", "banner_thin_blue.gltf.glb", "banner_shield_red.gltf.glb", "banner_patternC_green.gltf.glb"][roll % 4], Transform3D(basis, edge))
					elif roll % 13 == 2:
						_add(KIT + "shelf_small_candles.gltf.glb", Transform3D(basis, surface + Vector3.UP * 1.9))
					elif roll % 17 == 3:
						_add(KIT + "sword_shield_broken.gltf.glb", Transform3D(basis, surface + Vector3.UP * 2.0 + basis.z * 0.05))
			_corridor_dressing(c, base, room_cells)
	_corner_pillars()
	for room: Dictionary in rooms:
		_dress_room(room)
	_flush()
	_build_light_pool()

func _corridor_dressing(c: Vector2i, base: Vector3, room_cells: Dictionary) -> void:
	if room_cells.has(c) or reserved.has(c) or c == game.entrance_cell or c == game.exit_cell:
		return
	var roll := _h(c.x, c.y, 9)
	var wall_dir := Vector2i.ZERO
	for d in DIRS:
		if not is_open(c + d):
			wall_dir = d
			break
	var yaw := float(roll % 628) * 0.01
	if roll % 100 < 12:
		var scatter: String = ["bone_A.gltf", "bone_B.gltf", "bone_C.gltf", "skull.gltf", "ribcage.gltf"][roll % 5]
		var offset := Vector3(wall_dir.x, 0, wall_dir.y) * 1.05 + Vector3(float(roll % 7) * 0.12 - 0.36, 0, float(roll % 5) * 0.12 - 0.24)
		_add(PROPS + scatter, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.8), base + offset + Vector3.UP * 0.02))
	elif roll % 100 < 20 and wall_dir != Vector2i.ZERO:
		var prop: String = ["barrel_large.gltf.glb", "barrel_small_stack.gltf.glb", "box_stacked.gltf.glb", "crates_stacked.gltf.glb", "trunk_large_A.gltf.glb"][roll % 5]
		var scale := 0.6 if prop == "barrel_large.gltf.glb" else 0.75
		_add(KIT + prop, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), base + Vector3(wall_dir.x, 0, wall_dir.y) * 1.05))
	elif roll % 100 < 25:
		_add(KIT + ["candle_triple.gltf.glb", "candle_melted.gltf.glb", "candle_lit.gltf.glb"][roll % 3], Transform3D(Basis(Vector3.UP, yaw), base + Vector3(wall_dir.x, 0, wall_dir.y) * 1.25))
	elif roll % 100 < 29:
		_add(KIT + "keyring_hanging.gltf.glb", Transform3D(Basis(Vector3.UP, yaw), base + Vector3.UP * wall_height))
	elif roll % 100 < 31:
		_add(PROPS + "lantern_hanging.gltf", Transform3D(Basis.IDENTITY, base + Vector3.UP * wall_height))
		torch_sockets.append(base + Vector3.UP * (wall_height - 1.1))

func _corner_pillars() -> void:
	for z in range(1, grid_size):
		for x in range(1, grid_size):
			var cells := [Vector2i(x - 1, z - 1), Vector2i(x, z - 1), Vector2i(x - 1, z), Vector2i(x, z)]
			var open := 0
			for c in cells:
				if is_open(c): open += 1
			var diagonal := open == 2 and is_open(cells[0]) == is_open(cells[3])
			if open == 3 or diagonal:
				var corner := (world(Vector2i(x - 1, z - 1)) + world(Vector2i(x, z))) * 0.5
				_add(KIT + "pillar.gltf.glb", Transform3D(Basis.IDENTITY.scaled(Vector3(0.62, 1.0, 0.62)), corner))

func _add_torch(surface: Vector3, basis: Basis, d: Vector2i) -> void:
	_add(KIT + "torch_mounted.gltf.glb", Transform3D(basis, surface + Vector3.UP * 2.05))
	var flame_at := surface + Vector3.UP * 2.05 + basis * Vector3(0, 0.78, 0.36)
	_add_flame(flame_at, 1.0)
	torch_sockets.append(flame_at - Vector3(d.x, 0, d.y) * 0.35)

func _dress_room(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var center := (world(rect.position) + world(rect.end - Vector2i.ONE)) * 0.5
	var type: String = room.type
	match type:
		"crypt":
			for i in 4:
				var off := Vector3((i % 2) * 5.0 - 2.5, 0, int(i / 2) * 5.0 - 2.5)
				_add(PROPS + ("coffin_decorated.gltf" if i % 2 == 0 else "coffin.gltf"), Transform3D(Basis(Vector3.UP, PI * 0.5 * (i % 2)), center + off))
				_add(PROPS + "skull_candle.gltf", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.7), center + off * 1.55))
			_add(PROPS + "shrine_candles.gltf", Transform3D(Basis.IDENTITY, center))
			torch_sockets.append(center + Vector3.UP * 1.6)
		"library":
			_add(KIT + "table_medium_broken.gltf.glb", Transform3D(Basis(Vector3.UP, 0.3), center))
			_add(KIT + "candle_triple.gltf.glb", Transform3D(Basis.IDENTITY, center + Vector3(0.2, 0.95, 0.1)))
			# Shelves hang on the chamber walls (surface 5.5 m from centre) and face inward.
			for i in 4:
				var a := PI * 0.5 * i
				_add(KIT + "shelves.gltf.glb", Transform3D(Basis(Vector3.UP, atan2(-cos(a), -sin(a))), center + Vector3(cos(a), 0, sin(a)) * 5.5))
			torch_sockets.append(center + Vector3.UP * 1.8)
		"treasure":
			_add(KIT + "chest_gold.glb", Transform3D(Basis(Vector3.UP, PI), center))
			for i in 6:
				var a := TAU * float(i) / 6.0
				_add(KIT + ("coin_stack_large.gltf.glb" if i % 2 == 0 else "chest.glb"), Transform3D(Basis(Vector3.UP, a), center + Vector3(cos(a), 0, sin(a)) * 3.6))
			_add(KIT + "barrel_small_stack.gltf.glb", Transform3D(Basis(Vector3.UP, 1.1).scaled(Vector3.ONE * 0.8), center + Vector3(4.5, 0, -4.5)))
			torch_sockets.append(center + Vector3.UP * 1.5)
		"shrine":
			_add(PROPS + "plaque_candles.gltf", Transform3D(Basis.IDENTITY, center))
			for i in 8:
				var a := TAU * float(i) / 8.0
				_add(KIT + "candle_lit.gltf.glb", Transform3D(Basis.IDENTITY, center + Vector3(cos(a), 0, sin(a)) * 2.8))
				_add_flame(center + Vector3(cos(a), 0, sin(a)) * 2.8 + Vector3.UP * 0.62, 0.35)
			torch_sockets.append(center + Vector3.UP * 1.4)
		"armory":
			for i in 4:
				var a := TAU * float(i) / 4.0 + 0.4
				_add(KIT + "sword_shield_broken.gltf.glb", Transform3D(Basis(Vector3.UP, a), center + Vector3(cos(a), 0, sin(a)) * 3.2 + Vector3.UP * 1.0))
				_add(KIT + "trunk_large_A.gltf.glb", Transform3D(Basis(Vector3.UP, a + PI), center + Vector3(cos(a + 0.8), 0, sin(a + 0.8)) * 3.8))
			_add(KIT + "pillar_decorated.gltf.glb", Transform3D(Basis.IDENTITY.scaled(Vector3(0.7, 1.0, 0.7)), center))
			torch_sockets.append(center + Vector3.UP * 2.2)

func build_gates(entrance: Vector2i, entrance_dir: Vector2i, exit_cell: Vector2i, exit_dir: Vector2i) -> Node3D:
	var yaw := atan2(-float(entrance_dir.x), -float(entrance_dir.y))
	var entry := Node3D.new()
	entry.name = "EntrancePortal"
	entry.transform = Transform3D(Basis(Vector3.UP, yaw), world(entrance) + Vector3(entrance_dir.x, 0, entrance_dir.y) * cell * 0.5)
	add_child(entry)
	var gate := _instance(KIT + "wall_gated.gltf.glb")
	gate.name = "EntranceGate"
	entry.add_child(gate)
	var entry_glow := OmniLight3D.new()
	entry_glow.light_color = Color("68dbff")
	entry_glow.light_energy = 1.6
	entry_glow.omni_range = 6.5
	entry_glow.position = Vector3(0, 1.8, 1.2)
	entry.add_child(entry_glow)
	var mist := _particles(Color("8fe9ff"), 24, 2.6, Vector3(1.6, 0.2, 0.3), Vector3.UP * 0.35)
	mist.position = Vector3(0, 0.3, 0.8)
	entry.add_child(mist)
	var arch := _instance(PROPS + "arch_gate.gltf")
	arch.name = "VictoryArch"
	# The arch spans local X, so face its opening along the corridor that leads in.
	arch.transform = Transform3D(Basis(Vector3.UP, atan2(-float(exit_dir.x), -float(exit_dir.y))).scaled(Vector3(0.9, 0.9, 0.9)), world(exit_cell))
	add_child(arch)
	var portal := MeshInstance3D.new()
	portal.name = "MagicPortal"
	var disc := QuadMesh.new()
	disc.size = Vector2(2.9, 3.2)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 tint = vec3(0.85, 0.55, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y *= 1.1;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 5.0 + r * 12.0 - TIME * 3.0) * 0.5 + 0.5;
	float ring = smoothstep(1.0, 0.75, r) * smoothstep(0.0, 0.5, r);
	float core = smoothstep(0.6, 0.0, r);
	ALBEDO = tint * (swirl * ring * 1.4 + core * 0.9);
	ALPHA = clamp((ring * (0.35 + swirl * 0.65) + core * 0.6) * smoothstep(1.02, 0.9, r), 0.0, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	disc.material = material
	portal.mesh = disc
	portal.position = Vector3(0, 1.7, 0)
	arch.add_child(portal)
	var glow := OmniLight3D.new()
	glow.light_color = Color("c58bff")
	glow.light_energy = 2.4
	glow.omni_range = 9.0
	glow.position = Vector3(0, 2.0, 0.6)
	arch.add_child(glow)
	var sparkles := _particles(Color("d8a8ff"), 40, 2.2, Vector3(1.4, 1.6, 0.3), Vector3.UP * 0.6)
	sparkles.position = Vector3(0, 1.7, 0)
	arch.add_child(sparkles)
	return arch

func _instance(path: String) -> Node3D:
	return load(path).instantiate()

# ---------- batching ----------
func _meshes(path: String) -> Array:
	if mesh_cache.has(path):
		return mesh_cache[path]
	var entries := []
	if ResourceLoader.exists(path):
		var scene: Node = load(path).instantiate()
		for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var local := Transform3D.IDENTITY
			var node: Node = m
			while node != scene and node is Node3D:
				local = (node as Node3D).transform * local
				node = node.get_parent()
			entries.append([m.mesh, local])
		scene.free()
	mesh_cache[path] = entries
	return entries

func _add(path: String, xform: Transform3D) -> void:
	var cx := int(floor((xform.origin.x / cell + grid_size * 0.5) / CHUNK))
	var cz := int(floor((xform.origin.z / cell + grid_size * 0.5) / CHUNK))
	var entries := _meshes(path)
	for i in entries.size():
		var key := "%s#%d|%d|%d" % [path, i, cx, cz]
		if not batches.has(key):
			batches[key] = {"mesh": entries[i][0], "xforms": []}
		batches[key].xforms.append(xform * entries[i][1])

func _flush() -> void:
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch.mesh
		multi.instance_count = batch.xforms.size()
		for i in batch.xforms.size():
			multi.set_instance_transform(i, batch.xforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = key.get_file().replace("#", "_").replace("|", "_")
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 62.0
		instance.add_to_group("dungeon_kit")
		add_child(instance)
	batches.clear()

# ---------- flames & lights ----------
func _build_flame_material() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float intensity = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 uv = UV;
	float seed = NODE_POSITION_WORLD.x * 1.7 + NODE_POSITION_WORLD.z * 2.3;
	float n = noise(vec2(uv.x * 4.0 + seed, uv.y * 3.0 + TIME * 3.4 + seed));
	float shape = (1.0 - abs(uv.x - 0.5) * 2.2) * (uv.y) - n * 0.35 * (1.0 - uv.y);
	float core = smoothstep(0.05, 0.55, shape);
	vec3 col = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.85, 0.45), core);
	ALBEDO = col * intensity * 2.2;
	ALPHA = clamp(smoothstep(0.0, 0.25, shape) * (0.85 + 0.15 * sin(TIME * 17.0 + seed)), 0.0, 1.0);
}
"""
	flame_material = ShaderMaterial.new()
	flame_material.shader = shader

func _add_flame(at: Vector3, size: float) -> void:
	var key := "flame"
	if not mesh_cache.has(key):
		var quad := QuadMesh.new()
		quad.size = Vector2(0.34, 0.62)
		quad.center_offset = Vector3(0, 0.22, 0)
		quad.material = flame_material
		mesh_cache[key] = [[quad, Transform3D.IDENTITY]]
	var cx := int(floor((at.x / cell + grid_size * 0.5) / CHUNK))
	var cz := int(floor((at.z / cell + grid_size * 0.5) / CHUNK))
	var bkey := "flame#0|%d|%d" % [cx, cz]
	if not batches.has(bkey):
		batches[bkey] = {"mesh": mesh_cache[key][0][0], "xforms": []}
	batches[bkey].xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at))

func _build_light_pool() -> void:
	for i in LIGHT_POOL:
		var light := OmniLight3D.new()
		light.name = "TorchLight_%02d" % i
		light.light_color = Color("ffa458")
		light.light_energy = 0.0
		light.omni_range = 7.5
		light.omni_attenuation = 1.3
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		lights.append(light)
		var ember := _particles(Color("ffb35c"), 10, 1.4, Vector3(0.08, 0.05, 0.08), Vector3.UP * 0.9)
		ember.emitting = false
		light.add_child(ember)
		embers.append(ember)

func _particles(color: Color, amount: int, lifetime: float, box: Vector3, velocity: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = velocity.normalized() if velocity.length() > 0.0 else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = velocity.length() * 0.5
	p.initial_velocity_max = velocity.length()
	p.gravity = Vector3(0, 0.15, 0)
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	mesh.material = material
	p.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return p

## Reassigns the pooled lights to the torch sockets nearest the explorer.
func update_lights(focus: Vector3, delta: float) -> float:
	light_clock -= delta
	var t := Time.get_ticks_msec() * 0.001
	var nearest_distance := 99.0
	if light_clock <= 0.0 and not torch_sockets.is_empty():
		light_clock = 0.2
		var sorted: Array[Vector3] = torch_sockets.duplicate()
		sorted.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(focus) < b.distance_squared_to(focus))
		var count := LIGHT_POOL if quality_high else 6
		for i in lights.size():
			var active: bool = i < count and i < sorted.size() and sorted[i].distance_to(focus) < 26.0
			lights[i].visible = active
			if active:
				lights[i].global_position = sorted[i]
			embers[i].emitting = active and quality_high and not reduced_motion
	for i in lights.size():
		if not lights[i].visible:
			continue
		var d := lights[i].global_position.distance_to(focus)
		nearest_distance = minf(nearest_distance, d)
		var flicker := 0.0 if reduced_motion else sin(t * 9.0 + i * 1.7) * 0.18 + sin(t * 23.0 + i * 3.1) * 0.1
		var fade := clampf((26.0 - d) / 6.0, 0.0, 1.0)
		lights[i].light_energy = (1.7 + flicker) * fade
	return nearest_distance
