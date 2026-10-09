extends RisoProp
## A lantern: lit, burned out or waiting, swaying as the wizard brushes past.


## A springy lean that the wizard sets going as they pass (lanterns).
var brush_a: float = 0.0
var brush_v: float = 0.0


## Spring a lean toward `target`, pushed by the wizard passing near `at` (within `reach`).
func _brush(at: Vector2, reach: float) -> float:
	var player: Player = Stage.player()
	var target: float = 0.0
	if player != null:
		var d: Vector2 = to_global(at) - player.global_position
		var close: float = clampf(1.0 - d.length() / reach, 0.0, 1.0)
		if close > 0.0:
			target = (signf(d.x) * 0.1 - clampf(player.velocity.x / 300.0, -1.0, 1.0) * 0.22) * sqrt(close)
	brush_v += ((target - brush_a) * 24.0 - brush_v * 4.0) * _dt
	brush_a += brush_v * _dt
	return brush_a


func _draw_art() -> void:
	var lit: bool = MapInfo.instance != null and MapInfo.instance.is_respawn_lantern(host)
	var spent: bool = MapInfo.instance != null and MapInfo.instance.is_lantern_spent(host)
	var sw: float = sin(t * 2.2 + phase) * 0.12 - _brush(Vector2(30, _ground() - 80.0), 140.0)
	var g: float = _ground()
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-4, g - 110, 8, 110, 4), RisoShapes.rrect(-3, g - 111, 38, 6, 3)])
	var hang: Transform2D = Transform2D(sw, Vector2(30, g - 106))
	ink.ink(RisoPrint.BLUE, 1.0, [hang * RisoShapes.rrect(-2, 0, 4, 18, 2), hang * RisoShapes.rrect(-14, 14, 28, 8, 4)])
	var glass: PackedVector2Array = hang * RisoShapes.rrect(-12, 20, 24, 28, 10)
	if lit:
		ink.ink(RisoPrint.EYE, 0.25, [hang * RisoShapes.circle(Vector2(0, 34), 44.0, 32)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [glass])
		ink.ink(RisoPrint.EYE, 1.0, [glass], false)
		ink.knock([RisoPrint.EYE], [hang * RisoShapes.rrect(-4, 28, 8, 12, 4)])
		if MapInfo.instance.can_burn(host):
			# It can be burned into the mend spell: a drop of its light rises and falls over it.
			var rise: float = fmod(t * 0.6 + phase, 1.0)
			var c: Vector2 = Vector2(30, g - 78.0 - rise * 26.0)
			var drop: Array[PackedVector2Array] = [RisoShapes.circle(c, 7.0, 14), RisoShapes.tri(c + Vector2(-6, -2.5), c + Vector2(6, -2.5), c + Vector2(0, -16))]
			ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], drop)
			ink.ink(RisoPrint.PINK, 1.0 - rise * 0.6, drop, false)
	elif spent:
		# Empty glass, a charred wick and a thin smoke thread: the lantern has burned out.
		ink.ink(RisoPrint.NIGHT, 0.6, [glass], false)
		ink.ink(RisoPrint.BLUE, 0.5, [hang * RisoShapes.rrect(-3, 38, 6, 6, 2)], false)
		RisoMarks.smoke_thread(ink, hang.translated_local(Vector2(0, 38)), t + phase, 44.0, 3.2, 4.0, true)
	else:
		# Unclaimed: a low ember behind the glass, waiting to be lit.
		var flick: float = 0.8 + 0.2 * sin(t * 7.0 + phase)
		ink.ink(RisoPrint.EYE, 0.12, [hang * RisoShapes.circle(Vector2(0, 34), 24.0 * flick, 24)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [glass])
		ink.ink(RisoPrint.EYE, 0.5, [glass], false)
		ink.ink(RisoPrint.BLUE, 0.35, [glass], false)
