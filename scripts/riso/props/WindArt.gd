extends RisoProp
## Moving air: an updraft rising up its shaft, or a crosswind over its chasm.


## Moving air (Wind): streaks of lifted night drifting the way it blows, an updraft's rising up its
## shaft, a crosswind's across its chasm (with a sun glint here and there). A crosswind still
## waiting for its vane shows only a few faint motes hanging over the chasm.
func _draw_art() -> void:
	var w: Wind = host as Wind
	if w == null:
		return
	var r: Rect2 = Rect2(w.rect.position - host.global_position, w.rect.size)
	var streaks: Array[PackedVector2Array] = []
	var glints: Array[PackedVector2Array] = []
	if w.up > 0:
		var n: int = 4 + w.up * 2
		for k: int in range(n):
			var u: float = fmod(t * 0.55 + RisoShapes.hash1(float(k) * 1.7 + phase), 1.0)
			var x: float = r.position.x + r.size.x * (0.2 + 0.6 * RisoShapes.hash1(float(k) * 3.1 + phase))
			x += sin(t * 2.0 + float(k)) * 6.0
			var y: float = r.end.y - u * r.size.y
			var fade: float = sin(u * PI)
			streaks.append(RisoShapes.almond(Vector2(x, y), 4.0, 26.0 * fade + 4.0, 10))
			if k % 3 == 0:
				glints.append(RisoShapes.circle(Vector2(x, y - 26.0), 3.0 * fade, 8))
		ink.lift_ink([RisoPrint.NIGHT], 0.65, streaks)
		ink.ink(RisoPrint.ACCENT, 0.5, glints, false)
		# The floor it rises from: a pale lip of cloud.
		ink.lift_ink([RisoPrint.NIGHT], 0.4, [RisoShapes.ellipse(Vector2(r.get_center().x, r.end.y - 6.0), r.size.x * 0.4, 8.0, 16)])
		return
	var dir: float = w.blowing()
	if dir == 0.0:
		var motes: Array[PackedVector2Array] = []
		for k: int in range(7):
			var x: float = r.position.x + r.size.x * RisoShapes.hash1(float(k) * 2.3 + phase)
			var y: float = r.position.y + r.size.y * (0.3 + 0.6 * RisoShapes.hash1(float(k) * 5.9 + phase)) + sin(t * 1.3 + float(k)) * 5.0
			motes.append(RisoShapes.circle(Vector2(x, y), 3.0, 8))
		ink.lift_ink([RisoPrint.NIGHT], 0.3, motes)
		return
	var count: int = 4 + w.width * 2
	for k: int in range(count):
		var u: float = fmod(t * 0.7 + RisoShapes.hash1(float(k) * 1.3 + phase), 1.0)
		var x: float = r.position.x + r.size.x * (u if dir > 0.0 else 1.0 - u)
		var y: float = r.position.y + r.size.y * (0.15 + 0.75 * RisoShapes.hash1(float(k) * 4.7 + phase)) + sin(t * 2.0 + float(k)) * 4.0
		var fade: float = sin(u * PI)
		streaks.append(RisoShapes.almond(Vector2(x, y), 30.0 * fade + 4.0, 4.0, 10))
		if k % 4 == 0:
			glints.append(RisoShapes.circle(Vector2(x + dir * 30.0, y), 3.0 * fade, 8))
	ink.lift_ink([RisoPrint.NIGHT], 0.65, streaks)
	ink.ink(RisoPrint.ACCENT, 0.5, glints, false)

## A wind spreads over its whole extent (Wind.extent): it is in view if any of it is.
func view_rect() -> Rect2:
	return (host as Wind).extent() if host is Wind else Rect2()
