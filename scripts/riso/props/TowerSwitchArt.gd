extends RisoProp
## A crag tower's switch (TowerSwitch): a heavy lever in a stone base, and over it a paper board
## showing the gondola's line straight, its cable running from the bottom station (left) to the top
## (right, a chevron at that end): each station lit in accent with a paper glint while it is on, a
## small night disc while it is off, and a ring round each this switch flips (a solid band of night
## with paper between it and the station, no outline). The lever leans the way it was last thrown;
## locked (the tower flipped last), its knob is pink and a pink bar crosses the board, and a balk
## shakes it. A cold tower's (TowerSwitch.cold) knob is dull night and blue, its board screened in
## night with paper flecks of frost on it, until a strike on the tower's spire wakes it.

## The board: how big it is drawn against its measures here, how far apart its stations stand, its
## margin either end, its height (pixels, before the scale) and how high over the floor its middle
## stands (pixels).
const BOARD_SCALE: float = 0.62
const STATION_GAP: float = 40.0
const BOARD_PAD: float = 26.0
const BOARD_HIGH: float = 66.0
const BOARD_UP: float = 168.0
## A station lit (its disc, the glow round it, the glint), dark, and the ring round one it flips
## (inner and outer radius).
const LIT: float = 11.0
const GLOW: float = 3.5
const GLINT: float = 3.6
const DARK: float = 9.0
const RING: Vector2 = Vector2(15.5, 21.0)


## The TowerSwitch it dresses.
var lever: TowerSwitch:
	get:
		return host as TowerSwitch


func shines() -> bool:
	return true


## Lit at its knob while it can be flipped.
func light() -> Array:
	if lever == null or lever.locked() or lever.cold():
		return []
	return _light(Vector2(0, _ground() - 100.0), RisoLight.GLEAM, RisoPrint.ACCENT)


func _draw_art() -> void:
	var s: TowerSwitch = lever
	if s == null:
		return
	var g: float = _ground()
	var locked: bool = s.locked()
	var shake: float = sin((s.t - s.balked_at) * 60.0) * 4.0 * clampf(1.0 - (s.t - s.balked_at) / 0.3, 0.0, 1.0)
	var flip: float = clampf((s.t - s.flipped_at) / 0.25, 0.0, 1.0)
	# The lever: thrown toward the side its tower last left it (each flip swings it over).
	var side: float = 1.0 if locked else -1.0
	var tilt: float = side * 0.55 * (2.0 * flip - 1.0 if s.t - s.flipped_at < 0.25 else 1.0) + shake * 0.01
	var pivot: Vector2 = Vector2(shake, g - 44.0)
	var arm: Transform2D = Transform2D(tilt, pivot)
	var knob: Vector2 = arm * Vector2(0, -80)
	ink.ink(RisoPrint.BLUE, 1.0, [arm * RisoShapes.rrect(-5.5, -78.0, 11.0, 78.0, 5.5)])
	var base: PackedVector2Array = RisoShapes.rrect(-52, g - 46, 104, 46, 10)
	ink.ink(RisoPrint.BLUE, 1.0, [base])
	ink.ink(RisoPrint.NIGHT, 0.35, [RisoShapes.rrect(-52, g - 12, 104, 12, 5)], false)
	ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.rrect(-22, g - 46, 44, 8, 4)], false)
	var ball: PackedVector2Array = RisoShapes.circle(knob, 14.0, 20)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [ball])
	var cold: bool = s.cold()
	if cold:
		ink.ink(RisoPrint.BLUE, 0.7, [ball], false)
	else:
		ink.ink(RisoPrint.PINK if locked else RisoPrint.ACCENT, 1.0, [ball], false)
	# The board: the line, straight.
	var n: int = s.station_count()
	if n <= 0:
		return
	var wide: float = BOARD_PAD * 2.0 + STATION_GAP * float(n - 1)
	# Laid out about the board's middle in its own measures, then drawn BOARD_SCALE as big there.
	var xb: Transform2D = Transform2D(0.0, Vector2(BOARD_SCALE, BOARD_SCALE), 0.0, Vector2(shake, g - BOARD_UP))
	var left: float = -wide * 0.5
	var board: PackedVector2Array = xb * RisoShapes.rrect(left, -BOARD_HIGH * 0.5, wide, BOARD_HIGH, 9.0)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.PINK], [board])
	ink.ink(RisoPrint.BLUE, 0.16, [board], false)
	var y: float = 2.0
	var first: float = left + BOARD_PAD
	var last: float = first + STATION_GAP * float(n - 1)
	ink.ink(RisoPrint.NIGHT, 0.55, [xb * RisoShapes.rrect(first, y - 1.75, last - first, 3.5, 0.0), xb * PackedVector2Array([Vector2(left + wide - 8.0, y), Vector2(left + wide - 14.0, y - 5.0), Vector2(left + wide - 14.0, y + 5.0)])], false)
	var rings: Array[PackedVector2Array] = []
	var gaps: Array[PackedVector2Array] = []
	var glows: Array[PackedVector2Array] = []
	var lit: Array[PackedVector2Array] = []
	var glints: Array[PackedVector2Array] = []
	var dark: Array[PackedVector2Array] = []
	for k: int in range(n):
		var p: Vector2 = Vector2(first + STATION_GAP * float(k), y)
		if s.mask & (1 << k) != 0:
			rings.append(xb * RisoShapes.circle(p, RING.y, 28))
			gaps.append(xb * RisoShapes.circle(p, RING.x, 24))
		if s.map_info != null and s.map_info.station_on(k):
			glows.append(xb * RisoShapes.circle(p, LIT + GLOW, 20))
			lit.append(xb * RisoShapes.circle(p, LIT, 18))
			glints.append(xb * RisoShapes.circle(p + Vector2(-3.0, -3.0), GLINT, 10))
		else:
			dark.append(xb * RisoShapes.circle(p, DARK, 16))
	# The ring: a band of night, the paper between it and the station knocked clear inside it.
	ink.ink(RisoPrint.NIGHT, 1.0, rings, false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], gaps)
	ink.ink(RisoPrint.ACCENT, 0.35, glows, false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], lit)
	ink.ink(RisoPrint.ACCENT, 1.0, lit, false)
	ink.knock([RisoPrint.ACCENT], glints)
	ink.ink(RisoPrint.NIGHT, 1.0, dark, false)
	if locked:
		ink.ink(RisoPrint.PINK, 0.9, [xb * RisoShapes.rrect(left + 5.0, y - 3.0, wide - 10.0, 6.0, 3.0)], false)
	if cold:
		ink.ink(RisoPrint.NIGHT, 0.45, [board], false)
		var frost: Array[PackedVector2Array] = []
		for k: int in range(7):
			frost.append(xb * RisoShapes.sparkle(Vector2(left + 8.0 + (wide - 16.0) * RisoShapes.hash1(float(k) * 2.3 + 0.5), (RisoShapes.hash1(float(k) * 5.1 + 1.0) - 0.5) * (BOARD_HIGH - 14.0)), 4.0, 1.0))
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], frost)
