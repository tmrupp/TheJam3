extends Stunnable
class_name Wraith
## A wraith, in cemetery levels: a shrouded shade that hangs still, bobbing, until it senses the
## wizard within WAKE (through rock: it needs no line of sight), then drifts at them, straight
## through rock (slower inside it), and darts at them once near (see DART_RANGE). Its touch hurts, like any enemy's, and it falls back a moment
## after. If the wizard gets beyond LOSE it drifts home. Nothing solid stops it, and nothing stops
## the wizard passing through it. Nothing hurts it either (its Wound is unhurt): a blow only shows
## on it, and the hex or a parry stuns it. Moved only from here: its body is a frozen kinematic
## RigidBody2D that collides with nothing, and its HitBox does the hurting.
##
## It hunts only a wizard whose flame is out (MapInfo.flame_lit): snuffed at a font (Snuffer), or
## unprotected. While their flame is lit it does not come at them at all, wherever they are, and
## drifts home. It is light-shy too: while light falls on it (Lamplight: the wizard's lit flame, a
## lantern's light), it freezes where it is, cowering (its touch still hurts, if the wizard walks
## into it). Inside rock no light reaches it, so it comes on through the rock and freezes as it
## comes out into a lantern's light.

const WAKE: float = 640.0
const LOSE: float = 1400.0
const SPEED: float = 55.0
## Speed inside rock, as a share of SPEED.
const IN_ROCK: float = 0.6
const RECOIL_TIME: float = 1.2
const RECOIL_SPEED: float = 160.0
## The dart: hunting, with the wizard within DART_RANGE, it swells for SWELL seconds, drawing back
## from them at up to SWELL_BACK px/s (its art swells and flares its hem, its eyes burning: WraithArt),
## then darts at where they were as it finished, DART_SPEED px/s slowing to nothing over DART_TIME
## seconds (about DART_SPEED * DART_TIME / 2 px in all, slower inside rock), straight through
## anything. It hangs a moment after (DART_REST seconds) and drifts on DART_AGAIN seconds before it
## may dart again. A harder preset swells and rests for less (Difficulty.attack). Light (it freezes)
## or a stun breaks it off, and so does a touch (it falls back, as ever).
const DART_RANGE: float = 300.0
const SWELL: float = 0.65
const SWELL_BACK: float = 50.0
const DART_SPEED: float = 760.0
const DART_TIME: float = 0.4
const DART_REST: float = 0.6
const DART_AGAIN: float = 2.4

@onready var rb: RigidBody2D = $".."
@onready var player: Player = Stage.player()
var home: Vector2 = Vector2.ZERO
var awake: bool = false
## Seconds left falling back after a touch.
var recoil: float = 0.0
var velocity: Vector2 = Vector2.ZERO
## Frozen in light now (see the class note).
var shy: bool = false
## +1 facing right, -1 left (the art).
var facing: float = 1.0
## How far into the swell (0 to 1), and into the dart (0 to 1) it is, each -1 when not; which way it
## darts; and the seconds left hanging after a dart, and before it may dart again.
var swelling: float = -1.0
var darting: float = -1.0
var dart_dir: Vector2 = Vector2.ZERO
var resting: float = 0.0
var dart_wait: float = 0.0
var t: float = 0.0


func _ready() -> void:
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	# A shade: nothing collides with it (its HitBox still finds the wizard), and nothing hurts it.
	rb.collision_layer = 0
	rb.collision_mask = 0
	var wound: Wound = rb.get_node_or_null("Wound") as Wound
	if wound != null:
		wound.unhurt = true


## Whether it is inside rock now (the art fades it).
func in_rock() -> bool:
	var info: MapInfo = MapInfo.instance
	return info != null and info.world != null and info.solid_at(rb.global_position)


func _physics_process(delta: float) -> void:
	t += delta
	if home == Vector2.ZERO:
		home = rb.global_position
	shy = Lamplight.at(rb.global_position)
	if stunned or shy or player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		_break_off()
		return
	var to_wizard: Vector2 = player.global_position + Vector2(0, -50) - rb.global_position
	var info: MapInfo = MapInfo.instance
	var lit: bool = info != null and info.run != null and info.flame_lit()
	if lit:
		awake = false
	elif not awake and to_wizard.length() <= WAKE:
		awake = true
	elif awake and to_wizard.length() > LOSE:
		awake = false
	if not awake:
		_break_off()
	# A little faster on a harder preset (Difficulty.speed).
	var speed: float = SPEED * Difficulty.speed() * (IN_ROCK if in_rock() else 1.0)
	if recoil > 0.0:
		recoil = maxf(0.0, recoil - delta)
		velocity = -to_wizard.normalized() * RECOIL_SPEED * (recoil / RECOIL_TIME)
	elif awake and _dart(delta, to_wizard):
		pass
	elif awake:
		velocity = velocity.move_toward(to_wizard.normalized() * speed, speed * 2.0 * delta)
	else:
		var back: Vector2 = home - rb.global_position
		velocity = back.normalized() * minf(speed, back.length() / maxf(delta, 0.001)) if back.length() > 2.0 else Vector2.ZERO
	if swelling >= 0.0:
		# Swelling, it faces the wizard, though it draws back from them.
		facing = signf(to_wizard.x) if absf(to_wizard.x) > 5.0 else facing
	elif absf(velocity.x) > 5.0:
		facing = signf(velocity.x)
	rb.global_position += velocity * delta
	if recoil <= 0.0 and to_wizard.length() < 60.0:
		recoil = RECOIL_TIME
		_break_off()


## The dart, a step of it (see DART_RANGE), the wizard `to` away: whether it sets the velocity this
## step.
func _dart(delta: float, to: Vector2) -> bool:
	var pace: float = Difficulty.attack()
	if darting >= 0.0:
		darting = minf(1.0, darting + delta / DART_TIME)
		velocity = dart_dir * DART_SPEED * (1.0 - darting) * (IN_ROCK if in_rock() else 1.0)
		if darting >= 1.0:
			darting = -1.0
			resting = DART_REST
		return true
	if resting > 0.0:
		resting = maxf(0.0, resting - delta * pace)
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 4.0 * delta)
		if resting <= 0.0:
			dart_wait = DART_AGAIN
		return true
	if swelling >= 0.0:
		swelling += delta * pace / SWELL
		velocity = -to.normalized() * SWELL_BACK * sin(PI * minf(swelling, 1.0))
		if swelling >= 1.0:
			swelling = -1.0
			darting = 0.0
			dart_dir = to.normalized()
		return true
	if dart_wait > 0.0:
		dart_wait = maxf(0.0, dart_wait - delta * pace)
		return false
	if to.length() < DART_RANGE:
		swelling = 0.0
		return true
	return false


## A swell or dart under way is lost (light, a stun, a touch).
func _break_off() -> void:
	if swelling >= 0.0 or darting >= 0.0 or resting > 0.0:
		swelling = -1.0
		darting = -1.0
		resting = 0.0
		dart_wait = DART_AGAIN
