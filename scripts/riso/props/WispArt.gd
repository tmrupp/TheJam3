extends CreatureArt
class_name WispArt
## A wisp: a teardrop of pink ink floating over the floor it haunts, its round head first and its
## tail trailing, narrowing evenly to a point like a cone. Its head leads and its body trails it:
## its neck (where its head ends and its tail begins) goes the way it points, and each part of its
## tail points the way its neck pointed when it was that far back, so its tail follows the path
## its head has come. What the wisp is doing says where its neck goes and which way it points:
## - walking, it floats along level, bobbing, its tail wagging;
## - turning round, its neck runs round a loop out ahead of it, a tight circle, and back onto its
##   path facing the other way, and its tail follows it round;
## - falling, its head tips down and its tail streams up behind it, and it squashes as it lands;
## - winding up its lurch, it draws back and gathers itself, squat and coiled, its glow heating;
## - lurching, it lets go, long and thin, and settles as it slows.
## Standing still, its tail swings into line behind its head.


## How long the drop is, nose to tail's point, how thick its head, and how thick its tail's point
## (all but nothing: its flanks run straight from its head to it), in pixels.
const LENGTH: float = 60.0
const GIRTH: float = 26.0
const TAIL_GIRTH: float = 2.0
## Its neck: how far behind its nose its head ends and its tail begins. Ahead of it the body is
## rigid and behind it the tail bends. At rest its neck floats over the wisp's origin (FLOAT, the
## middle of its touch, HitBox), bobbing BOB up and down, so its head leads its origin and its
## tail trails it, and a turn brings its neck back to where it began.
const NECK_BACK: float = 22.0
const FLOAT: Vector2 = Vector2(0.0, -25.0)
const BOB: float = 3.0
const BOB_RATE: float = 3.0
## Points round its head, round its tail's point, and along each flank between.
const ROUND_POINTS: int = 12
const TAIL_POINTS: int = 2
const FLANK_POINTS: int = 9
## Its glow is a soft edge round it, GLOW of pink at the body's own edge (flickering) thinning to
## nothing this much further out in front, at its sides and past its tail's point; up to
## (1 + FLARE) times as strong as it winds up.
const GLOW_GROWN: Vector3 = Vector3(4.0, 7.0, 14.0)
const GLOW: float = 0.28
const FLARE: float = 2.5
const FLICKER_RATE: float = 10.0
## The blue printed over its pink, which cools it to a dusky violet; winding up, HEAT_BARES this
## share of it burns off, leaving it hot pink.
const COOL: float = 0.35
const HEAT_BARES: float = 0.85
## Its eyes: two ovals EYE_SIZE across and high, EYE_GAP apart along its body, the middle of the
## pair EYES_BACK behind its nose and EYE_UP over its spine; winding up they narrow by SQUINT.
const EYE_SIZE: Vector2 = Vector2(3.4, 4.2)
const EYE_GAP: float = 9.5
const EYES_BACK: float = 12.5
const EYE_UP: float = 2.0
const SQUINT: float = 0.4
## Its shadow on the floor: how wide and high, and how much night it lays.
const SHADOW: Vector2 = Vector2(22.0, 4.5)
const SHADOW_INK: float = 0.35
## Its tail wags as it goes: a wave running down it, WAG (radians) either way at its point, WAG_RATE
## fast, WAG_WAVE radians a pixel along it.
const WAG: float = 0.15
const WAG_RATE: float = 6.0
const WAG_WAVE: float = 0.06
## Stunned, its tail hangs down by this much at its point, and wags this share as fast.
const DROOP: float = 0.6
const STUNNED_PACE: float = 0.4
## The stars of a stun circle this far over the middle of its head.
const STARS_UP: float = 46.0
## How big its tell is round its head (px; RisoProp.tell_mark).
const TELL_R: float = 44.0

## Turning round (Mover.TURN_TIME, while its Mover holds still): its neck runs round a loop out
## ahead of it and comes back to where it began, facing the other way (turn_path), going the way
## it points all the way round and never slid aside. The loop is three arcs, each running smoothly
## into the next: it dips under its path on a curve TURN_DIP_R in radius; swings up and round most
## of a full circle TURN_R in radius, whose middle lies TURN_LOW under its path (so the loop hangs
## below the path more than it stands above it, and its head clears a ceiling one cell up); and
## comes back down onto its path on a wide curve. It leaves and rejoins its path at its walking
## pace (Mover.SPEED) and is quickest round the far side.
const TURN_R: float = 12.0
const TURN_DIP_R: float = 12.0
const TURN_LOW: float = 6.0

## Its wake: the way its neck pointed at every WAKE_STEP px of the way it has come, the WAKE most
## recent. Its tail reads its bend from it. Going slower than STILL_SPEED px/s (standing, winding
## up, stunned), its wake eases toward the way it points now, at up to STRAIGHTEN a second, so its
## tail swings into line behind it.
const WAKE_STEP: float = 2.5
const WAKE: int = 20
const STILL_SPEED: float = 30.0
const STRAIGHTEN: float = 8.0
## Its origin moved further than this between prints (px), it has been put somewhere else, and its
## wake is laid out afresh, straight behind it.
const PUT_ELSEWHERE: float = 120.0

## Falling: from FALL_FROM px/s to FALL_FULL its nose tips down, DIVE at most (radians), and it
## stretches by FALL_STRETCH; it tips and rights itself at DIVE_PACE a second. Landing from a fall
## it squashes, by up to LAND_SQUASH of its length a second into its length's spring.
const FALL_FROM: float = 60.0
const FALL_FULL: float = 420.0
const DIVE: float = 1.25
const DIVE_PACE: float = 9.0
const FALL_STRETCH: float = 0.16
const LAND_SQUASH: float = 7.0
## The spring its length settles on: how stiff (radians a second) and how damped (1: no bounce).
const LENGTH_SPRING: float = 22.0
const LENGTH_DAMP: float = 0.5
## How far its width gives as its length changes (1 would keep its area).
const WIDTH_GIVES: float = 0.8

## Winding up (Mover.WIND_UP): it draws back PULL px from where it faces and RISE up, its nose
## lifting REAR and its tail curling up over its back, COIL at its point (radians), and squashes
## by WIND_SQUASH of its length, easing in and out over the wind-up. Lurching it lets go at
## RELEASE_PACE a second and stretches by LURCH_STRETCH, less as it slows; broken off (a stun), it
## settles at SETTLE_PACE.
const PULL: float = 11.0
const RISE: float = 3.0
const REAR: float = 0.22
const COIL: float = 1.3
const WIND_SQUASH: float = 0.16
const LURCH_STRETCH: float = 0.5
const WIND_PACE: float = 40.0
const RELEASE_PACE: float = 30.0
const SETTLE_PACE: float = 9.0

## Its spine's bones (InkCanvas.rig): CHAIN of them from its nose to its tail's point, CHAIN_STEP
## apart, each point of the drop carried by the two either side of it.
const CHAIN: int = 13
const CHAIN_STEP: float = LENGTH / 12.0
## Where things lie along the body at rest, x forward from its middle: its nose, its neck, the
## middle of its head and of its eyes; and how far its tail's point trails its neck.
const NOSE_X: float = LENGTH * 0.5
const NECK_X: float = NOSE_X - NECK_BACK
const HEAD_X: float = NOSE_X - GIRTH * 0.5
const EYES_X: float = NOSE_X - EYES_BACK
const TAIL_BACK: float = LENGTH - NECK_BACK
## Further than this from the wizard (px) a wisp walking is printed every WISP_FAR_EVERY frames
## rather than every other one. Turning, falling, winding up, lurching or with its tail still bent
## it prints every frame.
const WISP_NEAR: float = 480.0
const WISP_FAR_EVERY: int = 3
## Left unprinted this long (out of view), it takes its pose up afresh rather than easing into it.
const STALE: float = 0.3
## The spring is stepped no coarser than this (seconds).
const SPRING_STEP: float = 1.0 / 120.0
## Its tail is bent while any part of it points this far (radians) off the way its head does.
const BENT: float = 0.05

## The rest shapes, built once (_rest_shapes): the shadow (a unit disc its bone stretches), the
## glow (and how strong it is at each of its points), the body and the eyes, open and stunned.
static var _rests: Dictionary = {}
## The spine's binders, by its first bone (each names the two bones a point lies between).
static var _binders: Dictionary = {}
## The turn's loop, worked out once (_turn_loop): how far ahead the middle of its circle lies, the
## radius of the curve that brings it back onto its path, how far the dip and that curve each
## turn it (radians), and how long each of its three arcs is.
static var _loop_ahead: float = -1.0
static var _loop_back_r: float = 0.0
static var _loop_dip: float = 0.0
static var _loop_back: float = 0.0
static var _loop_arcs: Vector3 = Vector3.ZERO

## Which way it faced when last printed (0 before its first print), and the turn it is making: the
## way it faced before, when the turn began by this art's clock (t), and how far round the loop its
## neck has come (px).
var _facing: int = 0
var _turn_from: int = 0
var _turn_t0: float = -100.0
var _turn_d: float = 0.0
## The way its nose points, as an angle (0 facing right, PI facing left, PI / 2 straight up).
var _nose: float = 0.0
## Its wake (see WAKE_STEP), the most recent first, and how far it has gone since that one (px).
var _wake: PackedFloat32Array = PackedFloat32Array()
var _wake_part: float = 0.0
## Where its origin was when last printed (world), less how far it had been carried by what it
## stands on (Mover.carried): what is left is the way it has gone itself.
var _was_at: Vector2 = Vector2.ZERO
## Its length against LENGTH (1 at rest), and how fast that is changing.
var _stretch: float = 1.0
var _stretch_v: float = 0.0
## How far tipped into a fall it is, how wound up, how hot its glow, and how limp (each 0 to 1).
var _dive: float = 0.0
var _wind: float = 0.0
var _heat: float = 0.0
var _limp: float = 0.0
## How fast it was last seen falling (px/s), to squash by when it lands.
var _fell: float = 0.0
## When it was last printed (t), and whether it was moving then in a way worth printing every frame.
var _printed_t: float = -100.0
var _lively: bool = false
## Its neck, the middle of its head and the point of its tail as last printed, in world space.
var _neck_at: Vector2 = Vector2.INF
var _head_at: Vector2 = Vector2.INF
var _tip_at: Vector2 = Vector2.INF
## The spine as last worked out: each bone's angle and place (kept, so a print makes no new arrays).
var _angles: PackedFloat32Array = PackedFloat32Array()
var _places: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	super()
	ink.rig()
	ink.keeps_shapes = true
	_angles.resize(CHAIN)
	_places.resize(CHAIN)
	_wake.resize(WAKE)


func _draw_art() -> void:
	var mover: Mover = host.get_node_or_null("Mover") as Mover
	var facing: int = 1
	var stunned: bool = false
	var winding: float = -1.0
	var lurching: float = -1.0
	var falling: float = 0.0
	var airborne: bool = false
	var turn_done: float = Mover.TURN_TIME
	var gone_to: Vector2 = host.global_position
	if mover != null:
		facing = mover.direction
		stunned = mover.stunned
		winding = mover.winding
		lurching = mover.lurching
		airborne = not mover.grounded
		falling = mover.fall_speed if airborne else 0.0
		turn_done = Mover.TURN_TIME - mover.turn_left
		gone_to -= mover.carried
	var went: float = gone_to.distance_to(_was_at)
	var fresh: bool = _facing == 0 or t - _printed_t > STALE or went > PUT_ELSEWHERE
	_was_at = gone_to
	_printed_t = t
	if fresh:
		_turn_from = facing
		_turn_t0 = t - Mover.TURN_TIME
	elif facing != _facing:
		# It has turned: the turn is timed from when its Mover began it.
		_turn_from = _facing
		_turn_t0 = t - turn_done
		_turn_d = 0.0
	_facing = facing
	var u: float = clampf((t - _turn_t0) / Mover.TURN_TIME, 0.0, 1.0)
	var turning: bool = u < 1.0

	# How wound up, how hot, how far into a fall, how limp: each eased toward where its Mover has it.
	var wind_to: float = 0.0
	var wind_pace: float = SETTLE_PACE
	var heat_to: float = 0.0
	var lunge: float = 0.0
	if winding >= 0.0:
		wind_to = WispArt.eased(winding)
		wind_pace = WIND_PACE
		heat_to = winding
	elif lurching >= 0.0:
		wind_pace = RELEASE_PACE
		heat_to = 1.0 - lurching
		lunge = (1.0 - lurching) * (1.0 - lurching)
	var dive_to: float = smoothstep(FALL_FROM, FALL_FULL, falling)
	var limp_to: float = 1.0 if stunned else 0.0
	if fresh:
		_wind = wind_to
		_heat = heat_to
		_dive = dive_to
		_limp = limp_to
	else:
		_wind = lerpf(_wind, wind_to, 1.0 - exp(-wind_pace * _dt))
		_heat = lerpf(_heat, heat_to, 1.0 - exp(-WIND_PACE * _dt))
		_dive = lerpf(_dive, dive_to, 1.0 - exp(-DIVE_PACE * _dt))
		_limp = lerpf(_limp, limp_to, 1.0 - exp(-SETTLE_PACE * _dt))
	# Landed since the last print: squash by how fast it came down.
	if airborne:
		_fell = maxf(_fell, falling)
	elif _fell > 0.0:
		if not fresh:
			_stretch_v -= LAND_SQUASH * smoothstep(FALL_FROM, FALL_FULL, _fell)
		_fell = 0.0
	# Its length, on its spring.
	var stretch_to: float = 1.0 - WIND_SQUASH * _wind + LURCH_STRETCH * lunge + FALL_STRETCH * _dive
	if fresh:
		_stretch = stretch_to
		_stretch_v = 0.0
	else:
		var left: float = _dt
		while left > 0.0:
			var h: float = minf(left, SPRING_STEP)
			left -= h
			_stretch_v += (LENGTH_SPRING * LENGTH_SPRING * (stretch_to - _stretch) - 2.0 * LENGTH_DAMP * LENGTH_SPRING * _stretch_v) * h
			_stretch += _stretch_v * h
	_stretch = clampf(_stretch, 0.5, 1.8)
	var sx: float = _stretch
	var sy: float = lerpf(1.0, 1.0 / _stretch, WIDTH_GIVES)

	# Its neck: where it is (over its origin, drawn back as it winds up, round its loop as it turns)
	# and the way it points (the way it faces, or the way its loop runs; lifted as it winds up,
	# tipped down as it falls: either by which way it faces, cos).
	var from: float = 0.0 if _turn_from > 0 else PI
	var to: float = 0.0 if facing > 0 else PI
	var face: float = from if u < 0.5 else to
	var ahead: float = cos(face)
	var tilt: float = (REAR * _wind - DIVE * _dive) * ahead
	var neck: Vector2 = FLOAT + Vector2(-PULL * _wind * ahead, -RISE * _wind)
	var heading: float = face
	if fresh:
		_wake.fill(face + tilt)
		_wake_part = 0.0
	if turning:
		# Round its loop: its wake is laid in step by step from where its neck was at the last
		# print, so its tail follows the loop exactly however far round its neck went in a print.
		var side: float = float(_turn_from)
		var length: float = WispArt.turn_length()
		var d: float = length * WispArt.turn_pace(u, length)
		went = maxf(d - _turn_d, 0.0)
		while _wake_part + (d - _turn_d) >= WAKE_STEP:
			_turn_d += WAKE_STEP - _wake_part
			_wake_lay(WispArt.turn_path(_turn_d, side).z + tilt)
		_wake_part += d - _turn_d
		_turn_d = d
		var on: Vector3 = WispArt.turn_path(d, side)
		neck += Vector2(on.x, on.y)
		heading = on.z
		_nose = heading + tilt
	else:
		_nose = heading + tilt
		if not fresh:
			var more: float = went
			while _wake_part + more >= WAKE_STEP:
				more -= WAKE_STEP - _wake_part
				_wake_lay(_nose)
			_wake_part += more
	# Standing still, its tail swings into line behind its head.
	var speed: float = went / maxf(_dt, 0.001)
	if not turning and not fresh and speed < STILL_SPEED:
		var ease_by: float = 1.0 - exp(-STRAIGHTEN * (1.0 - speed / STILL_SPEED) * _dt)
		for i: int in range(WAKE):
			_wake[i] = lerpf(_wake[i], _nose, ease_by)

	# The spine. Its head is rigid: the bones ahead of its neck lie straight out the way it points.
	# Behind its neck each bone points the way its neck did when it was that far back (its wake),
	# and wags, hangs (stunned) or curls up over its back (winding up) a little more toward its
	# point; each lies a step back along the spine from the one before.
	var bob: float = sin(t * BOB_RATE + phase)
	neck.y -= BOB * bob
	var pointing: Vector2 = Vector2(cos(_nose), -sin(_nose))
	var wag_at: float = t * WAG_RATE * (STUNNED_PACE if stunned else 1.0) + phase
	var bend_tip: float = (DROOP * _limp - COIL * _wind) * ahead
	var bent: bool = false
	var at: Vector2 = neck
	var last_angle: float = _nose
	var last_x: float = NECK_X
	for i: int in range(CHAIN):
		var x: float = NOSE_X - CHAIN_STEP * float(i)
		if x >= NECK_X:
			_angles[i] = _nose
			_places[i] = neck + pointing * ((x - NECK_X) * sx)
			continue
		var back: float = NECK_X - x
		var along_tail: float = back / TAIL_BACK
		var a: float = _wake_at(back)
		bent = bent or absf(a - _nose) > BENT
		a += (WAG * sin(wag_at - back * WAG_WAVE) * (1.0 - _wind) + bend_tip * along_tail) * along_tail
		var mid: float = (last_angle + a) * 0.5
		at -= Vector2(cos(mid), -sin(mid)) * ((last_x - x) * sx)
		_angles[i] = a
		_places[i] = at
		last_angle = a
		last_x = x
	_lively = turning or bent or winding >= 0.0 or lurching >= 0.0 or airborne or _dive > 0.01 or _wind > 0.01 or absf(_stretch - 1.0) > 0.01 or absf(_stretch_v) > 0.05

	var rests: Dictionary = WispArt._rest_shapes()
	# Its shadow on the floor under it, smaller as it bobs up.
	var g: float = _ground()
	ink.on_bone(ink.bone(Transform2D(Vector2(SHADOW.x * sx * (1.0 - 0.08 * bob), 0.0), Vector2(0.0, SHADOW.y), Vector2(neck.x, g - 3.0))))
	ink.ink(RisoPrint.NIGHT, SHADOW_INK, rests[&"shadow"], false)
	var base: int = 0
	for i: int in range(CHAIN):
		var a: float = _angles[i]
		var along: Vector2 = Vector2(cos(a), -sin(a))
		var across: Vector2 = Vector2(sin(a), cos(a))
		var x: float = NOSE_X - CHAIN_STEP * float(i)
		var xf: Transform2D = Transform2D(along * sx, across * sy, _places[i] - along * sx * x)
		var b: int = ink.bone(xf)
		if i == 0:
			base = b
		if i == CHAIN - 1:
			_tip_at = to_global(xf * Vector2(NOSE_X - LENGTH, 0.0))
	var head: Vector2 = neck + pointing * ((HEAD_X - NECK_X) * sx)
	_neck_at = to_global(neck)
	_head_at = to_global(head)

	# Its glow, flickering (the flicker steps FLICKER_RATE times a second) and flaring as it heats.
	var ft: float = floorf(t * FLICKER_RATE) / FLICKER_RATE
	var flicker: float = 0.85 + 0.15 * sin(ft * 5.3 + phase) * sin(ft * 2.1 + phase * 1.7)
	ink.on_chain(base, WispArt._binder(base))
	ink.ink_graded(RisoPrint.PINK, rests[&"glow"], rests[&"glow_fade"], true, GLOW * flicker * (1.0 + FLARE * _heat))
	# The body is opaque: the inks of whatever is behind it (grass, light, its own glow) are cleared
	# from under it, then its pink and the blue that cools it.
	ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], rests[&"body"])
	ink.ink(RisoPrint.PINK, 1.0, rests[&"body"])
	ink.ink(RisoPrint.BLUE, COOL * (1.0 - HEAT_BARES * _heat), rests[&"body"], false)
	# Its eyes, on a bone of their own: over its spine whichever way up it is, so they cross it as
	# it comes round (cos), and narrowed as it winds up.
	var across_head: Vector2 = Vector2(sin(_nose), cos(_nose))
	var eyes_at: Vector2 = neck + pointing * ((EYES_X - NECK_X) * sx) - across_head * EYE_UP * cos(_nose) * sy
	ink.on_bone(ink.bone(Transform2D(pointing, across_head * (1.0 - SQUINT * _wind), eyes_at)))
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], rests[&"eyes_stunned" if stunned else &"eyes"])
	ink.on_bone(0)
	if stunned:
		_stun_mark(head + Vector2(0.0, -STARS_UP))
	# Its tell (the wind-up) round its head, and the last beat before the lurch.
	if mover != null and not stunned:
		tell_mark(head, TELL_R, winding, Difficulty.last_beat(winding, Difficulty.tell(Mover.WIND_UP)))


## Lay the way its neck points, `angle`, into its wake as its newest, a WAKE_STEP on from the last.
func _wake_lay(angle: float) -> void:
	for i: int in range(WAKE - 1, 0, -1):
		_wake[i] = _wake[i - 1]
	_wake[0] = angle
	_wake_part = 0.0


## The way its neck pointed when it was `back` px back along the way it has come.
func _wake_at(back: float) -> float:
	if back <= _wake_part:
		return lerpf(_nose, _wake[0], back / _wake_part) if _wake_part > 0.001 else _wake[0]
	var f: float = (back - _wake_part) / WAKE_STEP
	var i: int = mini(int(f), WAKE - 2)
	return lerpf(_wake[i], _wake[i + 1], minf(f - float(i), 1.0))


## `x` (0 to 1, held to it) eased: slow away from 0, slow into 1, with no jolt at either end.
static func eased(x: float) -> float:
	var s: float = clampf(x, 0.0, 1.0)
	return s * s * s * (s * (s * 6.0 - 15.0) + 10.0)


## Work the turn's loop out, the first time (see TURN_R): where the middle of its circle must lie
## for the dip to run into it, and the curve that brings it back onto the path from the circle.
static func _turn_loop() -> void:
	if _loop_ahead >= 0.0:
		return
	var reach: float = TURN_R + TURN_DIP_R
	_loop_ahead = sqrt(reach * reach - (TURN_LOW - TURN_DIP_R) * (TURN_LOW - TURN_DIP_R))
	_loop_back_r = (_loop_ahead * _loop_ahead + TURN_LOW * TURN_LOW - TURN_R * TURN_R) / (2.0 * (TURN_R - TURN_LOW))
	_loop_dip = atan2(_loop_ahead, TURN_DIP_R - TURN_LOW)
	_loop_back = atan2(_loop_ahead, TURN_LOW + _loop_back_r)
	_loop_arcs = Vector3(TURN_DIP_R * _loop_dip, TURN_R * (PI + _loop_dip + _loop_back), _loop_back_r * _loop_back)


## How far round the turn's loop is, from leaving its path to coming back onto it (px).
static func turn_length() -> float:
	_turn_loop()
	return _loop_arcs.x + _loop_arcs.y + _loop_arcs.z


## The turn's loop at `d` px round it, for a wisp that faced `side` (1 right, -1 left) before the
## turn, from where its neck was when the turn began: Vector3(x, y, the way it runs there, an
## angle as _nose). Before the loop (d below 0) it runs straight on along its path, and after it
## straight back; between, the dip, the circle and the curve back (see TURN_R).
static func turn_path(d: float, side: float) -> Vector3:
	_turn_loop()
	var at: Vector2
	var angle: float
	var round_it: float = d - _loop_arcs.x
	var back: float = round_it - _loop_arcs.y
	if d <= 0.0:
		at = Vector2(d, 0.0)
		angle = 0.0
	elif round_it <= 0.0:
		# The dip: a curve under the path, touching it where the turn begins.
		var a: float = d / TURN_DIP_R
		at = Vector2(TURN_DIP_R * sin(a), TURN_DIP_R * (1.0 - cos(a)))
		angle = -a
	elif back <= 0.0:
		# The circle, from where the dip runs into it, up and round and over.
		angle = -_loop_dip + round_it / TURN_R
		at = Vector2(_loop_ahead + TURN_R * sin(angle), TURN_LOW + TURN_R * cos(angle))
	elif back < _loop_arcs.z:
		# The curve back down onto the path, touching it where the turn began.
		angle = PI + _loop_back - back / _loop_back_r
		at = Vector2(-_loop_back_r * sin(angle), -_loop_back_r - _loop_back_r * cos(angle))
	else:
		at = Vector2(-(back - _loop_arcs.z), 0.0)
		angle = PI
	return Vector3(at.x, at.y, angle) if side > 0.0 else Vector3(-at.x, at.y, PI - angle)


## How far round its loop (0 to 1), `length` px round, its neck is at `u` of the turn (0 to 1): it
## leaves its path and comes back onto it at its walking pace (Mover.SPEED), and is quickest half
## way round.
static func turn_pace(u: float, length: float) -> float:
	var ends: float = clampf(Mover.SPEED * Mover.TURN_TIME / length, 0.0, 1.0)
	return ends * u + (1.0 - ends) * (u - sin(TAU * u) / TAU)


## A drop lying along x: its head a round end `head_r` in radius with its nose at x = `nose`, its
## tail's a smaller one `tail_r` in radius reaching back to x = `tail`, and a flank from one to the
## other on either side, dead straight. Round the head first, from where the upper flank meets it,
## then back along the lower flank, round the tail's end and forward along the upper flank.
static func drop(nose: float, head_r: float, tail: float, tail_r: float) -> PackedVector2Array:
	var head_c: Vector2 = Vector2(nose - head_r, 0.0)
	var tail_c: Vector2 = Vector2(tail + tail_r, 0.0)
	# Where the flanks leave each round end: where a line touching both touches it.
	var leave: float = PI * 0.5 + asin(clampf((head_r - tail_r) / (head_c.x - tail_c.x), -1.0, 1.0))
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(ROUND_POINTS + 1):
		var a: float = lerpf(-leave, leave, float(i) / float(ROUND_POINTS))
		out.append(head_c + Vector2(cos(a), sin(a)) * head_r)
	var ends: PackedVector2Array = PackedVector2Array()
	for i: int in range(TAIL_POINTS + 1):
		var a: float = lerpf(leave, TAU - leave, float(i) / float(TAIL_POINTS))
		ends.append(tail_c + Vector2(cos(a), sin(a)) * tail_r)
	for flank: int in range(2):
		var a: Vector2 = out[ROUND_POINTS] if flank == 0 else ends[TAIL_POINTS]
		var b: Vector2 = ends[0] if flank == 0 else out[0]
		for k: int in range(1, FLANK_POINTS):
			out.append(a.lerp(b, float(k) / float(FLANK_POINTS)))
		if flank == 0:
			out.append_array(ends)
	return out


## A drop's outline (drop) cut into the pieces it is printed as: its head, whole; then its tail
## in rungs, each from one flank straight across to the other, a step along; and its tail's end. Cut
## so, each piece bends with the spine under it, where triangles running the length of the body
## would cut across a bend.
static func rungs(outline: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [outline.slice(0, ROUND_POINTS + 1)]
	var tail_from: int = ROUND_POINTS + FLANK_POINTS
	# The flanks' points from the head back: the lower as the outline has them, the upper the
	# other way round.
	var lower: PackedVector2Array = outline.slice(ROUND_POINTS, tail_from + 1)
	var upper: PackedVector2Array = PackedVector2Array([outline[0]])
	for k: int in range(1, FLANK_POINTS + 1):
		upper.append(outline[outline.size() - k])
	for k: int in range(FLANK_POINTS):
		out.append(PackedVector2Array([upper[k], upper[k + 1], lower[k + 1], lower[k]]))
	out.append(outline.slice(tail_from, tail_from + TAIL_POINTS + 1))
	return out


## The rest shapes (see _rests), built the first time.
static func _rest_shapes() -> Dictionary:
	if not _rests.is_empty():
		return _rests
	var shadow: Array[PackedVector2Array] = [RisoShapes.ellipse(Vector2.ZERO, 1.0, 1.0, 14)]
	var edge: PackedVector2Array = drop(NOSE_X, GIRTH * 0.5, NOSE_X - LENGTH, TAIL_GIRTH * 0.5)
	var body: Array[PackedVector2Array] = rungs(edge)
	# The glow: a strip from the body's edge, where it is strongest, out to a bigger drop round it,
	# where it is nothing, point for point.
	var rim: PackedVector2Array = drop(NOSE_X + GLOW_GROWN.x, GIRTH * 0.5 + GLOW_GROWN.y, NOSE_X - LENGTH - GLOW_GROWN.z, TAIL_GIRTH * 0.5 + GLOW_GROWN.y)
	var glow: Array[PackedVector2Array] = []
	var glow_fade: Array[PackedFloat32Array] = []
	for i: int in range(edge.size()):
		var j: int = (i + 1) % edge.size()
		glow.append(PackedVector2Array([edge[i], edge[j], rim[j], rim[i]]))
		glow_fade.append(PackedFloat32Array([1.0, 1.0, 0.0, 0.0]))
	var eyes: Array[PackedVector2Array] = []
	var dazed: Array[PackedVector2Array] = []
	for side: float in [0.5, -0.5]:
		var at: Vector2 = Vector2(EYE_GAP * side, 0.0)
		eyes.append(RisoShapes.ellipse(at, EYE_SIZE.x, EYE_SIZE.y, 10))
		dazed.append(RisoShapes.rrect(at.x - EYE_SIZE.x * 1.2, -1.5, EYE_SIZE.x * 2.4, 3.0, 1.5, 2))
	_rests[&"shadow"] = shadow
	_rests[&"body"] = body
	_rests[&"glow"] = glow
	_rests[&"glow_fade"] = glow_fade
	_rests[&"eyes"] = eyes
	_rests[&"eyes_stunned"] = dazed
	return _rests


## The binder for the spine whose first bone is `base`: a point lies between the two bones either
## side of its x, carried by each in proportion to how near it is.
static func _binder(base: int) -> Callable:
	if not _binders.has(base):
		_binders[base] = func(p: Vector2) -> Vector3:
			var f: float = clampf((NOSE_X - p.x) / CHAIN_STEP, 0.0, float(CHAIN - 1))
			var i: int = mini(int(f), CHAIN - 2)
			return Vector3(base + i, base + i + 1, 1.0 - (f - float(i)))
	return _binders[base]


## Every frame while it turns, falls, winds up, lurches, is still settling from one of them or has
## its tail still bent behind it; walking, thirty times a second near the wizard and twenty far
## from them (see WISP_NEAR).
func reprint_every() -> int:
	if _lively:
		return 1
	var player: Player = Stage.player()
	if player != null and host != null and host.global_position.distance_squared_to(player.global_position) > WISP_NEAR * WISP_NEAR:
		return WISP_FAR_EVERY
	return REPRINT_EVERY


## A shield centres on the middle of its head, which leads the wisp's origin.
func guard_center() -> Vector2:
	return _head_at if _head_at != Vector2.INF else super.guard_center()


## The middle of its head as last printed, in world space (its origin's place before a print).
func head_at() -> Vector2:
	return _head_at if _head_at != Vector2.INF else super.guard_center()


## Its neck as last printed, in world space (its origin's place before a print).
func neck_at() -> Vector2:
	return _neck_at if _neck_at != Vector2.INF else super.guard_center()


## The point of its tail as last printed, in world space (its origin's place before a print).
func tip_at() -> Vector2:
	return _tip_at if _tip_at != Vector2.INF else super.guard_center()
