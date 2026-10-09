extends TestKit
## Light and darkness by line of sight (RisoSight, RisoLight): sight stops at rock and reaches a
## little into the faces it meets, the shapes the darkness prints are whole outlines with no holes,
## a door or wall changing redoes it, and in the game the wizard's sight, the lanterns' pools and
## the shade follow the rock, with deep darkness in the catacombs only.
## godot --headless --path . --script res://tests/sight_test.gd

const CELL: float = 128.0


func run() -> void:
	_grid()
	_outside()
	await _in_game()
	finish()


## The middle of cell `v` on a grid whose (0, 0) corner is at the origin.
func _mid(v: Vector2i) -> Vector2:
	return (Vector2(v) + Vector2(0.5, 0.5)) * CELL


## A walled room 12 × 7 with a pillar three cells tall in it, seen from its left.
func _grid() -> void:
	print("sight on a grid")
	var s: RisoSight = RisoSight.new(Vector2.ZERO, CELL)
	for x: int in range(-1, 13):
		s.solid[Vector2i(x, -1)] = true
		s.solid[Vector2i(x, 7)] = true
	for y: int in range(-1, 8):
		s.solid[Vector2i(-1, y)] = true
		s.solid[Vector2i(12, y)] = true
	for y: int in range(2, 5):
		s.solid[Vector2i(6, y)] = true
	var eye: Vector2 = _mid(Vector2i(2, 3))
	var bounds: Rect2 = Rect2(Vector2(-2, -2) * CELL, Vector2(16, 11) * CELL)
	var seen: PackedVector2Array = s.polygon(eye, bounds)
	check(seen.size() >= 8, "it outlines what the eye sees")
	check(Geometry2D.is_point_in_polygon(_mid(Vector2i(4, 1)), seen), "open space in view is seen")
	check(Geometry2D.is_point_in_polygon(_mid(Vector2i(8, 0)), seen), "past the pillar's top, the room is seen")
	check(not Geometry2D.is_point_in_polygon(_mid(Vector2i(9, 3)), seen), "behind the pillar is not seen")
	check(not Geometry2D.is_point_in_polygon(Vector2(6.5, 3.5) * CELL, seen), "the pillar's inside is not seen")
	check(Geometry2D.is_point_in_polygon(Vector2(6.0 * CELL + RisoSight.FACE * 0.5, 3.5 * CELL), seen), "the face of the pillar the eye looks at is lit")
	check(not Geometry2D.is_point_in_polygon(_mid(Vector2i(2, 8)), seen), "beyond the floor is not seen")
	check_eq(s.polygon(_mid(Vector2i(6, 3)), bounds).size(), 4, "from inside rock, everything is seen")
	# A light's own reach: the box it is cast in bounds it.
	var box: Rect2 = Rect2(eye - Vector2(200, 200), Vector2(400, 400))
	var near: PackedVector2Array = s.polygon(eye, box)
	check(not Geometry2D.is_point_in_polygon(eye + Vector2(250, 0), near), "a light's sight ends at its reach")
	var v: int = s.version
	check(s.set_solid(Vector2i(6, 3), false) and s.version > v, "opening a cell bumps the version")
	check(not s.set_solid(Vector2i(6, 3), false), "opening it again changes nothing")
	check(Geometry2D.is_point_in_polygon(_mid(Vector2i(9, 3)), s.polygon(eye, bounds)), "with the pillar holed, the eye sees through it")


## The darkness prints outside sight: holes are split into whole outlines.
func _outside() -> void:
	print("outlines outside sight")
	var rect: Rect2 = Rect2(0, 0, 1000, 600)
	var hole: PackedVector2Array = RisoShapes.circle(Vector2(500, 300), 100.0, 32)
	var other: PackedVector2Array = RisoShapes.circle(Vector2(200, 200), 60.0, 24)
	var pieces: Array[PackedVector2Array] = RisoSight.outside(rect, [hole, other])
	var area: float = 0.0
	var plain: bool = true
	for p: PackedVector2Array in pieces:
		plain = plain and not Geometry2D.is_polygon_clockwise(p)
		area += _area(p)
		plain = plain and not Geometry2D.is_point_in_polygon(Vector2(500, 300), p) and not Geometry2D.is_point_in_polygon(Vector2(200, 200), p)
	check(pieces.size() >= 2 and plain, "the pieces are plain outlines clear of the holes")
	var want: float = rect.get_area() - _area(hole) - _area(other)
	check(absf(area - want) < 1.0, "together they cover the rest exactly (%.0f of %.0f)" % [area, want])
	check_eq(RisoSight.outside(rect, []).size(), 1, "with nothing seen, the whole view")


func _area(p: PackedVector2Array) -> float:
	var a: float = 0.0
	for i: int in range(p.size()):
		a += p[i].cross(p[(i + 1) % p.size()])
	return absf(a) * 0.5


func _in_game() -> void:
	print("in the game")
	await boot(28)
	await settle()
	# Landed: the wizard arrives in the air, and sight is worked out from where their eyes are.
	await until(func() -> bool: return player.is_on_floor())
	var light: RisoLight = main.get_node("RisoLight") as RisoLight
	await process_frame
	check(light.sight != null and light.sight.solid.size() > 0, "the rock is laid out for sight")
	var eye: Vector2 = RisoLight.eye(player)
	check(light.seen.size() >= 3 and Geometry2D.is_point_in_polygon(eye, light.seen), "the wizard sees from their eyes")
	# A cell of rock with rock all round it, near the wizard: its middle is out of sight.
	var deep: Vector2 = Vector2.INF
	var at: Vector2i = info.cell_at(player.global_position)
	for r: int in range(1, 6):
		for x: int in range(at.x - r, at.x + r + 1):
			for y: int in range(at.y - r, at.y + r + 1):
				var v: Vector2i = Vector2i(x, y)
				if deep == Vector2.INF and _buried(light.sight, v):
					deep = info.cell_position(v)
	check(deep != Vector2.INF and not Geometry2D.is_point_in_polygon(deep, light.seen), "buried rock is out of sight")
	check(Geometry2D.is_point_in_polygon(info.cell_position(at), light.seen), "the wizard's own cell is in sight")
	# The carried pool is cut by the rock as well.
	var pool: Array = light.pools[light.pools.size() - 1]
	var lit_rock: bool = false
	for shape: PackedVector2Array in pool[1]:
		lit_rock = lit_rock or (deep != Vector2.INF and Geometry2D.is_point_in_polygon(deep, shape))
	check(Vector2(light.carried.x, light.carried.y).is_equal_approx(pool[0]) and not lit_rock, "the carried pool stops at the rock")
	check(light.dark_ink.get_child_count() > 0, "the shade prints")
	check(is_equal_approx(info.here.shade(), Archetype.SHADE) and is_zero_approx(info.here.gloom()), "the garden is shaded out of sight, without deep darkness")
	RisoLight.by_sight = false
	await process_frame
	check(light.seen.is_empty(), "with sight off on the F7 panel, nothing is shaded")
	RisoLight.by_sight = true
	# A door shut in the sight's rock opens with the door.
	var doors: Array[Vector2i] = []
	for v: Vector2i in light._changing:
		if light._changing[v] == LevelGen.Type.DOOR:
			doors.append(v)
	if not doors.is_empty():
		var door: Vector2i = doors[0]
		check(light.sight.solid.has(door), "a shut door stops sight")
		info.record().opened[door] = true
		await process_frame
		check(not light.sight.solid.has(door), "once open, sight passes")
		info.record().opened.erase(door)
	print("the catacombs")
	info.coord = Vector2i(28, NextWorldDef.band_row(&"catacombs", 0))
	info._load_level()
	await settle()
	check(info.here.gloom() > 0.0 and info.here.shade() > Archetype.SHADE, "the catacombs are deep dark")
	check(light.pools.size() > 0, "their lights carve the dark")
	RunState.delete_save()


## Whether `v` and the eight cells round it are all rock.
func _buried(s: RisoSight, v: Vector2i) -> bool:
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			if not s.solid.has(v + Vector2i(dx, dy)):
				return false
	return true
