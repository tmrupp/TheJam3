extends "res://tests/interaction_hints_test.gd"
## Stills: the skeleton key (a bone-white bone with teeth) beside the coloured keys, a bone gate
## with the wizard at it, the wizard's chain carrying skeleton keys, and a shrine selling one.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_bones.gd

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	output = ProjectSettings.globalize_path("res://../art-captures/bones")
	DirAccess.make_dir_recursive_absolute(output)
	RunState.save_path = "user://capture_bones.save"
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
	for color: int in [0, 1, 2, 3, KeyRing.SKELETON]:
		var key: Node2D = load("res://prefabs/key.tscn").instantiate()
		key.set_meta(&"key_color", color)
		key.position = base + Vector2((float(keys.size()) - 2.0) * 60.0, 0)
		info.map_elements.add_child(key)
		keys.append(key)
	await settle(40)
	await shot("keys_and_bone")
	for key: Node2D in keys:
		key.queue_free()
	# The chain: two coloured keys and two skeleton keys.
	player.keyring.set_all([0, 2])
	player.keyring.set_skeletons(2)
	Abilities.set_tier(player, &"keyring", 1)
	player.keyring.set_all([0, 2])
	var floor_at: Vector2 = info.respawn_marker.global_position
	player.global_position = floor_at
	player.set_physics_process(true)
	camera.global_position = floor_at + Vector2(0, -40)
	camera.zoom = Vector2.ONE * 0.6
	camera.reset_smoothing()
	await settle(60)
	player.set_physics_process(false)
	await shot("chain_with_bones")
	# A bone gate: the first level along with a bone vault.
	var target: Vector2i = Vector2i(-1, -1)
	for x: int in range(28, 400):
		if MapInfo.bone_vault_at(Vector2i(x, 1)) and Relics.at(Vector2i(x, 1)) == &"":
			target = Vector2i(x, 1)
			break
	info.coord = target
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await loaded()
	for vault: Dictionary in info.world.vaults:
		if int(vault["color"]) != KeyRing.SKELETON:
			continue
		var door: Vector2i = vault["door"]
		var room: Array = vault["room"]
		var outside: Vector2i = door + (Vector2i.LEFT if room.has(door + Vector2i.RIGHT) else Vector2i.RIGHT)
		player.global_position = info.cell_position(outside)
		camera.global_position = info.cell_position(door)
		camera.zoom = Vector2.ONE * 0.3
		camera.reset_smoothing()
		await settle(40)
		await shot("bone_gate")
		camera.zoom = Vector2.ONE * 0.8
		camera.reset_smoothing()
		await settle(10)
		await shot("bone_gate_close")
		break
	# A shrine selling a skeleton key: at full health, with no relic left to point to.
	for dx: int in range(-Relics.SEARCH - 1, Relics.SEARCH + 2):
		for dy: int in range(0, Relics.SEARCH + 2):
			info.run.relics_found[Vector2i(info.coord.x + dx, dy)] = true
	player.health.health = player.health.max_health
	player.keyring.clear()
	var shrine: Node2D = first("shrine.tscn")
	if shrine != null:
		var mend: Node2D = shrine.get_node("Mend") as Node2D
		player.global_position = mend.global_position + Vector2(70, 0)
		camera.global_position = mend.global_position + Vector2(0, -80)
		camera.zoom = Vector2.ONE * 0.5
		camera.reset_smoothing()
		await settle(50)
		await shot("shrine_skeleton")
	print("CAPTURED bone key, chain, gate and shrine")
	quit()
