extends RisoProp
## A rock-bug nest (BugNest): a low mound of the rock's blue pebbles on the floor with a dark burrow
## in its front, pink eggs glinting inside it (danger), that swells and sheds grit while a bug
## hatches.

## How much it swells while a bug hatches.
const SWELL: float = 0.12


## Drawn about the middle of its cell, standing on the floor at the bottom of it.
func _draw_art() -> void:
	var nest: BugNest = host as BugNest
	if nest == null:
		return
	var f: float = 0.0 if nest.hatching < 0.0 else sin(nest.hatching / BugNest.HATCH * PI)
	var s: float = 1.0 + SWELL * f
	var floor_y: float = half
	var mound: Array[PackedVector2Array] = []
	for k: int in range(5):
		var x: float = (float(k) - 2.0) * 15.0 * s
		var r: float = (17.0 - absf(float(k) - 2.0) * 3.0) * s
		mound.append(RisoShapes.circle(Vector2(x, floor_y - r * 0.7), r, 16))
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.ACCENT], mound)
	ink.ink(RisoPrint.BLUE, 1.0, mound)
	ink.ink(RisoPrint.NIGHT, 0.3, [RisoShapes.rrect(-38.0 * s, floor_y - 10.0, 76.0 * s, 10.0, 4.0)], false)
	# The burrow, and the eggs in it.
	var hole: Array[PackedVector2Array] = [RisoShapes.ellipse(Vector2(0.0, floor_y - 12.0 * s), 14.0 * s, 10.0 * s, 16)]
	ink.knock([RisoPrint.BLUE], hole)
	ink.ink(RisoPrint.NIGHT, 0.9, hole, false)
	var eggs: Array[PackedVector2Array] = []
	for x: float in [-6.0, 1.0, 7.0]:
		eggs.append(RisoShapes.circle(Vector2(x * s, floor_y - 7.0 - absf(x) * 0.2), 3.2, 8))
	ink.ink(RisoPrint.PINK, 0.85 + 0.15 * f, eggs)
	if f > 0.0:
		var grit: Array[PackedVector2Array] = []
		for i: int in range(4):
			var g: float = fmod(t * 2.0 + float(i) * 0.25, 1.0)
			grit.append(RisoShapes.circle(Vector2((float(i) - 1.5) * 12.0, floor_y - 30.0 - g * 20.0), 2.2, 6))
		ink.ink(RisoPrint.NIGHT, 0.7, grit, false)
