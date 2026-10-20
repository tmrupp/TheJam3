class_name Worm
extends Node2D
## The worm (Bosses.GARDEN_DOWN): the boss of the garden's way down, fought in its gate level
## (docs/REGIONS_PLAN.md §6). A worm of SEGMENTS segments (WormSegment), each as big as a cell of
## the level. It moves cell by cell, its body following its head through the cells it has been,
## and bends there like a pipe: straight through a cell it crosses, round a quarter turn in a cell
## where it turns. It crawls along the walls, floors and ceilings (its lair: every open cell of the
## level that touches rock), and digs: it can tunnel through rock to get at the wizard, cutting a
## hole in each face it goes in and out by. Burrow holes are dug all through the level.
## It lies under the rock by the way on it guards until the wizard comes within WAKE_RANGE, then
## stalks them through the whole level: it comes up out of a burrow near them, crawls for a while
## (after them), sinks into the nearest burrow and comes up again elsewhere. Whenever it is about
## to come out of the rock (from a burrow, or through a wall) it waits EMERGE_WARN first: the hole
## throbs pink and spits dirt, and the ground rumbles (the screen shakes, harder the nearer the
## wizard is), then it bursts out.
## - Its head bites (pink), then its piece rests for BITE_RECOVERY with its head harmless. Its
##   body is solid, so it walls off a tunnel as it passes, and every
##   segment but the head has thorns along one flank (WormSegment), alternating from one segment
##   to the next: they hurt to touch, and a strike from that side glances off, so the wizard has to
##   pick a segment whose bare side faces them to cut it. Each time it comes out of the rock the
##   segment behind its head takes the flank facing the wizard, and the rest alternate from it,
##   until it goes into the rock again.
## - Each segment takes SEGMENT_HP hits, its hits left printed on it. Its flesh is soft: any bolt or
##   dash cuts it (Wound.least), a parry too. A cut head or tail shortens the worm; a cut in the
##   middle splits it in two, the back half growing a head at the cut. A worm of SHORTEST segments
##   or fewer burrows away and dies. The boss is slain when no worm is left, and its relic waits on
##   the floor nearest where the last one went down (MapInfo.boss_slain).
## - Each bolt, dash or parry cuts one segment, the first it meets (Wound.whole).
## - Only a parried bite (to its face) stuns it (Stunner.parry_only), and then the whole worm: its
##   segments go still and pale together, take double and do not bite.
## - Its body blocks the dash (WormSegment.WORM_LAYER): a dash goes through only where it cuts.
## Nothing here draws from the world RNG. The lair and its holes come from the level's layout and
## seed, and the worm's own choices from an RNG of its own, seeded by the level.

## How many segments it starts with, the hits each takes, and the longest a worm can be and still
## die of its cuts (it burrows away).
const SEGMENTS: int = 10
const SEGMENT_HP: int = 3
const SHORTEST: int = 2
## How wide its body is, as a share of a cell.
const GIRTH: float = 0.84
## How fast it crawls (px/s), and faster while the wizard is in its lair (the wizard runs at 300).
const SPEED: float = 170.0
const HUNT_SPEED: float = 280.0
## Seconds a piece rests after its head bites: it stays solid, but its head is harmless.
const BITE_RECOVERY: float = 0.65
## Striking (_strike_reach): it strikes only when the wizard is where its lunge will reach (its jaws
## go LUNGE_REACH cells on, plus their own radius): ahead of its head by less than STRIKE_RANGE
## cells, and less than STRIKE_ACROSS cells to either side of the way it faces. It pauses,
## draws its head back PULL_BACK cells, lunges LUNGE_REACH cells on along its path, holds there as
## its jaws snap shut, and settles back; then waits STRIKE_REST before striking again. Seconds each.
const STRIKE_RANGE: float = 1.1
const STRIKE_ACROSS: float = 0.45
const STRIKE_PAUSE: float = 0.18
const STRIKE_PULL: float = 0.22
const STRIKE_LUNGE: float = 0.08
const STRIKE_HOLD: float = 0.08
const STRIKE_RETURN: float = 0.22
const STRIKE_REST: float = 0.6
const PULL_BACK: float = 0.3
const LUNGE_REACH: float = 0.8
## How near where it lies (cells, across plus down) the wizard must come to wake it.
const WAKE_RANGE: int = 12
## Burrow holes all through the level: HOLES_PER_K per 1000 cells (at least HOLES_MIN), at least
## HOLE_APART cells apart, none within HOLE_CLEAR cells of an exit. It comes up at least
## EMERGE_APART steps from the wizard when it can.
const HOLES_PER_K: float = 9.0
const HOLES_MIN: int = 6
const HOLE_APART: int = 6
const HOLE_CLEAR: int = 2
const EMERGE_APART: int = 5
## What a cell of rock counts for, against a cell of open air, when it chooses its way: it digs
## through a wall when going round is more than this many times as far.
const ROCK_COST: int = 3
## How long it waits, rumbling, before it comes out of the rock; how often the ground shakes
## meanwhile and how hard (at its nearest), how hard when it bursts out, and how far from the
## wizard (px) the shaking is felt at all.
const EMERGE_WARN: float = 1.2
const RUMBLE_EVERY: float = 0.15
const RUMBLE: float = 3.5
const BURST_SHAKE: float = 9.0
const RUMBLE_NEAR: float = 1100.0
## Seconds it stays up before making for a hole, under the rock before coming up again, and before
## it first starts to come up once woken.
const UP_TIME: Vector2 = Vector2(8.0, 12.0)
const UNDER_TIME: Vector2 = Vector2(1.2, 2.4)
const WAKE_TIME: float = 0.6
## Hunting, the share of turns it takes at random instead of toward the wizard; wandering, the
## chance it keeps straight on at a fork.
const WANDER: float = 0.2
const KEEP_ON: float = 0.6
## How long a short worm takes to burrow away.
const DIE_TIME: float = 0.9
## Points printed along each segment's length.
const SAMPLES: int = 8
## How finely a rounded end feels its way out to the rock in front of it (px).
const CAP_STEP: float = 3.0
## Thorns printed along each side of a segment, how wide each is at its foot (half, px), and how
## squarely an edge must face the way they point to bristle fully (they grow in from an edge square
## to it, so one turning toward or away from it grows or shrinks rather than popping).
const THORNS_ALONG: int = 4
const THORN_BASE: float = 8.5
const THORN_SHOWN: float = 0.35
## How much shorter than the body's middle an edge may run (on the inside of a bend) before no
## thorns grow there; they grow fully only where it runs as long or longer.
const THORN_BUNCHED: float = 0.45
## The scales on the thorny half of a segment (_draw_scales): how far out from its middle each row
## stands (a share of the half width), how many to a row along a segment, each one's radius (px),
## and the pink and night they print over the flesh: small enough that the print's grain breaks
## them into a speckle of deeper pink, a rough hide rather than drawn plates.
const SCALE_ROWS: Array[float] = [0.84, 0.6, 0.36]
const SCALES_ALONG: int = 6
const SCALE_R: float = 8.0
const SCALE_PINK: float = 1.0
const SCALE_SHADE: float = 0.1
## The shadow at the back of each segment, under the one behind: how far along it runs (a share of
## a segment) and how dark it is.
const JOINT: float = 0.22
const JOINT_SHADE: float = 0.16
## How deep a segment must sink into the wizard before the wizard is let through it (so standing on
## the worm is not mistaken for being caught inside it).
const WEDGE: float = 4.0
## How near the wizard the head opens its mouth wide (px).
const BITE_NEAR: float = 160.0
## The mouth's wedge: its root ahead of the centre, reach past the nose and half spread, in radii.
const MOUTH_ROOT: float = 0.2
const MOUTH_REACH: float = 1.3
const MOUTH_SPREAD: float = 1.25
## The share of its opening at a distance, and closed while resting or stunned.
const MOUTH_CLOSED: float = 0.25
const MOUTH_REST: float = 0.12
## Chomping (_gape): chomps a second far off and right at the wizard, and the share of each chomp
## spent easing open, then snapping shut (the rest it holds shut).
const CHOMP_SLOW: float = 0.8
const CHOMP_FAST: float = 2.6
const CHOMP_OPEN: float = 0.62
const CHOMP_SNAP: float = 0.1
## Biting: seconds its jaws take to slam shut, its strokes to fade (_draw_bite), and at the end of
## its rest to ease back open.
const BITE_SNAP: float = 0.08
const BITE_BURST: float = 0.3
const BITE_EASE: float = 0.15
## Its teeth (_teeth): where they stand along each jaw's edge (a share of the way from the mouth's
## root to the round of the head), and how long and how wide at the root (half), in radii.
const TEETH_UPPER: Array[float] = [0.3, 0.6, 0.88]
const TEETH_LOWER: Array[float] = [0.45, 0.75]
const TOOTH_LEN: float = 0.28
const TOOTH_HALF: float = 0.11
## The body's flesh: these covers of pink and green on paper, and the share of them left while it
## is stunned (pale). The head is pink in full, and STUNNED_FLESH of it while stunned.
const FLESH_PINK: float = 0.32
const FLESH_GREEN: float = 0.2
const STUNNED_FLESH: float = 0.3
## How much of the flesh's inks freshly dug earth takes (with a little more green, so it is earth
## and not worm): the crumbs round a burrow hole and the dirt a coming worm throws up.
const HOLE_EARTH: float = 0.8
## The ground pushed up round a burrow hole (_mound): its rims' height over the face (px), how far
## out it reaches either side (in the worm's radii), and the dark pit's half depth (px).
const HOLE_RIM: float = 16.0
const HOLE_REACH: float = 1.8
const HOLE_PIT: float = 9.0
## The crumbs on the mound, each across (in radii, from the middle), up off the face (px) and its
## radius (px).
const HOLE_CRUMBS: Array[Vector3] = [
	Vector3(-0.98, 14.0, 4.5), Vector3(0.86, 10.0, 4.0), Vector3(-1.32, 10.0, 4.0),
	Vector3(1.02, 15.0, 4.5), Vector3(-0.8, 7.0, 3.5), Vector3(1.4, 8.0, 4.0),
	Vector3(-1.12, 18.0, 3.0), Vector3(0.74, 6.0, 3.0), Vector3(-1.55, 5.0, 3.5),
]
## Salts for the level seed: the holes, and the worm's own choices.
const HOLE_DEAL: int = 6100
const MIND_DEAL: int = 6200
## The four ways out of a cell.
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]

## What a worm is doing: down in the rock, crawling, sinking into a hole, or burrowing away to die.
enum { UNDER, UP, DIVING, DYING }


## One worm of the boss (it starts as one, and splits): its segments, head first, and the cells they
## are in. It moves a cell at a time: `u` of the way from each segment's cell to the one ahead of it
## (the head's toward `next`). It knows a cell further on (`after`), so its head bends the way it
## will turn before it gets there rather than nosing on into the rock.
class Piece:
	var segments: Array[WormSegment] = []
	## Each segment's cell, head first, then the cell the tail has just left.
	var cells: Array[Vector2i] = []
	var next: Vector2i = Vector2i.ZERO
	var after: Vector2i = Vector2i.ZERO
	var u: float = 0.0
	var state: int = UNDER
	## Seconds left: under, until it comes up; up, until it makes for a hole.
	var clock: float = INF
	## The hole it is making for (an index into holes; -1 for none).
	var hole: int = -1
	## Burrowing away: 1 down to 0.
	var fade: float = 1.0
	## The flank the thorns of the segment behind its head are on: 1 the left of the way it heads
	## (Vector2.orthogonal), -1 the right; the segments behind alternate from it
	## (WormSegment.flank). Chosen as it comes out of the rock (side_toward), and kept until it
	## goes in again.
	var side: float = 1.0
	## About to come out of the rock: seconds left of the warning (0: not waiting), and until the
	## next rumble.
	var warn: float = 0.0
	var rumble: float = 0.0
	## Seconds left of the rest after biting the wizard.
	var recovery: float = 0.0
	## Striking at the wizard (see _strike_reach): seconds into the strike (-1: not striking), how
	## far its head reaches past where it lies along its path (cells; less than 0 drawn back), and
	## seconds left before it may strike again.
	var strike: float = -1.0
	var reach: float = 0.0
	var strike_wait: float = 0.0

	## Where its head lies along path(), in cells, reaching out (or drawn back) as it strikes.
	func head_at() -> float:
		return at(0) - reach

	## The cells its body runs through, from the one after the one its head is going into to the one
	## its tail has left: position s along it (in cells) is the middle of path()[s].
	func path() -> Array[Vector2i]:
		var out: Array[Vector2i] = [after, next]
		out.append_array(cells)
		return out

	## Where segment `k` lies along path(), in cells.
	func at(k: int) -> float:
		return float(k) + 2.0 - u


## A burrow hole: the rock cell it is dug into, the open cell in front of it, its mouth (on the rock
## face between them) and the way out of it.
class Hole:
	var cell: Vector2i
	var entry: Vector2i
	var mouth: Vector2
	var out: Vector2


var map_info: MapInfo
## Which boss it is (Bosses), and the cell the level placed it in.
var boss: StringName = &""
var home: Vector2i = Vector2i.ZERO
## The lair, every cell it crawls (cell -> true), and the holes.
var lair: Dictionary = {}
var holes: Array[Hole] = []
var pieces: Array[Piece] = []
## Whether the wizard has come near yet (it lies under until then), whether it is after them (from
## then on, while they are in the level), and their cell.
var awake: bool = false
var hunting: bool = false
var wizard_cell: Vector2i = Vector2i(-1, -1)
## Where the last segment went down, for the relic.
var last_at: Vector2 = Vector2.ZERO
var slain: bool = false
## How many times the ground has rumbled before it came out, and how many times it has come out
## (for the tests).
var rumbles: int = 0
var emergences: int = 0
var ink: InkCanvas
var t: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## A cell's size in pixels, and the middle of cell (0, 0).
var cell: float = 64.0
var origin: Vector2 = Vector2.ZERO
## Distances through the lair to a cell (goal -> {cell -> steps}), kept as they are asked for.
var _fields: Dictionary = {}
## How many fields to keep before starting afresh (the wizard's cell changes as they move).
const FIELDS_KEPT: int = 48


func _ready() -> void:
	# Over the terrain with the other things in a level (props, z 2); its segments draw nothing.
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)


func setup(info: MapInfo, v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	home = v
	var tm: TileMap = info.tile_map
	cell = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	origin = info.cell_position(Vector2i.ZERO)
	var w: LevelGen = info.world
	rng.seed = Rules.level_seed(w.seed_for_colors, MIND_DEAL)
	last_at = center(home)
	_find_lair(w)
	_dig_holes(w)
	var worm: Piece = Piece.new()
	for i: int in range(SEGMENTS):
		var segment: WormSegment = WormSegment.new(self, cell * GIRTH * 0.5, SEGMENT_HP)
		segment.name = "Segment%d" % i
		segment.flank = 1.0 if i % 2 == 1 else -1.0
		add_child(segment)
		worm.segments.append(segment)
		worm.cells.append(home)
	worm.cells.append(home)
	worm.next = home
	worm.after = home
	worm.segments[0].make_head()
	pieces.append(worm)


## The middle of cell `v`.
func center(v: Vector2i) -> Vector2:
	return origin + Vector2(v) * cell


# ------------------------------------------------------------------ the lair and its holes

## Whether the worm can crawl through cell `v` of `w`: open, and not a door or a gate.
static func passable(w: LevelGen, v: Vector2i) -> bool:
	if not w.is_valid(v):
		return false
	var type: LevelGen.Type = w.get_cell(v).type
	return type not in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE]


## The cells it crawls: every open cell of the level touching rock (or the level's edge), side or
## corner, so it keeps to the walls, floors and ceilings.
func _find_lair(w: LevelGen) -> void:
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var v: Vector2i = Vector2i(x, y)
			if not passable(w, v):
				continue
			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					var n: Vector2i = v + Vector2i(dx, dy)
					if n != v and (not w.is_valid(n) or w.is_ground(n)):
						lair[v] = true


## The burrow holes, all through the level: rock cells beside the lair, floors first, dealt by the
## level seed (no RNG draw), kept HOLE_APART apart and clear of the exits.
func _dig_holes(w: LevelGen) -> void:
	var found: Dictionary = {}
	var cells: Array = lair.keys()
	cells.sort()
	for v: Vector2i in cells:
		if w.exits.values().any(func(e: Vector2i) -> bool: return LevelGen.dist(e, v) < HOLE_CLEAR):
			continue
		for d: Vector2i in DIRS:
			var h: Vector2i = v + d
			if w.is_ground(h) and not found.has(h):
				found[h] = v
	var order: Array = found.keys()
	var seed_of: int = w.seed_for_colors
	# Floors first (the worm rises out of the ground), then walls and ceilings, each by the seed.
	var rank: Callable = func(h: Vector2i) -> float:
		var floor_hole: bool = h - (found[h] as Vector2i) == Vector2i(0, 1)
		return (0.0 if floor_hole else 1.0) + RisoDecor.h(seed_of, h, HOLE_DEAL)
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return float(rank.call(a)) < float(rank.call(b)))
	var count: int = maxi(HOLES_MIN, w.per_area(HOLES_PER_K))
	for h: Vector2i in order:
		if holes.size() >= count:
			break
		if holes.any(func(o: Hole) -> bool: return LevelGen.dist(o.cell, h) < HOLE_APART):
			continue
		_hole_at(h, found[h])


## The hole dug into rock cell `rock` from open cell `entry` (dug now if there is none yet).
func _hole_at(rock: Vector2i, entry: Vector2i) -> int:
	for i: int in range(holes.size()):
		if holes[i].cell == rock and holes[i].entry == entry:
			return i
	var hole: Hole = Hole.new()
	hole.cell = rock
	hole.entry = entry
	hole.out = Vector2(entry - rock)
	hole.mouth = (center(rock) + center(entry)) * 0.5
	holes.append(hole)
	return holes.size() - 1


## What it costs to go into cell `v`: 1 for open air, ROCK_COST for rock (it digs), 0 where it
## cannot go at all (out of the level, doors and gates, a secret room's walls).
func _cost(w: LevelGen, v: Vector2i) -> int:
	if not w.is_valid(v):
		return 0
	if w.is_ground(v):
		return ROCK_COST
	return 1 if passable(w, v) else 0


## How far every cell of the level is from `goal`, through the air and digging through rock (see
## _cost).
func _field(goal: Vector2i) -> Dictionary:
	if _fields.has(goal):
		return _fields[goal]
	if _fields.size() >= FIELDS_KEPT:
		_fields.clear()
	var w: LevelGen = map_info.world
	var far: Dictionary = {goal: 0}
	var buckets: Array = [[goal]]
	var d: int = 0
	while d < buckets.size():
		for v: Vector2i in buckets[d]:
			if int(far[v]) != d:
				continue
			for dir: Vector2i in DIRS:
				var n: Vector2i = v + dir
				var c: int = _cost(w, n)
				if c <= 0 or int(far.get(n, 1 << 30)) <= d + c:
					continue
				far[n] = d + c
				while buckets.size() <= d + c:
					buckets.append([])
				(buckets[d + c] as Array).append(n)
		d += 1
	_fields[goal] = far
	return far


# ------------------------------------------------------------------ moving

func _physics_process(delta: float) -> void:
	if map_info == null or slain:
		return
	var player: Player = map_info.player
	var here: bool = player != null and is_instance_valid(player)
	if here:
		wizard_cell = map_info.cell_at(player.global_position)
	if here and not awake and LevelGen.dist(wizard_cell, home) <= WAKE_RANGE:
		awake = true
		for p: Piece in pieces:
			p.clock = WAKE_TIME
	hunting = here and awake
	# A harder preset runs it faster (Difficulty.haste).
	for p: Piece in pieces.duplicate():
		_step(p, delta * Difficulty.haste())
	for p: Piece in pieces:
		_hold(p)
		_place(p)
	_unwedge(player)
	if pieces.is_empty():
		_die()


## A piece's turn: down, wait to come up; up or diving, crawl on; dying, fade.
func _step(p: Piece, delta: float) -> void:
	match p.state:
		UNDER:
			if awake:
				p.clock -= delta
				if p.clock <= 0.0:
					_emerge(p)
		UP, DIVING:
			if p.warn > 0.0:
				_rumble(p, delta)
				return
			if _stunned(p):
				p.strike = -1.0
				return
			p.strike_wait = maxf(0.0, p.strike_wait - delta)
			if p.strike < 0.0:
				# Its head settles back to where it lies (after a bite, or a strike cut short).
				p.reach = move_toward(p.reach, 0.0, delta * LUNGE_REACH / STRIKE_RETURN)
			if p.recovery > 0.0:
				p.recovery = maxf(0.0, p.recovery - delta)
				return
			if p.strike >= 0.0:
				# Striking: held still while its head draws back and lunges.
				p.strike += delta
				p.reach = _strike_reach(p.strike)
				if p.strike >= STRIKE_PAUSE + STRIKE_PULL + STRIKE_LUNGE + STRIKE_HOLD + STRIKE_RETURN:
					p.strike = -1.0
					p.reach = 0.0
					p.strike_wait = STRIKE_REST
				return
			if p.reach == 0.0 and _can_strike(p):
				p.strike = 0.0
				return
			if p.state == UP:
				p.clock -= delta
				if p.clock <= 0.0 and p.hole < 0 and not holes.is_empty():
					p.hole = _nearest_hole(p.cells[0])
			p.u += (HUNT_SPEED if hunting else SPEED) / cell * delta
			while p.u >= 1.0 and p.state != UNDER and p.warn <= 0.0:
				p.u -= 1.0
				p.cells.push_front(p.next)
				p.cells.pop_back()
				_stepped(p)
		DYING:
			p.fade -= delta / DIE_TIME
			if p.fade <= 0.0:
				_bury(p)


## Each segment has moved up a cell: choose where the head goes next. In its hole, the head stays
## there and the body slides in after it, until the whole worm is under.
func _stepped(p: Piece) -> void:
	var head: Vector2i = p.cells[0]
	if p.state == DIVING or (p.hole >= 0 and head == holes[p.hole].cell):
		p.state = DIVING
		p.next = head
		p.after = head
		if p.cells.slice(0, p.segments.size()).all(func(c: Vector2i) -> bool: return c == head):
			p.state = UNDER
			p.u = 0.0
			p.hole = -1
			p.clock = rng.randf_range(UNDER_TIME.x, UNDER_TIME.y)
		return
	var w: LevelGen = map_info.world
	if not passable(w, head) and passable(w, p.cells[1]):
		# In the rock, come from the open: there is a hole where it went in (dug as it headed in).
		_hole_at(head, p.cells[1])
	p.next = p.after
	if passable(w, head) and not passable(w, p.next):
		# Heading into a wall: the hole where it goes in is dug as its nose reaches the face, so
		# the body never slides into unbroken rock.
		var dug: Hole = holes[_hole_at(p.next, head)]
		RisoFx.burst(&"impact", dug.mouth, dug.out, [RisoPrint.BLUE, RisoPrint.NIGHT])
		_shake(dug.mouth, RUMBLE, 0.2)
	p.after = _choose(p, p.next, head)
	if not passable(w, head) and passable(w, p.next):
		# About to come out of the rock: wait, rumbling, at the hole it breaks out by.
		_hole_at(head, p.next)
		_warn(p)


## Hold the worm in the rock, its head at the face it is about to break out of, for EMERGE_WARN.
func _warn(p: Piece) -> void:
	p.u = 0.0
	p.warn = EMERGE_WARN
	p.rumble = 0.0


## The face a worm waiting in the rock is about to break out of: where, and the way out.
func _face(p: Piece) -> Array[Vector2]:
	return [(center(p.cells[0]) + center(p.next)) * 0.5, Vector2(p.next - p.cells[0])]


## A worm about to come out: the ground rumbles and dirt spits from the hole; at the end of the
## wait it bursts out.
func _rumble(p: Piece, delta: float) -> void:
	var face: Array[Vector2] = _face(p)
	p.warn = maxf(0.0, p.warn - delta)
	p.rumble -= delta
	if p.rumble <= 0.0:
		p.rumble = RUMBLE_EVERY
		rumbles += 1
		_shake(face[0], RUMBLE * (0.5 + 0.5 * (1.0 - p.warn / EMERGE_WARN)), RUMBLE_EVERY + 0.05)
		RisoFx.burst(&"impact", face[0], face[1], [RisoPrint.BLUE, RisoPrint.NIGHT])
	if p.warn <= 0.0:
		var player: Player = map_info.player
		if player != null and is_instance_valid(player):
			p.side = side_toward(face[1], face[0], player.global_position)
		emergences += 1
		_shake(face[0], BURST_SHAKE, 0.3)
		RisoFx.burst(&"hit", face[0], face[1], [RisoPrint.PINK, RisoPrint.BLUE])


## The flank (see Piece.side) facing `wizard` for a worm coming out at `mouth` heading `out`.
static func side_toward(out: Vector2, mouth: Vector2, wizard: Vector2) -> float:
	return 1.0 if (wizard - mouth).dot(out.orthogonal()) >= 0.0 else -1.0


## Shake the screen `intensity` for `sustain` seconds, as felt by the wizard from `at`: fully up
## close, not at all past RUMBLE_NEAR.
func _shake(at: Vector2, intensity: float, sustain: float) -> void:
	var player: Player = map_info.player
	if player == null or not is_instance_valid(player):
		return
	var near: float = clampf(1.0 - at.distance_to(player.global_position) / RUMBLE_NEAR, 0.0, 1.0)
	if near > 0.0:
		Wound.shake(intensity * near, sustain)


## Whether piece `p` is stunned (its segments are stunned together, see _hold).
func _stunned(p: Piece) -> bool:
	return p.segments.any(func(s: WormSegment) -> bool: return s.stunned())


## A stun on any segment stops the whole piece: every segment is held as long as the longest.
func _hold(p: Piece) -> void:
	var most: float = 0.0
	for s: WormSegment in p.segments:
		most = maxf(most, s.stunner.left)
	if most <= 0.0:
		return
	for s: WormSegment in p.segments:
		if s.stunner.left < most - 0.05:
			s.stunner.stun(most, true)


## Come up out of a hole: near the wizard (but not on top of them) while it is after them,
## anywhere otherwise. The whole worm starts down in the hole, its head at the mouth, and waits
## there rumbling (_warn) before it follows its head out.
func _emerge(p: Piece) -> void:
	if holes.is_empty():
		return
	var held: Dictionary = _held(p)
	var pick: int = -1
	var best: float = INF
	var field: Dictionary = _field(wizard_cell) if hunting else {}
	for i: int in range(holes.size()):
		if held.has(holes[i].entry):
			continue
		var score: float = rng.randf()
		if hunting:
			# Not too near; else the furthest.
			var steps: float = float(field.get(holes[i].entry, 9999))
			score = steps if steps >= EMERGE_APART else 10000.0 - steps
		if score < best:
			best = score
			pick = i
	if pick < 0:
		p.clock = UNDER_TIME.x
		return
	var hole: Hole = holes[pick]
	p.cells.clear()
	for i: int in range(p.segments.size() + 1):
		p.cells.append(hole.cell)
	p.next = hole.entry
	p.after = _choose(p, hole.entry, hole.cell)
	p.u = 0.0
	p.hole = -1
	p.state = UP
	p.clock = rng.randf_range(UP_TIME.x, UP_TIME.y)
	_warn(p)


## The hole nearest `from`.
func _nearest_hole(from: Vector2i) -> int:
	var field: Dictionary = _field(from)
	var best: int = 0
	for i: int in range(holes.size()):
		if float(field.get(holes[i].entry, INF)) < float(field.get(holes[best].entry, INF)):
			best = i
	return best


## The cell the head goes on to from `cur` (having come from `prev`): into its hole when there (and
## staying in it); else on along the walls or digging through rock, not into its own body or
## another worm if it can help it, toward its hole or the wizard (the cheaper way, see _cost), or
## wandering along the walls.
func _choose(p: Piece, cur: Vector2i, prev: Vector2i) -> Vector2i:
	if p.hole >= 0 and cur == holes[p.hole].cell:
		return cur
	if p.hole >= 0 and cur == holes[p.hole].entry:
		return holes[p.hole].cell
	var w: LevelGen = map_info.world
	var ways: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		if lair.has(cur + d) or w.is_ground(cur + d):
			ways.append(cur + d)
	# Never back the way it came, nor into its own body as it will lie then (the tail moves on).
	var body: Array[Vector2i] = [prev]
	body.append_array(p.cells.slice(0, maxi(1, p.segments.size() - 2)))
	ways = ways.filter(func(n: Vector2i) -> bool: return not body.has(n))
	if ways.is_empty():
		return _dig(p, cur, prev)
	var held: Dictionary = _held(p)
	var on: Array[Vector2i] = ways.filter(func(n: Vector2i) -> bool: return not held.has(n))
	if on.is_empty():
		on = ways
	var goal: Variant = null
	if p.hole >= 0:
		goal = holes[p.hole].entry
	elif hunting and rng.randf() >= WANDER:
		goal = wizard_cell
	if goal != null:
		var field: Dictionary = _field(goal as Vector2i)
		# Ties are broken by where the worm starts looking, so it does not always turn the same way.
		var first: int = rng.randi_range(0, on.size() - 1)
		var best: Vector2i = on[first]
		for k: int in range(on.size()):
			var n: Vector2i = on[(first + k) % on.size()]
			if int(field.get(n, 9999)) < int(field.get(best, 9999)):
				best = n
		return best
	# Wandering, it keeps to the open where it can.
	var open: Array[Vector2i] = on.filter(func(n: Vector2i) -> bool: return lair.has(n))
	if not open.is_empty():
		on = open
	var ahead: Vector2i = cur + (cur - prev)
	if on.has(ahead) and rng.randf() < KEEP_ON:
		return ahead
	return on[rng.randi_range(0, on.size() - 1)]


## Boxed in (its own body, doors or the level's edge all round): rather than turn back on itself,
## it digs a new hole into any rock beside its head and burrows away there. With no rock to dig
## into it goes on into the open; with nowhere at all, back the way it came.
func _dig(p: Piece, cur: Vector2i, prev: Vector2i) -> Vector2i:
	var w: LevelGen = map_info.world
	var tries: Array[Vector2i] = [cur + (cur - prev)]
	for d: Vector2i in DIRS:
		tries.append(cur + d)
	for c: Vector2i in tries:
		if c != prev and w.is_ground(c):
			p.hole = _hole_at(c, cur)
			return c
	for c: Vector2i in tries:
		if c != prev and not p.cells.has(c) and passable(w, c):
			return c
	return prev


## The cells the other worms are in, and going into.
func _held(p: Piece) -> Dictionary:
	var out: Dictionary = {}
	for o: Piece in pieces:
		if o == p or o.state == UNDER:
			continue
		out[o.next] = true
		out[o.after] = true
		for i: int in range(o.segments.size()):
			out[o.cells[i]] = true
	return out


## The point `s` cells along `path` (see Piece.path): through each cell the body runs from the
## middle of the edge it comes in by to the middle of the edge it goes out by, straight across, or
## round a quarter circle about the corner between them where it turns.
func point(path: Array[Vector2i], s: float) -> Vector2:
	var j: int = clampi(roundi(s), 0, path.size() - 1)
	var u: float = clampf(float(j) + 0.5 - s, 0.0, 1.0)
	var c: Vector2 = center(path[j])
	var ahead: Vector2 = Vector2(path[j - 1] - path[j]) if j > 0 else Vector2.ZERO
	var behind: Vector2 = Vector2(path[j + 1] - path[j]) if j + 1 < path.size() else Vector2.ZERO
	if ahead == Vector2.ZERO and behind == Vector2.ZERO:
		ahead = Vector2.RIGHT
	if ahead == Vector2.ZERO:
		ahead = -behind
	if behind == Vector2.ZERO:
		behind = -ahead
	var h: float = cell * 0.5
	var from: Vector2 = c + behind * h
	var to: Vector2 = c + ahead * h
	if ahead == -behind:
		return from.lerp(to, u)
	if ahead == behind:
		# Doubling back on itself: in to the middle and out again.
		return from.lerp(c, u * 2.0) if u < 0.5 else c.lerp(to, u * 2.0 - 1.0)
	var corner: Vector2 = c + (ahead + behind) * h
	var a0: float = (from - corner).angle()
	return corner + Vector2.from_angle(a0 + angle_difference(a0, (to - corner).angle()) * u) * h


## The way the body faces at `s` along `path`: toward the head.
func facing(path: Array[Vector2i], s: float) -> Vector2:
	var d: Vector2 = point(path, s - 0.05) - point(path, s + 0.05)
	return d.normalized() if d != Vector2.ZERO else Vector2.RIGHT


## Whether the body is out in the open at `s` along `path` (not down in the rock of a hole).
func open_at(path: Array[Vector2i], s: float) -> bool:
	return passable(map_info.world, path[clampi(roundi(s), 0, path.size() - 1)])


## The stretches of the body from `front` to `back` along `path` that are out in the open, cell by
## cell: the body crosses from one cell to the next at the middle of their shared edge, so a
## stretch ends exactly at a hole's rock face, and the worm slides into the ground cleanly.
func _runs(path: Array[Vector2i], front: float, back: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for j: int in range(clampi(roundi(front), 0, path.size() - 1), clampi(roundi(back), 0, path.size() - 1) + 1):
		if not passable(map_info.world, path[j]):
			continue
		var a: float = maxf(front, float(j) - 0.5)
		var b: float = minf(back, float(j) + 0.5)
		if b <= a:
			continue
		if not out.is_empty() and absf(out[out.size() - 1].y - a) < 0.001:
			out[out.size() - 1].y = b
		else:
			out.append(Vector2(a, b))
	return out


## Put each segment's body where it lies along the worm's path. One down in a hole is not shown,
## nor live; nor is a worm burrowing away live.
func _place(p: Piece) -> void:
	var path: Array[Vector2i] = p.path()
	for k: int in range(p.segments.size()):
		var s: WormSegment = p.segments[k]
		var along: float = p.head_at() if k == 0 else p.at(k)
		s.global_position = point(path, along)
		s.heading = facing(path, along)
		s.spikes = s.heading.orthogonal() * p.side * s.flank
		if s.thorns != null:
			s.thorns.rotation = s.spikes.angle()
		s.shown = p.state != UNDER and open_at(path, along)
		s.set_live(s.shown and p.state != DYING)
		s.recovering = k == 0 and p.recovery > 0.0
		s.sync_touch()


## How far a striking head reaches `since` seconds into its strike (cells along its path; less
## than 0 drawn back): still while it pauses, drawing back, lunging out quicker and quicker, held
## there, then easing back to where it lies.
static func _strike_reach(since: float) -> float:
	var t0: float = since - STRIKE_PAUSE
	if t0 < 0.0:
		return 0.0
	if t0 < STRIKE_PULL:
		var u: float = t0 / STRIKE_PULL
		return -PULL_BACK * (1.0 - (1.0 - u) * (1.0 - u))
	t0 -= STRIKE_PULL
	if t0 < STRIKE_LUNGE:
		var u: float = t0 / STRIKE_LUNGE
		return lerpf(-PULL_BACK, LUNGE_REACH, u * u)
	t0 -= STRIKE_LUNGE
	if t0 < STRIKE_HOLD:
		return LUNGE_REACH
	t0 -= STRIKE_HOLD
	return lerpf(LUNGE_REACH, 0.0, smoothstep(0.0, 1.0, minf(t0 / STRIKE_RETURN, 1.0)))


## Whether piece `p` strikes now: up and after the wizard, rested from its last strike, its head
## out in the open, the wizard near and ahead of it, and open air where it would lunge to.
func _can_strike(p: Piece) -> bool:
	if p.state != UP or not hunting or p.strike_wait > 0.0 or p.segments.is_empty():
		return false
	var head: WormSegment = p.segments[0]
	var player: Player = map_info.player
	if not head.live or player == null or not is_instance_valid(player):
		return false
	var path: Array[Vector2i] = p.path()
	var to: Vector2 = player.global_position - head.global_position
	var ahead: float = to.dot(head.heading)
	var across: float = absf(to.cross(head.heading))
	return ahead > 0.0 and ahead < cell * STRIKE_RANGE and across < cell * STRIKE_ACROSS \
			and open_at(path, p.at(0) - LUNGE_REACH)


## A head has bitten the wizard: hold its piece still and close its mouth for BITE_RECOVERY.
func bit(head: WormSegment) -> void:
	for p: Piece in pieces:
		if not p.segments.is_empty() and p.segments[0] == head and head.live and p.state != DYING:
			p.strike = -1.0
			p.recovery = BITE_RECOVERY
			head.recovering = true
			head.sync_touch()
			return


## The worm has moved where the wizard stands: let them through it rather than wedge them in the
## rock, and let it block them again once they are clear of it.
func _unwedge(player: Player) -> void:
	if player == null or not is_instance_valid(player) or player.collider == null or player.collider.shape == null:
		return
	var box: Rect2 = player.collider.shape.get_rect()
	box = Rect2(player.collider.global_position + box.position * player.collider.global_scale, box.size * player.collider.global_scale)
	var inside: bool = false
	for p: Piece in pieces:
		for s: WormSegment in p.segments:
			if s.live and s.global_position.clamp(box.position, box.end).distance_to(s.global_position) < s.radius - WEDGE:
				inside = true
	if player.get_collision_mask_value(WormSegment.WORM_LAYER) == inside:
		player.set_collision_mask_value(WormSegment.WORM_LAYER, not inside)


# ------------------------------------------------------------------ cuts and the end

## Segment `segment` has lost its last hit: the worm is cut there. A head or tail lost shortens the
## worm; a middle one splits it, and the back half grows a head at the cut, moving on into the
## cut's cell. A worm left SHORTEST or shorter burrows away.
func cut(segment: WormSegment) -> void:
	var p: Piece = null
	for o: Piece in pieces:
		if o.segments.has(segment):
			p = o
	if p == null:
		return
	var i: int = p.segments.find(segment)
	last_at = segment.global_position
	RisoFx.burst(&"hit", segment.global_position, segment.heading, [RisoPrint.PINK, RisoPrint.BLUE])
	Wound.shake(10.0, 0.18)
	segment.set_live(false)
	segment.queue_free()
	if i == 0:
		# The next segment is the head now, going on into the cell the old head was in.
		p.segments.remove_at(0)
		p.after = p.next
		p.next = p.cells.pop_front()
		if not p.segments.is_empty():
			p.segments[0].make_head()
	elif i == p.segments.size() - 1:
		p.segments.remove_at(i)
		p.cells.pop_back()
	else:
		var back: Piece = Piece.new()
		back.segments = p.segments.slice(i + 1)
		back.cells = p.cells.slice(i + 1)
		back.next = p.cells[i]
		back.u = p.u
		back.state = UP
		back.side = p.side
		back.clock = rng.randf_range(UP_TIME.x, UP_TIME.y)
		back.segments[0].make_head()
		p.segments = p.segments.slice(0, i)
		p.cells = p.cells.slice(0, i + 1)
		pieces.append(back)
		back.after = _choose(back, back.next, back.cells[0])
		_shorten(back)
	if p.segments.is_empty():
		pieces.erase(p)
	else:
		_shorten(p)


## A worm SHORTEST segments long or shorter burrows away where it is, and dies.
func _shorten(p: Piece) -> void:
	if p.segments.size() <= SHORTEST and p.state != DYING:
		p.state = DYING
		p.fade = 1.0


## A short worm has burrowed away: it is gone.
func _bury(p: Piece) -> void:
	for s: WormSegment in p.segments:
		if s.shown:
			last_at = s.global_position
			RisoFx.burst(&"impact", s.global_position, Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
		s.queue_free()
	pieces.erase(p)


## No worm is left: the boss is slain, and its relic waits on the free floor nearest where the last
## one went down.
func _die() -> void:
	slain = true
	var w: LevelGen = map_info.world
	var near: Vector2i = map_info.cell_at(last_at)
	var floor_cell: Variant = LevelGen.best_of(w.free_floors(), func(v: Vector2i) -> int: return LevelGen.dist(v, near))
	var at: Vector2 = map_info.cell_position(floor_cell as Vector2i) if floor_cell != null else last_at
	map_info.boss_slain(boss, at)
	queue_free()


## Slain outright (the F7 panel's Slay boss): every worm gone at once, and the relic left as for
## any death.
func slay() -> void:
	if slain:
		return
	for p: Piece in pieces:
		for s: WormSegment in p.segments:
			if s.shown:
				last_at = s.global_position
			s.queue_free()
	pieces.clear()
	_die()


## How many segments are left in all its worms.
func segments_left() -> int:
	var n: int = 0
	for p: Piece in pieces:
		n += p.segments.size()
	return n


# ------------------------------------------------------------------ the print

## Its holes, then each worm from tail to head: a pipe of pale flesh (bleached to paper while
## stunned) bending through its cells, a shadow at each joint, its hits left as dark dots across
## each segment, a rounded tail, the head pink with a wedge mouth cut out of its round front, lined
## with paper teeth, that chomps as the wizard comes near and slams shut as it bites, and the
## stun's stars circling over a stunned head. What is down in a hole is not printed.
func _process(delta: float) -> void:
	t += delta
	if ink == null:
		return
	ink.global_position = Vector2.ZERO
	ink.begin()
	for hole: Hole in holes:
		_draw_hole(hole)
	for p: Piece in pieces:
		if p.warn > 0.0:
			_draw_warning(p)
	var wizard: Vector2 = map_info.player.global_position if map_info != null and map_info.player != null else Vector2.INF
	for p: Piece in pieces:
		if p.state == UNDER or p.segments.is_empty():
			continue
		var path: Array[Vector2i] = p.path()
		var pale: bool = _stunned(p)
		var k: float = clampf(p.fade, 0.0, 1.0)
		var width: float = cell * GIRTH * k
		var last: int = p.segments.size() - 1
		for i: int in range(last, -1, -1):
			var s: WormSegment = p.segments[i]
			var front: float = p.at(i) - 0.5
			if i == 0:
				front = p.head_at()
			var back: float = p.at(i) + 0.5
			var flesh: Array[PackedVector2Array] = _pipe(path, front, back, width)
			if i == last:
				flesh.append_array(_cap(path, back, width, false))
			var gape: float = 0.0
			if i == 0:
				flesh.append_array(_cap(path, front, width, true))
				if s.shown:
					gape = _gape(p, pale, wizard)
					flesh = _bite_out(flesh, _jaw(s, width, gape))
			if flesh.is_empty():
				continue
			ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], flesh)
			if i == 0:
				ink.ink(RisoPrint.PINK, (STUNNED_FLESH if pale else 1.0) * k, flesh, false)
				if s.shown:
					ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], _teeth(s, width, gape))
					_draw_bite(p, width)
			else:
				var cover: float = (STUNNED_FLESH if pale else 1.0) * k
				ink.ink(RisoPrint.PINK, FLESH_PINK * cover, flesh, false)
				ink.ink(RisoPrint.BLUE, FLESH_GREEN * cover, flesh, false)
			# The joint behind it, in shadow under the segment ahead's overhang.
			if i != last:
				ink.ink(RisoPrint.NIGHT, JOINT_SHADE * k, _pipe(path, back - JOINT, back, width), false)
			if s.thorns != null:
				_draw_scales(path, p.side * s.flank, front, back, width, k, pale)
			if s.shown:
				_draw_hits(s, width, k)
			# Thorns print wherever the flesh beside them is out in the open, each on its own (not the
			# whole segment by its middle), so they go into and come out of a hole with the flesh.
			if s.thorns != null:
				_draw_thorns(path, s, front, back, width, i == last, pale)
		if pale and p.segments[0].shown and p.state != DYING:
			_draw_stun(p.segments[0], width)
	ink.finish()


## The body along `path` from `front` to `back` (in cells), `width` across, as strips of what is
## out in the open (the part down in a hole's rock is left out, cut off at the rock face).
func _pipe(path: Array[Vector2i], front: float, back: float, width: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for run: Vector2 in _runs(path, front, back):
		var n: int = maxi(2, ceili((run.y - run.x) * float(SAMPLES)))
		var left: PackedVector2Array = PackedVector2Array()
		var right: PackedVector2Array = PackedVector2Array()
		for m: int in range(n + 1):
			var s: float = lerpf(run.x, run.y, float(m) / float(n))
			var at: Vector2 = point(path, s)
			var side: Vector2 = facing(path, s).orthogonal() * width * 0.5
			left.append(at + side)
			right.append(at - side)
		var poly: PackedVector2Array = left
		for m: int in range(right.size() - 1, -1, -1):
			poly.append(right[m])
		out.append(poly)
	return out


## A rounded end of the body at `s` along `path`: the head's (facing on) or the tail's (facing
## back). Nothing while it is down in a hole; flattened as it nears a hole's rock face, so it never
## pokes through the rock.
func _cap(path: Array[Vector2i], s: float, width: float, head: bool) -> Array[PackedVector2Array]:
	if not open_at(path, s):
		return []
	var at: Vector2 = point(path, s)
	var way: Vector2 = facing(path, s) * (1.0 if head else -1.0)
	# Only as far out as the open air goes that way (CAP_STEP at a time).
	var depth: float = 0.0
	while depth < width * 0.5 and passable(map_info.world, map_info.cell_at(at + way * minf(depth + CAP_STEP, width * 0.5))):
		depth = minf(depth + CAP_STEP, width * 0.5)
	if depth < 1.0:
		return []
	var side: Vector2 = way.orthogonal()
	var half: PackedVector2Array = PackedVector2Array()
	for n: int in range(13):
		var a: float = -PI * 0.5 + PI * float(n) / 12.0
		half.append(at + side * sin(a) * width * 0.5 + way * cos(a) * depth)
	# On a bend the sides of the round head can meet rock too, not just its nose.
	if head:
		return _clip_to_air(half, at, width * 0.5)
	return [half]


## A rounded head's visible part, clipped to the open cells round its centre.
func _clip_to_air(poly: PackedVector2Array, at: Vector2, radius: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var lo: Vector2i = map_info.cell_at(at - Vector2.ONE * radius)
	var hi: Vector2i = map_info.cell_at(at + Vector2.ONE * radius)
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			var c: Vector2i = Vector2i(x, y)
			if not passable(map_info.world, c):
				continue
			var corner: Vector2 = center(c) - Vector2.ONE * cell * 0.5
			var square: PackedVector2Array = PackedVector2Array([corner, corner + Vector2(cell, 0), corner + Vector2.ONE * cell, corner + Vector2(0, cell)])
			out.append_array(Geometry2D.intersect_polygons(poly, square))
	return out


## How far piece `p`'s mouth gapes (0 shut, 1 wide). It chomps: near the wizard its jaws ease open
## and snap shut, quicker and wider the nearer they are (still and a little open while they are
## far). Striking, they work with the strike (_strike_gape). Biting, they spring wide and slam shut
## (BITE_SNAP), stay shut through the rest after, and ease back to a little open at its end.
## Stunned, it hangs nearly shut.
func _gape(p: Piece, pale: bool, wizard: Vector2) -> float:
	if pale:
		return MOUTH_REST
	if p.recovery > 0.0:
		var since: float = BITE_RECOVERY - p.recovery
		if since < BITE_SNAP:
			var u: float = since / BITE_SNAP
			return 1.0 - u * u
		return lerpf(MOUTH_REST, 0.0, clampf(p.recovery / BITE_EASE, 0.0, 1.0))
	if p.strike >= 0.0:
		return _strike_gape(p.strike)
	var head: WormSegment = p.segments[0]
	var near: float = 0.0
	if wizard != Vector2.INF:
		near = clampf(1.0 - head.global_position.distance_to(wizard) / BITE_NEAR, 0.0, 1.0)
	var f: float = fposmod(t * lerpf(CHOMP_SLOW, CHOMP_FAST, near) + float(head.get_instance_id() % 97) * 0.13, 1.0)
	var open: float = 0.0
	if f < CHOMP_OPEN:
		var u: float = f / CHOMP_OPEN
		open = 1.0 - (1.0 - u) * (1.0 - u)
	elif f < CHOMP_OPEN + CHOMP_SNAP:
		open = 1.0 - (f - CHOMP_OPEN) / CHOMP_SNAP
	return lerpf(MOUTH_CLOSED * (1.0 - near), lerpf(MOUTH_CLOSED, 1.0, near), open)


## How far a striking head's jaws gape `since` seconds into its strike: closing as it fixes on the
## wizard, opening wide as it draws back, wide through the lunge, snapping shut at its full reach,
## and easing a little open again as it settles back.
static func _strike_gape(since: float) -> float:
	var t0: float = since
	if t0 < STRIKE_PAUSE:
		return MOUTH_CLOSED * (1.0 - t0 / STRIKE_PAUSE)
	t0 -= STRIKE_PAUSE
	if t0 < STRIKE_PULL:
		var u: float = t0 / STRIKE_PULL
		return 1.0 - (1.0 - u) * (1.0 - u)
	t0 -= STRIKE_PULL + STRIKE_LUNGE
	if t0 < 0.0:
		return 1.0
	if t0 < STRIKE_HOLD:
		var u: float = minf(t0 / BITE_SNAP, 1.0)
		return 1.0 - u * u
	t0 -= STRIKE_HOLD
	return MOUTH_CLOSED * minf(t0 / STRIKE_RETURN, 1.0)


## A wedge cut out of the head's round front, opened `gape` (see _gape), showing what is behind it,
## without extending the head beyond its collider.
func _jaw(head: WormSegment, width: float, gape: float) -> PackedVector2Array:
	var r: float = width * 0.5
	var at: Vector2 = head.global_position
	var way: Vector2 = head.heading
	var side: Vector2 = way.orthogonal()
	return PackedVector2Array([at + way * r * MOUTH_ROOT, at + way * r * MOUTH_REACH + side * r * gape * MOUTH_SPREAD, at + way * r * MOUTH_REACH - side * r * gape * MOUTH_SPREAD])


## Paper fangs along both edges of the mouth (_jaw), opened `gape`, pointing into it: those of one
## jaw between those of the other, so shut they mesh in a zigzag along the seam. Only in the open.
func _teeth(head: WormSegment, width: float, gape: float) -> Array[PackedVector2Array]:
	var r: float = width * 0.5
	var at: Vector2 = head.global_position
	var way: Vector2 = head.heading
	var side: Vector2 = way.orthogonal()
	var root: Vector2 = at + way * r * MOUTH_ROOT
	var out: Array[PackedVector2Array] = []
	for jaw: float in [1.0, -1.0]:
		var dir: Vector2 = (way * r * (MOUTH_REACH - MOUTH_ROOT) + side * jaw * r * gape * MOUTH_SPREAD).normalized()
		# Toward the middle of the mouth, square to the jaw's edge.
		var into: Vector2 = dir.orthogonal()
		if into.dot(side * jaw) > 0.0:
			into = -into
		# How far along the edge it meets the round of the head.
		var o: Vector2 = root - at
		var b: float = o.dot(dir)
		var reach: float = -b + sqrt(maxf(0.0, b * b - o.length_squared() + r * r))
		var spots: Array[float] = TEETH_UPPER if jaw > 0.0 else TEETH_LOWER
		for frac: float in spots:
			var base: Vector2 = root + dir * reach * frac - into * 2.0
			var tooth: PackedVector2Array = PackedVector2Array([base - dir * r * TOOTH_HALF, base + into * r * TOOTH_LEN, base + dir * r * TOOTH_HALF])
			out.append_array(_clip_to_air(tooth, at, r))
	return out


## Pink strokes thrown out from the shut jaws as a head bites, fading over BITE_BURST.
func _draw_bite(p: Piece, width: float) -> void:
	var since: float = BITE_RECOVERY - p.recovery
	if p.recovery <= 0.0 or since >= BITE_BURST:
		return
	var u: float = since / BITE_BURST
	var head: WormSegment = p.segments[0]
	var r: float = width * 0.5
	var strokes: Array[PackedVector2Array] = []
	for i: int in range(5):
		var dir: Vector2 = head.heading.rotated((float(i) - 2.0) * 0.42)
		var from: Vector2 = head.global_position + dir * (r * 1.08 + 18.0 * u)
		var to: Vector2 = from + dir * (8.0 + 14.0 * (1.0 - u))
		var across: Vector2 = dir.orthogonal() * 2.5
		strokes.append(PackedVector2Array([from + across, to + across * 0.4, to - across * 0.4, from - across]))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], 1.0 - u, strokes)
	ink.ink(RisoPrint.PINK, 1.0 - u, strokes, false)


## Take the mouth out of the flesh. A cut that would leave a hole inside one strip is kept whole
## instead, so the print never mistakes a hole for another piece of flesh.
static func _bite_out(polys: Array[PackedVector2Array], cut: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in polys:
		var left: Array[PackedVector2Array] = Geometry2D.clip_polygons(poly, cut)
		var holed: bool = false
		for a: PackedVector2Array in left:
			for b: PackedVector2Array in left:
				if a != b and Geometry2D.is_point_in_polygon(a[0], b):
					holed = true
		if holed:
			out.append(poly)
		else:
			out.append_array(left)
	return out


## A segment's thorns: pink spikes standing out from the edge of its body on the side they face,
## longest where the edge faces them squarely (and round the tail's end, on the tail). They grow
## from fixed places along the body (thorn_spots), so they ride along with it as it crawls; round
## the outside of a bend they fan apart, and on the inside, where the body bunches up, they shrink
## away smoothly rather than cross. Turning away from the side they face, they shrink too. They
## show wherever the flesh they grow from is out in the open, each on its own, so they go into and
## come out of a hole with it; standing out over the rock of a wall it crawls along, they print over
## it, so its thorny side is always seen. Down in the rock, nothing shows.
func _draw_thorns(path: Array[Vector2i], s: WormSegment, front: float, back: float, width: float, tail: bool, pale: bool) -> void:
	var spikes: Array[PackedVector2Array] = []
	var edge: Array = thorn_spots(path, front, back, width)
	if tail and open_at(path, back):
		var end: Vector2 = point(path, back)
		var way: Vector2 = -facing(path, back)
		for n: int in range(1, 4):
			var out: Vector2 = way.rotated(-PI * 0.5 + PI * float(n) / 4.0)
			edge.append([end + out * width * 0.5, out, 1.0])
	for e: Array in edge:
		var normal: Vector2 = e[1]
		var w: float = normal.dot(s.spikes)
		var grown: float = float(e[2]) * smoothstep(0.0, THORN_SHOWN, w)
		if grown < 0.05:
			continue
		var base: Vector2 = e[0]
		var along: Vector2 = normal.orthogonal() * THORN_BASE * grown
		var tip: Vector2 = base + normal * WormSegment.THORN_LEN * (0.5 + 0.7 * w) * grown
		spikes.append(PackedVector2Array([base - normal * 3.0 + along, tip, base - normal * 3.0 - along]))
	# Cleared to paper first, so those over the rock print as bright as those in the open.
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], spikes)
	ink.ink(RisoPrint.PINK, 0.35 if pale else 1.0, spikes)


## Where thorns grow along both edges of the body from `front` to `back` on `path`, `width` across:
## [point on the edge, the way out from it, how fully grown (0..1)], THORNS_ALONG to a side at fixed
## shares of the way along, so they move with the body, where it is out in the open. One on the
## inside of a bend, where the edge
## runs shorter than the body's middle, is grown less the more it is squeezed, and not at all past
## THORN_BUNCHED (see _draw_thorns, which keeps those on the side the thorns face).
func thorn_spots(path: Array[Vector2i], front: float, back: float, width: float) -> Array:
	var edge: Array = []
	var ds: float = 0.04
	for n: int in range(THORNS_ALONG):
		var at_s: float = lerpf(front, back, (float(n) + 0.5) / float(THORNS_ALONG))
		if not open_at(path, at_s):
			continue
		var at: Vector2 = point(path, at_s)
		var side: Vector2 = facing(path, at_s).orthogonal()
		var middle: float = maxf(point(path, at_s - ds).distance_to(point(path, at_s + ds)), 0.0001)
		for flank: float in [1.0, -1.0]:
			var a: Vector2 = point(path, at_s - ds) + facing(path, at_s - ds).orthogonal() * flank * width * 0.5
			var b: Vector2 = point(path, at_s + ds) + facing(path, at_s + ds).orthogonal() * flank * width * 0.5
			# How much longer the edge runs here than the body's middle: well under 1 on the inside
			# of a bend.
			var stretch: float = a.distance_to(b) / middle
			var grown: float = smoothstep(THORN_BUNCHED, 1.0, stretch)
			if grown > 0.0:
				edge.append([at + side * flank * width * 0.5, side * flank, grown])
	return edge


## A segment's scales: on the half of its body toward its thorns (flank `toward`: 1 the left of the
## way it heads, -1 the right), rows of small plates in the thorns' own pink (danger), so the side
## that cannot be cut reads as a rough hide and the bare side as soft flesh (scale_plates).
func _draw_scales(path: Array[Vector2i], toward: float, front: float, back: float, width: float, k: float, pale: bool) -> void:
	var plates: Array[PackedVector2Array] = scale_plates(path, toward, front, back, width)
	var cover: float = (STUNNED_FLESH if pale else 1.0) * k
	ink.ink(RisoPrint.PINK, SCALE_PINK * cover, plates, false)
	ink.ink(RisoPrint.NIGHT, SCALE_SHADE * cover, plates, false)


## The scales on the body from `front` to `back` along `path`, `width` across, on flank `toward`:
## each a half disc lying back toward the tail, in rows staggered one to the next. Fixed to the body
## like the thorns, shrinking on the squeezed inside of a bend, and only where the flesh is out in
## the open.
func scale_plates(path: Array[Vector2i], toward: float, front: float, back: float, width: float) -> Array[PackedVector2Array]:
	var plates: Array[PackedVector2Array] = []
	var ds: float = 0.04
	for row: int in range(SCALE_ROWS.size()):
		var off: float = SCALE_ROWS[row] * width * 0.5
		for n: int in range(SCALES_ALONG):
			var at_s: float = lerpf(front, back, (float(n) + 0.25 + 0.5 * float(row % 2)) / float(SCALES_ALONG))
			if not open_at(path, at_s):
				continue
			var way: Vector2 = facing(path, at_s)
			var side: Vector2 = way.orthogonal() * toward
			# Squeezed on the inside of a bend: smaller, and none past THORN_BUNCHED.
			var a: Vector2 = point(path, at_s - ds) + facing(path, at_s - ds).orthogonal() * toward * off
			var b: Vector2 = point(path, at_s + ds) + facing(path, at_s + ds).orthogonal() * toward * off
			var middle: float = maxf(point(path, at_s - ds).distance_to(point(path, at_s + ds)), 0.0001)
			var grown: float = smoothstep(THORN_BUNCHED, 1.0, a.distance_to(b) / middle)
			if grown < 0.05:
				continue
			var radius: float = SCALE_R * grown
			var centre: Vector2 = point(path, at_s) + side * off
			var plate: PackedVector2Array = PackedVector2Array()
			for m: int in range(9):
				plate.append(centre + (-way).rotated(-PI * 0.5 + PI * float(m) / 8.0) * radius)
			plates.append(plate)
	return plates


## A segment's hits left, as dark dots in a row across its middle.
func _draw_hits(s: WormSegment, width: float, k: float) -> void:
	var dots: Array[PackedVector2Array] = []
	var n: int = maxi(s.wound.hp, 0)
	var side: Vector2 = s.heading.orthogonal()
	for j: int in range(n):
		var off: float = (float(j) - float(n - 1) * 0.5) * width * 0.22
		dots.append(RisoShapes.circle(s.global_position - s.heading * width * 0.08 + side * off, width * 0.075, 8))
	ink.ink(RisoPrint.NIGHT, 0.85 * k, dots, false)


## A burrow hole, as wide as the worm: the ground itself pushed up round a dark pit across the rock
## face, two shoulders of the rock's own ink rising to a rim either side (turfed like the floor's
## cap strip where the hole is dug in a floor, so the ground runs on over them), with crumbs of the
## freshly dug earth (the worm's pale flesh tones) on their inner slopes among clods of the ground's
## own; all of it only over open air, so in a narrow shaft it heaps against the walls. The worm's
## body ends at the face, inside the pit.
func _draw_hole(hole: Hole) -> void:
	var at: Transform2D = Transform2D(hole.out.angle() + PI * 0.5, hole.mouth)
	var r: float = cell * GIRTH * 0.5
	# Only over open air: in a narrow shaft or tunnel the earth heaps up against its walls rather
	# than spilling over them.
	var shoulders: Array[PackedVector2Array] = _clip_to_air(at * _mound(r), hole.mouth, r * HOLE_REACH + HOLE_RIM)
	# Printed as the terrain prints rock (and, on a floor, its cap strip over it).
	ink.knock([RisoPrint.PINK, RisoPrint.ACCENT], shoulders)
	ink.ink(RisoPrint.BLUE, 1.0, shoulders)
	if hole.out.dot(Vector2.UP) > 0.5:
		ink.ink(RisoPrint.ACCENT, 1.0, shoulders)
	ink.ink(RisoPrint.NIGHT, 1.0, [at * RisoShapes.almond(Vector2(0, 0), r * 0.97, HOLE_PIT, 24)], false)
	var dug: Array[PackedVector2Array] = []
	var clods: Array[PackedVector2Array] = []
	for k: int in range(HOLE_CRUMBS.size()):
		var c: Vector3 = HOLE_CRUMBS[k]
		var spot: Vector2 = at * Vector2(c.x * r, -c.y)
		if not passable(map_info.world, map_info.cell_at(spot)):
			continue
		var crumb: PackedVector2Array = RisoShapes.circle(spot, c.z, 8)
		# Every third one a clod of the ground's own; the rest freshly dug earth.
		if k % 3 == 2:
			clods.append(crumb)
		else:
			dug.append(crumb)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], dug)
	ink.ink(RisoPrint.PINK, FLESH_PINK * HOLE_EARTH, dug, false)
	ink.ink(RisoPrint.BLUE, FLESH_GREEN * HOLE_EARTH + 0.25, dug, false)
	ink.knock([RisoPrint.PINK, RisoPrint.ACCENT], clods)
	ink.ink(RisoPrint.BLUE, 1.0, clods)
	ink.ink(RisoPrint.NIGHT, 0.3, clods, false)


## The ground pushed up round a hole, in the hole's frame (across x, out along -y, the mouth at the
## origin) for a worm of radius `r`: low at the middle, where the pit is, rising to a rim either
## side at the worm's flanks, and easing back down to the face HOLE_REACH radii out.
static func _mound(r: float) -> PackedVector2Array:
	var reach: float = r * HOLE_REACH
	var out: PackedVector2Array = PackedVector2Array([Vector2(reach, 1.0), Vector2(-reach, 1.0)])
	for n: int in range(33):
		var x: float = lerpf(-reach, reach, float(n) / 32.0)
		var a: float = absf(x)
		var h: float = HOLE_RIM * pow(a / r, 3.0) if a < r else HOLE_RIM * (0.5 + 0.5 * cos(PI * (a - r) / (reach - r)))
		out.append(Vector2(x, -h))
	return out


## A worm about to come out at its face: the ground bulges there in pink (danger), throbbing
## faster and swelling as it nears, round a dark slit, and clods of dirt jump from it.
func _draw_warning(p: Piece) -> void:
	var face: Array[Vector2] = _face(p)
	var at: Transform2D = Transform2D(face[1].angle() + PI * 0.5, face[0])
	var r: float = cell * GIRTH * 0.5
	var near: float = 1.0 - p.warn / EMERGE_WARN
	var throb: float = 0.5 + 0.5 * sin(t * lerpf(10.0, 30.0, near))
	var swell: float = 10.0 + 24.0 * near + 4.0 * throb
	var bulge: PackedVector2Array = at * RisoShapes.almond(Vector2(0, -swell * 0.35), r * (1.05 + 0.1 * throb), swell, 28)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [bulge])
	ink.ink(RisoPrint.PINK, 0.6 + 0.4 * throb, [bulge], false)
	ink.ink(RisoPrint.NIGHT, 1.0, [at * RisoShapes.almond(Vector2(0, -swell * 0.3), r * 0.55, 3.0 + 4.0 * near, 16)], false)
	var dirt: Array[PackedVector2Array] = []
	for i: int in range(9):
		var x: float = (float(i) / 8.0 - 0.5) * 2.4 * r
		var hop: float = absf(sin(t * (12.0 + float(i) * 1.7) + float(i) * 2.1)) * (14.0 + 40.0 * near)
		dirt.append(RisoShapes.circle(at * Vector2(x, -swell * 0.5 - hop), 4.5 + 2.5 * near, 8))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], dirt)
	ink.ink(RisoPrint.PINK, FLESH_PINK * HOLE_EARTH, dirt, false)
	ink.ink(RisoPrint.BLUE, FLESH_GREEN * HOLE_EARTH + 0.25, dirt, false)


## Stars circling over a stunned worm's head, fewer as the stun runs out.
func _draw_stun(head: WormSegment, width: float) -> void:
	var frac: float = head.stunner.fraction()
	var stars: Array[PackedVector2Array] = []
	for i: int in range(3):
		var a: float = t * 1.3 + TAU * float(i) / 3.0
		var at: Vector2 = head.global_position + Vector2(cos(a) * 30.0, -width * 0.5 - 16.0 + sin(a) * 8.0)
		stars.append(Transform2D(t * 0.9 + float(i), at) * RisoShapes.sparkle(Vector2.ZERO, 8.0 + 5.0 * frac))
	ink.ink(RisoPrint.ACCENT, 0.9, stars)
