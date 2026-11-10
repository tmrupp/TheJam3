extends RisoProp
## A barrier's mark (BarrierMark): the move its barrier is made for (RisoGlyph, fitted to a roundel)
## in a small roundel on the rock over its way in, in the quiet inks: the roundel a disc of paper
## screened back with blue (MARK_PAPER), the move's mark in night. A note, not a prize: no accent.
## Gone once the wizard knows the move.

## The roundel's radius (px), how much of the paper shows through its blue, and how far down from
## the middle of its rock cell it sits (of the cell).
const MARK_R: float = 17.0
const MARK_PAPER: float = 0.55
const MARK_DOWN: float = 0.18


func _draw_art() -> void:
	var mark: BarrierMark = host as BarrierMark
	var info: MapInfo = MapInfo.instance
	if mark == null or info == null or not mark.showing:
		return
	var cell_px: float = (info.cell_position(Vector2i(1, 0)) - info.cell_position(Vector2i.ZERO)).x
	var c: Vector2 = to_local(info.cell_position(mark.on_rock)) + Vector2(0, cell_px * MARK_DOWN)
	var disc: PackedVector2Array = RisoShapes.circle(c, MARK_R, 22)
	ink.knock(RisoPrint.ALL_PLATES, [disc])
	ink.ink(RisoPrint.BLUE, 1.0 - MARK_PAPER, [disc], false)
	ink.ink(RisoPrint.NIGHT, 0.9, RisoGlyph.fit(mark.move, c, MARK_R * 0.72, t), false)

