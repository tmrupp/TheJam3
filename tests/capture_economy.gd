extends SceneTree
## Stills for groups 7 and 8: a star cluster, a skeleton key, the lit lantern that can be burned
## into the mend spell (with the HUD showing a full keyring and skeleton keys), and the pause menu
## with Give up.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_economy.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(camera: Camera2D, at: Vector2) -> Image:
	for i: int in range(25):
		camera.global_position = at + Vector2(0, -80)
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (at + Vector2(0, -80)))
	var x: int = clampi(int(sp.x) - 250, 0, 780)
	var y: int = clampi(int(sp.y) - 250, 0, 220)
	return root.get_texture().get_image().get_region(Rect2i(x, y, 500, 500))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_capture.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	for i: int in range(60):
		await process_frame
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	var shots: Array[Image] = []
	# The star cluster, the wizard beside it.
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "star_cluster.tscn":
			player.global_position = (n as Node2D).global_position + Vector2(-110, 40)
			shots.append(await shot(camera, (n as Node2D).global_position))
			break
	# A skeleton key beside a coloured key.
	var at: Vector2 = player.global_position + Vector2(140, 0)
	for k: Array in [[KeyRing.SKELETON, Vector2(0, 0)], [2, Vector2(90, 0)]]:
		var key: Node2D = (load("res://prefabs/key.tscn") as PackedScene).instantiate()
		key.set_meta(&"key_color", int(k[0]))
		key.position = at + (k[1] as Vector2)
		info.map_elements.add_child(key)
	shots.append(await shot(camera, at + Vector2(45, 0)))
	# The lit start lantern, burnable: mend II with a draught gone. The HUD shows a keyring III's keys
	# and two skeleton keys.
	Abilities.grant(player, &"keyring")
	Abilities.grant(player, &"keyring")
	Abilities.grant(player, &"keyring")
	KeyRing.set_all(player, [0, 1, 2, 3])
	KeyRing.set_skeletons(player, 2)
	Abilities.grant(player, &"mend")
	Abilities.grant(player, &"mend")
	player.set_meta(&"mend_draughts", 1)
	var lantern: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n is Checkpoint and info.is_respawn_lantern(n):
			lantern = n as Node2D
	if lantern != null:
		player.global_position = lantern.global_position + Vector2(70, 0)
		shots.append(await shot(camera, lantern.global_position))
	var strip: Image = Image.create(500 * shots.size(), 500, false, shots[0].get_format())
	for k: int in range(shots.size()):
		strip.blit_rect(shots[k], Rect2i(0, 0, 500, 500), Vector2i(k * 500, 0))
	strip.save_png(output.path_join("economy.png"))
	# The whole screen, for the HUD.
	root.get_texture().get_image().save_png(output.path_join("economy_hud.png"))
	# The pause menu, with Give up.
	menu.call("pause_resume_game")
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("economy_menu.png"))
	menu.call("pause_resume_game")
	# The level map's legend, with the new marks.
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("economy_map.png"))
	MapInfo.delete_save()
	print("CAPTURED economy stills to ", output)
	quit()
