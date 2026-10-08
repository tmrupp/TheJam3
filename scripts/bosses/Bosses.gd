class_name Bosses
extends RefCounted
## The bosses that guard the band ends (docs/REGIONS_PLAN.md §5). The last level of each band,
## toward the next, is a gate level: its way on is sealed while the band's boss lives, in every
## world column. A boss is beaten once per run (RunState.bosses): then every gate level of its band
## opens for good, the boss is never met again, and where it fell a relic waits, free. The worm and
## the bramble fight in the gate level itself; the others in an arena of their own (Arena), a side
## world behind a door in the gate level. Until each boss is built, a stand-in fights for it (Boss);
## the worm is built (Worm).

## Who guards the garden's way down and its way up, and the far end of each band below and above
## the garden, in NextWorldDef.DOWN's and UP's order.
const GARDEN_DOWN: StringName = &"worm"
const GARDEN_UP: StringName = &"bramble"
const DOWN: Array[StringName] = [&"necromancer", &"beast"]
const UP: Array[StringName] = [&"spider", &"whale"]
## The bosses fought in the gate level rather than an arena.
const IN_LEVEL: Array[StringName] = [&"worm", &"bramble"]
## Salt for the run seed when dealing a boss's relic.
const RELIC_DEAL: int = 5300
## The prefab of each boss built so far; the rest are fought by the stand-in (Boss), which is the
## boss cell's prefab in Placeables.
const SCENES: Dictionary = {
	&"worm": "res://prefabs/worm.tscn",
}


## The prefab boss `name` is fought as: its own (SCENES), else the stand-in.
static func scene(name: StringName) -> PackedScene:
	if SCENES.has(name):
		return load(String(SCENES[name])) as PackedScene
	return Placeables.scene(LevelGen.Type.BOSS)


## The boss whose gate is the way on of row `row`'s levels, or &"" for a row with no gate.
static func gate_at(row: int) -> StringName:
	var g: int = NextWorldDef.GARDEN_ROWS
	if row == g:
		return GARDEN_DOWN
	if row == -g:
		return GARDEN_UP
	var past: int = absi(row) - g
	if past <= 0 or past % NextWorldDef.BAND != 0:
		return &""
	@warning_ignore("integer_division")
	var i: int = past / NextWorldDef.BAND - 1
	var names: Array[StringName] = DOWN if row > 0 else UP
	return names[i] if i < names.size() else &""


## The row of the gate boss `name` guards (0 for none).
static func row_of(name: StringName) -> int:
	if name == GARDEN_DOWN:
		return NextWorldDef.GARDEN_ROWS
	if name == GARDEN_UP:
		return -NextWorldDef.GARDEN_ROWS
	for way: int in [1, -1]:
		var names: Array[StringName] = DOWN if way > 0 else UP
		var i: int = names.find(name)
		if i >= 0:
			return way * (NextWorldDef.GARDEN_ROWS + (i + 1) * NextWorldDef.BAND)
	return 0


## Whether boss `name` fights in an arena of its own (else in its gate level).
static func in_arena(name: StringName) -> bool:
	return name != &"" and not IN_LEVEL.has(name)


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


## The relic boss `name` leaves for the wizard of run `run_seed` with `player`'s abilities: the first
## of the relic moves (Relics.MOVES, gone round from one dealt by the seed and the boss) not yet
## known, or &"" when every one is.
static func relic_for(name: StringName, run_seed: int, player: Player) -> StringName:
	var moves: Array[StringName] = Relics.MOVES
	var first: int = posmod(Rules.level_seed(run_seed, RELIC_DEAL + row_of(name)), moves.size())
	for i: int in range(moves.size()):
		var move: StringName = moves[(first + i) % moves.size()]
		if Abilities.tier(player, move) == 0:
			return move
	return &""
