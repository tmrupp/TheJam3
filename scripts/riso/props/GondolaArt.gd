extends RisoProp
## A gondola (Gondola): its cable round the whole circuit with a pulley wheel at each corner, and
## the car hung from the cable on a hanger with a wheel
## running along it: a roof and a floor of blue, corner posts, a low screened panel round the lower
## half, and its lever on the back wall (leaning the way it will run, upright while it stands). Its
## sides are barred while shut: pink while its rider is shut in (danger), blue otherwise.

## How far over the car's floor the cable runs (cells), and the wheels' size (pixels).
const CABLE_UP: float = 2.55
const WHEEL: float = 13.0


## The Gondola it dresses.
var car: Gondola:
	get:
		return host as Gondola


## The cable runs round the whole level: animate while any of it is in view.
func view_rect() -> Rect2:
	if car == null or car.stations.is_empty():
		return Rect2()
	var lo: Vector2 = car.world_at(0.0)
	var hi: Vector2 = car.world_at(float(car.loop.size.y + car.loop.size.x))
	return Rect2(lo, Vector2.ZERO).expand(hi + Vector2(0.0, -car.cell_px * CABLE_UP)).grow(car.cell_px * 1.5)


func _draw_art() -> void:
	if car == null or car.stations.is_empty():
		return
	var cell: float = car.cell_px
	var up: Vector2 = Vector2(0.0, -cell * CABLE_UP)
	var h: float = float(car.loop.size.y)
	var w: float = float(car.loop.size.x)
	var corners: Array[Vector2] = []
	for along: float in [0.0, h, h + w, h + w + h]:
		corners.append(to_local(car.world_at(along) + up))
	var cable: PackedVector2Array = PackedVector2Array(corners)
	cable.append(corners[0])
	ink.ink(RisoPrint.NIGHT, 0.85, RisoDecor.strip(cable, 3.2, 3.2))
	var wheels: Array[PackedVector2Array] = []
	var hubs: Array[PackedVector2Array] = []
	for c: Vector2 in corners:
		wheels.append(RisoShapes.circle(c, WHEEL, 18))
		hubs.append(RisoShapes.circle(c, WHEEL * 0.35, 10))
	ink.ink(RisoPrint.BLUE, 1.0, wheels)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], hubs)
	# The car, from its floor (this node's origin) up.
	var cw: float = cell * 2.0
	var ch: float = cell * 2.0
	var on_cable: Vector2 = Vector2(0.0, -cell * CABLE_UP)
	var sway: float = sin(t * 1.7 + phase) * 1.5
	var body: Array[PackedVector2Array] = [
		RisoShapes.rrect(-cw * 0.5 - 6.0, -ch - 6.0, cw + 12.0, 22.0, 9.0),
		RisoShapes.rrect(-cw * 0.5, -10.0, cw, 20.0, 6.0),
		RisoShapes.rrect(-cw * 0.5, -ch, 12.0, ch, 4.0),
		RisoShapes.rrect(cw * 0.5 - 12.0, -ch, 12.0, ch, 4.0),
	]
	body.append_array(RisoDecor.strip(PackedVector2Array([Vector2(sway, -ch - 4.0), on_cable]), 6.0, 4.0))
	body.append(RisoShapes.circle(on_cable, 8.0, 14))
	ink.ink(RisoPrint.BLUE, 0.4, [RisoShapes.rrect(-cw * 0.5 + 8.0, -ch * 0.38, cw - 16.0, ch * 0.38 - 6.0, 4.0)])
	ink.ink(RisoPrint.BLUE, 1.0, body)
	ink.ink(RisoPrint.NIGHT, 0.4, [RisoShapes.rrect(-cw * 0.5 - 6.0, -ch + 6.0, cw + 12.0, 10.0, 4.0), RisoShapes.rrect(-cw * 0.5, 0.0, cw, 10.0, 4.0)], false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.circle(on_cable, 3.0, 8)])
	# The lever on the back wall: a post with a handle leaning the way it runs, a paper knob.
	var lean: float = float(car.dir) * 0.6 if car.running else 0.0
	var handle: Transform2D = Transform2D(lean, Vector2(0.0, -40.0))
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-16.0, -46.0, 32.0, 40.0, 6.0), handle * RisoShapes.rrect(-3.0, -46.0, 6.0, 46.0, 3.0)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [handle * RisoShapes.circle(Vector2(0.0, -48.0), 7.0, 14)])
	# Its bars, coming down across each side as it shuts.
	var pink: Array[PackedVector2Array] = []
	var blue: Array[PackedVector2Array] = []
	for k: int in range(2):
		if car.shut[k] <= 0.0:
			continue
		var side: float = -1.0 if k == 0 else 1.0
		var drop: float = (ch - 12.0) * car.shut[k]
		var bars: Array[PackedVector2Array] = []
		for b: int in range(3):
			var x: float = side * (cw * 0.5 - 18.0 - float(b) * 11.0)
			bars.append(RisoShapes.rrect(x - 2.5, -ch + 10.0, 5.0, drop, 2.0))
		bars.append(RisoShapes.rrect(side * (cw * 0.5 - 12.0) - (34.0 if side > 0.0 else 0.0), -ch + 10.0 + drop * 0.5, 34.0, 4.0, 2.0))
		(pink if car.sealed else blue).append_array(bars)
	ink.ink(RisoPrint.PINK, 1.0, pink)
	ink.ink(RisoPrint.BLUE, 0.9, blue)
