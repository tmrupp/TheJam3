class_name Tutorial
extends SideWorld
## The tutorial: a side world laid out by hand (MAP), where a new run begins (MapInfo.start_run,
## when the start menu's tutorial toggle is on) before it comes out into the world chosen. One long
## hall in the garden's print, taught without words: each stretch asks for one thing, and a card of
## the control it wants (ControlHint) stands at its start until the wizard has used it there.
## From left to right: the start lantern, lit, and the wizard by it (walk); steps up and down with
## stars over them (jump); a bed of thorns a jump clears, a star over it; a bed of thorns too wide
## to jump (dash), its thorns sending the wizard back to its edge as all thorns do, and a star
## cluster past it; a wider bed that a jump and a dash fall short of, with a moon over it where the
## dash goes, which gives the dash back for a second one (a moon, Moon), a star where that one goes;
## a lantern to light (interact);
## a key on a ledge and its door across a low corridor; a wisp (the spell); a watcher hovering over
## the hall, in view but warded against every blow but its own shots turned back (the spell's guard,
## a parry, its own card, standing where its first shot comes at the wizard); a bed
## of thorns too wide to jump and dash over, crossed by bouncing off them (a pogo: the guard, or a
## slash down, catching the thorns underfoot, its own card too); the utility spell's
## card, which costs the wizard a heart as it rises so that mend has something to heal (ControlHint);
## a lantern to light and then burn into mend, filling the draught just drunk (the burn card, by it,
## learned by burning it: a lantern lit is the only thing that refills mend, at the cost of its
## protection), and a lantern past it to light again, to be protected once more; a shrine, where the stars picked up on the way buy a first ability, a choice between a strict
## upgrade and a swap (BOONS); a room of trophy stands, one for each boss in the band layout
## (TrophyStand), where the run is won by bringing back every boss's trophy (Trophy); and the way
## out (the map).
## The way out comes out by the door into here that every start level has (deals): laid once the
## rest of that level is laid out (laid_last), so it moves nothing else there. Through that door the
## wizard comes back in at the way out. Its key and door are dealt the first colour, to match.
## Nothing here draws from the world RNG: it is the same every visit, in every world.
## Whether a player has been through it is kept apart from any run (done, mark_done), so the toggle
## starts on until they have.

## The hall, row by row: rock (#), open air (.), where a run starts (S) by its lantern, lit (L), a
## lantern to light (l), a star (*) and a star cluster (C), thorns (^), a key (k) and its door (D),
## a wisp (w), a watcher hovering (s, HOVERING), a moon (m), the shrine (H, its left foot), the spots for trophy stands (T), the
## way out (B), and the control cards (ControlHint, by the digits of HINTS: "0" the burn card).
const MAP: Array[String] = [
	"#########################################################################################################################################################",
	"#########################################################################################################################################################",
	"#..................................................................###..................................................................................#",
	"#..................................................................###..................................................................................#",
	"#..................................................................###..................................................................................#",
	"#..................................................................###..................................................................................#",
	"#..................................................................###..................................................................................#",
	"#...............**.................................................###........w.........................................................................#",
	"#............*.....*..........................................k....###..................................................................................#",
	"#..............###......*............*........m.*............###...###....................s.............................................................#",
	"#.L.S.1...2.#########........**..3........C..........5.l....####....D....4.*.....*...8.....9.............**.7......0.l......l...H....T.T.T.T.T.T..6...B.#",
	"########################^^##########^^^######^^^^###########################################^^^^^^^^^^###################################################",
	"#########################################################################################################################################################",
	"#########################################################################################################################################################",
	"#########################################################################################################################################################",
	"#########################################################################################################################################################",
]
## The map's letter for its watcher: it hovers (the `hovers` mod, Shooter) rather than stands,
## as a watcher standing on a ledge cannot see down past its edge, and only a parried shot wounds it
## (the `parried_only` mod, Wound.parried_only), so turning its shots back is the one way to beat it.
const HOVERING: String = "s"
## The things each letter of the map places (see MAP).
const THINGS: Dictionary = {
	"l": LevelGen.Type.CHECKPOINT,
	"*": LevelGen.Type.COIN,
	"C": LevelGen.Type.CLUSTER,
	"^": LevelGen.Type.SPIKES,
	"w": LevelGen.Type.ENEMY,
	"s": LevelGen.Type.SHOOTER,
	"H": LevelGen.Type.SHRINE,
	"m": LevelGen.Type.MOON,
}
## The control card each digit of the map stands for (ControlHint.action).
const HINTS: Dictionary = {
	"1": &"Move",
	"2": &"Jump",
	"3": &"Dash",
	"4": &"Spell",
	"5": &"Discover",
	"6": &"ShowMap",
	"7": &"Utility",
	"8": ControlHint.PARRY,
	"9": ControlHint.POGO,
	"0": ControlHint.BURN,
}
## What its shrine offers, a first lesson in choosing (boons): a strict upgrade, vigor (a heart more,
## as the utility card has just shown what a heart is worth), against a swap, hex (a bolt) in place
## of the slash in the damage slot, handed back as an exam paper if taken (Shrine.buy_boon).
const BOONS: Array[StringName] = [&"vigor", &"hex"]
## The map's letter for a spot a trophy stand may take. The layout's bosses (Bands.bosses) take the
## middle ones of them, in order; there are spots enough for the whole game's six.
const STAND: String = "T"
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
				if w.type_at(v) != LevelGen.Type.GROUND:
					w._to_rock(v)
			elif w.type_at(v) != LevelGen.Type.EMPTY:
				w._to_open(v)
	var stands: Array[Vector2i] = []
	for y: int in range(size.y):
		for x: int in range(size.x):
			var v: Vector2i = Vector2i(x, y)
			var c: String = _at(v)
			if THINGS.has(c):
				w.put(v, THINGS[c])
				if c == HOVERING:
					w.get_cell(v).mods["hovers"] = true
					w.get_cell(v).mods["parried_only"] = true
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
				STAND:
					stands.append(v)
	var bosses: Array[StringName] = Bands.bosses()
	var first: int = maxi(0, floori(float(stands.size() - bosses.size()) * 0.5))
	for i: int in range(mini(bosses.size(), stands.size())):
		w.put(stands[first + i], LevelGen.Type.TROPHY_STAND, bosses[i])


## Its shrine's boons (BOONS) while both are still unknown to the wizard; else the usual ones (a
## wizard back in through the start level's door, later in the run, with one of them learned).
func boons(player: Player) -> Array[StringName]:
	for a: StringName in BOONS:
		if Abilities.tier(player, a) > 0:
			return []
	return BOONS.duplicate()


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
