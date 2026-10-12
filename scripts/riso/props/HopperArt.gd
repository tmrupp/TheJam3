extends CreatureArt
## A hopper: a blob of pink spell-water on the ground, drawn out into a drop as it leaps, its tail
## following the way its head has come.


## The blob's round (art units): how wide and high it sits on the ground, the round body it gathers
## into in the air (its radius, its middle over the feet), and how the art is scaled.
const BLOB_W: float = 13.0
const BLOB_H: float = 13.0
const R: float = 10.0
const MIDDLE: Vector2 = Vector2(0, -10)
const SCALE: float = 1.7
## Points round its outline.
const ROUND: int = 24
## The tail: the head's path over the last TAIL_TIME seconds (so it trails out in a leap and draws
## back in as the head comes to rest), at most TAIL_LEN px of it.
const TAIL_TIME: float = 0.14
const TAIL_LEN: float = 90.0
## How fast (of the way, a second) it gathers into a drop leaving the ground and spreads into a
## blob landing, and how far forward (radians) it leans over its feet as it crouches.
const SHAPE_EASE: float = 14.0
const CROUCH_LEAN: float = 0.35
## The splash on landing: how many droplets, for how long (seconds), and how far they fly (art units).
const SPLASH: int = 4
const SPLASH_TIME: float = 0.35
const SPLASH_REACH: float = 16.0

## 0 a blob on the ground, 1 a round drop in the air.
var air: float = 0.0
## The head's path (world x, y, and the art clock when it was there), newest last.
var trail: Array[Vector3] = []


## The hopper: on the ground a blob of pink spell-water, wider than high, with two paper eyes and
## a paper gleam; crouching to leap it leans forward over its feet (the eyes narrowing) rather than
## squashing. Leaving the ground it gathers into a round drop whose tail follows the way its head
## has come, streaming out behind the leap and curving as it arcs, then drawing back in as it lands
## and spreads out again, with a few droplets splashing out round it.
func _draw_art() -> void:
	var hop: Hopper = host.get_node_or_null("Hopper") as Hopper
	var facing: float = 1.0
	var crouch: float = -1.0
	var grounded: bool = true
	var landed: float = 10.0
	var stunned: bool = false
	if hop != null:
		facing = hop.facing
		crouch = hop.crouch
		grounded = hop.grounded
		landed = hop.since_landing
		stunned = hop.stunned
	air = move_toward(air, 0.0 if grounded else 1.0, _dt * SHAPE_EASE)
	var lean: float = 0.0
	if crouch >= 0.0 and not stunned:
		lean = CROUCH_LEAN * crouch * crouch * (3.0 - 2.0 * crouch)
	var feet: Vector2 = Vector2(0, 16)
	var xf: Transform2D = Transform2D(0.0, Vector2(facing * SCALE, SCALE), 0.0, feet) * Transform2D(lean, Vector2.ZERO)
	if not grounded:
		var g: float = _ground()
		var high: float = clampf((g - feet.y) / 300.0, 0.0, 1.0)
		ink.ink(RisoPrint.NIGHT, 0.35 * (1.0 - high * 0.6), [RisoShapes.ellipse(Vector2(0, g - 3.0), 24.0 * (1.0 - high * 0.4), 5.0, 16)], false)
	# The head's path, kept for TAIL_TIME, so the tail follows it.
	var head: Vector2 = xf * Vector2(0, -BLOB_H * 0.5).lerp(MIDDLE, air)
	var head_world: Vector2 = to_global(head)
	trail.append(Vector3(head_world.x, head_world.y, t))
	while trail.size() > 1 and t - trail[0].z > TAIL_TIME:
		trail.pop_front()
	var body: PackedVector2Array = xf * _shape(air)
	var tail: PackedVector2Array = _tail(head, R * SCALE * air)
	if not tail.is_empty():
		# The tail and the round as one outline: the largest of what merging them gives (any other is
		# a hole or a sliver).
		var best: float = 0.0
		for poly: PackedVector2Array in Geometry2D.merge_polygons(body, tail):
			var area: float = absf(_area(poly))
			if area > best:
				best = area
				body = poly
	ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [body])
	ink.ink(RisoPrint.PINK, 1.0, [body])
	ink.ink(RisoPrint.BLUE, 0.3, [body], false)
	# A shade along its underside, and a paper gleam high on its round, as on wet glass.
	var under: Vector2 = Vector2(0, -BLOB_H * 0.45).lerp(MIDDLE + Vector2(0, 1.5), air)
	ink.ink(RisoPrint.NIGHT, 0.25, [xf * RisoShapes.crescent(under, lerpf(BLOB_W * 0.9, R * 0.95, air), Vector2(0, -3.0))], false)
	var gleam_at: Vector2 = Vector2(-5.5, -BLOB_H * 0.72).lerp(MIDDLE + Vector2(-4.5, -4.0), air)
	var eyes: Array[PackedVector2Array] = [xf * Transform2D(-0.6, gleam_at) * RisoShapes.almond(Vector2.ZERO, 1.6, 3.6, 10)]
	for k: int in range(2):
		var e: Vector2 = Vector2(2.5 + 4.5 * float(k), -BLOB_H * 0.55).lerp(MIDDLE + Vector2(2.5 + 4.0 * float(k), -1.5), air)
		if stunned:
			eyes.append(xf * RisoShapes.rrect(e.x - 1.6, e.y - 0.3, 3.2, 0.6, 0.3, 2))
		elif crouch >= 0.0:
			eyes.append(xf * PackedVector2Array([e + Vector2(-1.8, -1.0), e + Vector2(1.8, 0.2), e + Vector2(1.6, 1.0), e + Vector2(-1.8, 0.2)]))
		else:
			eyes.append(xf * RisoShapes.ellipse(e, 1.3, 2.2, 12))
	ink.knock(RisoPrint.ALL_PLATES, eyes)
	# Landing: droplets thrown out and falling back.
	if grounded and landed < SPLASH_TIME:
		var u: float = landed / SPLASH_TIME
		var drops: Array[PackedVector2Array] = []
		for i: int in range(SPLASH):
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var row: float = float(i >> 1)
			var out: float = SPLASH_REACH * (0.6 + 0.4 * row) * u
			var up: float = 10.0 * (0.8 + 0.3 * row) * (u - u * u) * 4.0
			drops.append(xf * RisoShapes.circle(Vector2(side * (BLOB_W * 0.8 + out), -up), 1.8 * (1.0 - u * 0.6), 8))
		ink.ink(RisoPrint.PINK, 1.0 - u, drops)
	if stunned:
		_stun_mark(xf * Vector2(0, -34))


## Its outline (art units, feet at the origin) between the blob on the ground (`a` 0: wider than
## high, flat beneath) and the round body of a drop in the air (`a` 1), point for point.
static func _shape(a: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(ROUND):
		var ang: float = TAU * float(i) / float(ROUND)
		var blob: Vector2 = Vector2(cos(ang) * BLOB_W, -BLOB_H * maxf(0.0, -sin(ang)) + 1.2 * maxf(0.0, sin(ang)))
		var drop: Vector2 = MIDDLE + Vector2(cos(ang), sin(ang)) * R
		pts.append(blob.lerp(drop, a))
	return RisoShapes.smooth(pts)


## The tail (in the art's frame, px): a strip along the head's path back from `head`, `width` across
## at the head and tapering to a point at the far end; empty while the path is too short to show.
func _tail(head: Vector2, width: float) -> PackedVector2Array:
	if width < 1.0 or trail.size() < 2:
		return PackedVector2Array()
	var path: PackedVector2Array = PackedVector2Array([head])
	var length: float = 0.0
	for i: int in range(trail.size() - 2, -1, -1):
		var p: Vector2 = to_local(Vector2(trail[i].x, trail[i].y))
		var last: Vector2 = path[path.size() - 1]
		var step: float = p.distance_to(last)
		if step < 0.5:
			continue
		if length + step > TAIL_LEN:
			path.append(last + (p - last).normalized() * (TAIL_LEN - length))
			length = TAIL_LEN
			break
		path.append(p)
		length += step
	if path.size() < 2 or length < width * 0.6:
		return PackedVector2Array()
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var along: float = 0.0
	for i: int in range(path.size()):
		if i > 0:
			along += path[i].distance_to(path[i - 1])
		var d: Vector2 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var half: float = width * 0.92 * (1.0 - along / length)
		left.append(path[i] + d.orthogonal() * half)
		right.append(path[i] - d.orthogonal() * half)
	right.reverse()
	return left + right


## The signed area of `poly`.
static func _area(poly: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
