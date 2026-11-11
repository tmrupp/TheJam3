extends TestKit
## suite: full
## The garden bosses' signs (docs/REVIEW_PLAN.md §2): how near a boss is (Bosses.near), the worm's
## rumble in the levels near it (WormSign: none far off or above the start, more next door than at
## the edge of its reach, none once the worm is slain), and the spares (GardenArchetype.place_spares)
## the loader keeps as this run's nearness calls for (Bosses.spare_kept): laid the same in every
## build, kept as near as the run is, none SIGN_REACH columns off, the same on a revisit; and a
## thorn vine on its own in a garden wall (GardenVine) that lashes, hurts only while out, recoils
## stunned, and is in the same place on a revisit.
## godot --headless --path . --script res://tests/boss_signs_test.gd

## Game seconds a level's rumbles are counted over.
const LISTEN: float = 12.0


func run() -> void:
	if not needs([&"garden"]):
		finish()
		return
	await boot(28)
	var seed: int = info.run.run_seed
	var worm_col: int = Bosses.column(&"worm", seed)
	var worm_row: int = Bosses.row_of(&"worm")
	var near_row: int = worm_row - signi(worm_row)
	_near(seed, worm_col, worm_row)
	await _rumbles(worm_col, near_row)
	await _spares(Vector2i(worm_col, near_row), LevelGen.Type.WORMLET, "wormlet.tscn")
	var bramble_col: int = Bosses.column(&"bramble", seed)
	var bramble_row: int = Bosses.row_of(&"bramble")
	await _spares(Vector2i(bramble_col, bramble_row - signi(bramble_row)), LevelGen.Type.POD, "seed_pod.tscn")
	await _vine(bramble_col, bramble_row - signi(bramble_row))
	finish()


func _near(seed: int, col: int, row: int) -> void:
	print("how near")
	check(is_equal_approx(Bosses.near(&"worm", Vector2i(col, row), seed), 1.0), "1 in the worm's own level")
	check(is_equal_approx(Bosses.near(&"worm", Vector2i(col + 1, row), seed), 1.0 - 1.0 / Bosses.SIGN_REACH), "less next door")
	check(Bosses.near(&"worm", Vector2i(col + Bosses.SIGN_REACH, row), seed) == 0.0, "0 at %d levels off" % Bosses.SIGN_REACH)
	check(Bosses.near(&"worm", Vector2i(col, -1), seed) == 0.0 and Bosses.near(&"bramble", Vector2i(col, 1), seed) == 0.0, "0 on the far side of the start")
	check(Bosses.spare_kept(0, 4, 0.75) and Bosses.spare_kept(2, 4, 0.75) and not Bosses.spare_kept(3, 4, 0.75) and not Bosses.spare_kept(0, 4, 0.0) and Bosses.spare_kept(3, 4, 1.0), "spares kept as near as the run is, the first first")


## How many times the ground rumbles in LISTEN game seconds at `at`.
func listen(at: Vector2i) -> int:
	await go(at)
	var sign: WormSign = info.map_elements.get_node_or_null("WormSign") as WormSign
	if sign == null:
		return -1
	var was: int = sign.rumbles
	await within(func() -> bool: return false, LISTEN)
	return sign.rumbles - was


func _rumbles(col: int, row: int) -> void:
	print("the worm's rumble")
	var next_door: int = await listen(Vector2i(col, row))
	var edge: int = await listen(Vector2i(col + 2, row))
	var far: int = await listen(Vector2i(col + Bosses.SIGN_REACH + 3, row))
	var above: int = await listen(Vector2i(col, -1))
	print("  rumbles in %d s: next door %d, two off %d, far %d, above the start %d" % [int(LISTEN), next_door, edge, far, above])
	check(next_door > edge and edge > 0, "the ground rumbles near the worm, more often next door")
	check(far == 0 and above == 0, "never far off, nor above the start")
	info.run.bosses[&"worm"] = true
	var slain: int = await listen(Vector2i(col, row))
	check(slain == 0, "and never once the worm is slain")
	info.run.bosses.erase(&"worm")


## Spares of `type` laid at `at` (and SIGN_REACH columns off): the same every build, kept as near
## as the run is, none far off, the same on a revisit.
func _spares(at: Vector2i, type: LevelGen.Type, scene: String) -> void:
	print("spares at %s" % at)
	var w: LevelGen = build(at)
	var again: LevelGen = build(at)
	check(w.objects == again.objects, "the level is laid out the same every time")
	var laid: int = w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == type and w.get_cell(v).mods.has("spare")).size()
	check(laid > 0, "spares laid (%d)" % laid)
	var want: int = roundi(Bosses.near(StringName(w.get_cell(w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).mods.has("spare"))[0]).mods["spare_of"]) if laid > 0 else &"worm", at, info.run.run_seed) * float(laid))
	await go(at)
	var kept: int = placed(scene).filter(func(n: Node) -> bool: return n.has_meta(&"spare")).size()
	check(kept == want and kept > 0, "%d of them kept, as near as the run is" % kept)
	info.travel(MapInfo.Exit.LEFT if Rules.maze_has(at, MapInfo.Exit.LEFT) else MapInfo.Exit.RIGHT)
	await settle()
	await go(at)
	check_eq(placed(scene).filter(func(n: Node) -> bool: return n.has_meta(&"spare")).size(), kept, "the same on a revisit")
	var off: Vector2i = at + Vector2i(Bosses.SIGN_REACH, 0)
	await go(off)
	check(placed(scene).filter(func(n: Node) -> bool: return n.has_meta(&"spare")).is_empty(), "none kept %d columns off" % Bosses.SIGN_REACH)


## A vine on its own near the bramble: its cadence, its touch, its stun.
func _vine(col: int, row: int) -> void:
	print("a thorn vine on its own")
	var at: Vector2i = Vector2i(-9999, 0)
	for dx: int in [0, 1, -1]:
		var w: LevelGen = build(Vector2i(col + dx, row))
		if at.x == -9999 and w.objects.any(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.VINE and int(w.get_cell(v).mods.get("spare", 99)) == 0):
			at = Vector2i(col + dx, row)
	check(at.x != -9999, "a level near the bramble with a vine laid")
	if at.x == -9999:
		return
	await go(at)
	var vines: Array[Node] = placed("garden_vine.tscn")
	check(not vines.is_empty(), "a vine grows out of its wall there")
	if vines.is_empty():
		return
	var vine: GardenVine = vines[0] as GardenVine
	var cells: Array = vines.map(func(n: Node) -> Vector2i: return n.get_meta(&"cell"))
	check(info.world.is_ground(vine.cell - Vector2i(roundi(vine.way.x), roundi(vine.way.y))), "rooted in rock, lashing out into the open")
	vine.t = 0.0
	vine._physics_process(1.0 / 60.0)
	check(vine.phase()[0] == &"rest" and not vine.hurts(), "resting in the rock, it does not hurt")
	vine.t = BrambleVine.REST + BrambleVine.WARN + BrambleVine.GROW + 0.1
	vine._physics_process(1.0 / 60.0)
	check(vine.phase()[0] == &"hold" and vine.hurts() and vine.length > vine.full * 0.9, "out, it reaches its length and hurts")
	vine.stunner.stun(1.0, true)
	vine._physics_process(1.0 / 60.0)
	check(vine.recoiled() and not vine.hurts(), "parried, it recoils and does not hurt")
	info.travel(MapInfo.Exit.LEFT if Rules.maze_has(at, MapInfo.Exit.LEFT) else MapInfo.Exit.RIGHT)
	await settle()
	await go(at)
	check_eq(placed("garden_vine.tscn").map(func(n: Node) -> Vector2i: return n.get_meta(&"cell")), cells, "the same vines on a revisit")
