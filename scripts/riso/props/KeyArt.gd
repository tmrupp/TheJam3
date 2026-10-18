extends RisoProp
## A key, bobbing in a light of its own colour (RisoLight); a skeleton key is bone-white with a
## paper twinkle, in a plain light. An exam paper (KeyRing.paper) lies the same way: a paper sheet
## (PAPER times a key's size) with a folded corner, its subject's mark (RisoGlyph) on it in gold, and
## under it a gold pip for each tier; a stolen one's folded corner is pink (KeyRing.is_stolen).

## How much bigger an exam paper is drawn than a key, and its mark on it.
const PAPER: float = 1.7
const PAPER_MARK: float = 0.5


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
		# The sheet and its folded corner, bare paper (no ruled lines: the mark takes their place).
		var sheet: Array[PackedVector2Array] = RisoMarks.paper_shape(o, PAPER)
		ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, sheet.slice(0, 1))
		if KeyRing.is_stolen(color):
			ink.ink(RisoPrint.PINK, 1.0, sheet.slice(1, 2))
		else:
			ink.ink(RisoPrint.NIGHT, 0.55, sheet.slice(1, 2), false)
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoGlyph.of(KeyRing.paper_spell(color), Vector2.ZERO, t):
			mark.append(Transform2D(0.0, Vector2(PAPER_MARK, PAPER_MARK), 0.0, o + Vector2(0, 2.0 * PAPER)) * poly)
		ink.ink(RisoPrint.ACCENT, 1.0, mark)
		var tier: int = KeyRing.paper_tier(color)
		var pips: Array[PackedVector2Array] = []
		for i: int in range(tier):
			var p: Vector2 = o + Vector2((float(i) - float(tier - 1) * 0.5) * 10.0, 13.0 * PAPER + 9.0)
			pips.append(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]))
		ink.knock(RisoPrint.ALL_PLATES, pips)
		ink.ink(RisoPrint.ACCENT, 1.0, pips)
		return
	var shape: Array[PackedVector2Array] = RisoMarks.key_shape(o, 1.0, color)
	RisoPrint.ink_key(ink, color, 1.0, shape)
	if color == KeyRing.SKELETON:
		# A bone-white skeleton key, with a paper twinkle turning over it: rarer than the coloured keys.
		ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, [Transform2D(t * 1.5, o + Vector2(-18, -20)) * RisoShapes.sparkle(Vector2.ZERO, 6.0)])
