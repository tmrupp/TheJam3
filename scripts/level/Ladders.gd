class_name Ladders
extends RefCounted
## Where a rolling ladder can hang and stand in a level's cells, apart from the ladder itself
## (RollingLadder, a body in the scene, has hang and stands under the same names): the generator
## asks as it lays one out (LevelGen._make_ladder; docs/CODE_REVIEW.md 2.1).

## The most cells a ladder hangs below its step, and the fewest (shorter than that it is no ladder).
const LADDER_MOST: int = 6
const LADDER_LEAST: int = 2
## What a ladder hanging through a cell would run into.
const SOLID: Array[LevelGen.Type] = [LevelGen.Type.PLATFORM, LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.PHASE_BLOCK]


## How many cells a ladder from cell `v`, its step `length` cells long rolling `travel` cells right,
## can hang: the cells under the top of its step's cell down to rock or a ledge, the fewest of any
## column it passes over, at most LADDER_MOST.
static func hang(w: LevelGen, v: Vector2i, length: int, travel: int) -> int:
	var most: int = LADDER_MOST
	for x: int in range(v.x, v.x + length + travel):
		var open: int = 0
		while open < most and _hangs_through(w, Vector2i(x, v.y + open), open):
			open += 1
		most = mini(most, open)
	return most


## How many cells a ladder whose step is at cell `v`, rolling `travel` cells right, hangs with its
## foot on solid ground: the same number down to rock in every column it passes over (a flat floor
## under its whole track), from LADDER_LEAST to LADDER_MOST; 0 where it would stand on a ledge, in
## the air, or on a floor that rises or falls along its track.
static func stands(w: LevelGen, v: Vector2i, travel: int) -> int:
	var depth: int = -1
	for x: int in range(v.x, v.x + travel + 1):
		var open: int = 0
		while open <= LADDER_MOST and _hangs_through(w, Vector2i(x, v.y + open), open):
			open += 1
		if open < LADDER_LEAST or open > LADDER_MOST or not w.is_ground(Vector2i(x, v.y + open)) or (depth >= 0 and open != depth):
			return 0
		depth = open
	return depth


## Whether a ladder hangs on through cell `c`, `depth` cells under its step's: not rock, and under
## the step's own row nothing it would run into (a ledge, a crumbling block, a door or a gate).
static func _hangs_through(w: LevelGen, c: Vector2i, depth: int) -> bool:
	if not w.is_valid(c) or w.is_ground(c):
		return false
	return depth == 0 or not w.type_at(c) in SOLID
