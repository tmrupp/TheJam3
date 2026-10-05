extends SceneTree
## suite: window (reads back the rendered screen, so it needs a real window: full run only)
## The worlds page picks another visited level and shows its map; the F7 ability picker sets tiers.
## godot --path . --windowed --script res://tests/map_worlds_test.gd

var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(info: MapInfo) -> void:
	await process_frame
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(10):
		await process_frame


func run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://map_worlds_test.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	await settle(info)
	var first: Vector2i = info.coord
	info.reveal(info.cell_at(info.player.global_position), 6)
	# The keys' and doors' colours as the level dealt them, to check the map deals them alike.
	var live: Dictionary = {}
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() in ["key.tscn", "door.tscn"] and n.has_meta(&"cell") and not n.has_meta(&"dropped_id"):
			live[n.get_meta(&"cell")] = int(n.get_meta(&"key_color", 0))
	var dealt: Dictionary = preload("res://scripts/riso/RisoMap.gd").dealt_colors(info.world)
	check(not live.is_empty() and live.keys().all(func(v: Vector2i) -> bool: return dealt.get(v, -9) == live[v]), "another level's page deals its keys' and doors' colours as the level did (%d)" % live.size())
	info.ink_whole_map()
	var first_seen: int = info.seen_count()
	info.travel(MapInfo.Exit.RIGHT)
	await settle(info)
	var map: Node = RisoPrint.instance.map_view
	map.call("toggle")
	map.call("page", 1)
	await process_frame
	check(int(map.get("view")) == 2 and map.get("selected") == info.coord, "the worlds page opens with the cursor on this level")
	var left: InputEventAction = InputEventAction.new()
	left.action = &"Left"
	left.pressed = true
	map.call("_world_input", left)
	check(map.get("selected") == first, "Left moves the cursor to the level to the left")
	var accept: InputEventAction = InputEventAction.new()
	accept.action = &"Discover"
	accept.pressed = true
	map.call("_world_input", accept)
	for i: int in range(4):
		await process_frame
	check(int(map.get("view")) == 1 and map.get("viewing") == first, "opening it shows that level's page")
	var w: MapInfo.World = info.world_at(first)
	check(w != null and w.size.x > 0, "its layout is rebuilt from its seed")
	check(first_seen > 0 and (map.get("rock") as Sprite2D).visible and (map.get("rock") as Sprite2D).texture != null, "and its seen map is drawn (%d cells seen)" % first_seen)
	var shown: Dictionary = map.get("_shown")
	check(shown.has("key") and shown.has("door"), "with its keys and doors (%s)" % [shown.keys()])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("map_other_level.png"))
	map.call("close")
	map.call("toggle")
	check(map.get("viewing") == info.coord, "reopening the map shows the level being played")
	map.call("close")
	await process_frame

	print("ability picker")
	var player: Player = info.player
	Abilities.set_tier(player, &"double_jump", 2)
	check(player.MAX_JUMPS == 3, "setting double jump II gives three jumps")
	Abilities.set_tier(player, &"astral", 1)
	check(Abilities.spell(player) == &"astral" and Abilities.tier(player, &"hex") == 0, "setting a spell takes the slot")
	Abilities.set_tier(player, &"astral", 0)
	check(Abilities.spell(player) == &"", "setting it to none empties the slot")
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASSED")
		quit()
