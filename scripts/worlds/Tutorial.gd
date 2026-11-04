class_name Tutorial
extends SideWorld
## The tutorial: a side world laid out by hand (MAP), where a new run begins (MapInfo.start_run,
## when the start menu's tutorial toggle is on) before it comes out into the world chosen. One long
## hall in the garden's print, taught without words: each stretch asks for one thing, and a card of
## the control it wants (ControlHint) stands at its start until the wizard has used it there.
## From left to right: the start lantern, lit, and the wizard by it (walk); steps up and down with
## stars over them (jump); a bed of thorns a jump clears, a star over it; a bed of thorns too wide
## to jump (dash), its thorns sending the wizard back to its edge as all thorns do, and a star
## cluster past it; a lantern to light (interact);
## a key on a ledge and its door across a low corridor; a wisp (the spell); a watcher on a slab out
## of reach, beaten only by turning its shots back (the spell's guard, a parry); a shrine, where the
## stars picked up on the way buy a first ability; and the way out (the map), with room by it.
## The way out comes out by the door into here that every start level has (deals): laid once the
## rest of that level is laid out (laid_last), so it moves nothing else there. Through that door the
## wizard comes back in at the way out. Its key and door are dealt the first colour, to match.
## Nothing here draws from the world RNG: it is the same every visit, in every world.
## Whether a player has been through it is kept apart from any run (done, mark_done), so the toggle
## starts on until they have.

## The hall, row by row: rock (#), open air (.), where a run starts (S) by its lantern, lit (L), a
## lantern to light (l), a star (*) and a star cluster (C), thorns (^), a key (k) and its door (D),
## a wisp (w), a watcher (s), the shrine (H, its left foot), the way out (B), and the control cards
## (ControlHint, by the digits of HINTS).
const MAP: Array[String] = [
	"########################################################################################################",
	"########################################################################################################",
	"#...........................................................###........................................#",
	"#...........................................................###........................................#",
	"#...........................................................###........................................#",
	"#...........................................................###..................s.....................#",
	"#...........................................................###.................###....................#",
	"#...............**..........................................###........w...............................#",
	"#............*.....*...................................k....###........................................#",
	"#..............###......*............*................###...###........................................#",
	"#.L.S.1...2.#########........**..3........C...5.l....####....D....4.*.....*...4.....**.....H.....6...B.#",
	"########################^^##########^^^#################################################################",
	"########################################################################################################",
	"########################################################################################################",
	"########################################################################################################",
	"########################################################################################################",
]
## The things each letter of the map places (see MAP).
const THINGS: Dictionary = {
	"l": LevelGen.Type.CHECKPOINT,
	"*": LevelGen.Type.COIN,
	"C": LevelGen.Type.CLUSTER,
	"^": LevelGen.Type.SPIKES,
	"w": LevelGen.Type.ENEMY,
	"s": LevelGen.Type.SHOOTER,
	"H": LevelGen.Type.SHRINE,
}
## The control card each digit of the map stands for (ControlHint.action).
const HINTS: Dictionary = {
	"1": &"Move",
	"2": &"Jump",
	"3": &"Dash",
	"4": &"Spell",
	"5": &"Discover",
	"6": &"ShowMap",
}
## The key colour its key and door are dealt (Rules.rarity_color's first).
const KEY_COLOR: int = 0

## Where whether the tutorial has been through is kept (tests set their own), and the key in it.
static var settings_path: String = "user://settings.cfg"
const SECTION: String = "tutorial"
const DONE_KEY: String = "done"


func _init() -> void:
	name = "tutorial"
	way = Vector2.LEFT
	print_realm = &"garden"
	plants = true
	price_factor = 0.0
	laid_last = true
	cells = Vector2i(MAP[0].length(), MAP.size())


## Every start level has a door into its tutorial.
func deals(at: Vector2i) -> bool:
	return not Worlds.is_side(at) and at.y == 0


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
			if THINGS.has(c):
				w.put(v, THINGS[c])
			elif HINTS.has(c):
				w.put(v, LevelGen.Type.HINT, HINTS[c])
			match c:
				"S":
					w.start = v
				"L":
					w.put(v, LevelGen.Type.CHECKPOINT)
					w.start_lantern = v
				"k":
					w.put(v, LevelGen.Type.KEY, KEY_COLOR)
				"D":
					w.put(v, LevelGen.Type.DOOR, KEY_COLOR)
				"B":
					w.put(v, LevelGen.Type.EXIT, MapInfo.Exit.BACK)
					w.exits = {MapInfo.Exit.BACK: v}


## Its exits: the way out alone (back out of the door it is entered by).
func ways() -> Array[int]:
	var out: Array[int] = [MapInfo.Exit.BACK]
	return out


## What the map holds at `v` (rock outside it).
func _at(v: Vector2i) -> String:
	if v.y < 0 or v.y >= MAP.size() or v.x < 0 or v.x >= MAP[v.y].length():
		return "#"
	return MAP[v.y][v.x]


# ------------------------------------------------------------------ whether it has been through

## Whether a player has come out of the tutorial before, in any run.
static func done() -> bool:
	var file: ConfigFile = ConfigFile.new()
	if file.load(settings_path) != OK:
		return false
	return bool(file.get_value(SECTION, DONE_KEY, false))


## Note that a player has come out of the tutorial.
static func mark_done() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.load(settings_path)
	file.set_value(SECTION, DONE_KEY, true)
	file.save(settings_path)


## The kind's number (its index in Worlds.KINDS).
static func kind_number() -> int:
	return Worlds.kind_of(Tutorial)


## The tutorial a run on `run_seed` begins in.
static func of(run_seed: int) -> Vector2i:
	return Worlds.side_at(kind_number(), Vector2i(run_seed, 0))
