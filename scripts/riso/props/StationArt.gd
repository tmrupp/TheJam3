extends RisoProp
## A gondola's station (GondolaStation), drawn about its doorway: a paper board on the rock over the
## doorway with a little cable car and the station's number in dots, a blue frame down either side
## of the doorway (faint once the station is open, in the background, so the way through reads as
## open), a striped boarding step across its floor reaching out to the car, and the call
## switch in the doorway, a blue box on the frame by the car bearing the car in paper over its paper
## button, which blinks while the car is on its way here and is dim while the station is shut.

## The call switch: its box (size, and how high its middle is over the floor), how far its middle is
## in from the doorway's edge by the car, and its button (radius).
const SWITCH: Vector2 = Vector2(34.0, 62.0)
const SWITCH_UP: float = 70.0
const SWITCH_IN: float = 24.0
const BUTTON: float = 8.0
## The board over the doorway (size, and how far over the doorway's top its middle is), and the
## number's dots.
const BOARD: Vector2 = Vector2(100.0, 38.0)
const BOARD_UP: float = 32.0
const DOT: float = 3.5
## How far the boarding step reaches out past the doorway toward the car, and how thick it is.
const STEP_OUT: float = 20.0
const STEP_H: float = 12.0
## How strongly the doorway's frame is inked while the station is shut, and once it is open.
const FRAME_SHUT: float = 1.0
const FRAME_OPEN: float = 0.3
## How fast the button blinks while the car comes (blinks a second).
const BLINK: float = 3.0


## The GondolaStation it dresses.
var station: GondolaStation:
	get:
		return host as GondolaStation


## It reaches over the doorway, the board over it and the step out to the car.
func view_rect() -> Rect2:
	if host == null:
		return Rect2()
	return Rect2(host.global_position - Vector2(half * 2.0, half * 3.0), Vector2(half * 4.0, half * 4.5))


func _draw_art() -> void:
	if station == null or station.gondola == null or not is_instance_valid(station.gondola) or station.gondola.stale():
		return
	var g: float = _ground()
	var cell: float = half * 2.0
	# The car's side of the doorway (it stands in the doorway, its landing the other way).
	var side: float = -float(station.inner)
	var door_x: float = 0.0
	var top: float = g - cell
	# The frame down either side of the doorway, and the step across its floor out to the car.
	var gondola: Gondola = station.gondola
	var frame: Array[PackedVector2Array] = []
	for e: float in [-1.0, 1.0]:
		frame.append(RisoShapes.rrect(door_x + e * (half - 5.0) - 5.0, top, 10.0, cell - STEP_H, 3.0))
	ink.ink(RisoPrint.BLUE, FRAME_OPEN if gondola.is_open(station.index) else FRAME_SHUT, frame)
	var step_l: float = minf(door_x - half, door_x - half + side * STEP_OUT)
	var step_w: float = cell + STEP_OUT
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(step_l, g - STEP_H, step_w, STEP_H, 4.0)])
	var ticks: Array[PackedVector2Array] = []
	var n: int = int(step_w / 18.0)
	for k: int in range(n):
		ticks.append(RisoShapes.rrect(step_l + 6.0 + float(k) * 18.0, g - STEP_H + 3.0, 9.0, 4.0, 1.5))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], ticks)
	# The board over the doorway: paper, with the car and the station's number.
	var board_c: Vector2 = Vector2(door_x, top - BOARD_UP)
	var board: PackedVector2Array = RisoShapes.rrect(board_c.x - BOARD.x * 0.5, board_c.y - BOARD.y * 0.5, BOARD.x, BOARD.y, 9.0)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.PINK], [board])
	ink.ink(RisoPrint.BLUE, 0.18, [board], false)
	ink.ink(RisoPrint.NIGHT, 0.85, _car_glyph(board_c + Vector2(-BOARD.x * 0.5 + 24.0, 3.0), 11.0), false)
	var dots: Array[PackedVector2Array] = []
	var count: int = station.index + 1
	for k: int in range(count):
		var row: int = k % 3
		@warning_ignore("integer_division")
		var col: int = k / 3
		dots.append(RisoShapes.circle(board_c + Vector2(4.0 + float(col) * 10.0, -9.0 + float(row) * 9.0), DOT, 8))
	ink.ink(RisoPrint.NIGHT, 0.85, dots, false)
	# The call switch on the frame by the car.
	var box_c: Vector2 = Vector2(side * (half - SWITCH_IN), g - SWITCH_UP)
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(box_c.x - SWITCH.x * 0.5, box_c.y - SWITCH.y * 0.5, SWITCH.x, SWITCH.y, 6.0)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], _car_glyph(box_c + Vector2(0.0, -11.0), 9.5))
	var button: PackedVector2Array = RisoShapes.circle(box_c + Vector2(0.0, 16.0), BUTTON, 12)
	if not gondola.is_open(station.index):
		ink.ink(RisoPrint.NIGHT, 0.5, [button], false)
	elif not station.called() or fmod(t * BLINK, 1.0) < 0.6:
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [button])


## A little cable car centred at `c`, `r` across from its middle: a cable, a hanger and a body.
func _car_glyph(c: Vector2, r: float) -> Array[PackedVector2Array]:
	return [
		RisoShapes.rrect(c.x - r * 1.4, c.y - r * 1.25, r * 2.8, maxf(2.0, r * 0.22), 1.0),
		RisoShapes.rrect(c.x - r * 0.12, c.y - r * 1.2, r * 0.24, r * 0.7, 1.0),
		RisoShapes.rrect(c.x - r, c.y - r * 0.55, r * 2.0, r * 1.3, r * 0.35),
	]
