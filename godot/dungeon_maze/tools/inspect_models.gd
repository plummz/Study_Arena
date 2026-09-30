extends SceneTree
# Developer tool: prints the structure of imported KayKit models.
# Run: godot --headless --path godot/dungeon_maze --script res://tools/inspect_models.gd

func _init() -> void:
	for path in ["res://assets/models/characters/Skeleton_Warrior.glb", "res://assets/models/characters/Mage.glb"]:
		var scene: Node = load(path).instantiate()
		print("== ", path)
		_dump(scene, 0)
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player:
			print("  animations: ", player.get_animation_list())
		var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton:
			var names: Array[String] = []
			for i in skeleton.get_bone_count(): names.append(skeleton.get_bone_name(i))
			print("  bones: ", names)
		scene.free()
	for path in ["res://assets/models/kit/wall.gltf.glb", "res://assets/models/kit/wall_corner.gltf.glb", "res://assets/models/kit/wall_pillar.gltf.glb", "res://assets/models/kit/torch_mounted.gltf.glb", "res://assets/models/kit/floor_tile_large.gltf.glb", "res://assets/models/props/skull.gltf", "res://assets/models/weapons/staff.gltf"]:
		var scene: Node = load(path).instantiate()
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		for m: MeshInstance3D in meshes:
			print("%s :: %s aabb=%s surfaces=%d xform=%s" % [path.get_file(), m.name, m.get_aabb(), m.mesh.get_surface_count(), m.transform.origin])
		scene.free()
	quit()

func _dump(node: Node, depth: int) -> void:
	if depth > 3: return
	print("  ".repeat(depth + 1), node.name, " <", node.get_class(), ">")
	for child in node.get_children(): _dump(child, depth + 1)
