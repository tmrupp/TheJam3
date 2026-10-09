extends SceneTree
## The light of the wizard's carried lantern (RisoLight), away from any lit lantern: the warm pool
## while protected, then the dim pink one while unprotected.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_carried_light.gd

const SIZE: Vector2i = Vector2i(640, 480)


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_carried_light.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	# Stand by the deeper exit, far from the lit lantern at the way in.
	player.global_position = info.cell_position(info.world.exits[MapInfo.Exit.DEEPER]) + Vector2(-140, 20)
	var shots: Array[Image] = []
	for vulnerable: bool in [false, true]:
		info.run.vulnerable = vulnerable
		for i: int in range(40):
			camera.global_position = player.global_position
			camera.reset_smoothing()
			await process_frame
		var img: Image = root.get_texture().get_image()
		shots.append(img.get_region(Rect2i((img.get_width() - SIZE.x) / 2, (img.get_height() - SIZE.y) / 2, SIZE.x, SIZE.y)))
	var out: Image = Image.create(SIZE.x * 2, SIZE.y, false, shots[0].get_format())
	for k: int in range(2):
		out.blit_rect(shots[k], Rect2i(Vector2i.ZERO, SIZE), Vector2i(k * SIZE.x, 0))
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	out.save_png(output.path_join("carried_light.png"))
	print("CAPTURED carried light to ", output)
	quit()
