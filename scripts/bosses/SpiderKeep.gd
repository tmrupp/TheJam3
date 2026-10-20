class_name SpiderKeep
extends RefCounted
## The spider's keep (Bosses.UP's first, docs/REGIONS_PLAN.md §6): a tall hall of broken floors
## built of masonry at the top of the crags' gate level, the spider (Spider) hanging in the dark
## under its roof and the way on standing on its top floor, so the way up out of the crags is
## reached only up through the keep. cut lays it over whatever the collapse made, right after the
## caves are joined and before the gondola and the towers (which are laid round it), and only in the
## spider's gate levels: no other level changes. It notes what it holds in LevelGen.keep:
## - "box": the whole keep, its walls, roof and ground included; "inside": the hall's air and
##   floors inside them (cells);
## - "floors": the rows of its broken floors, top first; "well": the first column of the well;
## - "holes": every hole in the floors (the well's and the stairs'), "stairs": the stair holes alone;
## - "ledges": the one-way ledges under the stair holes; "webs": the cells each web spans;
## - "on": the way on's cell, on the top floor against a wall; "roost": the spider's cell, under
##   the roof; "doors": the doorways' cells through its walls; "crossbows": the crossbows' cells
##   (arm), once the spider is placed.
## The hall is HALL cells across inside walls WALL thick, under a roof ROOF rows thick. Under the
## roof is the spider's roost, ROOST rows of air; under that FLOORS broken floors, a STOREY apart,
## and under the lowest the ground storey and the ground. Every floor is broken twice: by the well,
## a hole HOLE cells wide in the same columns all the way down, which the spider drops through and
## climbs back up; and by a stair hole, on alternate sides of the well, with a one-way ledge under
## it halfway down the storey below, so each floor is climbed to in two of the wizard's own hops
## (Reach.UP). Webs (SpiderWeb) are strung across every hole of the well, and across a share of
## the stair holes (WEB_SHARE). It is entered by a doorway through each wall at the ground storey,
## with a passage out from each to the caves. Its stone is kept whole (LevelGen.kept_whole), so
## nothing later carves, tunnels or builds into it, and nothing else is placed inside it. Nothing
## here draws from the world RNG: where it goes, its well, stairs and webs are hashed from the
## level seed.

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
## The level's row its roof starts on (the level's edge is over it).
const TOP: int = 1
## How wide a hole is, and the floor kept between a stair hole and the wall (at least) and the well.
const HOLE: int = 3
const TO_WALL: int = 1
const TO_WELL: int = 2
## The well's first column, counting from the keep's left edge, is dealt from WELL_FROM to WELL_TO.
const WELL_FROM: int = WALL + 6
const WELL_TO: int = WALL + HALL - HOLE - 4
## The share of the stair holes with a web across them (every hole of the well has one).
const WEB_SHARE: float = 0.5
## The doorways through its walls at the ground storey: DOOR_ROWS high, with a passage out from each
## until it meets open air, at most DOOR_REACH cells.
const DOOR_ROWS: int = 2
const DOOR_REACH: int = 8
## How much more an existing building of the crags (a shaft, a keep) counts against a place than
## open air walled over, when choosing where the keep goes.
const BUILT_COST: int = 3
## Salts for the level seed: where it goes, its well, which side its first stair is on, each
## stair's place, each stair's web, and which wall its first crossbow is in.
const PLACE_DEAL: int = 6700
const WELL_DEAL: int = 6710
const SIDE_DEAL: int = 6720
const STAIR_DEAL: int = 6730
const WEB_DEAL: int = 6740
const CROSSBOW_DEAL: int = 6750


## Whether the level `def` describes has the spider's keep: the crags' gate level, in every world
## column, while it is a level of its own (not a side world).
static func wanted(def: NextWorldDef) -> bool:
	return not Worlds.is_side(def.coord) and def.gate == &"spider"


## Cut the keep into `w` at the top of the level and keep it in w.keep (see the class
## description). Where it goes: the columns whose stone would wall over the least of the caves and
## of the crags' other buildings, ties dealt by the seed. A level too small for it gets none.
static func cut(w: LevelGen) -> void:
	if w.size.x < SIZE.x + 4 or w.size.y < SIZE.y + TOP + 12:
		return
	var best: int = -1
	var best_score: float = INF
	for x: int in range(2, w.size.x - SIZE.x - 1):
		var box: Rect2i = Rect2i(x, TOP, SIZE.x, SIZE.y)
		var inside: Rect2i = _inside(box)
		var score: float = RisoDecor.h(w.seed_for_colors, Vector2i(x, TOP), PLACE_DEAL)
		for cx: int in range(box.position.x, box.end.x):
			for cy: int in range(box.position.y, box.end.y):
				var c: Vector2i = Vector2i(cx, cy)
				if w.structures.has(c):
					score += float(BUILT_COST)
				elif not inside.has_point(c) and not w.is_ground(c):
					score += 1.0
		if score < best_score:
			best_score = score
			best = x
	if best >= 0:
		_build(w, Rect2i(best, TOP, SIZE.x, SIZE.y))


## The hall's air and floors in the keep `box`, inside its walls, roof and ground.
static func _inside(box: Rect2i) -> Rect2i:
	return Rect2i(box.position + Vector2i(WALL, ROOF), Vector2i(HALL, SIZE.y - ROOF - GROUND))


## Arm the keep with crossbows (Crossbow) set into its hall's walls, shooting into the hall: one to a
## floor, in the row the wizard stands in on it, on alternate walls (the first dealt by the level
## seed; the other wall where the way on stands against this one). Each takes the hall's cell in
## front of its slit, with {"facing": the way it shoots, "inward": true}, and their cells are noted
## in w.keep["crossbows"]. Their arrows pierce the spider (Bullet). Placed with the spider, last
## (LevelGen.place_boss), with no RNG draws.
static func arm(w: LevelGen) -> void:
	if w.keep.is_empty():
		return
	var inside: Rect2i = w.keep["inside"]
	var floors: Array[int] = w.keep["floors"]
	var left_first: bool = _h(w, inside.position, CROSSBOW_DEAL) < 0.5
	var bows: Array[Vector2i] = []
	for k: int in range(floors.size()):
		var left: bool = (k % 2 == 0) == left_first
		for side: bool in [left, not left]:
			var at: Vector2i = Vector2i(inside.position.x if side else inside.end.x - 1, floors[k] - 1)
			if w.get_cell(at).type != LevelGen.Type.EMPTY:
				continue
			w.put(at, LevelGen.Type.CROSSBOW, {"facing": 1 if side else -1, "inward": true})
			bows.append(at)
			break
	w.keep["crossbows"] = bows


## A number in [0, 1) dealt by the level seed and `v` with `salt`.
static func _h(w: LevelGen, v: Vector2i, salt: int) -> float:
	return RisoDecor.h(w.seed_for_colors, v, salt)


## Build the keep in `box` (see the class description).
static func _build(w: LevelGen, box: Rect2i) -> void:
	var o: Vector2i = box.position
	var inside: Rect2i = _inside(box)
	var floor_rows: Array[int] = []
	for k: int in range(FLOORS):
		floor_rows.append(o.y + ROOF + ROOST + k * STOREY)
	var walled: Dictionary = {}
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			var v: Vector2i = Vector2i(x, y)
			w.structures[v] = &"spider"
			if inside.has_point(v) and not floor_rows.has(y):
				if not w._open(v) or w.get_cell(v).type != LevelGen.Type.EMPTY:
					w._to_open(v)
				w.masonry.erase(v)
				w.interiors[v] = true
			else:
				if w.get_cell(v).type != LevelGen.Type.GROUND:
					w._to_rock(v)
				w.masonry[v] = true
				w.interiors.erase(v)
				walled[v] = true
	var well: int = o.x + WELL_FROM + int(_h(w, o, WELL_DEAL) * float(WELL_TO - WELL_FROM + 1))
	well = clampi(well, o.x + WELL_FROM, o.x + WELL_TO)
	var holes: Array[Rect2i] = []
	var stairs: Array[Rect2i] = []
	var ledges: Array[Vector2i] = []
	var webs: Array[Rect2i] = []
	var left_first: bool = _h(w, o, SIDE_DEAL) < 0.5
	for k: int in range(FLOORS):
		var row: int = floor_rows[k]
		var shaft: Rect2i = Rect2i(well, row, HOLE, 1)
		holes.append(shaft)
		webs.append(shaft)
		# The stair hole, on this floor's side of the well (or the other, where this one has no
		# room).
		var left: Vector2i = Vector2i(inside.position.x + TO_WALL, well - TO_WELL - HOLE)
		var right: Vector2i = Vector2i(well + HOLE + TO_WELL, inside.end.x - TO_WALL - HOLE)
		var sides: Array[Vector2i] = []
		for side: Vector2i in ([left, right] if (k % 2 == 0) == left_first else [right, left]):
			if side.y >= side.x:
				sides.append(side)
		if sides.is_empty():
			continue
		var span: Vector2i = sides[0]
		var at: int = span.x + int(_h(w, Vector2i(k, row), STAIR_DEAL) * float(span.y - span.x + 1))
		var stair: Rect2i = Rect2i(clampi(at, span.x, span.y), row, HOLE, 1)
		holes.append(stair)
		stairs.append(stair)
		if _h(w, Vector2i(k, row), WEB_DEAL) < WEB_SHARE:
			webs.append(stair)
	for hole: Rect2i in holes:
		for x: int in range(hole.position.x, hole.end.x):
			var v: Vector2i = Vector2i(x, hole.position.y)
			w._to_open(v)
			w.interiors[v] = true
			walled.erase(v)
	# A doorway through each wall at the ground storey, and a passage on out to open air.
	var doors: Array[Vector2i] = []
	var bottom: int = inside.end.y - 1
	for side: int in [-1, 1]:
		var wall_x: int = inside.position.x - 1 if side < 0 else inside.end.x
		for k: int in range(0, WALL + DOOR_REACH):
			var x: int = wall_x + side * k
			if x < 1 or x > w.size.x - 2:
				break
			var past: bool = k >= WALL
			if past and range(bottom - DOOR_ROWS + 1, bottom + 1).any(func(y: int) -> bool: return w._open(Vector2i(x, y))):
				break
			for y: int in range(bottom - DOOR_ROWS + 1, bottom + 1):
				var v: Vector2i = Vector2i(x, y)
				if not w._open(v) or w.get_cell(v).type != LevelGen.Type.EMPTY:
					w._to_open(v)
				walled.erase(v)
				if not past:
					w.interiors[v] = true
					doors.append(v)
	for v: Vector2i in walled:
		w.kept_whole[v] = true
	# Whatever the new walls cut off is joined up again round the keep, never through it.
	w.connect_caves(walled)
	# Nothing else is placed inside it.
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			w.empties.erase(Vector2i(x, y))
	for stair: Rect2i in stairs:
		for x: int in range(stair.position.x, stair.end.x):
			@warning_ignore("integer_division")
			var ledge: Vector2i = Vector2i(x, stair.position.y + STOREY / 2)
			w.put(ledge, LevelGen.Type.PLATFORM)
			ledges.append(ledge)
	# The way on, on the top floor against whichever wall has no hole under it.
	var top_floor: int = floor_rows[0]
	var on: Vector2i = Vector2i(inside.position.x, top_floor - 1)
	if holes.any(func(h: Rect2i) -> bool: return h.has_point(Vector2i(on.x, top_floor))):
		on = Vector2i(inside.end.x - 1, top_floor - 1)
	@warning_ignore("integer_division")
	var roost: Vector2i = Vector2i(o.x + SIZE.x / 2, inside.position.y)
	w.keep = {
		"box": box, "inside": inside, "floors": floor_rows, "well": well, "holes": holes,
		"stairs": stairs, "ledges": ledges, "webs": webs, "on": on, "roost": roost, "doors": doors,
	}
