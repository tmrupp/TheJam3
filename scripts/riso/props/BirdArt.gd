extends CreatureArt
## A swooping bird: a pink swallow beating its wings, swept back as it dives.


## A swooping bird (Bird): a pink swallow, its body an almond with a forked tail and a paper eye,
## its wings beating as it patrols and swept back as it swoops, a soft pink trail behind the dive.
## Before a dive it warns: it rears with its wings flared high and shivering, its paper eye wide, a
## pink screech fanning from its beak, and a pink mark tightening on the spot it will dive through.
## Stunned, its wings hang and stars circle it.
func _draw_art() -> void:
	var b: Bird = host.get_node_or_null("Bird") as Bird
	var facing: float = b.facing if b != null else 1.0
	var stunned: bool = b.stunned if b != null else false
	var diving: bool = b != null and b.swooping()
	var warn: float = b.tell if b != null and b.telling() else -1.0
	var vel: Vector2 = b.velocity if b != null else Vector2.ZERO
	var pitch: float = clampf(vel.y / 600.0, -0.7, 0.7) * (1.0 if not diving else 1.3)
	if warn >= 0.0:
		pitch = -0.45 * minf(1.0, warn * 3.0)
		_warn_mark(b, warn)
	var xf: Transform2D = Transform2D(pitch * facing, Vector2(facing, 1.0) * 2.4, 0.0, Vector2(0, -8 + (0.0 if diving else sin(t * 3.0 + phase) * 3.0)))
	var body: PackedVector2Array = xf * RisoShapes.almond(Vector2.ZERO, 13.0, 5.0, 12)
	var tail: PackedVector2Array = xf * PackedVector2Array([Vector2(-9, -1), Vector2(-21, -7), Vector2(-16, 0), Vector2(-21, 6), Vector2(-9, 2)])
	# Wings: long swept blades hinged at the shoulder, beating up and down about it (the far one a
	# little behind and darker); in the dive, folded tight back along the body.
	var beat: float = sin(t * 12.0 + phase)
	# Up to near upright on the upstroke, well below the body on the down.
	var near_lift: float = 0.3 if diving else (-0.3 if stunned else 0.6 + 0.95 * beat)
	var far_lift: float = 0.2 if diving else (-0.4 if stunned else 0.5 + 0.85 * sin(t * 12.0 + phase - 0.6))
	if warn >= 0.0:
		# Flared high and shivering.
		near_lift = 1.45 + sin(t * 70.0) * 0.08
		far_lift = 1.3 + sin(t * 70.0 + 1.0) * 0.08
	var reach: float = 16.0 if diving else 25.0
	var wings: Array[PackedVector2Array] = [xf * _wing(Vector2(3, -1), far_lift, reach * 0.9), xf * _wing(Vector2(1, -1), near_lift, reach)]
	if diving:
		var trail: Array[PackedVector2Array] = []
		for k: int in range(3):
			trail.append(RisoShapes.circle(-vel.normalized() * (26.0 + 18.0 * float(k)), 6.0 - 1.5 * float(k), 10))
		ink.ink(RisoPrint.PINK, 0.25, trail)
	ink.ink(RisoPrint.PINK, 1.0, [wings[0]])
	ink.ink(RisoPrint.NIGHT, 0.45, [wings[0]], false)
	ink.ink(RisoPrint.PINK, 1.0, [body, tail])
	ink.ink(RisoPrint.PINK, 1.0, [wings[1]])
	ink.ink(RisoPrint.NIGHT, 0.15, [wings[1]], false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE], [xf * RisoShapes.circle(Vector2(7, -1.2), 2.4 if warn >= 0.0 else 1.6, 8)])
	if warn >= 0.0:
		# The screech: three pink wedges fanning from the beak, growing as the warning runs.
		var fan: Array[PackedVector2Array] = []
		var cry: float = 6.0 + 10.0 * minf(1.0, warn * 2.0)
		for k: int in range(3):
			var a: float = (float(k) - 1.0) * 0.45
			var d: Vector2 = Vector2(cos(a), sin(a))
			var side: Vector2 = d.orthogonal() * 1.4
			fan.append(xf * PackedVector2Array([Vector2(19, 0) + d * 2.0 + side, Vector2(19, 0) + d * cry, Vector2(19, 0) + d * 2.0 - side]))
		ink.ink(RisoPrint.PINK, 1.0, fan)
	ink.ink(RisoPrint.ACCENT, 1.0, [xf * PackedVector2Array([Vector2(12, -1), Vector2(17, 0.5), Vector2(12, 1.5)])], false)
	if stunned:
		_stun_mark(xf * Vector2(0, -12))


## The spot the dive will go through: a pink disc tightening to a bright point as the dive nears.
func _warn_mark(b: Bird, warn: float) -> void:
	var at: Vector2 = to_local(b.mark)
	var r: float = lerpf(46.0, 16.0, warn)
	ink.ink(RisoPrint.PINK, 0.18 + 0.12 * warn, [RisoShapes.circle(at, r, 28)])
	ink.ink(RisoPrint.PINK, 0.6 + 0.4 * warn, [RisoShapes.circle(at, 5.0 + 3.0 * warn, 14)])


## A swallow's wing hinged at `shoulder` (bird units, facing right): a blade swept back from it,
## `reach` long, lifted `lift` radians above straight back (negative, below), with a curved leading
## edge and a thinner trailing one.
static func _wing(shoulder: Vector2, lift: float, reach: float) -> PackedVector2Array:
	var along: Vector2 = Vector2(-cos(lift), -sin(lift))
	var out: Vector2 = Vector2(along.y, -along.x)
	if out.y > 0.0:
		out = -out
	var tip: Vector2 = shoulder + along * reach
	# Broad at the root (the shoulder along the back), narrowing to a pointed tip.
	return RisoShapes.smooth(PackedVector2Array([shoulder + Vector2(5, 0), shoulder + along * reach * 0.4 + out * 6.0, tip, shoulder + along * reach * 0.6 - out * 1.5, shoulder + Vector2(-6, 1)]), 3)
