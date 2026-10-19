extends RisoProp
## A hall's door (ExamDoor): a portcullis like any gate, winching up and down, no lock, and on the
## wall over its doorway, up or down, two signs. Its plate: a disc in its classroom's department's
## colour (RisoPrint.DEPT_INKS; night for the library's) with the mark of what it teaches now knocked
## out to paper (RisoGlyph) and under it a paper pip for each tier taught (ExamDoor.subject, tier;
## a bare plate while it has no class). Round the rim of a classroom's plate, its day (ExamDoor.cycle):
## Timetable.PERIODS arcs in night, the day's first period at the top and the rest going round
## clockwise, an arc for a period in session and none for one closed, and a small notch outside the
## rim at the period it is now (ExamDoor.period), as a clock's hand. Beside it, while its class asks
## for a prerequisite (ExamDoor.prereq), its tag: a sheet in the colour of the department it asks for,
## its folded corner bare paper, with that department's emblem (RisoMarks.emblem: a leaf, a skull, a
## crystal, a star) and under it a pip for each tier it needs, both knocked out to paper: a paper of
## that department (or a spell of it held) opens the door. The two stand side by side over the
## doorway, a little left of its middle (PAIR_LEFT).

## The plate's radius, how big the mark is on it and how far up from its middle, and its tier pips
## (their size, the room between them, and how far down from its middle).
const PLATE_R: float = 26.0
const MARK: float = 0.5
const MARK_UP: float = 5.0
const PIP: float = 3.6
const PIP_GAP: float = 9.0
const PIP_DOWN: float = 15.0
## The day's arcs round the plate: their radius, their width and the gap left between two
## (radians); and the notch at the period it is now, outside them: its width and how far it stands
## out from the arcs (px).
const RING_R: float = 33.0
const RING_W: float = 4.5
const RING_GAP: float = 0.32
const NOTCH_W: float = 9.0
const NOTCH_OUT: float = 7.0
## The prerequisite's tag: its size (as a paper's, RisoMarks.paper_shape), the room between it and the
## notch round the plate beside it, its emblem's size and how far up from its middle, and how far down
## its pips.
const TAG: float = 1.75
const TAG_GAP: float = 6.0
## How far left of the doorway's middle the plate and the tag beside it stand (px), so the tag keeps
## clear of the wall's far edge.
const PAIR_LEFT: float = 6.0
const EMBLEM: float = 0.95
const EMBLEM_UP: float = 6.0
const TAG_PIPS_DOWN: float = 14.0


func _draw_art() -> void:
	var door: ExamDoor = host as ExamDoor
	var g: float = _ground()
	var lift: float = door.lift if door != null else 0.0
	RisoMarks.portcullis(ink, g, half, RisoMarks.NO_LOCK, lift, 1.0)
	var top: float = g - 2.0 * half
	var c: Vector2 = Vector2(0, top - RING_R - NOTCH_OUT - 6.0)
	# With a tag beside it, the two are centred over the doorway together.
	var need: Array = door.prereq() if door != null else [&"", 0]
	var outer: float = RING_R + RING_W * 0.5 + NOTCH_OUT
	var tag_half: float = 10.0 * TAG
	if need[0] != &"":
		c.x = -(TAG_GAP + tag_half * 2.0) * 0.5 - PAIR_LEFT
	var plate: PackedVector2Array = RisoShapes.circle(c, PLATE_R, 28)
	if door == null or not RisoPrint.ink_dept(ink, door.dept(), 1.0, [plate]):
		ink.ink(RisoPrint.NIGHT, 0.9, [plate], false)
	var subject: StringName = door.subject() if door != null else &""
	if subject != &"":
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoGlyph.of(subject, Vector2.ZERO, t):
			mark.append(Transform2D(0.0, Vector2(MARK, MARK), 0.0, c + Vector2(0, -MARK_UP)) * poly)
		ink.knock(RisoPrint.ALL_PLATES, mark)
	var tier: int = door.tier() if door != null else 0
	ink.knock(RisoPrint.ALL_PLATES, _pips(c + Vector2(0, PIP_DOWN), tier))
	# The day round the rim, the first period at the top and the rest going round clockwise, and the
	# notch at the period it is now.
	var cycle: Array[bool] = door.cycle() if door != null else ([] as Array[bool])
	var arcs: Array[PackedVector2Array] = []
	var span: float = TAU / float(maxi(cycle.size(), 1))
	for k: int in range(cycle.size()):
		if not cycle[k]:
			continue
		var mid: float = -PI * 0.5 + span * float(k)
		arcs.append_array(RisoDecor.strip(RisoMarks.arc_points(c, RING_R, mid - span * 0.5 + RING_GAP * 0.5, mid + span * 0.5 - RING_GAP * 0.5), RING_W, RING_W))
	if not cycle.is_empty():
		var a: float = -PI * 0.5 + span * float(door.period())
		var out: Vector2 = Vector2(cos(a), sin(a))
		var side: Vector2 = Vector2(-out.y, out.x)
		var tip: Vector2 = c + out * (RING_R + RING_W * 0.5 + 1.0)
		var back: Vector2 = c + out * outer
		arcs.append(PackedVector2Array([tip, back + side * NOTCH_W * 0.5, back - side * NOTCH_W * 0.5]))
	ink.ink(RisoPrint.NIGHT, 1.0, arcs, false)
	# The prerequisite's tag beside it, in the colour of the department it asks for.
	if need[0] != &"":
		var tc: Vector2 = Vector2(c.x + outer + TAG_GAP + tag_half, c.y)
		var sheet: Array[PackedVector2Array] = RisoMarks.paper_shape(tc, TAG)
		RisoPrint.ink_dept(ink, need[0], 1.0, sheet.slice(0, 1))
		ink.knock(RisoPrint.ALL_PLATES, sheet.slice(1, 2))
		var band: StringName = Institute.DEPARTMENTS.get(need[0], &"institute")
		var at: Vector2 = tc + Vector2(0, -EMBLEM_UP)
		var fit: Transform2D = Transform2D(0.0, Vector2(EMBLEM, EMBLEM), 0.0, at)
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoMarks.emblem(band, Vector2.ZERO):
			mark.append(fit * poly)
		ink.knock(RisoPrint.ALL_PLATES, mark)
		var holes: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoMarks.emblem_holes(band, Vector2.ZERO):
			holes.append(fit * poly)
		RisoPrint.ink_dept(ink, need[0], 1.0, holes)
		ink.knock(RisoPrint.ALL_PLATES, _pips(tc + Vector2(0, TAG_PIPS_DOWN), int(need[1])))


## `count` pips in a row, centred on `at`.
func _pips(at: Vector2, count: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in range(count):
		var p: Vector2 = at + Vector2((float(i) - float(count - 1) * 0.5) * PIP_GAP, 0)
		out.append(PackedVector2Array([p + Vector2(0, -PIP), p + Vector2(PIP, 0), p + Vector2(0, PIP), p + Vector2(-PIP, 0)]))
	return out
