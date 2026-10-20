extends RisoProp
## One plank of a chasm's bridge, laid or waiting.


## The Bridge it dresses.
var bridge: Bridge:
	get:
		return host as Bridge

## How much of its ink a laid plank prints while it bears no one, and how much that wavers.
const GHOST: float = 0.45
const GHOST_WAVER: float = 0.08


## One plank of a chasm's bridge (Bridge), across the top of its cell along the bridge's sag
## (Bridge.sag_left, sag_right). Laid, two pale boards with dark seams over a rope slung between
## posts; as it lays itself it drops into place and darkens in. Not yet laid, a faint dashed outline
## over the chasm, so you know a bridge belongs there. Laid while the wizard's flame burns, it bears
## no one (Bridge.bears) and prints as a ghost of itself, GHOST of its ink, wavering.
func _draw_art() -> void:
	var top: float = -64.0
	if bridge.laid <= 0.0:
		var dashes: Array[PackedVector2Array] = []
		for k: int in range(4):
			var x: float = -60.0 + float(k) * 32.0
			dashes.append(_board(x, x + 22.0, top + 4.0, 4.0))
		ink.ink(RisoPrint.ACCENT, 0.35 + 0.1 * sin(t * 2.0 + phase), dashes)
		return
	var laid: float = bridge.laid * lerpf(GHOST + GHOST_WAVER * sin(t * 2.4 + phase), 1.0, bridge.firm)
	var drop: float = (1.0 - bridge.laid) * -40.0
	var boards: Array[PackedVector2Array] = [_board(-66.0, -2.0, top + drop, 16.0), _board(2.0, 66.0, top + drop, 16.0)]
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], laid * 0.9, boards)
	ink.ink(RisoPrint.ACCENT, 0.25 * laid, boards, false)
	ink.ink(RisoPrint.NIGHT, 0.45 * laid, [_board(-66.0, 66.0, top + drop + 12.0, 4.0)], false)
	# The rope rail: a post at the cell's left edge, the rope sagging to the next, along the deck.
	if bridge.laid >= 1.0:
		var rope: PackedVector2Array = PackedVector2Array()
		for k: int in range(9):
			var u: float = float(k) / 8.0
			var x: float = -64.0 + 128.0 * u
			rope.append(Vector2(x, _deck(x) + top - 46.0 + sin(u * PI) * 12.0))
		var foot: float = _deck(-64.0) + top
		ink.ink(RisoPrint.BLUE, laid, [RisoShapes.rrect(-67.0, foot - 52.0, 6.0, 54.0, 3.0)])
		ink.ink(RisoPrint.NIGHT, 0.8 * laid, RisoDecor.strip(rope, 3.0, 3.0), false)


## How far the deck hangs at `x` across the cell (px), between the plank's two ends.
func _deck(x: float) -> float:
	return lerpf(bridge.sag_left, bridge.sag_right, (x + 64.0) / 128.0)


## A board from `a` to `b` across the cell, `thick` deep, its top `y` below the deck's line.
func _board(a: float, b: float, y: float, thick: float) -> PackedVector2Array:
	var r: float = minf(thick * 0.25, 4.0)
	return PackedVector2Array([Vector2(a + r, y + _deck(a)), Vector2(b - r, y + _deck(b)), Vector2(b, y + _deck(b) + r),
		Vector2(b, y + _deck(b) + thick - r), Vector2(b - r, y + _deck(b) + thick), Vector2(a + r, y + _deck(a) + thick),
		Vector2(a, y + _deck(a) + thick - r), Vector2(a, y + _deck(a) + r)])
