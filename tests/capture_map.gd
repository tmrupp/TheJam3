extends SceneTree
## Windowed stills of the printed map: the level view and the world view (seed 28).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_map.gd

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
	var player: Player = main.get_node("Player") as Player
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	# A little history: some of the level seen, a lantern lit, doors opened to the side and deeper.
	player.set_physics_process(false)
	info.ink_whole_map()
	for which: int in [MapInfo.Exit.DEEPER, MapInfo.Exit.RIGHT]:
		info.reveal(info.world.exits[which], 4)
	info.record()["lateral_open"][MapInfo.Exit.RIGHT] = true
	info.record()["deeper_paid"] = true
	for step: int in [MapInfo.Exit.RIGHT, MapInfo.Exit.DEEPER, MapInfo.Exit.BACK, MapInfo.Exit.LEFT]:
		info.travel(step)
		while info.travelling:
			await process_frame
		player.set_physics_process(false)
		for i: int in range(3):
			await physics_frame
	for i: int in range(10):
		await process_frame
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_map_level.png"))
	map.call("page", 1)
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_map_world.png"))
	print("CAPTURED map stills to ", output)
	quit()
