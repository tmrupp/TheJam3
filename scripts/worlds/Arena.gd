class_name Arena
extends SideWorld
## A boss's arena (Bosses.in_arena): a side world behind a door in its gate level, a plain hall,
## WIDTH cells across and HEIGHT high, with a flat floor, the way back (and a lantern) at the left
## and the boss on the right. It is a dead end: its way back, free like its door, returns to the
## gate level, whose way on opens once the boss is slain. A boss with an arena of its own lays it
## out instead: the spider's keep (SpiderKeep), a tall hall of broken floors printed as the crags'
## castle. The bosses whose arenas are not built yet share this hall, and the stand-in (Boss)
## fights in it.

const WIDTH: int = 40
const HEIGHT: int = 16
## The hall's air runs from row CEILING down to row FLOOR - 1, the floor below.
const CEILING: int = 3
const FLOOR: int = 12
## Where the way back, its lantern and the boss stand along the floor.
const BACK_X: int = 3
const LANTERN_X: int = 6
const BOSS_X: int = 28


func _init() -> void:
	name = "arena"
	way = Vector2.RIGHT
	plants = false
	price_factor = 0.0
	cells = Vector2i(WIDTH, HEIGHT)


## Gate levels whose boss fights in an arena deal its door.
func deals(at: Vector2i) -> bool:
	return not Worlds.is_side(at) and Bosses.in_arena(Bosses.gate_at(at.y))


## The boss whose arena it is.
func boss() -> StringName:
	return Bosses.gate_at(origin().y)


## Whether it is the spider's keep (SpiderKeep) rather than the plain hall.
func keep() -> bool:
	return boss() == &"spider"


## The keep is its own size.
func setup(at: Vector2i) -> NextWorldDef:
	super(at)
	if keep():
		size = SpiderKeep.SIZE
	return self


func title() -> String:
	return "world %d · %s" % [coord.x, "the keep" if keep() else String(boss())]


## The keep is printed as the crags' castle, dressed as theirs.
func realm() -> StringName:
	return &"crags" if keep() else print_realm


func decor() -> StringName:
	return &"crags" if keep() else super()


func grows() -> bool:
	return keep() or plants


## An empty hall, in the generator's colours (the collapse is laid over by populate anyway).
func fallback() -> Array:
	var out: Array = []
	for x: int in range(size.x):
		var column: Array = []
		for y: int in range(size.y):
			column.append(Color.WHITE if _open(Vector2i(x, y)) else Color.BLACK)
		out.append(column)
	return out


## The hall, whatever the collapse made: its air open, the rest rock; the way back and a lantern at
## the left, the boss on the right. The spider's keep instead (SpiderKeep.build).
func populate(w: LevelGen) -> void:
	if keep():
		SpiderKeep.build(w, boss())
		return
	for x: int in range(WIDTH):
		for y: int in range(HEIGHT):
			var v: Vector2i = Vector2i(x, y)
			if _open(v) and w.get_cell(v).type != LevelGen.Type.EMPTY:
				w._to_open(v)
			elif not _open(v) and w.get_cell(v).type != LevelGen.Type.GROUND:
				w._to_rock(v)
	var back: Vector2i = Vector2i(BACK_X, FLOOR - 1)
	var lantern: Vector2i = Vector2i(LANTERN_X, FLOOR - 1)
	w.put(back, LevelGen.Type.EXIT, MapInfo.Exit.BACK)
	w.put(lantern, LevelGen.Type.CHECKPOINT)
	w.exits = {MapInfo.Exit.BACK: back}
	w.exit_lanterns = {MapInfo.Exit.BACK: lantern}
	w.put(Vector2i(BOSS_X, FLOOR - 1), LevelGen.Type.BOSS, boss())


func _open(v: Vector2i) -> bool:
	return v.x >= 1 and v.x < WIDTH - 1 and v.y >= CEILING and v.y < FLOOR
