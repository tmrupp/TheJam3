extends SceneTree
## Windowed frames of the wizard walking through grass and flowers: the plants bend and spring
## back. Writes sway_00..sway_NN and a contact strip.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_sway.gd

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
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	camera.zoom *= 2.0
	# The floor cell with the most plants within a few cells, with open floor to walk along.
	var best: Vector2 = Vector2.ZERO
	var best_n: int = -1
	for index: int in decor.swaying:
		var it: Dictionary = decor.items[index]
		if it["hang"]:
			continue
		var a: Vector2 = it["anchor"]
		var n: int = 0
		for other: int in decor.swaying:
			var b: Vector2 = decor.items[other]["anchor"]
			if not decor.items[other]["hang"] and absf(b.y - a.y) < 4.0 and absf(b.x - a.x) < 400.0:
				n += 1
		if n > best_n:
			best_n = n
			best = a
	player.global_position = best + Vector2(-420, -60)
	camera.global_position = best + Vector2(0, -80)
	camera.reset_smoothing()
	for i: int in range(20):
		await physics_frame
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	var frames: Array[Image] = []
	Input.action_press("Right")
	for f: int in range(90):
		await process_frame
		if f == 60:
			Input.action_release("Right")
		if f % 10 == 5:
			var img: Image = root.get_texture().get_image()
			frames.append(img.get_region(Rect2i(240, 160, 800, 400)))
	var strip: Image = Image.create(400 * 3, 200 * 3, false, frames[0].get_format())
	for k: int in range(mini(9, frames.size())):
		var small: Image = frames[k].duplicate()
		small.resize(400, 200)
		strip.blit_rect(small, Rect2i(0, 0, 400, 200), Vector2i((k % 3) * 400, (k / 3) * 200))
	strip.save_png(out.path_join("sway_strip.png"))
	print("CAPTURED sway near ", best_n, " plants")
	quit()
