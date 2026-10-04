extends SceneTree
## Hyperspace, a side world (see SideWorld): a long linear hazard world between the level the jump is paid in and the
## level its gate drops to, with its own address (seed, -depth) and tile on the worlds map.
## godot --headless --path . --script res://tests/hyperspace_test.gd

var main: Node
var info: MapInfo
var player: Player
var failed: bool = false


## A kind of world made from nothing but its name: everything else is SideWorld's.
class Nook extends SideWorld:
	func _init() -> void:
		name = "nook"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(frames: int = 6) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame


func count(w: MapInfo.World, type: int) -> int:
	var n: int = 0
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			if int(w.get_cell(Vector2i(x, y)).type) == type:
				n += 1
	return n


func placed(scene: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == scene and not node.is_queued_for_deletion():
			found.append(node)
	return found


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://hyperspace_test.save"
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")

	print("addresses")
	var from: Vector2i = Vector2i(28, 3)
	var at: Vector2i = Worlds.side_at(Worlds.kind_of(Hyperspace), from)
	check(Worlds.is_side(at) and not Worlds.is_side(from) and Worlds.origin_of(at) == from, "the chasm of (28, 3) is (28, -4), and knows where it came from")
	var lands: Vector2i = (MapInfo.def_for(at) as SideWorld).destination()
	check(lands.y == 3 + Hyperspace.DROP and absi(lands.x - 28) <= 1 and lands.x - 28 == Hyperspace.drift(from), "its gate lands %d levels below, %d worlds sideways" % [Hyperspace.DROP, lands.x - 28])
	var drifts: Dictionary = {}
	for s: int in range(1, 60):
		drifts[Hyperspace.drift(Vector2i(s, 2))] = true
	check(drifts.size() == 3, "across worlds, hyperspace drifts left, right or straight down")
	check(MapInfo.def_for(at) is Hyperspace and not MapInfo.def_for(from) is SideWorld and MapInfo.def_for(at).size == Vector2i(Hyperspace.WIDTH, Hyperspace.HEIGHT), "its definition is the chasm's, at its own size")
	check(MapInfo.where(at).contains("hyperspace"), "it is named on screen: %s" % MapInfo.where(at))

	print("generation")
	var linear_ok: bool = true
	var hazards_ok: bool = true
	var uncrossed: Array[Vector2i] = []
	var made: int = 0
	for world_seed: int in [1, 7, 28, 99, 123]:
		for depth: int in [1, 4, 9]:
			var def: NextWorldDef = MapInfo.def_for(Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(world_seed, depth)))
			var cells: Array = wfc.call("generate_level", def)
			var w: MapInfo.World = MapInfo.World.new(cells, def)
			made += 1
			var back: Vector2i = w.exits[MapInfo.Exit.BACK]
			var gate: Vector2i = w.exits[MapInfo.Exit.DEEPER]
			if not (w.size == Vector2i(Hyperspace.WIDTH, Hyperspace.HEIGHT) and back.x < 8 and gate.x > w.size.x - 8 and w.exits.size() == 2):
				linear_ok = false
			if count(w, MapInfo.Type.SPIKES) < 30 or count(w, MapInfo.Type.SHOOTER) < 3 or count(w, MapInfo.Type.CHECKPOINT) < 3 or count(w, MapInfo.Type.EXIT) != 2:
				hazards_ok = false
			if not Hyperspace.crossable(w):
				uncrossed.append(Vector2i(world_seed, depth))
	check(linear_ok, "all %d chasms run from a way back at the left to a gate at the right" % made)
	check(hazards_ok, "each is thick with thorns and watchers, with a lantern at the start, the end and halfway")
	check(uncrossed.is_empty(), "lifts, ledges and moons make each crossable from the way back to the gate (not: %s)" % [uncrossed])
	var def_a: NextWorldDef = MapInfo.def_for(at)
	var def_b: NextWorldDef = MapInfo.def_for(Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(29, 3)))
	var a1: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def_a), def_a)
	var a2: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def_a), def_a)
	var b: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def_b), def_b)
	var same: bool = true
	var differs: bool = false
	for x: int in range(a1.size.x):
		for y: int in range(a1.size.y):
			var v: Vector2i = Vector2i(x, y)
			same = same and a1.get_cell(v).type == a2.get_cell(v).type
			differs = differs or a1.get_cell(v).type != b.get_cell(v).type
	check(same, "the same address always gives the same chasm")
	check(differs, "another seed's chasm differs")

	print("debug runs")
	MapInfo.debug = true
	var dd: NextWorldDef = MapInfo.def_for(Vector2i(5, 0))
	var first: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", dd), dd)
	var spawn: Vector2i = first.exits[MapInfo.Exit.BACK]
	check(first.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).x >= 0 and first.get_cell(first.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1))).type == MapInfo.Type.EXIT and int(first.get_cell(first.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1))).extra_info) == Worlds.door(Worlds.kind_of(Hyperspace)), "the first level of a debug run has a chasm door")
	check(absi(first.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).x - spawn.x) + absi(first.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).y - spawn.y) <= 12, "right by the spawn, like the other debug exits")
	check(Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(5, 0)) == Vector2i(5, -1) and Worlds.is_side(Vector2i(5, -1)) and Worlds.origin_of(Vector2i(5, -1)) == Vector2i(5, 0), "its chasm is (5, -1), clear of the level at (5, 0)")
	MapInfo.debug = false
	var plain: NextWorldDef = MapInfo.def_for(Vector2i(5, 0))
	check(not MapInfo.World.new(wfc.call("generate_level", plain), plain).exits.has(Worlds.door(Worlds.kind_of(Hyperspace))), "and an ordinary run's first level has none")

	print("the jump in play")
	var plunge_seed: int = -1
	for world_seed: int in range(1, 120):
		var d: NextWorldDef = MapInfo.def_for(Vector2i(world_seed, 1))
		if MapInfo.level_seed(d.gen_seed, 777) % 100 < Hyperspace.CHANCE:
			plunge_seed = world_seed
			break
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = str(plunge_seed)
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.set_physics_process(false)
	var origin: Vector2i = info.coord
	check(origin == Vector2i(plunge_seed, 1) and info.world.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).x >= 0, "level (%d, 1) deals a hyperspace door" % plunge_seed)
	var jump: Node = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == Worlds.door(Worlds.kind_of(Hyperspace)))[0]
	player.collect(int(jump.call("price")) + 3 - player.coins.coins)
	jump.call("interacted")
	await settle()
	player.set_physics_process(false)
	var chasm: Vector2i = Worlds.side_at(Worlds.kind_of(Hyperspace), origin)
	check(info.coord == chasm and info.deepest == 1, "the jump leads into the chasm, and only %d deep so far" % info.deepest)
	check(info.records.has(chasm) and info.records.has(origin) and not info.records.has(origin + Vector2i(0, 1)), "it has its own record, and no level of the drop was visited")
	check(info.world.size == Vector2i(Hyperspace.WIDTH, Hyperspace.HEIGHT) and info.world.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).x < 0, "a chasm of %d x %d cells" % [info.world.size.x, info.world.size.y])
	check(player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0, "arriving at its way back")
	check(placed("spikes.tscn").size() > 30 and placed("shooter_enemy.tscn").size() >= 3, "with %d thorns and %d watchers" % [placed("spikes.tscn").size(), placed("shooter_enemy.tscn").size()])
	var gate_node: Node = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == MapInfo.Exit.DEEPER)[0]
	check(int(gate_node.call("price")) == 0, "its gate is free: the jump was paid on the way in")

	print("the worlds map")
	var map: Node = RisoPrint.instance.map_view
	map.call("toggle")
	map.call("page", 1)
	await process_frame
	var grid_chasm: Vector2 = map.call("grid_at", chasm)
	var grid_origin: Vector2 = map.call("grid_at", origin)
	check(absf(grid_chasm.x - grid_origin.x) <= 0.5 and grid_chasm.y > grid_origin.y and grid_chasm.y < grid_origin.y + Hyperspace.DROP, "its tile hangs between the level and the one %d below" % Hyperspace.DROP)
	check(map.get("selected") == chasm and map.call("tile_size", chasm).y > map.call("tile_size", origin).y, "the cursor starts on it, a strip taller than a level")
	var up: InputEventAction = InputEventAction.new()
	up.action = &"Up"
	up.pressed = true
	map.call("_world_input", up)
	check(map.get("selected") == origin, "Up moves the cursor from the chasm to the level above it")
	var down: InputEventAction = InputEventAction.new()
	down.action = &"Down"
	down.pressed = true
	map.call("_world_input", down)
	check(map.get("selected") == chasm, "Down moves it back")
	map.call("close")

	print("the way through")
	info.travel(MapInfo.Exit.BACK)
	await settle()
	player.set_physics_process(false)
	check(info.coord == origin and player.global_position.distance_to(info.cell_position(info.world.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)))) < 80.0, "its way back returns to the level, out of the hyperspace door")
	check((info.record(chasm).get("ways_taken", {}) as Dictionary).has(MapInfo.Exit.DEEPER) == false and (info.record(origin).get("doors_paid", {}) as Dictionary).has(Worlds.door(Worlds.kind_of(Hyperspace))), "the jump stays paid, and the chasm uncrossed")
	jump = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == Worlds.door(Worlds.kind_of(Hyperspace)))[0]
	check(int(jump.call("price")) == 0, "going in again costs nothing")
	jump.call("interacted")
	await settle()
	player.set_physics_process(false)
	check(info.coord == chasm, "and leads back in")
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.set_physics_process(false)
	var landing: Vector2i = (MapInfo.def_for(chasm) as SideWorld).destination()
	check(info.coord == landing and info.deepest == landing.y and not info.records.has(Vector2i(plunge_seed, 3)), "the gate drops to depth %d, skipping the levels between" % landing.y)
	check(player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0, "arriving by that level's way back")
	check((info.record(chasm).get("ways_taken", {}) as Dictionary).has(MapInfo.Exit.DEEPER), "and the chasm is marked crossed")

	print("the landing level")
	check(MapInfo.def_for(landing).arrival_from != null and MapInfo.def_for(origin).arrival_from == null, "the level the gate drops into knows a chasm leads to it")
	check(info.world.exits.has(MapInfo.Exit.RETURN) and info.world.exits.has(MapInfo.Exit.BACK), "it has an ordinary way up as well as its way back")
	info.travel(MapInfo.Exit.BACK)
	await settle()
	player.set_physics_process(false)
	check(info.coord == chasm and player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.DEEPER])) < 80.0, "its way back leads into the chasm, at the gate")
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.set_physics_process(false)
	info.travel(MapInfo.Exit.RETURN)
	await settle()
	player.set_physics_process(false)
	check(info.coord == Vector2i(landing.x, landing.y - 1) and player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.DEEPER])) < 80.0, "the ordinary way up leads to depth %d, by its deeper exit" % info.coord.y)
	check(map.call("links", info).any(func(pair: Array) -> bool: return pair[0] == info.coord and pair[1] == landing), "and the worlds map joins the two")

	print("a new kind of world")
	var nook: SideWorld = Nook.new()
	nook.setup(Worlds.side_at(0, Vector2i(7, 2)))
	var out: Dictionary = nook.lead(MapInfo.Exit.DEEPER)
	check(nook.dead_end() and out["to"] == Vector2i(7, 2) and out["arrive"] == Worlds.door(0) and nook.lead(MapInfo.Exit.BACK)["way"] == Vector2.LEFT, "a dead end's ways both lead out of its door")
	check(nook.title() == "world 7 · nook" and nook.price(MapInfo.Exit.DEEPER, {}) == 0 and not nook.exit_grand(MapInfo.Exit.DEEPER) and nook.neighbours().size() == 1 and nook.neighbours()[0] == Vector2i(7, 2), "with its name, free exits and its one neighbour, from SideWorld alone")
	check(is_equal_approx(nook.progress(Vector2i(0, 5)), 0.0) and is_equal_approx(nook.progress(Vector2i(nook.size.x - 1, 5)), 1.0), "its progress runs across it, the way it is crossed")
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASSED")
		quit()
