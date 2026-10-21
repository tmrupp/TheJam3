extends RisoProp
## A grave mark (GraveMark): a small headstone in blue with a round top, a cross knocked out of it to
## paper, standing on the floor the wizard bound their soul to, with a soft glow of the wizard's own
## round it (glow belongs to the wizard) and a mote of it rising off the stone, pulsing slowly. It
## shines a little, to be found again in the dark (to the eye only).

## The headstone's size (px) and how high the mote rises over it, and how fast it pulses.
const STONE: Vector2 = Vector2(40.0, 56.0)
const MOTE_RISE: float = 26.0
const PULSE: float = 2.2


func shines() -> bool:
	return true


func light() -> Array:
	return _light(Vector2(0, -STONE.y * 0.6), RisoLight.SPARK, RisoPrint.BLUE)


func _draw_art() -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * PULSE + phase)
	# The glow round it, in the wizard's own ink.
	ink.ink(RisoPrint.GLOW, lerpf(0.18, 0.32, pulse), [RisoShapes.circle(Vector2(0, -STONE.y * 0.55), STONE.y * 0.95, 28)])
	# The stone: a round top on a slab, its foot on the floor.
	var top: Vector2 = Vector2(0, -STONE.y + STONE.x * 0.5)
	var stone: Array[PackedVector2Array] = [RisoShapes.circle(top, STONE.x * 0.5, 20), RisoShapes.rrect(-STONE.x * 0.5, top.y, STONE.x, STONE.y - STONE.x * 0.5, 2.0)]
	ink.knock([RisoPrint.GLOW], stone)
	ink.ink(RisoPrint.BLUE, 1.0, stone)
	ink.ink(RisoPrint.NIGHT, 0.35, [RisoShapes.rrect(-STONE.x * 0.5, -6.0, STONE.x, 6.0, 1.0)])
	# The cross, knocked out to paper.
	ink.knock([RisoPrint.BLUE, RisoPrint.NIGHT], [RisoShapes.rrect(-3.5, top.y - 9.0, 7.0, 30.0, 2.0), RisoShapes.rrect(-11.0, top.y - 1.5, 22.0, 7.0, 2.0)])
	# A mote of glow rising off it and fading as it goes.
	var u: float = fmod(t * 0.45 + phase, 1.0)
	var mote: PackedVector2Array = RisoShapes.sparkle(Vector2(sin(t * 1.7) * 4.0, -STONE.y - 6.0 - MOTE_RISE * u), lerpf(7.0, 3.0, u))
	ink.ink(RisoPrint.GLOW, sin(u * PI), [mote])
