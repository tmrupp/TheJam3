class_name Bosses
extends RefCounted
## The bosses that guard the band ends (docs/REGIONS_PLAN.md §5). The last level of each band,
## toward the next, is a gate level: its way on is sealed while the band's boss lives, in every
## world column. A boss is beaten once per run (RunState.bosses): then every gate level of its band
## opens for good, the boss is never met again, and where it fell a relic unlock waits (KeyRing.UNLOCK:
## the only way to take a relic of a move not yet known, see Relic), and beside it its trophy (Trophy), to be brought back to its stand in the tutorial (TrophyStand). Every boss
## fights in its gate level itself (LevelGen.place_boss), as its own prefab (SCENES), but in one
## world column only, dealt for the run near the column it started in (column): every gate level of
## its row is laid out for it (a shaft, a hall, a crypt, a chamber), but it is met in that one, and
## the others stand empty (LevelLoader leaves it out). Its column is felt in the levels near it
## (near; docs/REVIEW_PLAN.md §2): the worm's rumble (WormSign), and spare small worms, seed pods and
## thorn vines kept as the run's nearness calls for (spare_kept); a shrine sells which way it lies
## (Shrine). The bosses are the worm (Worm), the bramble (Bramble, in its shaft:
## BrambleShaft), the lodestone golem (Golem, in its hall: LodeHall), the necromancer (Necromancer,
## in a crypt: Crypts), the whale (Whale) and the eldritch beast (Beast, in its chamber: Institute;
## its souls: BeastSouls), the whale the one boss not in a gate level: it roams the sky's top row
## (WhaleHunt), fought at its heart in its belly (Belly, WhaleHeart, the prefab its name places).

## Who guards which gate is the band layout's (Bands.LAYOUTS): the garden's way down and way up,
## and the far end of each band below and above it.
## Salt for the run seed when dealing a boss's relic.
const RELIC_DEAL: int = Salts.BOSSES_RELIC * Salts.STRIDE
## Bosses that have given way to others since a run was saved, by the old name: the new one (the
## golem took the spider's place). A saved run's bosses slain and relics waiting are read under the
## new names (RunState.gone_kinds).
const RENAMED: Dictionary = {&"spider": &"golem"}
## The prefab of each boss, placed for its boss cell (Placeables has none for that cell).
const SCENES: Dictionary = {
	&"worm": "res://prefabs/worm.tscn",
	&"bramble": "res://prefabs/bramble.tscn",
	&"golem": "res://prefabs/golem.tscn",
	&"necromancer": "res://prefabs/necromancer.tscn",
	&"whale": "res://prefabs/whale_heart.tscn",
	&"beast": "res://prefabs/beast.tscn",
}


## The prefab boss `name` is fought as (SCENES).
static func scene(name: StringName) -> PackedScene:
	return load(String(SCENES[name])) as PackedScene


## Salt for the run seed when dealing a boss's column.
const COLUMN_DEAL: int = Salts.BOSSES_COLUMN * Salts.STRIDE
## The world column boss `name` is met in, in run `run_seed` (which starts in column `run_seed`):
## within spread(name) of it, dealt by the run seed and the boss. The whale roams its row instead
## (WhaleHunt).
static func column(name: StringName, run_seed: int) -> int:
	var reach: int = spread(name)
	var roll: int = Rules.level_seed(run_seed, COLUMN_DEAL + posmod(String(name).hash(), 997))
	return run_seed + posmod(roll, reach * 2 + 1) - reach


## How many columns either side of the run's starting column boss `name`'s column may be: as many
## as its band is deep (Bands: the garden's half, from the start to its gate, for the garden's
## bosses; the band's rows for a band's), so finding its column is a walk as long as the band's.
static func spread(name: StringName) -> int:
	var row: int = row_of(name)
	if absi(row) <= Bands.garden_rows():
		return Bands.garden_rows()
	return int(Bands.band_at(row)["rows"])


## How many levels from a garden boss's own (columns and rows added) its signs reach (near).
const SIGN_REACH: int = 4


## How near level `at` is to boss `name`'s own, in run `run_seed`: 1 in its level, falling to 0
## SIGN_REACH levels away (columns and rows added); 0 in a side world, on the far side of the start
## from its gate (the worm's signs are below the start, the bramble's above), for the whale (it
## roams), and for a boss left out of the bands in play. Whether it is slain is the caller's to ask.
static func near(name: StringName, at: Vector2i, run_seed: int) -> float:
	if name == &"whale" or Worlds.is_side(at):
		return 0.0
	var row: int = row_of(name)
	if row == 0 or signi(at.y) != signi(row):
		return 0.0
	var d: int = absi(at.x - column(name, run_seed)) + absi(at.y - row)
	return clampf(1.0 - float(d) / float(SIGN_REACH), 0.0, 1.0)


## Whether spare `order` (0 first) of `count` laid in a level for a boss's signs is kept in it, the
## level being `nearness` (near) to that boss: as many of them as its nearness calls for, the first
## first; none at 0, every one in the boss's own column.
static func spare_kept(order: int, count: int, nearness: float) -> bool:
	return order < roundi(nearness * float(count))


## The boss ahead of row `row`: the one whose gate is the first met going away from the start from
## it (its own row's, if it is a gate level), or &"" with none that way. The start looks down.
static func ahead(row: int) -> StringName:
	var way: int = NextWorldDef.away(row)
	var r: int = row
	while absi(r) <= absi(row) + Bands.GARDEN_ROWS + Bands.BAND_ROWS * 4:
		var name: StringName = gate_at(r)
		if name != &"":
			return name
		r += way
	return &""


## The boss whose gate is the way on of row `row`'s levels, or &"" for a row with no gate.
static func gate_at(row: int) -> StringName:
	return Bands.gate_at(row)


## The row of the gate boss `name` guards (0 for none, or for one left out of the bands in play).
static func row_of(name: StringName) -> int:
	return Bands.row_of(name)


## The gates a way from row `from` to row `to` passes out through (away from the start), nearest
## the start first: by stepping outward past a gate level's row on the way. Going toward the start
## passes no gate; across the start, only the gates on the far side count.
static func crossed(from: int, to: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if to == from:
		return out
	var way: int = signi(to) if to != 0 else 0
	if way == 0:
		return out
	var start: int = absi(from) if signi(from) == way else 0
	for d: int in range(start, absi(to)):
		var name: StringName = gate_at(way * d)
		if name != &"" and absi(to) > d:
			out.append(name)
	return out


## A relic move the wizard of run `run_seed` with `player`'s abilities could still learn, as boss
## `name` falls: the first of the relic moves (Relics.MOVES, gone round from one dealt by the seed
## and the boss) not yet known, or &"" when every one is (then a boss drops no relic unlock, see
## MapInfo.boss_slain). Bosses dropped this move's relic itself before they dropped unlocks; a saved
## run's relic still waiting from then is kept (RunState.boss_relics).
static func relic_for(name: StringName, run_seed: int, player: Player) -> StringName:
	var moves: Array[StringName] = Relics.MOVES
	var first: int = posmod(Rules.level_seed(run_seed, RELIC_DEAL + row_of(name)), moves.size())
	for i: int in range(moves.size()):
		var move: StringName = moves[(first + i) % moves.size()]
		if Abilities.tier(player, move) == 0:
			return move
	return &""
