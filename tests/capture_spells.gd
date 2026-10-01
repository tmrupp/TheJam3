extends SceneTree
## Windowed stills: the ink well, awareness pointers, levitating, a plant mid-sway, and the map's
## page tabs.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_spells.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(name: String, frames: int = 12) -> void:
	for i: int in range(frames):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join(name))


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
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	for i: int in range(20):
		await process_frame
	player.collect(20)
	# The ink well, close up.
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "inkwell.tscn":
			player.global_position = (n as Node2D).global_position + Vector2(-200, 0)
			camera.global_position = (n as Node2D).global_position + Vector2(0, -60)
			camera.reset_smoothing()
	await shot("spell_inkwell.png", 30)
	# Awareness III, pinged, back near the spawn.
	for i: int in range(3):
		Abilities.grant(player, &"awareness")
	player.global_position = info.cell_position(info.world.exits[MapInfo.Exit.BACK])
	camera.global_position = player.global_position
	camera.reset_smoothing()
	await shot("spell_none.png", 10)
	Abilities.cast(player)
	await shot("spell_awareness.png", 10)
	# Levitating in mid air.
	Abilities.grant(player, &"levitate")
	player.global_position += Vector2(0, -200)
	player.velocity = Vector2.ZERO
	await shot("x.png", 2)
	Abilities.cast(player)
	await shot("spell_levitate.png", 10)
	# The map, worlds page.
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	await shot("spell_map_level.png", 10)
	map.call("page", 1)
	await shot("spell_map_worlds.png", 10)
	print("CAPTURED spells")
	quit()
