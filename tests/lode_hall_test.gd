extends TestKit
## The lodestone golem's hall (LodeHall, docs/REGIONS_PLAN.md §6), built at the top of the crags'
## gate level once the golem guards it: its walls (but for a doorway through each at the ground
## storey, out to the caves), roof and ground in masonry kept whole; two galleries over the ground
## floor, each broken by the golem's gap and, in the other half of the hall, by the wizard's stair
## hole with two ledges under it a hop apart, the gaps on opposite sides; a storey of air over every
## floor tall enough for the golem; the way on on the top gallery against the wall on its gap's
## side, climbed to from the ground storey with the wizard's own hops; the golem in its lair on the
## ground floor under the lower gallery's gap; a crossbow to each gallery set in the walls shooting
## into the hall; the gondola and the towers laid round it, nothing else inside; the same every
## build, in every world's gate level and only there. Prints the hall of world 28 as rows of
## characters, to look over.
## godot --headless --path . --script res://tests/lode_hall_test.gd


func run() -> void:
	var gate: Vector2i = Vector2i(28, Bosses.row_of(&"golem"))
	var w: LevelGen = build(gate)
	var keep: Dictionary = w.keep
	check(keep.has("lair") and (keep["box"] as Rect2i).size == LodeHall.SIZE and (keep["box"] as Rect2i).position.y == LodeHall.TOP, "the golem's gate level has its hall at the top, %d by %d cells" % [LodeHall.SIZE.x, LodeHall.SIZE.y])
	var box: Rect2i = keep["box"]
	var inside: Rect2i = keep["inside"]
	var floors: Array[int] = keep["floors"]
	var doors: Array[Vector2i] = keep["doors"]
	var gaps: Array[Rect2i] = keep["gaps"]
	var stairs: Array[Rect2i] = keep["stairs"]
	_print_hall(w)
	var walls_ok: bool = true
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var v: Vector2i = Vector2i(x, y)
			if not inside.has_point(v) and not doors.has(v):
				walls_ok = walls_ok and w.is_ground(v) and w.masonry.has(v) and w.kept(v)
	check(walls_ok and floors.size() == LodeHall.GALLERIES, "walled, roofed and grounded in masonry kept whole, with %d galleries" % floors.size())
	check(doors.size() == 2 * LodeHall.WALL * LodeHall.DOOR_ROWS and doors.all(func(v: Vector2i) -> bool: return not w.is_ground(v) and v.y >= inside.end.y - LodeHall.DOOR_ROWS), "a doorway through each wall at the ground storey")

	@warning_ignore("integer_division")
	var mid: int = inside.position.x + LodeHall.HALL / 2
	var galleries_ok: bool = gaps.size() == LodeHall.GALLERIES and stairs.size() == LodeHall.GALLERIES
	for k: int in range(floors.size()):
		var gap: Rect2i = gaps[k]
		var stair: Rect2i = stairs[k]
		galleries_ok = galleries_ok and gap.size.x == LodeHall.GAP and stair.size.x == LodeHall.STAIR and gap.position.y == floors[k] and stair.position.y == floors[k]
		galleries_ok = galleries_ok and (gap.end.x <= mid) != (stair.end.x <= mid)
		galleries_ok = galleries_ok and gap.position.x - inside.position.x >= LodeHall.TO_WALL and inside.end.x - gap.end.x >= LodeHall.TO_WALL
		galleries_ok = galleries_ok and stair.position.x - inside.position.x >= LodeHall.TO_WALL and inside.end.x - stair.end.x >= LodeHall.TO_WALL
		for x: int in range(inside.position.x, inside.end.x):
			var c: Vector2i = Vector2i(x, floors[k])
			galleries_ok = galleries_ok and w.is_ground(c) != (gap.has_point(c) or stair.has_point(c))
	check(galleries_ok, "every gallery broken by the golem's gap (%d wide) and, in the other half, a stair hole (%d wide), the rest of it whole" % [LodeHall.GAP, LodeHall.STAIR])
	check((gaps[0].end.x <= mid) != (gaps[1].end.x <= mid), "the galleries' gaps on opposite sides of the hall")
	var air_ok: bool = true
	for y: int in range(inside.position.y, inside.end.y):
		if floors.has(y):
			continue
		for x: int in range(inside.position.x, inside.end.x):
			air_ok = air_ok and not w.is_ground(Vector2i(x, y))
	check(air_ok, "%d rows of air over every floor, for the golem" % LodeHall.ROOM)
	var ledges: Array[Vector2i] = keep["ledges"]
	var ledges_ok: bool = ledges.size() == LodeHall.GALLERIES * 2 * LodeHall.STAIR
	for stair: Rect2i in stairs:
		var toward: int = 1 if stair.position.x < mid else -1
		for x: int in range(stair.position.x, stair.end.x):
			ledges_ok = ledges_ok and w.get_cell(Vector2i(x, stair.position.y + Reach.UP)).type == LevelGen.Type.PLATFORM
			ledges_ok = ledges_ok and w.get_cell(Vector2i(x + toward * LodeHall.STAIR, stair.position.y + 2 * Reach.UP)).type == LevelGen.Type.PLATFORM
	check(ledges_ok, "two ledges under every stair hole, a hop apart: one right under it, one beside it toward the middle")

	var on: Vector2i = w.exits.get(MapInfo.Exit.DEEPER, Vector2i(-1, -1))
	var gap_left: bool = gaps[0].end.x <= mid
	check(on == keep["on"] and on.y == floors[0] - 1 and on.x == (inside.position.x if gap_left else inside.end.x - 1) and w.get_cell(on).type == LevelGen.Type.EXIT and w.is_ground(on + Vector2i.DOWN), "the way on on the top gallery, against the wall on its gap's side")
	var parent: Dictionary = Reach.tree(w, Vector2i(inside.position.x + 1, inside.end.y - 1))
	var top: bool = parent.keys().any(func(v: Vector2i) -> bool: return v.y == floors[0] - 1)
	var out: bool = parent.keys().any(func(v: Vector2i) -> bool: return not box.has_point(v))
	check(top and out, "the top gallery climbed to from the ground storey with the wizard's own hops, and out through its doorways")
	var bosses: Array[Vector2i] = w.objects_of(LevelGen.Type.BOSS)
	check(bosses.size() == 1 and StringName(w.get_cell(bosses[0]).extra_info) == &"golem" and bosses[0] == keep["lair"] and bosses[0].y == inside.end.y - 1 and w.is_ground(bosses[0] + Vector2i.DOWN) and gaps[-1].has_point(Vector2i(bosses[0].x, gaps[-1].position.y)), "the golem in its lair on the ground floor, under the lower gallery's gap")
	var path: Array = w.circuit.get("path", [])
	check(not path.is_empty() and path.all(func(v: Vector2i) -> bool: return v.y > box.end.y), "the gondola runs below it")
	check(w.towers.all(func(t: Dictionary) -> bool: return not (t["box"] as Rect2i).intersects(box)), "and no tower stands in it")
	var bows: Array[Vector2i] = keep["crossbows"]
	var bows_ok: bool = bows.size() == LodeHall.GALLERIES
	for v: Vector2i in bows:
		var how: Dictionary = w.get_cell(v).extra_info
		var facing: int = int(how["facing"])
		bows_ok = bows_ok and w.get_cell(v).type == LevelGen.Type.CROSSBOW and bool(how["inward"]) and floors.has(v.y + 1)
		bows_ok = bows_ok and w.is_ground(v - Vector2i(facing, 0)) and w.is_ground(v - Vector2i(facing * 2, 0)) and not w.is_ground(v + Vector2i(facing, 0))
	check(bows_ok, "a crossbow to each gallery, in the hall's wall, shooting into the hall (%d)" % bows.size())
	var stray: bool = w.objects.any(func(v: Vector2i) -> bool: return box.has_point(v) and not w.get_cell(v).type in [LevelGen.Type.PLATFORM, LevelGen.Type.EXIT, LevelGen.Type.BOSS] and not bows.has(v))
	check(not stray, "nothing else is placed in it")

	var again: LevelGen = build(gate)
	check(again.objects == w.objects and again.keep == w.keep, "the same every build")
	var everywhere: bool = true
	for world: int in [29, 30, 31]:
		var other: LevelGen = build(Vector2i(world, gate.y))
		everywhere = everywhere and other.keep.has("lair") and other.objects_of(LevelGen.Type.BOSS) == [other.keep["lair"]]
	check(everywhere, "in every world's gate level")
	check(build(Vector2i(28, gate.y + 1)).keep.is_empty(), "and only there")
	finish()


## Print the hall in `w` as rows of characters: # stone, . air, = a ledge, > the way on, G the
## golem, B a crossbow, + a doorway.
func _print_hall(w: LevelGen) -> void:
	var box: Rect2i = w.keep["box"]
	var doors: Array[Vector2i] = w.keep["doors"]
	for y: int in range(box.position.y - 1, box.end.y + 1):
		var line: String = ""
		for x: int in range(box.position.x - 3, box.end.x + 3):
			var v: Vector2i = Vector2i(x, y)
			var type: LevelGen.Type = w.get_cell(v).type if w.is_valid(v) else LevelGen.Type.GROUND
			if doors.has(v):
				line += "+"
			elif type == LevelGen.Type.PLATFORM:
				line += "="
			elif type == LevelGen.Type.EXIT:
				line += ">"
			elif type == LevelGen.Type.BOSS:
				line += "G"
			elif type == LevelGen.Type.CROSSBOW:
				line += "B"
			elif w.is_valid(v) and w.is_ground(v):
				line += "#"
			else:
				line += "."
		print("  " + line)
