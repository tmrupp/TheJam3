class_name BeastSouls
extends RefCounted
## The eldritch beast's souls (Bosses.DOWN's last, docs/REGIONS_PLAN.md §6), apart from the scene.
## The first time the beast wakes in its chamber (Beast), it sends its souls out across the run
## (send): one for every SOULS_EVERY levels the wizard has visited (SOULS_MIN to SOULS_MOST), most
## into levels the wizard has been to, in any band and any column, and one in every AFAR_EVERY into
## a level beside one of those, not yet visited. Never into a side world, a gate level (where a boss
## fights) or the level it was sent from. Each lies on a floor of its level (spot), the same on
## every visit, and abominations rise round it (BeastSoul). The beast cannot be wounded while any
## lives: each destroyed shuts one of its eyes, and stays destroyed for the rest of the run, whatever
## deaths come. Kept in RunState.souls and souls_sent. Nothing here draws from any RNG.

## No cell chosen yet for a soul (its level not yet laid out since it was sent).
const NO_SPOT: Vector2i = Vector2i(-1, -1)
## One soul for every SOULS_EVERY levels visited, at least SOULS_MIN and at most SOULS_MOST.
const SOULS_EVERY: int = 5
const SOULS_MIN: int = 3
const SOULS_MOST: int = 7
## One soul in every AFAR_EVERY goes into a level not yet visited (beside one that has been).
const AFAR_EVERY: int = 3
## A soul lies at least SOUL_CLEAR cells from the way into its level, where there is such a floor.
const SOUL_CLEAR: int = 8
## Abominations laid round a soul each time its level is entered (BeastSoul): up to GUARDS, on the
## free floors nearest it within GUARD_REACH cells.
const GUARDS: int = 2
const GUARD_REACH: int = 6
## Salts for the run seed: which levels take a soul, and where in its level it lies.
const SOUL_DEAL: int = 7800
const SPOT_DEAL: int = 7810


## Whether a soul could be sent into place `c`: an ordinary level, not a gate level, not `from`.
static func could_hold(c: Vector2i, from: Vector2i) -> bool:
	return not Worlds.is_side(c) and c != from and Bosses.gate_at(c.y) == &""


## A hash of place `c` for run `run`: the order souls go out in.
static func _order(run: RunState, c: Vector2i) -> int:
	return Rules.level_seed(run.run_seed, SOUL_DEAL + c.x * 977 + c.y * 131)


## The places a soul may go: [the levels visited, the levels beside them (left and right) not
## visited], each sorted in the order souls go out in.
static func candidates(run: RunState, from: Vector2i) -> Array:
	var near: Array[Vector2i] = []
	var afar: Array[Vector2i] = []
	for c: Vector2i in run.records:
		if could_hold(c, from):
			near.append(c)
	for c: Vector2i in near:
		for side: Vector2i in [Vector2i(c.x - 1, c.y), Vector2i(c.x + 1, c.y)]:
			if not run.records.has(side) and could_hold(side, from) and not afar.has(side):
				afar.append(side)
	var by: Callable = func(a: Vector2i, b: Vector2i) -> bool:
		var ha: int = _order(run, a)
		var hb: int = _order(run, b)
		return ha < hb or (ha == hb and a < b)
	near.sort_custom(by)
	afar.sort_custom(by)
	return [near, afar]


## How many souls go out when `visited` levels have been visited.
static func count_for(visited: int) -> int:
	return clampi(ceili(float(visited) / float(SOULS_EVERY)), SOULS_MIN, SOULS_MOST)


## The beast woke in place `from` (its gate level): its souls go out (see the class description),
## unless they already have, or it is slain.
static func send(run: RunState, from: Vector2i) -> void:
	if run.souls_sent > 0 or run.bosses.has(&"beast"):
		return
	var lists: Array = candidates(run, from)
	var near: Array[Vector2i] = lists[0]
	var afar: Array[Vector2i] = lists[1]
	var n: int = count_for(near.size())
	@warning_ignore("integer_division")
	var far_n: int = mini(maxi(1, n / AFAR_EVERY), afar.size())
	var near_n: int = mini(n - far_n, near.size())
	# Too few visited levels: the rest go afar.
	far_n = mini(n - near_n, afar.size())
	for c: Vector2i in near.slice(0, near_n) + afar.slice(0, far_n):
		run.souls[c] = NO_SPOT
	run.souls_sent = run.souls.size()


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
