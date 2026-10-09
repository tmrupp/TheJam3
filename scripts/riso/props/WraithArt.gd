extends CreatureArt
## A wraith: a pale shroud streaming behind it, its eyes lit while it chases.


## A wraith: a pale shroud floating over a tattered hem that streams behind it, a dark hood with
## two pink eyes. Paper lifted out of whatever is behind it, so it reads over the night and, fainter,
## as a pale shape inside rock (where it can pass).
func _draw_art() -> void:
	var w: Wraith = host.get_node_or_null("Wraith") as Wraith
	var facing: float = w.facing if w != null else 1.0
	var stunned: bool = w.stunned if w != null else false
	var in_rock: bool = w.in_rock() if w != null else false
	var vel: Vector2 = w.velocity if w != null else Vector2.ZERO
	var bob: float = sin(t * 2.0 + phase) * 6.0
	var lean: float = clampf(vel.x / 200.0, -1.0, 1.0) * 0.18
	var xf: Transform2D = Transform2D(lean, Vector2(facing, 1.0) * 2.6, 0.0, Vector2(0, -10 + bob))
	# The shroud: a hood narrowing to the shoulders, widening to a ragged hem that waves.
	var outline: PackedVector2Array = PackedVector2Array([Vector2(0, -34), Vector2(9, -31), Vector2(13, -22), Vector2(12, -10), Vector2(16, 4), Vector2(19, 18)])
	for k: int in range(6):
		var x: float = 19.0 - float(k) * 7.6
		var wave: float = sin(t * 5.0 + float(k) * 1.3 + phase) * 3.0
		outline.append(Vector2(x - 3.8, 24.0 + wave + (5.0 if k % 2 == 0 else 0.0)))
	outline.append_array(PackedVector2Array([Vector2(-19, 18), Vector2(-16, 4), Vector2(-12, -10), Vector2(-13, -22), Vector2(-9, -31)]))
	# Like cloth, the shroud streams back from the way it drifts, more the lower down: the hood
	# leads, the hem trails (in its own facing's units, before the turn).
	var drag: Vector2 = Vector2(-absf(vel.x), -vel.y) / 95.0 * 7.0
	for k: int in range(outline.size()):
		var low: float = clampf((outline[k].y + 30.0) / 56.0, 0.0, 1.0)
		outline[k] += drag * low * low
	var shroud: PackedVector2Array = xf * RisoShapes.smooth(outline, 2)
	var lift: float = 0.45 if in_rock else 0.85
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], lift, [shroud])
	ink.ink(RisoPrint.BLUE, 0.18, [shroud], false)
	var hood: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(2, -20), 7.5, 8.5, 16)
	ink.ink(RisoPrint.NIGHT, 0.9 if not in_rock else 0.5, [hood], false)
	# Its eyes: dim hollows while it hangs waiting; lit pink, glowing, while it chases.
	var chasing: bool = w != null and w.awake and not stunned
	var eyes: Array[PackedVector2Array] = []
	var glows: Array[PackedVector2Array] = []
	for e: Vector2 in [Vector2(0, -21), Vector2(6, -21)]:
		var eye: PackedVector2Array = RisoShapes.ellipse(e, 1.5, 2.1, 10)
		if chasing:
			eye = RisoShapes.circle(e, 2.1, 16)
		elif stunned:
			eye = RisoShapes.rrect(e.x - 1.6, e.y - 0.3, 3.2, 0.6, 0.3, 2)
		eyes.append(xf * eye)
		glows.append(xf * RisoShapes.circle(e, 3.6 + 0.5 * sin(t * 8.0 + phase), 12))
	if chasing:
		# Lit: the pink lifts the hood's night under it, so it shines out of the dark.
		ink.ink(RisoPrint.PINK, 0.45, glows)
		ink.ink(RisoPrint.PINK, 1.0, eyes)
	else:
		ink.ink(RisoPrint.BLUE, 0.6, eyes, false)
	if stunned:
		_stun_mark(xf * Vector2(0, -44))
