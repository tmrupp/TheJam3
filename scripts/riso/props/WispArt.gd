extends CreatureArt
class_name WispArt
## A wisp, its body following the path its head has travelled.


## Wisp turning: the wisp turns round along a teardrop lying on its path, the path cutting it in
## half: the drop's point is where the wisp is when it turns, and its round end lies ahead. The
## wisp dips off its path, swings up round the round end and back over the top, and comes down
## onto its path at the point facing the other way (half a turn in all), its body following the
## path's heading. Timed by the art's own clock from the moment its facing changes, while its Mover
## holds still for the same time (Mover.TURN_TIME). The body is symmetric about its spine
## (y = -8.2), so half a turn of the old facing is the new facing upright; the eyes slide to their
## mirrored height on the way so they land exactly.
## WISP_DROP_LEN is how far ahead the drop reaches, point to round end, at most (see _fit_loop);
## its height keeps in proportion (wisp_drop_half).
const WISP_DROP_LEN: float = 56.0
## The smallest drop, where the room ahead or over the floor is tight.
const WISP_DROP_MIN: float = 24.0
var wisp_turn_t0: float = -100.0
var wisp_from: float = 0.0
var wisp_to: float = 0.0
## This turn's drop length, fitted to the open space around the wisp when the turn starts.
var wisp_drop_len: float = WISP_DROP_LEN
## How far round the drop the head had come by the last frame (0..1).
var _drop_e: float = 0.0
## The middle of the body as last drawn (world space), where a shield round it centres.
var _body_middle: Vector2 = Vector2.INF
## The middle of the body, in its own art units (it runs from the tail tip at x -12.4 to the head).
const BODY_MIDDLE: Vector2 = Vector2(-3.0, -8.2)


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
		_drop_e = 0.0
	var u: float = clampf((t - wisp_turn_t0) / Mover.TURN_TIME, 0.0, 1.0)
	var spinning: bool = u < 1.0
	var side: float = wisp_from if spinning else wisp_to
	var loop_at: Vector2 = Vector2.ZERO
	var heading: float = 0.0
	var e: float = _drop_pace(u)
	if spinning:
		loop_at = _drop_at(e, side)
		heading = float(wisp_loop(e)[1])
	var e_eyes: float = clampf(-heading / PI, 0.0, 1.0)
	var width: float = 1.0
	# Its shadow on the floor, shrinking as it bobs up: it belongs to the ground it haunts.
	var g: float = _ground()
	var reach: float = WISP_DROP_LEN * wisp_drop_half()
	var lift: float = clampf(-loop_at.y / reach, 0.0, 1.0)
	# And darkening as it swoops down toward it on a turn.
	var dip: float = clampf(loop_at.y / reach, 0.0, 1.0)
	ink.ink(RisoPrint.NIGHT, 0.35 * (1.0 - lift * 0.6 + dip * 0.5), [RisoShapes.ellipse(Vector2(loop_at.x, g - 3.0), (26.0 + bob * 1.2) * (1.0 - lift * 0.4), 5.0, 16)], false)
	# The body follows the path its head has travelled (see _wisp_place): the head is placed on
	# its drop, and everything behind it lies along the recorded trail, so mid-turn the tail traces
	# the drop and after the turn it unwinds along it as the wisp moves off.
	_wp_k = k
	_wp_side = side
	_wp_bob = Vector2(0, bob * k * 0.7)
	var head_rest: Vector2 = Vector2(0, 14.0 - 3.3 * k - 8.2 * k * 0.6)
	var head: Vector2 = head_rest + loop_at
	_wp_head_dir = Vector2(side * cos(heading), sin(heading)) if spinning else Vector2(side, 0)
	if spinning:
		# The drop goes into the trail in short steps from where the head was last frame, so the
		# tail follows its curve exactly however far round the head went in one frame.
		var step: float = WISP_STEP / (wisp_drop_round() * wisp_drop_len)
		var at_e: float = _drop_e + step
		while at_e < e:
			_wisp_trail_add(to_global(head_rest + _drop_at(at_e, side)))
			at_e += step
		_drop_e = e
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
	_body_middle = to_global(_wisp_place(PackedVector2Array([BODY_MIDDLE]), false)[0])
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


## A shield centres on the middle of the body, which trails behind the wisp's origin.
func guard_center() -> Vector2:
	return _body_middle if _body_middle != Vector2.INF else super.guard_center()


## Size the turning drop to the room: smaller over a near floor, and short of a wall or another
## wisp ahead (two wisps meeting turn together, so each takes half the way between them). The head
## floats about WISP_HEAD_Y over the wisp's origin and dips to WISP_FLOOR_GAP over the floor, and
## the body reaches about WISP_NOSE past the head round the drop's round end.
const WISP_HEAD_Y: float = -23.0
const WISP_FLOOR_GAP: float = 18.0
const WISP_NOSE: float = 14.0
## Another wisp within this height of this one is on the same floor (as Mover counts it).
const WISP_SAME_FLOOR: float = 24.0


func _fit_loop(forward: float) -> void:
	var at: Vector2 = host.global_position
	var room: float = (_ground() - WISP_HEAD_Y - WISP_FLOOR_GAP) / wisp_drop_half()
	var info: MapInfo = MapInfo.instance
	if info != null and info.world != null:
		var c: Vector2i = info.cell_at(at)
		var f: Vector2i = Vector2i(int(signf(forward)), 0)
		if _wisp_blocked(info, c + f):
			var face: float = info.cell_position(c + f).x - forward * half
			room = minf(room, absf(face - at.x) - WISP_NOSE)
	for other: Node in get_tree().get_nodes_in_group(&"wisps"):
		var d: Vector2 = (other as Node2D).global_position - at
		if other != host and absf(d.y) < WISP_SAME_FLOOR and d.x * forward > 0.0:
			room = minf(room, absf(d.x) * 0.5 - WISP_NOSE)
	wisp_drop_len = clampf(room, WISP_DROP_MIN, WISP_DROP_LEN)


func _wisp_blocked(info: MapInfo, v: Vector2i) -> bool:
	if not info.world.is_valid(v):
		return true
	var kind: int = info.world.get_cell(v).type
	return kind == LevelGen.Type.GROUND or kind == LevelGen.Type.CRACKED


## Where the head is on this turn's drop at `e` of the way round, from where it would be walking
## (facing `side`).
func _drop_at(e: float, side: float) -> Vector2:
	var p: Vector2 = (wisp_loop(e)[0] as Vector2) * wisp_drop_len
	return Vector2(side * p.x, p.y)


## How far round the drop the head is (0..1) at `u` of the turn (0..1): it leaves its path and
## comes back onto it at the wisp's walking pace (Mover.SPEED), and is quickest round the round end.
func _drop_pace(u: float) -> float:
	var ends: float = clampf(Mover.SPEED * Mover.TURN_TIME / (wisp_drop_round() * wisp_drop_len), 0.0, 1.0)
	return ends * u + (1.0 - ends) * (u - sin(TAU * u) / TAU)


## The drop's shape, by how the heading turns along each half of it (point to round end, as shares
## of that half): it leaves the path over the first WISP_DROP_TIP, runs on straight, and the round
## end's even curve comes in between WISP_DROP_ROUND.x and .y. The angle at the point follows.
const WISP_DROP_TIP: float = 0.12
const WISP_DROP_ROUND: Vector2 = Vector2(0.3, 0.5)
## Samples along each half of the drop.
const WISP_DROP_STEPS: int = 64
static var _loop: PackedVector2Array = PackedVector2Array()
static var _loop_heading: PackedFloat32Array = PackedFloat32Array()
## The drop's half height and the way round it, in drop lengths (see _build_drop).
static var _loop_half: float = 0.0
static var _loop_round: float = 0.0


## The wisp's turning drop at `e`, the share of the way round it (0..1): [position (x forward from
## the point, 1 at the round end; y down from the path), heading in radians (0 forward, positive
## turning down)]. The heading dips a little, then turns up round the round end and over the top,
## and levels out at -PI, backward, as the drop comes back to its point.
static func wisp_loop(e: float) -> Array:
	_build_drop()
	var f: float = clampf(e, 0.0, 1.0) * float(_loop.size() - 1)
	var i0: int = mini(int(f), _loop.size() - 2)
	var t0: float = f - float(i0)
	return [_loop[i0].lerp(_loop[i0 + 1], t0), lerpf(_loop_heading[i0], _loop_heading[i0 + 1], t0)]


## How far the drop reaches either side of its path, in drop lengths.
static func wisp_drop_half() -> float:
	_build_drop()
	return _loop_half


## The way round the drop, in drop lengths.
static func wisp_drop_round() -> float:
	_build_drop()
	return _loop_round


## Build the drop once. The half out, from the point to the round end, comes from integrating its
## heading, dipping first by the angle that brings it back onto the path at the round end; the half
## back is the half out mirrored across the path, run backward.
static func _build_drop() -> void:
	if not _loop.is_empty():
		return
	var n: int = WISP_DROP_STEPS
	var lo: float = 0.0
	var hi: float = PI * 0.5
	var heads: PackedFloat32Array = PackedFloat32Array()
	var pts: PackedVector2Array = PackedVector2Array()
	for it: int in range(40):
		var dip: float = (lo + hi) * 0.5
		heads = _drop_half_heading(dip, n)
		pts = _drop_trace(heads)
		# Still ending above the path: dip more.
		if pts[n].y < 0.0:
			lo = dip
		else:
			hi = dip
	var length: float = pts[n].x
	_loop = PackedVector2Array()
	_loop_heading = PackedFloat32Array()
	for i: int in range(n + 1):
		_loop.append(Vector2(pts[i].x, pts[i].y - pts[n].y * float(i) / float(n)) / length)
		_loop_heading.append(heads[i])
	for i: int in range(n - 1, -1, -1):
		_loop.append(Vector2(_loop[i].x, -_loop[i].y))
		_loop_heading.append(-PI - heads[i])
	_loop_half = 0.0
	for p: Vector2 in _loop:
		_loop_half = maxf(_loop_half, absf(p.y))
	_loop_round = 1.0 / length


## The heading at each step along the half out, dipping by `dip` off the point: the round end's
## curve ramps in (its running total, scaled so the heading is straight up at the round end).
static func _drop_half_heading(dip: float, n: int) -> PackedFloat32Array:
	var ramp: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(n):
		ramp.append(ramp[i] + smoothstep(WISP_DROP_ROUND.x, WISP_DROP_ROUND.y, (float(i) + 0.5) / float(n)))
	var heads: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(n + 1):
		var u: float = float(i) / float(n)
		heads.append(dip * smoothstep(0.0, WISP_DROP_TIP, u) - (PI * 0.5 + dip) * ramp[i] / ramp[n])
	return heads


## The points along the half out for its headings, each step a 1/(2n) share of the way round.
static func _drop_trace(heads: PackedFloat32Array) -> PackedVector2Array:
	var n: int = heads.size() - 1
	var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i: int in range(n):
		var h: float = (heads[i] + heads[i + 1]) * 0.5
		pts.append(pts[i] + Vector2(cos(h), sin(h)) / float(2 * n))
	return pts


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
