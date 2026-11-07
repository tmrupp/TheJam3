extends TestKit
## The labyrinth (Rules.maze_has): levels do not all have every way out, yet every level can be
## reached from every other. Each way is the same seen from both of its ends, the start's row keeps
## its side doors and the rows next to it their ways to it, some ways are gone on the other rows,
## and a level laid out has doors on its ways alone, its definition leading nowhere by the others.
## Bosses are met in one column each, near the run's start (Bosses.column), and the boss ahead of a
## row is the next gate away from the start (Bosses.ahead).
## godot --headless --path . --script res://tests/maze_test.gd

## The columns and rows whose levels must all be reached from the start, and how far either side
## the search may wander to reach them.
const COLUMNS: int = 24
const ROWS: int = 40
const WANDER: int = 160


func run() -> void:
	MapInfo.debug = false
	_both_ends()
	_near_the_start()
	_reached()
	_built()
	_bosses()
	finish()


## Where level `at`'s way `exit` leads, as the labyrinth joins levels: one column across, or one row
## toward or away from the start (the start's way back, up).
func _across(at: Vector2i, exit: int) -> Vector2i:
	match exit:
		MapInfo.Exit.LEFT:
			return at + Vector2i(-1, 0)
		MapInfo.Exit.RIGHT:
			return at + Vector2i(1, 0)
		MapInfo.Exit.DEEPER:
			return at + Vector2i(0, NextWorldDef.away(at.y))
	return at + Vector2i(0, -1 if at.y == 0 else -NextWorldDef.away(at.y))


## The way arrived at by leaving `at` by `exit`.
func _arrived_by(at: Vector2i, exit: int) -> int:
	match exit:
		MapInfo.Exit.LEFT:
			return MapInfo.Exit.RIGHT
		MapInfo.Exit.RIGHT:
			return MapInfo.Exit.LEFT
		MapInfo.Exit.DEEPER:
			return MapInfo.Exit.BACK
	# Toward the start: arriving at its way on, or from row -1 at the start's way back (up).
	return MapInfo.Exit.BACK if at.y == -1 or at.y == 0 else MapInfo.Exit.DEEPER


func _both_ends() -> void:
	print("each way is there from both its ends")
	var same: bool = true
	var cut_sides: int = 0
	var cut_homes: int = 0
	var all: int = 0
	for x: int in range(-COLUMNS, COLUMNS):
		for y: int in range(-ROWS, ROWS):
			var at: Vector2i = Vector2i(x, y)
			for exit: int in [MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT, MapInfo.Exit.DEEPER, MapInfo.Exit.BACK]:
				var there: bool = Rules.maze_has(at, exit)
				if there != Rules.maze_has(_across(at, exit), _arrived_by(at, exit)):
					same = false
			if absi(y) >= 2:
				all += 1
				cut_sides += 0 if Rules.maze_has(at, MapInfo.Exit.RIGHT) else 1
				cut_homes += 0 if Rules.maze_has(at, MapInfo.Exit.BACK) else 1
	check(same, "a way is there from one level exactly when it is from the level it leads to")
	var sides: float = float(cut_sides) / float(all)
	var homes: float = float(cut_homes) / float(all)
	check(sides > 0.25 and sides < 0.7 and homes > 0.2 and homes < 0.6, "off the start's rows, some side doors (%d%%) and ways toward the start (%d%%) are gone" % [roundi(sides * 100.0), roundi(homes * 100.0)])


func _near_the_start() -> void:
	print("the start's row and the rows next to it")
	var whole: bool = true
	for x: int in range(-COLUMNS, COLUMNS):
		for exit: int in [MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT, MapInfo.Exit.DEEPER, MapInfo.Exit.BACK]:
			whole = whole and Rules.maze_has(Vector2i(x, 0), exit)
		whole = whole and Rules.maze_has(Vector2i(x, 1), MapInfo.Exit.BACK) and Rules.maze_has(Vector2i(x, -1), MapInfo.Exit.BACK)
	check(whole, "the start's row keeps every way out, and the rows next to it their ways to it")
	var runs: bool = true
	for y: int in range(-ROWS, ROWS):
		if y == 0:
			continue
		var run_len: int = 0
		for x: int in range(-COLUMNS, COLUMNS):
			run_len = run_len + 1 if Rules.maze_has(Vector2i(x, y), MapInfo.Exit.RIGHT) else 0
			runs = runs and run_len < Rules.MAZE_RUN
	check(runs, "no more than %d levels joined side to side off the start's row" % Rules.MAZE_RUN)
	var gates: bool = true
	for boss: StringName in Bands.bosses():
		var row: int = Bosses.row_of(boss)
		for x: int in range(-COLUMNS, COLUMNS):
			gates = gates and Rules.maze_has(Vector2i(x, row), MapInfo.Exit.DEEPER)
	check(gates, "every gate level keeps its way on")


func _reached() -> void:
	print("every level is reached from the start")
	var seen: Dictionary = {Vector2i(0, 0): true}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for exit: int in [MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT, MapInfo.Exit.DEEPER, MapInfo.Exit.BACK]:
			if not Rules.maze_has(at, exit):
				continue
			var to: Vector2i = _across(at, exit)
			if absi(to.x) > WANDER or absi(to.y) > ROWS or seen.has(to):
				continue
			seen[to] = true
			queue.append(to)
	var missed: Array[Vector2i] = []
	for x: int in range(-COLUMNS, COLUMNS):
		for y: int in range(-ROWS, ROWS + 1):
			if not seen.has(Vector2i(x, y)):
				missed.append(Vector2i(x, y))
	check(missed.is_empty(), "all %d levels of %d columns and %d rows reached (missed %s)" % [COLUMNS * 2 * (ROWS * 2 + 1), COLUMNS * 2, ROWS * 2 + 1, missed.slice(0, 5)])


func _built() -> void:
	print("a level laid out has doors on its ways alone")
	var at: Variant = null
	for x: int in range(20, 60):
		var c: Vector2i = Vector2i(x, 3)
		if not Rules.maze_has(c, MapInfo.Exit.RIGHT) and not Rules.maze_has(c, MapInfo.Exit.BACK) and Worlds.arriving_at(c) == null:
			at = c
			break
	check(at != null, "a level missing its right door and its way back")
	if at == null:
		return
	var def: NextWorldDef = Rules.def_for(at)
	check(not def.ways().has(MapInfo.Exit.RIGHT) and not def.ways().has(MapInfo.Exit.BACK) and def.ways().has(MapInfo.Exit.LEFT) or not Rules.maze_has(at, MapInfo.Exit.LEFT), "its definition leaves them out")
	check(def.lead(MapInfo.Exit.RIGHT).is_empty() and def.lead(MapInfo.Exit.BACK).is_empty(), "and they lead nowhere")
	check(not def.neighbours().has(at + Vector2i(1, 0)), "nor is the level beside it a neighbour")
	var w: LevelGen = build(at)
	var doors: Array[int] = []
	for v: Vector2i in w.objects_of(LevelGen.Type.EXIT):
		doors.append(int(w.get_cell(v).extra_info))
	check(not doors.has(MapInfo.Exit.RIGHT) and not doors.has(MapInfo.Exit.BACK) and doors.has(MapInfo.Exit.DEEPER) == Rules.maze_has(at, MapInfo.Exit.DEEPER), "no door on them (doors: %s)" % [doors])
	check(w.exits.has(MapInfo.Exit.BACK) and w.get_cell(w.exits[MapInfo.Exit.BACK]).type != LevelGen.Type.EXIT, "its start is still by the way back's spot, with no door on it")


func _bosses() -> void:
	print("bosses in one column each")
	for boss: StringName in Bands.bosses():
		var reach: int = Bosses.spread(boss)
		var near: bool = true
		var spread: Dictionary = {}
		for run_seed: int in range(0, 1000):
			var col: int = Bosses.column(boss, run_seed)
			near = near and absi(col - run_seed) <= reach
			spread[col - run_seed] = true
		check(near and spread.size() == reach * 2 + 1, "%s: within %d columns of the run's start, every offset dealt" % [boss, reach])
	check_eq(Bosses.spread(Bosses.gate_at(Bands.garden_rows())), Bands.garden_rows(), "a garden boss's columns span as far as the garden is deep")
	for boss: StringName in Bands.bosses():
		var row: int = Bosses.row_of(boss)
		if absi(row) > Bands.garden_rows():
			check_eq(Bosses.spread(boss), int(Bands.band_at(row)["rows"]), "%s's columns span as far as its band is deep" % boss)
	var garden: int = Bands.garden_rows()
	check(Bosses.ahead(0) == Bosses.gate_at(garden) and Bosses.ahead(2) == Bosses.gate_at(garden) and Bosses.ahead(-2) == Bosses.gate_at(-garden), "the boss ahead: the garden's down from the start and below it, up's above it")
	check(Bosses.ahead(garden) == Bosses.gate_at(garden), "a gate level's own boss is the one ahead")
