extends SceneTree
## Render garden foliage, F7 equipment and a formerly unsupported hyperspace exit lantern.

var camera: Camera2D
var output: String

func _initialize() -> void:
	call_deferred("capture")

func look(at: Vector2, file: String) -> void:
	camera.global_position = at
	camera.reset_smoothing()
	for i: int in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file))

func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	output = ProjectSettings.globalize_path("res://../art-captures/garden-equipment")
	DirAccess.make_dir_recursive_absolute(output)
	RunState.save_path = "user://capture_garden_equipment.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = MapInfo.instance
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player")
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	camera = main.get_node("Camera2D")
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	var decor: RisoDecor = main.get_node("RisoDecor")
	for kind: StringName in [&"shrub_run", &"leafy"]:
		var plants: Array[Dictionary] = decor.items.filter(func(it: Dictionary) -> bool: return it["kind"] == kind)
		var fenced: Array[Dictionary] = plants.filter(func(it: Dictionary) -> bool:
			return decor.items.any(func(fence: Dictionary) -> bool: return fence["kind"] == &"fence_run" and it["cell"] in fence["cells"]))
		if not fenced.is_empty():
			plants = fenced
		if not plants.is_empty():
			var at: Vector2 = info.cell_position(plants[0]["cell"])
			player.global_position = at + Vector2(140, 0)
			await look(at + Vector2(0, -40), String(kind) + ".png")
	var riso: RisoPrint = RisoPrint.instance
	Abilities.set_tier(player, &"keyring", 3)
	player.keyring.set_all([0, 1, 2, 3])
	player.keyring.set_skeletons(2)
	riso.set_pad_panel(true)
	for i: int in range(3):
		await process_frame
	(riso._options[&"key_0"] as OptionButton).grab_focus()
	var scroll: ScrollContainer = riso.panel.get_child(0)
	scroll.scroll_vertical = maxi(0, int(riso._key_capacity_label.position.y) - 10)
	for i: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("f7-keys.png"))
	riso.set_pad_panel(false)
	info.coord = Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(1, 1))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	while info.travelling:
		await process_frame
	player.set_physics_process(false)
	var lantern: Vector2 = info.cell_position(info.world.exit_lanterns[MapInfo.Exit.DEEPER])
	player.global_position = lantern + Vector2(-180, 0)
	await look(lantern + Vector2(0, -160), "hyperspace-exit-lantern.png")
	RunState.delete_save()
	print("CAPTURED garden, keys and grounded hyperspace lantern")
	quit()
