extends SceneTree
## Focus transitions and lock hints. With a renderer, also saves review captures.

var info: MapInfo
var player: Player
var camera: Camera2D
var failed: bool = false
var output: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)

func settle(frames: int = 25) -> void:
	for i: int in range(frames):
		await physics_frame
		await process_frame

func loaded() -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	await process_frame
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(info.world != null and not info.travelling)
	player.set_physics_process(false)
	camera.limit_left = -1000000
	camera.limit_top = -1000000
	camera.limit_right = 1000000
	camera.limit_bottom = 1000000
	await settle(3)

func first(file: String) -> Node2D:
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == file:
			return node as Node2D
	return null

func focus(object: Node2D) -> Interactable:
	for node: Node in get_nodes_in_group(&"interactables"):
		(node as Interactable).touching = false
	# Stay close to bells so a nearby switch does not become the nearer interaction.
	var offset: float = -25.0 if object.scene_file_path.get_file() == "bell.tscn" else -55.0
	player.global_position = object.global_position + Vector2(offset, 0)
	camera.global_position = object.global_position + Vector2(0, -90)
	camera.reset_smoothing()
	var it: Interactable = object.get_node("Interactable") as Interactable
	it.touch(player)
	await settle()
	check(it.is_focused(), "%s gets sole interaction focus" % object.name)
	return it

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	output = ProjectSettings.globalize_path("res://../art-captures/interaction-hints")
	DirAccess.make_dir_recursive_absolute(output)
	MapInfo.save_path = "user://interaction_hints_test.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	main.get_node("Menu").world_seed.text = "28"
	main.get_node("Menu").start_game()
	player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.invulnerable.enable()
	await loaded()
	await settle()

	var well: Node2D = first("inkwell.tscn")
	player.global_position = well.global_position + Vector2(-300, 0)
	camera.global_position = well.global_position + Vector2(0, -90)
	camera.reset_smoothing()
	await settle()
	var prompt: Node = well.get_node("RisoPrompt")
	check(not (prompt.get("hint_label") as Label).visible, "map price hidden outside interaction focus")
	await shot("inkwell_idle")
	var it: Interactable = await focus(well)
	check(it.prompt_hint().get("text") == "map · %d" % int(well.call("price")), "generic hint contains current map price")
	check((prompt.get("hint_label") as Label).visible, "map price pops up for the focused inkwell")
	await shot("inkwell_focused")
	player.global_position = well.global_position + Vector2(-300, 0)
	it.untouch(player)
	await settle()
	check(not (prompt.get("hint_label") as Label).visible, "price closes after leaving")
	player.collect(100)
	well.call("buy")
	await settle()
	check(not it.available, "paid inkwell has no further interaction")

	var door: Node2D = first("door.tscn")
	it = await focus(door.get_node("Unlock") as Node2D)
	check(int(it.prompt_hint().get("key_color", -1)) == int(door.get_meta(&"key_color")), "portcullis exposes its key requirement")
	await shot("portcullis_key")
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "level_exit.tscn" and int(node.call("lock")) >= 0:
			it = await focus(node as Node2D)
			check(int(it.prompt_hint().get("key_color", -1)) == int(node.call("lock")), "lateral door exposes its key requirement")
			await shot("lateral_padlock")
			break

	Abilities.grant(player, &"keyring")
	Abilities.grant(player, &"keyring")
	Abilities.grant(player, &"keyring")
	KeyRing.set_all(player, [0, 1, 2, 3])
	# Keep the whole trailing ring against open sky for the size comparison.
	player.global_position = Vector2(-2000, -2000)
	camera.global_position = player.global_position + Vector2(0, -90)
	camera.reset_smoothing()
	await settle(90)
	await shot("equal_keyring")
	KeyRing.set_all(player, [])
	info.coord = Vector2i(28, 3)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await loaded()
	var captured: Dictionary = {}
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() != "bell.tscn":
			continue
		var lock: int = int(node.get("lock"))
		var kind: String = "switch" if lock < 0 else "key"
		if captured.has(kind):
			continue
		captured[kind] = true
		it = await focus(node as Node2D)
		check(bool(it.prompt_hint().get("switch", false)) if lock < 0 else int(it.prompt_hint().get("key_color", -1)) == lock, "chained bell shows its %s requirement" % kind)
		await shot("bell_" + kind)
		node.call("open")
		await settle()
		check(it.prompt_hint().is_empty(), "freed bell returns to the ring interaction")
		node.call("ring")
		await settle()
		check(not it.available, "rung bell hides its prompt")
	check(captured.has("key") and captured.has("switch"), "covered both bell lock types")
	print("FAIL: interaction hints" if failed else "PASS: interaction hints")
	quit(1 if failed else 0)
