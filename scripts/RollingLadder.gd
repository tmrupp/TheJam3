extends MovingPlatform
class_name RollingLadder
## A library's rolling ladder, in the institute where other bands have lifts (LevelGen.make_moving):
## a step (a one-way ledge, ridden like a lift's) hooked to a rail that runs along its track,
## rolling back and forth along it as a lift glides, and a ladder hanging from the step down to the
## floor or a ledge (or LADDER_MOST cells, whichever is less, so it never runs into either anywhere
## along its track). The wizard takes hold of the ladder by pressing up or down on it (Player), climbs it, and
## is carried along as it rolls, climbing all the while (out of the way of a bolt, say); climbed to
## the top they step onto the step, at the bottom onto the floor, and a jump or a dash lets go.

## The group every rolling ladder is in, for the wizard to find the one they are on (`at`).
const GROUP: StringName = &"rolling_ladders"
## The most cells a ladder hangs below its step, and how far either side of its middle it is held
## (px).
const LADDER_MOST: int = 6
const HOLD: float = 34.0

## How many cells it hangs below the top of its step's cell (0: no ladder, the step alone).
var rungs: int = 0


func _ready() -> void:
	add_to_group(GROUP)


func setup(map_info: MapInfo, v: Vector2i, info: Array) -> void:
	super(map_info, v, info)
	rungs = hang(map_info.world, v, length, int(info[2]))


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


## Whether a ladder hangs on through cell `c`, `depth` cells under its step's: not rock, and under
## the step's own row not a ledge.
static func _hangs_through(w: LevelGen, c: Vector2i, depth: int) -> bool:
	if not w.is_valid(c) or w.is_ground(c):
		return false
	return depth == 0 or w.get_cell(c).type != LevelGen.Type.PLATFORM


## Where its ladder stands (world): the middle of its step, across.
func ladder_x() -> float:
	return global_position.x + float(length - 1) * cell_size * 0.5


## The top of its step (world y) and the foot of its ladder.
func top_y() -> float:
	return global_position.y - cell_size * 0.5


func foot_y() -> float:
	return top_y() + float(rungs) * cell_size


## How fast it is rolling now (px a second, along its track).
func speed() -> float:
	if waiting:
		return 0.0
	var dt: float = 1.0 / 60.0
	return (offset_at(t + dt) - offset_at(t)).x / dt


## The rolling ladder in `tree` whose ladder holds `at` (world; within HOLD across of it, from
## `above` px over its top to its foot), or null.
static func at(tree: SceneTree, spot: Vector2, above: float = 0.0) -> RollingLadder:
	for node: Node in tree.get_nodes_in_group(GROUP):
		var ladder: RollingLadder = node as RollingLadder
		if ladder == null or ladder.rungs <= 0:
			continue
		if absf(spot.x - ladder.ladder_x()) <= HOLD and spot.y >= ladder.top_y() - above and spot.y <= ladder.foot_y():
			return ladder
	return null
