extends RisoProp
## A gondola (Gondola): its cable strung between two posts with pulley wheels at its stations, and
## the car hung from it on a hanger with a wheel running along the cable: a roof and a floor of
## blue, corner posts, and a low panel round the lower half. While it is shut, pink bars come down
## across both its open sides from the roof.

## How far over the car's floor the cable runs (cells), and the posts' and wheels' sizes (pixels).
const CABLE_UP: float = 2.55
const POST: float = 7.0
const WHEEL: float = 13.0


## The Gondola it dresses.
var car: Gondola:
	get:
		return host as Gondola


## The cable reaches far beyond the car: animate while any of it is in view.
func view_rect() -> Rect2:
	if car == null or car.stations.size() < 2:
		return Rect2()
	var up: Vector2 = Vector2(0.0, -car.cell_px * CABLE_UP)
	return Rect2(car.stations[0] + up, Vector2.ZERO).expand(car.stations[1] + up).expand(car.stations[0]).expand(car.stations[1]).grow(car.cell_px * 1.5)


func _draw_art() -> void:
	if car == null or car.stations.size() < 2:
		return
	var cell: float = car.cell_px
	var up: Vector2 = Vector2(0.0, -cell * CABLE_UP)
	var ends: Array[Vector2] = [to_local(car.stations[0] + up), to_local(car.stations[1] + up)]
	# The posts, beside each station (out on the side away from the other station), and the pulleys.
	var posts: Array[PackedVector2Array] = []
	var wheels: Array[PackedVector2Array] = []
	var hubs: Array[PackedVector2Array] = []
	for i: int in range(2):
		var floor_at: Vector2 = to_local(car.stations[i])
		var away: float = signf(car.stations[i].x - car.stations[1 - i].x)
		var px: float = floor_at.x + (away if away != 0.0 else 1.0) * (cell + POST * 2.0)
		posts.append(RisoShapes.rrect(px - POST * 0.5, ends[i].y - 4.0, POST, floor_at.y - ends[i].y + 6.0, 2.0))
		var x0: float = minf(px, ends[i].x)
		posts.append(RisoShapes.rrect(x0 - 2.0, ends[i].y - 2.0, absf(px - ends[i].x) + 4.0, 5.0, 2.0))
		wheels.append(RisoShapes.circle(ends[i], WHEEL, 18))
		hubs.append(RisoShapes.circle(ends[i], WHEEL * 0.35, 10))
	ink.ink(RisoPrint.BLUE, 0.9, posts)
	ink.ink(RisoPrint.NIGHT, 0.35, posts, false)
	# The cable, a little slack between its ends.
	var cable: PackedVector2Array = PackedVector2Array()
	for k: int in range(17):
		var u: float = float(k) / 16.0
		cable.append(ends[0].lerp(ends[1], u) + Vector2(0.0, sin(u * PI) * 10.0))
	ink.ink(RisoPrint.NIGHT, 0.9, RisoDecor.strip(cable, 3.2, 3.2))
	ink.ink(RisoPrint.BLUE, 1.0, wheels)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], hubs)
	# The car, from its floor (this node's origin) up.
	var w: float = cell * 2.0
	var h: float = cell * 2.0
	var u_here: float = clampf(Vector2.ZERO.distance_to(ends[0] - up) / maxf(1.0, ends[0].distance_to(ends[1])), 0.0, 1.0)
	var on_cable: Vector2 = Vector2(0.0, -cell * CABLE_UP + sin(u_here * PI) * 10.0)
	var sway: float = sin(t * 1.7 + phase) * 1.5
	var body: Array[PackedVector2Array] = [
		RisoShapes.rrect(-w * 0.5 - 6.0, -h - 6.0, w + 12.0, 22.0, 9.0),
		RisoShapes.rrect(-w * 0.5, -10.0, w, 20.0, 6.0),
		RisoShapes.rrect(-w * 0.5, -h, 12.0, h, 4.0),
		RisoShapes.rrect(w * 0.5 - 12.0, -h, 12.0, h, 4.0),
	]
	var hanger: Array[PackedVector2Array] = RisoDecor.strip(PackedVector2Array([Vector2(sway, -h - 4.0), on_cable]), 6.0, 4.0)
	ink.ink(RisoPrint.BLUE, 0.4, [RisoShapes.rrect(-w * 0.5 + 8.0, -h * 0.38, w - 16.0, h * 0.38 - 6.0, 4.0)])
	body.append_array(hanger)
	ink.ink(RisoPrint.BLUE, 1.0, body)
	ink.ink(RisoPrint.NIGHT, 0.4, [RisoShapes.rrect(-w * 0.5 - 6.0, -h + 6.0, w + 12.0, 10.0, 4.0), RisoShapes.rrect(-w * 0.5, 0.0, w, 10.0, 4.0)], false)
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.circle(on_cable, 8.0, 14)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.circle(on_cable, 3.0, 8)])
	# Its bars, coming down across both open sides as it shuts.
	if car.shut > 0.0:
		var bars: Array[PackedVector2Array] = []
		var drop: float = (h - 12.0) * car.shut
		for side: float in [-1.0, 1.0]:
			for k: int in range(3):
				var x: float = side * (w * 0.5 - 18.0 - float(k) * 11.0)
				bars.append(RisoShapes.rrect(x - 2.5, -h + 10.0, 5.0, drop, 2.0))
			bars.append(RisoShapes.rrect(side * (w * 0.5 - 12.0) - (34.0 if side > 0.0 else 0.0), -h + 10.0 + drop * 0.5, 34.0, 4.0, 2.0))
		ink.ink(RisoPrint.PINK, 1.0, bars)
