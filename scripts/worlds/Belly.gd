class_name Belly
extends SideWorld
## The whale's belly (Whale, docs/REGIONS_PLAN.md §6): a side world entered only through the
## trapped whale's open mouth (MapInfo.enter_belly), never by a door. A dark hall WIDTH cells across
## and HEIGHT high, laid out over whatever the collapse made: its ribs hang from its roof every
## RIB_EVERY cells, RIB_DROP rows deep, with a ridge under each; pools of its acid (thorns, pink)
## sink into its floor between some of them; the way back (its mouth, out to the whale's level) and
## a lantern stand at the left, and its heart (WhaleHeart, as the boss's own prefab, Bosses.SCENES)
## at the far right. Its way back leads out to the whale's level. Printed in a realm of its own
## (RisoPrint.REALMS.belly: dull flesh under a dark maroon), breathing behind (RisoBackground).
## Nothing here draws from the world RNG: it is the same every visit.

const WIDTH: int = 40
const HEIGHT: int = 15
## The hall's air runs from row CEILING down to row FLOOR - 1, the floor below.
const CEILING: int = 3
const FLOOR: int = 12
## Its ribs: one every RIB_EVERY cells from RIB_FROM, hanging RIB_DROP rows from its roof, a cell
## wide, with a ridge a row high under each.
const RIB_EVERY: int = 6
const RIB_FROM: int = 8
const RIB_DROP: int = 4
## Pools of acid between every other pair of ribs, POOL cells wide.
const POOL: int = 2
## Where the way back, its lantern and the heart stand along the floor.
const BACK_X: int = 2
const LANTERN_X: int = 4
const HEART_X: int = WIDTH - 4


func _init() -> void:
	name = "the whale's belly"
	way = Vector2.RIGHT
	plants = false
	price_factor = 0.0
	cells = Vector2i(WIDTH, HEIGHT)
	print_realm = &"belly"


func title() -> String:
	return "world %d · %s" % [coord.x, name]


## An empty hall, in the generator's colours (the collapse is laid over by populate anyway).
func fallback() -> Array:
	var out: Array = []
	for x: int in range(size.x):
		var column: Array = []
		for y: int in range(size.y):
			column.append(Color.WHITE if _air(Vector2i(x, y)) else Color.BLACK)
		out.append(column)
	return out


## The hall, its ribs and acid, the way back and a lantern at the left, its heart at the right.
func populate(w: LevelGen) -> void:
	for x: int in range(WIDTH):
		for y: int in range(HEIGHT):
			var v: Vector2i = Vector2i(x, y)
			if _air(v) and w.get_cell(v).type != LevelGen.Type.EMPTY:
				w._to_open(v)
			elif not _air(v) and w.get_cell(v).type != LevelGen.Type.GROUND:
				w._to_rock(v)
	var pools: Array[Vector2i] = []
	var k: int = 0
	for x: int in range(RIB_FROM, HEART_X - 2, RIB_EVERY):
		for y: int in range(CEILING, CEILING + RIB_DROP):
			w._to_rock(Vector2i(x, y))
		w._to_rock(Vector2i(x, FLOOR - 1))
		if k % 2 == 1:
			for p: int in range(POOL):
				pools.append(Vector2i(x + 2 + p, FLOOR - 1))
		k += 1
	for v: Vector2i in pools:
		w.put(v, LevelGen.Type.SPIKES)
	var back: Vector2i = Vector2i(BACK_X, FLOOR - 1)
	var lantern: Vector2i = Vector2i(LANTERN_X, FLOOR - 1)
	w.put(back, LevelGen.Type.EXIT, MapInfo.Exit.BACK)
	w.put(lantern, LevelGen.Type.CHECKPOINT)
	w.exits = {MapInfo.Exit.BACK: back}
	w.exit_lanterns = {MapInfo.Exit.BACK: lantern}
	w.put(Vector2i(HEART_X, FLOOR - 2), LevelGen.Type.BOSS, &"whale")


## Its exits: the way back alone.
func ways() -> Array[int]:
	var out: Array[int] = [MapInfo.Exit.BACK]
	return out


func _air(v: Vector2i) -> bool:
	return v.x >= 1 and v.x < WIDTH - 1 and v.y >= CEILING and v.y < FLOOR
