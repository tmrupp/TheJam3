class_name Whale
extends Node2D
## The whale (Bosses.UP's last, docs/REGIONS_PLAN.md §6) in the level it is in now (WhaleHunt: one
## world on the sky's top row, moving as the wizard comes and goes), put there as the level is
## built (MapInfo._spawn_whale). A huge body LENGTH long that swims along the top of the level. In
## its level the camera goes no higher than CEILING cells over the level's top, and its middle swims
## ABOVE that, so only its underside is ever seen: its pale belly and pleated throat, a fin hanging
## down, its flukes as they beat. It swims from fully off one side of the level to fully off the
## other at CRUISE, rests out of sight for TURN seconds, and comes back. Cruising, it prints behind
## the islands, a shadow passing over.
##
## When the wizard stands high (in the top HIGH_ROWS rows) under open sky (no rock straight above
## them), a little ahead of its head (AHEAD_MIN to AHEAD_MAX cells), and it has rested SWOOP_REST
## seconds, it swoops: its head dips into view and its jaw seam glows pink for TELL seconds, a mark
## on the spot the wizard stood; then its head dives along a curve to that spot in DIVE seconds,
## mouth gaping, and snaps shut; then it climbs back in CLIMB seconds and swims on. Moving off the
## spot dodges it. A wizard within GULP_REACH of its open mouth is gobbled: while it is free, a blow
## and thrown along the way it swims; while it is trapped (WhaleHunt.trapped: the levels either side
## set to blow into its level), taken into its belly (Belly, MapInfo.enter_belly), where its heart
## is. It cannot be wounded or touched otherwise: bolts and dashes pass it by. Printed by itself,
## from below. Nothing here draws from any RNG.

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
## Its speed on a pass (px/s), the share of it it keeps while swooping, and its rest out of sight
## between passes (seconds).
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
## Its swoop: the warning, the dive to the mark and the climb back (seconds), and how far its head
## dips into view while it warns (px).
const TELL: float = 1.2
const DIVE: float = 0.9
const CLIMB: float = 1.6
const TELL_DIP: float = 320.0
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
## How far its body bends to its head (the share of its length from the nose that follows a dive).
const BEND_FROM: float = 0.3
## Where its jaw hinges (along it, 0 the tail stock, 1 the nose), its lips' line (a share of its
## half-height below its spine), and how far its lower jaw swings down, wide open (radians).
const HINGE: float = 0.84
const LIPS: float = 0.42
const MAW: float = 0.65

## What it is doing: swimming a pass, resting out of sight to turn, or the three parts of a swoop.
enum Phase { CRUISE, TURN, TELL, DIVE, CLIMB }

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
## The spot it dives at (where the wizard stood as it warned), and whether this swoop has gobbled.
var mark: Vector2 = Vector2.ZERO
var gulped: bool = false
## How far its head is bent from where it swims (px, in its own frame, facing right).
var bend: Vector2 = Vector2.ZERO
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


## Where its mouth's middle is.
func mouth() -> Vector2:
	return _world(_mouth_at(bend))


## Whether its mouth is open wide enough to gobble.
func open() -> bool:
	return gape > GULP_GAPE


## Whether it is warning of a swoop.
func telling() -> bool:
	return phase == Phase.TELL


## Whether it is in a swoop: warning, diving or climbing.
func swooping() -> bool:
	return phase == Phase.TELL or phase == Phase.DIVE or phase == Phase.CLIMB


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
	var haste: float = Difficulty.haste()
	var speed: float = CRUISE * (SWOOP_DRIFT if swooping() else 1.0)
	match phase:
		Phase.TURN:
			u += delta
			if u >= TURN:
				facing = -facing
				phase = Phase.CRUISE
				u = 0.0
		Phase.CRUISE:
			global_position.x += facing * speed * delta
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
			global_position.x += facing * speed * delta
			u = minf(1.0, u + delta * haste / TELL)
			bend = Vector2(0.0, TELL_DIP * _ease(u))
			gape = 0.2 * u
			if u >= 1.0:
				phase = Phase.DIVE
				u = 0.0
		Phase.DIVE:
			global_position.x += facing * speed * delta
			u = minf(1.0, u + delta / DIVE)
			var reach: Vector2 = _local(mark) - _mouth_at(Vector2.ZERO)
			bend = Vector2(0.0, TELL_DIP).lerp(reach, _ease(u))
			gape = minf(1.0, u * 2.0)
			_gulp()
			if u >= 1.0:
				phase = Phase.CLIMB
				u = 0.0
		Phase.CLIMB:
			global_position.x += facing * speed * delta
			u = minf(1.0, u + delta / CLIMB)
			var from: Vector2 = _local(mark) - _mouth_at(Vector2.ZERO)
			bend = from * (1.0 - _ease(u))
			gape = move_toward(gape, 0.0, delta * 8.0)
			if u >= 1.0:
				phase = Phase.CRUISE
				u = 0.0
				since = 0.0
				bend = Vector2.ZERO
				z_index = Z_CRUISE
	global_position.y = swim_y + sin(t * 0.4) * 16.0


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


## Its open mouth closing on the wizard: gobbled, once a swoop.
func _gulp() -> void:
	if gulped or not open() or u < 0.6 or map_info.travelling:
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


## How much of a bend a point `s` along it (0 the tail stock, 1 the nose) takes.
static func _bent(s: float) -> float:
	return smoothstep(BEND_FROM, 1.0, s)


## Its spine at `s` (0 the tail stock, 1 the nose), bent by `by`, in its own frame.
static func _spine(s: float, by: Vector2) -> Vector2:
	return Vector2(lerpf(-LENGTH * 0.5, LENGTH * 0.5, s), 0.0) + by * _bent(s)


## Its spine's downward side at `s` (unit length).
static func _down(s: float, by: Vector2) -> Vector2:
	var along: Vector2 = (_spine(minf(1.0, s + 0.01), by) - _spine(maxf(0.0, s - 0.01), by)).normalized()
	return Vector2(-along.y, along.x)


## Its half-height at `s`: thin at the tail stock, greatest behind the middle, blunt at the head.
static func _girth(s: float) -> float:
	if s < 0.62:
		return GIRTH * (0.1 + 0.9 * pow(sin(s / 0.62 * PI * 0.5), 1.2))
	var k: float = (s - 0.62) / 0.38
	return GIRTH * (1.0 - 0.45 * k * k)


## A point on it at `s`, `side` of its half-height below its spine (negative, above).
static func _on(s: float, side: float, by: Vector2) -> Vector2:
	return _spine(s, by) + _down(s, by) * _girth(s) * side


## Its mouth's middle in its own frame, bent by `by`: inside its open jaws, a little back from its
## nose and below the line of its lips.
static func _mouth_at(by: Vector2) -> Vector2:
	var down: Vector2 = _down(1.0, by)
	return _spine(1.0, by) + down * GIRTH * 0.45 - Vector2(down.y, -down.x) * LENGTH * 0.06


## A strip along it from `s0` to `s1`, `side` of its half-height below its spine, `thick` px high.
static func _strip(s0: float, s1: float, side: float, thick: float, by: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = 16
	for i: int in range(n + 1):
		var s: float = lerpf(s0, s1, float(i) / float(n))
		out.append(_on(s, side, by) - _down(s, by) * thick * 0.5)
	for i: int in range(n, -1, -1):
		var s: float = lerpf(s0, s1, float(i) / float(n))
		out.append(_on(s, side, by) + _down(s, by) * thick * 0.5)
	return out


func _process(_delta: float) -> void:
	if ink == null:
		return
	ink.global_transform = Transform2D(0.0, global_position) * Transform2D(0.0, Vector2(facing, 1.0), 0.0, Vector2.ZERO)
	ink.begin()
	# Drawn with the bend kept clear of folding back on itself.
	var by: Vector2 = Vector2(clampf(bend.x, -LENGTH * 0.3, LENGTH * 0.6), bend.y)
	var n: int = 56
	# Its body: its underside from tail to nose, then its back from nose to tail.
	var body: PackedVector2Array = PackedVector2Array()
	for i: int in range(n + 1):
		body.append(_on(float(i) / float(n), 1.0, by))
	for i: int in range(n, -1, -1):
		body.append(_on(float(i) / float(n), -1.0, by))
	# Its flukes, beating, their lower lobe swinging down into view.
	var beat: float = sin(t * 0.9) * 0.3 + 0.1
	var fluke_xf: Transform2D = Transform2D(beat, _spine(0.0, by))
	var flukes: PackedVector2Array = fluke_xf * RisoShapes.smooth(PackedVector2Array([Vector2(40, -50), Vector2(-260, -330), Vector2(-560, -560), Vector2(-430, -250), Vector2(-330, 0), Vector2(-430, 250), Vector2(-560, 560), Vector2(-260, 330), Vector2(40, 50)]), 3)
	# Its long fin, hanging from under its middle and sculling slowly, swept back.
	var fin_xf: Transform2D = Transform2D(0.25 + sin(t * 0.6) * 0.1, _on(0.66, 0.8, by))
	var fin: PackedVector2Array = fin_xf * RisoShapes.smooth(PackedVector2Array([Vector2(90, -20), Vector2(20, 120), Vector2(-120, 260), Vector2(-300, 360), Vector2(-360, 370), Vector2(-260, 260), Vector2(-170, 110), Vector2(-120, -20)]), 3)
	var dark: Array[PackedVector2Array] = [body, flukes, fin]
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], dark)
	ink.ink(RisoPrint.NIGHT, 0.75, dark, false)
	ink.ink(RisoPrint.BLUE, 0.45, dark, false)
	# Its belly, paler, from the tail stock to the chin, deepest under the throat; the flukes' and
	# the fin's undersides paler too.
	var belly: PackedVector2Array = PackedVector2Array()
	for i: int in range(n + 1):
		belly.append(_on(lerpf(0.06, 0.995, float(i) / float(n)), 1.0, by))
	for i: int in range(n, -1, -1):
		var s: float = lerpf(0.06, 0.995, float(i) / float(n))
		belly.append(_on(s, 1.0 - _pale(s), by))
	var pale: Array[PackedVector2Array] = [belly, fin_xf * PackedVector2Array([Vector2(60, 0), Vector2(-60, 170), Vector2(-280, 340), Vector2(-150, 150), Vector2(-100, 0)])]
	ink.lift_ink([RisoPrint.NIGHT], 0.4, pale)
	ink.ink(RisoPrint.BLUE, 0.3, pale, false)
	# The pleats of its throat, from the chin back toward the navel.
	var pleats: Array[PackedVector2Array] = []
	for k: int in range(8):
		pleats.append(_strip(0.5 + float(k) * 0.025, 0.985, 0.94 - float(k) * 0.07, 5.0, by))
	ink.ink(RisoPrint.NIGHT, 0.4, pleats, false)
	# Barnacles on its chin and the fin's leading edge, in bare paper.
	var barnacles: Array[PackedVector2Array] = []
	for k: int in range(6):
		barnacles.append(RisoShapes.circle(_on(0.9 + float(k) * 0.016, 0.86 - float(k % 2) * 0.12, by), 11.0 + float(k % 3) * 4.0, 10))
	for k: int in range(4):
		barnacles.append(RisoShapes.circle(fin_xf * Vector2(40.0 - float(k) * 55.0, 60.0 + float(k) * 60.0), 9.0 + float(k % 2) * 5.0, 10))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], barnacles)
	_draw_mouth(by)
	# Its eye, in sun, seen only as its head comes down.
	var eye: Vector2 = _on(0.88, -0.05, by)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.circle(eye, 30.0, 18)])
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(eye, 19.0, 16)])
	# The spot it will dive at: a pink disc tightening as the dive nears.
	if phase == Phase.TELL or (phase == Phase.DIVE and u < 0.8):
		var warn: float = u if phase == Phase.TELL else 1.0
		var at: Vector2 = _local(mark)
		ink.ink(RisoPrint.PINK, 0.3 + 0.2 * warn, [RisoShapes.circle(at, lerpf(150.0, 60.0, warn), 32)])
		ink.ink(RisoPrint.PINK, 0.7 + 0.3 * warn, [RisoShapes.circle(at, 10.0 + 6.0 * warn, 14)])
	ink.finish()


## How deep its pale belly reaches up its side at `s` (a share of its half-height).
static func _pale(s: float) -> float:
	var throat: float = smoothstep(0.35, 0.6, s) * (1.0 - smoothstep(0.93, 1.0, s))
	return lerpf(0.3, 0.62, throat) * minf(1.0, s / 0.12)


## Its mouth: a seam along its lips, glowing pink as it warns; open, its lower jaw swings down from
## its hinge, pale and pleated, on a pink mouth with a dark gullet and a tongue, its baleen hanging
## in bare paper from its upper jaw.
func _draw_mouth(by: Vector2) -> void:
	if gape <= 0.25:
		var seam: PackedVector2Array = _strip(HINGE, 1.0, LIPS, 8.0 + gape * 40.0, by)
		ink.lift_ink([RisoPrint.NIGHT], 0.6, [seam])
		if phase == Phase.TELL:
			ink.ink(RisoPrint.PINK, 0.4 + 0.5 * u, [seam])
		return
	var open_by: float = (gape - 0.25) / 0.75
	var hinge: Vector2 = _on(HINGE, LIPS, by)
	var tip: Vector2 = _on(1.0, LIPS, by)
	var swing: float = MAW * open_by
	var reach: Vector2 = tip - hinge
	var jaw: Vector2 = reach.rotated(swing)
	# The upper lip, along its head, then the front of its open mouth, round to the lower jaw.
	var lips: PackedVector2Array = PackedVector2Array()
	for i: int in range(13):
		lips.append(_on(lerpf(HINGE, 1.0, float(i) / 12.0), LIPS, by))
	var maw: PackedVector2Array = lips.duplicate()
	for i: int in range(1, 9):
		maw.append(hinge + reach.rotated(swing * float(i) / 8.0) * (1.0 + 0.04 * sin(float(i) / 8.0 * PI)))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [maw])
	ink.ink(RisoPrint.PINK, 0.85, [maw])
	# Its gullet, dark at the back of its mouth, and its tongue along the lower jaw.
	var mid: Vector2 = reach.rotated(swing * 0.5).normalized()
	ink.ink(RisoPrint.NIGHT, 0.7, [RisoShapes.ellipse(hinge + mid * 120.0, 110.0, 50.0 + 70.0 * open_by, 20, mid.angle())])
	var low: Vector2 = jaw.normalized()
	ink.ink(RisoPrint.PINK, 0.5, [RisoShapes.ellipse(hinge + low * jaw.length() * 0.45 - low.rotated(PI * 0.5) * 50.0, jaw.length() * 0.3, 45.0, 20, low.angle())])
	# Its lower jaw: a pale pleated band under the open mouth, thick at the hinge, round at the chin.
	var out: Vector2 = low.rotated(PI * 0.5)
	var lower: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([hinge - low * 60.0, hinge + jaw * 0.5 - out * 6.0, hinge + jaw, hinge + jaw + out * GIRTH * 0.16 - low * 20.0, hinge + jaw * 0.5 + out * GIRTH * 0.3, hinge + out * GIRTH * 0.36]), 3)
	ink.knock([RisoPrint.PINK], [lower])
	ink.ink(RisoPrint.NIGHT, 0.75, [lower], false)
	ink.lift_ink([RisoPrint.NIGHT], 0.4, [lower])
	ink.ink(RisoPrint.BLUE, 0.3, [lower], false)
	var grooves: Array[PackedVector2Array] = []
	for k: int in range(4):
		var off: float = GIRTH * (0.08 + 0.06 * float(k))
		var a: Vector2 = hinge + out * off + low * 40.0
		var b: Vector2 = hinge + jaw * (0.92 - 0.1 * float(k)) + out * off * 0.5
		grooves.append(PackedVector2Array([a - out * 2.5, b - out * 2.5, b + out * 2.5, a + out * 2.5]))
	ink.ink(RisoPrint.NIGHT, 0.4, grooves, false)
	# Its baleen: a fringe of plates hanging from the upper lip.
	var plates: Array[PackedVector2Array] = []
	var fore: Vector2 = reach.normalized()
	var down: Vector2 = fore.rotated(PI * 0.5)
	for k: int in range(2, lips.size() - 1):
		var root: Vector2 = lips[k]
		var long: float = (60.0 + 30.0 * sin(float(k) * 1.7)) * open_by
		plates.append(PackedVector2Array([root - fore * 10.0, root + fore * 10.0, root + down * long + fore * 5.0, root + down * long - fore * 5.0]))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], plates)


## A smooth curve from `a` to `b` bending toward `c`, as points (12 of them).
static func _curve(a: Vector2, c: Vector2, b: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(12):
		var k: float = float(i) / 11.0
		out.append(a * (1.0 - k) * (1.0 - k) + c * 2.0 * k * (1.0 - k) + b * k * k)
	return out
