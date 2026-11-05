extends RisoProp
## A boss's trophy (Trophy), waiting where its boss fell, and a trophy stand in the tutorial
## (TrophyStand), with the trophy on it once it is set.

## How high over the ground a trophy floats on its stand, and how far it bobs (world pixels).
const OVER: float = 86.0
const BOB: float = 4.0
## A trophy's radius; and the faint disc an empty stand shows where its trophy will go: how far the
## night is lifted from it and how much accent it takes, and how much more of each it pulses with
## while the wizard carries that trophy.
const R: float = 30.0
const EMPTY_LIFT: float = 0.3
const EMPTY_INK: float = 0.25
const AWAIT_LIFT: float = 0.4
const AWAIT_INK: float = 0.5
## How far its name pops up over a stand.
const NAME_Y: float = 150.0


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
## the trophy floating over it once set, else a faint accent disc where it will go (pulsing brighter
## while the wizard carries it), and the boss's name popping up as the wizard steps up to it.
func _draw_art() -> void:
	var bob: float = sin(t * 2.0 + phase) * BOB
	if kind == &"trophy":
		_trophy(Vector2(0, bob))
		return
	var stand: TrophyStand = host as TrophyStand
	var g: float = _ground()
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-30, g - 20, 60, 20, 6)])
	ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.rrect(-20, g - 28, 40, 10, 4)])
	var c: Vector2 = Vector2(0, g - OVER + bob)
	if stand != null and stand.is_set():
		_trophy(c)
	else:
		var glow: float = 0.5 + 0.5 * sin(t * 4.0) if stand != null and stand.awaited() else 0.0
		var disc: PackedVector2Array = RisoShapes.circle(c, R, 28)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], EMPTY_LIFT + AWAIT_LIFT * glow, [disc])
		ink.ink(RisoPrint.ACCENT, EMPTY_INK + AWAIT_INK * glow, [disc], false)
	var sl: float = _pop(0, Vector2(0, g - 50))
	if sl > 0.0 and stand != null:
		_plaque(String(stand.boss), Vector2(0, g - NAME_Y), 24, RisoPrint.ACCENT if stand.is_set() else RisoPrint.BLUE, sl)


## The trophy at `c`, with two motes circling it.
func _trophy(c: Vector2) -> void:
	RisoMarks.trophy(ink, c, R * (1.0 + 0.05 * sin(t * 3.0 + phase)))
	var motes: Array[PackedVector2Array] = []
	for k: int in range(2):
		var ang: float = t * 1.4 + PI * float(k)
		motes.append(RisoShapes.sparkle(c + Vector2(cos(ang) * 46.0, sin(ang) * 16.0), 7.0))
	ink.ink(RisoPrint.ACCENT, 1.0, motes, false)
