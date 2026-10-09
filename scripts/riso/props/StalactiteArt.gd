extends RisoProp
## A falling stalactite (Stalactite): a spike of the rock's own stone hanging from the ceiling,
## shaded down one side, a paper gleam down the other, its lower part pink (danger) while it can
## fall, and hairline cracks in the ceiling round its root. It shakes, shedding grit, before it
## falls; once it has shattered it grows back from the ceiling in plain stone (harmless), and turns
## pink again once it hangs whole.

## How far it shakes either way before it falls (pixels) and how fast (radians a second).
const SHAKE_X: float = 2.5
const SHAKE_RATE: float = 70.0
## How much of it, from the tip, is pink while it can fall.
const PINK_SHARE: float = 0.42


## The Stalactite it dresses.
var stal: Stalactite:
	get:
		return host as Stalactite


## Drawn from its root on the ceiling (this node's origin) down.
func _draw_art() -> void:
	if stal == null:
		return
	var g: float = stal.grown()
	var long: float = Stalactite.LENGTH * g
	var wide: float = Stalactite.WIDE * (0.45 + 0.55 * g)
	var armed: bool = stal.state != Stalactite.State.REGROWING
	var x: float = sin(t * SHAKE_RATE) * SHAKE_X if stal.state == Stalactite.State.SHAKING else 0.0
	# The cracks in the ceiling round its root, while it still hangs there.
	if stal.drop <= 0.0:
		var cracks: Array[PackedVector2Array] = []
		for side: float in [-1.0, 1.0]:
			cracks.append_array(RisoDecor.strip(PackedVector2Array([Vector2(side * wide * 0.45, -2.0), Vector2(side * wide * 0.8, -7.0), Vector2(side * wide * 1.1, -6.0)]), 1.6, 0.8))
		ink.ink(RisoPrint.NIGHT, 0.6, cracks, false)
	if long < 2.0:
		return
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(x - wide * 0.5, -4.0), Vector2(x + wide * 0.5, -4.0), Vector2(x + wide * 0.34, long * 0.32),
		Vector2(x + wide * 0.14, long * 0.72), Vector2(x, long), Vector2(x - wide * 0.1, long * 0.68),
		Vector2(x - wide * 0.3, long * 0.3)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.ACCENT], [body])
	ink.ink(RisoPrint.BLUE, 1.0 if armed else 0.7, [body])
	ink.ink(RisoPrint.NIGHT, 0.35, [PackedVector2Array([Vector2(x + wide * 0.08, -4.0), Vector2(x + wide * 0.5, -4.0), Vector2(x + wide * 0.34, long * 0.32), Vector2(x + wide * 0.14, long * 0.72), Vector2(x, long)])], false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], RisoDecor.strip(PackedVector2Array([Vector2(x - wide * 0.24, 4.0), Vector2(x - wide * 0.17, long * 0.4)]), 2.4, 1.0))
	if armed:
		# Its lower part, pink: the part that falls on you.
		var from: float = long * (1.0 - PINK_SHARE)
		var band: PackedVector2Array = PackedVector2Array([Vector2(x - wide, from), Vector2(x + wide, from), Vector2(x + wide, long + 4.0), Vector2(x - wide, long + 4.0)])
		var tips: Array[PackedVector2Array] = Geometry2D.intersect_polygons(body, band)
		if not tips.is_empty():
			ink.knock([RisoPrint.BLUE], tips)
			ink.ink(RisoPrint.PINK, 1.0, tips)
	if stal.state == Stalactite.State.SHAKING:
		# Grit falling from its root as it works loose.
		var grit: Array[PackedVector2Array] = []
		for i: int in range(4):
			var f: float = fmod(t * 1.6 + float(i) * 0.27, 1.0)
			grit.append(RisoShapes.circle(Vector2((float(i) - 1.5) * wide * 0.4, f * 40.0), 2.2, 6))
		ink.ink(RisoPrint.NIGHT, 0.7, grit, false)
