extends SceneTree
func _init() -> void:
	var names := ["kit/banner_patternA_red.gltf.glb","kit/banner_thin_blue.gltf.glb","kit/keyring_hanging.gltf.glb","kit/shelf_small_candles.gltf.glb","props/lantern_hanging.gltf","props/plaque_candles.gltf","kit/sword_shield_broken.gltf.glb","props/arch_gate.gltf","props/crypt.gltf","props/coffin.gltf","props/shrine_candles.gltf","kit/chest.glb","kit/wall_gated.gltf.glb","kit/pillar_decorated.gltf.glb","kit/rubble_large.gltf.glb","kit/coin_stack_large.gltf.glb","kit/candle_triple.gltf.glb","kit/barrel_large.gltf.glb","kit/shelves.gltf.glb","kit/table_medium_broken.gltf.glb","props/bone_A.gltf","kit/torch_lit.gltf.glb","kit/wall_shelves.gltf.glb","kit/wall_archedwindow_gated.gltf.glb","props/skull_candle.gltf","kit/trunk_large_A.gltf.glb"]
	for n in names:
		var s: Node = load("res://assets/models/" + n).instantiate()
		var ms := s.find_children("*", "MeshInstance3D", true, false)
		var line: String = n + " meshes=" + str(ms.size())
		for m: MeshInstance3D in ms:
			line += " | " + m.name + " " + str(m.get_aabb()) + " at " + str(m.transform.origin)
		print(line)
		s.free()
	quit()
