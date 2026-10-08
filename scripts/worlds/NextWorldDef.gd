class_name NextWorldDef
extends RefCounted
## What a place in a run is, and how it behaves: how its terrain is collapsed and dressed, where
## each of its exits leads and what it costs, and how it is printed and mapped. This base class is
## the ordinary level at (seed, row): row 0 is where a run starts, rows below it (positive) lead
## down and rows above it (negative) lead up (docs/REGIONS_PLAN.md). Other kinds of world extend it
## (SideWorld, listed in Worlds.KINDS), so the rest of the game asks the place's definition rather
## than knowing which kind it is in. Get one with Rules.def_for (or MapInfo.here for the place being
## played).
##
## Its way on (MapInfo.Exit.DEEPER) leads away from the start and its way back (BACK) toward it:
## down and up below the start, up and down above it. The start's own way back leads up, so a run
## can set off either way.

## Where it is (see Worlds for where side worlds sit).
var coord: Vector2i
var gen_seed: int = 0
## The WFC sample its terrain is collapsed from.
var region: String
## How far from the start it counts as, in rows, whichever way (enemy health, prices, relics...):
## the distance |row| for a level.
var depth: int = 0
var debug: bool = false
## Cells across and down.
var size: Vector2i = Vector2i(64, 64)
## The kinds of side world (indices into Worlds.KINDS) this level has a door into.
var doors: Array[int] = []
## The side world whose way on leads into this level, or null. Then this level's way back leads
## into that world, and the level gets an ordinary way up as well (Exit.RETURN).
var arrival_from: Variant = null
## The move the relic in this level holds (see Relics), or &"" for none.
var relic: StringName = &""
## Whether a secret room in this level holds a skeleton key (see Rules.skeleton_at).
var skeleton: bool = false
## What kind of level it is (ARCHETYPES), by its depth: its terrain, look and what lives there.
## &"" for a side world.
var archetype: StringName = &""
## What that archetype brings (see Archetype), or null for a side world.
var arch: Archetype = null
## The collapse's symmetry: how many of the sample's patterns' turns and flips it may use (see
## gdextension/src/overlapping_wfc.hpp). 1 uses them as drawn, so up stays up (the extension's
## first flip is upside down).
var symmetry: int = 5

## The bands of rows each archetype holds (docs/REGIONS_PLAN.md §2). The garden is the hub: it
## spans the rows within GARDEN_ROWS of the start, both ways. Down from it, DOWN's archetypes follow
## one another, BAND rows each; up from it, UP's do. The outermost band of each way goes on for
## ever past its end. Each is a script extending Archetype; a new one joins by being listed here.
const GARDEN: Script = preload("res://scripts/worlds/archetypes/GardenArchetype.gd")
const DOWN: Array[Script] = [
	preload("res://scripts/worlds/archetypes/CemeteryArchetype.gd"),
	preload("res://scripts/worlds/archetypes/CatacombsArchetype.gd"),
]
const UP: Array[Script] = [
	preload("res://scripts/worlds/archetypes/CragsArchetype.gd"),
	preload("res://scripts/worlds/archetypes/SkyArchetype.gd"),
]
## Every archetype, the garden first, then down's, then up's.
const ARCHETYPES: Array[Script] = [GARDEN, DOWN[0], DOWN[1], UP[0], UP[1]]
const GARDEN_ROWS: int = 3
const BAND: int = 6


## Fill it in for the place at `at`, and return it.
func setup(at: Vector2i) -> NextWorldDef:
	coord = at
	debug = MapInfo.debug
	depth = absi(at.y)
	gen_seed = Rules.level_seed(at.x, at.y)
	arch = archetype_for(at.y)
	archetype = arch.name
	region = arch.sample
	symmetry = arch.symmetry
	size = Vector2i((Vector2(Rules.level_size(depth)) * arch.scale).round())
	for k: int in range(Worlds.KINDS.size()):
		if Worlds.proto(k).deals(at):
			doors.append(k)
	arrival_from = Worlds.arriving_at(at)
	relic = Relics.at(at)
	skeleton = Rules.skeleton_at(at)
	return self


## The names of the archetypes, in the order their bands come.
static func archetype_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: Script in ARCHETYPES:
		out.append((kind.new() as Archetype).name)
	return out


## The row of the band of the archetype named `kind` nearest the start (the garden's is the start
## itself), or -1 for none (no band is there).
static func first_depth(kind: StringName) -> int:
	return band_row(kind, 0)


## Row `k` of the band of the archetype named `kind`, counting from its row nearest the start (0)
## away from it (the garden's, down from the start), or -1 for an archetype with no band.
static func band_row(kind: StringName, k: int) -> int:
	if (GARDEN.new() as Archetype).name == kind:
		return k
	for way: int in [1, -1]:
		var bands: Array[Script] = DOWN if way > 0 else UP
		for i: int in range(bands.size()):
			if (bands[i].new() as Archetype).name == kind:
				return way * (GARDEN_ROWS + 1 + i * BAND + k)
	return -1


## Which way, along the rows, the way on (Exit.DEEPER) leads from row `row`: away from the start
## (+1 down from the start and below it, -1 up above it). The way back leads the other way.
static func away(row: int) -> int:
	return -1 if row < 0 else 1


## The archetype of levels on row `row` (a new one each time: it is small). Side worlds have none
## of their own, but ask with their origin's row.
static func archetype_for(row: int) -> Archetype:
	var d: int = absi(row)
	if d <= GARDEN_ROWS:
		return GARDEN.new()
	var bands: Array[Script] = DOWN if row > 0 else UP
	@warning_ignore("integer_division")
	return bands[mini((d - GARDEN_ROWS - 1) / BAND, bands.size() - 1)].new()


## The name of the archetype of levels on row `row`.
static func archetype_at(row: int) -> StringName:
	return archetype_for(row).name


## Whether the place's chasms are its gates (bridged by bells in a cemetery, blown over by a vane's
## wind in the sky; see Chasms).
func chasmed() -> bool:
	return arch != null and arch.chasmed


## Whether the place lies open to the sky: no rock border, a drop below (see Archetype.open).
func open() -> bool:
	return arch != null and arch.open


# ------------------------------------------------------------------ making it

## Dress the collapsed terrain held in `w`: exits, lanterns, keys, doors, enemies, stars.
func populate(w: LevelGen) -> void:
	w.populate_level(self)


## Terrain (in the generator's colours) to use if the collapse never settles, or [] for none.
func fallback() -> Array:
	return []


# ------------------------------------------------------------------ its exits

## The exits it can have, in order.
func ways() -> Array[int]:
	var out: Array[int] = [MapInfo.Exit.DEEPER, MapInfo.Exit.BACK, MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT]
	if arrival_from != null:
		out.append(MapInfo.Exit.RETURN)
	for k: int in doors:
		out.append(Worlds.door(k))
	return out


## Where leaving by `exit` leads: {"to": the place, "way": the way the transition sweeps,
## "arrive": the exit arrived at there}, or {} when it leads nowhere.
func lead(exit: int) -> Dictionary:
	var kind: int = Worlds.door_kind(exit)
	if kind >= 0:
		return _to(Worlds.side_at(kind, coord), Worlds.proto(kind).way, MapInfo.Exit.BACK)
	var on: int = away(coord.y)
	match exit:
		MapInfo.Exit.DEEPER:
			return _to(coord + Vector2i(0, on), Vector2(0, on), MapInfo.Exit.BACK)
		MapInfo.Exit.BACK:
			if arrival_from != null:
				# Back into the side world that leads here, at its way on.
				var from: Vector2i = arrival_from
				return _to(from, -Worlds.proto(Worlds.kind_at(from)).way, MapInfo.Exit.DEEPER)
			return _homeward()
		MapInfo.Exit.RETURN:
			return _homeward()
		MapInfo.Exit.LEFT:
			return _to(coord + Vector2i(-1, 0), Vector2.LEFT, MapInfo.Exit.RIGHT)
		MapInfo.Exit.RIGHT:
			return _to(coord + Vector2i(1, 0), Vector2.RIGHT, MapInfo.Exit.LEFT)
	return {}


func _to(at: Vector2i, way: Vector2, arrive: int) -> Dictionary:
	return {"to": at, "way": way, "arrive": arrive}


## The ordinary way back: one row toward the start, arriving at that level's way on; or, from the
## start, one row up, arriving at that level's way back (toward the start); and, coming down into
## the start from above, arriving at its way back (its way up).
func _homeward() -> Dictionary:
	var step: int = -away(coord.y)
	var to: Vector2i = coord + Vector2i(0, step)
	var arrive: int = MapInfo.Exit.BACK if coord.y == 0 or to.y == 0 and coord.y < 0 else MapInfo.Exit.DEEPER
	return _to(to, Vector2(0, step), arrive)


## The places its exits lead to (the generator lays them out ahead of time).
func neighbours() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for exit: int in ways():
		var to: Variant = lead(exit).get("to")
		if to != null and to != coord and not out.has(to) and Worlds.valid(to):
			out.append(to)
	return out


## Stars still owed to leave by `exit`, given the place's record. The way on costs the depth's
## price once (and the start's way up costs the same as its way down); a side door its world's
## entry price, once.
func price(exit: int, rec: LevelRecord) -> int:
	var kind: int = Worlds.door_kind(exit)
	if kind >= 0:
		return 0 if rec.doors_paid.has(exit) else Worlds.proto(kind).entry_price(depth)
	if exit == MapInfo.Exit.DEEPER and not rec.deeper_paid:
		return Rules.deeper_price(depth)
	if _way_up_from_start(exit) and not rec.up_paid:
		return Rules.deeper_price(depth)
	return 0


## Record `exit` as paid for.
func pay(exit: int, rec: LevelRecord) -> void:
	if Worlds.door_kind(exit) >= 0:
		rec.doors_paid[exit] = true
	elif _way_up_from_start(exit):
		rec.up_paid = true
	else:
		rec.deeper_paid = true


## Whether `exit` is the start's way up (its way back, unless a side world leads into it).
func _way_up_from_start(exit: int) -> bool:
	return coord.y == 0 and exit == MapInfo.Exit.BACK and arrival_from == null


# ------------------------------------------------------------------ how it looks

## The print realm (RisoPrint.REALMS) it is printed in, or &"" for the player's own.
func realm() -> StringName:
	return arch.realm() if arch != null else &""


## The decor plan (RisoDecor.PLANS) it wears: its archetype's, or the garden's for a side world.
func decor() -> StringName:
	return arch.decor if arch != null else &"garden"


## Whether plants and the other decor grow in it.
func grows() -> bool:
	return true


## Its name on screen and when sharing it: its depth below the start, or its height above it.
func title() -> String:
	return "world %d · %s %d" % [coord.x, "height" if coord.y < 0 else "depth", absi(coord.y)]


## The way an exit's chevron points: the way on away from the start, the way back toward it (the
## start's way back, up).
func exit_dir(exit: int) -> Vector2:
	match exit:
		MapInfo.Exit.BACK, MapInfo.Exit.RETURN:
			return Vector2(0, -away(coord.y))
		MapInfo.Exit.LEFT:
			return Vector2.LEFT
		MapInfo.Exit.RIGHT:
			return Vector2.RIGHT
	return Vector2(0, away(coord.y))


## Whether an exit is printed as a grand door (a side world's door, or a side world's way on).
func exit_grand(exit: int) -> bool:
	return Worlds.door_kind(exit) >= 0


## Where it sits on the worlds map, in tiles.
func grid_at() -> Vector2:
	return Vector2(coord)
