class_name SideWorld
extends NextWorldDef
## A world off the grid of levels (see Worlds for where it sits), entered through a side door
## that some levels deal (`deals`), paid for once (`entry_price`). You arrive at its way back
## (Exit.BACK), which returns you out of that door. Its way on (Exit.DEEPER) leads to its
## `destination`, arriving at that level's way back, which from then on leads in here again, at
## the way on (see `arriving`). One whose destination is the level it was entered from is a dead
## end: its way on returns there too.
##
## To add a kind of world: extend this, set its look and feel in _init (the vars below), override
## `deals` and `populate` (and `destination_for` with `arriving`, `depth_for`, `fallback` as
## needed), then list it in Worlds.KINDS. Hyperspace is the full example.

## Its number: its index in Worlds.KINDS.
var kind: int = -1
## What it is called on screen ("world 3 · <name>") and on the maps.
var name: String = "elsewhere"
## Which way you cross it: the transition sweeps this way going in, and back the other way.
var way: Vector2 = Vector2.RIGHT
## The print realm it is printed in (RisoPrint.REALMS), or &"" for the player's own.
var print_realm: StringName = &""
## Whether decor grows in it.
var plants: bool = false
## Its door costs this many times the deeper exit's price, in the level the door is in.
var price_factor: float = 1.0
## Its cells across and down, and its WFC sample ("" for the levels' own).
var cells: Vector2i = Vector2i(64, 16)
var sample: String = ""


# ------------------------------------------------------------------ the kind (asked of Worlds.proto)

## Whether level `at` deals a door into this kind of world.
func deals(_at: Vector2i) -> bool:
	return false


## Stars for its door in a level `level_depth` deep.
func entry_price(level_depth: int) -> int:
	return roundi(Rules.deeper_price(level_depth) * price_factor)


## Where the way on leads, for the world entered from level `from`.
func destination_for(from: Vector2i) -> Vector2i:
	return from


## The level whose world of this kind leads into level `at` (by its way on), or null.
func arriving(_at: Vector2i) -> Variant:
	return null


## How deep the world entered from level `from` counts as.
func depth_for(from: Vector2i) -> int:
	return from.y


# ------------------------------------------------------------------ one world of the kind

func setup(at: Vector2i) -> NextWorldDef:
	coord = at
	debug = MapInfo.debug
	kind = Worlds.kind_at(at)
	depth = depth_for(origin())
	gen_seed = Rules.level_seed(at.x, at.y)
	region = sample if sample != "" else GardenArchetype.SAMPLE
	size = cells
	return self


## The level it was entered from, and the one its way on leads to.
func origin() -> Vector2i:
	return Worlds.origin_of(coord)


func destination() -> Vector2i:
	return destination_for(origin())


func dead_end() -> bool:
	return destination() == origin()


func ways() -> Array[int]:
	var out: Array[int] = [MapInfo.Exit.BACK, MapInfo.Exit.DEEPER]
	return out


func lead(exit: int) -> Dictionary:
	match exit:
		MapInfo.Exit.BACK:
			return _to(origin(), -way, Worlds.door(kind))
		MapInfo.Exit.DEEPER:
			if dead_end():
				return _to(origin(), -way, Worlds.door(kind))
			return _to(destination(), exit_dir(exit), MapInfo.Exit.BACK)
	return {}


## Its exits are free: the door was paid for on the way in.
func price(_exit: int, _rec: LevelRecord) -> int:
	return 0


func realm() -> StringName:
	return print_realm


func grows() -> bool:
	return plants


func title() -> String:
	return "world %d · %s" % [coord.x, name]


func exit_dir(exit: int) -> Vector2:
	if exit == MapInfo.Exit.DEEPER and destination().y != origin().y:
		return Vector2.DOWN if destination().y > origin().y else Vector2.UP
	return -way if exit == MapInfo.Exit.BACK else way


func exit_grand(exit: int) -> bool:
	return exit == MapInfo.Exit.DEEPER and not dead_end()


## Halfway between the level it is entered from and the one it leads to (just under the first,
## for a dead end).
func grid_at() -> Vector2:
	if dead_end():
		return Vector2(origin()) + Vector2(0, 0.5)
	return (Vector2(origin()) + Vector2(destination())) * 0.5


## How far across it (0 at the way back, 1 at the way on) cell `v` is.
func progress(v: Vector2i) -> float:
	var span: Vector2 = Vector2(maxi(1, size.x - 1), maxi(1, size.y - 1))
	var along: float = (Vector2(v) / span).dot(way.abs())
	return 1.0 - along if way.x + way.y < 0.0 else along
