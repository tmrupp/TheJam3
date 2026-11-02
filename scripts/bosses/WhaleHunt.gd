class_name WhaleHunt
extends RefCounted
## The hunt for the whale (the sky's boss, docs/REGIONS_PLAN.md §6), apart from the scene: one
## whale, on the sky's top row (row()), in one world at a time (RunState.whale_x). It is met (placed,
## start) the first time the wizard comes into a sky level, a few worlds off; after that, each time
## the wizard comes into a sky level it moves (move): held where it is if it is trapped (trapped:
## the levels either side of its own set to blow into it, at least TRAP strong, by their vanes);
## else a world on the way its own level's wind is set to blow (Rules.wind_of), or, where that is
## still, a world either way or none, by a hash of the run and how often it has moved; and never
## more than REACH worlds from the wizard's. Its winds are the ones the vanes are set to, not the
## gusts of the moment. Nothing here draws from any RNG.

## No whale met yet (RunState.whale_x).
const NONE: int = -999999999
## The most worlds it strays from the wizard's, and the wind (each side) that holds it.
const REACH: int = 3
const TRAP: int = 1
## Salts for the run seed: where it is first met, and where it wanders.
const MEET_DEAL: int = 7700
const WANDER_DEAL: int = 7710


## The row it swims: the sky's top row, its gate row.
static func row() -> int:
	return Bosses.row_of(&"whale")


## Whether row `r` is a sky level's (the whale hunts the wizard there).
static func in_sky(r: int) -> bool:
	return NextWorldDef.archetype_at(r) == &"sky"


## The wind its vanes set level `at` of run `run` to (Rules.wind_of), 0 for a level never visited.
static func wind_at(run: RunState, at: Vector2i) -> int:
	return Rules.wind_of(run.records.get(at) as LevelRecord)


## Whether the whale in world `x` is trapped: the level on its left set to blow right into its
## level, and the one on its right set to blow left into it, each at least TRAP strong.
static func trapped(run: RunState, x: int) -> bool:
	return wind_at(run, Vector2i(x - 1, row())) >= TRAP and wind_at(run, Vector2i(x + 1, row())) <= -TRAP


## Meet the whale, if it is not met yet: a world off the wizard's (`wizard`, their place), one to
## REACH either way, by the run seed.
static func start(run: RunState, wizard: Vector2i) -> void:
	if run.whale_x != NONE:
		return
	var h: int = posmod(Rules.level_seed(run.run_seed, MEET_DEAL), 2 * REACH)
	var off: int = h - REACH + (1 if h >= REACH else 0)
	run.whale_x = wizard.x + off


## The wizard came into place `wizard`: the whale moves (see the class description), unless it is
## slain, or the place is not a sky level. Returns whether it moved.
static func move(run: RunState, wizard: Vector2i) -> bool:
	if run.bosses.has(&"whale") or Worlds.is_side(wizard) or not in_sky(wizard.y):
		return false
	if run.whale_x == NONE:
		start(run, wizard)
		return true
	var x: int = run.whale_x
	if not trapped(run, x):
		var wind: int = wind_at(run, Vector2i(x, row()))
		if wind != 0:
			x += signi(wind)
		else:
			x += posmod(Rules.level_seed(run.run_seed, WANDER_DEAL + run.whale_moves), 3) - 1
	x = clampi(x, wizard.x - REACH, wizard.x + REACH)
	var moved: bool = x != run.whale_x
	run.whale_x = x
	run.whale_moves += 1
	return moved


## Whether the whale is in place `at` now (its world, on its row), alive.
static func here(run: RunState, at: Vector2i) -> bool:
	return not run.bosses.has(&"whale") and run.whale_x != NONE and at == Vector2i(run.whale_x, row())
