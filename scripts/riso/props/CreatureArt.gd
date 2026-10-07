extends RisoProp
class_name CreatureArt
## The nightmares' art (WispArt, WatcherArt, HopperArt, WraithArt, BirdArt): what they share,
## the stars circling a stunned one's head.


## Stunned: three small stars of accent ink circle over the head at `c`, the ones passing behind
## smaller and fainter, circling slowly; they shrink as the stun runs out, and turn pink and blink
## in its last STUN_WARN seconds, when the enemy is about to wake.
const STUN_WARN: float = 1.0


func _stun_mark(c: Vector2) -> void:
	var stunner: Stunner = host.get_node_or_null("Stunner") as Stunner
	var frac: float = stunner.fraction() if stunner != null else 1.0
	if frac <= 0.0:
		return
	# About to wake: the last STUN_WARN seconds the stars turn pink (danger) and blink, faster and
	# faster toward the end.
	var left: float = stunner.left if stunner != null else 99.0
	var plate: int = RisoPrint.ACCENT
	if left < STUN_WARN:
		plate = RisoPrint.PINK
		var rate: float = lerpf(9.0, 3.0, left / STUN_WARN)
		if fmod(t * rate, 1.0) > 0.6:
			return
	var front: Array[PackedVector2Array] = []
	var back: Array[PackedVector2Array] = []
	for i: int in range(3):
		var a: float = t * 1.3 + TAU * float(i) / 3.0
		var depth: float = sin(a)
		var p: Vector2 = c + Vector2(cos(a) * 34.0, depth * 10.0)
		var star: PackedVector2Array = Transform2D(t * 0.9 + float(i), p) * RisoShapes.sparkle(Vector2.ZERO, (9.0 + 6.0 * frac) * (0.75 + 0.25 * depth))
		(front if depth >= 0.0 else back).append(star)
	ink.ink(plate, 0.5, back)
	ink.ink(plate, 1.0, front)
