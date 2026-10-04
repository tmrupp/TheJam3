extends SceneTree
## Windowed stills of a level's corner (the border rock) and its map, at depth 0 and deeper.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_border.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(name: String, frames: int = 20) -> void:
	for i: int in range(frames):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join(name))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_border.save"
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
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	# Top-left corner of the level: the camera stops at the border.
	camera.global_position = info.cell_position(Vector2i(0, 0))
	camera.reset_smoothing()
	await shot("border_corner.png")
	var map: Node = main.get_node("RisoMap")
	info.ink_whole_map()
	map.call("toggle")
	await shot("border_map_d0.png", 10)
	map.call("close")
	info.coord = Vector2i(28, 5)
	info.travel(MapInfo.Exit.DEEPER)
	while info.travelling:
		await process_frame
	player.set_physics_process(false)
	info.ink_whole_map()
	map.call("toggle")
	await shot("border_map_d6.png", 10)
	print("CAPTURED border sizes ", MapInfo.level_size(0), " ", info.world.size)
	quit()
