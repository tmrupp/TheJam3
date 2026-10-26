class_name PracticeRange
extends SideWorld
## The practice range, for debug runs: a side world no door leads into, entered only from the F7
## panel's Travel row (its button goes into the one under the chosen level, so its foes have that
## level's health, Wound.hp_for). It is for trying the damage spells against every kind of foe and
## weighing them against one another. It is laid out by hand (MAP), one long hall under a high
## roof: the wizard arrives at its left end, by the way back and a lantern, and walks right through
## a row of bays, each holding one kind of foe, parted by low walls a jump clears (most walkers
## stay in their own bay): wisps, hoppers, watchers (one on a step), foes with shields (a wisp, a
## watcher and a hopper), abominations, crossbows set into both walls of their bay shooting in, a
## rock-bug nest with two bugs, and last a tall bay where two birds patrol. Its tally (PracticeTally)
## stands by the way in: it brings the foes back after they fall, can hold them still or make them
## sturdy (the F7 panel's Practice range rows), and shows what the spell in the damage slot has done
## to them. Nothing here draws from the world RNG: it is the same every visit.

## The range, row by row: rock (#), open air (.), the way back (B), its lantern (L), the tally (T),
## and the foes: a wisp (w), a hopper (h), a watcher (s), each of those with a shield (W, H, S), an
## abomination (a), a crossbow in the wall to its left shooting right (>) and one in the wall to its
## right shooting left (<), a rock-bug (u), a rock-bug nest (n) and a bird (b, patrolling the open
## stretch of its row in its bay).
const MAP: Array[String] = [
	"#######################################################################################################################",
	"#######################################################################################################################",
	"#.....................................................................................................................#",
	"#.....................................................................................................................#",
	"#.....................................................................................................................#",
	"#.....................................................................................................................#",
	"#.........................................................................................................b...........#",
	"#.....................................................................................................................#",
	"#................................................................................................................b....#",
	"#.....................................................................................................................#",
	"#.........................................s...........................................................................#",
	"#.........#............#............#.....##.....#............#............##..........##............#................#",
	"#.B..L..T.#..w...w...w.#...h....h...#..s..##...s.#..W...S...H.#...a....a...##>........<##.u....n....u#................#",
	"#######################################################################################################################",
	"#######################################################################################################################",
	"#######################################################################################################################",
]
## What each letter of the map places (see MAP); a capital is the same foe with a shield.
const FOES: Dictionary = {
	"w": LevelGen.Type.ENEMY,
	"h": LevelGen.Type.HOPPER,
	"s": LevelGen.Type.SHOOTER,
	"W": LevelGen.Type.ENEMY,
	"H": LevelGen.Type.HOPPER,
	"S": LevelGen.Type.SHOOTER,
	"a": LevelGen.Type.ABOMINATION,
	"u": LevelGen.Type.BUG,
	"n": LevelGen.Type.NEST,
}
## The column the bird bay starts at: a bird patrols its row from there to the range's far wall.
const BIRD_BAY: int = 102


func _init() -> void:
	name = "practice range"
	way = Vector2.RIGHT
	plants = false
	price_factor = 0.0
	cells = Vector2i(MAP[0].length(), MAP.size())


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
	for y: int in range(size.y):
		for x: int in range(size.x):
			var v: Vector2i = Vector2i(x, y)
			var c: String = _at(v)
			if FOES.has(c):
				var cell: LevelGen.Cell = w.put(v, FOES[c])
				if c == c.to_upper():
					cell.mods["shield"] = Shield.HP
				continue
			match c:
				"B":
					w.put(v, LevelGen.Type.EXIT, MapInfo.Exit.BACK)
					w.exits = {MapInfo.Exit.BACK: v}
				"L":
					w.put(v, LevelGen.Type.CHECKPOINT)
					w.exit_lanterns = {MapInfo.Exit.BACK: v}
				"T":
					w.put(v, LevelGen.Type.TALLY)
				">", "<":
					w.put(v, LevelGen.Type.CROSSBOW, {"facing": 1 if c == ">" else -1, "inward": true})
				"b":
					w.put(v, LevelGen.Type.BIRD, [BIRD_BAY, size.x - 2])


## Its exits: the way back alone.
func ways() -> Array[int]:
	var out: Array[int] = [MapInfo.Exit.BACK]
	return out


## What the map holds at `v` (rock outside it).
func _at(v: Vector2i) -> String:
	if v.y < 0 or v.y >= MAP.size() or v.x < 0 or v.x >= MAP[v.y].length():
		return "#"
	return MAP[v.y][v.x]
