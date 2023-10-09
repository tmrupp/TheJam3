extends CharacterBody2D

@onready var collider = $CollisionShape2D
@onready var health = $Health
@onready var coins = $Coins

@onready var corpse_prefab = preload("res://prefabs/corpse.tscn") 

signal astral_projection_signal
signal elapse_ability_time_signal(time)
signal parry
signal died
signal direction_signal(direction)

func collect (x):
	coins.modify(x)

func refresh_self (timer):
	timer.refresh()
	
var invulnerable = ActionTimer.new(2, refresh_self)
var knock_back = ActionTimer.new(0.25, refresh_self)
var knock = Vector2.ZERO

func show_hurt():
	var r = 0
	while r < 1.0:
		await get_tree().create_timer(0.1).timeout
		r += 0.1
		sprite.modulate.g = r
		sprite.modulate.b = r
		
func show_invulnerable():
	var d = 0
	var step = .01
	var min_value = .4
	var period = 0.25
	while invulnerable.is_acting():
		await get_tree().create_timer(step).timeout
		d += step
		sprite.modulate.a = ((sin(d*2*PI/period)+1)/2)*(1-min_value) + (min_value)
#		print("sprite.modulate.a=", sprite.modulate.a, " sin(d*180*period)=", sin(d*180*period), " d=", d)
	sprite.modulate.a = 1

func normal_hurt (damage, v, _attacker):
	if not invulnerable.is_acting():
		health.modify_health(damage)
		invulnerable.enable()
		knock_back.enable()
		knock = v
		show_hurt()
		show_invulnerable()
		
func hurt (damage, v, attacker):
	hurt_ability.bind(damage, v, attacker).call()
	
var hurt_ability = normal_hurt

# SPEED: how quickly the player moves
const SPEED = 300.0
# JUMP_VELOCITY: how quickly and high the player jumps
const JUMP_VELOCITY = -600.0
const JUMP_GRAVITY_FACTOR = 0.7
const JUMP_END_CUT_FACTOR = 0.5
var jumps = 1
var MAX_JUMPS = 1


# DASH_SPEED: how quickly the player dashes
# DASH_TIME: how long the dash takes
# Y_DASH_FACTOR: how much the dash is diminished in the Y direction
const DASH_SPEED = 600.0
const Y_DASH_FACTOR = 1.0
var blink_enabled = false
func dash_end(_timer):
	velocity = Vector2.ZERO
	$"DashTrail".stop_trail()
var dash = ActionTimer.new(0.25, dash_end)

# WALL_JUMP_SPEED: how quickly and high the player jumps
# WALL_JUMP_TIME: how long manual control is overriden 
# (feels better when pushing into wall to jump and then jumps away)
# WALL_JUMP_Y_FACTOR: by how much the y component of a normal jump is factored when wall jumping
const WALL_JUMP_SPEED = 400.0
const WALL_JUMP_Y_FACTOR = 0.6
var wall_jump = ActionTimer.new(0.25)

# BUFFER_TIME: how long before hitting the ground can the player 
# can buffer their next jump
var buffer_jump = ActionTimer.new(0.25)

# COYOTE_TIME: how long after leaving grounded state can the player still input a jump
var coyote = ActionTimer.new(0.1)

# HANG_TIME: how long at thje apex of a jump does gravity distortion take place
# HANG_FACTOR: by how much is gravity distorted when hanging
# HANG_SPEED_TARGET: which speed to dampen gravity between (symmetrical)
const HANG_FACTOR = 0.9
const HANG_SPEED_TARGET = 40
var hang = ActionTimer.new(1000)

# all of the timers (for decrementing)
var timers = [dash, wall_jump, buffer_jump, coyote, hang, invulnerable, knock_back]

# whether or not the player has control
var manual_control = true

@onready var tile_map = $"../TileMap"
@onready var sprite = $"Sprite2D"

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# called when an animation is finished
func animation_finished(animation):
	if (animation == "hop"):
		animating_jumping = false
	pass

# gets the respawn and saves it
var respawn

#puts the player back at the spawn location
func reset_position():
	position = respawn.position
	velocity = Vector2.ZERO	
	knock = Vector2.ZERO
	await get_tree().physics_frame

func setup_corpse (pos):
	var corpse = corpse_prefab.instantiate()
	corpse.position = pos
	$"/root/Main".add_child(corpse)
	var sub = ceil(coins.coins/2.0)
	corpse.setup(sub)
	collect(-sub)

# kills the player and puts them back at respawn
func die():
	died.emit()
	var pos = position
	reset_position()
	setup_corpse(pos)

# does a jump and triggers the jumping animation
var animating_jumping = false
var jumping = false
func jump(factor=1.0):
	velocity.y = JUMP_VELOCITY * factor
	# animation_player.play("hop", -1, 4)
	# animation_player.queue("falling")
	jumping = true

	animating_jumping = true
	
	$"ParticleController".Jump()

# does a dash moving rapidly in one direction
func do_dash(dash_direction):
	velocity = dash_direction * DASH_SPEED
	velocity.y *= Y_DASH_FACTOR
	$"DashTrail".make_trail()
var dash_ability = do_dash

func _physics_process(delta):
	if Input.is_action_just_pressed("AstralProjection"):
		astral_projection_signal.emit()
		
	if Input.is_action_just_pressed("Parry"):
		parry.emit()
	
	var walled = false
	var wall_normal

	# get input from the user to establish direction
	var direction = Vector2.RIGHT * Input.get_axis("Left", "Right") + Vector2.DOWN * Input.get_axis("Up", "Down")
	
	direction_signal.emit(direction)
	
	# makes the sprite face which direction the user is pointing towards
	if direction.x != 0:
		if direction.x > 0:
			sprite.scale.x = abs(sprite.scale.x)
		else:
			sprite.scale.x = -abs(sprite.scale.x)

	# checks all current collisions and checks to see if colliding with a wall,
	# wall normal must be in the x direction (an up-down wall) to be considered walled for wall jumping
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
			jumping = false
			hang.enable()
		# undamp once velocity exitys symmetrical range
		if (velocity.y > 0 and velocity.y > HANG_SPEED_TARGET):
			hang.end()

		if (velocity.y > 0):
			# animation_player.play("falling")
			pass
	else: # on the ground
		animating_jumping = false
		jumping = false
		jumps = MAX_JUMPS
		if direction.x != 0:
			# if user is inputing a direction animate "moving"
			# animation_player.play("scuttle")
			pass
		else:
			# if on the ground stop falling and play idle
			# if animation_player.current_animation == "falling":
				# animation_player.stop()
#			print("here? animation=", animation_player.assigned_animation)
			# animation_player.play("idle")
			pass
		
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
		if (is_on_floor() or coyote.is_acting() or jumps > 0):
			coyote.end()
			jump()
			jumps -= 1
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

	if Input.is_action_just_released("Jump"):
		if jumping:
			velocity.y *= JUMP_END_CUT_FACTOR
		jumping = false
		pass
	
	# no manual control while dashing or wall jumping (prevents jumping over and over on a wall)
	manual_control = not (dash.is_acting() or wall_jump.is_acting() or knock_back.is_acting())

	# if has manual control set the velocity correctly
	if (manual_control):
		if direction:
			velocity.x = direction.x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED/10)
			
	if knock != Vector2.ZERO:
		velocity = knock
		knock = Vector2.ZERO
		
	# get dash input and dash if necessary
	if Input.is_action_just_pressed("Dash"):
		if not dash.acted:
			dash.enable()
			dash_ability.bind(direction).call()
	
	# elapse the time in all timers
	for timer in timers:
		timer.elapse(delta)
	elapse_ability_time_signal.emit(delta)

	# this uses veolcity and calculates collisions for next frame
	move_and_slide()
