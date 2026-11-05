class_name BrambleTangle
extends RefCounted
## The bramble's own vines (Bramble), as they live, are struck and die, and as they are printed:
## - its crown, a tangle of thorned canes walling off the head of its shaft. Each cane grows out of
##   the rock round the head (the roof, the far wall, the landing's side) and finds its own way
##   into the head, turning toward the room left between the canes already grown and curling of
##   itself; more sprout off those, until the head is filled (COVER). Nothing of it is there until
##   the bramble wakes (wake): then its canes grow out of the rock, the tips leading, thin and
##   thickening behind, thorns budding along them, sprouts branching off as their canes pass them;
## - its heart's stalk, a cane of its own out of the roof down through the middle of the crown, the
##   bud hanging from its tip (Bramble._draw_bud), so the bud is held whatever the crown does: the
##   hollow round the bud never cuts it, and the bud quivers and is drawn back with it;
## - its roots, one down the face of each wall of the shaft past its bulbs to the lowest bulb or
##   vine, with sprouts off them into the shaft: canes as the crown's are, as thick, thorned and
##   inked, but grown from the start, and printed under the bulbs and vines (draw).
## Every cane sways a little at rest. Struck (quiver), a shudder runs out from the blow along every
## cane near it, the tips shaking most. Round its heart (the bud the canes hide, Bramble._draw_bud)
## the canes draw back from a hollow (set_hollow), as wide as the bramble's wounds have made it:
## every cane that runs into the hollow ends at its edge, and everything that grew off it beyond is
## gone. Dying (die), a dry front runs out from the heart: each cane pales, thins, crinkles and its
## thorns droop and go straw-pale as it passes, and once a cane out of the rock and all that grew off
## it is dry, it draws back into the rock, its tips first, until nothing is left. The roots, longest,
## are last. All of it is grown from the level seed (never the world RNG): the same every visit.

## The crown's canes: how many at most, and the share of the head they fill before no more grow.
const CANES_MAX: int = 12
const COVER: float = 0.85
## Where its canes grow out of the rock round the head: how many out of the roof, out of the far
## wall and out of the landing's side under the way on, and how far into the rock each starts (px).
const FROM_ROOF: int = 2
const FROM_WALL: int = 2
const FROM_LANDING: int = 1
const ANCHOR_IN: float = 14.0
## How long a cane out of the rock and a sprout off another are (px, dealt between), and how wide
## each is at its foot (px, dealt between); every cane thins to TIP_WIDE at its tip. Sprouts sprout
## no further than SPROUT_GENS off the rock.
const LONG_ROCK: Vector2 = Vector2(320.0, 500.0)
const LONG_SPROUT: Vector2 = Vector2(130.0, 280.0)
const WIDE_ROCK: Vector2 = Vector2(48.0, 60.0)
const WIDE_SPROUT: Vector2 = Vector2(28.0, 36.0)
const TIP_WIDE: float = 7.0
## How a cane thins toward its tip: the higher, the longer it keeps its width before it tapers.
const TAPER: float = 1.6
const SPROUT_GENS: int = 2
## How many places along its canes a sprout weighs before it grows from the roomiest.
const SPROUT_TRIES: int = 8
## How a cane finds its way: its step (px), how far ahead it looks for room (px) and how far it may
## turn either way a step (radians), what a turn costs it against the room it finds (a share of a
## crowded square), how hard it curls of itself (radians a px, dealt between, either way), and how
## far under the head its canes may hang (px).
const STEP: float = 12.0
const LOOK: float = 40.0
const TURN: float = 0.32
const TURN_COST: float = 0.35
const CURL: Vector2 = Vector2(0.002, 0.007)
const FRINGE: float = 36.0
## The squares (px) the head is cut into to judge its room, and how far round a cane (px, past its
## half width) a square is taken as filled.
const GRID: float = 12.0
const GRID_PAD: float = 8.0
## Its thorns: how far apart along a cane (px, dealt between), how long (px, plus a share of the
## cane's width there), how far they hook toward the cane's tip (a share), how wide their feet are
## (a share of their length, at least THORN_FOOT px), and how much longer those hanging under the
## head are.
const THORN_EVERY: Vector2 = Vector2(40.0, 62.0)
const THORN_LONG: float = 20.0
const THORN_SHARE: float = 0.4
const THORN_HOOK: float = 0.4
const THORN_FEET: float = 0.28
const THORN_FOOT: float = 7.0
const THORN_HANG: float = 1.7
## Growing, once it wakes: how fast its canes grow out (px a second along them), how far behind the
## tip a cane is at its full width (px; nearer, it is thinner), and how far behind it a thorn is
## fully out (px).
const GROW_SPEED: float = 600.0
const GROW_THIN: float = 110.0
const THORN_GROW: float = 50.0
## Its sway at rest: how far it moves (px) and how fast (cycles a second); and how far along from the
## rock (px) a cane of the crown sways and quivers fully (a root, ROOT_FLEX of it everywhere).
const SWAY: float = 3.0
const SWAY_RATE: float = 0.3
const FLEX: float = 140.0
const ROOT_FLEX: float = 0.45
## A quiver: how fast it runs out from the blow (px a second), how fast it shakes (cycles a second),
## how quickly it dies away (a second) and how long it lasts (seconds), and how far from the blow it
## is half as strong (px). At most QUIVERS are felt at once (the oldest go).
const QUIVER_SPEED: float = 700.0
const QUIVER_RATE: float = 10.0
const QUIVER_DAMP: float = 4.5
const QUIVER_TIME: float = 1.1
const QUIVER_FALL: float = 320.0
const QUIVERS: int = 6
## The hollow round the heart: how much wider than the bud it is (px), and how far its edge is
## softened, drawn back a little short of it (px).
const HOLLOW_PAD: float = 24.0
## Dying: the dry front runs out from the heart at DRY_SPEED (px a second), a cane out of the rock
## and all that grew off it up to DRY_JITTER seconds later (hashed); each point dries over DRY_TIME;
## BACK_DELAY after the last of it is dry it draws back into the rock, over BACK_MIN seconds plus its
## reach at BACK_SPEED (a root, the longest by far, at ROOT_BACK_SPEED).
const DRY_SPEED: float = 1600.0
const DRY_JITTER: float = 0.2
const DRY_TIME: float = 0.55
const BACK_DELAY: float = 0.25
const BACK_MIN: float = 0.3
const BACK_SPEED: float = 450.0
const ROOT_BACK_SPEED: float = 1800.0
## Drying, how much thinner a cane grows (a share of its width) and how far it crinkles (px); printed
## in DRY_STEPS steps.
const DRY_THIN: float = 0.45
const DRY_CRINKLE: float = 4.0
const DRY_STEPS: int = 6
## The inks: canes out of the rock and the roots (the tangle's depths, dark) and those sprouted
## over them (bark); and once dry, the blue left on each, the night left on the dark ones, and the
## pink on a thorn with blue screened over it (straw-pale).
const DEEP_BLUE: float = 0.85
const DEEP_NIGHT: float = 0.42
const BARK_BLUE: float = 0.9
const BARK_NIGHT: float = 0.22
## The roots' thorns, which do not hurt, are bark rather than pink: the night left on them.
const ROOT_THORN_NIGHT: float = 0.1
const DRY_BLUE: float = 0.42
const DRY_NIGHT: float = 0.15
const DRY_PINK: float = 0.35
const DRY_THORN_BLUE: float = 0.35
## A root: how far out of the rock face it waves (px) in two waves along it (px long), how wide it is
## at its top and at its lowest bulb or vine (px), thinning to its tip over its last ROOT_TIP px;
## and its sprouts, about one every ROOTLET_EVERY px: how long (px, dealt between), how wide at
## their foot (px, dealt between), and how hard they curl (radians a px, dealt between, either way).
const ROOT_SWAY: float = 14.0
const ROOT_WAVES: Vector2 = Vector2(180.0, 70.0)
const ROOT_WIDE: Vector2 = Vector2(42.0, 28.0)
const ROOT_TIP: float = 90.0
const ROOTLET_EVERY: float = 240.0
const ROOTLET_LONG: Vector2 = Vector2(80.0, 150.0)
const ROOTLET_WIDE: Vector2 = Vector2(16.0, 22.0)
const ROOTLET_CURL: Vector2 = Vector2(0.004, 0.011)
## The heart's stalk: how wide it is at the roof and at the bud (px), how far from the bud's middle
## it grows out of the roof (a share of the head's width, dealt between, either way), how far above
## the tucked-up bud it comes straight down (px), and its thorns, fewer and smaller than the
## crown's (how far apart along it, px, dealt between; how long, px).
const STALK_WIDE: Vector2 = Vector2(34.0, 18.0)
const STALK_OFF: Vector2 = Vector2(0.08, 0.28)
const STALK_DROP: float = 50.0
const STALK_THORNS: Vector2 = Vector2(60.0, 90.0)
const STALK_THORN: float = 16.0
## Salt for the level seed.
const DEAL: int = 6670


## One cane: a line of points out of the rock (or off the cane it sprouts from), how wide it is at
## each and its thorns.
class Cane:
	## &"crown", &"stalk" (the heart's) or &"root".
	var kind: StringName = &""
	## How many canes off the rock it is (0: out of the rock itself).
	var gen: int = 0
	var pts: PackedVector2Array = PackedVector2Array()
	## How far along it each point is (px), and its whole length.
	var arc: PackedFloat32Array = PackedFloat32Array()
	var length: float = 0.0
	var widths: PackedFloat32Array = PackedFloat32Array()
	## The way across it at each point at rest (a unit vector), which it sways and quivers along.
	var across: PackedVector2Array = PackedVector2Array()
	## Its thorns: how far along it, which edge (1 or -1), and how long (px).
	var thorns: Array[Vector3] = []
	## The cane it sprouts from (its index, -1 for one out of the rock) and how far along that it
	## sprouts; how far from the rock its foot is, along the canes it grows from (px).
	var parent: int = -1
	var base: float = 0.0
	var from_rock: float = 0.0
	## The cane out of the rock it belongs to (its index), and a number hashed for it (0 to 1).
	var tree: int = 0
	var salt: float = 0.0
	## A root: the way out of its wall into the shaft (1 the left wall, -1 the right).
	var wall: float = 0.0

	func _init(of: StringName, points: PackedVector2Array, wide: PackedFloat32Array, k: float) -> void:
		kind = of
		pts = points
		widths = wide
		salt = k
		arc.resize(pts.size())
		across.resize(pts.size())
		for j: int in range(1, pts.size()):
			length += pts[j - 1].distance_to(pts[j])
			arc[j] = length
		for j: int in range(pts.size()):
			across[j] = BrambleTangle.across_at(pts, j)


var canes: Array[Cane] = []
var level_seed: int = 0
## The head it walls off (px), and where its crown may grow (the head and a fringe under it).
var head: Rect2 = Rect2()
var room: Rect2 = Rect2()
## The bramble's clock (seconds), set by it each frame; when it woke (-1 asleep) and when it began to
## die (-1 alive).
var now: float = 0.0
var woke_at: float = -1.0
var died_at: float = -1.0
## The blows it still feels: where (x, y), when (z) and how hard (w, px).
var quivers: Array[Vector4] = []
## The hollow round its heart: its middle and its half sizes (px; zero for none).
var hollow_at: Vector2 = Vector2.ZERO
var hollow_r: Vector2 = Vector2.ZERO
## Dying: where the dry front sets out from; for each cane out of the rock (by index), when its
## last point is dry, when it starts to draw back and how long that takes, and how far from the rock
## its furthest point is (px); and when the last of it is in (seconds into its death).
var dry_from: Vector2 = Vector2.ZERO
var back_at: Dictionary = {}
var back_time: Dictionary = {}
var tree_reach: Dictionary = {}
var end_time: float = 0.0
## How far its crown reaches at the most once grown (px from the rock).
var crown_reach: float = 0.0
## The heart's stalk (one of `canes`), and how far down it reaches now: to the bud's cap, set by the
## bramble each frame as the bud drops (px, y).
var stalk: Cane = null
var bud_y: float = INF
## The room grid: how many squares across and down, and which are filled.
var _gw: int = 0
var _gh: int = 0
var _filled: PackedByteArray = PackedByteArray()


## The way across points `pts` at point `j` (a unit vector).
static func across_at(pts: PackedVector2Array, j: int) -> Vector2:
	var a: Vector2 = pts[maxi(j - 1, 0)]
	var b: Vector2 = pts[mini(j + 1, pts.size() - 1)]
	return (b - a).normalized().orthogonal()


## A number from 0 to 1 hashed from the level seed and `k`.
func deal(k: float) -> float:
	return RisoShapes.hash1(float(level_seed % 7919) * 0.37 + k * 1.7 + float(DEAL))


# ------------------------------------------------------------------ growing it

## Grow its crown over head `r` (px), the landing on side `inner` (1 right, -1 left); the heart's
## stalk down to the bud, at `bud_x`, its cap at `tuck_y` tucked up and `bare_y` bared; and its
## roots down the walls: `walls` is [the x of the left wall's face, the right's], and `lows` the
## lowest y each root reaches (the left's first). Its foot on the landing's side comes out from
## under the landing, at `landing_y`.
func grow(r: Rect2, inner: float, bud_x: float, tuck_y: float, bare_y: float, walls: Array[float], lows: Array[float], landing_y: float, seed_of: int) -> void:
	level_seed = seed_of
	head = r
	room = Rect2(r.position.x, r.position.y, r.size.x, r.size.y + FRINGE)
	canes.clear()
	_grow_crown(inner)
	_grow_stalk(bud_x, tuck_y, bare_y)
	_grow_roots(walls, lows, landing_y, inner)


## The heart's stalk: out of the roof a little to one side, bending down to the bud's middle above
## where the bud is tucked up, then straight down to where its cap hangs once bared; thick at the
## roof, thinner at the bud, with a few thorns.
func _grow_stalk(bud_x: float, tuck_y: float, bare_y: float) -> void:
	var off: float = lerpf(STALK_OFF.x, STALK_OFF.y, deal(700.0)) * head.size.x * (1.0 if deal(701.0) < 0.5 else -1.0)
	var a: Vector2 = Vector2(clampf(bud_x + off, head.position.x + 20.0, head.end.x - 20.0), head.position.y - ANCHOR_IN)
	var j: Vector2 = Vector2(bud_x, minf(tuck_y - STALK_DROP, bare_y))
	var drop: float = j.y - a.y
	var c1: Vector2 = a + Vector2(0.0, drop * 0.5)
	var c2: Vector2 = j - Vector2(0.0, drop * 0.45)
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = maxi(6, ceili(drop / STEP))
	for m: int in range(steps + 1):
		var u: float = float(m) / float(steps)
		var v: float = 1.0 - u
		pts.append(a * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + j * u * u * u)
	var y: float = j.y + STEP
	while y < bare_y:
		pts.append(Vector2(bud_x, y))
		y += STEP
	pts.append(Vector2(bud_x, bare_y + 4.0))
	var widths: PackedFloat32Array = PackedFloat32Array()
	for m: int in range(pts.size()):
		widths.append(lerpf(STALK_WIDE.x, STALK_WIDE.y, float(m) / float(pts.size() - 1)))
	var c: Cane = Cane.new(&"stalk", pts, widths, deal(702.0))
	c.tree = canes.size()
	var along: float = lerpf(STALK_THORNS.x, STALK_THORNS.y, deal(703.0)) * 0.6
	var side: float = 1.0
	var n: int = 0
	while along < c.length - 40.0:
		n += 1
		c.thorns.append(Vector3(along, side, STALK_THORN))
		side = -side
		along += lerpf(STALK_THORNS.x, STALK_THORNS.y, deal(704.0 + float(n) * 0.1))
	stalk = c
	canes.append(c)
	crown_reach = maxf(crown_reach, c.length)


## The crown: canes out of the rock round the head, then sprouts off them, until the head is filled.
func _grow_crown(inner: float) -> void:
	_gw = ceili(room.size.x / GRID)
	_gh = ceili(room.size.y / GRID)
	_filled = PackedByteArray()
	_filled.resize(_gw * _gh)
	var outer_x: float = head.position.x if inner > 0.0 else head.end.x
	var inner_x: float = head.end.x if inner > 0.0 else head.position.x
	# Where they grow out of the rock: [where, which way].
	var feet: Array[Array] = []
	for i: int in range(FROM_ROOF):
		var x: float = lerpf(head.position.x + 12.0, head.end.x - 12.0, (float(i) + 0.2 + 0.6 * deal(10.0 + float(i))) / float(FROM_ROOF))
		feet.append([Vector2(x, head.position.y - ANCHOR_IN), PI * 0.5 + (deal(11.0 + float(i)) - 0.5) * 1.1])
	for i: int in range(FROM_WALL):
		var y: float = lerpf(head.position.y + 14.0, head.end.y - 10.0, (float(i) + 0.2 + 0.6 * deal(20.0 + float(i))) / float(FROM_WALL))
		var out: float = 0.0 if inner > 0.0 else PI
		feet.append([Vector2(outer_x - inner * ANCHOR_IN, y), out + (deal(21.0 + float(i)) - 0.5) * 1.2])
	for i: int in range(FROM_LANDING):
		# Out of the landing's side, under the way on, reaching back across under the head.
		var y: float = head.end.y - lerpf(14.0, head.size.y * 0.3, deal(30.0 + float(i)))
		var back: float = PI if inner > 0.0 else 0.0
		feet.append([Vector2(inner_x + inner * ANCHOR_IN, y), back + (deal(31.0 + float(i)) - 0.5) * 0.8])
	var k: float = 40.0
	while canes.size() < CANES_MAX:
		k += 1.0
		var i: int = canes.size()
		if i < feet.size():
			var foot: Array = feet[i]
			var long: float = lerpf(LONG_ROCK.x, LONG_ROCK.y, deal(k + 0.1))
			_add_cane(foot[0], foot[1], long, lerpf(WIDE_ROCK.x, WIDE_ROCK.y, deal(k + 0.2)), -1, 0.0, k)
			continue
		if _cover() >= COVER:
			break
		# A sprout off a cane already grown: of SPROUT_TRIES places along the canes, the one with the
		# most room off either side of it, heading that way.
		var best: float = INF
		var from: int = -1
		var along: float = 0.0
		var side: float = 1.0
		for n: int in range(SPROUT_TRIES):
			var tried: int = mini(int(deal(k + 0.3 + float(n) * 0.11) * float(canes.size())), canes.size() - 1)
			var of: Cane = canes[tried]
			if of.gen >= SPROUT_GENS:
				continue
			var at_try: float = of.length * lerpf(0.1, 0.5, deal(k + 0.4 + float(n) * 0.13))
			var jj: int = _index_at(of, at_try)
			var spot: Vector2 = point_at(of, at_try)
			for way: float in [1.0, -1.0]:
				var room_at: float = _crowd(spot + of.across[jj] * way * LOOK) + _crowd(spot + of.across[jj] * way * LOOK * 2.0)
				if room_at < best:
					best = room_at
					from = tried
					along = at_try
					side = way
		if from < 0:
			break
		var parent: Cane = canes[from]
		var j: int = _index_at(parent, along)
		var on: Vector2 = (parent.pts[mini(j + 1, parent.pts.size() - 1)] - parent.pts[maxi(j - 1, 0)]).normalized()
		var at: Vector2 = point_at(parent, along)
		var heading: float = (parent.across[j] * side + on * lerpf(0.2, 0.9, deal(k + 0.5))).angle()
		var long2: float = lerpf(LONG_SPROUT.x, LONG_SPROUT.y, deal(k + 0.6))
		var wide: float = clampf(width_at(parent, along) * 0.85, WIDE_SPROUT.x, lerpf(WIDE_SPROUT.x, WIDE_SPROUT.y, deal(k + 0.7)))
		_add_cane(at, heading, long2, wide, from, along, k)
	crown_reach = 0.0
	for c: Cane in canes:
		crown_reach = maxf(crown_reach, c.from_rock + c.length)


## Grow a cane of the crown from `at` heading `heading` (radians), up to `long` px, `wide` px wide at
## its foot, off cane `parent` (-1 for out of the rock) `base` px along it; hashed by `k`.
func _add_cane(at: Vector2, heading: float, long: float, wide: float, parent: int, base: float, k: float) -> void:
	var curl: float = lerpf(CURL.x, CURL.y, deal(k + 0.8)) * (1.0 if deal(k + 0.85) < 0.5 else -1.0)
	var pts: PackedVector2Array = PackedVector2Array([at])
	var h: float = heading
	var p: Vector2 = at
	var inside: bool = false
	var out: int = 0
	for m: int in range(ceili(long / STEP)):
		# Of three ways (on, and a turn either way), the one with the most room ahead.
		var best: float = INF
		var best_h: float = h
		for turn: float in [-TURN, 0.0, TURN]:
			var ahead: Vector2 = p + Vector2.from_angle(h + turn) * LOOK
			var score: float = _crowd(ahead) + absf(turn) / TURN * TURN_COST + 0.15 * deal(k + float(m) * 0.13 + turn)
			if not room.has_point(ahead):
				score += 3.0
			if score < best:
				best = score
				best_h = h + turn
		h = lerp_angle(h, best_h, 0.6) + curl * STEP * (1.0 + 0.5 * sin(float(m) * 0.4 + k))
		p += Vector2.from_angle(h) * STEP
		pts.append(p)
		if room.has_point(p):
			inside = true
			out = 0
		elif inside:
			out += 1
			if out >= 2:
				break
	if pts.size() < 3:
		return
	var widths: PackedFloat32Array = PackedFloat32Array()
	for j: int in range(pts.size()):
		var u: float = float(j) / float(pts.size() - 1)
		widths.append(lerpf(wide, TIP_WIDE, pow(u, TAPER)) * (0.9 + 0.1 * sin(u * 9.0 + k)))
	var c: Cane = Cane.new(&"crown", pts, widths, deal(k + 0.9))
	c.parent = parent
	c.base = base
	if parent >= 0:
		var of: Cane = canes[parent]
		c.gen = of.gen + 1
		c.from_rock = of.from_rock + base
		c.tree = of.tree
	else:
		c.tree = canes.size()
	_thorns(c, k)
	canes.append(c)
	for j: int in range(pts.size()):
		_fill(pts[j], widths[j] * 0.5 + GRID_PAD)


## Thorns along cane `c` (hashed by `k`), on alternate edges now and then, hooked toward its tip,
## the longer where it is thicker.
func _thorns(c: Cane, k: float) -> void:
	var along: float = lerpf(THORN_EVERY.x, THORN_EVERY.y, deal(k + 1.1))
	var side: float = 1.0 if deal(k + 1.2) < 0.5 else -1.0
	var n: int = 0
	while along < c.length - 6.0:
		n += 1
		if deal(k + 1.3 + float(n) * 0.07) < 0.8:
			c.thorns.append(Vector3(along, side, THORN_LONG + width_at(c, along) * THORN_SHARE * (0.8 + 0.4 * deal(k + 1.4 + float(n) * 0.05))))
		side = -side
		along += lerpf(THORN_EVERY.x, THORN_EVERY.y, deal(k + 1.5 + float(n) * 0.09))


## Its roots: one down the face of each wall, from up in the head past the bulbs and vines on it to
## the lowest, wandering off the rock face, thick as a crown's cane, thinning past the lowest and
## thorned; on the landing's side out from under the landing. Sprouts branch off them into the
## shaft now and then.
func _grow_roots(walls: Array[float], lows: Array[float], landing_y: float, inner: float) -> void:
	for side: int in [0, 1]:
		var out: float = 1.0 if side == 0 else -1.0
		var k: float = 500.0 + float(side) * 10.0
		var p1: float = deal(k + 0.1) * TAU
		var p2: float = deal(k + 0.2) * TAU
		var on_landing: bool = (out < 0.0) == (inner > 0.0)
		var y: float = landing_y - 4.0 if on_landing else head.position.y + 30.0
		var top: float = y
		var low: float = lows[side] + ROOT_TIP * 0.5
		var pts: PackedVector2Array = PackedVector2Array()
		var widths: PackedFloat32Array = PackedFloat32Array()
		while y <= low:
			var u: float = clampf((y - top) / maxf(low - ROOT_TIP - top, 1.0), 0.0, 1.0)
			var tip: float = clampf((low - y) / ROOT_TIP, 0.0, 1.0)
			var wave: float = 0.6 * sin(y * TAU / ROOT_WAVES.x + p1) + 0.4 * sin(y * TAU / ROOT_WAVES.y + p2)
			pts.append(Vector2(walls[side] + out * ROOT_SWAY * (0.5 + 0.5 * wave), y))
			widths.append(lerpf(TIP_WIDE, lerpf(ROOT_WIDE.x, ROOT_WIDE.y, u), pow(tip, 0.6)) * (0.9 + 0.1 * sin(y * TAU / ROOT_WAVES.y * 1.3 + p1)))
			y += 10.0
		if pts.size() < 3:
			continue
		var root: Cane = Cane.new(&"root", pts, widths, deal(k))
		root.tree = canes.size()
		root.wall = out
		_thorns(root, k + 0.6)
		var at: int = canes.size()
		canes.append(root)
		var n: int = 0
		var along: float = ROOTLET_EVERY * (0.5 + 0.6 * deal(k + 0.3))
		while along < root.length - ROOT_TIP * 1.5:
			var j: int = _index_at(root, along)
			var into: float = 1.0 if root.across[j].x * out > 0.0 else -1.0
			_rootlet(at, along, into, lerpf(ROOTLET_LONG.x, ROOTLET_LONG.y, deal(k + 0.4 + float(n) * 0.07)), minf(lerpf(ROOTLET_WIDE.x, ROOTLET_WIDE.y, deal(k + 0.45 + float(n) * 0.07)), root.widths[j] * 0.8), k + 1.0 + float(n))
			n += 1
			along += ROOTLET_EVERY * (0.7 + 0.6 * deal(k + 0.5 + float(n) * 0.07))


## A sprout off root `from` (its index), `along` px down it, heading off its edge `side` (1 or -1)
## into the shaft and on down along the root, `long` px long and `wide` px wide at its foot,
## arching, tapering as the crown's canes do, thorned.
func _rootlet(from: int, along: float, side: float, long: float, wide: float, k: float) -> void:
	var root: Cane = canes[from]
	var j: int = _index_at(root, along)
	var on: Vector2 = (root.pts[mini(j + 1, root.pts.size() - 1)] - root.pts[maxi(j - 1, 0)]).normalized()
	var heading: float = (root.across[j] * side * 0.7 + on * 0.8).angle()
	var curl: float = lerpf(ROOTLET_CURL.x, ROOTLET_CURL.y, deal(k + 0.7)) * (1.0 if deal(k + 0.75) < 0.5 else -1.0)
	var steps: int = maxi(4, ceili(long / STEP))
	var pts: PackedVector2Array = PackedVector2Array([point_at(root, along)])
	var widths: PackedFloat32Array = PackedFloat32Array([wide])
	for m: int in range(1, steps + 1):
		heading += curl * STEP
		pts.append(pts[m - 1] + Vector2.from_angle(heading) * STEP)
		widths.append(lerpf(wide, TIP_WIDE, pow(float(m) / float(steps), TAPER)))
	var c: Cane = Cane.new(&"root", pts, widths, deal(k + 0.77))
	_thorns(c, k + 0.9)
	c.gen = 1
	c.parent = from
	c.base = along
	c.from_rock = along
	c.tree = root.tree
	canes.append(c)


## The index of the point of cane `c` at or just past `along` px (at least 1).
static func _index_at(c: Cane, along: float) -> int:
	var j: int = 1
	while j < c.pts.size() - 1 and c.arc[j] < along:
		j += 1
	return j


## The point `along` px along cane `c`, at rest.
static func point_at(c: Cane, along: float) -> Vector2:
	for j: int in range(1, c.pts.size()):
		if along <= c.arc[j]:
			return c.pts[j - 1].lerp(c.pts[j], (along - c.arc[j - 1]) / maxf(c.arc[j] - c.arc[j - 1], 0.001))
	return c.pts[c.pts.size() - 1]


## Cane `c`'s width `along` px along it.
static func width_at(c: Cane, along: float) -> float:
	for j: int in range(1, c.arc.size()):
		if along <= c.arc[j]:
			return lerpf(c.widths[j - 1], c.widths[j], (along - c.arc[j - 1]) / maxf(c.arc[j] - c.arc[j - 1], 0.001))
	return c.widths[c.widths.size() - 1]


## How crowded the head is round `at` (0 to 1: the share of the 3 by 3 squares round it filled;
## outside the room, 1).
func _crowd(at: Vector2) -> float:
	var gx: int = floori((at.x - room.position.x) / GRID)
	var gy: int = floori((at.y - room.position.y) / GRID)
	var n: int = 0
	var full: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var x: int = gx + dx
			var y: int = gy + dy
			n += 1
			if x < 0 or y < 0 or x >= _gw or y >= _gh or _filled[y * _gw + x] != 0:
				full += 1
	return float(full) / float(n)


## Mark the squares within `r` px of `at` filled.
func _fill(at: Vector2, r: float) -> void:
	var x0: int = maxi(0, floori((at.x - r - room.position.x) / GRID))
	var x1: int = mini(_gw - 1, floori((at.x + r - room.position.x) / GRID))
	var y0: int = maxi(0, floori((at.y - r - room.position.y) / GRID))
	var y1: int = mini(_gh - 1, floori((at.y + r - room.position.y) / GRID))
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var mid: Vector2 = room.position + (Vector2(x, y) + Vector2.ONE * 0.5) * GRID
			if mid.distance_to(at) <= r + GRID * 0.5:
				_filled[y * _gw + x] = 1


## The share of the head (not its fringe) its crown fills.
func _cover() -> float:
	var rows: int = mini(_gh, ceili(head.size.y / GRID))
	var full: int = 0
	for y: int in range(rows):
		for x: int in range(_gw):
			full += _filled[y * _gw + x]
	return float(full) / float(maxi(rows * _gw, 1))


## The share of the head its crown fills, as grown (for the tests).
func cover() -> float:
	return _cover()


# ------------------------------------------------------------------ living, struck, dying

## It wakes: its crown grows out of the rock from now.
func wake() -> void:
	if woke_at < 0.0:
		woke_at = now


## Whether it has woken.
func awake() -> bool:
	return woke_at >= 0.0


## How far its crown has grown out (px from the rock).
func grown_px() -> float:
	return maxf(0.0, now - woke_at) * GROW_SPEED if woke_at >= 0.0 else 0.0


## How much of its crown has grown out (0 to 1).
func grown() -> float:
	return clampf(grown_px() / maxf(crown_reach, 1.0), 0.0, 1.0)


## A blow `power` px hard at `at`: a shudder runs out from it.
func quiver(at: Vector2, power: float) -> void:
	quivers.append(Vector4(at.x, at.y, now, power))
	while quivers.size() > QUIVERS:
		quivers.pop_front()


## Whether any blow is still felt.
func quivering() -> bool:
	return quivers.any(func(q: Vector4) -> bool: return now - q.z < QUIVER_TIME + 1.0)


## The canes draw back from a hollow at `at`, `r` px across each way (half sizes; zero for none).
func set_hollow(at: Vector2, r: Vector2) -> void:
	hollow_at = at
	hollow_r = r


## It dies, the dry front setting out from `from`: when each cane out of the rock, with all that grew
## off it, dries and draws back.
func die(from: Vector2) -> void:
	if died_at >= 0.0:
		return
	died_at = now
	dry_from = from
	var dry_end: Dictionary = {}
	tree_reach.clear()
	for c: Cane in canes:
		var last: float = 0.0
		for p: Vector2 in c.pts:
			last = maxf(last, dry_at(p, c))
		dry_end[c.tree] = maxf(float(dry_end.get(c.tree, 0.0)), last)
		tree_reach[c.tree] = maxf(float(tree_reach.get(c.tree, 0.0)), c.from_rock + c.length)
	end_time = 0.0
	for tree: int in dry_end:
		back_at[tree] = float(dry_end[tree]) + DRY_TIME + BACK_DELAY
		back_time[tree] = BACK_MIN + float(tree_reach[tree]) / (ROOT_BACK_SPEED if canes[tree].kind == &"root" else BACK_SPEED)
		end_time = maxf(end_time, float(back_at[tree]) + float(back_time[tree]))


## Whether it is dying.
func dying() -> bool:
	return died_at >= 0.0


## Seconds into its death that point `p` of cane `c` starts to dry.
func dry_at(p: Vector2, c: Cane) -> float:
	return p.distance_to(dry_from) / DRY_SPEED + DRY_JITTER * canes[c.tree].salt


## How dry point `p` of cane `c` is now (0 to 1).
func dryness(p: Vector2, c: Cane) -> float:
	if died_at < 0.0:
		return 0.0
	return clampf((now - died_at - dry_at(p, c)) / DRY_TIME, 0.0, 1.0)


## How far cane `c`'s whole tree has drawn back into the rock (0 to 1).
func drawn_back(c: Cane) -> float:
	if died_at < 0.0:
		return 0.0
	return smoothstep(0.0, 1.0, (now - died_at - float(back_at.get(c.tree, INF))) / float(back_time.get(c.tree, 1.0)))


## How far along each cane is out now (px; 0 for one not out at all): grown so far, short of the
## hollow, drawn back as far as its death has come, and none of a sprout whose foot is gone.
func reaches() -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(canes.size())
	var grown_to: float = grown_px()
	for i: int in range(canes.size()):
		var c: Cane = canes[i]
		var r: float = c.length
		if c.kind != &"root":
			r = minf(r, grown_to - c.from_rock)
		if c.kind == &"crown" and hollow_r.x > 0.5:
			r = minf(r, _hollow_cut(c))
		if c == stalk and bud_y < INF:
			r = minf(r, _arc_to_y(c, bud_y))
		if died_at >= 0.0:
			var keep: float = float(tree_reach.get(c.tree, 0.0)) * (1.0 - drawn_back(c))
			r = minf(r, keep - c.from_rock)
		if c.parent >= 0 and c.base > out[c.parent] - 2.0:
			r = 0.0
		out[i] = maxf(r, 0.0)
	return out


## How far along cane `c` it first reaches down to `y` (its whole length if it never does).
static func _arc_to_y(c: Cane, y: float) -> float:
	for j: int in range(1, c.pts.size()):
		if c.pts[j].y >= y:
			return lerpf(c.arc[j - 1], c.arc[j], (y - c.pts[j - 1].y) / maxf(c.pts[j].y - c.pts[j - 1].y, 0.001))
	return c.length


## Where the stalk's tip is now (px), swayed and quivering with it, so the bud hangs from it; and
## how far it is out (px), 0 once drawn back into the rock.
func stalk_tip() -> Vector2:
	if stalk == null:
		return Vector2.INF
	var r: float = reaches()[canes.find(stalk)]
	var j: int = _index_at(stalk, r)
	var at: Vector2 = point_at(stalk, r)
	return at + stalk.across[j] * _shake(at, stalk, r) * (1.0 - dryness(at, stalk))


## Whether the stalk has grown down as far as the bud (its reach to the bud's cap).
func holds_bud() -> bool:
	if stalk == null:
		return false
	return reaches()[canes.find(stalk)] >= _arc_to_y(stalk, bud_y) - 1.0


## How far along cane `c` it first runs into the hollow (its whole length if it never does).
func _hollow_cut(c: Cane) -> float:
	var f0: float = _in_hollow(c.pts[0])
	if f0 <= 0.0:
		return 0.0
	for j: int in range(1, c.pts.size()):
		var f: float = _in_hollow(c.pts[j])
		if f <= 0.0:
			return lerpf(c.arc[j - 1], c.arc[j], f0 / maxf(f0 - f, 0.0001))
		f0 = f
	return c.length


## Where `p` is against the hollow: below 0 inside it, above 0 outside.
func _in_hollow(p: Vector2) -> float:
	var d: Vector2 = (p - hollow_at) / hollow_r
	return d.length_squared() - 1.0


## How far point `p` of cane `c` is pushed across it now (px): its sway, and every blow still felt.
func _shake(p: Vector2, c: Cane, along: float) -> float:
	var flex: float = ROOT_FLEX if c.kind == &"root" else clampf((c.from_rock + along) / FLEX, 0.0, 1.0)
	if flex <= 0.0:
		return 0.0
	var out: float = SWAY * sin(now * SWAY_RATE * TAU + p.x * 0.031 + p.y * 0.017 + c.salt * 6.0)
	for q: Vector4 in quivers:
		var d: float = p.distance_to(Vector2(q.x, q.y))
		var tt: float = now - q.z - d / QUIVER_SPEED
		if tt < 0.0 or tt > QUIVER_TIME:
			continue
		out += q.w * exp(-tt * QUIVER_DAMP) * sin(tt * QUIVER_RATE * TAU + c.salt * 3.0 + along * 0.05) / (1.0 + d / QUIVER_FALL)
	return out * flex


## How far point `j` of cane `c` is pushed across it now (px; for the tests).
func shake_at(c: Cane, j: int) -> float:
	return _shake(c.pts[j], c, c.arc[j])


## Whether point `p` is inside the hollow round the heart (for the tests).
func in_hollow(p: Vector2) -> bool:
	return hollow_r.x > 0.5 and _in_hollow(p) < 0.0


## Where the tip of the root down the wall facing `out` (1 the left wall, into the shaft rightward;
## -1 the right) is now (px), or none (INF) if it has none.
func root_tip(out: float) -> Vector2:
	var reach: PackedFloat32Array = reaches()
	for i: int in range(canes.size()):
		var c: Cane = canes[i]
		if c.kind == &"root" and c.gen == 0 and c.wall == out:
			return point_at(c, reach[i])
	return Vector2.INF


# ------------------------------------------------------------------ the print

## Print on `ink` its roots (`roots`; printed first, under the bulbs and vines) or the rest (its
## crown and the heart's stalk): the canes out of the rock and the roots dark, those sprouted over
## them in bark, each set laid over the last, and their thorns in pink over all.
func draw(ink: InkCanvas, roots: bool) -> void:
	var reach: PackedFloat32Array = reaches()
	var grown_to: float = grown_px()
	# Shapes by layer (0 roots, 1 the crown's depths, 2 and 3 its bark) and by how dry, and thorns
	# by how dry.
	var bodies: Array = []
	for layer: int in range(4):
		var steps: Array = []
		for _s: int in range(DRY_STEPS + 1):
			var none: Array[PackedVector2Array] = []
			steps.append(none)
		bodies.append(steps)
	var spikes: Array = []
	for _s: int in range(DRY_STEPS + 1):
		var none2: Array[PackedVector2Array] = []
		spikes.append(none2)
	for i: int in range(canes.size()):
		var c: Cane = canes[i]
		var keep: float = reach[i]
		if keep < 1.5 or (c.kind == &"root") != roots:
			continue
		var layer: int = 2 if c.kind == &"stalk" else (1 if c.gen == 0 else 2 + (i % 2))
		_pose(c, keep, grown_to, bodies[layer], spikes)
	for layer: int in range(4):
		for step: int in range(DRY_STEPS + 1):
			var body: Array[PackedVector2Array] = bodies[layer][step]
			if body.is_empty():
				continue
			var dry: float = float(step) / float(DRY_STEPS)
			match layer:
				1:
					ink.lift_ink([RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.BLUE, RisoPrint.NIGHT], 1.0, body)
					ink.ink(RisoPrint.BLUE, lerpf(DEEP_BLUE, DRY_BLUE, dry), body, false)
					ink.ink(RisoPrint.NIGHT, lerpf(DEEP_NIGHT, DRY_NIGHT, dry), body, false)
				_:
					ink.lift_ink([RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.BLUE, RisoPrint.NIGHT], 1.0, body)
					ink.ink(RisoPrint.BLUE, lerpf(BARK_BLUE, DRY_BLUE, dry), body, false)
					ink.ink(RisoPrint.NIGHT, lerpf(BARK_NIGHT, 0.0, dry), body, false)
	for step: int in range(DRY_STEPS + 1):
		var spike: Array[PackedVector2Array] = spikes[step]
		if spike.is_empty():
			continue
		var dry: float = float(step) / float(DRY_STEPS)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 1.0, spike)
		if roots:
			# The roots' thorns do not hurt, so they are bark, not danger pink.
			ink.ink(RisoPrint.BLUE, lerpf(BARK_BLUE, DRY_BLUE, dry), spike, false)
			ink.ink(RisoPrint.NIGHT, lerpf(ROOT_THORN_NIGHT, 0.0, dry), spike, false)
			continue
		ink.ink(RisoPrint.PINK, lerpf(1.0, DRY_PINK, dry), spike)
		ink.ink(RisoPrint.BLUE, DRY_THORN_BLUE * dry, spike, false)


## Cane `c` as it lies now, `keep` px of it out, its crown grown to `grown_to` px from the rock:
## swayed and quivering, thin where it has just grown, its tip pointed, pieces of it as dry as they
## are into `steps` (by how dry), and its thorns into `spikes`.
func _pose(c: Cane, keep: float, grown_to: float, steps: Array, spikes: Array) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var arc: PackedFloat32Array = PackedFloat32Array()
	var across: PackedVector2Array = PackedVector2Array()
	for j: int in range(c.pts.size()):
		if j > 0 and c.arc[j] > keep:
			var u: float = (keep - c.arc[j - 1]) / maxf(c.arc[j] - c.arc[j - 1], 0.001)
			pts.append(c.pts[j - 1].lerp(c.pts[j], u))
			arc.append(keep)
			across.append(c.across[j])
			break
		pts.append(c.pts[j])
		arc.append(c.arc[j])
		across.append(c.across[j])
	if pts.size() < 2:
		return
	var n: int = pts.size()
	var top: PackedVector2Array = PackedVector2Array()
	var low: PackedVector2Array = PackedVector2Array()
	var dry: PackedFloat32Array = PackedFloat32Array()
	var moved: PackedVector2Array = PackedVector2Array()
	for j: int in range(n):
		var d: float = dryness(pts[j], c)
		var p: Vector2 = pts[j] + across[j] * (_shake(pts[j], c, arc[j]) * (1.0 - d) + sin(arc[j] * 0.4 + c.salt * 10.0) * DRY_CRINKLE * d)
		var w: float = width_at(c, arc[j]) * 0.5 * (1.0 - DRY_THIN * d)
		if c.kind != &"root":
			w *= clampf((grown_to - c.from_rock - arc[j]) / GROW_THIN, 0.3, 1.0)
		# Its tip, to a point; but the stalk holds the bud's cap at its full width.
		if c != stalk:
			w *= clampf((keep - arc[j]) / 10.0, 0.12, 1.0)
		top.append(p + across[j] * w)
		low.append(p - across[j] * w)
		dry.append(d)
		moved.append(p)
	# In pieces, each as dry as its first point (DRY_STEPS steps), sharing their ends.
	var a: int = 0
	var step_a: int = roundi(dry[0] * float(DRY_STEPS))
	for j: int in range(1, n):
		var step: int = roundi(dry[j] * float(DRY_STEPS))
		if step != step_a or j == n - 1:
			var piece: PackedVector2Array = top.slice(a, j + 1)
			var under: PackedVector2Array = low.slice(a, j + 1)
			under.reverse()
			piece.append_array(under)
			(steps[step_a] as Array[PackedVector2Array]).append(piece)
			a = j
			step_a = step
	for th: Vector3 in c.thorns:
		if th.x > keep - 6.0:
			continue
		var out: float = 1.0 if c.kind == &"root" else clampf((grown_to - c.from_rock - th.x) / THORN_GROW, 0.0, 1.0)
		if out <= 0.05:
			continue
		var j: int = 1
		while j < n - 1 and arc[j] < th.x:
			j += 1
		var u: float = (th.x - arc[j - 1]) / maxf(arc[j] - arc[j - 1], 0.001)
		var at: Vector2 = moved[j - 1].lerp(moved[j], u)
		var d: float = lerpf(dry[j - 1], dry[j], u)
		var on: Vector2 = (moved[j] - moved[j - 1]).normalized()
		var side: Vector2 = across[j] * th.y
		var long: float = th.z * out
		var way: Vector2 = (side * (1.0 - THORN_HOOK) + on * THORN_HOOK).normalized()
		if at.y > head.end.y - 4.0 and c.kind == &"crown":
			# Hanging under the head, pointing down the shaft, longer.
			way = (Vector2.DOWN + on * 0.25).normalized()
			long *= THORN_HANG
		var w: float = width_at(c, th.x) * 0.5 * (1.0 - DRY_THIN * d)
		var base: Vector2 = at + way * w * 0.6
		var foot: Vector2 = way.orthogonal() * maxf(THORN_FOOT, long * THORN_FEET)
		# Drying, it shrinks and droops back toward the rock.
		var tip: Vector2 = base + way * long * (1.0 - 0.3 * d) - on * long * 0.5 * d
		(spikes[roundi(d * float(DRY_STEPS))] as Array[PackedVector2Array]).append(PackedVector2Array([base - foot, tip, base + foot]))
