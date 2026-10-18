class_name BeastSouls
extends RefCounted
## The eldritch beast's souls (Bosses.DOWN's last, docs/REGIONS_PLAN.md §6), apart from the scene.
## The first time the beast wakes in its chamber (Beast), it sends its souls out across the run
## (send): SOULS, and one more for every FED_PER_SOUL rings of the institute's bells before then,
## without end (count: the bells feed it, RunState.fed). The wizard who explored is
## rewarded for it: for every VISITS_PER_SOUL levels visited,
## one soul goes into a level they have been to (in any band and column, mapped and known), and
## the rest are flung far (far_flung): into levels not yet visited, FAR_COLUMNS worlds off the
## beast's to either side, each in a band of its own in turn. So a wizard who dived straight down
## hunts souls all over the world, and one who wandered finds them in places they know. Never into
## a side world, a gate level (where a boss fights) or the level it was sent from. Each lies on a
## floor of its level (spot), the same on every visit, and abominations rise round it (BeastSoul).
## The beast cannot be wounded while any lives: each destroyed shuts one of its eyes, and stays
## destroyed for the rest of the run, whatever deaths come. Kept in RunState.souls and souls_sent.
## Nothing here draws from any RNG.

## No cell chosen yet for a soul (its level not yet laid out since it was sent).
const NO_SPOT: Vector2i = Vector2i(-1, -1)
## How many souls it sends out, fed nothing; one more for every FED_PER_SOUL rings of the bells.
const SOULS: int = 8
const FED_PER_SOUL: int = 4
## One soul stays in a level visited for every VISITS_PER_SOUL levels visited (up to all of them).
const VISITS_PER_SOUL: int = 5
## A soul flung far goes this many worlds off the beast's (from, to), to either side.
const FAR_COLUMNS: Vector2i = Vector2i(3, 12)
## The bands souls are flung into, taking turns (NextWorldDef's archetype names).
const FAR_BANDS: Array[StringName] = [&"garden", &"cemetery", &"crags", &"institute", &"sky"]
## How many places to try for the souls flung far before giving up on the rest.
const FAR_TRIES: int = 200
## A soul lies at least SOUL_CLEAR cells from the way into its level, where there is such a floor.
const SOUL_CLEAR: int = 8
## Abominations laid round a soul each time its level is entered (BeastSoul): up to GUARDS, on the
## free floors nearest it within GUARD_REACH cells.
const GUARDS: int = 2
const GUARD_REACH: int = 6
## Salts for the run seed: which levels visited take a soul, where the far ones go, and where in its
## level a soul lies.
const SOUL_DEAL: int = 7800
const SPOT_DEAL: int = 7810
const FAR_DEAL: int = 7820


## Whether a soul could be sent into place `c`: an ordinary level, not a gate level, not `from`.
static func could_hold(c: Vector2i, from: Vector2i) -> bool:
	return not Worlds.is_side(c) and c != from and Bosses.gate_at(c.y) == &""


## A hash of place `c` for run `run`: the order souls go out in.
static func _order(run: RunState, c: Vector2i) -> int:
	return Rules.level_seed(run.run_seed, SOUL_DEAL + c.x * 977 + c.y * 131)


## The levels visited a soul could go into from the beast's level `from`, in the order souls go
## out in (hashed from the run seed).
static func visited(run: RunState, from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in run.records:
		if could_hold(c, from):
			out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ha: int = _order(run, a)
		var hb: int = _order(run, b)
		return ha < hb or (ha == hb and a < b))
	return out


## How many souls it sends out in run `run`, fed as it has been (see SOULS).
static func count(run: RunState) -> int:
	@warning_ignore("integer_division")
	return SOULS + run.fed / FED_PER_SOUL


## How many of `most` souls stay in levels visited, when `count` levels a soul could go into were
## visited.
static func kept_near(count: int, most: int = SOULS) -> int:
	@warning_ignore("integer_division")
	return mini(mini(count / VISITS_PER_SOUL, most), count)


## The `k`th place tried for a soul flung far from the beast's level `from` in run `run`: in the
## band whose turn it is (FAR_BANDS, from one dealt by the run), a row of it, and a world
## FAR_COLUMNS off the beast's to one side or the other, all dealt by the run seed.
static func far_flung(run: RunState, from: Vector2i, k: int) -> Vector2i:
	var roll: int = Rules.level_seed(run.run_seed, FAR_DEAL + k)
	var first: int = posmod(Rules.level_seed(run.run_seed, FAR_DEAL - 1), FAR_BANDS.size())
	var band: StringName = FAR_BANDS[(first + k) % FAR_BANDS.size()]
	var row: int = 0
	if band == &"garden":
		row = posmod(roll, NextWorldDef.GARDEN_ROWS * 2 - 1) - (NextWorldDef.GARDEN_ROWS - 1)
	else:
		row = NextWorldDef.band_row(band, posmod(roll >> 4, NextWorldDef.BAND))
	var off: int = FAR_COLUMNS.x + posmod(roll >> 8, FAR_COLUMNS.y - FAR_COLUMNS.x + 1)
	var side: int = 1 if posmod(roll >> 12, 2) == 0 else -1
	return Vector2i(from.x + side * off, row)


## The beast woke in place `from` (its gate level): its souls go out (see the class description),
## unless they already have, or it is slain.
static func send(run: RunState, from: Vector2i) -> void:
	if run.souls_sent > 0 or run.bosses.has(&"beast"):
		return
	var known: Array[Vector2i] = visited(run, from)
	var souls: int = count(run)
	for c: Vector2i in known.slice(0, kept_near(known.size(), souls)):
		run.souls[c] = NO_SPOT
	var k: int = 0
	while run.souls.size() < souls and k < FAR_TRIES:
		var c: Vector2i = far_flung(run, from, k)
		if could_hold(c, from) and not run.records.has(c) and not run.souls.has(c):
			run.souls[c] = NO_SPOT
		k += 1
	run.souls_sent = run.souls.size()


## How far place `a` is from place `b`: places across plus rows.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## How many of its souls live.
static func alive(run: RunState) -> int:
	return run.souls.size()


## Whether a soul lies in place `at`.
static func here(run: RunState, at: Vector2i) -> bool:
	return run.souls.has(at)


## Where the soul in place `at` lies in its layout `w`: chosen the first time (a free floor at least
## SOUL_CLEAR cells from the way in, else any, dealt by the run seed) and kept. NO_SPOT when there is
## no soul there or no floor for it.
static func spot(run: RunState, at: Vector2i, w: LevelGen) -> Vector2i:
	if not run.souls.has(at):
		return NO_SPOT
	var kept: Vector2i = run.souls[at]
	if kept != NO_SPOT:
		return kept
	var floors: Array[Vector2i] = w.free_floors()
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, NO_SPOT)
	var clear: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return start == NO_SPOT or LevelGen.dist(v, start) >= SOUL_CLEAR)
	if not clear.is_empty():
		floors = clear
	if floors.is_empty():
		return NO_SPOT
	var pick: Vector2i = floors[posmod(Rules.level_seed(run.run_seed, SPOT_DEAL + at.x * 977 + at.y * 131), floors.size())]
	run.souls[at] = pick
	return pick


## The free floors of `w` nearest `soul` (within GUARD_REACH cells, not its own), up to GUARDS,
## where abominations are laid round it.
static func guard_spots(w: LevelGen, soul: Vector2i) -> Array[Vector2i]:
	var near: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool: return v != soul and LevelGen.dist(v, soul) <= GUARD_REACH and LevelGen.dist(v, soul) >= 2)
	near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = LevelGen.dist(a, soul)
		var db: int = LevelGen.dist(b, soul)
		return da < db or (da == db and a < b))
	var out: Array[Vector2i] = []
	for v: Vector2i in near:
		if out.size() >= GUARDS:
			break
		if out.all(func(o: Vector2i) -> bool: return LevelGen.dist(o, v) >= 2):
			out.append(v)
	return out


## The soul in place `at` is destroyed, for good.
static func destroyed(run: RunState, at: Vector2i) -> void:
	run.souls.erase(at)


## The beast is slain: whatever souls are left go with it.
static func end(run: RunState) -> void:
	run.souls.clear()
