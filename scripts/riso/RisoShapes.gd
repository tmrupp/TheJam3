class_name RisoShapes
## Polygon builders for riso art. Every shape is a filled, closed PackedVector2Array.


static func circle(c: Vector2, r: float, n: int = 18) -> PackedVector2Array:
	return ellipse(c, r, r, n)


static func ellipse(c: Vector2, rx: float, ry: float, n: int = 20, rot: float = 0.0) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	for i: int in range(n):
		var t: float = TAU * float(i) / float(n)
		var p: Vector2 = Vector2(cos(t) * rx, sin(t) * ry)
		out.append(c + Vector2(p.x * cr - p.y * sr, p.x * sr + p.y * cr))
	return out


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


static func rrect(x: float, y: float, w: float, h: float, r: float, seg: int = 4) -> PackedVector2Array:
	r = minf(r, minf(w, h) * 0.5)
	var out: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	var starts: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k: int in range(4):
		for s: int in range(seg + 1):
			var t: float = starts[k] + (PI * 0.5) * float(s) / float(seg)
			out.append(corners[k] + Vector2(cos(t), sin(t)) * r)
	return out


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
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in range(seg + 1):
		var u: float = float(k) / float(seg)
		out.append(c + Vector2(-w + 2.0 * w * u, -h * 4.0 * u * (1.0 - u)))
	for k: int in range(seg - 1, 0, -1):
		var u: float = float(k) / float(seg)
		out.append(c + Vector2(-w + 2.0 * w * u, h * 4.0 * u * (1.0 - u)))
	return out


## Four-point star with concave (quadratic) sides.
static func sparkle(c: Vector2, r: float, sx: float = 1.0, seg: int = 4) -> PackedVector2Array:
	var tips: Array[Vector2] = [Vector2(0, -r), Vector2(r * sx, 0), Vector2(0, r), Vector2(-r * sx, 0)]
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in range(4):
		var a: Vector2 = tips[k]
		var b: Vector2 = tips[(k + 1) % 4]
		for s: int in range(seg):
			var t: float = float(s) / float(seg)
			out.append(c + a.lerp(Vector2.ZERO, t).lerp(Vector2.ZERO.lerp(b, t), t))
	return out


## Round-topped arch standing on y + h.
static func arch(x: float, y: float, w: float, h: float, n: int = 10) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([Vector2(x, y + h), Vector2(x, y + w * 0.5)])
	for k: int in range(1, n):
		var t: float = PI + PI * float(k) / float(n)
		out.append(Vector2(x + w * 0.5 + cos(t) * w * 0.5, y + w * 0.5 + sin(t) * w * 0.5))
	out.append(Vector2(x + w, y + w * 0.5))
	out.append(Vector2(x + w, y + h))
	return out


static func xf(t: Transform2D, poly: PackedVector2Array) -> PackedVector2Array:
	return t * poly


static func hash1(n: float) -> float:
	var v: float = sin(n * 127.1 + 311.7) * 43758.5453
	return v - floorf(v)
