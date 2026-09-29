extends SceneTree
## Windowed capture of the riso print in the generated main game (seed 28).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_riso.gd
## python tests/encode_art_gif.py ../art-captures/riso-frames ../art-captures/riso-game.gif

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	DirAccess.make_dir_recursive_absolute(output)
	for f: String in DirAccess.get_files_at(output):
		DirAccess.remove_absolute(output.path_join(f))
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.map_seed.text = "28"
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_menu.png"))
	menu.start_game()
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_upgrade.png"))
	main.get_node("UpgradeMenu").done()
	var info: Node = main.get_node("CanvasLayer/MapInfo")
	var deadline: int = Time.get_ticks_msec() + 20000
	while info.world == null and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(30):
		await process_frame
	var saved: int = 0
	for frame: int in range(360):
		var time: float = float(frame) / 60.0
		var right: bool = time > 0.5 and time < 5.5
		if right:
			Input.action_press("Right")
		else:
			Input.action_release("Right")
		if frame in [70, 150, 230]:
			Input.action_press("Jump")
		if frame in [95, 175, 255]:
			Input.action_release("Jump")
		if frame == 120 or frame == 290:
			Input.action_press("Dash")
		if frame == 124 or frame == 294:
			Input.action_release("Dash")
		await process_frame
		if frame % 4 == 0:
			var img: Image = root.get_texture().get_image()
			img.save_png(output.path_join("frame_%03d.png" % saved))
			saved += 1
	Input.action_release("Right")
	print("CAPTURED ", saved, " frames to ", output)
	menu.pause_resume_game()
	for i: int in range(6):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_pause.png"))
	menu.pause_resume_game()
	await process_frame
	# Stills framed on the props that must sit on the ground.
	var player: Node2D = main.get_node("Player") as Node2D
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var wanted: Dictionary = {"door.tscn": "door", "spikes.tscn": "spikes", "checkpoint.tscn": "lantern", "goal.tscn": "gate"}
	var lit_one: bool = false
	for node: Node in info.map_elements.get_children():
		var file: String = node.scene_file_path.get_file()
		if not wanted.has(file):
			continue
		var target: Node2D = node as Node2D
		var label: String = wanted[file]
		wanted.erase(file)
		if file == "checkpoint.tscn" and not lit_one:
			player.set("respawn", target)
			lit_one = true
		player.global_position = target.global_position + Vector2(-220, -40)
		camera.global_position = target.global_position
		camera.reset_smoothing()
		for i: int in range(20):
			await process_frame
		root.get_texture().get_image().save_png(output.path_join("still_%s.png" % label))
	quit()
