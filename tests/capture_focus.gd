extends SceneTree
## Close-ups of each spell focus (wand, orb, book, hand), ready (top) and half recharged
## (bottom), and a stunned wisp.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_focus.gd

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
	for i: int in range(40):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var base_zoom: Vector2 = camera.zoom
	camera.zoom = base_zoom * 4.0
	var hex: Hex = player.get_node("Hex") as Hex
	var out_img: Image = null
	var k: int = 0
	for focus: StringName in RisoPrint.FOCI:
		RisoPrint.instance.spell_focus = focus
		for half: bool in [false, true]:
			hex.refill()
			if half:
				hex.charges = 0
			for i: int in range(6):
				if half:
					hex.recharge = Hex.COOLDOWN * 0.5
				camera.global_position = player.global_position + Vector2(0, -30)
				camera.reset_smoothing()
				await process_frame
			var shot: Image = root.get_texture().get_image().get_region(Rect2i(440, 110, 400, 400))
			if out_img == null:
				out_img = Image.create(1600, 1200, false, shot.get_format())
			out_img.blit_rect(shot, Rect2i(0, 0, 400, 400), Vector2i(k * 400, 400 if half else 0))
		k += 1
	# A stunned wisp.
	camera.zoom = base_zoom * 2.0
	var wisp: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "mover_enemy.tscn":
			wisp = n as Node2D
			break
	wisp.get_node("Stunner").call("stun", 3.0)
	for i: int in range(20):
		camera.global_position = wisp.global_position + Vector2(0, -40)
		camera.reset_smoothing()
		await process_frame
	var stun: Image = root.get_texture().get_image().get_region(Rect2i(340, 60, 600, 400))
	stun.resize(600, 400)
	out_img.blit_rect(stun, Rect2i(0, 0, 600, 400), Vector2i(0, 800))
	# And the HUD's flame.
	var hud: Image = root.get_texture().get_image().get_region(Rect2i(0, 0, 500, 120))
	hud.resize(1000, 240, Image.INTERPOLATE_NEAREST)
	out_img.blit_rect(hud, Rect2i(0, 0, 1000, 240), Vector2i(600, 880))
	var path: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	out_img.save_png(path.path_join("spell_foci.png"))
	print("CAPTURED spell foci")
	quit()
