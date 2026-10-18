extends RisoProp
## A hall's door (ExamDoor): a portcullis like any gate, winching up and down, no lock, and on the
## wall over its doorway, up or down, a dark plate (night ink, reading against the pale marble) with
## the mark of what its hall teaches knocked out to paper (RisoGlyph): a lecture hall's subject now,
## with a night pip over it for each tier taught (a bare plate while it has no class, or on the
## library's). Beside a classroom's plate, while its class asks for a
## prerequisite (ExamDoor.prereq), hangs a small dark plate holding a paper sheet with that subject's
## mark in night, and under it a paper pip for each tier it needs: the paper (or the spell known)
## that opens the door.

## The prerequisite's sheet: its size, and how far beside the plate's middle it hangs.
const NEED_SHEET: float = 1.15
const NEED_SIDE: float = 44.0

## The plate's radius, and how big the mark is on it.
const PLATE_R: float = 19.0
const MARK: float = 0.5


func _draw_art() -> void:
	var door: ExamDoor = host as ExamDoor
	var g: float = _ground()
	var lift: float = door.lift if door != null else 0.0
	RisoMarks.portcullis(ink, g, half, RisoMarks.NO_LOCK, lift, 1.0)
	var top: float = g - 2.0 * half
	var c: Vector2 = Vector2(0, top - PLATE_R - 10.0)
	var plate: PackedVector2Array = RisoShapes.circle(c, PLATE_R, 28)
	ink.ink(RisoPrint.NIGHT, 0.9, [plate], false)
	var subject: StringName = door.subject() if door != null else &""
	if subject != &"":
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoGlyph.of(subject, Vector2.ZERO, t):
			mark.append(Transform2D(0.0, Vector2(MARK, MARK), 0.0, c) * poly)
		ink.knock(RisoPrint.ALL_PLATES, mark)
	var tier: int = door.tier() if door != null else 0
	if tier > 0:
		var pips: Array[PackedVector2Array] = []
		for i: int in range(tier):
			var p: Vector2 = c + Vector2((float(i) - float(tier - 1) * 0.5) * 9.0, -PLATE_R - 8.0)
			pips.append(PackedVector2Array([p + Vector2(0, -3.5), p + Vector2(3.5, 0), p + Vector2(0, 3.5), p + Vector2(-3.5, 0)]))
		ink.knock(RisoPrint.ALL_PLATES, pips)
		ink.ink(RisoPrint.NIGHT, 1.0, pips, false)
	var need: Array = door.prereq() if door != null else [&"", 0]
	if need[0] != &"":
		var nc: Vector2 = c + Vector2(NEED_SIDE, 0)
		var tall: float = 13.0 * NEED_SHEET
		ink.ink(RisoPrint.NIGHT, 0.9, [RisoShapes.rrect(nc.x - tall, nc.y - tall - 6.0, tall * 2.0, tall * 2.0 + 22.0, 5.0)], false)
		var sheet: Array[PackedVector2Array] = RisoMarks.paper_shape(nc, NEED_SHEET)
		ink.knock(RisoPrint.ALL_PLATES, sheet.slice(0, 1))
		ink.ink(RisoPrint.NIGHT, 0.55, sheet.slice(1, 2), false)
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoGlyph.of(need[0], Vector2.ZERO, t):
			mark.append(Transform2D(0.0, Vector2(0.36, 0.36), 0.0, nc) * poly)
		ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
		var pips: Array[PackedVector2Array] = []
		for i: int in range(int(need[1])):
			var p: Vector2 = nc + Vector2((float(i) - float(int(need[1]) - 1) * 0.5) * 7.0, tall + 7.0)
			pips.append(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0)]))
		ink.knock(RisoPrint.ALL_PLATES, pips)
