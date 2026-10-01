extends SceneTree
## The surface decor, lantern light and ambient life: decor is a pure function of the level,
## stays inside it and clear of structures, never touches the level's RNG, and the life and
## light turn up where they should.
## godot --headless --path . --script res://tests/decor_test.gd

var main: Node
var info: MapInfo
var player: Player
var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle() -> void:
	await process_frame
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(4):
		await physics_frame
		await process_frame


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	player.set_physics_process(false)
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor

	print("decor")
	var first: Array = decor.items.duplicate(true)
	var kinds: Dictionary = {}
	for it: Dictionary in first:
		kinds[it["kind"]] = true
	check(first.size() > info.world.size.x * info.world.size.y / 15 and kinds.size() >= 7, "%d props of %d kinds" % [first.size(), kinds.size()])
	check(not kinds.has(&"strata") and not kinds.has(&"fossil") and not kinds.has(&"geode") and not kinds.has(&"vein"), "nothing printed inside the rock")
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, info.world.size)
	check(first.all(func(it: Dictionary) -> bool: return bounds.has_point(it["base"])), "all inside the level (none on its outer walls)")
	var structures: Dictionary = {}
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() in RisoDecor.STRUCTURES and node.has_meta(&"cell"):
			structures[node.get_meta(&"cell")] = true
	var clear: bool = true
	for it: Dictionary in first:
		if it["kind"] in [&"tuft", &"mushroom", &"stones", &"roots", &"stalactite", &"drip", &"vine"] and structures.has(it["cell"]):
			clear = false
	check(clear, "none in a cell holding an exit, shrine, door, lantern, thorns, portal or orb")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	check(decor.items != first, "another level wears different decor")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	check(decor.items == first, "the same level always wears the same decor")

	print("lantern light")
	var light: RisoLight = main.get_node("RisoLight") as RisoLight
	check(light.lanterns.size() > 0 and light.lanterns.any(func(l: Node) -> bool: return info.is_respawn_lantern(l)), "the lanterns are lit, the respawn among them")

	print("ambient life")
	var ambient: Node = main.get_node("RisoAmbient")
	var seen: Dictionary = {"fireflies": 0, "moths": 0, "drops": 0}
	var cam: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	# Only some spots hold life (fireflies fade in and out), so look at several of each.
	var spots: Dictionary = {"fireflies": decor.firefly_spots, "moths": PackedVector2Array([light.glass(light.lanterns[0], info)]), "drops": decor.drip_spots}
	for what: String in spots:
		var list: PackedVector2Array = spots[what]
		for n: int in range(mini(8, list.size())):
			if int(seen[what]) > 0:
				break
			cam.global_position = list[n]
			cam.reset_smoothing()
			for i: int in range(150):
				await process_frame
				seen[what] = maxi(int(seen[what]), int((ambient.get("counts") as Dictionary)[what]))
	check(int(seen["fireflies"]) > 0 and int(seen["moths"]) > 0 and int(seen["drops"]) > 0, "fireflies, moths and ink drops show where they live: %s" % [seen])

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: decor")
		quit()
