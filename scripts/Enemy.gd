extends RigidBody2D


const SPEED = 100.0
const JUMP_VELOCITY = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite = $Sprite2D
@onready var tilemap = $"/root/Main/TileMap" # $\"../TileMap\"
@onready var dcast = $DownCast

func setup (_map_info, _v):
	pass

func turn ():
	direction *= -1
	dcast.position.x *= -1

func wait_to_down ():
	down_wait = true
	await get_tree().create_timer(.1).timeout
	down_wait = false

var direction = 1
var down_wait = false
func _physics_process(delta):
	var collision = move_and_collide(Vector2(SPEED, 0)*delta*direction)
	
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
	
