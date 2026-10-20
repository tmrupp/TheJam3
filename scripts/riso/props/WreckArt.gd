extends RisoProp
## Wreckage the whale has swallowed (Wreck).

## Its size: across (px, a little less than its two cells) and down from its deck to its bottom.
const ACROSS: float = 236.0
const DOWN: float = 72.0
## The stain the acid leaves on its lower part, and how far up it reaches (a share of its height).
const STAIN: float = 0.3
const STAIN_UP: float = 0.45


## The Wreck it dresses.
var wreck: Wreck:
	get:
		return host as Wreck


## It rides the acid, printed wherever it is.
func every_frame() -> bool:
	return true


## Wreckage lying in the acid, its deck flat at the top (it is stood on), its lower part stained
## darker where the acid has soaked it. A balloon's basket (wicker on its side, a dark rim along its
## deck, broken ropes trailing); a temple's column drum lying on its side (pale marble, fluted
## along its length, its round face showing at one end, a chip out of its rim); or a crate (planks,
## a brace across them, nail heads in bare paper).
func _draw_art() -> void:
	var k: StringName = wreck.kind if wreck != null else &"crate"
	var x0: float = -ACROSS * 0.5
	match k:
		&"basket":
			_basket(x0)
		&"column":
			_column(x0)
		_:
			_crate(x0)
	# The acid's stain over its lower part.
	var stain: PackedVector2Array = RisoShapes.rrect(x0, DOWN * (1.0 - STAIN_UP), ACROSS, DOWN * STAIN_UP, 8.0)
	ink.ink(RisoPrint.NIGHT, STAIN, [stain], false)


## A balloon's basket, on its side: wicker in rows, a dark rim along its deck, two broken ropes.
func _basket(x0: float) -> void:
	var body: PackedVector2Array = RisoShapes.rrect(x0 + 4.0, 0.0, ACROSS - 8.0, DOWN, 10.0)
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK], [body])
	ink.ink(RisoPrint.BLUE, 0.85, [body])
	var weave: Array[PackedVector2Array] = []
	for row: int in range(4):
		var y: float = 18.0 + 14.0 * float(row)
		var shift: float = 9.0 if row % 2 == 1 else 0.0
		var x: float = x0 + 14.0 + shift
		while x < x0 + ACROSS - 22.0:
			weave.append(RisoShapes.rrect(x, y, 12.0, 3.0, 1.5))
			x += 18.0
	ink.ink(RisoPrint.NIGHT, 0.45, weave, false)
	ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.rrect(x0, -2.0, ACROSS, 11.0, 5.0)], false)
	# Broken ropes trailing off its far end.
	var ropes: Array[PackedVector2Array] = []
	for i: int in range(2):
		var from: Vector2 = Vector2(-x0 - 6.0, 12.0 + 26.0 * float(i))
		var sway: float = sin(t * 1.1 + phase + float(i)) * 6.0
		ropes.append_array(RisoDecor.strip(PackedVector2Array([from, from + Vector2(22.0, 10.0 + sway), from + Vector2(34.0, 30.0 + sway)]), 3.0, 1.5))
	ink.ink(RisoPrint.BLUE, 1.0, ropes)


## A temple's column drum lying on its side: pale marble fluted along its length, its round face at
## one end, a chip out of its rim.
func _column(x0: float) -> void:
	var r: float = DOWN * 0.5
	var body: PackedVector2Array = RisoShapes.rrect(x0 + 10.0, 0.0, ACROSS - 10.0, DOWN, 6.0)
	var face: PackedVector2Array = RisoShapes.ellipse(Vector2(x0 + 12.0, r), 14.0, r, 20)
	ink.knock(RisoPrint.ALL_PLATES, [body, face])
	ink.ink(RisoPrint.BLUE, 0.18, [body], false)
	var flutes: Array[PackedVector2Array] = []
	for i: int in range(5):
		var y: float = 10.0 + 13.0 * float(i)
		flutes.append(RisoShapes.rrect(x0 + 26.0, y, ACROSS - 40.0, 3.0, 1.5))
	ink.ink(RisoPrint.NIGHT, 0.3, flutes, false)
	# Its round face, a little darker, and a chip out of its far rim.
	ink.ink(RisoPrint.BLUE, 0.35, [face], false)
	ink.ink(RisoPrint.NIGHT, 0.2, RisoShapes.ring(Vector2(x0 + 12.0, r), r * 0.55, r * 0.62, 18), false)
	ink.ink(RisoPrint.NIGHT, 0.45, [RisoShapes.tri(Vector2(-x0 - 24.0, 0.0), Vector2(-x0, 0.0), Vector2(-x0, 18.0))], false)


## A crate: planks across it, a brace from corner to corner, nail heads in bare paper.
func _crate(x0: float) -> void:
	var body: PackedVector2Array = RisoShapes.rrect(x0 + 6.0, 0.0, ACROSS - 12.0, DOWN, 4.0)
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK], [body])
	ink.ink(RisoPrint.BLUE, 1.0, [body])
	var seams: Array[PackedVector2Array] = []
	for i: int in range(1, 4):
		seams.append(RisoShapes.rrect(x0 + 10.0, DOWN * float(i) / 4.0 - 1.5, ACROSS - 20.0, 3.0, 1.0))
	var brace: PackedVector2Array = PackedVector2Array([Vector2(x0 + 14.0, DOWN - 8.0), Vector2(x0 + 26.0, DOWN - 8.0), Vector2(-x0 - 14.0, 8.0), Vector2(-x0 - 26.0, 8.0)])
	ink.ink(RisoPrint.NIGHT, 0.45, seams, false)
	ink.ink(RisoPrint.NIGHT, 0.3, [brace], false)
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(x0 + 6.0, -2.0, 14.0, DOWN + 2.0, 3.0), RisoShapes.rrect(-x0 - 20.0, -2.0, 14.0, DOWN + 2.0, 3.0)])
	var nails: Array[PackedVector2Array] = []
	for y: float in [8.0, DOWN - 8.0]:
		for x: float in [x0 + 13.0, -x0 - 13.0]:
			nails.append(RisoShapes.circle(Vector2(x, y), 2.6, 8))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], nails)
