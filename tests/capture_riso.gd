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
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.map_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	main.get_node("UpgradeMenu").done()
	var info: Node = main.get_node("CanvasLayer/MapInfo")
	var deadline: int = Time.get_ticks_msec() + 20000
	while info.world == null and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(30):
		await process_frame
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	DirAccess.make_dir_recursive_absolute(output)
	for f: String in DirAccess.get_files_at(output):
		DirAccess.remove_absolute(output.path_join(f))
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
	quit()
