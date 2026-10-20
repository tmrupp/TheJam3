extends RisoProp
## A light gate (LightGate): a portcullis like any gate, winching up and down, its cross-rail
## hung with a plate showing what opens it: a sun gate's a yellow sun with its rays, a shade gate's
## a pale crescent moon on night ink.


func _draw_art() -> void:
	var gate: LightGate = host as LightGate
	var g: float = _ground()
	var lift: float = gate.lift if gate != null else 0.0
	RisoMarks.portcullis(ink, g, half, RisoMarks.NO_LOCK, lift, 1.0)
	# The plate rides the cross-rail, where portcullis puts it.
	var top: float = g - 2.0 * half
	var bottom: float = lerpf(g - 14.0, top + 14.0, clampf(lift, 0.0, 1.0))
	var span: float = bottom - (top + 10.0)
	if span <= 40.0:
		return
	var c: Vector2 = Vector2(0, top + 10.0 + span * 0.5)
	var plate: PackedVector2Array = RisoShapes.circle(c, 17.0, 28)
	if gate == null or gate.sun:
		ink.knock(RisoPrint.ALL_PLATES, [plate])
		var rays: Array[PackedVector2Array] = []
		for k: int in range(8):
			var a: float = TAU * float(k) / 8.0 + t * 0.3
			var d: Vector2 = Vector2.from_angle(a)
			rays.append(PackedVector2Array([c + d * 9.0 + d.orthogonal() * 2.4, c + d * 15.0, c + d * 9.0 - d.orthogonal() * 2.4]))
		rays.append(RisoShapes.circle(c, 7.0, 20))
		ink.ink(RisoPrint.ACCENT, 1.0, rays, false)
	else:
		ink.ink(RisoPrint.NIGHT, 1.0, [plate])
		var moon: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in Geometry2D.clip_polygons(RisoShapes.circle(c, 10.0, 24), RisoShapes.circle(c + Vector2(5.0, -3.0), 9.0, 24)):
			if not Geometry2D.is_polygon_clockwise(piece):
				moon.append(piece)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.9, moon)
