class_name Worlds
extends RefCounted
## Every kind of place a run can be in. The ordinary levels sit on a grid at (seed, row): row 0 is
## where a run starts, rows below it (positive) lead down, rows above it (negative) lead up (see
## NextWorldDef), anywhere above -SIDE_BASE. They are defined by NextWorldDef itself. Every other
## kind is a side world (SideWorld), reached through a door that some levels deal. The kinds are
## listed in KINDS, and a kind's index there is its number. To add one: extend SideWorld (see
## Hyperspace), then list it here.
##
## Side worlds hang off the grid far below every level's row: kind k entered from level (seed, row)
## is at (seed, -(SIDE_BASE + k * STRIDE + row + STRIDE / 2)), so each has its own record, save entry
## and map tile, and never meets a level, whichever branch it is entered from. A door into kind k is
## exit number DOOR_BASE + k (see door).

const KINDS: Array[Script] = [
	preload("res://scripts/worlds/Hyperspace.gd"),
]
## Each kind's span of rows; a side world's origin row lies within half of it either way of 0.
const STRIDE: int = 100000
## Rows at or beyond this far above the start belong to side worlds.
const SIDE_BASE: int = 1000000
## Exit numbers from here up are side doors (below are MapInfo.Exit's).
const DOOR_BASE: int = 16

## An instance of kind `kind`, to ask questions about the kind as a whole (see SideWorld). Made
## fresh each time (they are small), so nothing outlives a run or is shared between threads.
static func proto(kind: int) -> SideWorld:
	var p: SideWorld = KINDS[kind].new()
	p.kind = kind
	return p


## The definition of the place at `at`.
static func def_for(at: Vector2i) -> NextWorldDef:
	var def: NextWorldDef = KINDS[kind_at(at)].new() if is_side(at) else NextWorldDef.new()
	return def.setup(at)


## Whether `at` is a side world rather than a level.
static func is_side(at: Vector2i) -> bool:
	return at.y <= -SIDE_BASE


## The kind of side world at `at`, or -1 for a level.
static func kind_at(at: Vector2i) -> int:
	@warning_ignore("integer_division")
	return -1 if not is_side(at) else (-at.y - SIDE_BASE) / STRIDE


## The level the side world at `at` is entered from.
static func origin_of(at: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(at.x, (-at.y - SIDE_BASE) % STRIDE - STRIDE / 2)


## The side world of kind `kind` entered from level `from`.
static func side_at(kind: int, from: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(from.x, -(SIDE_BASE + kind * STRIDE + from.y + STRIDE / 2))


## Where version-2 saves kept the side world at `old` (kind k from (seed, depth) at
## (seed, -(k * STRIDE + depth) - 1)), now: for RunState's migration. Levels keep their place.
static func from_v2(old: Vector2i) -> Vector2i:
	if old.y >= 0:
		return old
	@warning_ignore("integer_division")
	return side_at((-old.y - 1) / STRIDE, Vector2i(old.x, (-old.y - 1) % STRIDE))


## Whether `at` is a place at all (a level, or a side world of a kind that exists).
static func valid(at: Vector2i) -> bool:
	return not is_side(at) or kind_at(at) < KINDS.size()


## The exit number of a door into kind `kind`, and the kind a door exit leads into (-1 if none).
static func door(kind: int) -> int:
	return DOOR_BASE + kind


static func door_kind(exit: int) -> int:
	return exit - DOOR_BASE if exit >= DOOR_BASE and exit - DOOR_BASE < KINDS.size() else -1


## The number of the kind `script` defines (-1 if it is not listed).
static func kind_of(script: Script) -> int:
	return KINDS.find(script)


## The side world whose way on leads into level `at`, or null.
static func arriving_at(at: Vector2i) -> Variant:
	for k: int in range(KINDS.size()):
		var from: Variant = proto(k).arriving(at)
		if from != null:
			return side_at(k, from)
	return null
