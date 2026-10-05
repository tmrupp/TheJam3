extends SceneTree
## Fresh screenshots of lit/spent lanterns and protection feedback, without touching run saves.

var main: Node
var info: MapInfo
var player: Player
var camera: Camera2D

func _initialize() -> void:
	call_deferred("capture")

func settle() -> void:
	await process_frame
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(12):
		await process_frame
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	info.map_elements.process_mode = Node.PROCESS_MODE_DISABLED

func shot(name: String) -> void:
	while RisoTransition.instance != null and RisoTransition.instance.busy():
		await process_frame
	camera.reset_smoothing()
	# The level is frozen for the capture; refresh the lantern art after its state changes.
	for node: Node in info.map_elements.get_children():
		if node is Checkpoint and node.has_node("RisoArt"):
			node.get_node("RisoArt").call("_redraw")
	for i: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://../art-captures/lantern-death")
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	MapInfo.save_path = "user://lantern_capture.save"
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	await settle()
	camera.zoom = Vector2.ONE * 0.55
	camera.global_position = info.cell_position(info.respawn_cell) + Vector2(0, -45)
	await shot("lit")
	player.collect(8)
	player.global_position += Vector2(300, 0)
	player.die()
	await settle()
	player.invulnerable.end()
	player.global_position += Vector2(-100, 0)
	camera.global_position = info.cell_position(info.respawn_cell) + Vector2(0, -45)
	await shot("spent")
	info.recover_ghost()
	await shot("recovered-still-unprotected")
	for node: Node in info.map_elements.get_children():
		if node is Checkpoint and not info.is_lantern_spent(node):
			info.light_lantern(node)
			camera.global_position = (node as Node2D).global_position + Vector2(0, -45)
			player.global_position = (node as Node2D).global_position
			break
	await shot("another-lantern")
	print("CAPTURED lantern death states")
	quit()
