extends SceneTree
## Phase 6 of docs/DEEPER_PLAN.md: the printed map. What a level has seen grows around the
## player, all at once when its ink well is paid, and is kept in its record; the map opens on the level, then the
## world, then closes, pausing the game; the world view's links follow the records.
## godot --headless --path . --script res://tests/map_test.gd

var main: Node
var info: MapInfo
var player: Player
var map: Node
var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(frames: int = 4) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
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
	map = main.get_node("RisoMap")

	print("seeing the level")
	var here: Vector2i = info.cell_at(player.global_position)
	check(info.is_seen(here) and info.is_seen(here + Vector2i(3, 0)), "cells around the wizard are seen")
	var far: Vector2i = info.world.exits[MapInfo.Exit.DEEPER]
	check(not info.is_seen(far), "the far deeper exit is not yet seen")
	var before: int = info.seen_count()
	player.global_position = info.cell_position(far)
	await settle(2)
	check(info.is_seen(far) and info.seen_count() > before, "walking there reveals it")
	var wells: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "inkwell.tscn")
	check(wells.size() == 1, "one ink well in the level")
	var well: Node = wells[0]
	check(int(well.call("price")) == MapInfo.map_price(0) and MapInfo.map_price(4) > MapInfo.map_price(0), "it costs %d stars here, more deeper" % MapInfo.map_price(0))
	player.collect(-player.coins.coins)
	well.call("buy")
	check(not bool(well.call("used")) and info.seen_count() < info.world.size.x * info.world.size.y, "too few stars: the map stays as explored")
	player.collect(MapInfo.map_price(0))
	well.call("buy")
	check(info.seen_count() == info.world.size.x * info.world.size.y and player.coins.coins == 0, "paid: the whole level is inked at once")
	check(bool(well.call("used")), "and the well is dry")
	var count: int = info.seen_count()
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	check(info.seen_count() >= count, "a revisit keeps what was seen")
	check(bool((info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "inkwell.tscn")[0]).call("used")), "and the well stays dry")

	print("opening the map")
	map.call("toggle")
	await process_frame
	check(int(map.get("view")) == 1 and paused and map.visible, "M opens the level page, paused")
	map.call("page", 1)
	await process_frame
	check(int(map.get("view")) == 2 and paused, "D turns to the worlds page")
	map.call("page", 1)
	check(int(map.get("view")) == 2, "and no further")
	map.call("page", -1)
	check(int(map.get("view")) == 1, "A turns back to the level")
	map.call("toggle")
	await process_frame
	check(int(map.get("view")) == 0 and not paused and not map.visible, "M again closes it, playing again")
	map.call("toggle")
	map.call("close")
	await process_frame
	check(int(map.get("view")) == 0 and not paused, "Menu closes it")

	print("the world view")
	info.record()["lateral_open"][MapInfo.Exit.RIGHT] = true
	info.record()["deeper_paid"] = true
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	var links: Array = map.call("links", info)
	var pairs: Array = links.map(func(l: Array) -> String: return "%s>%s" % [l[0], l[1]])
	check(pairs.has("(28, 0)>(29, 0)") and pairs.has("(28, 0)>(28, 1)"), "links follow the opened side door and the paid deeper door: %s" % [pairs])
	check((map.call("tiles", info) as Dictionary).has(Vector2i(28, 1)) and (map.call("tiles", info) as Dictionary).has(Vector2i(29, 0)), "every visited level is a tile")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 6")
		quit()
