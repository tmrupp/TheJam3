extends RisoProp
class_name WormletArt
## A small worm (Wormlet), printed with the boss worm's own look (Worm.ink_flesh, jaw_at,
## teeth_at, ink_joint, ink_hits, ink_warning, ink_hole): three segments of pale flesh, a pink head
## with a wedge mouth of paper teeth that chomps, a rounded tail, shadows at its joints and its one
## hit left as a dot. Before it comes out the rock throbs pink where it will. From a floor it comes
## up out of a burrow hole as the boss's (the ground pushed up round a dark pit, crumbs of dug
## earth), only what is out of the rock showing, and bends over onto the floor toward the wizard; it
## inches along, bunching up into a hump with its head planted and stretching out again with its
## tail planted; and it dives head first into a new hole. From a ceiling it drops head first out of
## a hole there and flops down onto the floor. Its holes fall in behind it. Stunned, it is pale.

## How many segments it has, and how many points each one's middle is drawn through.
const SEGMENTS: int = 3
const SEG_POINTS: int = 8
## Inching: how far (px) it gets on with each bunch and stretch, and how high its middle humps when
## it is bunched up (px).
const INCH: float = 22.0
const HUMP: float = 12.0
## How long it takes to flop down onto the floor after dropping from a ceiling (seconds).
const FLOP_TIME: float = 0.18
## How much wider than its girth its warning in the rock is (Worm.ink_warning): a little, and the
## warning the boss's made smaller to that width (warn_size), so it lies flat along the rock face.
const WARN_WIDE: float = 1.3
## How much wider than its own radius the turn its body makes out of a hole is: a little, so the
## flesh on the inside of the turn does not fold over itself.
const TURN_WIDE: float = 1.3
## How far its jaws open and how fast they chomp, and how much bigger its teeth are than the boss's
## for its head (Worm.teeth_at), so they show at its size.
const CHOMP: float = 0.8
const CHOMP_RATE: float = 7.0
const TEETH: float = 1.6
## How far back from each joint (a share of its length) the shadow under the segment ahead reaches.
const JOINT: float = 0.07
## How far (a share of its length) each segment runs on under the one ahead, so no gap opens between
## them where it bends; and how far either side of a point (a share of its length) its line is read
## for the way it runs there, so two segments meeting at a joint end square to the same line.
const OVERLAP: float = 0.04
const TANGENT: float = 0.01
## How far its holes are sunk into the rock they are dug in, as a share of their rims' height: the pit
## opens just under the face, and the ground heaped round it rises out of the floor over its edge.
const HOLE_SINK: float = 0.5


## The Wormlet it dresses.
var worm: Wormlet:
	get:
		return host.get_node_or_null("Wormlet") as Wormlet if host != null else null

## How far it has crept along the floor (px), for the inching; where it was across last frame, what
## it was doing, and when it landed from a ceiling (this art's clock, t).
var _crept: float = 0.0
var _last_x: float = 0.0
var _last_state: int = -1
var _landed_at: float = -10.0


func _draw_art() -> void:
	var w: Wormlet = worm
	if w == null:
		return
	var o: Vector2 = host.global_position
	_track(w)
	_draw_holes(w, o)
	if w.state == Wormlet.State.WARN:
		var info: MapInfo = MapInfo.instance
		if info != null:
			Worm.ink_warning(ink, Transform2D(w.face_way().angle() + PI * 0.5, w.mouth() - o), Wormlet.GIRTH * 0.5 * WARN_WIDE, w.warn_near(), t, warn_size(info))
		return
	if not w.shown():
		return
	var length: float = Wormlet.LENGTH
	var turn: float = PI * 0.5 * Wormlet.GIRTH * 0.5 * TURN_WIDE
	# Where its turn out of a hole begins: under the floor's face by as much as the turn is wider than
	# the body, so it comes to lie on the floor.
	var face: float = Wormlet.GIRTH * 0.5 * TURN_WIDE
	# And as much further out from the hole's middle, so it comes to lie where its body is.
	var wide: float = Wormlet.GIRTH * 0.5 * (TURN_WIDE - 1.0)
	match w.state:
		Wormlet.State.RISE:
			# Up out of the hole behind where it will lie, head first, and over onto the floor.
			var m: Vector2 = Vector2(w.mouth_x - o.x - w.heading * wide, face)
			var head: float = w.out * (length + turn)
			_draw_body(w, func(u: float) -> Vector2: return _bend(m, w.heading, head - length * (1.0 - u)), clampf((length - head) / length, 0.0, 1.0), 1.0)
		Wormlet.State.SINK:
			# Head first down into the hole ahead of it, the rest following.
			var m: Vector2 = Vector2(w.mouth_x - o.x + w.heading * wide, face)
			var head: float = turn - (1.0 - w.out) * (length + turn)
			_draw_body(w, func(u: float) -> Vector2: return _bend(m, -w.heading, head + length * (1.0 - u)), 0.0, clampf((head + length) / length, 0.0, 1.0))
		Wormlet.State.DROP:
			# Head first out of the ceiling, only what is out of the rock showing.
			var ceiling: float = w.face_point().y - o.y
			_draw_body(w, func(u: float) -> Vector2: return Vector2(0.0, -length * (1.0 - u)), clampf(1.0 + ceiling / length, 0.0, 1.0), 1.0)
		_:
			if t - _landed_at < FLOP_TIME:
				_draw_body(w, _flop(w.heading, (t - _landed_at) / FLOP_TIME), 0.0, 1.0)
			else:
				_draw_body(w, _inching(w.heading), 0.0, 1.0)


## Keep its creeping and its landing in step with what it does: out on the floor it starts stretched
## out, and it creeps as far as its body moves.
func _track(w: Wormlet) -> void:
	var x: float = host.global_position.x
	if w.state == Wormlet.State.OUT:
		if _last_state != Wormlet.State.OUT:
			_crept = INCH * 0.5
			if _last_state == Wormlet.State.DROP:
				_landed_at = t
		else:
			_crept += absf(x - _last_x)
	_last_x = x
	_last_state = w.state


## Its holes, as the boss's, printed as the rock is; each opening, then falling in after it.
func _draw_holes(w: Wormlet, o: Vector2) -> void:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null or w.burrows.is_empty():
		return
	var r: float = Wormlet.GIRTH * 0.5
	var size: float = hole_size(info)
	var to_local: Transform2D = Transform2D(0.0, -o)
	var was: bool = ink.of_the_rock
	ink.of_the_rock = true
	for b: Wormlet.Burrow in w.burrows:
		var k: float = w.open_of(b)
		if k <= 0.01:
			continue
		var rim: float = Worm.HOLE_RIM * size * k
		# Sunk a little into the rock, the heaped ground reaching as far into the face under it.
		var sink: float = rim * HOLE_SINK
		var at: Transform2D = Transform2D(b.out.angle() + PI * 0.5, b.mouth - b.out * sink)
		# Heaped only on the floor (or ceiling) it is dug in, never out over a drop beside it.
		var back: Vector2i = Vector2i(roundi(-b.out.x), roundi(-b.out.y))
		var shoulders: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in Worm.clip_to_air(info, at * Worm.mound_shape(r, rim), b.mouth, r * Worm.HOLE_REACH + Worm.HOLE_RIM, back, sink):
			shoulders.append(to_local * poly)
		var open: Callable = func(spot: Vector2) -> bool:
			var c: Vector2i = info.cell_at(spot + o)
			return Worm.passable(info.world, c) and not Worm.passable(info.world, c + back)
		Worm.ink_hole(ink, to_local * at, r, shoulders, b.out.dot(Vector2.UP) > 0.5, open, size * k)
	ink.of_the_rock = was


## How big its holes are next to the boss's (Worm.ink_hole's `size`): the boss's made smaller to its
## girth, rims, pit and crumbs alike, by its radius over the boss's (about 0.26 in the game's 128 px
## cell), so a hole stands as high on it as the boss's does on the boss.
static func hole_size(info: MapInfo) -> float:
	var cell: float = (info.cell_position(Vector2i(1, 0)) - info.cell_position(Vector2i.ZERO)).x
	return Wormlet.GIRTH / (cell * Worm.GIRTH)


## How big its warning is next to the boss's (Worm.ink_warning's `size`): the boss's made smaller to
## its own width, WARN_WIDE times its girth (about 0.34 in the game's 128 px cell), its height, slit
## and dirt alike, so it lies as flat as the boss's and a little wider than the worm.
static func warn_size(info: MapInfo) -> float:
	return hole_size(info) * WARN_WIDE


## Its body along `at` (u 0 its tail to 1 its head, to a local point), drawn only from `lo` to `hi`
## along it (what is out of the rock): each segment, tail first, the head last over the others.
func _draw_body(w: Wormlet, at: Callable, lo: float, hi: float) -> void:
	if hi - lo < 0.01:
		return
	var width: float = Wormlet.GIRTH
	var cover: float = Worm.STUNNED_FLESH if w.stunned else 1.0
	var head_at: Vector2 = at.call(1.0)
	var head_way: Vector2 = (head_at - (at.call(0.97) as Vector2)).normalized()
	var gape: float = Worm.MOUTH_REST if w.stunned else CHOMP * (0.5 + 0.5 * sin(t * CHOMP_RATE + phase))
	var wound: Wound = host.get_node_or_null("Wound") as Wound
	for i: int in range(SEGMENTS):
		var end: float = float(i + 1) / float(SEGMENTS)
		var span: Vector2 = segment_span(i, lo, hi)
		var a: float = span.x
		var b: float = span.y
		if b - a < 0.005:
			continue
		var head: bool = i == SEGMENTS - 1
		var flesh: Array[PackedVector2Array] = [band(at, a, b, width)]
		if i == 0 and lo <= 0.0:
			var tail_at: Vector2 = at.call(0.0)
			flesh.append(Worm.cap_shape(tail_at, (tail_at - (at.call(0.03) as Vector2)).normalized(), width, width * 0.5))
		var mouth: bool = head and hi >= 1.0
		if mouth:
			flesh.append(Worm.cap_shape(head_at, head_way, width, width * 0.5))
			flesh = Worm._bite_out(flesh, Worm.jaw_at(head_at, head_way, width, gape))
		Worm.ink_flesh(ink, flesh, head, cover)
		if mouth:
			Worm.ink_teeth(ink, Worm.teeth_at(head_at, head_way, width, gape, TEETH))
		if head:
			var dot: float = 5.0 / 6.0
			if dot >= a and dot <= b:
				Worm.ink_hits(ink, at.call(dot), head_way, width, maxi(wound.hp, 0) if wound != null else 0, 1.0)
		elif hi >= end:
			# The joint ahead of it, in shadow under the next segment's overhang.
			Worm.ink_joint(ink, [band(at, maxf(end - JOINT, a), end, width)], 1.0)


## Lying on the floor, heading `heading` (±1), inching: stretching out with its tail planted, then
## bunching up into a hump with its head planted, as it creeps.
func _inching(heading: float) -> Callable:
	var p: float = fposmod(_crept / INCH, 1.0)
	var bunch: float = 1.0 - 2.0 * p if p < 0.5 else 2.0 * p - 1.0
	var span: float = Wormlet.LENGTH - INCH * bunch
	return func(u: float) -> Vector2: return Vector2(heading * (u - 0.5) * span, -HUMP * bunch * sin(PI * u))


## Flopping down onto the floor after a drop, `k` (0 to 1) of the way: from hanging head down to lying
## along the floor toward `heading`, its head sliding forward as the rest swings over.
static func _flop(heading: float, k: float) -> Callable:
	var e: float = 1.0 - (1.0 - k) * (1.0 - k)
	var way: Vector2 = Vector2.from_angle(lerp_angle(Vector2.DOWN.angle(), Vector2(heading, 0.0).angle(), e))
	var head: Vector2 = Vector2(heading * Wormlet.LENGTH * 0.5 * e, 0.0)
	return func(u: float) -> Vector2: return head - way * Wormlet.LENGTH * (1.0 - u)


## A point `s` (px) along the way out of a floor hole, from `m` just under its mouth: straight up out
## of the rock below (s under 0), round a quarter turn (TURN_WIDE of the body's radius) toward `dir`
## (±1), then along the floor, lying on it.
static func _bend(m: Vector2, dir: float, s: float) -> Vector2:
	var r: float = Wormlet.GIRTH * 0.5 * TURN_WIDE
	var turn: float = PI * 0.5 * r
	if s <= 0.0:
		return m + Vector2(0.0, -s)
	if s < turn:
		var a: float = s / r
		return m + Vector2(dir * r * (1.0 - cos(a)), -r * sin(a))
	return m + Vector2(dir * (r + s - turn), -r)


## Where along its body (u, 0 its tail to 1 its head) segment `i` is printed, as (from, to), when
## only `lo` to `hi` of it is out of the rock: its own share, running on OVERLAP under the next one
## (the head, last, runs on under nothing).
static func segment_span(i: int, lo: float, hi: float) -> Vector2:
	var start: float = float(i) / float(SEGMENTS)
	var end: float = float(i + 1) / float(SEGMENTS)
	return Vector2(maxf(start, lo), minf(end + (OVERLAP if i < SEGMENTS - 1 else 0.0), hi))


## A strip `width` across along its body `at` from `a` to `b`, square at each point to the way the
## body runs there (read from `at` itself, TANGENT either side), so where two segments meet their
## ends match.
static func band(at: Callable, a: float, b: float, width: float) -> PackedVector2Array:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for n: int in range(SEG_POINTS + 1):
		var u: float = lerpf(a, b, float(n) / float(SEG_POINTS))
		var p: Vector2 = at.call(u)
		var way: Vector2 = (at.call(minf(u + TANGENT, 1.0)) as Vector2) - (at.call(maxf(u - TANGENT, 0.0)) as Vector2)
		var side: Vector2 = way.normalized().orthogonal() * width * 0.5
		left.append(p + side)
		right.append(p - side)
	var poly: PackedVector2Array = left
	for n: int in range(right.size() - 1, -1, -1):
		poly.append(right[n])
	return poly
