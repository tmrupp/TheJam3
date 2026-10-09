extends RisoProp
## A moon (a dash reset): a crescent that drops to a sliver when used and waxes back.


## The Moon it dresses.
var moon: Moon:
	get:
		return host as Moon


## A moon: a crescent in accent ink inside a soft halo, rocking as it floats. The moment the
## wizard touches it, it drops to a faint sliver (spent) until they leave, then grows back as it
## waxes.
func _draw_art() -> void:
	var full: float = 0.0 if moon.in_use else 1.0 - clampf(moon.waning / 2.5, 0.0, 1.0)
	var o: Vector2 = Vector2(0, sin(t * 2.2 + phase) * 6.0)
	var k: float = lerpf(0.55, 1.0, full)
	var crescent: PackedVector2Array = Transform2D(sin(t) * 0.25, Vector2(k, k), 0.0, o) * RisoShapes.crescent(Vector2.ZERO, 22.0, Vector2(10, -5))
	if full >= 1.0:
		ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(o, 34.0, 28)])
		ink.ink(RisoPrint.ACCENT, 1.0, [crescent])
		ink.ink(RisoPrint.BLUE, 0.5, [crescent])
	else:
		ink.ink(RisoPrint.ACCENT, 0.3 * full + 0.1, [crescent])
