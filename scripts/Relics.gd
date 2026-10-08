class_name Relics
extends RefCounted
## Relics: the big movement abilities and astral projection (MOVES), which open up whole areas,
## are not taught at shrines until found. Tier I of each only comes from a relic, which lies in a
## secret room (see LevelGen.place_secrets) or behind a bone gate in rare levels: from depth
## MIN_DEPTH, CHANCE % of them rising to CHANCE_MAX deeper (see chance; about one in 15, so a big
## move means going out of your way), each holding one of MOVES dealt by its seed (every level of a
## debug run holds one). Once a move is known, shrines offer its higher tiers as usual. At full
## health, a shrine's mending station sells the whereabouts of the nearest relic not yet found
## instead (HINT_PRICE times its level's deeper price), marked on the worlds map (see nearest).

const MOVES: Array[StringName] = [&"double_jump", &"wall_climb", &"blink", &"levitate", &"astral"]
const CHANCE: int = 5
## Relics lie no shallower than this; from there the chance rises a point every two levels, up to
## CHANCE_MAX, so a run meets about as many as before, only deeper.
const MIN_DEPTH: int = 3
const CHANCE_MAX: int = 8
const PRICE: float = 4.0
const HINT_PRICE: float = 1.5
## How far (in levels, across and down) a shrine looks for a relic.
const SEARCH: int = 12


## The share (%) of levels `depth` deep that hold a relic (0 above MIN_DEPTH).
static func chance(depth: int) -> int:
	if depth < MIN_DEPTH:
		return 0
	@warning_ignore("integer_division")
	return mini(CHANCE + (depth - MIN_DEPTH) / 2, CHANCE_MAX)


## The move the relic in level `at` holds, or &"" for a level without one.
static func at(at: Vector2i) -> StringName:
	if Worlds.is_side(at):
		return &""
	var h: int = Rules.level_seed(Rules.level_seed(at.x, at.y), 4242)
	var d: int = absi(at.y)
	if not MapInfo.debug and (d < MIN_DEPTH or h % 100 >= chance(d)):
		return &""
	@warning_ignore("integer_division")
	return MOVES[(h / 100) % MOVES.size()]


## The level nearest `from` (by levels across plus rows down or up, either side of the start)
## holding a relic not in `found`, or null if none is within SEARCH. Ties go to the higher row,
## then the one to the left.
static func nearest(from: Vector2i, found: Dictionary) -> Variant:
	for d: int in range(SEARCH + 1):
		for dy: int in range(-d, d + 1):
			var y: int = from.y + dy
			if Worlds.is_side(Vector2i(from.x, y)):
				continue
			var rest: int = d - absi(dy)
			for x: int in ([from.x - rest, from.x + rest] if rest > 0 else [from.x]):
				var c: Vector2i = Vector2i(x, y)
				if at(c) != &"" and not found.has(c):
					return c
	return null


## Stars to take the relic in a level `depth` from the start.
static func price(depth: int) -> int:
	return roundi(Rules.deeper_price(depth) * PRICE)


## Stars for a relic's whereabouts at a shrine in a level `depth` from the start.
static func hint_price(depth: int) -> int:
	return roundi(Rules.deeper_price(depth) * HINT_PRICE)
