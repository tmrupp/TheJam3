extends SceneTree
## Phase 6 of docs/DEEPER_PLAN.md: the printed map. What a level has seen grows around the
## player and with moon shards, and is kept in its record; the map opens on the level, then the
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
	before = info.seen_count()
	info.discover_random_chunk()
	check(info.seen_count() - before >= MapInfo.CHUNK_SIZE * MapInfo.CHUNK_SIZE / 2, "a moon shard reveals a chunk (%d cells)" % (info.seen_count() - before))
	var count: int = info.seen_count()
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	check(info.seen_count() >= count, "a revisit keeps what was seen")

	print("opening the map")
	map.call("cycle")
	await process_frame
	check(int(map.get("view")) == 1 and paused and map.visible, "first press: the level, paused")
	map.call("cycle")
	await process_frame
	check(int(map.get("view")) == 2 and paused, "second press: the world")
	map.call("cycle")
	await process_frame
	check(int(map.get("view")) == 0 and not paused and not map.visible, "third press: closed, playing again")
	map.call("cycle")
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
