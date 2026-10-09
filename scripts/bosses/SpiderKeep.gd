class_name SpiderKeep
extends RefCounted
## The spider's keep (docs/REGIONS_PLAN.md §6): its arena (Arena), a tall hall of broken floors
## built of masonry, the spider (Spider) hanging in the dark under its roof. build lays it out over
## whatever the collapse made, and notes what it holds in LevelGen.keep:
## - "inside": the hall's air and floors, inside its walls, roof and ground (cells);
## - "floors": the rows of its broken floors, top first; "well": the first column of the well;
## - "holes": every hole in the floors (the well's and the stairs'), "stairs": the stair holes alone;
## - "ledges": the one-way ledges under the stair holes; "webs": the cells each web spans.
## The hall is HALL cells across inside walls WALL thick, under a roof ROOF rows thick. Under the
## roof is the spider's roost, ROOST rows of air; under that FLOORS broken floors, a STOREY apart,
## and under the lowest the ground storey and the ground. Every floor is broken twice: by the well,
## a hole HOLE cells wide in the same columns all the way down, which the spider drops through and
## climbs back up; and by a stair hole, on alternate sides of the well, with a one-way ledge under
## it halfway down the storey below, so each floor is climbed to in two of the wizard's own hops
## (Reach.UP). Webs (SpiderWeb) are strung across every hole of the well, and across a share of
## the stair holes (WEB_SHARE). The way back and a lantern stand on the ground at the left, and the
## stair holes over them keep clear of it (BACK_CLEAR). It draws from the arena's own RNG, so it is
## the same every visit; no level is changed by it.

## The hall: its width inside, its walls and roof (cells thick), the roost's rows of air, the
## broken floors and the rows from one to the next, and the ground under it all.
const HALL: int = 18
const WALL: int = 2
const ROOF: int = 2
const ROOST: int = 8
const FLOORS: int = 5
const STOREY: int = 4
const GROUND: int = 2
## The whole keep, in cells.
const SIZE: Vector2i = Vector2i(HALL + 2 * WALL, ROOF + ROOST + FLOORS * STOREY + GROUND)
## How wide a hole is, and the floor kept between a stair hole and the wall (at least) and the well.
const HOLE: int = 3
const TO_WALL: int = 1
const TO_WELL: int = 2
## The well's first column is dealt from WELL_FROM to WELL_TO.
const WELL_FROM: int = WALL + 6
const WELL_TO: int = WALL + HALL - HOLE - 4
## The way back and its lantern on the ground, and the columns the lowest stair hole keeps off.
const BACK_X: int = WALL + 1
const LANTERN_X: int = WALL + 4
const BACK_CLEAR: int = WALL + 6
## The share of the stair holes with a web across them (every hole of the well has one).
const WEB_SHARE: float = 0.5


## Lay the keep out in `w` (see the class description), with `boss` hanging in the middle of the
## roost, under the roof.
static func build(w: LevelGen, boss: StringName) -> void:
	var inside: Rect2i = Rect2i(WALL, ROOF, HALL, SIZE.y - ROOF - GROUND)
	var floor_rows: Array[int] = []
	for k: int in range(FLOORS):
		floor_rows.append(ROOF + ROOST + k * STOREY)
	for x: int in range(SIZE.x):
		for y: int in range(SIZE.y):
			var v: Vector2i = Vector2i(x, y)
			var open: bool = inside.has_point(v) and not floor_rows.has(y)
			if open:
				if w.get_cell(v).type != LevelGen.Type.EMPTY:
					w._to_open(v)
				w.interiors[v] = true
			else:
				if w.get_cell(v).type != LevelGen.Type.GROUND:
					w._to_rock(v)
				w.masonry[v] = true
	var well: int = WELL_FROM + w.rng.randi_range(0, WELL_TO - WELL_FROM)
	var holes: Array[Rect2i] = []
	var stairs: Array[Rect2i] = []
	var ledges: Array[Vector2i] = []
	var webs: Array[Rect2i] = []
	var left_first: bool = w.rng.randi_range(0, 1) == 0
	for k: int in range(FLOORS):
		var row: int = floor_rows[k]
		var shaft: Rect2i = Rect2i(well, row, HOLE, 1)
		holes.append(shaft)
		webs.append(shaft)
		# The stair hole, on this floor's side of the well (or the other, where this one has no
		# room), clear of the way back under the lowest floor.
		var lowest: bool = k == FLOORS - 1
		var left: Vector2i = Vector2i(maxi(WALL + TO_WALL, BACK_CLEAR if lowest else 0), well - TO_WELL - HOLE)
		var right: Vector2i = Vector2i(well + HOLE + TO_WELL, WALL + HALL - TO_WALL - HOLE)
		var sides: Array[Vector2i] = []
		for side: Vector2i in ([left, right] if (k % 2 == 0) == left_first else [right, left]):
			if side.y >= side.x:
				sides.append(side)
		if sides.is_empty():
			continue
		var span: Vector2i = sides[0]
		var stair: Rect2i = Rect2i(span.x + w.rng.randi_range(0, span.y - span.x), row, HOLE, 1)
		holes.append(stair)
		stairs.append(stair)
		if w.rng.randf() < WEB_SHARE:
			webs.append(stair)
	for hole: Rect2i in holes:
		for x: int in range(hole.position.x, hole.end.x):
			var v: Vector2i = Vector2i(x, hole.position.y)
			w._to_open(v)
			w.masonry.erase(v)
			w.interiors[v] = true
	for stair: Rect2i in stairs:
		for x: int in range(stair.position.x, stair.end.x):
			@warning_ignore("integer_division")
			var ledge: Vector2i = Vector2i(x, stair.position.y + STOREY / 2)
			w.put(ledge, LevelGen.Type.PLATFORM)
			ledges.append(ledge)
	var ground: int = inside.end.y - 1
	var back: Vector2i = Vector2i(BACK_X, ground)
	var lantern: Vector2i = Vector2i(LANTERN_X, ground)
	w.put(back, LevelGen.Type.EXIT, MapInfo.Exit.BACK)
	w.put(lantern, LevelGen.Type.CHECKPOINT)
	w.exits = {MapInfo.Exit.BACK: back}
	w.exit_lanterns = {MapInfo.Exit.BACK: lantern}
	@warning_ignore("integer_division")
	w.put(Vector2i(SIZE.x / 2, ROOF), LevelGen.Type.BOSS, boss)
	w.keep = {
		"inside": inside, "floors": floor_rows, "well": well, "holes": holes, "stairs": stairs,
		"ledges": ledges, "webs": webs,
	}
