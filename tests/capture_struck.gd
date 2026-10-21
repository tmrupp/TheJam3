extends SceneTree
## Windowed stills of a wisp struck by a blow that wounds it (Wound.felt, RisoProp.struck): before,
## in the hit-stop, and as it wobbles back to rest.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_struck.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join(name))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_struck.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	for i: int in range(20):
		await process_frame
	player.set_physics_process(false)
	for e: Node in info.map_elements.get_children():
		if e.scene_file_path.get_file() != "mover_enemy.tscn":
			continue
		var wisp: Node2D = e as Node2D
		wisp.get_node("Mover").set("stunned", true)
		(wisp.get_node("Wound") as Wound).hp = 9
		player.global_position = wisp.global_position + Vector2(-400, 0)
		camera.global_position = wisp.global_position
		camera.reset_smoothing()
		for i: int in range(15):
			await process_frame
		shot("still_struck_0_before.png")
		(wisp.get_node("Wound") as Wound).hit(1, Vector2.RIGHT)
		await process_frame
		await process_frame
		shot("still_struck_1_stop.png")
		while Engine.time_scale < 1.0:
			await process_frame
		for i: int in range(3):
			await process_frame
		shot("still_struck_2_wobble.png")
		for i: int in range(5):
			await process_frame
		shot("still_struck_3_wobble.png")
		for i: int in range(20):
			await process_frame
		shot("still_struck_4_rest.png")
		break
	print("CAPTURED struck stills")
	quit()
