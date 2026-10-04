extends SceneTree
## Stills: a switch gate, its switch before and after it is thrown, and a hyperspace door.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_switches.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(camera: Camera2D, at: Vector2) -> Image:
	for i: int in range(25):
		camera.global_position = at + Vector2(0, -80)
		camera.reset_smoothing()
		await process_frame
	# Centred on the thing on screen (the camera stops at the level's edge).
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (at + Vector2(0, -80)))
	var x: int = clampi(int(sp.x) - 250, 0, 780)
	var y: int = clampi(int(sp.y) - 250, 0, 220)
	return root.get_texture().get_image().get_region(Rect2i(x, y, 500, 500))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	await process_frame
	# A world whose depth 1 deals a hyperspace door.
	var world_seed: int = 1
	while MapInfo.level_seed(MapInfo.def_for(Vector2i(world_seed, 1)).gen_seed, 777) % 100 >= MapInfo.PLUNGE_CHANCE:
		world_seed += 1
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = str(world_seed)
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.global_position = Vector2(-9000, -9000)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var shots: Array[Image] = []
	var lever: Node2D = null
	var gate: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "switch.tscn":
			lever = n as Node2D
		elif n.scene_file_path.get_file() == "switch_gate.tscn":
			gate = n as Node2D
	shots.append(await shot(camera, gate.global_position))
	shots.append(await shot(camera, lever.global_position))
	lever.call("flip")
	shots.append(await shot(camera, lever.global_position))
	info.travel(MapInfo.Exit.DEEPER)
	await process_frame
	while info.world == null or info.travelling:
		await process_frame
	player.set_physics_process(false)
	player.global_position = Vector2(-9000, -9000)
	for i: int in range(90):
		await process_frame
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "level_exit.tscn" and int(n.get("exit")) == MapInfo.Exit.PLUNGE:
			var art: Node = n.get_node_or_null("RisoArt")
			shots.append(await shot(camera, (n as Node2D).global_position))
	var out: Image = Image.create(500 * shots.size(), 500, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(0, 0, 500, 500), Vector2i(k * 500, 0))
	out.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("switches_and_jump.png"))
	print("CAPTURED switches and hyperspace door")
	quit()
