extends SceneTree
## A/B/C stills of paper at edges: the same frozen frames printed with different tint punch and
## trap settings, written as side-by-side strips.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_rims.gd

const VARIANTS: Array[Array] = [[1.0, 0.0, "A"], [0.4, 0.8, "B"], [0.0, 1.2, "C"]]
## A is the old look; B is the default now.


func _initialize() -> void:
	call_deferred("capture")


func reprint(main: Node, info: MapInfo) -> void:
	RisoPrint.instance.world_built(info, info.coord.y)
	for node: Node in get_nodes_in_group(&"riso_art"):
		if node.has_method("_redraw"):
			node.call("_redraw")


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
	var riso: RisoPrint = RisoPrint.instance
	riso.sheet_rate = 0.0
	riso.reprint_on_motion = false
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	var scenes: Array[Vector2] = [player.global_position]
	for want: String in ["shrine.tscn", "level_exit.tscn", "mover_enemy.tscn"]:
		for n: Node in info.map_elements.get_children():
			if n.scene_file_path.get_file() == want:
				scenes.append((n as Node2D).global_position)
				break
	for si: int in range(scenes.size()):
		var shots: Array[Image] = []
		for v: Array in VARIANTS:
			riso.tint_punch = float(v[0])
			riso.trap = float(v[1])
			InkCanvas.tint_punch = float(v[0])
			player.global_position = scenes[si] + Vector2(-150, 0)
			camera.global_position = scenes[si]
			for i: int in range(3):
				await process_frame
			reprint(main, info)
			for i: int in range(6):
				await process_frame
			var img: Image = root.get_texture().get_image()
			img.save_png(out.path_join("rims_%d_%s.png" % [si, v[2]]))
			shots.append(img.get_region(Rect2i(400, 180, 480, 360)))
		var strip: Image = Image.create(480 * 3 + 16, 360, false, shots[0].get_format())
		strip.fill(Color.WHITE)
		for k: int in range(3):
			strip.blit_rect(shots[k], Rect2i(Vector2i.ZERO, shots[k].get_size()), Vector2i(k * 488, 0))
		strip.save_png(out.path_join("rims_strip_%d.png" % si))
	print("CAPTURED rims strips: ", scenes.size())
	quit()
