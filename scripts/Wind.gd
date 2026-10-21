class_name Wind
extends Node2D
## Moving air, in sky levels (SkyArchetype.populate, carve_chasms). Two kinds:
## - an updraft ({"up": cells}): a shaft of rising air over a floor, always blowing, that lifts the
##   wizard to just over a floor beside its top;
## - the crosswind over a gap ({"chasm": id, "width": cells}), set aside for now (nothing places
##   one: the level's gusts cross its gaps): the level's wind held over a gap, carrying the wizard
##   over and holding them up as they go.
## The level's wind (Rules.wind_of: its vanes, Vane) comes in gusts (MapInfo.gusting): STILL seconds
## of stillness, then a gust, over and over. A gust blows the level's wind's way at CARRY px/s
## however many vanes set it; more vanes make it blow longer, not harder: GUST seconds for one,
## GUST_STEP more for each vane past the first (at most GUST_MAX, gust_for).
## The wizard asks push_at each physics step (Player): an updraft eases their rise toward
## LIFT_SPEED; a crosswind carries them along and lets them sink no faster than GLIDE (not at all:
## they float level across). Up/down steers at STEER_SPEED within a crosswind, so the wizard can
## descend out of it before reaching the far side. A gust blows across the whole level
## (MapInfo.gust_at): anywhere in its open air it carries the wizard its way while they are off the
## ground, bearing them up so they sink no faster than GUST_SINK (holding Down drops them out of
## that, to fall as ever), GROUND_SHARE of that carry while
## they stand, and not at all where rock shelters them, LEE cells upwind on their row or the row
## over it (close by a wall on the side it comes from). So the gaps between islands are crossed in a
## gust, with the wind; one it blows across the wrong way cannot be crossed until it is turned.

const LIFT_SPEED: float = 430.0
const LIFT_ACCEL: float = 2600.0
const CARRY: float = 480.0
const GROUND_SHARE: float = 0.35
const GUST_SINK: float = 60.0
const LEE: int = 2
const STILL: float = 3.5
const GUST: float = 3.0
const GUST_STEP: float = 1.5
const GUST_MAX: float = 9.0
const WARN: float = 1.0
const GLIDE: float = 0.0
const STEER_SPEED: float = 240.0

var map_info: MapInfo
## Cells the updraft rises (0 for a crosswind).
var up: int = 0
## The chasm a crosswind spans (-1 for an updraft), and its width in cells.
var chasm: int = -1
var width: int = 0
## The moving air, in world space.
var rect: Rect2 = Rect2()


func setup(info: MapInfo, v: Vector2i, extra: Dictionary) -> void:
	map_info = info
	var cell: Vector2 = Vector2(info.tile_map.tile_set.tile_size) * info.tile_map.global_scale
	var at: Vector2 = info.cell_position(v)
	if extra.has("up"):
		up = int(extra["up"])
		var floor_y: float = at.y + cell.y * 0.5
		rect = Rect2(Vector2(at.x - cell.x * 0.5, floor_y - cell.y * float(up)), Vector2(cell.x, cell.y * float(up)))
	else:
		chasm = int(extra["chasm"])
		width = int(extra["width"])
		# `v` is the chasm's first cell under its floor row; the wind fills the three rows over the
		# floor and the one under it, from the last cell of floor on one side to the first on the
		# other.
		var corner: Vector2 = info.cell_position(Vector2i(v.x - 1, v.y - 3)) - cell * 0.5
		rect = Rect2(corner, Vector2(cell.x * float(width + 2), cell.y * 4.0))
	# Sit in the middle of the air it moves, so its art is drawn whenever any of it is in view.
	global_position = rect.get_center()


## Which way a crosswind blows along x (+1 right, -1 left): the level's wind's in a gust
## (MapInfo.gust_wind), or 0 while it is still (or for an updraft).
func blowing() -> float:
	if chasm < 0 or map_info == null:
		return 0.0
	return float(signi(map_info.gust_wind()))


## How fast a crosswind carries the wizard (px/s) while it blows: carry_for its level's wind (a
## vane's at least).
func carry() -> float:
	return carry_for(maxi(1, absi(map_info.level_wind()) if map_info != null else 1))


## How fast a gust of `strength` vanes carries the wizard (px/s): CARRY, however many vanes (they
## make it blow longer, gust_for); none for a still wind.
static func carry_for(strength: int) -> float:
	return CARRY if strength > 0 else 0.0


## How long (seconds) a gust of `strength` vanes blows: GUST for one, GUST_STEP more for each vane
## past the first, at most GUST_MAX.
static func gust_for(strength: int) -> float:
	return minf(GUST + GUST_STEP * float(maxi(strength, 1) - 1), GUST_MAX)


## The air it moves (world space). Things that wake and print by what is in view go by all of
## it, not its middle: a tall shaft's top can be on screen with its middle far below.
func extent() -> Rect2:
	return rect


func active() -> bool:
	return up > 0 or blowing() != 0.0


## The push at a point inside it: (0, -LIFT_SPEED) for an updraft, (±carry, 0) for a crosswind.
func push() -> Vector2:
	if up > 0:
		return Vector2(0.0, -LIFT_SPEED)
	return Vector2(blowing() * carry(), 0.0)


## The sum of the wind blowing at `at`.
static func push_at(tree: SceneTree, at: Vector2) -> Vector2:
	var total: Vector2 = Vector2.ZERO
	for node: Node in tree.get_nodes_in_group(&"wind"):
		var w: Wind = node as Wind
		if w != null and w.rect.has_point(at) and w.active():
			total += w.push()
	return total


func _ready() -> void:
	add_to_group(&"wind")
