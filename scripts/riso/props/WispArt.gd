extends CreatureArt
## A wisp, its body following the path its head has travelled.


## Wisp turning: the wisp turns round in one arc, a half turn that dips under its path (forward,
## down, back under and up onto its path facing the other way), its body following the path's
## heading. Timed by the art's own clock from the moment its facing changes, while its Mover holds
## still for the same time. The body is symmetric about its spine (y = -8.2), so half a turn of the
## old facing is the new facing upright; the eyes slide to their mirrored height on the way so
## they land exactly. WISP_LOOP_H is how deep the arc dips, at most (see _fit_loop).
const WISP_LOOP_W: float = 30.0
const WISP_LOOP_H: float = 26.0
const WISP_TURN_TIME: float = 0.5
var wisp_turn_t0: float = -100.0
static var _loop: PackedVector2Array = PackedVector2Array()
static var _loop_heading: PackedFloat32Array = PackedFloat32Array()
var wisp_from: float = 0.0
var wisp_to: float = 0.0
## This turn's loop size, fitted to the open space around the wisp when the turn starts.
var wisp_loop_w: float = WISP_LOOP_W
var wisp_loop_h: float = WISP_LOOP_H


func _draw_art() -> void:
	var mover: Mover = host.get_node_or_null("Mover") as Mover
	var dir: float = 1.0
	var stunned: bool = false
	if mover != null:
		dir = mover.direction
		stunned = mover.stunned
		# Falling (as when it settles after spawning): keep the body straight rather than letting
		# the trail record the drop and hang it tail-up.
		if not mover.grounded:
			_trail = PackedVector2Array()
	var k: float = 3.6
	var bob: float = -3.0 - sin(t * 3.0 + phase) * 1.6
	if wisp_to == 0.0:
		wisp_from = dir
		wisp_to = dir
	if dir != wisp_to:
		wisp_from = wisp_to
		wisp_to = dir
		_fit_loop(wisp_from)
		wisp_turn_t0 = t
	var u: float = clampf((t - wisp_turn_t0) / WISP_TURN_TIME, 0.0, 1.0)
	var spinning: bool = u < 1.0
	var side: float = wisp_from if spinning else wisp_to
	var loop_at: Vector2 = Vector2.ZERO
	var spin: float = 0.0
	if spinning:
		var e: float = u * u * (3.0 - 2.0 * u)
		var sample: Array = wisp_loop(e)
		# The loop is drawn upside down: the wisp dips under its path rather than rising over it.
		loop_at = Vector2(side * (sample[0] as Vector2).x * wisp_loop_w, -(sample[0] as Vector2).y * wisp_loop_h)
		spin = -float(sample[1])
	var e_eyes: float = clampf(-spin / PI, 0.0, 1.0)
	var width: float = 1.0
	# Its shadow on the floor, shrinking as it bobs up: it belongs to the ground it haunts.
	var g: float = _ground()
	var lift: float = clampf(-loop_at.y / WISP_LOOP_H, 0.0, 1.0)
	# And darkening as it swoops down toward it on a turn.
	var dip: float = clampf(loop_at.y / WISP_LOOP_H, 0.0, 1.0)
	ink.ink(RisoPrint.NIGHT, 0.35 * (1.0 - lift * 0.6 + dip * 0.5), [RisoShapes.ellipse(Vector2(loop_at.x, g - 3.0), (26.0 + bob * 1.2) * (1.0 - lift * 0.4), 5.0, 16)], false)
	# The body follows the path its head has travelled (see _wisp_place): the head is placed on
	# its loop, and everything behind it lies along the recorded trail, so mid-turn the tail traces
	# the head's arc and after the turn it straightens out as the wisp moves off.
	_wp_k = k
	_wp_side = side
	_wp_bob = Vector2(0, bob * k * 0.7)
	var head: Vector2 = Vector2(0, 14.0 - 3.3 * k - 8.2 * k * 0.6) + loop_at
	_wp_head_dir = Vector2(side * cos(spin), -sin(spin)) if spinning else Vector2(side, 0)
	_wisp_trail_add(to_global(head))
	# Body, veils and glow reach about 22 art units back, scaled 1.1 k; plus the bend lookahead.
	_wisp_sample(22.0 * k * 1.1 + 8.0)
	var speed: float = 0.3 if stunned else 0.7
	var flicker: float = 0.85 + 0.15 * sin(t * 5.3 + phase) * sin(t * 2.1 + phase * 1.7)
	# The glow trails the wisp: strongest behind the head, thinning out past the tail.
	ink.ink(RisoPrint.PINK, 0.06 * flicker, [_wisp_place(RisoShapes.ellipse(Vector2(-10.5, -8.4), 11.0, 7.5, 28), true)])
	ink.ink(RisoPrint.PINK, 0.1 * flicker, [_wisp_place(RisoShapes.ellipse(Vector2(-6.0, -8.2), 9.5, 8.0, 28), true)])
	# Two lagging after-veils behind the body, then the body. The body is solid ink with only its
	# tail tip thinning; the veils stay faint.
	for layer: int in [2, 1, 0]:
		var lag: float = float(layer) * 0.55
		var w: Array[float] = []
		for j: int in range(4):
			w.append(sin(t * 6.0 * speed - float(j) - lag) * 1.4)
		var back: Vector2 = Vector2(-2.6, -0.4) * float(layer)
		var pts: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
			Vector2(5.6, -9), Vector2(4.6, -4.6), Vector2(1.6, -3), Vector2(-2, -3.8 + w[1] * 0.3), Vector2(-5.6, -4.8 + w[1]),
			Vector2(-9, -6.6 + w[2]), Vector2(-12.4, -8.6 + w[3]), Vector2(-8.8, -9.6 + w[2]), Vector2(-5.2, -11 + w[1] * 0.6),
			Vector2(-1.4, -13.2), Vector2(2.6, -13.4)]))
		var fade: PackedFloat32Array = PackedFloat32Array()
		var top: float = (1.0 if layer == 0 else 0.3 / float(layer)) * (1.0 if layer == 0 else flicker)
		for p: Vector2 in pts:
			# Along the body from the tail tip (0) to the head (1). The body is solid ink from about
			# the middle forward and tapers to nothing at the tail tip; the veils stay faint.
			var along: float = clampf((p.x + 12.4) / 18.0, 0.0, 1.0)
			var solid: float = clampf(along / 0.45, 0.0, 1.0)
			fade.append(top * (solid * solid * (3.0 - 2.0 * solid) if layer == 0 else lerpf(0.15, 1.0, along)))
		var poly: PackedVector2Array = _wisp_place(Transform2D(0.0, back) * pts, true)
		if layer == 0:
			# Opaque: clear the inks of whatever is behind (grass, light, glow) under the body.
			ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [_wisp_place(RisoShapes.smooth(PackedVector2Array([
				Vector2(5.6, -9), Vector2(4.6, -4.6), Vector2(1.6, -3), Vector2(-2, -3.8), Vector2(-4.5, -4.8), Vector2(-4.5, -11),
				Vector2(-1.4, -13.2), Vector2(2.6, -13.4)])), true)])
		ink.ink_graded(RisoPrint.PINK, [poly], [fade])
		if layer == 0:
			var cool: PackedFloat32Array = PackedFloat32Array()
			for a: float in fade:
				cool.append(a * 0.35)
			ink.ink_graded(RisoPrint.BLUE, [poly], [cool])
	var eyes: Array[PackedVector2Array] = []
	for eye: Vector2 in [Vector2(3.4, -9.2), Vector2(0.7, -9.4)]:
		# Mid-spin the eyes slide to their mirrored height about the spine, so after half a turn
		# they sit exactly where the upright wisp's eyes do.
		var ep: Vector2 = Vector2(eye.x, lerpf(eye.y, -16.4 - eye.y, e_eyes)) if spinning else eye
		var shape: PackedVector2Array = RisoShapes.rrect(ep.x - 1.0, ep.y - 0.4, 2.0, 0.8, 0.4, 2) if stunned else RisoShapes.ellipse(ep, 0.9, 1.9, 14)
		eyes.append(_wisp_place(shape, false))
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], eyes)
	if stunned:
		_stun_mark(head + _wp_bob + Vector2(0, -52))


## Size the turning arc to the room: shallower over a near floor, tighter against a wall. The head
## floats about WISP_HEAD_Y over the wisp's origin, and dips to WISP_FLOOR_GAP over the floor.
const WISP_HEAD_Y: float = -23.0
const WISP_FLOOR_GAP: float = 29.0


func _fit_loop(forward: float) -> void:
	wisp_loop_w = WISP_LOOP_W
	wisp_loop_h = clampf(_ground() - WISP_HEAD_Y - WISP_FLOOR_GAP, 8.0, WISP_LOOP_H)
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return
	var c: Vector2i = info.cell_at(host.global_position)
	var f: Vector2i = Vector2i(int(signf(forward)), 0)
	if _wisp_blocked(info, c + f):
		wisp_loop_w = 16.0


func _wisp_blocked(info: MapInfo, v: Vector2i) -> bool:
	if not info.world.is_valid(v):
		return true
	var kind: int = info.world.get_cell(v).type
	return kind == LevelGen.Type.GROUND or kind == LevelGen.Type.CRACKED


## The wisp's turning loop at `e` (0..1): [position (x forward, y up negative, roughly within
## 0..1 x -1..0), heading in radians (0 forward, PI back)]. The heading sweeps from forward, up
## over the top, past backward on the way down, and levels out backward; the path is closed so it
## ends where it began. Built once by integrating the heading.
static func wisp_loop(e: float) -> Array:
	if _loop.is_empty():
		var n: int = 96
		# Heading theta(u) = PI u + c sin(PI u); pick c so the path comes back down to its start.
		var lo: float = 0.0
		var hi: float = 3.0
		var c: float = 1.0
		for it: int in range(40):
			c = (lo + hi) * 0.5
			var ys: float = 0.0
			for i: int in range(n):
				var uu: float = (float(i) + 0.5) / float(n)
				ys += sin(PI * uu + c * sin(PI * uu))
			if ys > 0.0:
				lo = c
			else:
				hi = c
		var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
		var p: Vector2 = Vector2.ZERO
		for i: int in range(n):
			var uu: float = (float(i) + 0.5) / float(n)
			var th: float = PI * uu + c * sin(PI * uu)
			p += Vector2(cos(th), -sin(th)) / float(n)
			pts.append(p)
		var drift: Vector2 = pts[n]
		var top: float = 0.001
		for i: int in range(n + 1):
			pts[i] -= drift * float(i) / float(n)
			top = maxf(top, -pts[i].y)
		var wide: float = 0.001
		for i: int in range(n + 1):
			pts[i] /= top
			wide = maxf(wide, absf(pts[i].x))
		for i: int in range(n + 1):
			pts[i].x /= wide
		_loop = pts
		_loop_heading = PackedFloat32Array()
		for i: int in range(n + 1):
			var a: Vector2 = pts[maxi(0, i - 1)]
			var b: Vector2 = pts[mini(n, i + 1)]
			var d: Vector2 = b - a
			var h: float = atan2(-d.y, d.x)
			if i > 0 and h < _loop_heading[i - 1] - PI:
				h += TAU
			_loop_heading.append(h)
		_loop_heading[0] = 0.0
		_loop_heading[n] = PI
	var f: float = clampf(e, 0.0, 1.0) * float(_loop.size() - 1)
	var i0: int = mini(int(f), _loop.size() - 2)
	var t0: float = f - float(i0)
	return [_loop[i0].lerp(_loop[i0 + 1], t0), lerpf(_loop_heading[i0], _loop_heading[i0 + 1], t0)]


## Place a wisp shape on screen by following its trail. A point's local x is how far it lies
## behind the head (x = 0) along the body, and its local y how far it sits off the spine
## (y = -8.2). Points behind the head go where the head was that distance ago, offset across the
## trail's direction there; points ahead of it extend along the head's heading. The head's
## positions are recorded in world space without the bob, which is added to the whole shape.
const WISP_TRAIL_LEN: float = 260.0
var _wp_k: float = 3.6
var _wp_side: float = 1.0
var _wp_bob: Vector2 = Vector2.ZERO
var _wp_head_dir: Vector2 = Vector2.RIGHT
var _trail: PackedVector2Array = PackedVector2Array()


func _wisp_trail_add(at: Vector2) -> void:
	# Start (or after a jump, restart) with a straight trail behind the facing.
	if _trail.is_empty() or _trail[0].distance_to(at) > 120.0:
		_trail = PackedVector2Array()
		for n: int in range(66):
			_trail.append(at - _wp_head_dir * 4.0 * float(n))
		_trail_measure()
		return
	if _trail[0].distance_to(at) < 0.5:
		return
	_trail.insert(0, at)
	var total: float = 0.0
	for n: int in range(1, _trail.size()):
		total += _trail[n].distance_to(_trail[n - 1])
		if total > WISP_TRAIL_LEN:
			_trail.resize(n + 1)
			break
	_trail_measure()


## The distance along the trail from the head to each of its points (for _trail_at).
var _trail_cum: PackedFloat32Array = PackedFloat32Array()


func _trail_measure() -> void:
	_trail_cum.resize(_trail.size())
	var total: float = 0.0
	for n: int in range(_trail.size()):
		if n > 0:
			total += _trail[n].distance_to(_trail[n - 1])
		_trail_cum[n] = total


## Where the trail was `d` px behind the head: [position (world), direction of travel there].
## A binary search over the measured trail (each wisp asks this hundreds of times a frame).
func _trail_at(d: float) -> Array:
	if d <= 0.0 or _trail.size() < 2:
		return [_trail[0] - _wp_head_dir * d if not _trail.is_empty() else Vector2.ZERO, _wp_head_dir]
	if _trail_cum.size() != _trail.size():
		_trail_measure()
	var n: int = _trail_cum.bsearch(d)
	while n < _trail.size() and n > 0 and _trail_cum[n] - _trail_cum[n - 1] <= 0.0001:
		n += 1
	if n >= 1 and n < _trail.size():
		var a: Vector2 = _trail[n - 1]
		var b: Vector2 = _trail[n]
		var f: float = (d - _trail_cum[n - 1]) / (_trail_cum[n] - _trail_cum[n - 1])
		return [a.lerp(b, f), (a - b).normalized()]
	var last: Vector2 = _trail[_trail.size() - 1]
	var tail_dir: Vector2 = (_trail[_trail.size() - 2] - last).normalized()
	return [last - tail_dir * (d - _trail_cum[_trail.size() - 1]), tail_dir]


## The trail sampled every WISP_STEP px from the head, once a frame (_wisp_sample): positions in
## this prop's space and directions of travel. Placing a wisp's hundreds of vertices reads this
## table instead of walking the trail for each.
const WISP_STEP: float = 2.0
var _ts_pos: PackedVector2Array = PackedVector2Array()
var _ts_dir: PackedVector2Array = PackedVector2Array()
## How sharply the trail bends at each sample: the turn from 6 px older to 6 px newer.
var _ts_turn: PackedFloat32Array = PackedFloat32Array()
var _lk_turn: float = 0.0
## The last lookup (_wisp_lookup), kept in fields so lookups allocate nothing.
var _lk_pos: Vector2 = Vector2.ZERO
var _lk_dir: Vector2 = Vector2.RIGHT


func _wisp_sample(max_d: float) -> void:
	var n: int = ceili(max_d / WISP_STEP) + 2
	_ts_pos.resize(n)
	_ts_dir.resize(n)
	for i: int in range(n):
		var at: Array = _trail_at(float(i) * WISP_STEP)
		_ts_pos[i] = to_local(at[0] as Vector2)
		_ts_dir[i] = at[1]
	_ts_turn.resize(n)
	var reach: int = ceili(6.0 / WISP_STEP)
	for i: int in range(n):
		var older: Vector2 = _ts_dir[mini(i + reach, n - 1)]
		var newer: Vector2 = _ts_dir[maxi(i - reach, 0)]
		_ts_turn[i] = older.angle_to(newer) if i > 0 else 0.0


## Where the trail was `d` px behind the head (in this prop's space), and its direction there,
## into _lk_pos and _lk_dir.
func _wisp_lookup(d: float) -> void:
	if d <= 0.0:
		_lk_dir = _wp_head_dir
		_lk_pos = _ts_pos[0] - _wp_head_dir * d
		_lk_turn = 0.0
		return
	var f: float = d / WISP_STEP
	var i: int = mini(int(f), _ts_pos.size() - 2)
	var u: float = f - float(i)
	_lk_pos = _ts_pos[i].lerp(_ts_pos[i + 1], u)
	_lk_dir = _ts_dir[i].lerp(_ts_dir[i + 1], u).normalized()
	_lk_turn = lerpf(_ts_turn[i], _ts_turn[i + 1], u)


func _wisp_place(poly: PackedVector2Array, _curl: bool) -> PackedVector2Array:
	var sx: float = _wp_k * 1.1
	var sy: float = _wp_k * 0.6
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(poly.size())
	var across_turn: float = _wp_side * PI * 0.5
	for n: int in range(poly.size()):
		var d: float = -poly[n].x * sx
		# On a tight bend, keep the inside edge within the bend's radius so the body bunches
		# instead of folding over itself (a folded outline can't be printed).
		_wisp_lookup(d)
		var turn: float = _lk_turn
		var dir: Vector2 = _lk_dir
		# Within the first stretch behind the head, ease from the head's heading to the trail's.
		if d < 14.0:
			dir = _wp_head_dir.lerp(dir, clampf(d / 14.0, 0.0, 1.0)).normalized()
		var off: Vector2 = dir.rotated(across_turn) * ((poly[n].y + 8.2) * sy)
		if absf(turn) > 0.02:
			var centre: Vector2 = dir.rotated(signf(turn) * PI * 0.5)
			if off.dot(centre) > 0.0:
				off = off.limit_length(0.8 * 12.0 / absf(turn))
		out[n] = _lk_pos + off + _wp_bob
	# Wide shapes (glow, veils) can still cross over themselves on the tightest bend: print their
	# outline hull instead of nothing.
	if Geometry2D.triangulate_polygon(out).is_empty():
		var hull: PackedVector2Array = Geometry2D.convex_hull(out)
		if hull.size() > 3:
			hull.remove_at(hull.size() - 1)
			return _resample_loop(hull, out.size(), out[0])
	return out


## `loop` resampled evenly to `count` points (so per-vertex shading still lines up), starting
## at the point nearest `start`.
func _resample_loop(loop: PackedVector2Array, count: int, start: Vector2) -> PackedVector2Array:
	var m: int = loop.size()
	var first: int = 0
	for n: int in range(m):
		if loop[n].distance_squared_to(start) < loop[first].distance_squared_to(start):
			first = n
	var total: float = 0.0
	for n: int in range(m):
		total += loop[n].distance_to(loop[(n + 1) % m])
	var out: PackedVector2Array = PackedVector2Array()
	var seg: int = first
	var walked: float = 0.0
	var seg_len: float = loop[seg].distance_to(loop[(seg + 1) % m])
	for n: int in range(count):
		var want: float = total * float(n) / float(count)
		while walked + seg_len < want and seg_len >= 0.0:
			walked += seg_len
			seg = (seg + 1) % m
			seg_len = loop[seg].distance_to(loop[(seg + 1) % m])
		var f: float = (want - walked) / maxf(seg_len, 0.0001)
		out.append(loop[seg].lerp(loop[(seg + 1) % m], clampf(f, 0.0, 1.0)))
	return out
