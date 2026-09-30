extends SceneTree
## Phase 1 of docs/DEEPER_PLAN.md: levels are a pure function of (seed, depth), the four exits
## connect them, records survive revisits, and the deeper exit is paid for once.
## godot --headless --path . --script res://tests/deeper_test.gd

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


func wait_level() -> bool:
	var deadline: int = Time.get_ticks_msec() + 30000
	await process_frame
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(4):
		await physics_frame
		await process_frame
	return not info.travelling


func fingerprint() -> int:
	var types: PackedInt32Array = PackedInt32Array()
	for column: Array in info.world.cells:
		for cell: Variant in column:
			types.append(cell.type)
	return hash([types, info.world.exits, info.world.exit_lanterns, info.world.objects])


func placed(scene: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == scene and not node.is_queued_for_deletion():
			found.append(node)
	return found


func has_cell(scene: String, v: Vector2i) -> bool:
	return placed(scene).any(func(n: Node) -> bool: return n.get_meta(&"cell", Vector2i(-1, -1)) == v)


func go(exit: int) -> void:
	info.travel(exit)
	await wait_level()


## Placed at the cell's centre, the player then drops onto its floor (half a cell below).
func in_cell(v: Vector2i) -> bool:
	var d: Vector2 = player.global_position - info.cell_position(v)
	return absf(d.x) < 8.0 and d.y > -8.0 and d.y < 72.0


func near_exit(which: int) -> bool:
	return in_cell(info.world.exits[which])


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	main.get_node("UpgradeMenu").done()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	if not await wait_level():
		push_error("level never loaded")
		quit(1)
		return

	print("level (28, 0)")
	check(MapInfo.instance == info, "MapInfo.instance is the live MapInfo")
	check(info.coord == Vector2i(28, 0), "a run starts at depth 0 of its seed")
	check(info.world.exits.size() == 4, "four exits placed: %s" % [info.world.exits])
	check(placed("level_exit.tscn").size() == 3, "depth 0 has no way back, only three doors")
	check(placed("checkpoint.tscn").size() >= 4, "a lantern beside every exit")
	check(info.respawn_coord == info.coord, "the start lantern is lit")
	var back: Vector2i = info.world.exits[MapInfo.Exit.BACK]
	var deeper: Vector2i = info.world.exits[MapInfo.Exit.DEEPER]
	print("  exits ", info.world.exits, " back-to-deeper ", absi(back.x - deeper.x) + absi(back.y - deeper.y))
	var f0: int = fingerprint()

	# Pickups and doors are recorded, then stay gone on a revisit.
	var coin: Node = placed("coin.tscn")[0]
	var coin_cell: Vector2i = coin.get_meta(&"cell")
	coin.call("touch", player)
	var door: Node = placed("door.tscn")[0]
	var door_cell: Vector2i = door.get_meta(&"cell")
	player.set_meta(&"carried_key", int(door.get_meta(&"key_color", 0)))
	door.get_node("Unlock").call("try_open")
	var stars: int = player.coins.coins
	check(stars == 1, "the coin paid a star")

	print("deeper exit price")
	var exit_node: Node = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == MapInfo.Exit.DEEPER)[0]
	check(int(exit_node.call("price")) == MapInfo.deeper_price(0), "deeper costs %d at depth 0" % MapInfo.deeper_price(0))
	exit_node.call("interacted")
	await process_frame
	check(info.coord.y == 0 and not info.travelling, "too few stars: the deeper exit stays shut")
	player.collect(20)
	exit_node.call("interacted")
	await wait_level()
	check(info.coord == Vector2i(28, 1), "paid: now at (28, 1)")
	check(player.coins.coins == 21 - MapInfo.deeper_price(0), "the price was taken once")
	check(near_exit(MapInfo.Exit.BACK), "going deeper arrives at the way back")
	var f1: int = fingerprint()
	check(f1 != f0, "depth 1 differs from depth 0")
	check(placed("level_exit.tscn").size() == 4, "depth 1 has all four doors")

	print("back to (28, 0)")
	await go(MapInfo.Exit.BACK)
	check(info.coord == Vector2i(28, 0), "back is free and returns to depth 0")
	check(near_exit(MapInfo.Exit.DEEPER), "going back arrives at the deeper exit")
	check(fingerprint() == f0, "(28, 0) regenerates identically")
	check(not has_cell("coin.tscn", coin_cell), "the taken coin stays taken")
	check(not has_cell("door.tscn", door_cell), "the opened door stays open")
	check(placed("coin.tscn").size() > 0, "the other coins are still there")
	exit_node = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == MapInfo.Exit.DEEPER)[0]
	check(int(exit_node.call("price")) == 0, "the deeper exit stays paid")

	print("sideways")
	await go(MapInfo.Exit.RIGHT)
	check(info.coord == Vector2i(29, 0), "right steps to seed 29")
	check(near_exit(MapInfo.Exit.LEFT), "arrives at the left exit")
	var f29: int = fingerprint()
	check(f29 != f0, "seed 29 differs from seed 28")
	await go(MapInfo.Exit.LEFT)
	await go(MapInfo.Exit.LEFT)
	check(info.coord == Vector2i(27, 0), "left twice reaches seed 27")

	print("determinism across runs")
	info.start_run(29)
	await wait_level()
	check(fingerprint() == f29, "a run started at 29 matches walking there from 28")
	info.start_run(28)
	await wait_level()
	check(fingerprint() == f0, "a fresh run at 28 matches the first")
	check(has_cell("coin.tscn", coin_cell), "a new run starts with fresh records")
	info.coord = Vector2i(28, 0)
	info.travel(MapInfo.Exit.DEEPER)
	await wait_level()
	check(fingerprint() == f1, "(28, 1) is the same every time")

	print("respawn in another level")
	var lantern: Node = placed("checkpoint.tscn")[0]
	lantern.call("interacted")
	var lit_cell: Vector2i = lantern.get_meta(&"cell")
	check(info.respawn_coord == Vector2i(28, 1) and info.respawn_cell == lit_cell, "lighting a lantern moves the respawn")
	await go(MapInfo.Exit.BACK)
	player.reset_position()
	await wait_level()
	check(info.coord == Vector2i(28, 1), "dying elsewhere reloads the lantern's level")
	check(in_cell(lit_cell), "and stands the player at the lantern")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 1")
		quit()
