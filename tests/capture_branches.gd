extends SceneTree
## Stills of going up from the start: the start's way up, a level above the start (its chevrons
## and the sign reading a height), the travel card on the way up, and the worlds map with rows
## above the start.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_branches.gd


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_branches.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	player.set_physics_process(false)
	for i: int in range(40):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("branches_start_way_up.png"))
	# Up through the start's way up, and one more.
	for step: int in range(2):
		info.here.pay(MapInfo.Exit.DEEPER if info.coord.y < 0 else MapInfo.Exit.BACK, info.record())
		info.travel(MapInfo.Exit.DEEPER if info.coord.y < 0 else MapInfo.Exit.BACK)
		# The travel card, part way.
		for i: int in range(14):
			await process_frame
		if step == 1:
			root.get_texture().get_image().save_png(output.path_join("branches_card_up.png"))
		while info.world == null or info.travelling:
			await process_frame
		player.set_physics_process(false)
	for i: int in range(40):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("branches_level_above.png"))
	# Its way on, which leads further up.
	var on: Vector2 = info.cell_position(info.world.exits[MapInfo.Exit.DEEPER])
	player.get_node("CameraControl").set_process(false)
	for i: int in range(30):
		camera.global_position = on + Vector2(0, -60)
		camera.reset_smoothing()
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("branches_way_on_up.png"))
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	map.call("page", 1)
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("branches_worlds_map.png"))
	RunState.delete_save()
	print("CAPTURED branch stills to ", output)
	quit()
