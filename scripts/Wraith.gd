extends Stunnable
class_name Wraith
## A wraith, in cemetery levels: a shrouded shade that hangs still, bobbing, until it senses the
## wizard within WAKE (through rock: it needs no line of sight), then drifts at them, straight
## through rock (slower inside it). Its touch hurts, like any enemy's, and it falls back a moment
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
	# A little faster on a harder preset (Difficulty.speed).
	var speed: float = SPEED * Difficulty.speed() * (IN_ROCK if in_rock() else 1.0)
	if recoil > 0.0:
		recoil = maxf(0.0, recoil - delta)
		velocity = -to_wizard.normalized() * RECOIL_SPEED * (recoil / RECOIL_TIME)
	elif awake:
		velocity = velocity.move_toward(to_wizard.normalized() * speed, speed * 2.0 * delta)
	else:
		var back: Vector2 = home - rb.global_position
		velocity = back.normalized() * minf(speed, back.length() / maxf(delta, 0.001)) if back.length() > 2.0 else Vector2.ZERO
	if absf(velocity.x) > 5.0:
		facing = signf(velocity.x)
	rb.global_position += velocity * delta
	if recoil <= 0.0 and to_wizard.length() < 60.0:
		recoil = RECOIL_TIME
