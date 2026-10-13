extends CreatureArt
class_name SkeletonArt
## A skeleton (Skeleton): a stick figure of bare bones lifted out of the dark to paper: a bare round
## skull with two sockets, a spine, two ribs, a pelvis, and limbs of two bones each, the arms hung
## straight from the ends of the top rib. Asleep it lies along the floor of its niche, its sockets
## empty; rising, it swings up onto its feet; awake, a pink point burns in each socket (printed over the
## darkness, so an awake skeleton shows in a dark crypt and a sleeping one does not).
##
## Its limbs are posed by two-bone inverse kinematics. Its feet take turns: each is planted on the
## floor and stays put while the body moves over it, until it is half a stride (STEP) behind the
## hip, when it steps in a quick arc to half a stride ahead of where the hip will be as it lands
## (aimed again each frame of the step, as the body goes on), so the feet straddle the hip rather
## than trail it; standing, they settle a little apart, one ahead of the other. The knees bend
## forward to fit. Off the ground (a hop, a fall) its feet hang under it.
##
## The rest of it moves with the steps: the body lifts as each leg swings and the torso rocks over
## the hip toward the swinging leg; the skull follows the body a moment late, bobbing and tilting,
## and lolls a little as it stands; the arms hang straight from its sides, a little out from the
## ribs, each swinging like a pendulum opposite its own side's foot and easing after it. The far leg and arm print a little
## fainter.

## Bones are given in art units (SCALE px each), from its feet on the floor, facing right.
const SCALE: float = 1.8
## The hip's height, and the thigh's and shin's lengths (a little longer together than the hip is
## high, so a planted leg is never quite straight).
const HIP: float = 19.0
const THIGH: float = 10.5
const SHIN: float = 10.5
## The shoulder's height, the upper arm's and forearm's lengths, where the neck meets the skull (a
## little over the top rib), and the skull's middle
## above it and how big it is.
const SHOULDER: float = 38.0
const UPPER: float = 8.5
const FORE: float = 8.5
const NECK: Vector2 = Vector2(0.0, -42.0)
const SKULL: Vector2 = Vector2(1.0, -50.0)
const SKULL_R: float = 8.0
## Its sockets, from the skull's middle, and how big.
const EYES: Array[Vector2] = [Vector2(-1.5, 0.0), Vector2(4.5, 0.0)]
const EYE_R: float = 2.2
## How far apart the hips sit (each side of the spine), and where the shoulders are: at the ends of
## the top rib, out at its sides, a little under the spine's top.
const HIPS: float = 3.5
const SHOULDERS: Vector2 = Vector2(7.0, 3.5)
## How thick the limbs are.
const LIMB: float = 3.2
## A stride (art units): a foot steps from half of it behind the hip to half of it ahead. A step
## takes STEP_TIME seconds and lifts the foot STEP_LIFT at its height. Standing, the feet settle a
## quarter of a stride either side of under the hip, stepping when one is further than SETTLE from
## there. How fast it is walking (px/s) is eased toward what it is by WALK_EASE (of the way, a
## second).
const STEP: float = 14.0
const STEP_TIME: float = 0.2
const STEP_LIFT: float = 5.0
const SETTLE: float = 3.5
const WALK_EASE: float = 10.0
## How far the whole stride is shifted forward (art units: a step starts that much short of half a
## stride behind the hip and lands that much past half a stride ahead), so the feet sit centred
## under the hip on average as it walks (tests/capture_skeleton_gif.gd prints how far they are).
const LEAD: float = 1.0
## As a leg swings: how far the body lifts (art units) and the torso rocks (radians) over the hip.
const BOB: float = 1.6
const ROCK: float = 0.07
## The skull: how fast it follows the body (of the way, a second), how far it tilts after it
## (radians, for each art unit it lags), and how far it lolls as it stands (radians).
const HEAD_EASE: float = 9.0
const HEAD_TILT: float = 0.12
const LOLL: float = 0.06
## How far its hands swing (art units, either way) as its feet go a stride, how far ahead of the
## shoulder they hang and how far out from its sides, and how fast they ease to where they go (of
## the way, a second); how far down (px) the floor under a foot is looked for.
const SWING: float = 5.0
const HANG: float = 1.0
const SPLAY: float = 3.0
const HAND_EASE: float = 7.0
const FLOOR_LOOK: float = 160.0

## Its feet where they are planted, in world pixels (the far one first), and the step under way:
## which foot (-1 none), from where, to where, and how far along (0 to 1).
var feet: Array[Vector2] = []
var stepping: int = -1
var step_from: Vector2 = Vector2.ZERO
var step_to: Vector2 = Vector2.ZERO
var step_t: float = 0.0
## The foot to step next (they take turns).
var next_foot: int = 0
## How fast it is walking (px/s, eased).
var speed: float = 0.0
## Where its hands are (art units, from its feet), eased toward where they hang.
var hands: Array[Vector2] = [Vector2(4, -26), Vector2(2, -26)]
## How high the skull is carried (art units, the body's lift eased after it).
var head_lift: float = 0.0
## Its glow canvas: the pink in its sockets, over the darkness (RisoLight.SHADE_Z).
var glow: InkCanvas
## Where the host was last frame (world), for which way and how fast it walks.
var _was: Vector2 = Vector2.INF


func _ready() -> void:
	super()
	glow = InkCanvas.new()
	glow.z_index = RisoLight.SHADE_Z + 1
	glow.z_as_relative = false
	add_child(glow)


func _draw_art() -> void:
	var sk: Skeleton = host.get_node_or_null("Skeleton") as Skeleton
	var facing: float = sk.facing if sk != null else 1.0
	var awake: bool = sk != null and not sk.asleep
	var up: float = 0.0
	if awake:
		var k: float = 1.0 - sk.rising / Skeleton.RISE if sk.rising > 0.0 else 1.0
		up = k * k * (3.0 - 2.0 * k)
	var g: float = _ground()
	# Lying, it lies along the floor, its skull the way it faces; rising, it swings up onto its feet.
	var lying: Vector2 = Vector2(-27.0 * SCALE * facing, g - 6.0 * SCALE)
	var xf: Transform2D = Transform2D(lerpf(PI * 0.5 * facing, 0.0, up), Vector2(facing, 1.0) * SCALE, 0.0, lying.lerp(Vector2(0, g), up))
	var standing: bool = up >= 1.0
	var grounded: bool = sk == null or sk.grounded
	if standing and grounded:
		_walk(facing, g)
	else:
		feet.clear()
		stepping = -1
	# The swing of the step under way: 0 to 1 and back over it, and toward which leg.
	var swing: float = sin(step_t * PI) if stepping >= 0 else 0.0
	var toward: float = -1.0 if stepping == 0 else 1.0
	var lift: float = swing * BOB
	var hip: Vector2 = Vector2(0, -HIP - lift)
	var knees: Array[Vector2] = []
	var soles: Array[Vector2] = []
	for i: int in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var at: Vector2 = hip + Vector2(HIPS * side, 0)
		var foot: Vector2 = at + Vector2(1.0, THIGH + SHIN - 0.5)
		if not feet.is_empty():
			foot = _art(_foot(i), facing, g)
		elif standing:
			# Off the ground: hanging, bent a little.
			foot = at + Vector2(-1.0 + side * 1.5, (THIGH + SHIN) * 0.85)
		soles.append(foot)
		knees.append(_joint(at, foot, THIGH, SHIN, Vector2(1, 0)))
	# The torso rocks over the hip toward the swinging leg, carrying the shoulders, ribs and neck.
	var rock: Transform2D = Transform2D(swing * toward * ROCK, hip) * Transform2D(0.0, -hip)
	var shoulder: Vector2 = rock * Vector2(0, -SHOULDER - lift)
	_swing(rock, shoulder, soles, up)
	# The far limbs first, a little fainter, then the body and skull, then the near limbs.
	var far: Array[PackedVector2Array] = []
	var near: Array[PackedVector2Array] = []
	for i: int in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var into: Array[PackedVector2Array] = far if i == 0 else near
		var at: Vector2 = hip + Vector2(HIPS * side, 0)
		into.append(xf * _bone(at, knees[i], LIMB))
		into.append(xf * _bone(knees[i], soles[i], LIMB))
		into.append(xf * RisoShapes.rrect(soles[i].x - 1.0, soles[i].y - 1.8, 6.0, 3.0, 1.5))
		var arm: Vector2 = shoulder + rock.basis_xform(Vector2(SHOULDERS.x * side, SHOULDERS.y))
		var elbow: Vector2 = _joint(arm, hands[i], UPPER, FORE, Vector2(-1, 0.2))
		into.append(xf * _bone(arm, elbow, LIMB * 0.85))
		into.append(xf * _bone(elbow, hands[i], LIMB * 0.85))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.55, far)
	var body: Array[PackedVector2Array] = []
	body.append(xf * RisoShapes.rrect(-7.0, hip.y - 2.5, 14.0, 5.0, 2.5))
	var neck: Vector2 = rock * (NECK + Vector2(0, -lift))
	body.append(xf * _bone(hip + Vector2(0, -1), neck, 3.6))
	body.append(xf * (rock * RisoShapes.rrect(-8.0, -SHOULDER - lift + 2.0, 16.0, 3.4, 1.7)))
	body.append(xf * (rock * RisoShapes.rrect(-6.0, -SHOULDER - lift + 7.0, 12.0, 3.4, 1.7)))
	# The skull rides the neck a moment late: carried at its eased height, tilted by how far it
	# lags and by the torso's rock, and lolling a little.
	head_lift = lift if not standing else lerpf(head_lift, lift, clampf(_dt * HEAD_EASE, 0.0, 1.0))
	var tilt: float = swing * toward * ROCK * 1.5 + (head_lift - lift) * HEAD_TILT + sin(t * 1.3 + phase) * LOLL * up
	var head: Transform2D = Transform2D(tilt, neck + Vector2(0, lift - head_lift)) * Transform2D(0.0, -NECK)
	body.append(xf * (head * RisoShapes.circle(SKULL, SKULL_R, 24)))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.9, body)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.9, near)
	_eyes(xf * head, awake, up)


## A bone from `a` to `b`, `wide` across, its ends rounded.
func _bone(a: Vector2, b: Vector2, wide: float) -> PackedVector2Array:
	var long: float = a.distance_to(b) + wide
	return Transform2D((b - a).angle(), (a + b) * 0.5) * RisoShapes.rrect(-long * 0.5, -wide * 0.5, long, wide, wide * 0.5)


## Two-bone inverse kinematics: the joint between a bone `first` long from `root` and one `second`
## long reaching `tip` (as near as they can), bent toward `bend`.
static func _joint(root: Vector2, tip: Vector2, first: float, second: float, bend: Vector2) -> Vector2:
	var to: Vector2 = tip - root
	var d: float = clampf(to.length(), absf(first - second) + 0.01, first + second - 0.01)
	var along: Vector2 = to.normalized() if to.length() > 0.001 else Vector2.DOWN
	var a: float = (first * first - second * second + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(first * first - a * a, 0.0))
	var side: Vector2 = along.orthogonal()
	if side.dot(bend) < 0.0:
		side = -side
	return root + along * a + side * h


## A point in the world as art units from its feet (facing right).
func _art(world: Vector2, facing: float, g: float) -> Vector2:
	var local: Vector2 = to_local(world) - Vector2(0, g)
	return Vector2(local.x * facing, local.y) / SCALE


## Foot `i` where it is now, in the world: planted, or along its step's arc.
func _foot(i: int) -> Vector2:
	if stepping != i:
		return feet[i]
	var at: Vector2 = step_from.lerp(step_to, step_t)
	return at + Vector2(0, -sin(step_t * PI) * STEP_LIFT * SCALE)


## Plant and step its feet as it walks (see the class note).
func _walk(facing: float, g: float) -> void:
	var here: Vector2 = host.global_position
	var dx: float = here.x - _was.x if _was != Vector2.INF else 0.0
	_was = here
	var moving: float = signf(dx) if absf(dx) > 0.05 else 0.0
	speed = lerpf(speed, absf(dx) / maxf(_dt, 0.001), clampf(_dt * WALK_EASE, 0.0, 1.0))
	var floor_y: float = to_global(Vector2(0, g)).y
	var stride: float = STEP * SCALE
	if feet.is_empty():
		for i: int in range(2):
			feet.append(Vector2(_under(i, here, facing) + _stance(i) * facing, floor_y))
	if stepping >= 0:
		step_t = minf(1.0, step_t + _dt / STEP_TIME)
		# Aimed again as the body goes on: half a stride ahead of where the hip will be as it lands.
		if moving != 0.0:
			step_to.x = _under(stepping, here, facing) + moving * (stride * 0.5 + LEAD * SCALE + speed * STEP_TIME * (1.0 - step_t))
		if step_t >= 1.0:
			feet[stepping] = step_to
			next_foot = 1 - stepping
			stepping = -1
	if stepping < 0:
		# Whichever foot is left further behind steps if the turn's foot is not ready (after a turn).
		var i: int = next_foot
		if moving != 0.0 and (_under(1 - i, here, facing) - feet[1 - i].x) * moving > stride:
			i = 1 - i
		var under: float = _under(i, here, facing)
		var to: float = INF
		if moving != 0.0:
			if (under - feet[i].x) * moving > stride * 0.5 - LEAD * SCALE or absf(feet[i].y - floor_y) > half:
				to = under + moving * (stride * 0.5 + LEAD * SCALE + speed * STEP_TIME)
		else:
			var rest: float = under + _stance(i) * facing
			if absf(feet[i].x - rest) > SETTLE * SCALE or absf(feet[i].y - floor_y) > half:
				to = rest
		if to != INF:
			stepping = i
			step_from = feet[i]
			step_to = Vector2(to, _floor_at(to, floor_y))
			step_t = 0.0


## Where foot `i` would be straight under its hip (world x), the body at `here` facing `facing`.
func _under(i: int, here: Vector2, facing: float) -> float:
	var side: float = -1.0 if i == 0 else 1.0
	return here.x + (side * HIPS + 1.0) * SCALE * facing


## How far ahead of under its hip (px, the way it faces) foot `i` stands at rest: the one to step
## next a quarter of a stride back, the other a quarter forward.
func _stance(i: int) -> float:
	return STEP * SCALE * (-0.25 if i == next_foot else 0.25)


## The floor under world x `x`, looked for from a cell over `near` down FLOOR_LOOK px; `near` if none.
func _floor_at(x: float, near: float) -> float:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return near
	var y: float = near - half * 2.0
	while y < near + FLOOR_LOOK:
		if info.solid_at(Vector2(x, y)):
			return info.cell_position(info.cell_at(Vector2(x, y))).y - half
		y += 4.0
	return near


## Where its hands go, eased there: hanging at its sides from the shoulders (`shoulder`, the torso
## rocked by `rock`), a little ahead, each swinging opposite its own side's foot as it walks
## (`soles`, the feet in art units), and swaying a little as it stands (along its body while it
## lies).
func _swing(rock: Transform2D, shoulder: Vector2, soles: Array[Vector2], up: float) -> void:
	for i: int in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var arm: Vector2 = shoulder + rock.basis_xform(Vector2(SHOULDERS.x * side, SHOULDERS.y))
		var under: float = HIPS * side + 1.0
		var ahead: float = clampf((soles[i].x - under) / (STEP * 0.5), -1.0, 1.0) if not feet.is_empty() else 0.0
		var sway: float = sin(t * 1.7 + phase + side) * 0.6
		# Reaching for a little past the arm's length, so it hangs straight and swings like a pendulum.
		var want: Vector2 = arm + Vector2(SPLAY * side + HANG - ahead * SWING + sway, UPPER + FORE)
		hands[i] = hands[i].lerp(want, 1.0 if up < 1.0 else clampf(_dt * HAND_EASE, 0.0, 1.0))


## Its sockets on the skull (`xf`, the skull's frame in art units): night hollows, and awake, a pink
## point in each with a faint pink glow round them, over the darkness.
func _eyes(xf: Transform2D, awake: bool, up: float) -> void:
	glow.begin()
	var sockets: Array[PackedVector2Array] = []
	var points: Array[PackedVector2Array] = []
	for e: Vector2 in EYES:
		sockets.append(xf * RisoShapes.circle(SKULL + e, EYE_R, 12))
		points.append(xf * RisoShapes.circle(SKULL + e, EYE_R * 0.5 + 0.2 * sin(t * 9.0 + phase), 8))
	ink.ink(RisoPrint.NIGHT, 0.9, sockets, false)
	if awake:
		var mid: Vector2 = SKULL + (EYES[0] + EYES[1]) * 0.5
		glow.ink(RisoPrint.PINK, 0.35 * up, [xf * RisoShapes.ellipse(mid, absf(EYES[1].x - EYES[0].x) * 0.5 + EYE_R * 1.6, EYE_R * 1.5, 14)])
		glow.ink(RisoPrint.PINK, up, points)
	glow.finish()
