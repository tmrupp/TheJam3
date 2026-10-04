class_name Worlds
extends RefCounted
## Every kind of place a run can be in. The ordinary levels sit on a grid at (seed, depth >= 0)
## and are defined by NextWorldDef itself. Every other kind is a side world (SideWorld), reached
## through a door that some levels deal. The kinds are listed in KINDS, and a kind's index there is
## its number. To add one: extend SideWorld (see Hyperspace), then list it here.
##
## Side worlds hang off the grid at negative depths: kind k entered from level (seed, depth) is at
## (seed, -(k * STRIDE + depth) - 1), so each has its own record, save entry and map tile, and
## never meets a level. A door into kind k is exit number DOOR_BASE + k (see door).

const KINDS: Array[Script] = [
	preload("res://scripts/worlds/Hyperspace.gd"),
]
const STRIDE: int = 100000
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
	return at.y < 0


## The kind of side world at `at`, or -1 for a level.
static func kind_at(at: Vector2i) -> int:
	@warning_ignore("integer_division")
	return -1 if at.y >= 0 else (-at.y - 1) / STRIDE


## The level the side world at `at` is entered from.
static func origin_of(at: Vector2i) -> Vector2i:
	return Vector2i(at.x, (-at.y - 1) % STRIDE)


## The side world of kind `kind` entered from level `from`.
static func side_at(kind: int, from: Vector2i) -> Vector2i:
	return Vector2i(from.x, -(kind * STRIDE + from.y) - 1)


## Whether `at` is a place at all (a level, or a side world of a kind that exists).
static func valid(at: Vector2i) -> bool:
	return at.y >= 0 or kind_at(at) < KINDS.size()


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
