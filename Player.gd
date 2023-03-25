extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0


const DASH_SPEED = 600.0
const DASH_TIME = 0.25
var has_dash = true
var dashing = 0.0
var dash_direction

const WALL_JUMP_SPEED = 200.0
const WALL_JUMP_TIME = 0.25
var wall_jumping = 0.0

const BUFFER_TIME = 0.25
var buffered_jump = 0.0

var manual_control = true

enum State {
	# grounded
	IDLE,
	RUNNING,
	
	# airborn
	JUMPING,
	DASHING,
}

@onready var tile_map = $"../TileMap"

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func refresh_dash ():
	has_dash = true
	
var respawn
func _ready():
	respawn = $"../Respawn"

func die():
	print("i died")
	position = respawn.position
	velocity = Vector2.ZERO
	
func _physics_process(delta):
	if position.y > 300:
		die()

	var walled = false
	var wall_normal
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if (col.get_normal().x != 0):
			walled = true
			wall_normal = col.get_normal()


	# Add the gravity.
	if not is_on_floor():
		if (dashing <= 0):
			velocity.y += gravity * delta
	else:
		if (buffered_jump > 0.0):
			print(" buffered_jump=",buffered_jump)
			buffered_jump = 0.0
			velocity.y = JUMP_VELOCITY	
		refresh_dash()

	# Handle Jump.
	if Input.is_action_just_pressed("Jump"):
		if (is_on_floor() or walled):
			velocity.y = JUMP_VELOCITY	
			if (walled and not is_on_floor()):
				velocity.x = wall_normal.x * WALL_JUMP_SPEED
				wall_jumping = WALL_JUMP_TIME
		else:
			buffered_jump = BUFFER_TIME
			

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Vector2.RIGHT * Input.get_axis("Left", "Right") + Vector2.DOWN * Input.get_axis("Up", "Down")
	
	manual_control = not (dashing > 0 or wall_jumping > 0)

	if (manual_control):
		if direction:
			velocity.x = direction.x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
	
	if Input.is_action_just_pressed("Dash") and has_dash:
		has_dash = false
		dashing = DASH_TIME
		dash_direction = direction
		velocity = dash_direction * DASH_SPEED
	
	if dashing > 0:
		dashing -= delta
		if dashing <= 0:
			velocity = Vector2.ZERO

	if wall_jumping > 0:
		wall_jumping -= delta
		
	if buffered_jump > 0:
		buffered_jump -= delta

	move_and_slide()
