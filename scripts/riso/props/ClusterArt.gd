extends RisoProp
## A star cluster: a big star turning in a wide halo with smaller stars wheeling round it.


## A star cluster: a big star turning in a wide halo with smaller stars wheeling round it, all
## bobbing; the big star has a paper glint so it reads as more than a star.
func _draw_art() -> void:
	var o: Vector2 = Vector2(0, sin(t * 2.4 + phase) * 5.0)
	var pulse: float = 1.0 + 0.06 * sin(t * 4.0 + phase)
	ink.ink(RisoPrint.ACCENT, 0.2, [RisoShapes.circle(o, 54.0 * pulse, 32)])
	var big: PackedVector2Array = Transform2D(t * 0.5 + phase, o) * RisoShapes.sparkle(Vector2.ZERO, 34.0 * pulse)
	var stars: Array[PackedVector2Array] = [big]
	for k: int in range(5):
		var a: float = t * 0.9 + TAU * float(k) / 5.0 + phase
		var at: Vector2 = o + Vector2(cos(a) * 44.0, sin(a) * 26.0)
		stars.append(Transform2D(-a, at) * RisoShapes.sparkle(Vector2.ZERO, 12.0 + 3.0 * float(k % 2)))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], stars)
	ink.ink(RisoPrint.ACCENT, 1.0, stars, false)
	ink.knock([RisoPrint.ACCENT], [RisoShapes.circle(o + Vector2(-4, -4), 4.0, 10)])
