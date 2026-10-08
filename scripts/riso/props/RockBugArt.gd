extends CreatureArt
## A rock-bug (RockBug): a little pink mite carrying a grey pebble on its back, one paper eye at its
## front and a row of little feet that ripple while it walks, its back turned away from whatever it
## clings to (rock, a gondola's cable), tumbling as it falls.

## How fast its feet ripple while it walks (radians a second), and how high a foot lifts (pixels).
const STEP_RATE: float = 16.0
const STEP: float = 2.5
## Its feet: how many, how far apart and how big (pixels).
const FEET: int = 4
const FOOT_GAP: float = 10.0
const FOOT: float = 3.0


## Drawn in pixels about its middle: +x the way it walks, +y toward what it clings to (RockBug.BODY
## pixels away, where its feet are), all turned so its back faces `up`. A low pink body and head, its
## feet under them, and a grey pebble over its back (knocked clear of the pink, blue with a night
## shade under its crown).
func _draw_art() -> void:
	var bug: RockBug = host.get_node_or_null("RockBug") as RockBug
	var up: Vector2 = bug.up if bug != null else Vector2.UP
	var walking: bool = bug != null and bug.walking and not bug.stunned
	# Its head leads the way it moves.
	var turn: float = up.angle() + PI * 0.5
	var facing: float = 1.0
	if bug != null and Vector2.RIGHT.rotated(turn).dot(bug.heading) < 0.0:
		facing = -1.0
	var xf: Transform2D = Transform2D(turn, Vector2(facing, 1.0), 0.0, Vector2.ZERO)
	var tick: float = t * STEP_RATE if walking else 0.0
	var body: Array[PackedVector2Array] = [
		xf * RisoShapes.ellipse(Vector2(-1.0, 4.0), 19.0, 7.0, 18),
		xf * RisoShapes.circle(Vector2(16.0, 2.0), 7.0, 14),
	]
	for k: int in range(FEET):
		var lift: float = maxf(0.0, sin(tick + float(k) * PI * 0.5)) * STEP
		var x: float = (float(k) - float(FEET - 1) * 0.5) * FOOT_GAP
		body.append(xf * RisoShapes.circle(Vector2(x, RockBug.BODY - FOOT - lift), FOOT, 8))
	ink.ink(RisoPrint.PINK, 1.0, body)
	var stone: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(-4.0, -5.0), 17.0, 12.0, 18, -0.15)
	ink.knock([RisoPrint.PINK], [stone])
	ink.ink(RisoPrint.BLUE, 1.0, [stone])
	ink.ink(RisoPrint.NIGHT, 0.35, [xf * RisoShapes.ellipse(Vector2(-2.0, -1.0), 14.0, 7.0, 14, -0.15)], false)
	# Its eye: paper with a night pupil looking ahead.
	var eye: Vector2 = Vector2(18.0, 1.0)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], [xf * RisoShapes.circle(eye, 3.0, 12)])
	ink.ink(RisoPrint.NIGHT, 1.0, [xf * RisoShapes.circle(eye + Vector2(1.2, 0.0), 1.5, 8)], false)
	if bug != null and bug.stunned:
		_stun_mark(xf * Vector2(0.0, -28.0))
