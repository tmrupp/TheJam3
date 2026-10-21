class_name Belly
extends SideWorld
## The whale's belly (Whale, docs/REGIONS_PLAN.md §6): a side world entered only through the
## trapped whale's mouth (MapInfo.enter_belly), never by a door. It is laid out by hand (MAP): the
## wizard arrives at its mouth, top left, by the way back (out to the whale's level) and a lantern;
## its gullet, ringed with muscle, steps down to the right into its stomach, a great dome over a
## bowl. Bone ledges cross the dome from the gullet's lip down to the way out at its right, and its
## bowl holds a pool of acid (Acid) that floods and drains. Drained, it lies in three pits along the
## stomach's floor, each three cells wide, and in each floats a piece of wreckage it has swallowed
## (Wreck), two cells wide, its deck level with the floor, leaving a hole of open acid beside it;
## flooded, the wreckage rides up on it. Steps up its
## right side lead to the way out, a short passage to the chamber where its heart (WhaleHeart, as
## the boss's own prefab, Bosses.SCENES) hangs. Printed in a realm of its own (RisoPrint.REALMS.belly:
## dull flesh under a dark maroon), breathing behind (RisoBackground), dressed with bones, strands
## and veins (RisoDecor.plan_belly). Nothing here draws from the world RNG: it is the same every
## visit.

## The belly, row by row: rock (#), open air (.), a bone ledge (=, a one-way ledge), the way back
## (B), its lantern (L), the heart (H), a piece of wreckage two cells wide (w, the kinds in WRECKS
## from left to right), and where the acid is anchored (A; its pool is ACID_BASIN).
const MAP: Array[String] = [
	"########################################################################",
	"########################################################################",
	"########################################################################",
	"#..........#############################################################",
	"#..........#############################################################",
	"#...........############################################################",
	"#..............#########################################################",
	"#...............#.######################################################",
	"#.B..L..............####################################################",
	"#############.......#..############.........############################",
	"###############.........#######.................########################",
	"##################........###.....................######################",
	"####################......##.......................##########.......####",
	"#######################..............................#######.........###",
	"#########################.............................#####...........##",
	"#########################..==.........................####.............#",
	"########################.......==......................###.............#",
	"########################...........==..................###.............#",
	"#######################................==...............##.............#",
	"#######################....................==..........................#",
	"#######################........................==.....................##",
	"#######################............................==.............H..###",
	"#######################..............................==.............####",
	"########################................................################",
	"########################...............................#################",
	"#########################.............................##################",
	"##########################...........................###################",
	"###########################.........................####################",
	"#############################.....................######################",
	"###############################......A..........########################",
	"##################################w..#w..#w..###########################",
	"########################################################################",
	"########################################################################",
	"########################################################################",
]
## The acid's pool: the cells it may fill, and how high it lies drained and flooded, as rows (from
## the top of the map; a fraction is that share of a row down from its top). Drained, it lies just
## under the floor, so the wreckage floating in its pits is level with the floor.
const ACID_BASIN: Rect2i = Rect2i(22, 22, 35, 9)
const ACID_LOW: float = 30.31
const ACID_HIGH: float = 24.15
## The wreckage in its pits, left to right (Wreck.KINDS).
const WRECKS: Array[StringName] = [&"basket", &"column", &"crate"]


func _init() -> void:
	name = "the whale's belly"
	way = Vector2.RIGHT
	plants = true
	price_factor = 0.0
	cells = Vector2i(MAP[0].length(), MAP.size())
	print_realm = &"belly"


func title() -> String:
	return "world %d · %s" % [coord.x, name]


## Its own decor (RisoDecor.plan_belly): bones, strands and veins.
func decor() -> StringName:
	return &"belly"


## The map in the generator's colours (the collapse is laid over by populate anyway).
func fallback() -> Array:
	var out: Array = []
	for x: int in range(size.x):
		var column: Array = []
		for y: int in range(size.y):
			column.append(Color.BLACK if _at(Vector2i(x, y)) == "#" else Color.WHITE)
		out.append(column)
	return out


## The map laid over whatever the collapse made, then what stands in it.
func populate(w: LevelGen) -> void:
	for x: int in range(size.x):
		for y: int in range(size.y):
			var v: Vector2i = Vector2i(x, y)
			if _at(v) == "#":
				if w.get_cell(v).type != LevelGen.Type.GROUND:
					w._to_rock(v)
			elif w.get_cell(v).type != LevelGen.Type.EMPTY:
				w._to_open(v)
	var wrecks: int = 0
	for y: int in range(size.y):
		for x: int in range(size.x):
			var v: Vector2i = Vector2i(x, y)
			match _at(v):
				"=":
					w.put(v, LevelGen.Type.PLATFORM)
				"B":
					w.put(v, LevelGen.Type.EXIT, MapInfo.Exit.BACK)
					w.exits = {MapInfo.Exit.BACK: v}
				"L":
					w.put(v, LevelGen.Type.CHECKPOINT)
					w.exit_lanterns = {MapInfo.Exit.BACK: v}
				"H":
					w.put(v, LevelGen.Type.BOSS, &"whale")
				"w":
					w.put(v, LevelGen.Type.WRECK, WRECKS[wrecks % WRECKS.size()])
					wrecks += 1
				"A":
					w.put(v, LevelGen.Type.ACID, {"basin": ACID_BASIN, "low": ACID_LOW, "high": ACID_HIGH})


## Its exits: the way back alone.
func ways() -> Array[int]:
	var out: Array[int] = [MapInfo.Exit.BACK]
	return out


## What the map holds at `v` (rock outside it).
func _at(v: Vector2i) -> String:
	if v.y < 0 or v.y >= MAP.size() or v.x < 0 or v.x >= MAP[v.y].length():
		return "#"
	return MAP[v.y][v.x]
