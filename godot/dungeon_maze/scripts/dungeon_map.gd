class_name DungeonMap
extends Control

var game: Node

func _draw() -> void:
	if game == null or game.grid.is_empty():
		return
	var cell := minf(size.x, size.y) / float(game.grid_size)
	draw_rect(Rect2(Vector2.ZERO, size), Color("dc0b0c12"), true)
	for z in game.grid_size:
		for x in game.grid_size:
			if game.grid[game._index(Vector2i(x, z))] == 0:
				draw_rect(Rect2(Vector2(x * cell, z * cell), Vector2(cell + 0.4, cell + 0.4)), Color("7a565b68"), true)
	for encounter in game.encounters:
		if not is_instance_valid(encounter):
			continue
		var grid_pos: Vector2 = Vector2(encounter.position.x, encounter.position.z) / game.CELL_SIZE + Vector2.ONE * (game.grid_size / 2.0)
		var color := Color("59b8ff") if encounter.get_meta("kind") == "npc" else Color("db4868")
		draw_circle(grid_pos * cell + Vector2.ONE * cell * 0.5, maxf(1.4, cell * 0.24), color)
	# Traps appear once spotted (within a few metres) or while a scholar's reveal is active.
	var revealed: bool = Time.get_ticks_msec() * 0.001 < float(game.traps_revealed_until)
	for trap in get_tree().get_nodes_in_group("trap"):
		if revealed or bool(trap.get_meta("seen", false)):
			_draw_world_dot(trap, cell, Color("ff9f43"), 0.24)
	# Relics show once spotted, or everywhere while the Scholar's Lens is active.
	var lens: bool = game.active_buffs.has("sight")
	for boost in get_tree().get_nodes_in_group("boost"):
		if not is_instance_valid(boost) or bool(boost.get_meta("spent", false)): continue
		if lens or bool(boost.get_meta("seen", false)):
			var grid_pos: Vector2 = Vector2(boost.position.x, boost.position.z) / float(game.CELL_SIZE) + Vector2.ONE * (float(game.grid_size) / 2.0)
			var c: Vector2 = grid_pos * cell + Vector2.ONE * cell * 0.5
			var r := maxf(2.5, cell * 0.4)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), game.BOOSTS[boost.get_meta("boost")].color)
	for snake in get_tree().get_nodes_in_group("snake"):
		_draw_world_dot(snake, cell, Color("79df72"), 0.3)
	for puddle in get_tree().get_nodes_in_group("puddle"):
		_draw_world_dot(puddle, cell, Color("5ac8ed88"), 0.2)
	if is_instance_valid(game.player):
		var player_pos: Vector2 = Vector2(game.player.position.x, game.player.position.z) / game.CELL_SIZE + Vector2.ONE * (game.grid_size / 2.0)
		draw_circle(player_pos * cell + Vector2.ONE * cell * 0.5, maxf(2.5, cell * 0.38), Color("ffe178"))
		var heading := Vector2(-sin(game.player.rotation.y), -cos(game.player.rotation.y))
		var center := player_pos * cell + Vector2.ONE * cell * 0.5
		draw_line(center, center + heading * maxf(6.0, cell * 0.8), Color("fff4a8"), 2.0)
	_draw_marker(game.entrance_cell, cell, Color("58e6c2"), "ENTRANCE")
	_draw_marker(game.exit_cell, cell, Color("f5a3ff"), "EXIT · OPEN" if game.exit_open else "EXIT")
	for room: Dictionary in game.rooms:
		var rect: Rect2i = room.rect
		draw_rect(Rect2(Vector2(rect.position) * cell, Vector2(rect.size) * cell), Color("edc38355"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 7), "Gold you · Blue scholar · Red foe · Orange trap · ◆ relic", HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 11, Color.WHITE)

func _draw_marker(grid_cell: Vector2i, cell_size: float, color: Color, text: String) -> void:
	var at := Vector2(grid_cell.x, grid_cell.y) * cell_size + Vector2.ONE * cell_size * 0.5
	draw_circle(at, maxf(3.4, cell_size * 0.46), color)
	draw_string(ThemeDB.fallback_font, at + Vector2(7, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _draw_world_dot(node: Node3D, cell_size: float, color: Color, radius_scale: float) -> void:
	if not is_instance_valid(node): return
	var grid_pos: Vector2 = Vector2(node.position.x, node.position.z) / float(game.CELL_SIZE) + Vector2.ONE * (float(game.grid_size) / 2.0)
	draw_circle(grid_pos * cell_size + Vector2.ONE * cell_size * 0.5, maxf(1.3, cell_size * radius_scale), color)
