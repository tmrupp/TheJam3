extends TestKit
## Going up and down from the start (docs/REGIONS_PLAN.md): the start's way up is a door that costs
## what its way down does; through it, the first level above the start, whose way back leads home
## into the start's way up; climbing on through the garden into the crags; the place shown as a
## height; a hyperspace that crosses the start into the other branch; and a run saved above the
## start, and in a side world entered from there, read back where it was.
## godot --headless --path . --script res://tests/branches_test.gd


func run() -> void:
	await boot(28)
	player.set_physics_process(false)
	var up_door: Array[Node] = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == MapInfo.Exit.BACK)
	check(up_door.size() == 1, "the start has a way up")
	var owed: int = int(up_door[0].call("price"))
	check(owed == Rules.deeper_price(0), "it costs %d stars, as the way down does" % owed)
	player.collect(owed - player.coins.coins)
	up_door[0].call("interacted")
	await settle()
	player.set_physics_process(false)
	check(info.coord == Vector2i(28, -1) and info.here.archetype == &"garden", "paying it leads up, to the garden's first level above the start")
	check(player.coins.coins == 0 and info.run.deepest == 1 and info.run.furthest_row == -1, "the stars are spent, and the run has been 1 from the start, above it")
	check(player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0, "arriving at its way back, which leads home")
	check(Rules.where(info.coord) == "world 28 · height 1", "the place reads as a height")

	print("home again")
	info.travel(MapInfo.Exit.BACK)
	await settle()
	player.set_physics_process(false)
	check(info.coord == Vector2i(28, 0) and player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0, "its way back leads down into the start, at the way up")
	check(info.here.price(MapInfo.Exit.BACK, info.record()) == 0, "and the way up, once paid, is free")

	print("climbing on")
	for i: int in range(NextWorldDef.GARDEN_ROWS + 1):
		info.here.pay(MapInfo.Exit.DEEPER if info.coord.y < 0 else MapInfo.Exit.BACK, info.record())
		info.travel(MapInfo.Exit.DEEPER if info.coord.y < 0 else MapInfo.Exit.BACK)
		await settle()
		player.set_physics_process(false)
	check(info.coord == Vector2i(28, -(NextWorldDef.GARDEN_ROWS + 1)) and info.here.archetype == &"crags", "past the garden's top row the crags begin (%s)" % info.coord)
	check(info.here.depth == NextWorldDef.GARDEN_ROWS + 1 and info.run.deepest == NextWorldDef.GARDEN_ROWS + 1, "a level counts its distance from the start, up as down")

	print("saved up here")
	info.save_run()
	var saved: Dictionary = RunState.read_save()
	check(saved.get("coord") == info.coord and int(saved.get("furthest_row", 0)) == info.coord.y, "a run saved above the start keeps where it is")
	var side: Vector2i = Worlds.side_at(0, info.coord)
	saved["coord"] = side
	saved["version"] = RunState.SAVE_VERSION
	RunState.write_save(saved)
	check(RunState.read_save().get("coord") == side and Worlds.origin_of(side) == info.coord, "and a side world entered from up here is found again")

	print("across the start")
	var hyper: Hyperspace = Worlds.proto(Worlds.kind_of(Hyperspace)) as Hyperspace
	var crossing: Variant = null
	for x: int in range(1, 400):
		var from: Vector2i = Vector2i(x, -2)
		if hyper.deals(from) and Hyperspace.crosses(from):
			crossing = from
			break
	check(crossing != null, "some hyperspace above the start crosses into the branch below")
	if crossing != null:
		var to: Vector2i = hyper.destination_for(crossing)
		check(to.y == 2 + Hyperspace.DROP and Rules.def_for(to).arrival_from == Worlds.side_at(0, crossing), "it comes out %d rows below the start, and that level's way back leads into it" % to.y)
	RunState.delete_save()
	finish()
