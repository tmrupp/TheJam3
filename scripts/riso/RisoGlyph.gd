class_name RisoGlyph
extends RefCounted
## The mark of each ability (Abilities): printed in a shrine's niche, on a relic, in the HUD's
## spell slot and on the map. A new ability gets its mark here (anything else shows a spark).

## How far a mark reaches from its middle, about: each is drawn to fill this, so all print alike in
## weight wherever they are shown at one size.
const MARK_R: float = 24.0
## How far the pieces of blink's broken dot have drifted apart.
const BLINK_APART: float = 2.6
## Half the gap of paper down the spine of levitate's feather.
const SPINE: float = 0.9
## The outer radius of each of push's three bows.
const PUSH_R: float = 24.0
## How many times seeker's trail wobbles from side to side, how far it sways at its start (it settles
## as it nears the star), and how many steps it is drawn in.
const SEEKER_WOBBLES: float = 1.5
const SEEKER_SWAY: float = 5.0
const SEEKER_STEPS: int = 28


## An ability's mark fitted inside a circle of `radius` round `c` (a roundel): centred on the middle
## of its extent and sized, by its still pose, until its farthest point meets the circle, so a mark
## that moves keeps its size.
static func fit(a: StringName, c: Vector2, radius: float, t: float) -> Array[PackedVector2Array]:
	var still: Array[PackedVector2Array] = of(a, Vector2.ZERO, 0.0)
	var box: Rect2 = Rect2(still[0][0], Vector2.ZERO)
	for poly: PackedVector2Array in still:
		for p: Vector2 in poly:
			box = box.expand(p)
	var mid: Vector2 = box.get_center()
	var far: float = 0.001
	for poly: PackedVector2Array in still:
		for p: Vector2 in poly:
			far = maxf(far, p.distance_to(mid))
	var s: float = radius / far
	var move: Transform2D = Transform2D(0.0, Vector2(s, s), 0.0, c - mid * s)
	var out: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in of(a, Vector2.ZERO, t):
		out.append(move * poly)
	return out


## An ability's mark, centred on `c` and reaching about MARK_R from it: what a shrine teaches.
## Each is one bold silhouette, and what is inside one (an eye's pupil, a ring's hole, the cross on
## a flask) is a gap of paper between its shapes rather than a shape printed over it, so it reads
## in any one ink. The marks of a slot share a look: a damage spell's is sharp (a blade, a spark, a
## burst), a movement's shows the wizard as a dot on its way or the doorways it goes by, a utility
## spell's is round and soft, and a perk's is something of the wizard's own (a heart, a key ring).
static func of(a: StringName, c: Vector2, t: float) -> Array[PackedVector2Array]:
	match a:
		&"dash":
			return [RisoMarks.chevron(c + Vector2(-8, 0), Vector2.RIGHT, 0.8), RisoMarks.chevron(c + Vector2(12, 0), Vector2.RIGHT, 0.8)]
		&"double_jump":
			return [RisoMarks.chevron(c + Vector2(0, -10), Vector2.UP, 0.8), RisoMarks.chevron(c + Vector2(0, 12), Vector2.UP, 0.8)]
		&"wall_climb":
			# A wall with holds down its face, and the wizard's dot going up beside it.
			var wall: PackedVector2Array = RisoShapes.rrect(c.x - 22, c.y - 24, 10, 48, 3)
			for y: float in [-14.0, 0.0, 14.0]:
				wall = _merged(wall, RisoShapes.circle(c + Vector2(-12, y), 3.5, 12))
			return [wall, RisoMarks.chevron(c + Vector2(8, -6), Vector2.UP, 0.7), RisoShapes.circle(c + Vector2(8, 15), 5.5, 14)]
		&"blink":
			# The wizard's dot come apart where it was, and whole again a way on.
			var gone: Array[PackedVector2Array] = [RisoShapes.circle(c + Vector2(14, 0), 10.0, 20)]
			for k: int in range(4):
				var from: float = PI * 0.5 * float(k)
				var o: Vector2 = c + Vector2(-13, 0) + Vector2.from_angle(from + PI * 0.25) * BLINK_APART
				var quarter: PackedVector2Array = PackedVector2Array([o])
				for s: int in range(7):
					quarter.append(o + Vector2.from_angle(from + PI * 0.5 * float(s) / 6.0) * 8.5)
				gone.append(quarter)
			return gone
		&"astral":
			# A spirit in a sheet, its hem waving, with eyes of paper.
			var sheet: PackedVector2Array = RisoShapes.smooth(_at(c, [Vector2(0, -27), Vector2(17, -23), Vector2(18, 0), Vector2(19, 26),
				Vector2(11, 25), Vector2(6, 12), Vector2(0, 25), Vector2(-6, 12), Vector2(-11, 25), Vector2(-19, 26), Vector2(-18, 0), Vector2(-17, -23)]), 4)
			return _pierced(sheet, [RisoShapes.circle(c + Vector2(-6, -7), 3.8, 12), RisoShapes.circle(c + Vector2(6, -7), 3.8, 12)], c.y - 7.0)
		&"vigor":
			# A heart.
			var heart: PackedVector2Array = _merged(RisoShapes.circle(c + Vector2(-8, -8), 10.0, 20), RisoShapes.circle(c + Vector2(8, -8), 10.0, 20))
			return [_merged(heart, RisoShapes.tri(c + Vector2(-17.6, -3.5), c + Vector2(17.6, -3.5), c + Vector2(0, 19)))]
		&"levitate":
			# A feather adrift, split down its spine, over the ground it has left.
			var feather: Transform2D = Transform2D(-0.8, c + Vector2(2, -9))
			var vane: PackedVector2Array = RisoShapes.almond(Vector2.ZERO, 17.0, 7.5, 12)
			var lift: Array[PackedVector2Array] = [RisoShapes.rrect(c.x - 16, c.y + 19, 32, 5, 2.5), feather * RisoShapes.rrect(-25, -1.6, 9, 3.2, 1.6)]
			for half: Rect2 in [Rect2(-20, -10, 40, 10 - SPINE), Rect2(-20, SPINE, 40, 10 - SPINE)]:
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(vane, _box(half)):
					lift.append(feather * piece)
			return lift
		&"rift":
			# Two doorways the wizard opens, linked by an arc of dots over them.
			var pair: Array[PackedVector2Array] = _doorway(c + Vector2(-11, 3)) + _doorway(c + Vector2(11, 3))
			for x: float in [-6.0, 0.0, 6.0]:
				pair.append(RisoShapes.circle(c + Vector2(x, -19.0 + absf(x) * 0.4), 2.4, 8))
			return pair
		&"awareness":
			# An open eye: two lids round a pupil, paper between.
			var lids: Array[PackedVector2Array] = _pierced(RisoShapes.almond(c, 24.0, 15.0, 16), [RisoShapes.almond(c, 17.5, 10.5, 14)], c.y)
			lids.append(RisoShapes.circle(c, 6.5, 16))
			return lids
		&"speed":
			# The wizard's dot running, three streaks tapering away behind it.
			return [RisoShapes.circle(c + Vector2(15, 0), 8.0, 16), _ribbon(_at(c, [Vector2(-14, -9), Vector2(3, -9)]), 1.0, 5.0),
				_ribbon(_at(c, [Vector2(-24, 0), Vector2(3, 0)]), 1.0, 5.5), _ribbon(_at(c, [Vector2(-14, 9), Vector2(3, 9)]), 1.0, 5.0)]
		&"warp":
			# A doorway, and the wizard's dots flung out of it, to land who knows where.
			var flung: Array[PackedVector2Array] = _doorway(c + Vector2(-9, 5))
			flung.append_array([RisoShapes.circle(c + Vector2(7, -17), 4.5, 12), RisoShapes.circle(c + Vector2(17, -7), 3.6, 10),
				RisoShapes.circle(c + Vector2(19, 6), 2.8, 8)])
			return flung
		&"slash":
			# One broad blade, sweeping round.
			return [RisoShapes.crescent(c + Vector2(2, -2), 23.0, Vector2(-9, 7), 48)]
		&"nova":
			# A burst: a bead and eight rays, long and short by turns.
			var burst: Array[PackedVector2Array] = [RisoShapes.circle(c, 8.0, 18)]
			for i: int in range(8):
				var d: Vector2 = Vector2.from_angle(TAU * float(i) / 8.0 - PI * 0.5)
				var side: Vector2 = Vector2(-d.y, d.x) * 3.2
				burst.append(RisoShapes.tri(c + d * 12.0 + side, c + d * (24.0 if i % 2 == 0 else 18.0), c + d * 12.0 - side))
			return burst
		&"push":
			# A gust: three bows side by side, like ))).
			var gust: Array[PackedVector2Array] = []
			for k: int in range(3):
				gust.append(RisoWard.arc(PUSH_R - 5.5, PUSH_R, -0.8, 0.8, c + Vector2(-30.0 + 11.0 * float(k), 0)))
			return gust
		&"seeker":
			# A homing bolt: a star at the end of a trail that wobbles as it hunts its mark.
			var head: Vector2 = c + Vector2(9, -9)
			var from: Vector2 = c + Vector2(-24, 18)
			var to: Vector2 = head + Vector2(-8, 8)
			var across: Vector2 = (to - from).normalized().orthogonal()
			var trail: PackedVector2Array = PackedVector2Array()
			for k: int in range(SEEKER_STEPS + 1):
				var u: float = float(k) / float(SEEKER_STEPS)
				trail.append(from.lerp(to, u) + across * sin(u * TAU * SEEKER_WOBBLES) * SEEKER_SWAY * (1.0 - u * 0.6))
			return [RisoShapes.sparkle(head, 15.0), _ribbon(trail, 1.5, 8.0)]
		&"lunge":
			# A spear thrust: a shaft and its broad point.
			return [RisoShapes.rrect(c.x - 24, c.y - 3, 26, 6, 3), PackedVector2Array([c + Vector2(4, 0), c + Vector2(11, -10), c + Vector2(25, 0), c + Vector2(11, 10)])]
		&"hex":
			# A comet: a big spark with a straight tail tapering behind it.
			var head: Vector2 = c + Vector2(4, -4)
			return [RisoShapes.sparkle(head, 22.0), _ribbon(PackedVector2Array([c + Vector2(-24, 24), head + Vector2(-8, 8)]), 1.0, 11.0)]
		&"resurrect":
			# A headstone, round-topped, a cross of paper through it, a soft spark rising off it.
			var stone: PackedVector2Array = _merged(RisoShapes.circle(c + Vector2(0, -2), 14.0, 24), RisoShapes.rrect(c.x - 14, c.y - 2, 28, 22, 2))
			var cross: PackedVector2Array = _at(c + Vector2(0, 2), [Vector2(-2.5, -11), Vector2(2.5, -11), Vector2(2.5, -5), Vector2(8, -5), Vector2(8, 0), Vector2(2.5, 0),
				Vector2(2.5, 11), Vector2(-2.5, 11), Vector2(-2.5, 0), Vector2(-8, 0), Vector2(-8, -5), Vector2(-2.5, -5)])
			var grave: Array[PackedVector2Array] = _pierced(stone, [cross], c.y)
			grave.append(RisoShapes.sparkle(c + Vector2(0, -26), 7.0))
			return grave
		&"mend":
			# A draught: a round flask, stoppered, a cross of paper on it.
			var flask: PackedVector2Array = _merged(RisoShapes.circle(c + Vector2(0, 8), 13.0, 24), RisoShapes.rrect(c.x - 4.5, c.y - 15, 9, 14, 2))
			var cross: PackedVector2Array = _at(c + Vector2(0, 8), [Vector2(-2, -6), Vector2(2, -6), Vector2(2, -2), Vector2(6, -2), Vector2(6, 2), Vector2(2, 2),
				Vector2(2, 6), Vector2(-2, 6), Vector2(-2, 2), Vector2(-6, 2), Vector2(-6, -2), Vector2(-2, -2)])
			var draught: Array[PackedVector2Array] = _pierced(flask, [cross], c.y + 8.0)
			draught.append(RisoShapes.rrect(c.x - 6.5, c.y - 22, 13, 5, 2))
			return draught
		&"ferry":
			# A raft of four planks, arrows over it both ways: to and fro.
			var raft: Array[PackedVector2Array] = [RisoMarks.chevron(c + Vector2(-10, -9), Vector2.LEFT, 0.45), RisoMarks.chevron(c + Vector2(10, -9), Vector2.RIGHT, 0.45)]
			for k: int in range(4):
				raft.append(RisoShapes.rrect(c.x - 21.25 + 11.0 * float(k), c.y + 4, 9.5, 9, 2))
			return raft
		&"ward":
			# Three curved plates in a ring round a bead.
			var guard: Array[PackedVector2Array] = [RisoShapes.circle(c, 6.0, 14)]
			for i: int in range(3):
				var mid: float = -PI * 0.5 + TAU * (float(i) + 0.5) / 3.0
				guard.append(RisoWard.arc(14.0, 22.0, mid - 0.8, mid + 0.8, c))
			return guard
		&"keyring":
			# A ring with two keys hanging off it to one side.
			var ring: Array[PackedVector2Array] = RisoShapes.ring(c + Vector2(-10, -10), 8.0, 13.0, 28)
			for k: int in range(2):
				var turn: float = 0.35 + 0.75 * float(k)
				var xf: Transform2D = Transform2D(turn, c + Vector2(-10, -10) + Vector2.from_angle(turn) * 22.0)
				for poly: PackedVector2Array in RisoMarks.key_shape(Vector2.ZERO, 0.6, k):
					ring.append(xf * poly)
			return ring
	return [RisoShapes.sparkle(c, 18.0)]


## `points` moved to `c`.
static func _at(c: Vector2, points: Array[Vector2]) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		out.append(c + p)
	return out


## Rectangle `r` as a shape.
static func _box(r: Rect2) -> PackedVector2Array:
	return RisoShapes.rrect(r.position.x, r.position.y, r.size.x, r.size.y, 0.0)


## Shapes `a` and `b` as one (they must overlap).
static func _merged(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	return Geometry2D.merge_polygons(a, b)[0]


## A doorway round its middle `at`: a round-topped arch open to the floor, and the step it stands
## on.
static func _doorway(at: Vector2) -> Array[PackedVector2Array]:
	var arch: Array[PackedVector2Array] = Geometry2D.clip_polygons(RisoShapes.arch(at.x - 9, at.y - 17, 18, 29), RisoShapes.arch(at.x - 4, at.y - 12, 8, 25))
	arch.append(RisoShapes.rrect(at.x - 11, at.y + 13.5, 22, 4, 2))
	return arch


## Shape `body` with `holes` cut through it, each crossing the line across at height `y`: a shape
## has no holes, so the body is cut in two along that line and each half has the holes taken out of
## its edge. The halves meet along the line everywhere but at the holes (RisoShapes.ring is made the
## same way).
static func _pierced(body: PackedVector2Array, holes: Array[PackedVector2Array], y: float) -> Array[PackedVector2Array]:
	var box: Rect2 = Rect2(body[0], Vector2.ZERO)
	for p: Vector2 in body:
		box = box.expand(p)
	box = box.grow(1.0)
	var out: Array[PackedVector2Array] = []
	for half: Rect2 in [Rect2(box.position, Vector2(box.size.x, y - box.position.y)), Rect2(box.position.x, y, box.size.x, box.end.y - y)]:
		var pieces: Array[PackedVector2Array] = Geometry2D.intersect_polygons(body, _box(half))
		for hole: PackedVector2Array in holes:
			var cut: Array[PackedVector2Array] = []
			for piece: PackedVector2Array in pieces:
				cut.append_array(Geometry2D.clip_polygons(piece, hole))
			pieces = cut
		out.append_array(pieces)
	return out


## A band along `path` that widens from `w0` at its start to `w1` at its end: a tail, a streak.
static func _ribbon(path: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var n: int = path.size()
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in range(n):
		var along: Vector2 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var half: float = lerpf(w0, w1, float(i) / float(n - 1)) * 0.5
		left.append(path[i] + Vector2(-along.y, along.x) * half)
		right.append(path[i] - Vector2(-along.y, along.x) * half)
	right.reverse()
	left.append_array(right)
	return left
