extends RisoProp
class_name BoardArt
## The library's timetable board (TimetableBoard): a dark slate in a wooden frame (blue) on the back
## wall of the library's ground floor, BOARD_W cells wide and BOARD_H high, in a soft light of its own.
## Along its top a paper diamond for each period of the day, now's the largest. Then a band for each
## classroom in its department's colour (RisoPrint.DEPT_INKS), shaded with night but in now's column: at its left
## the department's emblem knocked out to paper (RisoMarks.emblem); in each period's column the mark of
## what it teaches then knocked out to paper (RisoGlyph), or a faint dash while it is closed; in now's
## column a paper pip under the mark for each tier taught and, while the class asks for a
## prerequisite, the same tag as on its door (ExamDoorArt: the colour and emblem of the department it
## asks for, a pip for each tier) beside it; and at its right a locator, a
## plan of where the halls stand: the library in paper, the classroom in its colour with a faint line
## to it from the library, a paper chevron under it if it holds the way on.

## The board's size in cells, how far over the floor it hangs (cells), its frame's width, the emblem
## column's and the locator's widths, and its header's height (px).
const BOARD_W: float = 8.0
const BOARD_H: float = 3.2
const BOARD_UP: float = 0.35
const FRAME: float = 12.0
const LABEL_W: float = 84.0
const LOCATOR_W: float = 200.0
const HEADER_H: float = 40.0
## The room between two bands (px), how much night shades a band out of now's column, and the
## emblem's size against a band's height.
const BAND_GAP: float = 6.0
const BAND_SHADE: float = 0.45
const EMBLEM_FIT: float = 0.04
## The marks' size against a band's height, and the pips' size and the room between them (px).
const MARK_FIT: float = 1.0 / 58.0
const PIP: float = 5.0
const PIP_GAP: float = 13.0
## The prerequisite's tag (as a paper's, RisoMarks.paper_shape), how far right of the mark, its
## emblem's size and how far up, and how far down its pips.
const TAG: float = 1.5
const TAG_RIGHT: float = 72.0
const TAG_EMBLEM: float = 1.05
const TAG_EMBLEM_UP: float = 6.0
const TAG_PIPS_DOWN: float = 13.0
## It hangs on the wall with the decor, behind the people and things before it (RisoDecor's layer).
const Z: int = -15
## A locator's inset in its band (px), and how big a hall's spot is in it (px high, half as wide again).
const LOCATOR_IN: float = 9.0
const LOCATOR_SPOT: float = 14.0


func shines() -> bool:
	return true


func _ready() -> void:
	super()
	z_index = Z


func light() -> Array:
	return _light(Vector2(0, _ground() - (BOARD_UP + BOARD_H * 0.5) * half * 2.0), RisoLight.BEACON, -1)


## The board's rectangle, round its host (px).
func _board() -> Rect2:
	var cell: float = half * 2.0
	var g: float = _ground()
	var w: float = BOARD_W * cell
	var h: float = BOARD_H * cell
	return Rect2(-w * 0.5, g - BOARD_UP * cell - h, w, h)


func view_rect() -> Rect2:
	var r: Rect2 = _board().grow(FRAME + 8.0)
	return Rect2(host.global_position + r.position, r.size)


func _draw_art() -> void:
	var board: TimetableBoard = host as TimetableBoard
	if board == null:
		return
	var r: Rect2 = _board()
	var frame: Rect2 = r.grow(FRAME)
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(frame.position.x, frame.position.y, frame.size.x, frame.size.y, 6.0)])
	ink.ink(RisoPrint.NIGHT, 0.92, [RisoShapes.rrect(r.position.x, r.position.y, r.size.x, r.size.y, 3.0)], false)
	var rows: Array[Dictionary] = board.rows()
	var left: float = r.position.x + LABEL_W
	var col_w: float = (r.size.x - LABEL_W - LOCATOR_W) / float(Timetable.PERIODS)
	var now: int = board.period()
	# The periods along the top, now's the largest.
	var marks: Array[PackedVector2Array] = []
	for k: int in range(Timetable.PERIODS):
		var c: Vector2 = Vector2(left + col_w * (float(k) + 0.5), r.position.y + HEADER_H * 0.5)
		var s: float = 12.0 if k == now else 7.0
		marks.append(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]))
	ink.knock(RisoPrint.ALL_PLATES, marks)
	if rows.is_empty():
		return
	var row_h: float = (r.size.y - HEADER_H) / float(rows.size())
	var band_h: float = row_h - BAND_GAP
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		var dept: StringName = row["dept"]
		var y: float = r.position.y + HEADER_H + row_h * (float(i) + 0.5)
		var top: float = y - band_h * 0.5
		# The band: its colour in the emblem's column and now's, shaded with night in the others.
		RisoPrint.ink_dept(ink, dept, 1.0, [RisoShapes.rrect(r.position.x + 4.0, top, LABEL_W - 4.0, band_h, 4.0)])
		for k: int in range(Timetable.PERIODS):
			var cell: PackedVector2Array = RisoShapes.rrect(left + col_w * float(k) + 2.0, top, col_w - 4.0, band_h, 3.0)
			RisoPrint.ink_dept(ink, dept, 1.0, [cell])
			if k != now:
				ink.ink(RisoPrint.NIGHT, BAND_SHADE, [cell], false)
		# The department's emblem.
		var dc: Vector2 = Vector2(r.position.x + LABEL_W * 0.5 + 2.0, y)
		var band_of: StringName = Institute.DEPARTMENTS.get(dept, &"institute")
		var fit: Transform2D = Transform2D(0.0, Vector2.ONE * band_h * EMBLEM_FIT, 0.0, dc)
		var emblem: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoMarks.emblem(band_of, Vector2.ZERO):
			emblem.append(fit * poly)
		ink.knock(RisoPrint.ALL_PLATES, emblem)
		var holes: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoMarks.emblem_holes(band_of, Vector2.ZERO):
			holes.append(fit * poly)
		RisoPrint.ink_dept(ink, dept, 1.0, holes)
		# What it teaches in each period.
		var subjects: Array = row["subjects"]
		for k: int in range(subjects.size()):
			var c: Vector2 = Vector2(left + col_w * (float(k) + 0.5), y)
			var a: StringName = subjects[k]
			if a == &"":
				ink.knock(RisoPrint.ALL_PLATES, [RisoShapes.rrect(c.x - 12.0, c.y - 2.0, 24.0, 4.0, 2.0)])
				continue
			var lift: float = band_h * 0.12 if k == now else 0.0
			var mark: Array[PackedVector2Array] = []
			for poly: PackedVector2Array in RisoGlyph.of(a, Vector2.ZERO, t):
				mark.append(Transform2D(0.0, Vector2.ONE * band_h * MARK_FIT, 0.0, c + Vector2(0, -lift)) * poly)
			ink.knock(RisoPrint.ALL_PLATES, mark)
			if k != now:
				continue
			ink.knock(RisoPrint.ALL_PLATES, _pips(c + Vector2(0, band_h * 0.34), int(row["tier"])))
			var need: Array = row["need"]
			if need[0] != &"":
				var tc: Vector2 = c + Vector2(TAG_RIGHT, 0)
				var sheet: Array[PackedVector2Array] = RisoMarks.paper_shape(tc, TAG)
				RisoPrint.ink_dept(ink, need[0], 1.0, sheet.slice(0, 1))
				ink.knock(RisoPrint.ALL_PLATES, sheet.slice(1, 2))
				var need_band: StringName = Institute.DEPARTMENTS.get(need[0], &"institute")
				var tag_fit: Transform2D = Transform2D(0.0, Vector2.ONE * TAG_EMBLEM, 0.0, tc + Vector2(0, -TAG_EMBLEM_UP))
				var tag_mark: Array[PackedVector2Array] = []
				for poly: PackedVector2Array in RisoMarks.emblem(need_band, Vector2.ZERO):
					tag_mark.append(tag_fit * poly)
				ink.knock(RisoPrint.ALL_PLATES, tag_mark)
				var tag_holes: Array[PackedVector2Array] = []
				for poly: PackedVector2Array in RisoMarks.emblem_holes(need_band, Vector2.ZERO):
					tag_holes.append(tag_fit * poly)
				RisoPrint.ink_dept(ink, need[0], 1.0, tag_holes)
				ink.knock(RisoPrint.ALL_PLATES, _pips(tc + Vector2(0, TAG_PIPS_DOWN), int(need[1])))
		_locator(board, Rect2(r.end.x - LOCATOR_W + 2.0, top, LOCATOR_W - 6.0, band_h), row)


## The halls in small in `area`, as a plan of where they stand (the stretch of the level holding
## them, TimetableBoard.halls_bounds, stretched to fill it): the library in paper, the classroom `row`
## stands in its department's colour, a faint line between them, and a paper chevron under it if it
## holds the way on.
func _locator(board: TimetableBoard, area: Rect2, row: Dictionary) -> void:
	ink.lift_ink([RisoPrint.NIGHT], 0.18, [RisoShapes.rrect(area.position.x, area.position.y, area.size.x, area.size.y, 3.0)])
	var inner: Rect2 = area.grow(-LOCATOR_IN)
	var bounds: Rect2i = board.halls_bounds()
	var to: Callable = func(v: Vector2) -> Vector2:
		return inner.position + (v - Vector2(bounds.position)) / Vector2(bounds.size) * inner.size
	var library: Rect2i = board.library_box()
	var box_of: Rect2i = row["box"]
	var a: Vector2 = to.call(Vector2(library.position) + Vector2(library.size) * 0.5)
	var b: Vector2 = to.call(Vector2(box_of.position) + Vector2(box_of.size) * 0.5)
	ink.lift_ink([RisoPrint.NIGHT], 0.6, RisoDecor.strip(PackedVector2Array([a, b]), 3.0, 3.0))
	ink.knock(RisoPrint.ALL_PLATES, [_spot(a)])
	var room: PackedVector2Array = _spot(b)
	RisoPrint.ink_dept(ink, row["dept"], 1.0, [room])
	if bool(row["way_on"]):
		ink.knock(RisoPrint.ALL_PLATES, [RisoMarks.chevron(b + Vector2(0, LOCATOR_SPOT * 0.5 + 7.0), Vector2.DOWN, 0.35)])


## A hall's spot in a locator, round `c`.
func _spot(c: Vector2) -> PackedVector2Array:
	return RisoShapes.rrect(c.x - LOCATOR_SPOT * 0.7, c.y - LOCATOR_SPOT * 0.5, LOCATOR_SPOT * 1.4, LOCATOR_SPOT, 2.0)


## `count` pips in a row, centred on `at`.
func _pips(at: Vector2, count: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in range(count):
		var p: Vector2 = at + Vector2((float(i) - float(count - 1) * 0.5) * PIP_GAP, 0)
		out.append(PackedVector2Array([p + Vector2(0, -PIP), p + Vector2(PIP, 0), p + Vector2(0, PIP), p + Vector2(-PIP, 0)]))
	return out
