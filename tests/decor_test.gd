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


## Each prop's kind and cell (plants also keep their live sway, which depends on timing).
func layout(items: Array) -> Array:
	return items.map(func(it: Dictionary) -> Array: return [it["kind"], it["cell"]])


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
	MapInfo.save_path = "user://decor_test.save"
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
	check(kinds.has(&"fence_run"), "fences stand behind stretches of floor")
	check(kinds.has(&"shrub_run") and not kinds.has(&"bush") and not kinds.has(&"shrub"), "garden floors grow hedges, in runs along stretches of floor")
	check(first.filter(func(it: Dictionary) -> bool: return it["kind"] == &"shrub_run").all(func(it: Dictionary) -> bool: return (it["cells"] as Array).size() >= RisoDecor.SHRUB_MIN and (it["cells"] as Array).size() <= RisoDecor.SHRUB_MAX), "each hedge %d to %d cells long" % [RisoDecor.SHRUB_MIN, RisoDecor.SHRUB_MAX])
	check(not kinds.has(&"strata") and not kinds.has(&"fossil") and not kinds.has(&"geode") and not kinds.has(&"vein"), "nothing printed inside the rock")
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, info.world.size)
	check(first.all(func(it: Dictionary) -> bool: return bounds.has_point(it["base"])), "all inside the level (none on its outer walls)")
	var structures: Dictionary = {}
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() in RisoDecor.STRUCTURES and node.has_meta(&"cell"):
			var c: Vector2i = node.get_meta(&"cell")
			for d: int in [-1, 0, 1]:
				structures[c + Vector2i(d, 0)] = true
	var clear: bool = true
	for it: Dictionary in first:
		for c: Vector2i in it.get("cells", [it["cell"]]):
			if structures.has(c):
				clear = false
	check(clear, "none in or beside a cell holding an exit, shrine, door, lantern, thorns, portal, bell, switch or key")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	check(layout(decor.items) != layout(first), "another level wears different decor")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	check(layout(decor.items) == layout(first), "the same level always wears the same decor")

	print("lantern light")
	var light: RisoLight = main.get_node("RisoLight") as RisoLight
	check(light.lanterns.size() > 0 and light.lanterns.any(func(l: Node) -> bool: return info.is_respawn_lantern(l)), "the lanterns are lit, the respawn among them")

	print("ambient life")
	var ambient: Node = main.get_node("RisoAmbient")
	var seen: Dictionary = {"fireflies": 0, "drops": 0}
	var cam: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	# Only some spots hold life (fireflies fade in and out), so look at several of each.
	var spots: Dictionary = {"fireflies": decor.firefly_spots, "drops": decor.drip_spots}
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
	check(int(seen["fireflies"]) > 0 and int(seen["drops"]) > 0, "fireflies and ink drops show where they live: %s" % [seen])
	cam.global_position = light.glass(light.lanterns[0], info)
	cam.reset_smoothing()
	var moths_absent: bool = true
	for i: int in range(60):
		await process_frame
		moths_absent = moths_absent and int((ambient.get("counts") as Dictionary)["moths"]) == 0
	check(moths_absent, "no insects orbit the lantern")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: decor")
		quit()
