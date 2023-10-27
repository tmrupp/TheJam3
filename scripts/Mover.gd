extends Node2D


const SPEED: float = 100.0
const JUMP_VELOCITY: float = -400.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var tilemap: TileMap = $"/root/Main/TileMap" # $\"../TileMap\"
@onready var dcast: RayCast2D = $DownCast
@onready var rb: RigidBody2D = $".."
@onready var sprite: Sprite2D = $"../Sprite2D"
var stunned: bool = false

func turn () -> void:
	direction *= -1
	dcast.position.x *= -1

func wait_to_down () -> void:
	down_wait = true
	await get_tree().create_timer(.1).timeout
	down_wait = false


var direction: int = 1
var down_wait: bool = false
func _physics_process(delta: float) -> void:
	if stunned:
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
	
