extends SceneTree
## Windowed stills of phase 2: the ghost, the vulnerable wizard and HUD, and the end-of-run card.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_death.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(output: String, name: String, frames: int = 20) -> void:
	for i: int in range(frames):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join(name))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_death.save"
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	DirAccess.make_dir_recursive_absolute(output)
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(10):
		await process_frame
	menu.start_game()
	for i: int in range(10):
		await process_frame
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	for i: int in range(30):
		await process_frame
	# Die away from the lantern (on a star's spot), so the ghost and the respawn are apart.
	var spot: Vector2 = player.global_position
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "coin.tscn" and (node as Node2D).global_position.distance_to(player.global_position) > 600.0:
			spot = (node as Node2D).global_position
			break
	player.collect(6)
	player.global_position = spot
	player.die()
	for i: int in range(30):
		await process_frame
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.set_physics_process(false)
	camera.zoom *= 2.0
	camera.global_position = info.ghost_pos
	camera.reset_smoothing()
	await shot(output, "still_ghost.png", 40)
	camera.zoom *= 1.5
	camera.global_position = player.global_position + Vector2(0, -40)
	camera.reset_smoothing()
	# Freeze the level (a watcher keeps shooting) so the still is not caught mid hurt-flash.
	info.map_elements.process_mode = Node.PROCESS_MODE_DISABLED
	for i: int in range(30):
		await process_frame
	player.invulnerable.end()
	await shot(output, "still_vulnerable.png", 3)
	camera.zoom /= 1.5
	info.map_elements.process_mode = Node.PROCESS_MODE_INHERIT
	camera.zoom /= 2.0
	player.get_node("CameraControl").set_process(true)
	player.set_physics_process(true)
	# The ghost in another world: the HUD names it.
	info.travel(MapInfo.Exit.RIGHT)
	while info.travelling:
		await process_frame
	player.set_meta(&"carried_key", 1)
	await shot(output, "still_hud_elsewhere.png", 30)
	player.die()
	await shot(output, "still_run_end.png", 40)
	print("CAPTURED death stills to ", output)
	quit()
