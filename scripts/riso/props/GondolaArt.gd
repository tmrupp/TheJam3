extends RisoProp
## A gondola (Gondola): its cable along the whole track (blue, so it shows against the sky, as the
## rock-bugs on it must) with a pulley wheel at each turn, and the car hung from the cable on a
## hanger with a wheel running along it: a rounded roof with a hatch on its crown (where rock-bugs
## come in) and a floor of blue, nothing solid between them at its sides but a thin rail at each
## edge (so it reads as open, to step on and off; rock-bugs crawl on the rails), faint grey bars across its back wall with a rail across them (behind whoever rides), and its lever on
## the back wall (leaning the way it runs, upright while it stands). Its sides come down barred at
## their very edges while it runs, pink with a rider in it (danger) and blue empty, and lift when it
## stands. While it stands at a station shut by a toll gate, a fare box shows on the back wall on
## that side (GondolaFare), where the toll is paid from inside. It swings with its body (Gondola.swing) on the hinge atop its roof, its hanger hanging
## straight down from the wheel on the cable. Its stations are
## drawn by StationArt.

## The wheels' size (pixels).
const WHEEL: float = 13.0
## The roof: how far its crown rises over the top of the car, and how far its rim reaches below it
## (pixels).
const CROWN: float = Gondola.ROOF_RISE
const RIM: float = 16.0
## The rails at its sides its bars run in (rock-bugs crawl on them): how wide, and how strongly
## inked.
const RAIL: float = 5.0
const RAIL_COVER: float = 0.7
## How high up the back wall a fare box hangs, as a share of the car's height: over the head of
## whoever rides.
const FARE_UP: float = 0.72
## The bars across its back wall: how many upright, how far down the rail across them is (a share
## of the wall's height), and how faint they are (blue cover, over paper).
const BACK_BARS: int = 13
const BACK_RAIL: float = 0.45
const BACK_COVER: float = 0.32
## The bars down each side while it runs: how many, and how far apart (pixels).
const SIDE_BARS: int = 4
const SIDE_GAP: float = 11.0


## The Gondola it dresses.
var car: Gondola:
	get:
		return host as Gondola


## The cable runs the length of the level: animate while any of it is in view.
func view_rect() -> Rect2:
	if car == null or car.stations.is_empty():
		return Rect2()
	var r: Rect2 = Rect2(car.world_at(0.0), Vector2.ZERO)
	for i: int in CragsArchetype.turns(car.path):
		r = r.expand(car.world_at(float(i))).expand(car.world_at(float(i)) + Vector2(0.0, -car.cell_px * Gondola.CABLE_UP))
	return r.grow(car.cell_px * 1.5)


func _draw_art() -> void:
	if car == null or car.stations.is_empty():
		return
	var cell: float = car.cell_px
	var up: Vector2 = Vector2(0.0, -cell * Gondola.CABLE_UP)
	var corners: Array[Vector2] = []
	for i: int in CragsArchetype.turns(car.path):
		corners.append(to_local(car.world_at(float(i)) + up))
	var cable: PackedVector2Array = PackedVector2Array(corners)
	ink.ink(RisoPrint.BLUE, 0.9, RisoDecor.strip(cable, 3.5, 3.5))
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
	# The hanger hangs straight down from the wheel on the cable to the hinge atop the roof, however
	# the car swings.
	var on_cable: Vector2 = to_local(car.pivot_at(car.s))
	var hinge: Vector2 = car.hinge()
	# The roof: a low dome over the car's top, its rim a little wider than the car.
	var roof: PackedVector2Array = PackedVector2Array()
	for n: int in range(21):
		var a: float = PI + PI * float(n) / 20.0
		roof.append(Vector2(cos(a) * (cw * 0.5 + 6.0), -ch + RIM + sin(a) * (CROWN + RIM)))
	var body: Array[PackedVector2Array] = [roof, RisoShapes.rrect(-cw * 0.5, -10.0, cw, 20.0, 6.0)]
	body.append_array(RisoDecor.strip(PackedVector2Array([hinge, on_cable]), 6.0, 4.0))
	body.append(RisoShapes.circle(on_cable, 8.0, 14))
	body.append(RisoShapes.circle(hinge, 6.0, 12))
	# Faint grey bars across the back wall, the night knocked out under them so they show.
	var back: Array[PackedVector2Array] = []
	for b: int in range(BACK_BARS):
		var x: float = lerpf(-cw * 0.5 + 16.0, cw * 0.5 - 16.0, float(b) / float(BACK_BARS - 1))
		back.append(RisoShapes.rrect(x - 3.0, -ch + RIM, 6.0, ch - RIM - 8.0, 2.0))
	back.append(RisoShapes.rrect(-cw * 0.5 + 12.0, -ch + RIM + (ch - RIM) * BACK_RAIL, cw - 24.0, 6.0, 2.0))
	ink.ink(RisoPrint.BLUE, BACK_COVER, back)
	var rails: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var x: float = side * (cw * 0.5 - Gondola.RAIL_IN)
		rails.append(RisoShapes.rrect(x - RAIL * 0.5, -ch + RIM - 4.0, RAIL, ch - RIM + 4.0, 2.0))
	ink.ink(RisoPrint.BLUE, RAIL_COVER, rails)
	ink.ink(RisoPrint.BLUE, 1.0, body)
	ink.ink(RisoPrint.NIGHT, 0.4, [RisoShapes.rrect(-cw * 0.5 - 6.0, -ch + RIM - 8.0, cw + 12.0, 8.0, 4.0), RisoShapes.rrect(-cw * 0.5, 0.0, cw, 10.0, 4.0)], false)
	# The hatch on its crown, beside the hanger: a dark slot.
	ink.ink(RisoPrint.NIGHT, 0.75, [RisoShapes.rrect(Gondola.HATCH_X - 11.0, -ch - CROWN + 10.0, 22.0, 8.0, 3.0)], false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.circle(on_cable, 3.0, 8)])
	# The lever on the back wall: a post with a handle leaning the way it runs, a paper knob.
	var lean: float = float(car.dir) * 0.6 if car.running else 0.0
	var handle: Transform2D = Transform2D(lean, Vector2(0.0, -40.0))
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-16.0, -46.0, 32.0, 40.0, 6.0), handle * RisoShapes.rrect(-3.0, -46.0, 6.0, 46.0, 3.0)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [handle * RisoShapes.circle(Vector2(0.0, -48.0), 7.0, 14)])
	# A fare box on the back wall, on the side of a station shut by a toll gate while the car stands
	# there (GondolaFare): a blue box with a paper slot and an accent coin over it.
	for fare: GondolaFare in car.fares:
		if fare.toll() == null:
			continue
		var fx: float = float(fare.side) * cw * 0.28
		var fy: float = -ch * FARE_UP
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(fx - 15.0, fy, 30.0, 34.0, 5.0)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.rrect(fx - 8.0, fy + 9.0, 16.0, 4.0, 1.5)])
		ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(Vector2(fx, fy - 12.0 + sin(t * 3.0) * 2.0), 7.0, 14)])
	# Its bars, coming down across each side, at its very edges, as it shuts.
	var pink: Array[PackedVector2Array] = []
	var blue: Array[PackedVector2Array] = []
	var edge: float = cw * 0.5 - 5.0
	var reach: float = SIDE_GAP * float(SIDE_BARS - 1)
	for k: int in range(2):
		if car.shut[k] <= 0.0:
			continue
		var side: float = -1.0 if k == 0 else 1.0
		var drop: float = (ch - RIM - 4.0) * car.shut[k]
		var bars: Array[PackedVector2Array] = []
		for b: int in range(SIDE_BARS):
			var x: float = side * (edge - float(b) * SIDE_GAP)
			bars.append(RisoShapes.rrect(x - 2.5, -ch + RIM, 5.0, drop, 2.0))
		var inner_x: float = side * (edge - reach)
		bars.append(RisoShapes.rrect(minf(inner_x, side * edge) - 2.5, -ch + RIM + drop * 0.5, reach + 5.0, 4.0, 2.0))
		(pink if car.sealed else blue).append_array(bars)
	ink.ink(RisoPrint.PINK, 1.0, pink)
	ink.ink(RisoPrint.BLUE, 0.9, blue)
