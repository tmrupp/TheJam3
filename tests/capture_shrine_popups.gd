extends SceneTree
## Stills of the shrine's pop-up labels: the wizard away from it, then at each offer in turn.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_shrine_popups.gd

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	DirAccess.make_dir_recursive_absolute(output)
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(20):
		await process_frame
	menu.start_game()
	var info: Node = main.get_node("CanvasLayer/MapInfo")
	var deadline: int = Time.get_ticks_msec() + 20000
	while info.world == null and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(30):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.health.health = 1
	player.collect(40)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	for item: Node in info.map_elements.get_children():
		if item.scene_file_path.get_file() != "shrine.tscn":
			continue
		var shrine: Node2D = item as Node2D
		camera.global_position = shrine.global_position + Vector2(128, -40)
		camera.reset_smoothing()
		for spot: String in ["away", "Boon", "Boon2", "Mend"]:
			var at: Vector2 = shrine.global_position + Vector2(-260, 0) if spot == "away" else (shrine.get_node(spot) as Node2D).global_position
			player.global_position = at
			for i: int in range(30):
				await process_frame
			root.get_texture().get_image().save_png(output.path_join("shrine_%s.png" % spot.to_lower()))
		break
	print("CAPTURED shrine pop-ups to ", output)
	quit()
