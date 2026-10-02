extends SceneTree
## Close-ups of the interaction prompt over the first lantern through one tap (the hand pressing
## down, the click ripple), and the shrine with two stations touched (only one prompt).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_prompt.gd

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
	for i: int in range(20):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.zoom *= 3.0
	var lamp: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "checkpoint.tscn":
			lamp = n as Node2D
			break
	lamp.get_node("Interactable").set("touching", true)
	player.global_position = lamp.global_position + Vector2(-40, 0)
	var shots: Array[Image] = []
	for f: int in range(40):
		camera.global_position = lamp.global_position + Vector2(0, -90)
		camera.reset_smoothing()
		await process_frame
		if f >= 16 and f % 3 == 0 and shots.size() < 6:
			var crop: Image = root.get_texture().get_image().get_region(Rect2i(560, 140, 150, 150))
			crop.resize(300, 300, Image.INTERPOLATE_NEAREST)
			shots.append(crop)
	var out: Image = Image.create(1800, 300, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(0, 0, 300, 300), Vector2i(k * 300, 0))
	out.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("prompt_hand.png"))
	print("CAPTURED prompt")
	quit()
