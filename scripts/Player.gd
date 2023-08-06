extends CharacterBody2D

# SPEED: how quickly the player moves
const SPEED = 300.0
# JUMP_VELOCITY: how quickly and high the player jumps
const JUMP_VELOCITY = -400.0

# this class is the generalized behavior of a time-based action
# deals with actions that take a certain duration and can be refreshed
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
# Y_DASH_FACTOR: how much the dash is diminished in the Y direction
const DASH_SPEED = 600.0
const Y_DASH_FACTOR = 0.6
var dash = ActionTimer.new(0.25)

# WALL_JUMP_SPEED: how quickly and high the player jumps
# WALL_JUMP_TIME: how long manual control is overriden 
# (feels better when pushing into wall to jump and then jumps away)
# WALL_JUMP_Y_FACTOR: by how much the y component of a normal jump is factored when wall jumping
const WALL_JUMP_SPEED = 300.0
const WALL_JUMP_Y_FACTOR = 0.5
var wall_jump = ActionTimer.new(0.25)

# BUFFER_TIME: how long before hitting the ground can the player 
# can buffer their next jump
var buffer_jump = ActionTimer.new(0.25)

# COYOTE_TIME: how long after leaving grounded state can the player still input a jump
var coyote = ActionTimer.new(0.1)

# HANG_TIME: how long at thje apex of a jump does gravity distortion take place
# HANG_FACTOR: by how much is gravity distorted when hanging
# HANG_SPEED_TARGET: which speed to dampen gravity between (symmetrical)
const HANG_FACTOR = 0.5
const HANG_SPEED_TARGET = 100
var hang = ActionTimer.new(1000)

# all of the timers (for decrementing)
var timers = [dash, wall_jump, buffer_jump, coyote, hang]

# whether or not the player has control
var manual_control = true

@onready var tile_map = $"../TileMap"
@onready var sprite = $"big bossanova"
@onready var animation_player = $"big bossanova/AnimationPlayer"

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# called when an animation is finished
func animation_finished(animation):
	if (animation == "hop"):
		animating_jumping = false
	pass

# gets the respawn and saves it
var respawn
func _ready():
	respawn = $"../Respawn"
	animation_player.connect("animation_started", animation_finished)

# kills the player and puts them back at respawn
func die():
	position = respawn.position
	velocity = Vector2.ZERO	

# does a jump and triggers the jumping animation
var animating_jumping = false
func jump(factor=1.0):
	velocity.y = JUMP_VELOCITY * factor
	animation_player.play("hop", -1, 4)
	animation_player.queue("falling")

	animating_jumping = true

# does a dash moving rapidly in one direction
func do_dash(dash_direction):
	velocity = dash_direction * DASH_SPEED
	velocity.y *= Y_DASH_FACTOR
	
func _physics_process(delta):
	var walled = false
	var wall_normal

	# get input from the user to establish direction
	var direction = Vector2.RIGHT * Input.get_axis("Left", "Right") + Vector2.DOWN * Input.get_axis("Up", "Down")
	
	# makes the sprite face which direction the user is pointing towards
	if direction.x != 0:
		if direction.x > 0:
			sprite.scale.x = abs(sprite.scale.x)
		else:
			sprite.scale.x = -abs(sprite.scale.x)

	# checks all current collisions and checks to see if colliding with a wall,
	# wall normal must be in the x direction (up-down) to be considered walled for wall jumping
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if (col.get_normal().x != 0):
			walled = true
			wall_normal = col.get_normal()

	# Add the gravity.
	# in the air
	if not is_on_floor():
		coyote.enable()
		
		if (not dash.is_acting()):
			var factor = 1.0 if not hang.is_acting() else HANG_FACTOR
			velocity.y += gravity * factor * delta
		
		# damp once velocity hits a certain amount
		if (velocity.y < 0 and velocity.y > -HANG_SPEED_TARGET):
			hang.enable()
		# undamp once velocity exitys symmetrical range
		if (velocity.y > 0 and velocity.y > HANG_SPEED_TARGET):
			hang.end()

		if (not animating_jumping):
			animation_player.play("falling")
	else: # on the ground
		animating_jumping = false
		if direction.x != 0:
			# if user is inputing a direction animate "moving"
			animation_player.play("scuttle")
		else:
			# if on the ground stop falling and play idle
			if animation_player.current_animation == "falling":
				animation_player.stop()
#			print("here? animation=", animation_player.assigned_animation)
			animation_player.play("idle")
		
		# if a jump was buffered, jump
		if (buffer_jump.is_acting()):
			buffer_jump.end()
			jump()

		# refresh grounded actions
		dash.refresh()
		coyote.refresh()
		hang.refresh()
		
	# cannot dash then exploit coyote jump
	if dash.is_acting():
		coyote.end()

	# Handle Jump.
	if Input.is_action_just_pressed("Jump"):
		# normal jump, stop coyoting on a jump
		if (is_on_floor() or coyote.is_acting()):
			coyote.end()
			jump()
		# wall jump, damped normal jump and move away from wall
		# takes away manual control
		elif (walled and not is_on_floor()):
			coyote.end()
			jump(WALL_JUMP_Y_FACTOR)
			velocity.x = wall_normal.x * WALL_JUMP_SPEED
			wall_jump.enable(true)
		else:
		# if not walled or grounded, buffer a jump
			buffer_jump.enable(true)
	
	# no manual control while dashing or wall jumping (prevents jumping over and over on a wall)
	manual_control = not (dash.is_acting() or wall_jump.is_acting())

	# if has manual control set the velocity correctly
	if (manual_control):
		if direction:
			velocity.x = direction.x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# get dash input and dash if necessary
	if Input.is_action_just_pressed("Dash"):
		if not dash.acted:
			dash.enable()
			do_dash(direction)
	
	# elapse the time in all timers
	for timer in timers:
		timer.elapse(delta)

	# this uses veolcity and calculates collisions for next frame
	move_and_slide()
