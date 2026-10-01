extends Node2D


const SPEED: float = 60.0
const JUMP_VELOCITY: float = -400.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var tilemap: TileMap = $"/root/Main/TileMap" # $\"../TileMap\"
@onready var dcast: RayCast2D = $DownCast
@onready var rb: RigidBody2D = $".."
@onready var sprite: Sprite2D = $"../Sprite2D"
var stunned: bool = false
## Turning round: the wisp holds still for TURN_TIME while its art loops up and over (RisoProp).
const TURN_TIME: float = 0.9
var turn_left: float = 0.0

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
	if stunned:
		return
	if turn_left > 0.0:
		turn_left = maxf(0.0, turn_left - delta)
		return

	var collision: KinematicCollision2D = rb.move_and_collide(Vector2(SPEED, 0)*delta*direction)
	
	if collision and collision.get_normal().x != 0:
		turn()
	elif not dcast.is_colliding():
		if not down_wait:
			turn()
			wait_to_down()
		
	if direction != 0:
		if direction > 0:
			sprite.scale.x = abs(sprite.scale.x)
		else:
			sprite.scale.x = -abs(sprite.scale.x)
	
