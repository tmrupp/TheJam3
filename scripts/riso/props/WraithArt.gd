extends CreatureArt
## A wraith: a pale shroud streaming behind it, its eyes lit while it chases; frozen in light, it
## cowers, drawn in and shivering, its eyes shut. About to dart (Wraith.DART_RANGE) it swells, its
## hem flaring wide and whipping, its hood darkening and its eyes burning bigger, shivering; darting,
## it stretches out along the way it goes.

## Swelling to dart: how much bigger it grows, how much wider and faster its hem waves, how far it
## shivers (art units), and how much bigger its eyes burn (their glow deepens, keeping its size). Darting: how far it stretches along its
## way and narrows across it, at full speed.
const SWELL_GROW: float = 0.22
const SWELL_HEM: float = 2.5
const SWELL_SHIVER: float = 1.2
const SWELL_EYES: float = 0.25
const DART_STRETCH: float = 0.25


## A wraith: a pale shroud floating over a tattered hem that streams behind it, a dark hood with
## two pink eyes. Paper lifted out of whatever is behind it, so it reads over the night and, fainter,
## as a pale shape inside rock (where it can pass).
func _draw_art() -> void:
	var w: Wraith = host.get_node_or_null("Wraith") as Wraith
	var facing: float = w.facing if w != null else 1.0
	var stunned: bool = w.stunned if w != null else false
	var in_rock: bool = w.in_rock() if w != null else false
	var vel: Vector2 = w.velocity if w != null else Vector2.ZERO
	var shy: bool = w.shy if w != null else false
	var swell: float = smoothstep(0.0, 1.0, w.swelling) if w != null and w.swelling >= 0.0 else 0.0
	var dart: float = 1.0 - w.darting if w != null and w.darting >= 0.0 else 0.0
	var bob: float = sin(t * 2.0 + phase) * 6.0 * (1.0 - swell)
	if shy:
		# Cowering in the light: still, drawn in, a quick shiver.
		bob = sin(t * 31.0 + phase) * 1.2
	var lean: float = clampf(vel.x / 200.0, -1.0, 1.0) * 0.18
	var size: Vector2 = Vector2(facing, 1.0) * 2.6 * (Vector2(0.86, 0.92) if shy else Vector2.ONE) * (1.0 + SWELL_GROW * swell)
	var shiver: Vector2 = Vector2(sin(t * 47.0 + phase), cos(t * 41.0 + phase)) * SWELL_SHIVER * 2.6 * swell
	var xf: Transform2D = Transform2D(lean, size, 0.0, Vector2(0, -10 + bob) + shiver)
	if dart > 0.0 and vel.length() > 1.0:
		# Darting: stretched out along the way it goes, about its middle.
		var along: Vector2 = vel.normalized()
		var stretch: Transform2D = Transform2D(along * (1.0 + DART_STRETCH * dart), along.orthogonal() * (1.0 - DART_STRETCH * 0.5 * dart), Vector2.ZERO)
		var turn: Transform2D = Transform2D(along, along.orthogonal(), Vector2.ZERO).affine_inverse()
		xf = stretch * turn * xf
	# The shroud: a hood narrowing to the shoulders, widening to a ragged hem that waves.
	var outline: PackedVector2Array = PackedVector2Array([Vector2(0, -34), Vector2(9, -31), Vector2(13, -22), Vector2(12, -10), Vector2(16, 4), Vector2(19, 18)])
	for k: int in range(6):
		var x: float = 19.0 - float(k) * 7.6
		# Swelling, the hem flares out wider and whips faster.
		var wave: float = sin(t * (5.0 + 9.0 * swell) + float(k) * 1.3 + phase) * 3.0 * (1.0 + SWELL_HEM * swell)
		var flare: float = (x - 3.8) * (1.0 + 0.3 * swell)
		outline.append(Vector2(flare, 24.0 + wave + (5.0 if k % 2 == 0 else 0.0)))
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
	ink.ink(RisoPrint.NIGHT, (0.9 if not in_rock else 0.5) + 0.1 * swell, [hood], false)
	# Its eyes: dim hollows while it hangs waiting; lit pink, glowing, while it chases.
	var chasing: bool = w != null and w.awake and not stunned and not shy
	var eyes: Array[PackedVector2Array] = []
	var glows: Array[PackedVector2Array] = []
	for e: Vector2 in [Vector2(0, -21), Vector2(6, -21)]:
		var eye: PackedVector2Array = RisoShapes.ellipse(e, 1.5, 2.1, 10)
		if chasing:
			eye = RisoShapes.circle(e, 2.1 * (1.0 + SWELL_EYES * swell), 16)
		elif stunned or shy:
			eye = RisoShapes.rrect(e.x - 1.6, e.y - 0.3, 3.2, 0.6, 0.3, 2)
		eyes.append(xf * eye)
		glows.append(xf * RisoShapes.circle(e, 3.6 + 0.5 * sin(t * 8.0 + phase), 12))
	if chasing:
		# Lit: the pink lifts the hood's night under it, so it shines out of the dark.
		ink.ink(RisoPrint.PINK, 0.45 + 0.45 * maxf(swell, dart), glows)
		ink.ink(RisoPrint.PINK, 1.0, eyes)
	else:
		ink.ink(RisoPrint.BLUE, 0.6, eyes, false)
	if stunned:
		_stun_mark(xf * Vector2(0, -44))
