extends RigidBody2D


const SPEED = 100.0
const JUMP_VELOCITY = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite = $Sprite2D
@onready var tilemap = $"/root/Main/TileMap" # $\"../TileMap\"
@onready var dcast = $DownCast
@onready var scast = $SideCast

func setup (_map_info, _v):
	pass

var direction = 1
func _physics_process(delta):
	
	if not dcast.is_colliding() or scast.is_colliding():
		direction *= -1
		
		dcast.position *= -1
		
		scast.position.x *= -1
		scast.target_position.x *= -1
		
	if direction != 0:
		if direction > 0:
			sprite.scale.x = abs(sprite.scale.x)
		else:
			sprite.scale.x = -abs(sprite.scale.x)
			
	var collision = move_and_collide(Vector2(SPEED, 0)*delta*direction)
