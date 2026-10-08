extends RisoProp
## A moving ledge and its track.


## The MovingPlatform it dresses.
var lift: MovingPlatform:
	get:
		return host as MovingPlatform


## A moving ledge: the static ledge's bar and cap, a pink rune glowing beneath, and its track
## printed as a faint dotted line that stays put while the ledge slides along it. A lift parked for
## its switch has a dark, unlit rune and the switch's emblem and sigil on a paper plate in its
## middle.
func _draw_art() -> void:
	var n: int = lift.length
	var x1: float = -half + float(n) * half * 2.0
	var mid: Vector2 = Vector2(float(n - 1) * half, -half + 17.0)
	var start: Vector2 = lift.start
	var holder: Node2D = host.get_parent() as Node2D
	var a: Vector2 = to_local(holder.to_global(start) if holder != null else start) + mid
	var b: Vector2 = a + (lift.axis) * lift.travel
	var dots: Array[PackedVector2Array] = []
	var steps: int = maxi(1, int(a.distance_to(b) / 26.0))
	for i: int in range(steps + 1):
		dots.append(RisoShapes.circle(a.lerp(b, float(i) / float(steps)), 3.5, 8))
	ink.ink(RisoPrint.BLUE, 0.35, dots)
	var pulse: float = 0.8 + 0.2 * sin(t * 3.0 + phase)
	for i: int in range(n):
		var c: Vector2 = Vector2(float(i) * half * 2.0, -half + 44.0)
		if lift.waiting:
			ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.almond(c, 10.0, 4.0, 8)])
			continue
		ink.ink(RisoPrint.PINK, 0.25, [RisoShapes.ellipse(c, 26.0 * pulse, 9.0 * pulse, 20)])
		ink.ink(RisoPrint.PINK, 1.0, [RisoShapes.almond(c, 10.0, 4.0, 8)])
	ink.ink(RisoPrint.BLUE, 1.0, [_bar(-half + 1.0, -half, x1 - 1.0, -half + 34.0, 12.0, true, true)])
	ink.ink(RisoPrint.ACCENT, 1.0, [_bar(-half + 1.0, -half - 3.0, x1 - 1.0, -half + 14.0, 8.0, true, true)])
	if lift.waiting:
		RisoMarks.switch_plate(ink, mid + Vector2(0, -8.0), 1.6, 1.0, Sigils.of(host))


## A horizontal bar whose left/right ends are rounded only when free.
func _bar(x0: float, y0: float, x1: float, y1: float, r: float, round_left: bool, round_right: bool) -> PackedVector2Array:
	r = minf(r, (y1 - y0) * 0.5)
	var out: PackedVector2Array = PackedVector2Array()
	if round_left:
		for s: int in range(5):
			var t: float = PI + PI * 0.5 * float(s) / 4.0
			out.append(Vector2(x0 + r, y0 + r) + Vector2(cos(t), sin(t)) * r)
	else:
		out.append(Vector2(x0, y0))
	if round_right:
		for s: int in range(5):
			var t: float = -PI * 0.5 + PI * 0.5 * float(s) / 4.0
			out.append(Vector2(x1 - r, y0 + r) + Vector2(cos(t), sin(t)) * r)
		for s: int in range(5):
			var t: float = PI * 0.5 * float(s) / 4.0
			out.append(Vector2(x1 - r, y1 - r) + Vector2(cos(t), sin(t)) * r)
	else:
		out.append(Vector2(x1, y0))
		out.append(Vector2(x1, y1))
	if round_left:
		for s: int in range(5):
			var t: float = PI * 0.5 + PI * 0.5 * float(s) / 4.0
			out.append(Vector2(x0 + r, y1 - r) + Vector2(cos(t), sin(t)) * r)
	else:
		out.append(Vector2(x0, y1))
	return out
