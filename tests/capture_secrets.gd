extends SceneTree
## Stills: a secret room's false wall with the wizard beside it, the room once opened (relic and
## stars), an astral projection inside rock, and both map pages after an ink well's relic hint.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_secrets.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(camera: Camera2D, at: Vector2) -> Image:
	for i: int in range(25):
		camera.global_position = at + Vector2(0, -80)
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (at + Vector2(0, -80)))
	var x: int = clampi(int(sp.x) - 250, 0, 780)
	var y: int = clampi(int(sp.y) - 250, 0, 220)
	return root.get_texture().get_image().get_region(Rect2i(x, y, 500, 500))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_secrets.save"
	await process_frame
	# A world whose depth 1 holds a relic.
	var world_seed: int = 1
	while Relics.at(Vector2i(world_seed, 1)) == &"":
		world_seed += 1
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = str(world_seed)
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.collect(200)
	info.travel(MapInfo.Exit.DEEPER)
	await process_frame
	while info.world == null or info.travelling:
		await process_frame
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	for i: int in range(90):
		await process_frame
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var secret: Dictionary = info.world.secrets[0]
	var door: Vector2i = secret["entrance"][0]
	var beside: Vector2i = door + Vector2i.LEFT
	if not info.world.is_valid(beside) or info.world.get_cell(beside).type == MapInfo.Type.GROUND or info.world.get_cell(beside).type == MapInfo.Type.CRACKED:
		beside = door + Vector2i.RIGHT
	var middle: Vector2 = (info.cell_position(door) + info.cell_position(secret["room"][0])) * 0.5
	player.global_position = info.cell_position(beside)
	var shots: Array[Image] = []
	shots.append(await shot(camera, middle))
	player.global_position = info.cell_position(door)
	for i: int in range(4):
		await physics_frame
	player.global_position = info.cell_position(beside)
	shots.append(await shot(camera, middle))
	# Up to the relic: its pop-up.
	var relic: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "relic.tscn":
			relic = n as Node2D
	if relic != null:
		player.global_position = relic.global_position + Vector2(-90, 0)
		shots.append(await shot(camera, relic.global_position))
	# Its pop-up, price and all.
	if relic != null:
		player.global_position = relic.global_position
		shots.append(await shot(camera, relic.global_position))
	# A shrine at full health: its third station sells a relic's whereabouts.
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "shrine.tscn":
			player.health.health = player.health.max_health
			var mend: Node2D = n.get_node("Mend") as Node2D
			player.global_position = mend.global_position
			shots.append(await shot(camera, mend.global_position + Vector2(-60, 0)))
			break
	# A projection inside rock, beside the room.
	player.global_position = info.cell_position(beside)
	Abilities.set_tier(player, &"astral", 2)
	player.get_node("AstralProjection").call("toggle")
	player.global_position = info.cell_position(beside + Vector2i(0, 2))
	shots.append(await shot(camera, info.cell_position(beside + Vector2i(0, 1))))
	var strip: Image = Image.create(500 * shots.size(), 500, false, shots[0].get_format())
	for k: int in range(shots.size()):
		strip.blit_rect(shots[k], Rect2i(0, 0, 500, 500), Vector2i(k * 500, 0))
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	strip.save_png(output.path_join("secret_room.png"))
	player.get_node("AstralProjection").call("toggle")
	# The ink well's hint on both map pages (this relic taken, so it points to another level).
	if relic != null:
		relic.call("take")
	player.global_position = info.cell_position(beside)
	info.ink_whole_map()
	var hint: Variant = info.hint_relic()
	print("hinted ", hint)
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	map.call("page", 1)
	if hint != null:
		map.set("selected", hint)
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("secret_map_worlds.png"))
	if hint != null:
		map.call("open_level", hint)
		for i: int in range(40):
			await process_frame
		root.get_texture().get_image().save_png(output.path_join("secret_map_hinted.png"))
	print("CAPTURED secret room stills to ", output)
	quit()
