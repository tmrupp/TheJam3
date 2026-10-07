extends RisoProp
## One plank of a chasm's bridge, laid or waiting.


## The Bridge it dresses.
var bridge: Bridge:
	get:
		return host as Bridge


## One plank of a chasm's bridge (Bridge), across the top of its cell. Laid, two pale boards with
## dark seams over a rope slung between posts; as it lays itself it drops into place and darkens
## in. Not yet laid, a faint dashed outline over the chasm, so you know a bridge belongs there.
func _draw_art() -> void:
	var laid: float = bridge.laid
	var top: float = -64.0
	if laid <= 0.0:
		var dashes: Array[PackedVector2Array] = []
		for k: int in range(4):
			dashes.append(RisoShapes.rrect(-60.0 + float(k) * 32.0, top + 4.0, 22.0, 4.0, 2.0))
		ink.ink(RisoPrint.ACCENT, 0.35 + 0.1 * sin(t * 2.0 + phase), dashes)
		return
	var drop: float = (1.0 - laid) * -40.0
	var boards: Array[PackedVector2Array] = [RisoShapes.rrect(-66.0, top + drop, 64.0, 16.0, 4.0), RisoShapes.rrect(2.0, top + drop, 64.0, 16.0, 4.0)]
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], laid * 0.9, boards)
	ink.ink(RisoPrint.ACCENT, 0.25 * laid, boards, false)
	ink.ink(RisoPrint.NIGHT, 0.45 * laid, [RisoShapes.rrect(-66.0, top + drop + 12.0, 132.0, 4.0, 2.0)], false)
	# The rope rail: a post at the cell's left edge, the rope sagging to the next.
	if laid >= 1.0:
		var rope: PackedVector2Array = PackedVector2Array()
		for k: int in range(9):
			var u: float = float(k) / 8.0
			rope.append(Vector2(-64.0 + 128.0 * u, top - 46.0 + sin(u * PI) * 12.0))
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-67.0, top - 52.0, 6.0, 54.0, 3.0)])
		ink.ink(RisoPrint.NIGHT, 0.8, RisoDecor.strip(rope, 3.0, 3.0), false)
