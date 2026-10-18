extends RisoProp
## A cord of the institute's great bell (SchoolBell): a thick cord of spell light in accent ink, a
## soft halo round it and fine night twists along it, hanging all the way from the ceiling to a
## tassel within reach; pulled, it jerks down and springs back. While the bell rings out
## (MapInfo.since_bell, BELL_TIME) every cord sways, fixed at the top and swinging free below,
## less and less. A hall's cord goes up into the ceiling through a dark socket with a gold pulley.
## The corridor's cord (`great`) hangs from the great bell itself: a big bell of accent ink on a
## blue yoke under the ceiling, shaded in night, its clapper the cord's top; rung, it swings hard
## and rings out in fading accent arcs. Along its yoke the periods of a block are marked
## (Timetable.PERIODS small diamonds knocked to paper): the one it is now swells in accent, bobbing in
## passing time while it waits for the wizard to go into a class.

## The period marks on the yoke: their size, and the room between them (px).
const MARK_R: float = 6.0
const MARK_GAP: float = 22.0
## The cord: how wide, how high its tassel hangs over the floor (px, its bottom), how many points
## along it, and how far a pull jerks it down (px).
const CORD_W: float = 9.0
const TASSEL_UP: float = 34.0
const CORD_POINTS: int = 16
const PULL: float = 18.0
## How far (px) the cord sways while the bell rings out, at its foot, and how fast.
const SWAY: float = 22.0
const SWAY_SPEED: float = 9.0
## The great bell: its height at most (px; less under a low ceiling, leaving BELL_HEADROOM over the
## floor), its width against its height, and how far it swings when rung (radians).
const BELL_H: float = 150.0
const BELL_HEADROOM: float = 210.0
const BELL_WIDE: float = 1.05
const BELL_SWING: float = 0.32


func shines() -> bool:
	return true


## Lit softly at its tassel, so it reads as something to use.
func light() -> Array:
	var bell: SchoolBell = host as SchoolBell
	return _light(Vector2(0.0, _ground() - TASSEL_UP - 20.0), RisoLight.GLEAM, RisoPrint.ACCENT)


## The cord reaches far over its cell, up to the ceiling: in view by all of it.
func view_rect() -> Rect2:
	var bell: SchoolBell = host as SchoolBell
	var up: float = float(bell.reach) * half * 2.0 if bell != null else half * 2.0
	return Rect2(host.global_position + Vector2(-140.0, _ground() - up), Vector2(300.0, up))


func _draw_art() -> void:
	var bell: SchoolBell = host as SchoolBell
	if bell == null:
		return
	var g: float = _ground()
	var info: MapInfo = bell.map_info
	var ringing: float = info.since_bell if info != null else 99.0
	var fade: float = clampf(1.0 - ringing / MapInfo.BELL_TIME, 0.0, 1.0)
	var x: float = 0.0
	var ceiling: float = g - float(bell.reach) * half * 2.0
	var top: float = ceiling
	var swing: float = sin(t * 0.9 + phase) * 0.01
	var bell_h: float = 0.0
	if bell.great:
		bell_h = clampf(float(bell.reach) * half * 2.0 - BELL_HEADROOM, 0.0, BELL_H)
		if fade > 0.0:
			swing = sin(ringing * 5.0) * BELL_SWING * fade
	if bell_h > 30.0:
		top = _great_bell(Vector2(x, ceiling), bell_h, swing, fade, ringing)
	else:
		# Up into the ceiling through a dark socket, over a gold pulley.
		ink.ink(RisoPrint.NIGHT, 0.9, [RisoShapes.ellipse(Vector2(x, ceiling + 2.0), 16.0, 6.0, 16)], false)
		ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(Vector2(x, ceiling + 9.0), 7.0, 14)])
		ink.ink(RisoPrint.NIGHT, 0.8, [RisoShapes.circle(Vector2(x, ceiling + 9.0), 2.5, 8)], false)
		top = ceiling + 9.0
	var pull: float = PULL * clampf(1.0 - bell.since_rung / 0.35, 0.0, 1.0) * sin(clampf(bell.since_rung / 0.35, 0.0, 1.0) * PI)
	var foot: float = g - TASSEL_UP + pull
	var cord: PackedVector2Array = PackedVector2Array()
	for i: int in range(CORD_POINTS + 1):
		var u: float = float(i) / float(CORD_POINTS)
		var y: float = lerpf(top, foot - 14.0, u)
		var sway: float = sin(ringing * SWAY_SPEED - u * 2.4) * SWAY * fade * u
		cord.append(Vector2(x + sway, y))
	var tip: Vector2 = cord[CORD_POINTS]
	# A soft halo of its light, the cord itself, its twists.
	ink.ink(RisoPrint.ACCENT, 0.16 + 0.12 * fade, RisoDecor.strip(cord, CORD_W * 3.0, CORD_W * 3.0))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], RisoDecor.strip(cord, CORD_W, CORD_W))
	ink.ink(RisoPrint.ACCENT, 1.0, RisoDecor.strip(cord, CORD_W, CORD_W))
	var twists: Array[PackedVector2Array] = []
	var steps: int = int((cord[CORD_POINTS].y - cord[0].y) / 13.0)
	for k: int in range(steps):
		var u: float = (float(k) + 0.5) / float(maxi(steps, 1))
		var at: Vector2 = cord[0].lerp(cord[CORD_POINTS], u)
		var i0: int = mini(int(u * float(CORD_POINTS)), CORD_POINTS - 1)
		at.x = cord[i0].x
		twists.append(PackedVector2Array([at + Vector2(-CORD_W * 0.5, -2.0), at + Vector2(CORD_W * 0.5, -6.0), at + Vector2(CORD_W * 0.5, -4.0), at + Vector2(-CORD_W * 0.5, 0.0)]))
	ink.ink(RisoPrint.NIGHT, 0.35, twists, false)
	# Its tassel: a knot and a fringe, within reach.
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(tip + Vector2(0, 2.0), 8.0, 14)])
	var fringe: PackedVector2Array = PackedVector2Array([tip + Vector2(-7, 6), tip + Vector2(7, 6), tip + Vector2(10, 26), tip + Vector2(-10, 26)])
	ink.ink(RisoPrint.ACCENT, 1.0, [fringe])
	var strands: Array[PackedVector2Array] = []
	for k: int in range(4):
		var sx: float = -6.0 + float(k) * 4.0
		strands.append(RisoShapes.rrect(tip.x + sx, tip.y + 10.0, 1.4, 15.0, 0.7))
	ink.ink(RisoPrint.NIGHT, 0.4, strands, false)
	if bell.great and info != null:
		_marks(info, Vector2(x, ceiling + 6.0))


## The great bell hung from the ceiling at `at` (the middle of its yoke), `h` tall, swung `swing`
## radians, ringing out while `fade` is above 0 (`ringing` seconds since it rang). Returns where the
## cord hangs from (its clapper).
func _great_bell(at: Vector2, h: float, swing: float, fade: float, ringing: float) -> float:
	var w: float = h * BELL_WIDE
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(at.x - w * 0.55, at.y, w * 1.1, 12.0, 3.0), RisoShapes.rrect(at.x - 5.0, at.y + 8.0, 10.0, 14.0, 3.0)])
	var hang: Transform2D = Transform2D(swing, Vector2(h / 100.0, h / 100.0), 0.0, at + Vector2(0, 20.0))
	# A bell's profile, 100 units tall, from its crown at the top to its lip.
	var profile: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([Vector2(-8, 0), Vector2(-24, 6), Vector2(-30, 24), Vector2(-33, 56), Vector2(-40, 82),
		Vector2(-52, 96), Vector2(52, 96), Vector2(40, 82), Vector2(33, 56), Vector2(30, 24), Vector2(24, 6), Vector2(8, 0)]), 3)
	var body: PackedVector2Array = hang * profile
	ink.knock(RisoPrint.ALL_PLATES, [body])
	ink.ink(RisoPrint.ACCENT, 1.0, [body])
	ink.ink(RisoPrint.NIGHT, 0.32, [hang * RisoShapes.smooth(PackedVector2Array([Vector2(8, 4), Vector2(22, 10), Vector2(28, 28), Vector2(32, 58), Vector2(40, 84), Vector2(52, 96), Vector2(18, 96), Vector2(16, 60)]), 3)], false)
	ink.ink(RisoPrint.NIGHT, 0.5, [hang * RisoShapes.rrect(-50.0, 88.0, 100.0, 5.0, 2.5), hang * RisoShapes.rrect(-34.0, 40.0, 68.0, 3.0, 1.5)], false)
	var clapper: Vector2 = hang * Vector2(-swing * 40.0, 100.0)
	ink.ink(RisoPrint.NIGHT, 0.95, [RisoShapes.circle(clapper, h * 0.07, 12)], false)
	if fade > 0.0:
		var arcs: Array[PackedVector2Array] = []
		for k: int in range(4):
			var u: float = fmod(ringing * 0.9 + float(k) / 4.0, 1.0)
			for side: float in [0.0, PI]:
				arcs.append_array(RisoDecor.strip(RisoMarks.arc_points(hang * Vector2(0, 50.0), h * 0.7 + u * h * 1.6, side - 0.8, side + 0.8), 4.0, 4.0))
		ink.ink(RisoPrint.ACCENT, 0.6 * fade, arcs, false)
	return clapper.y


## The block's periods marked along the great bell's yoke, its middle at `at` (see the class
## description).
func _marks(info: MapInfo, at: Vector2) -> void:
	var rec: LevelRecord = info.record()
	var now: int = Timetable.period(rec.rings)
	var marks: Array[PackedVector2Array] = []
	var lit: PackedVector2Array = PackedVector2Array()
	for p: int in range(Timetable.PERIODS):
		var c: Vector2 = at + Vector2((float(p) - float(Timetable.PERIODS - 1) * 0.5) * MARK_GAP, 0.0)
		var r: float = MARK_R * (1.5 if p == now else 1.0)
		if p == now and rec.passing:
			c.y += absf(sin(t * 4.0)) * 3.0
		var mark: PackedVector2Array = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		marks.append(mark)
		if p == now:
			lit = mark
	ink.knock(RisoPrint.ALL_PLATES, marks)
	if not lit.is_empty():
		ink.ink(RisoPrint.ACCENT, 1.0, [lit])
