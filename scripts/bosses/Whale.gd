class_name Whale
extends Node2D
## The whale (Bosses.UP's last, docs/REGIONS_PLAN.md §6) in the level it is in now (WhaleHunt: one
## world on the sky's top row, moving as the wizard comes and goes), put there as the level is
## built (MapInfo._spawn_whale). A huge body LENGTH long that swims along the top of the level. In
## its level the camera goes no higher than CEILING cells over the level's top, and its middle swims
## ABOVE that, so only its underside is ever seen: its pale belly and pleated throat, a pale fin
## hanging down, its flukes as they beat. It swims from fully off one side of the level to fully off
## the other at CRUISE, rests out of sight for TURN seconds, and comes back. Cruising, it prints
## behind the islands, a shadow passing over.
##
## When the wizard stands high (in the top HIGH_ROWS rows) under open sky (no rock straight above
## them), a little ahead of its nose (AHEAD_MIN to AHEAD_MAX cells), and it has rested SWOOP_REST
## seconds, it swoops: for TELL seconds its head dips into view and tips down, its lips parting on
## its pink baleen, a mark on the spot the wizard stood; then it lunges along one curve, down under
## that spot in DIVE seconds, its jaws opening wide, and up through it in as long again, scooping it
## up and snapping shut as it rises; then it settles back to its line in CLIMB seconds and swims on.
## Moving off the spot dodges it. A wizard within GULP_REACH of its open mouth is gobbled: while it
## is free, a blow and thrown along the way it swims; while it is trapped (WhaleHunt.trapped: the
## levels either side set to blow into its level), taken into its belly (Belly,
## MapInfo.enter_belly), where its heart is. It cannot be wounded or touched otherwise: bolts and
## dashes pass it by. Printed by itself, from below. Nothing here draws from any RNG.

## Its length, nose to tail stock, and its body's greatest half-height (px).
const LENGTH: float = 4800.0
const GIRTH: float = 640.0
## How much sky (cells) the camera shows over the level's top while it is there, and how far its
## middle swims above the highest the camera goes (px): only its lower part hangs into view.
const CEILING: int = 1
const ABOVE: float = 64.0
## How far past the level's edge (px, beyond its body) it swims before it turns: its flukes out of
## sight too.
const FLUKE_SPAN: float = 360.0
## Its speed on a pass (px/s), the share of it it keeps while it warns and settles, and its rest out
## of sight between passes (seconds).
const CRUISE: float = 360.0
const SWOOP_DRIFT: float = 0.25
const TURN: float = 4.0
## How near the top (rows from the level's top) the wizard must stand to draw it down, and how far
## ahead of its nose, across (cells).
const HIGH_ROWS: int = 7
const AHEAD_MIN: int = 2
const AHEAD_MAX: int = 7
## Its rest between swoops (seconds), free and trapped.
const SWOOP_REST: float = 6.0
const TRAPPED_REST: float = 3.0
## Its swoop: the warning, each half of its lunge (down ahead of the spot, then up through it), and
## the settling back to its line (seconds); and how far its head dips into view and tips down while
## it warns (px, radians).
const TELL: float = 1.2
const DIVE: float = 0.9
const CLIMB: float = 1.2
const TELL_DIP: float = 320.0
const TELL_TIP: float = 0.25
## The most its head turns from level, down or up, as it lunges (radians), and how far along its
## lunge (0 to 1) its open mouth reaches the spot: past the lowest point, scooping up.
const TILT: float = 0.6
const SCOOP: float = 0.7
## How near its mouth's middle (px) a wizard is gobbled, and how open (0 shut, 1 wide) its mouth
## must be.
const GULP_REACH: float = 300.0
const GULP_GAPE: float = 0.6
## Gobbled while free: the blow, and how hard it throws the wizard along its way (px/s) and up.
const SPIT_HURT: int = 1
const SPIT_SPEED: float = 700.0
const SPIT_LIFT: float = -250.0
## Where it prints: behind the islands as it cruises, among the props as it swoops.
const Z_CRUISE: int = -30
const Z_SWOOP: int = 2
## Where its body starts to bend toward its head (along it, 0 the tail stock, 1 the nose).
const BEND_FROM: float = 0.3
## Its head: where its rounded snout begins and where its jaws hinge (along it), its lips' line (a
## share of its half-height below its spine), how far its jaws part wide open (radians), and the
## share of that its upper jaw lifts (its lower jaw swings down the rest).
const SNOUT: float = 0.9
const HINGE: float = 0.8
const LIPS: float = 0.3
const MAW: float = 0.75
const LIFT: float = 0.3
## Its mouth's middle, inside its open jaws, from its nose in its head's frame (px).
const MOUTH: Vector2 = Vector2(-430.0, 80.0)

## What it is doing: swimming a pass, resting out of sight to turn, or the parts of a swoop
## (warning, diving, scooping up, settling).
enum Phase { CRUISE, TURN, TELL, DIVE, RISE, CLIMB }

var map_info: MapInfo
## Whether it is trapped in this level, which way it faces (+1 right), its clock, and how far its
## mouth is open (0 shut, 1 wide).
var trapped: bool = false
var facing: float = 1.0
var t: float = 0.0
var gape: float = 0.0
## What it is doing, how far through it (0..1, or seconds while turning), and seconds since its last
## swoop (faster on a harder preset).
var phase: Phase = Phase.CRUISE
var u: float = 0.0
var since: float = 0.0
## The spot it dives at (where the wizard stood as it warned), its lunge there and back (its nose's
## path in the world: start, bend, end), and whether this swoop has gobbled.
var mark: Vector2 = Vector2.ZERO
var path: Array[Vector2] = []
var gulped: bool = false
## Its head, in its own frame (facing right): how far its nose is bent from where it swims (px), and
## the way it heads (a unit vector). Its pose as it starts to settle back.
var bend: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT
var _settle_bend: Vector2 = Vector2.ZERO
var _settle_aim: Vector2 = Vector2.RIGHT
## Where a pass starts and ends (its middle, world x), the line it swims along (world y), the level's
## top, the high line under it and the highest the camera goes (world y), and a cell's size.
var left_x: float = 0.0
var right_x: float = 0.0
var swim_y: float = 0.0
var top_y: float = 0.0
var high_y: float = 0.0
var ceiling_y: float = 0.0
var cell: Vector2 = Vector2(128, 128)
var ink: InkCanvas
## Where its jaws hinge in its own frame, as last drawn.
var _hinge: Vector2 = Vector2.ZERO


func setup(info: MapInfo) -> void:
	map_info = info
	trapped = WhaleHunt.trapped(info.run, info.coord.x)
	var w: LevelGen = info.world
	cell = info.cell_position(Vector2i(1, 1)) - info.cell_position(Vector2i.ZERO)
	var margin: int = LevelLoader.SKY_MARGIN
	var view_left: float = info.cell_position(Vector2i(-margin, 0)).x - cell.x * 0.5
	var view_right: float = info.cell_position(Vector2i(w.size.x - 1 + margin, 0)).x + cell.x * 0.5
	left_x = view_left - LENGTH * 0.5 - FLUKE_SPAN
	right_x = view_right + LENGTH * 0.5 + FLUKE_SPAN
	top_y = info.cell_position(Vector2i(0, 0)).y - cell.y * 0.5
	high_y = top_y + cell.y * float(HIGH_ROWS)
	ceiling_y = top_y - cell.y * float(CEILING)
	swim_y = ceiling_y - ABOVE
	global_position = Vector2((view_left + view_right) * 0.5, swim_y)


func _ready() -> void:
	z_index = Z_CRUISE
	ink = InkCanvas.new()
	add_child(ink)


## A point in its own frame (facing right, its middle at the origin) in the world.
func _world(local: Vector2) -> Vector2:
	return global_position + local * Vector2(facing, 1.0)


## A point in the world in its own frame.
func _local(at: Vector2) -> Vector2:
	return (at - global_position) * Vector2(facing, 1.0)


## A way in its own frame in the world, or back (the same flip either way).
func _flip(way: Vector2) -> Vector2:
	return way * Vector2(facing, 1.0)


## Where its mouth's middle is.
func mouth() -> Vector2:
	return _world(_spine(1.0) + MOUTH.rotated(aim.angle()))


## Whether its mouth is open wide enough to gobble.
func open() -> bool:
	return gape > GULP_GAPE


## Whether it is warning of a swoop.
func telling() -> bool:
	return phase == Phase.TELL


## Whether it is in a swoop: warning, lunging or settling back.
func swooping() -> bool:
	return phase != Phase.CRUISE and phase != Phase.TURN


## Whether `at` is high enough to draw it down: in the level's top HIGH_ROWS rows.
func high(at: Vector2) -> bool:
	return at.y < high_y


## Whether rock stands anywhere straight above `at`, up to the level's top: shelter from it.
func sheltered(at: Vector2) -> bool:
	var y: float = at.y - cell.y * 0.75
	while y > top_y:
		if map_info.solid_at(Vector2(at.x, y)):
			return true
		y -= cell.y * 0.5
	return false


## Whether `at` is a little ahead of its nose, the way it swims (AHEAD_MIN to AHEAD_MAX cells).
func ahead(at: Vector2) -> bool:
	var d: float = (at.x - (global_position.x + facing * LENGTH * 0.5)) * facing
	return d >= cell.x * float(AHEAD_MIN) and d <= cell.x * float(AHEAD_MAX)


## Whether a wizard at `at` (standing or not) draws a swoop now, its rest aside.
func drawn_to(at: Vector2, standing: bool) -> bool:
	return phase == Phase.CRUISE and standing and high(at) and ahead(at) and not sheltered(at)


## Begin a swoop at `target`: the warning first.
func swoop_at(target: Vector2) -> void:
	mark = target
	phase = Phase.TELL
	u = 0.0
	gulped = false
	z_index = Z_SWOOP
	Wound.shake(6.0, TELL)


func _physics_process(delta: float) -> void:
	if map_info == null:
		return
	_hold_camera()
	t += delta
	global_position.y = swim_y + sin(t * 0.4) * 16.0
	var haste: float = Difficulty.haste()
	match phase:
		Phase.TURN:
			u += delta
			if u >= TURN:
				facing = -facing
				phase = Phase.CRUISE
				u = 0.0
		Phase.CRUISE:
			global_position.x += facing * CRUISE * delta
			since += delta * haste
			bend = bend.move_toward(Vector2.ZERO, delta * 400.0)
			gape = move_toward(gape, 0.0, delta * 3.0)
			if (facing > 0.0 and global_position.x >= right_x) or (facing < 0.0 and global_position.x <= left_x):
				global_position.x = clampf(global_position.x, left_x, right_x)
				phase = Phase.TURN
				u = 0.0
			else:
				_look()
		Phase.TELL:
			global_position.x += facing * CRUISE * SWOOP_DRIFT * delta
			u = minf(1.0, u + delta * haste / TELL)
			bend = Vector2(0.0, TELL_DIP * _ease(u))
			aim = Vector2.RIGHT.rotated(TELL_TIP * _ease(u))
			gape = 0.2 * u
			if u >= 1.0:
				_plan()
				phase = Phase.DIVE
				u = 0.0
		Phase.DIVE:
			u = minf(1.0, u + delta / DIVE)
			_follow(0.5 * u)
			# Parting as it goes down, opening wide only as it turns up.
			gape = lerpf(0.2, 0.7, u * u)
			if u >= 1.0:
				phase = Phase.RISE
				u = 0.0
		Phase.RISE:
			u = minf(1.0, u + delta / DIVE)
			_follow(0.5 + 0.5 * u)
			# Wide as it turns up, until it has scooped up the spot, then snapping shut.
			gape = minf(minf(1.0, 0.7 + u * 1.5), clampf(1.0 - (u - (SCOOP - 0.5) * 2.0 - 0.05) / 0.2, 0.0, 1.0))
			_gulp()
			if u >= 1.0:
				phase = Phase.CLIMB
				u = 0.0
				_settle_bend = bend
				_settle_aim = aim
		Phase.CLIMB:
			global_position.x += facing * CRUISE * SWOOP_DRIFT * delta
			u = minf(1.0, u + delta / CLIMB)
			bend = _settle_bend * (1.0 - _ease(u))
			aim = _settle_aim.slerp(Vector2.RIGHT, _ease(u))
			gape = 0.0
			if u >= 1.0:
				phase = Phase.CRUISE
				u = 0.0
				since = 0.0
				bend = Vector2.ZERO
				aim = Vector2.RIGHT
				z_index = Z_CRUISE


## Keep the camera under its ceiling (the level's own fitting, LevelLoader._fit_camera, comes after
## it is placed, and again on a refit).
func _hold_camera() -> void:
	var cam: Camera2D = map_info.camera()
	if cam != null and cam.limit_top < int(ceiling_y):
		cam.limit_top = int(ceiling_y)


## The wizard standing high under open sky, ahead of it, after a rest: swoop at them.
func _look() -> void:
	if since < (TRAPPED_REST if trapped else SWOOP_REST) or map_info.travelling:
		return
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player):
		return
	if drawn_to(player.global_position, player.is_on_floor()):
		swoop_at(player.global_position)


## Lay out its lunge, in the world: one curve for its nose, from where it is now, down under the
## marked spot and up the far side, back to its line, so that SCOOP along it, heading up, its open
## mouth takes in the spot.
func _plan() -> void:
	var from: Vector2 = _world(_spine(1.0))
	var to: Vector2 = from
	var bend_at: Vector2 = from
	var heading: Vector2 = Vector2.RIGHT.rotated(-TILT)
	var q: float = 1.0 - SCOOP
	for i: int in range(4):
		var nose: Vector2 = mark - _flip(MOUTH.rotated(heading.angle()))
		to = Vector2(from.x + (nose.x - from.x) / SCOOP, swim_y)
		bend_at = (nose - from * q * q - to * SCOOP * SCOOP) / (2.0 * SCOOP * q)
		heading = _tilted(_flip(2.0 * q * (bend_at - from) + 2.0 * SCOOP * (to - bend_at)))
	path = [from, bend_at, to]


## Its nose `p` along its lunge (0 to 1), its body drawn along after it: its middle keeps its place
## behind its nose, its head bent down to it and turned the way it moves.
func _follow(p: float) -> void:
	var a: Vector2 = path[0]
	var c: Vector2 = path[1]
	var b: Vector2 = path[2]
	var nose: Vector2 = a * (1.0 - p) * (1.0 - p) + c * 2.0 * p * (1.0 - p) + b * p * p
	var along: Vector2 = 2.0 * (1.0 - p) * (c - a) + 2.0 * p * (b - c)
	global_position.x = nose.x - facing * LENGTH * 0.5
	bend = Vector2(0.0, nose.y - global_position.y)
	aim = _tilted(_flip(along))


## The way `way` goes (in its own frame), turned no more than TILT from level.
static func _tilted(way: Vector2) -> Vector2:
	if way.length() < 0.001:
		return Vector2.RIGHT
	return Vector2.RIGHT.rotated(clampf(way.angle(), -TILT, TILT))


## Its open mouth scooping up the wizard as it rises: gobbled, once a swoop.
func _gulp() -> void:
	if gulped or not open() or phase != Phase.RISE or map_info.travelling:
		return
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.distance_to(mouth()) > GULP_REACH:
		return
	gulped = true
	if trapped:
		map_info.enter_belly()
	else:
		player.hurt(-SPIT_HURT, Vector2(facing * SPIT_SPEED, SPIT_LIFT), self)


## Smoothly from 0 to 1 as `x` goes from 0 to 1, slow at both ends.
static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Its spine at `s` (0 the tail stock, 1 the nose), in its own frame: straight up to BEND_FROM, then
## curving to its nose, bent by `bend` and heading along `aim`.
func _spine(s: float) -> Vector2:
	var x: float = lerpf(-LENGTH * 0.5, LENGTH * 0.5, s)
	if s <= BEND_FROM:
		return Vector2(x, 0.0)
	var front: float = LENGTH * (1.0 - BEND_FROM)
	var k: float = (s - BEND_FROM) / (1.0 - BEND_FROM)
	var k2: float = k * k
	var k3: float = k2 * k
	var root: Vector2 = Vector2(LENGTH * 0.5 - front, 0.0)
	var nose: Vector2 = Vector2(LENGTH * 0.5, 0.0) + bend
	return root * (2.0 * k3 - 3.0 * k2 + 1.0) + Vector2(front, 0.0) * (k3 - 2.0 * k2 + k) + nose * (3.0 * k2 - 2.0 * k3) + aim * front * (k3 - k2)


## Its spine's downward side at `s` (unit length).
func _down(s: float) -> Vector2:
	var along: Vector2 = (_spine(minf(1.0, s + 0.005)) - _spine(maxf(0.0, s - 0.005))).normalized()
	return Vector2(-along.y, along.x)


## Its half-height at `s`: thin at the tail stock, greatest behind the middle, narrowing to its
## head and rounding off at its snout.
static func _girth(s: float) -> float:
	if s < 0.62:
		return GIRTH * (0.1 + 0.9 * pow(sin(s / 0.62 * PI * 0.5), 1.2))
	var g: float = GIRTH * (1.0 - 0.6 * pow((s - 0.62) / 0.38, 1.5))
	if s > SNOUT:
		var k: float = (s - SNOUT) / (1.0 - SNOUT)
		g *= sqrt(maxf(0.0, 1.0 - k * k))
	return g


## A point on it at `s`, `side` of its half-height below its spine (negative, above), as if its
## mouth were shut.
func _on(s: float, side: float) -> Vector2:
	return _spine(s) + _down(s) * _girth(s) * side


## A point on it at `s`, `side` of its half-height below its spine, its jaws open as they are: the
## upper jaw (above its lips) lifted, the lower swung down, both about its hinge.
func _pt(s: float, side: float) -> Vector2:
	return _jawed(_on(s, side), s, side < LIPS)


## `at` (on it at `s`) turned with its upper jaw (`upper`) or its lower one, about its hinge: not at
## all behind the hinge, fully in front of it.
func _jawed(at: Vector2, s: float, upper: bool) -> Vector2:
	var w: float = smoothstep(HINGE - 0.02, HINGE + 0.05, s)
	if w <= 0.0 or gape <= 0.0:
		return at
	var turn: float = MAW * gape * w * (-LIFT if upper else 1.0 - LIFT)
	return _hinge + (at - _hinge).rotated(turn)


## The top of its pale underside at `s` (a side, as _on takes it): low along its belly, higher
## under its throat, up to its lips along its head.
static func _top(s: float) -> float:
	if s >= HINGE:
		return LIPS
	var pale: float = lerpf(0.3, 0.62, smoothstep(0.35, 0.6, s)) + (1.0 - LIPS - 0.62) * smoothstep(0.6, HINGE, s)
	return 1.0 - pale * minf(1.0, s / 0.12)


## Where along it the `i`th of `n` points round its outline falls: closer together toward its head.
static func _along(i: int, n: int) -> float:
	return 1.0 - pow(1.0 - float(i) / float(n), 1.5)


## A band `thick` px wide along the line through `points`.
static func _band(points: PackedVector2Array, thick: float) -> PackedVector2Array:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in range(points.size()):
		var a: Vector2 = points[maxi(0, i - 1)]
		var b: Vector2 = points[mini(points.size() - 1, i + 1)]
		var side: Vector2 = (b - a).normalized().orthogonal() * thick * 0.5
		left.append(points[i] + side)
		right.append(points[i] - side)
	right.reverse()
	left.append_array(right)
	return left


func _process(_delta: float) -> void:
	if ink == null:
		return
	ink.global_transform = Transform2D(0.0, global_position) * Transform2D(0.0, Vector2(facing, 1.0), 0.0, Vector2.ZERO)
	ink.begin()
	_hinge = _on(HINGE, LIPS)
	var n: int = 72
	# Its body: its underside from tail to snout (its lower jaw), then its back from snout to tail
	# (its upper jaw), across its open mouth if it is open.
	var body: PackedVector2Array = PackedVector2Array()
	for i: int in range(n + 1):
		body.append(_pt(_along(i, n), 1.0))
	for i: int in range(n, -1, -1):
		body.append(_pt(_along(i, n), -1.0))
	# Its flukes, beating, their lower lobe swinging down into view.
	var beat: float = sin(t * 0.9) * 0.3 + 0.1
	var fluke_xf: Transform2D = Transform2D(beat, _spine(0.0))
	var flukes: PackedVector2Array = fluke_xf * RisoShapes.smooth(PackedVector2Array([Vector2(40, -50), Vector2(-260, -330), Vector2(-560, -560), Vector2(-430, -250), Vector2(-330, 0), Vector2(-430, 250), Vector2(-560, 560), Vector2(-260, 330), Vector2(40, 50)]), 3)
	# Its long fin, rooted in its belly, sculling slowly, swept back.
	var fin_xf: Transform2D = Transform2D(0.25 + sin(t * 0.6) * 0.1, _on(0.66, 0.75))
	var fin: PackedVector2Array = fin_xf * RisoShapes.smooth(PackedVector2Array([Vector2(110, -60), Vector2(30, 120), Vector2(-120, 260), Vector2(-300, 360), Vector2(-360, 370), Vector2(-260, 260), Vector2(-170, 110), Vector2(-140, -60)]), 3)
	var dark: Array[PackedVector2Array] = [body, flukes, fin]
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], dark)
	ink.ink(RisoPrint.NIGHT, 0.75, dark, false)
	ink.ink(RisoPrint.BLUE, 0.45, dark, false)
	# Its pale underside, from the tail stock to its chin, up to its lips along its head; and its
	# fin, pale too.
	var belly: PackedVector2Array = PackedVector2Array()
	for i: int in range(n + 1):
		belly.append(_pt(lerpf(0.06, 1.0, _along(i, n)), 1.0))
	for i: int in range(n, -1, -1):
		var s: float = lerpf(0.06, 1.0, _along(i, n))
		belly.append(_jawed(_on(s, _top(s)), s, false))
	var pale: Array[PackedVector2Array] = [belly, fin]
	ink.lift_ink([RisoPrint.NIGHT], 0.4, pale)
	ink.ink(RisoPrint.BLUE, 0.3, pale, false)
	# The pleats of its throat, from under its chin back toward its navel.
	var pleats: Array[PackedVector2Array] = []
	for k: int in range(8):
		var line: PackedVector2Array = PackedVector2Array()
		var side: float = 0.94 - float(k) * 0.07
		for i: int in range(25):
			line.append(_pt(lerpf(0.5 + float(k) * 0.025, 0.985, float(i) / 24.0), side))
		pleats.append(_band(line, 5.0))
	ink.ink(RisoPrint.NIGHT, 0.4, pleats, false)
	# Barnacles on its chin and the fin's leading edge, in bare paper.
	var barnacles: Array[PackedVector2Array] = []
	for k: int in range(6):
		barnacles.append(RisoShapes.circle(_pt(0.9 + float(k) * 0.014, 0.85 - float(k % 2) * 0.15), 11.0 + float(k % 3) * 4.0, 10))
	for k: int in range(4):
		barnacles.append(RisoShapes.circle(fin_xf * Vector2(60.0 - float(k) * 55.0, 40.0 + float(k) * 60.0), 9.0 + float(k % 2) * 5.0, 10))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], barnacles)
	_draw_mouth()
	# Its eye, in sun, above the corner of its mouth: seen only as its head comes down.
	var eye: Vector2 = _pt(HINGE + 0.02, 0.02)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.circle(eye, 30.0, 18)])
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(eye, 19.0, 16)])
	# The spot it will dive at: a pink disc tightening as the lunge nears.
	if phase == Phase.TELL or (phase == Phase.DIVE and u < 0.8):
		var warn: float = u if phase == Phase.TELL else 1.0
		var at: Vector2 = _local(mark)
		ink.ink(RisoPrint.PINK, 0.3 + 0.2 * warn, [RisoShapes.circle(at, lerpf(150.0, 60.0, warn), 32)])
		ink.ink(RisoPrint.PINK, 0.7 + 0.3 * warn, [RisoShapes.circle(at, 10.0 + 6.0 * warn, 14)])
	ink.finish()


## Its open mouth, between its jaws: dark inside, a pink tongue along its lower jaw and a thick
## fringe of pink baleen hanging from its upper jaw. Shut, nothing: its lips are where its dark
## upper jaw meets its pale throat.
func _draw_mouth() -> void:
	if gape <= 0.02:
		return
	var m: int = 24
	var upper: PackedVector2Array = PackedVector2Array()
	var lower: PackedVector2Array = PackedVector2Array()
	for i: int in range(m + 1):
		var s: float = lerpf(HINGE, 1.0, float(i) / float(m))
		var lip: Vector2 = _on(s, LIPS)
		upper.append(_jawed(lip, s, true))
		lower.append(_jawed(lip, s, false))
	var inside: PackedVector2Array = upper.duplicate()
	for i: int in range(m, -1, -1):
		inside.append(lower[i])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], [inside])
	ink.ink(RisoPrint.NIGHT, 0.95, [inside], false)
	# Its tongue: a mound along its lower jaw, highest in the middle.
	var tongue: PackedVector2Array = lower.duplicate()
	for i: int in range(m, -1, -1):
		var k: float = float(i) / float(m)
		tongue.append(lower[i] + (upper[i] - lower[i]) * 0.3 * sin(k * PI))
	ink.knock([RisoPrint.NIGHT], [tongue])
	ink.ink(RisoPrint.PINK, 0.6, [tongue])
	# Its baleen: a gum along its upper lip, and from it thick plates hanging toward its lower jaw.
	var plates: Array[PackedVector2Array] = [_band(upper, 30.0)]
	for i: int in range(1, m, 2):
		var root: Vector2 = upper[i]
		var gap: Vector2 = lower[i] - root
		var long: float = minf(gap.length() * 0.5, 150.0)
		if long < 8.0:
			continue
		var hang: Vector2 = gap.normalized()
		var across: Vector2 = (upper[i + 1] - upper[i - 1]).normalized()
		plates.append(PackedVector2Array([root - across * 30.0, root + across * 30.0, root + hang * long + across * 20.0, root + hang * long - across * 20.0]))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], plates)
	ink.ink(RisoPrint.PINK, 0.95, plates)
