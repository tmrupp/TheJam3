extends "res://tests/interaction_hints_test.gd"
## Stills: the four keys in order of rarity (more teeth the rarer), and vaults in a garden, a
## cemetery and a sky level (carved in rock, or a strongbox), with the wizard at the door.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_vaults.gd

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	output = ProjectSettings.globalize_path("res://../art-captures/vaults")
	DirAccess.make_dir_recursive_absolute(output)
	RunState.save_path = "user://capture_vaults.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	main.get_node("Menu").world_seed.text = "28"
	main.get_node("Menu").start_game()
	player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	await loaded()
	var base: Vector2 = Vector2(-2000, -2000)
	player.global_position = base + Vector2(-600, 0)
	camera.global_position = base
	camera.zoom = Vector2.ONE * 0.7
	camera.reset_smoothing()
	var keys: Array[Node2D] = []
	for color: int in range(MapInfo.KEY_COLOR_COUNT):
		var key: Node2D = load("res://prefabs/key.tscn").instantiate()
		key.set_meta(&"key_color", color)
		key.position = base + Vector2((float(color) - 1.5) * 55.0, 0)
		info.map_elements.add_child(key)
		keys.append(key)
	await settle(40)
	await shot("keys_by_rarity")
	for key: Node2D in keys:
		key.queue_free()
	for at: Vector2i in [Vector2i(28, 0), Vector2i(28, NextWorldDef.first_depth(&"cemetery") + 1), Vector2i(28, NextWorldDef.first_depth(&"sky") + 1), Vector2i(1, 2)]:
		info.coord = at
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await loaded()
		if info.world.vaults.is_empty():
			print("no vault in ", at)
			continue
		var vault: Dictionary = info.world.vaults[0]
		var door: Vector2i = vault["door"]
		var room: Array = vault["room"]
		var outside: Vector2i = door + (Vector2i.LEFT if room.has(door + Vector2i.RIGHT) else Vector2i.RIGHT)
		var door_px: Vector2 = info.tile_map.to_global(info.tile_map.map_to_local(door))
		player.global_position = info.tile_map.to_global(info.tile_map.map_to_local(outside))
		camera.global_position = door_px
		camera.zoom = Vector2.ONE * 0.28
		camera.reset_smoothing()
		await settle(40)
		await shot("vault_%d_%d_color%d" % [at.x, at.y, int(vault["color"])])
	print("CAPTURED keys by rarity and vaults")
	quit()
