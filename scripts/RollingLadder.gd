extends MovingPlatform
class_name RollingLadder
## A library's rolling ladder, in the institute where other bands have lifts (LevelGen.make_moving),
## and on the lowest gallery of each library's stacks (Institute): a step (a one-way ledge as wide as
## the ladder, WIDTH) hooked to a rail that runs along its track, and a ladder hanging from the step
## down to the floor, its foot on solid ground all along its track (`stands`). It stays where it is
## left: it rolls along its track only while the wizard is on the ladder and presses a way (`roll`,
## Player). The wizard takes hold of the ladder by pressing up or down on it (Player), climbs it, and
## rolls it along, climbing all the while (out of the way of a bolt, say); climbed to the top they
## step onto the step, at the bottom onto the floor, and a jump or a dash lets go.

## The group every rolling ladder is in, for the wizard to find the one they are on (`at`).
const GROUP: StringName = &"rolling_ladders"
## The most cells a ladder hangs below its step, the fewest (shorter than that it is no ladder), and
## how far either side of its middle it is held (px).
const LADDER_MOST: int = Ladders.LADDER_MOST
const LADDER_LEAST: int = Ladders.LADDER_LEAST
const HOLD: float = 34.0
## How wide its step is (px): the ladder's own width at its top.
const WIDTH: float = 48.0
## How fast it rolls while the wizard on it presses a way (px a second).
const ROLL_SPEED: float = 240.0

## How many cells it hangs below the top of its step (0: no ladder, the step alone).
var rungs: int = 0
## How many cells over its own cell its step stands (a library's ladder hangs from its gallery's row,
## the cell under it its own).
var rise: int = 0
## How far along its track it stands (px from its start), how fast it rolled last step (px a
## second), and the physics frame it was last rolled in.
var along: float = 0.0
var rolling: float = 0.0
var _rolled: int = -10


func _ready() -> void:
	add_to_group(GROUP)


func setup(map_info: MapInfo, v: Vector2i, info: Array) -> void:
	super(map_info, v, info.slice(0, 3))
	rise = int(info[3]) if info.size() > 3 else 0
	start += Vector2.UP * float(rise) * cell_size
	rungs = rise + hang(map_info.world, v, length, int(info[2]))
	# It starts at a place along its track hashed from its cell (MovingPlatform's phase), and stays.
	along = offset_at(t).length()
	_held = start + axis * along
	_place(_held)


## Its step is as wide as the ladder.
func _width() -> float:
	return WIDTH


## Roll it `way` (-1 left, 1 right, 0 not at all) for `delta` seconds, along its track and no further:
## the wizard on it pressing a way (Player._on_ladder).
func roll(way: float, delta: float) -> void:
	var was: float = along
	along = clampf(along + way * ROLL_SPEED * delta, 0.0, travel)
	rolling = (along - was) / delta if delta > 0.0 else 0.0
	_rolled = Engine.get_physics_frames()
	_held = start + axis * along
	position = _held


## It stands where it was left (see roll).
func _physics_process(_delta: float) -> void:
	position = _held


## How many cells a ladder can hang, and how many it hangs with its foot on solid ground (Ladders).
static func hang(w: LevelGen, v: Vector2i, length: int, travel: int) -> int:
	return Ladders.hang(w, v, length, travel)


static func stands(w: LevelGen, v: Vector2i, travel: int) -> int:
	return Ladders.stands(w, v, travel)


## Where its ladder stands (world): the middle of its step, across.
func ladder_x() -> float:
	return global_position.x + float(length - 1) * cell_size * 0.5


## The top of its step (world y) and the foot of its ladder.
func top_y() -> float:
	return global_position.y - cell_size * 0.5


func foot_y() -> float:
	return top_y() + float(rungs) * cell_size


## How fast it is rolling now (px a second, along its track): 0 unless the wizard rolled it this
## physics frame or the last.
func speed() -> float:
	return rolling if Engine.get_physics_frames() - _rolled <= 1 else 0.0


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
