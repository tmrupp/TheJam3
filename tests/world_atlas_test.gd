extends TestKit
## The world atlas (tools/world_atlas) agrees with the game's rules of a place: its walls are the
## labyrinth's (Rules.maze_has), its relics, skeleton keys and bone vaults are where the rules lay
## them, its steps from the start are a true walk (each a step from a neighbour, none shorter than
## a neighbour allows), the bosses are where Bosses.column puts them and reached with their gates
## sealed, the row chart's relic shares follow Relics.chance, and its sums over many runs name each
## boss. On the demo's layout and the whole game's.
## godot --headless --path . --script res://tests/world_atlas_test.gd


func run() -> void:
	MapInfo.debug = false
	for layout: StringName in [Bands.DEMO, Bands.DEFAULT]:
		Bands.use(layout)
		var atlas: Control = (load("res://tools/world_atlas/world_atlas.tscn") as PackedScene).instantiate() as Control
		root.add_child(atlas)
		await frames(2)
		print("the %s layout" % layout)
		_check_atlas(atlas)
		atlas.queue_free()
		await frames(1)
	finish()


func _check_atlas(atlas: Control) -> void:
	var rows: Array[int] = atlas.get("rows")
	var steps: Dictionary = atlas.get("steps")
	var run_seed: int = atlas.get("run_seed")
	var columns: Array[int] = atlas.call("columns")
	check(rows.has(0) and rows.has(Bosses.row_of(Bands.bosses()[0])) and rows.has(Bosses.row_of(Bands.bosses()[1])),
			"its rows hold the start and both garden gates (%d to %d)" % [rows[0], rows[-1]])
	check_eq(int(steps.get(Vector2i(run_seed, 0), -1)), 0, "the start is no steps from itself")

	var walls_ok: bool = true
	var marks_ok: bool = true
	var relics: int = 0
	for r: int in rows:
		for x: int in columns:
			var at: Vector2i = Vector2i(x, r)
			var got: Dictionary = atlas.call("info", at)
			var open: Dictionary = got["open"]
			for exit: int in [MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT, MapInfo.Exit.DEEPER, MapInfo.Exit.BACK]:
				walls_ok = walls_ok and bool(open[exit]) == Rules.maze_has(at, exit)
			marks_ok = marks_ok and got["relic"] == Relics.at(at) and bool(got["skeleton"]) == Rules.skeleton_at(at) \
					and bool(got["bone"]) == Rules.bone_vault_at(at)
			if got["relic"] != &"":
				relics += 1
	check(walls_ok, "its walls are the labyrinth's")
	check(marks_ok and relics > 0, "its relics, skeleton keys and bone vaults are the rules' (%d relics in view)" % relics)

	# A true walk: no way out of a level reached leads to one in view further than a step on (two
	# through hyperspace), or not reached at all; and every level reached is that many steps on
	# from the nearest way into it.
	var walk_ok: bool = true
	var best: Dictionary = {}
	var wrong: String = ""
	for at: Vector2i in steps:
		var n: int = int(steps[at])
		for way: Array in atlas.call("_ways", at, true):
			var to: Vector2i = way[0]
			if not (to.x in columns and to.y in rows):
				continue
			var further: int = n + int(way[1])
			if not steps.has(to) or int(steps[to]) > further:
				walk_ok = false
				wrong = "%s (%d) leads to %s (%s)" % [at, n, to, steps.get(to, "unreached")]
			best[to] = mini(int(best.get(to, further)), further)
	for at: Vector2i in steps:
		if int(steps[at]) > 0 and int(best.get(at, -1)) != int(steps[at]):
			walk_ok = false
			wrong = "%s (%d) is %s from its nearest way in" % [at, int(steps[at]), best.get(at, "none")]
	check(walk_ok, "its steps from the start are a true walk (%d levels reached)%s" % [steps.size(), "" if walk_ok else ": " + wrong])

	var places: Dictionary = atlas.call("boss_places", run_seed)
	for boss: StringName in places:
		var at: Vector2i = places[boss]
		if not boss in (atlas.get("ROAMING") as Array):
			check_eq(at.x, Bosses.column(boss, run_seed), "the %s is drawn in its column" % boss)
		if absi(at.y) <= Bands.garden_rows():
			check(steps.has(at), "the %s's level is reached with every gate sealed (%d steps)" % [boss, int(steps.get(at, -1))])
	var past: Vector2i = Vector2i(run_seed, Bosses.row_of(Bands.bosses()[0]) + 1)
	check(not steps.has(past), "and nothing past its gate is")

	# The row chart counts relics over many columns: none at the start or the gates, and about
	# Relics.chance elsewhere.
	var chart: Dictionary = atlas.get("_chart")
	check_eq(float((chart[0] as Array)[0]), 0.0, "no relics on the start's row")
	check_eq(float((chart[Bosses.row_of(Bands.bosses()[0])] as Array)[0]), 0.0, "nor on a gate's")
	var row: int = 3
	var share: float = float((chart[row] as Array)[0])
	var expected: float = Relics.chance(row) / 100.0
	check(absf(share - expected) < 0.035, "row %d's relics are about Relics.chance (%.3f against %.2f)" % [row, share, expected])

	var text: String = atlas.call("summarize_runs", run_seed, 12, true)
	var named: bool = true
	for boss: StringName in Bands.bosses():
		if absi(Bosses.row_of(boss)) <= Bands.garden_rows():
			named = named and text.contains(String(boss).capitalize())
	check(named and text.contains("Nearest relic"), "its sums over many runs name each garden boss and the nearest relic")
	print(text)
	var said: String = atlas.call("describe", Vector2i(run_seed, 1))
	check(said.contains("World %d, row 1" % run_seed) and said.contains("Ways out"), "it describes a level")
