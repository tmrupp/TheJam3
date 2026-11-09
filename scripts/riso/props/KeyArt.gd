extends RisoProp
## A key, bobbing in a light of its own colour (RisoLight); a skeleton key is bone-white with a
## paper twinkle, in a plain light. An exam paper (KeyRing.paper) lies the same way, written out in
## full (RisoPrint.ink_paper: its department's colour, its subject's mark and a gold pip a tier), a
## relic unlock as a gold seal stamped with a paper star (RisoMarks.seal_shape), and a seed as a
## green-gold almond with a curl of sprout (RisoMarks.seed_shape).

## How much bigger an exam paper is drawn than a key, and a seed (KeyRing.SEED) lying.
const PAPER: float = 1.7
const SEED: float = 1.6


func shines() -> bool:
	return true


func light() -> Array:
	var sprite: CanvasItem = host.get_node_or_null("Sprite2D") as CanvasItem if host != null else null
	if sprite != null and not sprite.visible:
		return []
	var color: int = int(host.get_meta(&"key_color", 0))
	return _light(Vector2.ZERO, RisoLight.GLEAM, -1 if color == KeyRing.SKELETON or KeyRing.is_paper(color) else RisoPrint.key_inks(color)[0])


func _draw_art() -> void:
	var sprite: CanvasItem = host.get_node_or_null("Sprite2D") as CanvasItem
	if sprite != null and not sprite.visible:
		return
	var o: Vector2 = Vector2(0, sin(t * 3.0 + phase) * 4.0)
	var color: int = int(host.get_meta(&"key_color", 0))
	if KeyRing.is_paper(color):
		RisoPrint.ink_paper(ink, color, o, PAPER, t)
		return
	var size: float = SEED if color == KeyRing.SEED else 1.0
	var shape: Array[PackedVector2Array] = RisoMarks.key_shape(o, size, color)
	RisoPrint.ink_key(ink, color, 1.0, shape)
	if color == KeyRing.SKELETON:
		# A bone-white skeleton key, with a paper twinkle turning over it: rarer than the coloured keys.
		ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, [Transform2D(t * 1.5, o + Vector2(-18, -20)) * RisoShapes.sparkle(Vector2.ZERO, 6.0)])
