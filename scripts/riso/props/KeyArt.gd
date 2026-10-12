extends RisoProp
## A key, bobbing in a light of its own colour (RisoLight); a skeleton key is bone-white with a
## paper twinkle, in a plain light.


func shines() -> bool:
	return true


func light() -> Array:
	var sprite: CanvasItem = host.get_node_or_null("Sprite2D") as CanvasItem if host != null else null
	if sprite != null and not sprite.visible:
		return []
	var color: int = int(host.get_meta(&"key_color", 0))
	return _light(Vector2.ZERO, RisoLight.GLEAM, -1 if color == KeyRing.SKELETON else RisoPrint.key_inks(color)[0])


func _draw_art() -> void:
	var sprite: CanvasItem = host.get_node_or_null("Sprite2D") as CanvasItem
	if sprite != null and not sprite.visible:
		return
	var o: Vector2 = Vector2(0, sin(t * 3.0 + phase) * 4.0)
	var color: int = int(host.get_meta(&"key_color", 0))
	var shape: Array[PackedVector2Array] = RisoMarks.key_shape(o, 1.0, color)
	RisoPrint.ink_key(ink, color, 1.0, shape)
	if color == KeyRing.SKELETON:
		# A bone-white skeleton key, with a paper twinkle turning over it: rarer than the coloured keys.
		ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, [Transform2D(t * 1.5, o + Vector2(-18, -20)) * RisoShapes.sparkle(Vector2.ZERO, 6.0)])
