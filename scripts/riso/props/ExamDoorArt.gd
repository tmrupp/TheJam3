extends RisoProp
## A hall's door (ExamDoor): a portcullis like any gate, winching up and down, no lock, and on the
## wall over its doorway, up or down, a dark plate (night ink, reading against the pale marble) with
## the mark of what its hall teaches knocked out to paper (RisoGlyph): a lecture hall's subject now,
## with a night pip over it for each tier taught (a bare plate while it has no class), or the exam's
## subject; once the exam is passed a gold ring rims the plate.

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
	if door != null and door.passed():
		ink.ink(RisoPrint.ACCENT, 1.0, RisoShapes.ring(c, PLATE_R, PLATE_R + 4.0, 28))
