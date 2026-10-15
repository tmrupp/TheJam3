class_name RisoShapes
## Polygon builders for riso art. Every shape is a filled, closed PackedVector2Array.


## The shapes that only scale and move (a circle, a rounded corner, a sparkle, an almond) are worked
## out once at unit size, by their point count, and placed with one transform each time: the art
## asks for thousands of them a frame. The unit shapes, by kind and point count (see _unit).
static var _units: Dictionary = {}
## The kinds of unit shape: a circle, a rounded rectangle's four corners (clockwise from the top
## right, in order), an almond and a sparkle.
enum Unit { CIRCLE, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, CORNER_BOTTOM_LEFT, CORNER_TOP_LEFT, ALMOND, SPARKLE }


## The unit shape of kind `kind` (a Unit) with `n` points (a circle) or segments (the rest), made
## on first use.
static func _unit(kind: int, n: int) -> PackedVector2Array:
	var key: int = kind * 100000 + n
	var unit: Variant = _units.get(key)
	if unit != null:
		return unit
	var out: PackedVector2Array = PackedVector2Array()
	match kind:
		Unit.CIRCLE:
			for i: int in range(n):
				var t: float = TAU * float(i) / float(n)
				out.append(Vector2(cos(t), sin(t)))
		Unit.ALMOND:
			for k: int in range(n + 1):
				var u: float = float(k) / float(n)
				out.append(Vector2(-1.0 + 2.0 * u, -4.0 * u * (1.0 - u)))
			for k: int in range(n - 1, 0, -1):
				var u: float = float(k) / float(n)
				out.append(Vector2(-1.0 + 2.0 * u, 4.0 * u * (1.0 - u)))
		Unit.SPARKLE:
			var tips: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
			for k: int in range(4):
				var a: Vector2 = tips[k]
				var b: Vector2 = tips[(k + 1) % 4]
				for s: int in range(n):
					var t: float = float(s) / float(n)
					out.append(a.lerp(Vector2.ZERO, t).lerp(Vector2.ZERO.lerp(b, t), t))
		_:
			# A rounded rectangle's corner, a quarter turn from its start (clockwise from the top right).
			var start: float = -PI * 0.5 + PI * 0.5 * float(kind - Unit.CORNER_TOP_RIGHT)
			for s: int in range(n + 1):
				var t: float = start + (PI * 0.5) * float(s) / float(n)
				out.append(Vector2(cos(t), sin(t)))
	_units[key] = out
	return out


static func circle(c: Vector2, r: float, n: int = 18) -> PackedVector2Array:
	return ellipse(c, r, r, n)


static func ellipse(c: Vector2, rx: float, ry: float, n: int = 20, rot: float = 0.0) -> PackedVector2Array:
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	return Transform2D(Vector2(rx * cr, rx * sr), Vector2(-ry * sr, ry * cr), c) * _unit(Unit.CIRCLE, n)


## Closed quadratic spline through the midpoints of `pts` (every corner rounded).
static func smooth(pts: PackedVector2Array, seg: int = 4) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = pts.size()
	if n < 3:
		return pts
	for i: int in range(n):
		var a: Vector2 = (pts[(i - 1 + n) % n] + pts[i]) * 0.5
		var ctrl: Vector2 = pts[i]
		var b: Vector2 = (pts[i] + pts[(i + 1) % n]) * 0.5
		for s: int in range(seg):
			var t: float = float(s) / float(seg)
			out.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return out


## Open quadratic spline from the first of `pts` to the last, through the midpoints of the edges
## between (each inner point the control of its own curve): the open counterpart of smooth.
static func smooth_open(pts: PackedVector2Array, seg: int = 4) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 3:
		return pts
	var out: PackedVector2Array = PackedVector2Array([pts[0]])
	for i: int in range(1, n - 1):
		var a: Vector2 = pts[0] if i == 1 else (pts[i - 1] + pts[i]) * 0.5
		var b: Vector2 = pts[n - 1] if i == n - 2 else (pts[i] + pts[i + 1]) * 0.5
		for s: int in range(1, seg + 1):
			var t: float = float(s) / float(seg)
			out.append(a.lerp(pts[i], t).lerp(pts[i].lerp(b, t), t))
	return out


## A rectangle `w` by `h` from (`x`, `y`) with its corners rounded `r` (at most half its width or
## height), each corner in `seg` steps. Square corners give just the four corners; and where the
## rounding is half its height or width (a pill), the point where two corners meet is kept once.
## Repeated points would defeat the print's triangulator (RisoInkOp.Shape), sending each such
## shape the slow way round.
static func rrect(x: float, y: float, w: float, h: float, r: float, seg: int = 4) -> PackedVector2Array:
	r = minf(r, minf(w, h) * 0.5)
	if r <= 0.0001:
		return PackedVector2Array([Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h), Vector2(x, y)])
	var out: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	for k: int in range(4):
		out.append_array(Transform2D(Vector2(r, 0.0), Vector2(0.0, r), corners[k]) * _unit(Unit.CORNER_TOP_RIGHT + k, seg))
	if r * 2.0 < minf(w, h) - 0.0001:
		return out
	var kept: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in out:
		if kept.is_empty() or p.distance_squared_to(kept[kept.size() - 1]) > 0.000001:
			kept.append(p)
	if kept.size() > 1 and kept[0].distance_squared_to(kept[kept.size() - 1]) <= 0.000001:
		kept.remove_at(kept.size() - 1)
	return kept


static func tri(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b, c])


## A disc of radius r with a slightly smaller disc (offset d) bitten out.
static func crescent(c: Vector2, r: float, d: Vector2, n: int = 36) -> PackedVector2Array:
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	var r2: float = r * 0.9
	if r <= 0.0:
		return outer
	# Start both arcs at the bite direction so the kept points never wrap around the start.
	var a0: float = d.angle() if d.length_squared() > 0.0 else 0.0
	for k: int in range(n):
		var t: float = a0 + TAU * float(k) / float(n)
		var p: Vector2 = c + Vector2(cos(t), sin(t)) * r
		if p.distance_squared_to(c + d) > r2 * r2:
			outer.append(p)
	for k: int in range(n):
		var t: float = a0 + TAU * float(k) / float(n)
		var p: Vector2 = c + d + Vector2(cos(t), sin(t)) * r2
		if p.distance_squared_to(c) < r * r:
			inner.append(p)
	inner.reverse()
	outer.append_array(inner)
	return outer


static func almond(c: Vector2, w: float, h: float, seg: int = 10) -> PackedVector2Array:
	return Transform2D(Vector2(w, 0.0), Vector2(0.0, h), c) * _unit(Unit.ALMOND, seg)


## Four-point star with concave (quadratic) sides.
static func sparkle(c: Vector2, r: float, sx: float = 1.0, seg: int = 4) -> PackedVector2Array:
	return Transform2D(Vector2(r * sx, 0.0), Vector2(0.0, r), c) * _unit(Unit.SPARKLE, seg)


## Round-topped arch standing on y + h.
static func arch(x: float, y: float, w: float, h: float, n: int = 10) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([Vector2(x, y + h), Vector2(x, y + w * 0.5)])
	for k: int in range(1, n):
		var t: float = PI + PI * float(k) / float(n)
		out.append(Vector2(x + w * 0.5 + cos(t) * w * 0.5, y + w * 0.5 + sin(t) * w * 0.5))
	out.append(Vector2(x + w, y + w * 0.5))
	out.append(Vector2(x + w, y + h))
	return out


## A ring round `c` from radius `r0` out to `r1`, as two half rings (a polygon has no holes).
static func ring(c: Vector2, r0: float, r1: float, n: int = 32) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	@warning_ignore("integer_division")
	var half: int = maxi(3, n / 2)
	for side: int in range(2):
		var poly: PackedVector2Array = PackedVector2Array()
		for i: int in range(half + 1):
			poly.append(c + Vector2.from_angle(PI * (float(side) + float(i) / float(half))) * r1)
		for i: int in range(half, -1, -1):
			poly.append(c + Vector2.from_angle(PI * (float(side) + float(i) / float(half))) * r0)
		out.append(poly)
	return out


static func xf(t: Transform2D, poly: PackedVector2Array) -> PackedVector2Array:
	return t * poly


static func hash1(n: float) -> float:
	var v: float = sin(n * 127.1 + 311.7) * 43758.5453
	return v - floorf(v)
