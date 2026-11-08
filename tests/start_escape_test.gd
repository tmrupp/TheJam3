extends TestKit
## Every run can get out of its first level: at depth 0 one side door stands near the start, with a
## key in its lock colour, and both can be hopped to from the start (hops a little short of the
## wizard's reach) without passing a door or a switch gate.
## godot --headless --path . --script res://tests/start_escape_test.gd



## Footholds hopped to from `start` as the level's own start reach hops (Reach.tree: any drop, and
## higher from a moon), never through a door or a switch gate.
func reach_from(w: LevelGen, start: Vector2i) -> Dictionary:
	var nodes: Dictionary = Reach.footholds(w)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var a: Vector2i = queue.pop_back()
		for b: Vector2i in nodes:
			# Hop bounds the hop; this only skips footholds far beyond any (a quicker search).
			if seen.has(b) or absi(b.x - a.x) > w.size.y or a.y - b.y > Reach.MOON_UP:
				continue
			if not Reach.hop(w, a, b, bool(nodes.get(a, false)), LevelGen.START_ACROSS):
				continue
			if Reach.arc_cells(a, b).any(func(c: Vector2i) -> bool: return w.is_valid(c) and w.get_cell(c).type in [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE]):
				continue
			seen[b] = true
			queue.append(b)
	return seen


func run() -> void:
	var levels: int = 0
	var doors: int = 0
	var near: int = 0
	var keyed: int = 0
	var escapable: int = 0
	var worst: int = 0
	for world_seed: int in range(1, 41):
		var at: Vector2i = Vector2i(world_seed, 0)
		var w: LevelGen = build(at)
		levels += 1
		if w.start_side < 0:
			continue
		doors += 1
		var start: Vector2i = w.exits[MapInfo.Exit.BACK]
		var door: Vector2i = w.exits[w.start_side]
		var d: int = absi(door.x - start.x) + absi(door.y - start.y)
		worst = maxi(worst, d)
		if d <= 16:
			near += 1
		var colour: int = Rules.lateral_lock(at, w.start_side)
		var key: Variant = null
		if w.is_valid(w.start_key) and w.get_cell(w.start_key).type == LevelGen.Type.KEY and int(w.get_cell(w.start_key).extra_info) == colour:
			key = w.start_key
		if key == null:
			continue
		keyed += 1
		var reach: Dictionary = reach_from(w, start)
		if reach.has(door) and reach.has(key):
			escapable += 1
		else:
			print("  stuck: seed %d, start %s, door %s, key %s" % [world_seed, start, door, key])
	print("  %d levels: door placed %d, near %d (furthest %d cells), keyed %d, escapable %d" % [levels, doors, near, worst, keyed, escapable])
	check(doors == levels, "every first level has a side door near the start")
	check(near == doors, "within 16 cells of it")
	check(keyed == doors, "with a key in its lock colour")
	check(escapable == doors, "and both are hopped to from the start without passing a door or gate")

	print("in play")
	await boot(28)
	var side: int = info.world.start_side
	var door_node: LevelExit = null
	var key_node: Node = null
	for n: Node in placed("level_exit.tscn"):
		if (n as LevelExit).exit == side:
			door_node = n as LevelExit
	for n: Node in placed("key.tscn", true):
		if n.has_meta(&"cell") and n.get_meta(&"cell") == info.world.start_key:
			key_node = n
	check(door_node != null and key_node != null and int(key_node.get_meta(&"key_color")) == door_node.lock(), "the key by the start is the colour the door's lock asks for")
	finish()
