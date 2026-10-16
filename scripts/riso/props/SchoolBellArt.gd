extends RisoProp
## A bell of the institute's timetable (SchoolBell): a slim post in blue with a bracket at its head,
## a hand bell in accent ink hanging from it on a short night rope, swinging hard and ringing out in
## fading arcs when rung. The corridor's bell stands beside the timetable (`board`): a wooden board on
## two legs, its paper face ruled into a column for each period and a row for each hall with a class
## (Timetable.TIMETABLED, in the halls' order), each row headed by the hall's mark (a lecture hall's
## master's spell, RisoGlyph; the library's open book; the exam's portcullis bars, pink) and its
## periods in session filled in blue (the exam's in pink). A night pointer stands over the period it
## is now; in passing time it bobs, waiting for the wizard to go in somewhere.

## The board: where it stands (px from the post, across), how wide its face is, a row's height and
## the room for each row's mark.
const BOARD_X: float = 20.0
const BOARD_W: float = 100.0
const ROW: float = 15.0
const HEAD: float = 18.0
## How big a spell's mark is printed on the board (RisoGlyph's size, times this).
const MARK: float = 0.26


func shines() -> bool:
	return true


## Lit softly, so it reads as something to use.
func light() -> Array:
	return _light(Vector2(-26.0, _ground() - 118.0), RisoLight.GLEAM, RisoPrint.ACCENT)


func _draw_art() -> void:
	var bell: SchoolBell = host as SchoolBell
	var g: float = _ground()
	var since: float = bell.since_rung if bell != null else 99.0
	var post_x: float = -40.0 if bell != null and bell.board else 0.0
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(post_x - 4.0, g - 150.0, 8.0, 150.0, 3.0), RisoShapes.rrect(post_x - 4.0, g - 150.0, 34.0, 7.0, 3.0),
		RisoShapes.rrect(post_x - 14.0, g - 6.0, 28.0, 6.0, 3.0)])
	var swing: float = sin(t * 1.2 + phase) * 0.04
	if since < 2.5:
		swing = sin(since * 10.0) * 0.55 * exp(-since * 1.4)
	var hang: Transform2D = Transform2D(swing, Vector2(1.6, 1.6), 0.0, Vector2(post_x + 24.0, g - 143.0))
	var body: PackedVector2Array = hang * RisoShapes.smooth(PackedVector2Array([Vector2(-3, 8), Vector2(-7, 14), Vector2(-9, 24), Vector2(-14, 32), Vector2(14, 32), Vector2(9, 24), Vector2(7, 14), Vector2(3, 8)]), 3)
	ink.ink(RisoPrint.NIGHT, 1.0, [hang * RisoShapes.rrect(-1.2, 0.0, 2.4, 9.0, 1.2)], false)
	ink.ink(RisoPrint.ACCENT, 1.0, [body])
	ink.ink(RisoPrint.NIGHT, 0.3, [hang * RisoShapes.smooth(PackedVector2Array([Vector2(3, 10), Vector2(8, 16), Vector2(9, 24), Vector2(14, 32), Vector2(5, 32)]), 3)], false)
	# Its rope, hanging from the clapper to within reach.
	ink.ink(RisoPrint.NIGHT, 0.9, [hang * RisoShapes.circle(Vector2(-swing * 26.0, 35.0), 3.6, 10)], false)
	ink.ink(RisoPrint.NIGHT, 0.8, RisoDecor.strip(PackedVector2Array([hang * Vector2(-swing * 26.0, 36.0), Vector2(post_x + 24.0 + swing * 30.0, g - 58.0)]), 2.4, 2.0), false)
	ink.ink(RisoPrint.NIGHT, 0.8, [RisoShapes.circle(Vector2(post_x + 24.0 + swing * 30.0, g - 56.0), 4.0, 10)], false)
	if since < 1.6:
		var arcs: Array[PackedVector2Array] = []
		for k: int in range(3):
			var u: float = fmod(since * 1.4 + float(k) / 3.0, 1.0)
			for side: float in [0.0, PI]:
				arcs.append_array(RisoDecor.strip(RisoMarks.arc_points(hang * Vector2(0, 20), 24.0 + u * 64.0, side - 0.9, side + 0.9), 3.0, 3.0))
		ink.ink(RisoPrint.ACCENT, 0.7 * (1.0 - since / 1.6), arcs, false)
	if bell != null and bell.board:
		_board(bell, g)


## The timetable's board beside the post (see the class description).
func _board(bell: SchoolBell, g: float) -> void:
	var info: MapInfo = bell.map_info
	if info == null or info.world == null:
		return
	var w: LevelGen = info.world
	var rows: Array[int] = []
	for i: int in range(w.halls.size()):
		if w.halls[i]["kind"] in Timetable.TIMETABLED:
			rows.append(i)
	var rec: LevelRecord = info.record()
	var h: float = HEAD + ROW * float(rows.size()) + 8.0
	var top: float = g - 44.0 - h
	var x0: float = BOARD_X - BOARD_W * 0.5 + 30.0
	# Its legs and frame, then its paper face.
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(x0 + 8.0, top + h - 4.0, 6.0, g - (top + h) + 4.0, 2.0), RisoShapes.rrect(x0 + BOARD_W - 14.0, top + h - 4.0, 6.0, g - (top + h) + 4.0, 2.0),
		RisoShapes.rrect(x0 - 5.0, top - 5.0, BOARD_W + 10.0, h + 10.0, 4.0)])
	var face: PackedVector2Array = RisoShapes.rrect(x0, top, BOARD_W, h, 2.0)
	ink.knock(RisoPrint.ALL_PLATES, [face])
	var col_w: float = (BOARD_W - HEAD - 6.0) / float(Timetable.PERIODS)
	var cells: Array[PackedVector2Array] = []
	var exam_cells: Array[PackedVector2Array] = []
	var rules: Array[PackedVector2Array] = []
	for r: int in range(rows.size()):
		var hall: int = rows[r]
		var y: float = top + HEAD + ROW * float(r)
		rules.append(RisoShapes.rrect(x0 + 3.0, y - 1.0, BOARD_W - 6.0, 1.2, 0.6))
		var c: Vector2 = Vector2(x0 + HEAD * 0.5 + 2.0, y + ROW * 0.5)
		match w.halls[hall]["kind"]:
			&"lecture":
				var m: Vector2i = Timetable.master_of(w, hall)
				if m.x >= 0:
					var mark: Array[PackedVector2Array] = []
					for poly: PackedVector2Array in RisoGlyph.of(StringName((w.get_cell(m).extra_info as Dictionary)["ability"]), Vector2.ZERO, t):
						mark.append(Transform2D(0.0, Vector2(MARK, MARK), 0.0, c) * poly)
					ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
			&"library":
				ink.ink(RisoPrint.NIGHT, 1.0, [PackedVector2Array([c + Vector2(-6, -3), c + Vector2(0, -1), c + Vector2(0, 5), c + Vector2(-6, 3)]),
					PackedVector2Array([c + Vector2(0, -1), c + Vector2(6, -3), c + Vector2(6, 3), c + Vector2(0, 5)])], false)
			&"exam":
				var bars: Array[PackedVector2Array] = []
				for k: int in range(3):
					bars.append(RisoShapes.rrect(c.x - 5.0 + float(k) * 4.0, c.y - 5.0, 2.0, 10.0, 1.0))
				bars.append(RisoShapes.rrect(c.x - 6.0, c.y - 2.0, 12.0, 2.0, 1.0))
				ink.ink(RisoPrint.PINK, 1.0, bars, false)
		for p: int in range(Timetable.PERIODS):
			if not Timetable.in_session(w, hall, p):
				continue
			var box: PackedVector2Array = RisoShapes.rrect(x0 + HEAD + 3.0 + col_w * float(p) + 1.5, y + 2.5, col_w - 3.0, ROW - 5.0, 1.5)
			if w.halls[hall]["kind"] == &"exam":
				exam_cells.append(box)
			else:
				cells.append(box)
	ink.ink(RisoPrint.NIGHT, 0.35, rules, false)
	ink.ink(RisoPrint.BLUE, 1.0, cells, false)
	ink.ink(RisoPrint.PINK, 1.0, exam_cells, false)
	# The pointer over the period it is now, bobbing in passing time.
	var bob: float = absf(sin(t * 4.0)) * 4.0 if rec.passing else 0.0
	var px: float = x0 + HEAD + 3.0 + col_w * (float(posmod(rec.period, Timetable.PERIODS)) + 0.5)
	ink.ink(RisoPrint.NIGHT, 1.0, [RisoMarks.chevron(Vector2(px, top + 8.0 - bob), Vector2.DOWN, 0.32)], false)
