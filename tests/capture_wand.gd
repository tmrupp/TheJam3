extends SceneTree
## Close-ups of the hat tip (the dash) and the wand (the spell): both ready; dash used; hex just
## cast; hex half recharged.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_wand.gd

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
	camera.zoom *= 4.0
	var hex: Hex = player.get_node("Hex") as Hex
	var shots: Array[Image] = []
	for state: String in ["ready", "dash used", "hex cast", "hex half back"]:
		player.set_physics_process(state != "dash used")
		player.dash.refresh()
		hex.refill()
		match state:
			"dash used":
				player.dash.acted = true
			"hex cast":
				hex.cast(Vector2.UP)
			"hex half back":
				hex.charges = 0
				hex.recharge = Hex.COOLDOWN * 0.5
		for i: int in range(40 if state == "hex cast" else 4):
			camera.global_position = player.global_position + Vector2(0, -30)
			camera.reset_smoothing()
			await process_frame
		shots.append(root.get_texture().get_image().get_region(Rect2i(440, 110, 400, 400)))
		if state == "hex half back":
			hex.recharge = Hex.COOLDOWN * 0.5
	var strip: Image = Image.create(1600, 400, false, shots[0].get_format())
	for k: int in range(shots.size()):
		strip.blit_rect(shots[k], Rect2i(0, 0, 400, 400), Vector2i(k * 400, 0))
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	strip.save_png(out.path_join("hat_and_wand.png"))
	print("CAPTURED hat and wand")
	quit()
