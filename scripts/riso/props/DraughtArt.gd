extends RisoProp
## A mending draught (Draught): a drop of ember light over a bead, as Mend's glyph draws a draught,
## bobbing in a faint reward halo, with a paper gleam on the bead.


func _draw_art() -> void:
	var o: Vector2 = Vector2(0.0, sin(t * 3.0 + phase) * 4.0)
	ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(o, 26.0, 24)])
	var drop: Array[PackedVector2Array] = [RisoShapes.circle(o + Vector2(0.0, 7.0), 11.0, 22), RisoShapes.almond(o + Vector2(0.0, -12.0), 5.5, 10.0, 12)]
	ink.knock([RisoPrint.NIGHT], drop)
	ink.ink(RisoPrint.EYE, 1.0, drop)
	ink.knock([RisoPrint.EYE], [RisoShapes.circle(o + Vector2(-4.0, 4.0), 3.0, 10)])
