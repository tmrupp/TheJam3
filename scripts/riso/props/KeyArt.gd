extends RisoProp
## A key, bobbing in a halo of its own colour; a skeleton key is bone-white with a paper twinkle.


func _draw_art() -> void:
	var sprite: CanvasItem = host.get_node_or_null("Sprite2D") as CanvasItem
	if sprite != null and not sprite.visible:
		return
	var o: Vector2 = Vector2(0, sin(t * 3.0 + phase) * 4.0)
	var color: int = int(host.get_meta(&"key_color", 0))
	var shape: Array[PackedVector2Array] = RisoMarks.key_shape(o, 1.0, color)
	# A halo in the key's own colour, as the stars have (a skeleton key's is pale light).
	var halo: Array[PackedVector2Array] = [RisoShapes.circle(o + Vector2(-2, 1), 26.0, 24)]
	if color == KeyRing.SKELETON:
		# Round the bone's whole length.
		ink.lift_ink(RisoPrint.ALL_PLATES, 0.3, [RisoShapes.circle(o + Vector2(1, 1), 29.0, 26)])
	else:
		for plate: int in RisoPrint.key_inks(color):
			ink.ink(plate, 0.25, halo)
	RisoPrint.ink_key(ink, color, 1.0, shape)
	if color == KeyRing.SKELETON:
		# A bone-white skeleton key, with a paper twinkle turning over it: rarer than the coloured keys.
		ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, [Transform2D(t * 1.5, o + Vector2(-18, -20)) * RisoShapes.sparkle(Vector2.ZERO, 6.0)])
