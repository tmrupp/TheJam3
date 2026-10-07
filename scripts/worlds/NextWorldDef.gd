class_name NextWorldDef
extends RefCounted
## What a place in a run is, and how it behaves: how its terrain is collapsed and dressed, where
## each of its exits leads and what it costs, and how it is printed and mapped. This base class is
## the ordinary cave level at (seed, depth). Other kinds of world extend it (SideWorld, listed in
## Worlds.KINDS), so the rest of the game asks the place's definition rather than knowing which
## kind it is in. Get one with MapInfo.def_for (or MapInfo.here for the place being played).

## Where it is (see Worlds for where side worlds sit).
var coord: Vector2i
var gen_seed: int = 0
## The WFC sample its terrain is collapsed from.
var region: String
## How deep it counts as (enemy health, the price of its deeper exit).
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
## Whether a secret room in this level holds a skeleton key (see MapInfo.skeleton_at).
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

## Archetypes take bands of BAND levels in turn as you go deeper, in this order: the garden (the
## caves you start in) from the surface, then the cemetery, then the sky, then the garden again, and
## so on. Each is a script extending Archetype; a new one joins the turn by being listed here.
const ARCHETYPES: Array[Script] = [
	preload("res://scripts/worlds/archetypes/GardenArchetype.gd"),
	preload("res://scripts/worlds/archetypes/CemeteryArchetype.gd"),
	preload("res://scripts/worlds/archetypes/SkyArchetype.gd"),
]
const BAND: int = 6


## Fill it in for the place at `at`, and return it.
func setup(at: Vector2i) -> NextWorldDef:
	coord = at
	debug = MapInfo.debug
	depth = at.y
	gen_seed = MapInfo.level_seed(at.x, at.y)
	arch = archetype_for(depth)
	archetype = arch.name
	region = arch.sample
	symmetry = arch.symmetry
	size = Vector2i((Vector2(MapInfo.level_size(depth)) * arch.scale).round())
	for k: int in range(Worlds.KINDS.size()):
		if Worlds.proto(k).deals(at):
			doors.append(k)
	arrival_from = Worlds.arriving_at(at)
	relic = Relics.at(at)
	skeleton = MapInfo.skeleton_at(at)
	return self


## The names of the archetypes, in the order their bands come.
static func archetype_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: Script in ARCHETYPES:
		out.append((kind.new() as Archetype).name)
	return out


## The first depth of the first band of the archetype named `kind`, or -1.
static func first_depth(kind: StringName) -> int:
	var i: int = archetype_names().find(kind)
	return i * BAND if i >= 0 else -1


## The archetype of levels `depth` deep (a new one each time: it is small).
static func archetype_for(depth: int) -> Archetype:
	@warning_ignore("integer_division")
	return ARCHETYPES[(maxi(depth, 0) / BAND) % ARCHETYPES.size()].new()


## The name of the archetype of levels `depth` deep.
static func archetype_at(depth: int) -> StringName:
	return archetype_for(depth).name


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
	var above: Vector2i = Vector2i(coord.x, maxi(0, coord.y - 1))
	match exit:
		MapInfo.Exit.DEEPER:
			return _to(coord + Vector2i(0, 1), Vector2.DOWN, MapInfo.Exit.BACK)
		MapInfo.Exit.BACK:
			if arrival_from != null:
				# Back into the side world that leads here, at its way on.
				var from: Vector2i = arrival_from
				return _to(from, -Worlds.proto(Worlds.kind_at(from)).way, MapInfo.Exit.DEEPER)
			return _to(above, Vector2.UP, MapInfo.Exit.DEEPER)
		MapInfo.Exit.RETURN:
			return _to(above, Vector2.UP, MapInfo.Exit.DEEPER)
		MapInfo.Exit.LEFT:
			return _to(coord + Vector2i(-1, 0), Vector2.LEFT, MapInfo.Exit.RIGHT)
		MapInfo.Exit.RIGHT:
			return _to(coord + Vector2i(1, 0), Vector2.RIGHT, MapInfo.Exit.LEFT)
	return {}


func _to(at: Vector2i, way: Vector2, arrive: int) -> Dictionary:
	return {"to": at, "way": way, "arrive": arrive}


## The places its exits lead to (the generator lays them out ahead of time).
func neighbours() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for exit: int in ways():
		var to: Variant = lead(exit).get("to")
		if to != null and to != coord and not out.has(to) and Worlds.valid(to):
			out.append(to)
	return out


## Stars still owed to leave by `exit`, given the place's record. The deeper exit costs the
## depth's price once; a side door its world's entry price, once.
func price(exit: int, rec: LevelRecord) -> int:
	var kind: int = Worlds.door_kind(exit)
	if kind >= 0:
		return 0 if rec.doors_paid.has(exit) else Worlds.proto(kind).entry_price(depth)
	if exit == MapInfo.Exit.DEEPER and not rec.deeper_paid:
		return MapInfo.deeper_price(depth)
	return 0


## Record `exit` as paid for.
func pay(exit: int, rec: LevelRecord) -> void:
	if Worlds.door_kind(exit) >= 0:
		rec.doors_paid[exit] = true
	else:
		rec.deeper_paid = true


# ------------------------------------------------------------------ how it looks

## The print realm (RisoPrint.REALMS) it is printed in, or &"" for the player's own.
func realm() -> StringName:
	return arch.realm() if arch != null else &""


## Whether plants and the other decor grow in it.
func grows() -> bool:
	return true


## Its name on screen and when sharing it.
func title() -> String:
	return "world %d · depth %d" % [coord.x, coord.y]


## The way an exit's chevron points.
func exit_dir(exit: int) -> Vector2:
	match exit:
		MapInfo.Exit.BACK, MapInfo.Exit.RETURN:
			return Vector2.UP
		MapInfo.Exit.LEFT:
			return Vector2.LEFT
		MapInfo.Exit.RIGHT:
			return Vector2.RIGHT
	return Vector2.DOWN


## Whether an exit is printed as a grand door (a side world's door, or a side world's way on).
func exit_grand(exit: int) -> bool:
	return Worlds.door_kind(exit) >= 0


## Where it sits on the worlds map, in tiles.
func grid_at() -> Vector2:
	return Vector2(coord)
