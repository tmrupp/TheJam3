class_name BrambleShaft
extends RefCounted
## The bramble's shaft (Bosses.GARDEN_UP, docs/REGIONS_PLAN.md §6): the way up out of the garden is
## a tall shaft of rock cut near the top of its gate level, WIDTH cells wide inside, its height
## from the level's height. Its head is walled in: a landing of rock on one side holds the way on,
## and the knot the bramble is rooted in fills the rest of the head beside it, so the way on is
## reached only up the shaft, and only once the knot is gone. Ledges climb it from side to side,
## a hop apart; at its foot a low passage runs out through both walls to the caves. Its walls hold
## the bramble's bulbs (its weak points) and the roots of its thorn vines (Bramble).
## Cut right after the caves are joined, before anything else is placed, so the rest of the level
## lands round it, and only in the bramble's gate levels: no other level changes. Nothing here draws
## from the world RNG: where it goes and what is set in its walls are hashed from the level seed.
## Kept in LevelGen.shaft (see cut).

## How wide it is inside (cells), and how tall: HEIGHT_SHARE of the level's height, at least
## HEIGHT_MIN, made even so its ledges come out a hop above its floor.
const WIDTH: int = 4
const HEIGHT_SHARE: float = 0.5
const HEIGHT_MIN: int = 12
## The row its roof is on (the first open row is the next one down).
const ROOF: int = 1
## The landing at its head, LANDING cells across against one wall, with the way on standing at the
## wall and the relic's place beside it; the knot fills the rest of the head, KNOT_ROWS rows.
const LANDING: int = 2
const KNOT_ROWS: int = 3
## Ledges up the shaft, one cell wide against a wall, LEDGE_EVERY rows apart (a hop), from side to
## side; the first under the knot.
const LEDGE_EVERY: int = 2
## The passage out through both walls at its foot: FOOT_ROWS high, out until it meets open air, at
## most FOOT_REACH cells.
const FOOT_ROWS: int = 2
const FOOT_REACH: int = 8
## How many bulbs it has (BULBS.x to BULBS.y, dealt by the seed), and how far apart (rows) the thorn
## vines' roots are on each wall, kept VINE_CLEAR rows from a bulb on the same wall.
const BULBS: Vector2i = Vector2i(3, 5)
const VINE_APART: int = 4
const VINE_CLEAR: int = 1
## Salts for the level seed: where it goes, which side its landing is on, and its bulbs and vines.
const PLACE_DEAL: int = 6600
const SIDE_DEAL: int = 6610
const BULB_DEAL: int = 6620
const VINE_DEAL: int = 6630


## Whether the level `def` describes has the bramble's shaft: the garden's way up, in every world
## column, while it is a level of its own (not a side world).
static func wanted(def: NextWorldDef) -> bool:
	return not Worlds.is_side(def.coord) and def.gate == Bosses.GARDEN_UP


## Cut the shaft into `w` and keep it in w.shaft:
## - "inside": the open shaft (Rect2i), its walls, roof and floor round it;
## - "on": the way on's cell, on the landing against the wall; "relic": the landing's other cell;
## - "knot": the cells the knot fills (Rect2i), beside the landing;
## - "ledges": the ledges' cells; "bulbs" and "vines": [the wall cell, the way into the shaft]
##   for each bulb and each vine's root.
## Where it goes: the columns whose walls, roof and floor would wall over the least of the caves
## (and whose foot reaches them soonest), ties dealt by the seed.
static func cut(w: LevelGen) -> void:
	var height: int = maxi(HEIGHT_MIN, roundi(float(w.size.y) * HEIGHT_SHARE))
	height += height % 2
	var top: int = ROOF + 1
	height = mini(height, w.size.y - top - 3)
	height -= height % 2
	if height < HEIGHT_MIN or w.size.x < WIDTH + 6:
		return
	var best: int = -1
	var best_score: float = INF
	for a: int in range(2, w.size.x - 1 - WIDTH):
		var inside: Rect2i = Rect2i(a, top, WIDTH, height)
		var walled: int = 0
		for c: Vector2i in _rock_cells(inside):
			if not w.is_ground(c):
				walled += 1
		var foot: int = mini(_foot_length(w, inside, -1), _foot_length(w, inside, 1))
		var score: float = float(walled * 4 + foot) + RisoDecor.h(w.seed_for_colors, Vector2i(a, top), PLACE_DEAL)
		if score < best_score:
			best_score = score
			best = a
	if best < 0:
		return
	_build(w, Rect2i(best, top, WIDTH, height))


## The cells of the shaft made rock round `inside`: its roof, its walls (but for the foot) and its
## floor.
static func _rock_cells(inside: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var bottom: int = inside.end.y - 1
	for x: int in range(inside.position.x - 1, inside.end.x + 1):
		out.append(Vector2i(x, inside.position.y - 1))
		out.append(Vector2i(x, bottom + 1))
	for y: int in range(inside.position.y, bottom - FOOT_ROWS + 1):
		out.append(Vector2i(inside.position.x - 1, y))
		out.append(Vector2i(inside.end.x, y))
	return out


## How far (cells) the foot's passage must run out of the wall on `side` (-1 left, 1 right) to
## meet open air, FOOT_REACH + 1 if it does not within reach.
static func _foot_length(w: LevelGen, inside: Rect2i, side: int) -> int:
	var bottom: int = inside.end.y - 1
	var wall: int = inside.position.x - 1 if side < 0 else inside.end.x
	for k: int in range(1, FOOT_REACH + 1):
		var x: int = wall + side * k
		if x < 1 or x > w.size.x - 2:
			break
		for y: int in range(bottom - FOOT_ROWS + 1, bottom + 1):
			if w._open(Vector2i(x, y)):
				return k
	return FOOT_REACH + 1


## Build the shaft whose open inside is `inside` (see cut).
static func _build(w: LevelGen, inside: Rect2i) -> void:
	var top: int = inside.position.y
	var bottom: int = inside.end.y - 1
	var a: int = inside.position.x
	var walled: Dictionary = {}
	for c: Vector2i in _rock_cells(inside):
		if not w.is_ground(c):
			w._to_rock(c)
		walled[c] = true
	for x: int in range(a, inside.end.x):
		for y: int in range(top, bottom + 1):
			if not w._open(Vector2i(x, y)) or w.get_cell(Vector2i(x, y)).type != LevelGen.Type.EMPTY:
				w._to_open(Vector2i(x, y))
	# The foot: out through each wall, as far as open air (or FOOT_REACH).
	for side: int in [-1, 1]:
		var wall: int = a - 1 if side < 0 else inside.end.x
		for k: int in range(0, FOOT_REACH + 1):
			var x: int = wall + side * k
			if x < 1 or x > w.size.x - 2:
				break
			if k > 0 and range(bottom - FOOT_ROWS + 1, bottom + 1).any(func(y: int) -> bool: return w._open(Vector2i(x, y))):
				break
			for y: int in range(bottom - FOOT_ROWS + 1, bottom + 1):
				if not w._open(Vector2i(x, y)) or w.get_cell(Vector2i(x, y)).type != LevelGen.Type.EMPTY:
					w._to_open(Vector2i(x, y))
	# The landing against one wall, the knot beside it.
	var left: bool = RisoDecor.h(w.seed_for_colors, Vector2i(a, top), SIDE_DEAL) < 0.5
	var landing_x: int = a if left else inside.end.x - LANDING
	var knot_x: int = a + LANDING if left else a
	for x: int in range(landing_x, landing_x + LANDING):
		w._to_rock(Vector2i(x, top + 2))
		walled[Vector2i(x, top + 2)] = true
	var on: Vector2i = Vector2i(a if left else inside.end.x - 1, top + 1)
	var relic: Vector2i = on + (Vector2i.RIGHT if left else Vector2i.LEFT)
	# Whatever the new walls cut off is joined up again round the shaft, never through it.
	w.connect_caves(walled)
	# Nothing else is placed inside it.
	for x: int in range(a, inside.end.x):
		for y: int in range(top, bottom + 1):
			w.empties.erase(Vector2i(x, y))
	# Ledges from side to side, the first under the knot against the far wall from the landing.
	var ledges: Array[Vector2i] = []
	var side_x: Array[int] = [a, inside.end.x - 1]
	var turn: int = 0 if left else 1
	for row: int in range(top + KNOT_ROWS + 1, bottom, LEDGE_EVERY):
		var ledge: Vector2i = Vector2i(side_x[(turn + 1) % 2], row)
		turn += 1
		w.put(ledge, LevelGen.Type.PLATFORM)
		ledges.append(ledge)
	w.shaft = {
		"inside": inside,
		"on": on,
		"relic": relic,
		"knot": Rect2i(knot_x, top, WIDTH - LANDING, KNOT_ROWS),
		"ledges": ledges,
		"bulbs": _bulbs(w, inside),
	}
	w.shaft["vines"] = _vines(w, inside, w.shaft["bulbs"])


## The rows of the walls between the knot and the foot, where bulbs and vines go.
static func _rows(inside: Rect2i) -> Vector2i:
	return Vector2i(inside.position.y + KNOT_ROWS, inside.end.y - 1 - FOOT_ROWS)


## The bulbs (BULBS.x to BULBS.y of them, by the seed): one in each of as many bands down the walls,
## at a row in it dealt by the seed, from wall to wall.
static func _bulbs(w: LevelGen, inside: Rect2i) -> Array:
	var rows: Vector2i = _rows(inside)
	var s: int = w.seed_for_colors
	var count: int = BULBS.x + int(RisoDecor.h(s, inside.position, BULB_DEAL) * float(BULBS.y - BULBS.x + 1))
	count = clampi(count, BULBS.x, BULBS.y)
	var side: int = 0 if RisoDecor.h(s, inside.position, BULB_DEAL + 1) < 0.5 else 1
	var out: Array = []
	var span: float = float(rows.y - rows.x + 1) / float(count)
	for i: int in range(count):
		var lo: int = rows.x + floori(span * float(i))
		var hi: int = maxi(lo, rows.x + floori(span * float(i + 1)) - 1)
		var row: int = lo + int(RisoDecor.h(s, Vector2i(i, inside.position.y), BULB_DEAL + 2) * float(hi - lo + 1))
		row = clampi(row, lo, hi)
		var wall: Vector2i = _wall(inside, (side + i) % 2, row)
		out.append([wall, Vector2i.RIGHT if (side + i) % 2 == 0 else Vector2i.LEFT])
	return out


## The vines' roots: on each wall every VINE_APART rows from a row dealt by the seed, clear of the
## bulbs on that wall.
static func _vines(w: LevelGen, inside: Rect2i, bulbs: Array) -> Array:
	var rows: Vector2i = _rows(inside)
	var out: Array = []
	for side: int in [0, 1]:
		var first: int = rows.x + int(RisoDecor.h(w.seed_for_colors, Vector2i(side, inside.position.y), VINE_DEAL) * float(VINE_APART))
		for row: int in range(first, rows.y + 1, VINE_APART):
			var wall: Vector2i = _wall(inside, side, row)
			if bulbs.any(func(b: Array) -> bool: return (b[0] as Vector2i).x == wall.x and absi((b[0] as Vector2i).y - row) <= VINE_CLEAR):
				continue
			out.append([wall, Vector2i.RIGHT if side == 0 else Vector2i.LEFT])
	return out


## The wall cell on `side` (0 left, 1 right) of the shaft `inside` at `row`.
static func _wall(inside: Rect2i, side: int, row: int) -> Vector2i:
	return Vector2i(inside.position.x - 1 if side == 0 else inside.end.x, row)
