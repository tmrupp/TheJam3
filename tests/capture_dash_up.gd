extends SceneTree
## A strip of an upward dash, frame by frame, close up: how the afterimages are laid and fade.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_dash_up.gd

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
	for i: int in range(30):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.zoom *= 3.0
	var tm: TileMap = main.get_node("TileMap") as TileMap
	var w: Variant = info.world
	var start: Vector2 = player.global_position
	for x: int in range(2, int(w.size.x) - 3):
		var found: bool = false
		for y: int in range(5, int(w.size.y) - 1):
			var v: Vector2i = Vector2i(x, y)
			if not w.ground_below(v):
				continue
			var open: bool = true
			for d: int in range(5):
				if w.get_cell(v - Vector2i(0, d)).type in [MapInfo.Type.GROUND, MapInfo.Type.CRACKED, MapInfo.Type.SPIKES]:
					open = false
			if open:
				start = tm.to_global(tm.map_to_local(v))
				found = true
				break
		if found:
			break
	player.global_position = start
	player.velocity = Vector2.ZERO
	camera.global_position = start + Vector2(0, -120)
	camera.reset_smoothing()
	for i: int in range(30):
		await physics_frame
	player.dash.enable(true)
	player.do_dash(Vector2.UP)
	var frames: Array[Image] = []
	for f: int in range(1, 25):
		await physics_frame
		await process_frame
		if f in [2, 5, 8, 11, 14, 18, 22, 24]:
			frames.append(root.get_texture().get_image().get_region(Rect2i(440, 0, 400, 720)))
	var strip: Image = Image.create(400 * frames.size(), 720, false, frames[0].get_format())
	for k: int in range(frames.size()):
		strip.blit_rect(frames[k], Rect2i(0, 0, 400, 720), Vector2i(k * 400, 0))
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	strip.save_png(out.path_join("dash_up_strip.png"))
	print("CAPTURED dash up strip")
	quit()
