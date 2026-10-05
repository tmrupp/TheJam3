extends Node2D
## The hopper: squats on the floor until it sees the wizard close by, then crouches and leaps at
## them, aiming to land where they stood; it rests a moment between leaps. Moved only from here,
## like the wisp: a frozen (kinematic) RigidBody2D falling under its own gravity.

## How far off (across, up or down) it notices the wizard, with a clear line between them.
const SIGHT: Vector2 = Vector2(700, 400)
const CROUCH_TIME: float = 0.45
const REST_TIME: float = 1.1
const JUMP_SPEED: float = 700.0
const MAX_ACROSS: float = 420.0
const MAX_FALL: float = 1100.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var rb: RigidBody2D = $".."
@onready var player: Player = get_node_or_null("/root/Main/Player") as Player
var stunned: bool = false
var velocity: Vector2 = Vector2.ZERO
## Standing on something (only then does it crouch or leap).
var grounded: bool = false
## 0..1 through the crouch before a leap (the art curls forward with it), or -1 when not crouching.
var crouch: float = -1.0
var rest: float = 0.0
## +1 facing right, -1 left.
var facing: float = 1.0
## Seconds since it last landed (the art throws it forward as it lands).
var since_landing: float = 10.0


func _ready() -> void:
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	# Damage comes from HitBox. The leaping solid body must not carry the wizard or shove them
	# out of overlaps while they are invulnerable; it still collides with terrain normally.
	if player != null:
		rb.add_collision_exception_with(player)
		player.add_collision_exception_with(rb)
	# Spawned at its cell's centre: settle onto the floor at once.
	rb.move_and_collide(Vector2(0, 128))


func _physics_process(delta: float) -> void:
	since_landing += delta
	_move(delta)
	if stunned:
		crouch = -1.0
		return
	if not grounded:
		return
	if rest > 0.0:
		rest = maxf(0.0, rest - delta)
		return
	if crouch >= 0.0:
		crouch += delta / CROUCH_TIME
		if crouch >= 1.0:
			crouch = -1.0
			_leap()
	elif _sees_wizard():
		crouch = 0.0
		facing = signf(player.global_position.x - rb.global_position.x) if player.global_position.x != rb.global_position.x else facing


func _sees_wizard() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var d: Vector2 = player.global_position - rb.global_position
	if absf(d.x) > SIGHT.x or absf(d.y) > SIGHT.y:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(rb.global_position, player.global_position, 4, [rb.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Up and toward where the wizard is now, timed to come down about there.
func _leap() -> void:
	if player == null or not is_instance_valid(player):
		return
	var airtime: float = 2.0 * JUMP_SPEED / gravity
	var across: float = player.global_position.x - rb.global_position.x
	velocity = Vector2(clampf(across / airtime, -MAX_ACROSS, MAX_ACROSS), -JUMP_SPEED)
	facing = signf(across) if across != 0.0 else facing
	grounded = false


func _move(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL)
	var was_grounded: bool = grounded
	grounded = false
	var hit: KinematicCollision2D = rb.move_and_collide(velocity * delta)
	if hit == null:
		return
	var n: Vector2 = hit.get_normal()
	if n.y < -0.7:
		grounded = true
		velocity = Vector2.ZERO
		if not was_grounded:
			since_landing = 0.0
			rest = REST_TIME
	elif n.y > 0.7:
		velocity.y = maxf(velocity.y, 0.0)
	else:
		velocity.x = 0.0
