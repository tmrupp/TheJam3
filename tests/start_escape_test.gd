extends SceneTree
## Every run can get out of its first level: at depth 0 one side door stands near the start, with a
## key in its lock colour, and both can be hopped to from the start (hops a little short of the
## wizard's reach) without passing a door or a switch gate.
## godot --headless --path . --script res://tests/start_escape_test.gd

var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


## Footholds hopped to from `start`, never through a door or a switch gate.
func reach_from(w: MapInfo.World, start: Vector2i) -> Dictionary:
	var nodes: Dictionary = Reach.footholds(w)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var a: Vector2i = queue.pop_back()
		for b: Vector2i in nodes:
			if seen.has(b) or absi(b.x - a.x) > 8 or absi(b.y - a.y) > 8:
				continue
			if not Reach.hop(w, a, b, false, MapInfo.World.START_ACROSS):
				continue
			if Reach.arc_cells(a, b).any(func(c: Vector2i) -> bool: return w.is_valid(c) and w.get_cell(c).type in [MapInfo.Type.DOOR, MapInfo.Type.SWITCH_GATE]):
				continue
			seen[b] = true
			queue.append(b)
	return seen


func run() -> void:
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")
	var levels: int = 0
	var placed: int = 0
	var near: int = 0
	var keyed: int = 0
	var escapable: int = 0
	var worst: int = 0
	for world_seed: int in range(1, 41):
		var at: Vector2i = Vector2i(world_seed, 0)
		var def: NextWorldDef = MapInfo.def_for(at)
		var w: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
		levels += 1
		if w.start_side < 0:
			continue
		placed += 1
		var start: Vector2i = w.exits[MapInfo.Exit.BACK]
		var door: Vector2i = w.exits[w.start_side]
		var d: int = absi(door.x - start.x) + absi(door.y - start.y)
		worst = maxi(worst, d)
		if d <= 16:
			near += 1
		var colour: int = MapInfo.lateral_lock(at, w.start_side)
		var key: Variant = null
		if w.is_valid(w.start_key) and w.get_cell(w.start_key).type == MapInfo.Type.KEY and int(w.get_cell(w.start_key).extra_info) == colour:
			key = w.start_key
		if key == null:
			continue
		keyed += 1
		var reach: Dictionary = reach_from(w, start)
		if reach.has(door) and reach.has(key):
			escapable += 1
		else:
			print("  stuck: seed %d, start %s, door %s, key %s" % [world_seed, start, door, key])
	print("  %d levels: door placed %d, near %d (furthest %d cells), keyed %d, escapable %d" % [levels, placed, near, worst, keyed, escapable])
	check(placed == levels, "every first level has a side door near the start")
	check(near == placed, "within 16 cells of it")
	check(keyed == placed, "with a key in its lock colour")
	check(escapable == placed, "and both are hopped to from the start without passing a door or gate")

	print("in play")
	var menu: Node = main.get_node("Menu")
	MapInfo.save_path = "user://start_escape_test.save"
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	var side: int = info.world.start_side
	var door_node: Node = null
	var key_node: Node = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "level_exit.tscn" and int(n.get("exit")) == side:
			door_node = n
		if n.scene_file_path.get_file() == "key.tscn" and n.has_meta(&"cell") and n.get_meta(&"cell") == info.world.start_key:
			key_node = n
	check(door_node != null and key_node != null and int(key_node.get_meta(&"key_color")) == int(door_node.call("lock")), "the key by the start is the colour the door's lock asks for")
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASSED")
		quit()
