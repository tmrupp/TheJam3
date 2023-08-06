extends CharacterBody2D

# SPEED: how quickly the player moves
const SPEED = 300.0
# JUMP_VELOCITY: how quickly and high the player jumps
const JUMP_VELOCITY = -400.0

class ActionTimer:
	var MAX_TIME = 1.0
	var acting = 0.0
	var acted = false

	func _init(_MAX_TIME):
		MAX_TIME = _MAX_TIME

	func enable(force=false):
		if force or (acting <= 0.0 and not acted):
			acting = MAX_TIME
			acted = true

	func elapse(t):
		if acting > 0:
			acting -= t

	func end():
		acting = 0.0

	func refresh():
		acted = false

	func is_acting():
		return acting > 0

# DASH_SPEED: how quickly the player dashes
# DASH_TIME: how long the dash takes
const DASH_SPEED = 600.0
var dash_direction
var dash = ActionTimer.new(0.25)

# WALL_JUMP_SPEED: how quickly and high the player jumps
# WALL_JUMP_TIME: how long manual control is overriden 
# (feels better when pushing into wall to jump and then jumps away)
# WALL_JUMP_Y_FACTOR: by how much the y component of a normal jump is factored when wall jumping
const WALL_JUMP_SPEED = 200.0
const WALL_JUMP_Y_FACTOR = 0.75
var wall_jump = ActionTimer.new(0.25)

# BUFFER_TIME: how long before hitting the ground can the player 
# can buffer their next jump
var buffer_jump = ActionTimer.new(0.25)

# COYOTE_TIME: how long after leaving grounded state can the player still input a jump
var coyote = ActionTimer.new(0.1)

# HANG_TIME: how long at thje apex of a jump does gravity distortion take place
# HANG_FACTOR: by how much is gravity distorted when hanging
const HANG_FACTOR = 0.5
var hang = ActionTimer.new(1)

var timers = [dash, wall_jump, buffer_jump, coyote, hang]

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
@onready var sprite = $"big bossanova"
@onready var animation_player = $"big bossanova/AnimationPlayer"

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func animation_finished(animation):
	# print("finished, ", animation)
	if (animation == "hop"):
		animating_jumping = false
	pass

var respawn
func _ready():
	respawn = $"../Respawn"
	animation_player.connect("animation_started", animation_finished)

func die():
	position = respawn.position
	velocity = Vector2.ZERO	

var animating_jumping = false
func jump(factor=1.0):
	velocity.y = JUMP_VELOCITY * factor
	animation_player.play("hop", -1, 4)
	animation_player.queue("falling")

	animating_jumping = true
	
func do_dash():
	velocity = dash_direction * DASH_SPEED
	
func _physics_process(delta):
	var walled = false
	var wall_normal

	var direction = Vector2.RIGHT * Input.get_axis("Left", "Right") + Vector2.DOWN * Input.get_axis("Up", "Down")
	
	if direction.x != 0:
		if direction.x > 0:
			sprite.scale.x = abs(sprite.scale.x)
		else:
			sprite.scale.x = -abs(sprite.scale.x)

	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if (col.get_normal().x != 0):
			walled = true
			wall_normal = col.get_normal()

	# Add the gravity.
	if not is_on_floor():
		coyote.enable()
		
		if (not dash.is_acting()):
			var factor = 1.0 if not hang.is_acting() else HANG_FACTOR
			velocity.y += gravity * factor * delta
		
#		print("abs(velocity.y)=", abs(velocity.y))
		if (abs(velocity.y) <= 100):
			hang.enable()

		if (not animating_jumping):
			animation_player.play("falling")
	else:
		animating_jumping = false
		if direction.x != 0:
			animation_player.play("scuttle")
		else:
			if animation_player.current_animation == "falling":
				animation_player.stop()
#			print("here? animation=", animation_player.assigned_animation)
			animation_player.play("idle")

		if (buffer_jump.is_acting()):
			buffer_jump.end()
			jump()

		dash.refresh()
		coyote.refresh()
		hang.refresh()
		
	
	if dash.is_acting():
		coyote.end()

	# Handle Jump.
	if Input.is_action_just_pressed("Jump"):
		if (is_on_floor() or coyote.is_acting()):
			coyote.end()
			jump()
		elif (walled and not is_on_floor()):
			coyote.end()
			jump(WALL_JUMP_Y_FACTOR)
			velocity.x = wall_normal.x * WALL_JUMP_SPEED
			wall_jump.enable(true)
		else:
			buffer_jump.enable(true)
	
	print("wall_jump=", wall_jump.is_acting())
	manual_control = not (dash.is_acting() or wall_jump.is_acting())

	if (manual_control):
		if direction:
			velocity.x = direction.x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if Input.is_action_just_pressed("Dash"):
		if not dash.acted:
			dash.enable()
			dash_direction = direction
			do_dash()

	for timer in timers:
		timer.elapse(delta)

	move_and_slide()
