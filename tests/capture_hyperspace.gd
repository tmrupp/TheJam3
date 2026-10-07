extends SceneTree
## Windowed stills of hyperspace: its way in, a stretch of hazards, its level map and its
## tile on the worlds map.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_hyperspace.gd

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_hyperspace.save"
	var menu: Node = main.get_node("Menu")
	var seed_value: int = 4
	for s: int in range(1, 120):
		if Rules.level_seed(Rules.def_for(Vector2i(s, 1)).gen_seed, 777) % 100 < Hyperspace.CHANCE:
			seed_value = s
			break
	menu.world_seed.text = str(seed_value)
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	var player: Player = main.get_node("Player") as Player
	while info.world == null or info.travelling:
		await process_frame
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	info.travel(MapInfo.Exit.DEEPER)
	while info.travelling or info.world == null:
		await process_frame
	info.here.pay(Worlds.door(Worlds.kind_of(Hyperspace)), info.record())
	info.travel(Worlds.door(Worlds.kind_of(Hyperspace)))
	while info.travelling:
		await process_frame
	for i: int in range(40):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_hyperspace_start.png"))
	player.set_physics_process(false)
	for x: int in [Hyperspace.WIDTH / 4, Hyperspace.WIDTH * 2 / 5, Hyperspace.WIDTH * 3 / 5, Hyperspace.WIDTH * 3 / 4]:
		player.global_position = info.cell_position(Vector2i(x, Hyperspace.FLOOR - 4))
		var camera: Camera2D = main.get_node("Camera2D") as Camera2D
		camera.position = player.global_position
		for n: Node in player.get_children():
			if n.get("target_location") != null:
				n.set("target_location", player.global_position)
		for i: int in range(20):
			await process_frame
		root.get_texture().get_image().save_png(output.path_join("still_hyperspace_%d.png" % x))
	info.ink_whole_map()
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_hyperspace_map_level.png"))
	map.call("page", 1)
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_hyperspace_map_world.png"))
	# Through the gate, so the worlds page shows hyperspace joined to the levels at both ends.
	map.call("toggle")
	for i: int in range(5):
		await process_frame
	info.travel(MapInfo.Exit.DEEPER)
	while info.travelling:
		await process_frame
	for i: int in range(20):
		await process_frame
	map.call("toggle")
	map.call("page", 1)
	map.set("selected", Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(seed_value, 1)))
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("still_hyperspace_map_joined.png"))
	print("CAPTURED hyperspace stills to ", output)
	quit()
