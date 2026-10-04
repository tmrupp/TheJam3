extends SceneTree
## Stills of the dash afterimages mid-dash: sideways, straight up and diagonally up, in the main game.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_dash.gd

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_dash.save"
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
	camera.zoom *= 2.5
	# A floor cell with open air for three cells above it and one to the right, so every dash
	# runs its full length.
	var tm: TileMap = main.get_node("TileMap") as TileMap
	var start: Vector2 = player.global_position
	var w: Variant = info.world
	# Away from lanterns, whose light pool washes out the afterimages.
	var lamps: Array[Vector2] = []
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "checkpoint.tscn":
			lamps.append((n as Node2D).global_position)
	for x: int in range(2, int(w.size.x) - 3):
		var found: bool = false
		for y: int in range(4, int(w.size.y) - 1):
			var v: Vector2i = Vector2i(x, y)
			if not w.ground_below(v):
				continue
			var open: bool = true
			for d: Vector2i in [Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -2), Vector2i(0, -3), Vector2i(1, 0), Vector2i(1, -1), Vector2i(1, -2)]:
				if w.get_cell(v + d).type in [MapInfo.Type.GROUND, MapInfo.Type.CRACKED, MapInfo.Type.SPIKES]:
					open = false
			var at: Vector2 = tm.to_global(tm.map_to_local(v))
			if open and lamps.all(func(l: Vector2) -> bool: return l.distance_to(at) > 450.0):
				start = at
				found = true
				break
		if found:
			break
	var shots: Array[Image] = []
	for dir: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2(1, -1).normalized()]:
		player.global_position = start
		player.velocity = Vector2.ZERO
		for i: int in range(20):
			await physics_frame
		camera.global_position = start + dir * 70.0 + Vector2(0, -60)
		camera.reset_smoothing()
		player.dash.enable(true)
		player.do_dash(dir)
		for i: int in range(9):
			await physics_frame
		await process_frame
		shots.append(root.get_texture().get_image().get_region(Rect2i(340, 80, 600, 560)))
	var strip: Image = Image.create(1800, 560, false, shots[0].get_format())
	for k: int in range(shots.size()):
		strip.blit_rect(shots[k], Rect2i(0, 0, 600, 560), Vector2i(k * 600, 0))
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	DirAccess.make_dir_recursive_absolute(out)
	strip.save_png(out.path_join("dash_afterimages.png"))
	print("CAPTURED dash afterimages")
	quit()
