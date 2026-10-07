extends SceneTree
## The same frame printed with trapped plates (left) and independent plates (right), over a 3x
## close-up of each, held on one sheet so only the plate setting differs.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_plates.gd

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_plates.save"
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
	player.set_physics_process(false)
	var riso: RisoPrint = RisoPrint.instance
	riso.sheet_rate = 0.0
	var shots: Array[Image] = []
	for trap: bool in [true, false]:
		riso.trapped = trap
		for i: int in range(6):
			await process_frame
		shots.append(root.get_texture().get_image())
	var out: Image = Image.create(1280, 840, false, shots[0].get_format())
	# The wizard and the ledge's edge against the night.
	var crop: Rect2i = Rect2i(620, 90, 213, 160)
	for k: int in range(2):
		var half: Image = shots[k].duplicate() as Image
		half.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(half, Rect2i(0, 0, 640, 360), Vector2i(k * 640, 0))
		var close: Image = shots[k].get_region(crop)
		close.resize(639, 480, Image.INTERPOLATE_NEAREST)
		out.blit_rect(close, Rect2i(0, 0, 639, 480), Vector2i(k * 640, 360))
	var path: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	DirAccess.make_dir_recursive_absolute(path)
	out.save_png(path.path_join("plates_trapped_vs_independent.png"))
	print("CAPTURED plates comparison")
	quit()
