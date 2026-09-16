class_name DungeonMap
extends Control

var game: Node

func _draw() -> void:
	if game == null or game.grid.is_empty():
		return
	var cell := minf(size.x, size.y) / float(game.GRID_SIZE)
	draw_rect(Rect2(Vector2.ZERO, size), Color("dc0b0c12"), true)
	for z in game.GRID_SIZE:
		for x in game.GRID_SIZE:
			if game.grid[game._index(Vector2i(x, z))] == 0:
				draw_rect(Rect2(Vector2(x * cell, z * cell), Vector2(cell + 0.4, cell + 0.4)), Color("7a565b68"), true)
	for encounter in game.encounters:
		if not is_instance_valid(encounter):
			continue
		var grid_pos: Vector2 = Vector2(encounter.position.x, encounter.position.z) / game.CELL_SIZE + Vector2.ONE * (game.GRID_SIZE / 2.0)
		var color := Color("59b8ff") if encounter.get_meta("kind") == "npc" else Color("db4868")
		draw_circle(grid_pos * cell + Vector2.ONE * cell * 0.5, maxf(1.4, cell * 0.24), color)
	for trap in get_tree().get_nodes_in_group("trap"):
		_draw_world_dot(trap, cell, Color("ff9f43"), 0.24)
	for snake in get_tree().get_nodes_in_group("snake"):
		_draw_world_dot(snake, cell, Color("79df72"), 0.3)
	for puddle in get_tree().get_nodes_in_group("puddle"):
		_draw_world_dot(puddle, cell, Color("5ac8ed88"), 0.2)
	if is_instance_valid(game.player):
		var player_pos: Vector2 = Vector2(game.player.position.x, game.player.position.z) / game.CELL_SIZE + Vector2.ONE * (game.GRID_SIZE / 2.0)
		draw_circle(player_pos * cell + Vector2.ONE * cell * 0.5, maxf(2.5, cell * 0.38), Color("ffe178"))
		var heading := Vector2(-sin(game.player.rotation.y), -cos(game.player.rotation.y))
		var center := player_pos * cell + Vector2.ONE * cell * 0.5
		draw_line(center, center + heading * maxf(6.0, cell * 0.8), Color("fff4a8"), 2.0)
	_draw_marker(game.entrance_cell, cell, Color("58e6c2"), "ENTRANCE")
	_draw_marker(game.exit_cell, cell, Color("f5a3ff"), "EXIT")
	draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 7), "Gold: you · Blue: NPC · Red: enemy · M closes map", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw_marker(grid_cell: Vector2i, cell_size: float, color: Color, text: String) -> void:
	var at := Vector2(grid_cell.x, grid_cell.y) * cell_size + Vector2.ONE * cell_size * 0.5
	draw_circle(at, maxf(3.4, cell_size * 0.46), color)
	draw_string(ThemeDB.fallback_font, at + Vector2(7, -5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _draw_world_dot(node: Node3D, cell_size: float, color: Color, radius_scale: float) -> void:
	if not is_instance_valid(node): return
	var grid_pos := Vector2(node.position.x, node.position.z) / game.CELL_SIZE + Vector2.ONE * (game.GRID_SIZE / 2.0)
	draw_circle(grid_pos * cell_size + Vector2.ONE * cell_size * 0.5, maxf(1.3, cell_size * radius_scale), color)
