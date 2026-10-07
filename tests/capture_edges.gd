extends SceneTree
## Windowed stills: the wizard standing at a ledge's very end, grass and mushroom variety, and a
## watcher's eye opening as it watches.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_edges.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(name: String, frames: int = 15) -> void:
	for i: int in range(frames):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join(name))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_edges.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	camera.zoom *= 2.0
	var w: LevelGen = info.world
	# A floor cell whose right neighbour drops away: stand at its very end.
	for v: Vector2i in w.grounds:
		var above: Vector2i = v + Vector2i.UP
		if w.is_valid(above) and not w.is_ground(above) and not w.is_ground(v + Vector2i.RIGHT) and not w.is_ground(v + Vector2i(1, -1)) and not w.is_ground(v + Vector2i(1, 1)) and v.x > 2:
			player.global_position = info.cell_position(above) + Vector2(50, 0)
			camera.global_position = info.cell_position(v)
			camera.reset_smoothing()
			break
	await shot("edge_ledge.png", 40)
	# The spot with the most mushrooms and grass on screen.
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
	var best: Vector2 = Vector2.ZERO
	var best_n: int = -1
	for it: Dictionary in decor.items:
		if it["kind"] != &"mushroom":
			continue
		var a: Vector2 = info.cell_position(it["cell"])
		var n: int = 0
		for other: Dictionary in decor.items:
			if other["kind"] in [&"mushroom", &"tuft"] and info.cell_position(other["cell"]).distance_to(a) < 500.0:
				n += 1
		if n > best_n:
			best_n = n
			best = a
	player.global_position = best + Vector2(-2000, -2000)
	camera.global_position = best
	camera.reset_smoothing()
	await shot("edge_plants.png", 20)
	# A watcher in view: the eye opening.
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() != "shooter_enemy.tscn":
			continue
		var c: Vector2i = n.get_meta(&"cell")
		for d: int in [-1, 1]:
			if not w.is_ground(c + Vector2i(d, 0)) and not w.is_ground(c + Vector2i(2 * d, 0)):
				camera.global_position = (n as Node2D).global_position + Vector2(d * 120, -40)
				camera.reset_smoothing()
				player.global_position = info.cell_position(c + Vector2i(2 * d, 0))
				player.set_physics_process(false)
				await shot("eye_0.png", 4)
				await shot("eye_1.png", 50)
				await shot("eye_2.png", 70)
				player.global_position = Vector2(-9000, -9000)
				await shot("eye_3.png", 40)
				print("CAPTURED edges")
				quit()
				return
	quit()
