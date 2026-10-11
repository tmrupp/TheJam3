extends RisoProp
## A balloon moored on an island (Balloon): a wicker basket on the floor, tied to a peg by a pale
## line and hung by pale ropes under an
## envelope of blue gores with bare-paper seams, a band of sun round its mouth and a burner's sun
## flame under it. It leans with the level's wind; becalmed (no wind enough to carry it) it hangs
## slack and low, half fallen in on itself. Boarded, it rises, flame roaring, before the trip.

## How far it leans for each step of the wind's strength (radians), and at most.
const LEAN: float = 0.05
const LEAN_MAX: float = 0.22
## The envelope's half-width and half-height, full and slack (px).
const FULL: Vector2 = Vector2(92.0, 116.0)
const SLACK: Vector2 = Vector2(86.0, 70.0)


## The Balloon it dresses.
var balloon: Balloon:
	get:
		return host as Balloon


func _draw_art() -> void:
	if balloon == null:
		return
	var g: float = _ground()
	var wind: int = balloon.map_info.level_wind() if balloon.map_info != null else 0
	var full: bool = Balloon.trip(wind) != 0 or balloon.rising >= 0.0
	var u: float = clampf(balloon.rising / Balloon.RISE_TIME, 0.0, 1.0) if balloon.rising >= 0.0 else 0.0
	var lift: float = Balloon.RISE * u * u
	var lean: float = clampf(float(wind) * LEAN, -LEAN_MAX, LEAN_MAX) + sin(t * 0.8 + phase) * 0.03
	var basket_top: float = g - 46.0 - lift
	var size: Vector2 = FULL if full else SLACK
	var mouth: Vector2 = Vector2(0.0, basket_top - 70.0)
	var xf: Transform2D = Transform2D(lean, mouth)
	# The mooring line to its peg, while it is moored.
	if balloon.rising < 0.0:
		ink.ink(RisoPrint.BLUE, 1.0, [_strip(Vector2(30.0, basket_top + 20.0), Vector2(58.0, g - 4.0), 2.0)])
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(54.0, g - 14.0, 8.0, 14.0, 2.0)])
	# The ropes from the basket's corners up to the envelope's mouth.
	var ropes: Array[PackedVector2Array] = []
	for x: float in [-24.0, -8.0, 8.0, 24.0]:
		ropes.append(_strip(Vector2(x, basket_top), xf * Vector2(x * 1.6, 0.0), 2.0))
	ink.ink(RisoPrint.BLUE, 1.0, ropes)
	# The envelope: blue gores with paper seams, a sun band round its mouth.
	var centre: Vector2 = Vector2(0.0, -size.y + 10.0)
	var envelope: PackedVector2Array = xf * _envelope(centre, size, full)
	ink.knock([RisoPrint.NIGHT], [envelope])
	ink.ink(RisoPrint.BLUE, 1.0, [envelope])
	var seams: Array[PackedVector2Array] = []
	for k: int in range(-2, 3):
		var s: float = float(k) / 3.0
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(13):
			var a: float = PI * float(i) / 12.0
			pts.append(xf * (centre + Vector2(s * size.x * sin(a), -cos(a) * size.y)))
		seams.append_array(RisoDecor.strip(pts, 2.4, 2.4))
	ink.lift_ink([RisoPrint.BLUE], 0.8, seams)
	ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.rrect(-size.x * 0.42, -10.0, size.x * 0.84, 10.0, 3.0)])
	# The burner's flame: a flicker while it can fly, a roar as it rises.
	if full:
		var roar: float = 1.0 + 1.6 * u
		var upright: Transform2D = Transform2D(PI * 0.5, Vector2(0.0, 14.0))
		var flame: PackedVector2Array = xf * (upright * RisoShapes.almond(Vector2.ZERO, 16.0 * roar + 3.0 * sin(t * 17.0 + phase), 7.0 * roar, 10))
		ink.ink(RisoPrint.ACCENT, 0.9, [flame])
	# The basket: wicker, a darker rim.
	var basket: PackedVector2Array = RisoShapes.rrect(-28.0, basket_top, 56.0, 42.0, 6.0)
	ink.knock([RisoPrint.NIGHT], [basket])
	ink.ink(RisoPrint.BLUE, 0.85, [basket])
	ink.ink(RisoPrint.NIGHT, 0.5, [RisoShapes.rrect(-30.0, basket_top - 2.0, 60.0, 9.0, 4.0)], false)
	var weave: Array[PackedVector2Array] = []
	for k: int in range(3):
		weave.append(RisoShapes.rrect(-24.0, basket_top + 14.0 + 9.0 * float(k), 48.0, 2.2, 1.0))
	ink.ink(RisoPrint.NIGHT, 0.35, weave, false)


## The envelope about `c`, `size` across and up, round above and narrowing to its mouth below; slack,
## its top fallen in a little.
static func _envelope(c: Vector2, size: Vector2, full: bool) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		var a: float = TAU * float(i) / 32.0
		var p: Vector2 = Vector2(cos(a) * size.x, sin(a) * size.y)
		if p.y > 0.0:
			# The lower half narrows toward the mouth.
			p.x *= 1.0 - 0.55 * (p.y / size.y)
		elif not full:
			p.y *= 0.8 + 0.2 * absf(cos(a * 3.0))
		out.append(c + p)
	return out


## A line `w` wide from `a` to `b`.
static func _strip(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var n: Vector2 = (b - a).normalized().orthogonal() * w * 0.5
	return PackedVector2Array([a - n, b - n, b + n, a + n])


## It reaches well above its cell: in view if any of it is.
func view_rect() -> Rect2:
	return Rect2(host.global_position + Vector2(-140.0, -560.0), Vector2(280.0, 640.0)) if host != null else Rect2()
