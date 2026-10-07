extends RisoProp
## A laser set in the rock: warming, firing or resting. Always drawn (its beam reaches far).


## The Laser it dresses.
var laser: Laser:
	get:
		return host as Laser


## A laser set in the rock: a dark housing with a lens. Warming up, a thin flickering sight line
## runs out to the wall and the lens glows; firing, a broad pink beam with a bare-paper core, a
## flare at the lens and a splash where it strikes; resting, the lens goes dark.
func _draw_art() -> void:
	var dir: Vector2 = laser.dir
	var reach: float = laser.reach
	var state: Array = laser.phase()
	var u: float = float(state[1])
	var xf: Transform2D = Transform2D(dir.angle(), -dir * half)
	var muzzle: float = 30.0
	var housing: PackedVector2Array = xf * RisoShapes.rrect(-6.0, -20.0, 30.0, 40.0, 7.0)
	ink.ink(RisoPrint.BLUE, 1.0, [housing])
	ink.ink(RisoPrint.NIGHT, 0.45, [housing], false)
	ink.ink(RisoPrint.NIGHT, 0.8, [xf * RisoShapes.rrect(18.0, -13.0, 8.0, 26.0, 3.0)], false)
	var lens: PackedVector2Array = xf * RisoShapes.circle(Vector2(muzzle - 4.0, 0.0), 7.0, 16)
	var far: float = muzzle + reach
	match state[0]:
		&"warm":
			ink.ink(RisoPrint.PINK, 0.15 + 0.3 * u, [xf * RisoShapes.circle(Vector2(muzzle - 4.0, 0.0), 9.0 + 7.0 * u, 20)])
			ink.ink(RisoPrint.PINK, 1.0, [lens])
			if fmod(t * 18.0, 1.0) < 0.45 + 0.55 * u:
				ink.ink(RisoPrint.PINK, 0.3 + 0.4 * u, [xf * RisoShapes.rrect(muzzle, -1.2, reach, 2.4, 1.2)])
		&"fire":
			var s: float = clampf(minf(u, 1.0 - u) * 8.0, 0.0, 1.0)
			var w: float = 26.0 * (0.6 + 0.4 * s) * (1.0 + 0.06 * sin(t * 40.0))
			ink.ink(RisoPrint.PINK, 0.45 * s, [xf * RisoShapes.rrect(muzzle, -w * 0.85, reach, w * 1.7, w * 0.85)])
			ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.rrect(muzzle, -w * 0.5, reach, w, w * 0.5)])
			ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 0.9 * s, [xf * RisoShapes.rrect(muzzle, -w * 0.17, reach, w * 0.34, w * 0.17)])
			ink.ink(RisoPrint.PINK, 0.5 * s, [xf * RisoShapes.circle(Vector2(muzzle, 0.0), w * 1.3, 24), xf * RisoShapes.circle(Vector2(far, 0.0), w * 1.1, 24)])
			var splash: PackedVector2Array = xf * (Transform2D(t * 6.0, Vector2(far, 0.0)) * RisoShapes.sparkle(Vector2.ZERO, w * 0.9))
			ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 0.8 * s, [splash])
		_:
			ink.ink(RisoPrint.NIGHT, 0.6, [lens], false)

func culled() -> bool:
	return false
