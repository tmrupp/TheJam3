extends RisoProp
## An exam door (ExamDoor): a portcullis like any gate, winching up and down, no lock, its
## cross-rail hung with a paper plate bearing the mark of the spell its hall's master has mastered
## (RisoGlyph), the subject of the exam; once the exam is passed a gold ring rims the plate.

## The plate's radius, and how big the mark is on it.
const PLATE_R: float = 19.0
const MARK: float = 0.5


func _draw_art() -> void:
	var door: ExamDoor = host as ExamDoor
	var g: float = _ground()
	var lift: float = door.lift if door != null else 0.0
	RisoMarks.portcullis(ink, g, half, RisoMarks.NO_LOCK, lift, 1.0)
	var top: float = g - 2.0 * half
	var bottom: float = lerpf(g - 14.0, top + 14.0, clampf(lift, 0.0, 1.0))
	var span: float = bottom - (top + 10.0)
	if span <= 44.0:
		return
	var c: Vector2 = Vector2(0, top + 10.0 + span * 0.5)
	var plate: PackedVector2Array = RisoShapes.circle(c, PLATE_R, 28)
	ink.knock(RisoPrint.ALL_PLATES, [plate])
	var subject: StringName = door.subject() if door != null else &""
	if subject != &"":
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoGlyph.of(subject, Vector2.ZERO, t):
			mark.append(Transform2D(0.0, Vector2(MARK, MARK), 0.0, c) * poly)
		ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
	if door != null and door.passed():
		ink.ink(RisoPrint.ACCENT, 1.0, RisoShapes.ring(c, PLATE_R, PLATE_R + 4.0, 28))
