extends SceneTree
## Windowed stills of phase 7: a hex bolt in flight toward a wisp, and a cracked wall before and
## after it breaks.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_hex.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join(name))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_hex.save"
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
	# A wisp with open ground to its left: stand there and cast at it.
	for e: Node in info.map_elements.get_children():
		if e.scene_file_path.get_file() != "mover_enemy.tscn":
			continue
		var c: Vector2i = e.get_meta(&"cell")
		if info.world.get_cell(c + Vector2i(-2, 0)).type == MapInfo.Type.GROUND or info.world.get_cell(c + Vector2i(-1, 0)).type == MapInfo.Type.GROUND:
			continue
		e.get_node("Mover").set("stunned", true)
		player.global_position = (e as Node2D).global_position + Vector2(-260, 0)
		camera.global_position = (e as Node2D).global_position + Vector2(-130, -40)
		camera.reset_smoothing()
		for i: int in range(10):
			await process_frame
		(player.get_node("Hex") as Hex).cast(Vector2.RIGHT)
		for i: int in range(6):
			await physics_frame
		await process_frame
		shot("still_hex_bolt.png")
		for i: int in range(20):
			await process_frame
		shot("still_hex_after.png")
		break
	# A cracked wall, before and after.
	for w: Node in info.map_elements.get_children():
		if w.scene_file_path.get_file() != "cracked_wall.tscn":
			continue
		camera.global_position = (w as Node2D).global_position
		camera.reset_smoothing()
		for i: int in range(15):
			await process_frame
		shot("still_cracked.png")
		w.call("hex_hit", 1, Vector2.RIGHT)
		for i: int in range(6):
			await process_frame
		shot("still_cracked_break.png")
		break
	print("CAPTURED hex stills")
	quit()
