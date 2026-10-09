extends Stunnable
class_name Mover
## Wisp patrol: walk along the floor, turning round at walls, ledges and other wisps.
## The body is a frozen (kinematic) RigidBody2D moved only from here, falling under its own
## gravity until it lands, so the physics engine never bounces it on the floor.


const SPEED: float = 60.0
const JUMP_VELOCITY: float = -400.0
const MAX_FALL: float = 900.0
## Two wisps meeting both turn round at this distance, centre to centre, leaving each room for
## its turning drop (WispArt) in the half of the way between them, so the drops meet nose to nose.
const WISP_GAP: float = 100.0
## A wisp turns round when its front comes within WALL_ROOM of a wall, rather than at the wall, so
## its turning drop (WispArt) swings round in the open instead of into the rock.
const WALL_ROOM: float = 40.0
## The wall probe is lifted this far off the floor, so the floor it walks on never reads as a wall.
const WALL_LIFT: float = 4.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var tilemap: TileMap = Stage.tile_map() # $\"../TileMap\"
@onready var dcast: RayCast2D = $DownCast
@onready var rb: RigidBody2D = $".."
@onready var sprite: Sprite2D = $"../Sprite2D"
## Turning round: the wisp holds still for TURN_TIME while its art swoops round its turning drop
## (WispArt times the drop by it).
const TURN_TIME: float = 0.7
var turn_left: float = 0.0
var fall_speed: float = 0.0
## Standing on something (only then does it walk, or look for ledges).
var grounded: bool = false


func _ready() -> void:
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.add_to_group(&"wisps")
	# Spawned at its cell's centre: settle onto the floor at once.
	rb.move_and_collide(Vector2(0, 128))


func turn () -> void:
	direction *= -1
	dcast.position.x *= -1
	turn_left = TURN_TIME

func wait_to_down () -> void:
	down_wait = true
	await get_tree().create_timer(.1).timeout
	down_wait = false


var direction: int = 1
var down_wait: bool = false
func _physics_process(delta: float) -> void:
	_fall(delta)
	if stunned or not grounded:
		return
	if turn_left > 0.0:
		turn_left = maxf(0.0, turn_left - delta)
		return

	var collision: KinematicCollision2D = rb.move_and_collide(Vector2(SPEED, 0)*delta*direction)

	# Only a wall faced head-on turns it, never a seam or corner of the floor it walks on.
	if collision and absf(collision.get_normal().x) > 0.7 and signf(collision.get_normal().x) == -float(direction):
		turn()
	elif _wall_near() or _wisp_ahead():
		turn()
	elif not _floor_ahead():
		if not down_wait:
			turn()
			wait_to_down()

	if direction != 0:
		if direction > 0:
			sprite.scale.x = abs(sprite.scale.x)
		else:
			sprite.scale.x = -abs(sprite.scale.x)


## Fall until something is underfoot; resting on the floor, stay put (no bounce).
func _fall(delta: float) -> void:
	fall_speed = minf(fall_speed + gravity * delta, MAX_FALL)
	var hit: KinematicCollision2D = rb.move_and_collide(Vector2(0, fall_speed * delta))
	grounded = hit != null and hit.get_normal().y < -0.7
	if hit != null:
		fall_speed = 0.0


## Whether there is floor under the body just past its leading edge. A body-shape probe tests
## the same floor the wisp stands on, ground and one-way platforms alike; the old short ray
## misread the seams where a platform meets ground as ledges.
func _floor_ahead() -> bool:
	var ahead: Transform2D = rb.global_transform.translated(Vector2(absf(dcast.position.x) * 1.8 * float(direction), 0.0))
	return rb.test_move(ahead, Vector2(0, 10))


## What the wall probe last hit (one kept, so probing every frame makes nothing new).
var _wall_hit: KinematicCollision2D = KinematicCollision2D.new()


## A wall in front, within WALL_ROOM of the body: one a head-on bump would turn it at, seen sooner.
func _wall_near() -> bool:
	var lifted: Transform2D = rb.global_transform.translated(Vector2(0, -WALL_LIFT))
	if not rb.test_move(lifted, Vector2(WALL_ROOM * float(direction), 0), _wall_hit):
		return false
	return absf(_wall_hit.get_normal().x) > 0.7 and signf(_wall_hit.get_normal().x) == -float(direction)


## Another wisp in front on the same floor, closer than WISP_GAP.
func _wisp_ahead() -> bool:
	for other: Node in get_tree().get_nodes_in_group(&"wisps"):
		if other == rb:
			continue
		var d: Vector2 = (other as Node2D).global_position - rb.global_position
		if absf(d.y) < 24.0 and d.x * float(direction) > 0.0 and absf(d.x) < WISP_GAP:
			return true
	return false
