extends RisoProp
## A boss's trophy (Trophy), waiting where its boss fell, and a trophy stand in the tutorial
## (TrophyStand), with the trophy on it once it is set. Each shows its boss's mark
## (RisoMarks.boss_mark): on the trophy's gold, and, on an empty stand, faint where its trophy will
## go, so each stand says whose it is. No words.

## How high over the ground a trophy floats on its stand, and how far it bobs (world pixels).
const OVER: float = 86.0
const BOB: float = 4.0
## A trophy's radius; and the faint disc an empty stand shows where its trophy will go: how far the
## night is lifted from it and how much accent it takes, and how much more of each it pulses with
## while the wizard carries that trophy; and how strongly its boss's mark is printed on it.
const R: float = 30.0
const EMPTY_LIFT: float = 0.3
const EMPTY_INK: float = 0.25
const AWAIT_LIFT: float = 0.4
const AWAIT_INK: float = 0.5
const EMPTY_MARK: float = 0.8


func shines() -> bool:
	return true


## A trophy lights the ground round it, on a stand or waiting; an empty stand is dark.
func light() -> Array:
	if kind == &"trophystand":
		var stand: TrophyStand = host as TrophyStand
		if stand == null or not stand.is_set():
			return []
		return _light(Vector2(0, _ground() - OVER), RisoLight.GLEAM, RisoPrint.ACCENT)
	return _light(Vector2.ZERO, RisoLight.GLEAM, RisoPrint.ACCENT)


## Waiting, the trophy floats in its own light with two motes circling it. On a stand: a plinth,
## the trophy floating over it once set, else a faint accent disc where it will go with its boss's
## mark on it (pulsing brighter while the wizard carries it).
func _draw_art() -> void:
	var bob: float = sin(t * 2.0 + phase) * BOB
	if kind == &"trophy":
		var trophy: Trophy = host as Trophy
		_trophy(Vector2(0, bob), trophy.boss if trophy != null else &"")
		return
	var stand: TrophyStand = host as TrophyStand
	var boss: StringName = stand.boss if stand != null else &""
	var g: float = _ground()
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-30, g - 20, 60, 20, 6)])
	ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.rrect(-20, g - 28, 40, 10, 4)])
	var c: Vector2 = Vector2(0, g - OVER + bob)
	if stand != null and stand.is_set():
		_trophy(c, boss)
	else:
		var glow: float = 0.5 + 0.5 * sin(t * 4.0) if stand != null and stand.awaited() else 0.0
		var disc: PackedVector2Array = RisoShapes.circle(c, R, 28)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], EMPTY_LIFT + AWAIT_LIFT * glow, [disc])
		ink.ink(RisoPrint.ACCENT, EMPTY_INK + AWAIT_INK * glow, [disc], false)
		# Its boss's mark, the ground lifted to paper through it (a dark mark on the dim disc would
		# screen away); its holes are the disc again.
		var mark: Array = RisoMarks.boss_mark(boss, c, R * RisoMarks.BOSS_MARK)
		ink.lift_ink(RisoPrint.ALL_PLATES, EMPTY_MARK, mark[0])
		if not (mark[1] as Array).is_empty():
			ink.ink(RisoPrint.ACCENT, EMPTY_INK + AWAIT_INK * glow, mark[1], false)
		if not (mark[2] as Array).is_empty():
			ink.lift_ink(RisoPrint.ALL_PLATES, EMPTY_MARK, mark[2])


## The trophy of `boss` at `c`, with two motes circling it.
func _trophy(c: Vector2, boss: StringName) -> void:
	RisoMarks.trophy(ink, c, R * (1.0 + 0.05 * sin(t * 3.0 + phase)), 1.0, boss)
	var motes: Array[PackedVector2Array] = []
	for k: int in range(2):
		var ang: float = t * 1.4 + PI * float(k)
		motes.append(RisoShapes.sparkle(c + Vector2(cos(ang) * 46.0, sin(ang) * 16.0), 7.0))
	ink.ink(RisoPrint.ACCENT, 1.0, motes, false)
