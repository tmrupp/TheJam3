extends TestKit
## Phase 1 of docs/DEEPER_PLAN.md: levels are a pure function of (seed, depth), the four exits
## connect them, records survive revisits, and the deeper exit is paid for once.
## godot --headless --path . --script res://tests/deeper_test.gd


func fingerprint() -> int:
	var types: PackedInt32Array = PackedInt32Array()
	for column: Array in info.world.cells:
		for cell: Variant in column:
			types.append(cell.type)
	return hash([types, info.world.exits, info.world.exit_lanterns, info.world.objects])


func has_cell(scene: String, v: Vector2i) -> bool:
	return placed(scene).any(func(n: Node) -> bool: return n.get_meta(&"cell", Vector2i(-1, -1)) == v)


func go(exit: int) -> void:
	info.travel(exit)
	await settle()


## Placed at the cell's centre, the player then drops onto its floor (half a cell below).
func in_cell(v: Vector2i) -> bool:
	var d: Vector2 = player.global_position - info.cell_position(v)
	return absf(d.x) < 8.0 and d.y > -8.0 and d.y < 72.0


func near_exit(which: int) -> bool:
	return in_cell(info.world.exits[which])


func run() -> void:
	await boot()
	if info.world == null:
		check(false, "the first level loads")
		finish()
		return

	print("level (28, 0)")
	check(MapInfo.instance == info, "MapInfo.instance is the live MapInfo")
	check(info.coord == Vector2i(28, 0), "a run starts at depth 0 of its seed")
	check(info.world.exits.size() == 4, "four exits placed: %s" % [info.world.exits])
	check(placed("level_exit.tscn").size() == 3, "depth 0 has no way back, only three doors")
	check(placed("checkpoint.tscn").size() >= 2 and info.world.exit_lanterns.keys() == [MapInfo.Exit.BACK], "the start lantern, and lanterns are scarce: none beside the other exits")
	check(info.run.respawn_coord == info.coord, "the start lantern is lit")
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
	player.keyring.set_all([int(door.get_meta(&"key_color", 0))])
	door.get_node("Unlock").call("try_open")
	var stars: int = player.coins.coins
	check(stars == 1, "the coin paid a star")

	print("moving platforms")
	var lifts: Array[Node] = placed("moving_platform.tscn")
	# A small generated level may have no lifts. Exercise riding with a real, deterministic
	# prefab on an unobstructed track outside the level instead of relying on random density.
	var fixture: Node2D = load("res://prefabs/moving_platform.tscn").instantiate()
	info.map_elements.add_child(fixture)
	var fixture_cell: Vector2i = Vector2i(info.world.size.x + 8, 8)
	fixture.set_meta(&"cell", fixture_cell)
	fixture.call("setup", info, fixture_cell, [2, Vector2i.DOWN, 3])
	lifts.push_front(fixture)
	await physics_frame
	var on_track: bool = true
	for lift: Node in lifts:
		var start: Vector2 = lift.get("start")
		var along: float = ((lift as Node2D).position - start).dot(lift.get("axis") as Vector2)
		on_track = on_track and start == info.cell_position(lift.get_meta(&"cell")) and along >= -1.0 and along <= float(lift.get("travel")) + 1.0
	check(on_track, "each rides its own track from its cell (not the world origin)")
	# Vertical lifts first (the case that caught the wizard: it rises back into the feet); use the
	# first one the wizard actually lands on.
	var ordered: Array[Node] = lifts.filter(func(l: Node) -> bool: return (l.get("axis") as Vector2) == Vector2.DOWN)
	ordered.append_array(lifts.filter(func(l: Node) -> bool: return (l.get("axis") as Vector2) != Vector2.DOWN))
	var riding: bool = false
	var lift: Node2D = null
	var shape: CollisionShape2D = null
	var top: float = 0.0
	for candidate: Node in ordered:
		lift = candidate as Node2D
		shape = lift.get_node("CollisionShape2D") as CollisionShape2D
		for attempt: int in range(3):
			top = lift.global_position.y + shape.position.y - 16.5
			player.global_position = Vector2(lift.global_position.x + shape.position.x, top - 40.0)
			player.velocity = Vector2.ZERO
			# Riding: carried just over its top through the last frames (a lift going down does not
			# always count as floor underfoot, but the wizard goes down with it).
			var held: int = 0
			for i: int in range(20):
				await physics_frame
				top = lift.global_position.y + shape.position.y - 16.5
				if i >= 10 and player.global_position.y < top and player.global_position.y > top - 75.0:
					held += 1
			riding = held == 10
			if riding:
				break
		if riding:
			break
	player.drop()
	await until(func() -> bool: return player.global_position.y > lift.global_position.y + shape.position.y - 16.5 + 40.0, 2000)
	top = lift.global_position.y + shape.position.y - 16.5
	check(riding and player.global_position.y > top + 40.0, "down + jump drops through a moving platform (riding %s, %.0f below its top, axis %s)" % [riding, player.global_position.y - top, lift.get("axis")])
	player.global_position = info.cell_position(info.world.exits[MapInfo.Exit.BACK])
	await settle()

	print("level size")
	check(info.world.size == Rules.level_size(0) and Rules.level_size(6).x > Rules.level_size(0).x and Rules.level_size(6).y > Rules.level_size(0).y, "depth 0 is %s; deeper levels are bigger (%s at depth 6)" % [info.world.size, Rules.level_size(6)])
	var tm: TileMap = info.tile_map
	var walled: bool = true
	for x: int in range(-LevelLoader.BORDER, info.world.size.x + LevelLoader.BORDER):
		for y: int in [-1, -LevelLoader.BORDER, info.world.size.y, info.world.size.y + LevelLoader.BORDER - 1]:
			walled = walled and tm.get_cell_source_id(0, Vector2i(x, y)) != -1
	for y: int in range(-LevelLoader.BORDER, info.world.size.y + LevelLoader.BORDER):
		for x: int in [-1, -LevelLoader.BORDER, info.world.size.x, info.world.size.x + LevelLoader.BORDER - 1]:
			walled = walled and tm.get_cell_source_id(0, Vector2i(x, y)) != -1
	check(walled, "a solid border %d cells thick, flush against the level" % LevelLoader.BORDER)

	print("level contents")
	var lanterns: int = placed("checkpoint.tscn").size()
	var keys: int = placed("key.tscn").size()
	var area_k: float = float(info.world.size.x * info.world.size.y) / 1000.0
	# A first level also has its start key (for the side door near the start).
	var start_key: int = 1 if info.world.start_side >= 0 else 0
	check(keys == maxi(LevelGen.KEYS_MIN, roundi(LevelGen.KEYS_PER_K * area_k)) + start_key and lanterns <= 1 + maxi(1, roundi(LevelGen.LANTERNS_PER_K * area_k)), "%d keys and %d lanterns, in proportion to the level" % [keys, lanterns])
	check(placed("door.tscn").size() >= 1, "%d gates (doors) across corridors" % placed("door.tscn").size())
	var moons: Array[Node] = placed("moon.tscn")
	check(not moons.is_empty() and moons.size() <= info.world.per_area(LevelGen.MOONS_PER_K), "%d moons within the area budget" % moons.size())
	var open_air: bool = true
	for m: Node in moons:
		var c: Vector2i = m.get_meta(&"cell")
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				if info.world.is_ground(c + Vector2i(dx, dy)):
					open_air = false
		if info.world.is_ground(c + Vector2i(0, 2)):
			open_air = false
		open_air = open_air and not info.world._ledge_below(c)
	check(open_air, "every moon hangs in open air, clear of rock around and below")

	print("deeper exit price")
	var exit_node: Node = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == MapInfo.Exit.DEEPER)[0]
	check(int(exit_node.call("price")) == Rules.deeper_price(0), "deeper costs %d at depth 0" % Rules.deeper_price(0))
	exit_node.call("interacted")
	await process_frame
	check(info.coord.y == 0 and not info.travelling, "too few stars: the deeper exit stays shut")
	player.collect(20)
	exit_node.call("interacted")
	await settle()
	check(info.coord == Vector2i(28, 1), "paid: now at (28, 1)")
	check(player.coins.coins == 21 - Rules.deeper_price(0), "the price was taken once")
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
	await settle()
	check(fingerprint() == f29, "a run started at 29 matches walking there from 28")
	info.start_run(28)
	await settle()
	check(fingerprint() == f0, "a fresh run at 28 matches the first")
	check(has_cell("coin.tscn", coin_cell), "a new run starts with fresh records")
	info.coord = Vector2i(28, 0)
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	check(fingerprint() == f1, "(28, 1) is the same every time")

	print("respawn in another level")
	var lantern: Node = placed("checkpoint.tscn")[0]
	lantern.call("interacted")
	var lit_cell: Vector2i = lantern.get_meta(&"cell")
	check(info.run.respawn_coord == Vector2i(28, 1) and info.run.respawn_cell == lit_cell, "lighting a lantern moves the respawn")
	await go(MapInfo.Exit.BACK)
	player.reset_position()
	await settle()
	check(info.coord == Vector2i(28, 1), "dying elsewhere reloads the lantern's level")
	check(in_cell(lit_cell), "and stands the player at the lantern")

	finish()
