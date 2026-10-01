extends SceneTree
## A/B stills of the print texture: the same frozen frames with the old print (pure dots, even
## solids, no streaks or fibre) and the current defaults, side by side, plus close-ups.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_print.gd

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
	var riso: RisoPrint = RisoPrint.instance
	riso.sheet_rate = 0.0
	riso.reprint_on_motion = false
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.global_position = player.global_position
	var defaults: Array[float] = [riso.grain_touch, riso.mottle, riso.streak, riso.fibre]
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	var shots: Array[Image] = []
	for variant: Array in [[0.0, 0.0, 0.0, 0.0], defaults]:
		riso.grain_touch = variant[0]
		riso.mottle = variant[1]
		riso.streak = variant[2]
		riso.fibre = variant[3]
		for i: int in range(8):
			await process_frame
		shots.append(root.get_texture().get_image())
	shots[0].save_png(out.path_join("print_old.png"))
	shots[1].save_png(out.path_join("print_new.png"))
	for k: int in range(2):
		var zoom: Image = shots[k].get_region(Rect2i(420, 200, 320, 180))
		zoom.resize(960, 540, Image.INTERPOLATE_NEAREST)
		zoom.save_png(out.path_join("print_%s_zoom.png" % ["old", "new"][k]))
	print("CAPTURED print A/B")
	quit()
