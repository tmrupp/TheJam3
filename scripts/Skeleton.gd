extends Stunnable
class_name Skeleton
## A skeleton, of the cemetery's crypts (Crypts) and the necromancer's graves (Necromancer). One
## laid in a crypt sleeps, lying in its niche, harmless, until light falls on it (Lamplight: the
## wizard's lit flame, a lantern's light); then it rises (RISE seconds) and walks at the wizard
## along its floor, hopping up a step of a cell, stopping at a ledge unless the wizard is below,
## and its touch hurts. Light is what wakes it: a snuffed wizard (Snuffer) slips past the sleepers.
## One the necromancer raises comes up out of its grave awake. Once awake it stays awake; with the
## wizard beyond LOSE it stands where it is. It cannot be killed (its Wound is unhurt): a blow or a
## stun (a parry, the hex's) knocks it to pieces, a heap of bones on the floor, harmless, for
## APART seconds, and then it pulls itself together again (REFORM seconds) and comes on, awake. The
## body is a frozen kinematic RigidBody2D moved only from here, falling under its own gravity, as a
## wisp's is (Mover).

## Walking speed (px/s), a little faster on a harder preset (Difficulty.speed).
const SPEED: float = 70.0
## The hop up a step (px/s up): clears a cell.
const HOP: float = -580.0
const MAX_FALL: float = 900.0
## Seconds it takes to rise from its niche or its grave.
const RISE: float = 0.9
## Past this distance from the wizard (px) it stands still.
const LOSE: float = 1400.0
## It turns to face the wizard only when they are more than this far to one side (px), so it does
## not dither under them.
const FACE_GAP: float = 10.0
## How far ahead (px) it looks for a wall to hop or a ledge to stop at.
const AHEAD: float = 22.0
## Where light is looked for on it (px over its middle): its skull, lying or standing.
const LIGHT_RISE: float = 8.0
## Knocked to pieces: how long its bones take to fall (s), how long they lie in a heap, and how long
## it takes to pull itself together again.
const FALL: float = 0.3
const APART: float = 2.6
const REFORM: float = 0.8

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var rb: RigidBody2D = $".."
@onready var player: Player = Stage.player()
## Asleep in its niche (see the class note): set before it enters the scene to lay it awake.
var asleep: bool = true
## Seconds left of rising (0 once up).
var rising: float = 0.0
## +1 facing right, -1 left.
var facing: float = 1.0
var fall_speed: float = 0.0
var grounded: bool = false
## Walking now (the art swings its legs), and how far it has walked all told (px).
var walking: bool = false
var walked: float = 0.0
## Seconds left in pieces (see the class note; 0 while whole), counting down through FALL, APART
## and REFORM.
var broken: float = 0.0
## Whether it was stunned last frame: a stun knocks it to pieces as it lands, not for as long as it lasts.
var _was_stunned: bool = false


func _ready() -> void:
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.move_and_collide(Vector2(0, 64))
	var wound: Wound = rb.get_node_or_null("Wound") as Wound
	if wound != null:
		wound.unhurt = true
		wound.warded.connect(func(_dir: Vector2) -> void: _break())
	if asleep or rising > 0.0:
		_harmless(true)
	facing = -1.0 if RisoDecor.h(rb.get_instance_id(), Vector2i.ZERO, 0) < 0.5 else 1.0


## Raised awake out of a grave by the necromancer, before it enters the scene: rising.
func raise() -> void:
	asleep = false
	rising = RISE


## Its touch hurts only once it is up.
func _harmless(value: bool) -> void:
	var shape: CollisionShape2D = rb.get_node_or_null("HitBox/CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", value)


func _physics_process(delta: float) -> void:
	if stunned and not _was_stunned:
		_break()
	_was_stunned = stunned
	_fall(delta)
	walking = false
	if broken > 0.0:
		broken = maxf(0.0, broken - delta)
		if broken == 0.0:
			_harmless(false)
		return
	if stunned:
		return
	if asleep:
		if Lamplight.at(rb.global_position + Vector2(0, -LIGHT_RISE)):
			asleep = false
			rising = RISE
		return
	if rising > 0.0:
		rising = maxf(0.0, rising - delta)
		if rising == 0.0:
			_harmless(false)
		return
	if player == null or not is_instance_valid(player):
		return
	var to: Vector2 = player.global_position - rb.global_position
	if to.length() > LOSE:
		return
	if absf(to.x) > FACE_GAP:
		facing = signf(to.x)
	elif grounded:
		return
	if grounded and _wall_ahead():
		fall_speed = HOP
		grounded = false
	elif grounded and not _floor_ahead() and to.y < 32.0:
		return
	var step: float = SPEED * Difficulty.speed() * facing * delta
	var hit: KinematicCollision2D = rb.move_and_collide(Vector2(step, 0))
	if hit == null or absf(hit.get_normal().x) < 0.7:
		walking = true
		walked += absf(step)


## Fall until something is underfoot; resting on the floor, stay put (no bounce).
func _fall(delta: float) -> void:
	fall_speed = minf(fall_speed + gravity * delta, MAX_FALL)
	var hit: KinematicCollision2D = rb.move_and_collide(Vector2(0, fall_speed * delta))
	grounded = hit != null and hit.get_normal().y < -0.7
	if hit != null:
		fall_speed = 0.0


## A wall right in front, where it walks.
func _wall_ahead() -> bool:
	var lifted: Transform2D = rb.global_transform.translated(Vector2(0, -4))
	return rb.test_move(lifted, Vector2(AHEAD * facing, 0))


## Floor under the body just past its leading edge.
func _floor_ahead() -> bool:
	var ahead: Transform2D = rb.global_transform.translated(Vector2(AHEAD * facing, 0))
	return rb.test_move(ahead, Vector2(0, 12))


## Stunned or struck: it falls to pieces, harmless, to pull itself together again awake (see the
## class note). Struck again in pieces, it only lies there.
func _break() -> void:
	if broken > 0.0:
		return
	broken = FALL + APART + REFORM
	asleep = false
	rising = 0.0
	_harmless(true)
	RisoFx.burst(&"impact", rb.global_position, Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])


## How far in pieces it is, for the art: 0 whole, 1 a heap on the floor; rising to 1 as its bones
## fall and back to 0 as it pulls itself together.
func apart() -> float:
	if broken <= 0.0:
		return 0.0
	if broken > APART + REFORM:
		return clampf((FALL + APART + REFORM - broken) / FALL, 0.0, 1.0)
	if broken > REFORM:
		return 1.0
	return broken / REFORM
