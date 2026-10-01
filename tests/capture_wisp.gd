extends SceneTree
## Windowed close-ups of a wisp patrolling and turning round: a contact strip of the turn.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_wisp.gd

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.global_position = Vector2(-9000, -9000)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.zoom *= 3.0
	var wisp: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "mover_enemy.tscn":
			wisp = n as Node2D
			break
	var mover: Node = wisp.get_node("Mover")
	var frames: Array[Image] = []
	for i: int in range(12):
		camera.global_position = wisp.global_position + Vector2(0, -30)
		camera.reset_smoothing()
		await process_frame
	# Wait for the wisp to turn round at a ledge or wall, then record the turn.
	var start_dir: int = int(mover.get("direction"))
	for f: int in range(600):
		camera.global_position = wisp.global_position + Vector2(0, -30)
		camera.reset_smoothing()
		await process_frame
		if int(mover.get("direction")) != start_dir:
			break
	for f: int in range(64):
		camera.global_position = wisp.global_position + Vector2(0, -30)
		camera.reset_smoothing()
		await process_frame
		if f % 8 == 0:
			frames.append(root.get_texture().get_image().get_region(Rect2i(440, 210, 400, 300)))
	var strip: Image = Image.create(400 * 4, 300 * 2, false, frames[0].get_format())
	for k: int in range(mini(8, frames.size())):
		strip.blit_rect(frames[k], Rect2i(0, 0, 400, 300), Vector2i((k % 4) * 400, (k / 4) * 300))
	strip.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("wisp_turn.png"))
	print("CAPTURED wisp turn")
	quit()
