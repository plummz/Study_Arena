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
	if is_instance_valid(game.player):
		var player_pos: Vector2 = Vector2(game.player.position.x, game.player.position.z) / game.CELL_SIZE + Vector2.ONE * (game.GRID_SIZE / 2.0)
		draw_circle(player_pos * cell + Vector2.ONE * cell * 0.5, maxf(2.5, cell * 0.38), Color("ffe178"))
	draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 7), "Gold: you · Blue: NPC · Red: enemy", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
