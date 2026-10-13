extends CreatureArt
## A skeleton (Skeleton): bare bones lifted out of the dark to paper, shaded blue down one side.
## Asleep it lies along the floor of its niche, its eye sockets empty; rising, it swings up off the
## floor onto its feet; awake, it walks at the wizard with its arms reaching out ahead, pink points
## burning in its sockets.

## The bones are drawn standing, feet at the floor and the skull TALL over it (in art units, SCALE
## px each), then laid down or stood up (see _draw_art).
const TALL: float = 52.0
const SCALE: float = 1.8
## How far its legs swing (radians) and how many px of walking a full stride takes.
const SWING: float = 0.45
const STRIDE: float = 38.0


func _draw_art() -> void:
	var sk: Skeleton = host.get_node_or_null("Skeleton") as Skeleton
	var facing: float = sk.facing if sk != null else 1.0
	var asleep: bool = sk == null or sk.asleep
	var up: float = 1.0
	if asleep:
		up = 0.0
	elif sk.rising > 0.0:
		var k: float = 1.0 - sk.rising / Skeleton.RISE
		up = k * k * (3.0 - 2.0 * k)
	var g: float = _ground()
	# Lying, it lies along the floor, its skull the way it faces; standing, it is upright on its feet.
	var lying: Transform2D = Transform2D(PI * 0.5 * facing, Vector2.ONE, 0.0, Vector2(-TALL * 0.5 * SCALE * facing, g - 10.0 * SCALE))
	var angle: float = lerpf(PI * 0.5 * facing, 0.0, up)
	var at: Vector2 = lying.origin.lerp(Vector2(0, g), up)
	var xf: Transform2D = Transform2D(angle, Vector2(facing, 1.0) * SCALE, 0.0, at)
	var stride: float = sin((sk.walked if sk != null else 0.0) / STRIDE * PI) * SWING * up
	var reach: float = lerpf(0.2, 1.35, up) if not asleep else 0.15
	var bones: Array[PackedVector2Array] = []
	# Legs from the hip, swinging opposite each other as it walks.
	for side: float in [-1.0, 1.0]:
		var leg: Transform2D = Transform2D(stride * side, Vector2(side * 3.0, -20.0))
		bones.append(xf * (leg * RisoShapes.rrect(-1.6, 0.0, 3.2, 20.0, 1.6)))
		bones.append(xf * (leg * RisoShapes.rrect(-1.0, 18.0, 6.0, 3.0, 1.5)))
	# The pelvis, the spine and the ribs.
	bones.append(xf * RisoShapes.rrect(-7.0, -24.0, 14.0, 5.0, 2.5))
	bones.append(xf * RisoShapes.rrect(-1.5, -42.0, 3.0, 20.0, 1.5))
	for i: int in range(3):
		var y: float = -38.0 + float(i) * 4.5
		var w: float = 18.0 - float(i) * 2.5
		bones.append(xf * RisoShapes.rrect(-w * 0.5, y, w, 2.6, 1.3))
	# Arms from the shoulders, reaching out ahead (forward) as it walks at the wizard.
	for side: float in [-1.0, 1.0]:
		var sway: float = sin(t * 3.0 + phase + side) * 0.08 * up
		var arm: Transform2D = Transform2D(-reach + sway + side * 0.08, Vector2(side * 2.0, -40.0))
		bones.append(xf * (arm * RisoShapes.rrect(-1.4, 0.0, 2.8, 18.0, 1.4)))
	# The skull and its jaw.
	var skull: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(1.0, -TALL + 4.0), 7.5, 7.0, 18)
	var jaw: PackedVector2Array = xf * RisoShapes.rrect(-3.0, -TALL + 9.0, 9.0, 4.0, 1.5)
	bones.append(skull)
	bones.append(jaw)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.9, bones)
	# Shaded blue down its back.
	ink.ink(RisoPrint.BLUE, 0.22, [xf * RisoShapes.rrect(-9.0, -TALL - 4.0, 6.0, TALL + 4.0, 3.0)], false)
	# The eye sockets: dark hollows; awake, a pink point burns in each.
	var sockets: Array[PackedVector2Array] = []
	var points: Array[PackedVector2Array] = []
	for e: Vector2 in [Vector2(0.5, -TALL + 3.0), Vector2(5.0, -TALL + 3.0)]:
		sockets.append(xf * RisoShapes.circle(e, 1.9, 10))
		points.append(xf * RisoShapes.circle(e, 1.0 + 0.2 * sin(t * 9.0 + phase), 8))
	ink.ink(RisoPrint.NIGHT, 0.9, sockets, false)
	if not asleep:
		ink.ink(RisoPrint.PINK, 0.35 * up, [xf * RisoShapes.ellipse(Vector2(2.7, -TALL + 3.0), 4.5, 2.8, 14)])
		ink.ink(RisoPrint.PINK, up, points)
