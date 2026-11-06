class_name LodeHall
extends RefCounted
## The lodestone golem's hall (the crags' boss, docs/REGIONS_PLAN.md §6): a wide hall of masonry
## at the top of the crags' gate level, two galleries over its ground floor, the golem asleep on the
## ground floor and the way on standing on the top gallery, so the way up out of the crags is
## reached only up through the hall. It is cut right after the caves are joined and before the
## gondola and the towers (which are laid round it), and only in the golem's gate levels: no other
## level changes. It notes what it holds in LevelGen.keep:
## - "box": the whole hall, its walls, roof and ground included; "inside": its air and galleries
##   inside them (cells);
## - "floors": the rows of its galleries, top first;
## - "gaps": the golem's gap through each gallery, top first; "stairs": the wizard's stair hole
##   through each, top first;
## - "ledges": the one-way ledges under the stair holes;
## - "on": the way on's cell, on the top gallery against a wall; "lair": the golem's cell, on the
##   ground floor under the lower gallery's gap; "doors": the doorways' cells through its walls;
##   "crossbows": the crossbows' cells (arm), once the golem is placed.
## The hall is HALL cells across inside walls WALL thick, under a roof ROOF rows thick and over
## GROUND rows of ground. Inside, three storeys of ROOM rows of air (enough for the golem, which
## stands about three cells tall, to walk and wind up a slam in), the two between them floored by
## galleries. Every gallery is broken twice: by a gap GAP cells wide, which the golem leaps up and
## drops through, and, in the other half of the hall, by a stair hole STAIR cells wide with two
## one-way ledges under it, a hop apart (Reach.UP): the upper right under the hole, the lower beside
## it toward the middle of the hall (clear of the upper, so the climb zigzags), so each gallery is
## climbed to in the wizard's own hops. The galleries' gaps are on opposite sides, so going from the
## ground to the top gallery the golem has to cross the gallery between. The way on stands on the
## top gallery against the wall on its gap's side, across the hall from where its stair comes up. It
## is entered by a doorway through each wall at the ground storey, with a passage out from each to
## the caves. Its stone is kept whole (LevelGen.kept_whole), so nothing later carves, tunnels or
## builds into it, and nothing else is placed inside it. Nothing here draws from the world RNG:
## where it goes, which side its gaps are on and where its holes are are hashed from the level seed.
## Inside it, every damage spell is tempered (tempers, Empower).

## The hall: its width inside, its walls and roof (cells thick), the rows of air in each storey, the
## galleries between the storeys, and the ground under it all.
const HALL: int = 22
const WALL: int = 2
const ROOF: int = 2
const ROOM: int = 5
const GALLERIES: int = 2
const GROUND: int = 2
## The whole hall, in cells.
const SIZE: Vector2i = Vector2i(HALL + 2 * WALL, ROOF + (GALLERIES + 1) * ROOM + GALLERIES + GROUND)
## The level's row its roof starts on (the level's edge is over it).
const TOP: int = 1
## How wide the golem's gap and the wizard's stair hole through a gallery are, and the gallery kept
## (at least) between either and the wall.
const GAP: int = 5
const STAIR: int = 2
const TO_WALL: int = 2
## The doorways through its walls at the ground storey: DOOR_ROWS high, with a passage out from each
## until it meets open air, at most DOOR_REACH cells.
const DOOR_ROWS: int = 2
const DOOR_REACH: int = 8
## How much more an existing building of the crags (a shaft, a keep) counts against a place than
## open air walled over, when choosing where the hall goes.
const BUILT_COST: int = 3
## Salts for the level seed: where it goes, which side its top gallery's gap is on, each gap's place,
## each stair's place, and which wall its first crossbow is in.
const PLACE_DEAL: int = 6800
const SIDE_DEAL: int = 6810
const GAP_DEAL: int = 6820
const STAIR_DEAL: int = 6830
const CROSSBOW_DEAL: int = 6840


## Whether the level `def` describes has the lode hall: the golem's gate level, in every world
## column, while it is a level of its own (not a side world).
static func wanted(def: NextWorldDef) -> bool:
	return not Worlds.is_side(def.coord) and def.gate == &"golem"


## Cut the hall into `w` at the top of the level and keep it in w.keep (see the class description).
## Where it goes: the columns whose stone would wall over the least of the caves and of the crags'
## other buildings, ties dealt by the seed. A level too small for it gets none.
static func cut(w: LevelGen) -> void:
	if w.size.x < SIZE.x + 4 or w.size.y < SIZE.y + TOP + 12:
		return
	var best: int = -1
	var best_score: float = INF
	for x: int in range(2, w.size.x - SIZE.x - 1):
		var box: Rect2i = Rect2i(x, TOP, SIZE.x, SIZE.y)
		var inside: Rect2i = _inside(box)
		var score: float = _h(w, Vector2i(x, TOP), PLACE_DEAL)
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


## The hall's air and galleries in the hall `box`, inside its walls, roof and ground.
static func _inside(box: Rect2i) -> Rect2i:
	return Rect2i(box.position + Vector2i(WALL, ROOF), Vector2i(HALL, SIZE.y - ROOF - GROUND))


## Arm the hall with crossbows (Crossbow) set into its walls, shooting into the hall: one to a
## gallery, in the row the wizard stands in on it, on alternate walls (the first dealt by the level
## seed; the other wall where something already stands against this one). Each takes the hall's
## cell in front of its slit, with {"facing": the way it shoots, "inward": true}, and their cells
## are noted in w.keep["crossbows"]. Placed with the golem, last (LevelGen.place_boss), with no RNG
## draws.
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


## Whether the world point `at` is in the golem's hall of the place being played: there every damage
## spell is tempered (Empower.tempers_now), lodestone or none.
static func tempers(at: Vector2) -> bool:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null or not info.world.keep.has("lair"):
		return false
	return (info.world.keep["box"] as Rect2i).has_point(info.cell_at(at))


## A number in [0, 1) dealt by the level seed and `v` with `salt`.
static func _h(w: LevelGen, v: Vector2i, salt: int) -> float:
	return RisoDecor.h(w.seed_for_colors, v, salt)


## A hole `width` cells wide through gallery row `row`, its first column dealt (by `salt`) from
## `from` to `to` (columns), clamped there.
static func _hole(w: LevelGen, row: int, from: int, to: int, width: int, salt: int) -> Rect2i:
	var at: int = from + int(_h(w, Vector2i(from, row), salt) * float(to - from + 1))
	return Rect2i(clampi(at, from, to), row, width, 1)


## Build the hall in `box` (see the class description).
static func _build(w: LevelGen, box: Rect2i) -> void:
	var o: Vector2i = box.position
	var inside: Rect2i = _inside(box)
	var floor_rows: Array[int] = []
	for k: int in range(GALLERIES):
		floor_rows.append(inside.position.y + ROOM + k * (ROOM + 1))
	var walled: Dictionary = {}
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			var v: Vector2i = Vector2i(x, y)
			w.structures[v] = &"golem"
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
	# Each gallery's gap in one half of the hall and its stair hole in the other, the gaps taking
	# turns from side to side down the hall.
	@warning_ignore("integer_division")
	var half: int = HALL / 2
	var left_first: bool = _h(w, o, SIDE_DEAL) < 0.5
	var gaps: Array[Rect2i] = []
	var stairs: Array[Rect2i] = []
	for k: int in range(GALLERIES):
		var row: int = floor_rows[k]
		var gap_left: bool = (k % 2 == 0) == left_first
		var lo: int = inside.position.x + TO_WALL
		var hi: int = inside.end.x - TO_WALL
		var mid: int = inside.position.x + half
		if gap_left:
			gaps.append(_hole(w, row, lo, mid - GAP, GAP, GAP_DEAL))
			stairs.append(_hole(w, row, mid + 1, hi - STAIR, STAIR, STAIR_DEAL))
		else:
			gaps.append(_hole(w, row, mid + 1, hi - GAP, GAP, GAP_DEAL))
			stairs.append(_hole(w, row, lo, mid - 1 - STAIR, STAIR, STAIR_DEAL))
	for hole: Rect2i in gaps + stairs:
		for x: int in range(hole.position.x, hole.end.x):
			var v: Vector2i = Vector2i(x, hole.position.y)
			w._to_open(v)
			w.masonry.erase(v)
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
	# Whatever the new walls cut off is joined up again round the hall, never through it.
	w.connect_caves(walled)
	# Nothing else is placed inside it.
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			w.empties.erase(Vector2i(x, y))
	var ledges: Array[Vector2i] = []
	for stair: Rect2i in stairs:
		var toward: int = 1 if stair.position.x < inside.position.x + half else -1
		for x: int in range(stair.position.x, stair.end.x):
			for at: Vector2i in [Vector2i(x, stair.position.y + Reach.UP), Vector2i(x + toward * STAIR, stair.position.y + 2 * Reach.UP)]:
				w.put(at, LevelGen.Type.PLATFORM)
				ledges.append(at)
	# The way on, on the top gallery against the wall on its gap's side.
	var on_left: bool = gaps[0].position.x < inside.position.x + half
	var on: Vector2i = Vector2i(inside.position.x if on_left else inside.end.x - 1, floor_rows[0] - 1)
	@warning_ignore("integer_division")
	var lair: Vector2i = Vector2i(gaps[-1].position.x + GAP / 2, inside.end.y - 1)
	w.keep = {
		"box": box, "inside": inside, "floors": floor_rows, "gaps": gaps, "stairs": stairs,
		"ledges": ledges, "on": on, "lair": lair, "doors": doors,
	}
