extends CharacterBody2D

class_name Player

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var health: Health = $Health
@onready var coins: Coins = $Coins

@onready var corpse_prefab: Resource = preload("res://prefabs/corpse.tscn")

@onready var jump_sfx: AudioStreamPlayer = $JumpSFX
@onready var dash_sfx: AudioStreamPlayer = $DashSFX
@onready var death_sfx: AudioStreamPlayer = $DeathSFX

signal astral_projection_signal
signal elapse_ability_time_signal(time: float)
signal parry
signal died
signal direction_signal(direction: Vector2)

func collect (x: int) -> void:
	coins.modify(x)

func refresh_self (timer: ActionTimer) -> void:
	timer.refresh()
	
var invulnerable: ActionTimer = ActionTimer.new(2, refresh_self)
var knock_back: ActionTimer = ActionTimer.new(0.25, refresh_self)
var knock: Vector2 = Vector2.ZERO

func show_hurt() -> void:
	var r: float = 0
	while r < 1.0:
		await get_tree().create_timer(0.1).timeout
		r += 0.1
		sprite.modulate.g = r
		sprite.modulate.b = r
		
func show_invulnerable() -> void:
	var d: float = 0
	var step: float = .01
	var min_value: float = .4
	var period: float = 0.25
	while invulnerable.is_acting():
		await get_tree().create_timer(step).timeout
		d += step
		sprite.modulate.a = ((sin(d*2*PI/period)+1)/2)*(1-min_value) + (min_value)
#		print("sprite.modulate.a=", sprite.modulate.a, " sin(d*180*period)=", sin(d*180*period), " d=", d)
	sprite.modulate.a = 1

func normal_hurt (damage: int, v: Vector2, _attacker: Node) -> void:
	if not invulnerable.is_acting():
		health.modify_health(damage)
		invulnerable.enable()
		knock_back.enable()
		knock = v
		show_hurt()
		show_invulnerable()
		
func hurt (damage: int, v: Vector2, attacker: Node) -> void:
	hurt_ability.bind(damage, v, attacker).call()
	
var hurt_ability: Callable = normal_hurt

# SPEED: how quickly the player moves
const SPEED: float = 300.0
# JUMP_VELOCITY: how quickly and high the player jumps
const JUMP_VELOCITY: float = -600.0
const JUMP_GRAVITY_FACTOR: float = 0.7
const JUMP_END_CUT_FACTOR: float = 0.5
var jumps: int = 1
var MAX_JUMPS: int = 1


# DASH_SPEED: how quickly the player dashes
# DASH_TIME: how long the dash takes
# Y_DASH_FACTOR: how much the dash is diminished in the Y direction
const DASH_SPEED: float = 600.0
const Y_DASH_FACTOR: float = 1.0
var blink_enabled: bool = false
func dash_end(_timer: ActionTimer) -> void:
	velocity = Vector2.ZERO
	$"DashTrail".stop_trail()
var dash: ActionTimer = ActionTimer.new(0.25, dash_end)

# WALL_JUMP_SPEED: how quickly and high the player jumps
# WALL_JUMP_TIME: how long manual control is overriden 
# (feels better when pushing into wall to jump and then jumps away)
# WALL_JUMP_Y_FACTOR: by how much the y component of a normal jump is factored when wall jumping
const WALL_JUMP_SPEED: float = 400.0
const WALL_JUMP_Y_FACTOR: float = 0.6
var wall_jump: ActionTimer = ActionTimer.new(0.25)

# BUFFER_TIME: how long before hitting the ground can the player 
# can buffer their next jump
var buffer_jump: ActionTimer = ActionTimer.new(0.25)

# COYOTE_TIME: how long after leaving grounded state can the player still input a jump
var coyote: ActionTimer = ActionTimer.new(0.1)

# HANG_TIME: how long at thje apex of a jump does gravity distortion take place
# HANG_FACTOR: by how much is gravity distorted when hanging
# HANG_SPEED_TARGET: which speed to dampen gravity between (symmetrical)
# TODO: still able to climb
const HANG_FACTOR: float = 0.9
const HANG_SPEED_TARGET: float = 40
var hang: ActionTimer = ActionTimer.new(1000)

# CLIMB_SPEED: how fast the player can climb
# TODO: CLIMB_TIME: how long the player can hold onto a wall
# climable: whether or not climbing is enabled
const CLIMB_SPEED: float = 200.0
const CLIMB_TIME: float = 3.0
var climable: bool = false
var climb: ActionTimer = ActionTimer.new(CLIMB_TIME)

# all of the timers (for decrementing)
var timers: Array[ActionTimer] = [dash, wall_jump, buffer_jump, coyote, hang, invulnerable, knock_back, climb]

# whether or not the player has control
var manual_control: bool = true

@onready var tile_map: TileMap = $"../TileMap"
@onready var sprite: Sprite2D = $"Sprite2D"

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# called when an animation is finished
func animation_finished(animation: String) -> void:
	if (animation == "hop"):
		animating_jumping = false

# gets the respawn and saves it
var respawn: Node2D

func set_collision (enabled: bool) -> void:
	# ensures all normal and physics processing are done
	if (enabled):
		await get_tree().physics_frame
		await get_tree().process_frame
	$CollisionShape2D.set_deferred("disabled", not enabled)

func get_collision () -> bool:
	return not $CollisionShape2D.disabled
	
#puts the player back at the spawn location
func reset_position() -> void:
	position = respawn.position
	velocity = Vector2.ZERO	
	knock = Vector2.ZERO
	await get_tree().physics_frame

func setup_corpse (pos: Vector2) -> void:
	var corpse: Node2D = corpse_prefab.instantiate()
	corpse.position = pos
	$"/root/Main".add_child(corpse)
	var sub: int = ceil(coins.coins/2.0)
	corpse.setup(sub)
	collect(-sub)

# kills the player and puts them back at respawn
func die() -> void:
	died.emit()
	var pos: Vector2 = position
	reset_position()
	setup_corpse(pos)
	death_sfx.play()

# does a jump and triggers the jumping animation
var animating_jumping: bool = false
var jumping: bool = false
var jump_held: bool = false
func jump(factor: float=1.0) -> void:
	velocity.y = JUMP_VELOCITY * factor
	# animation_player.play("hop", -1, 4)
	# animation_player.queue("falling")
	jumping = true

	animating_jumping = true
	
	$"ParticleController".Jump()
	jump_sfx.play()

# does a dash moving rapidly in one direction
func do_dash(dash_direction: Vector2) -> void:
	velocity = dash_direction * DASH_SPEED
	velocity.y *= Y_DASH_FACTOR
	$"DashTrail".make_trail()
	dash_sfx.play()
var dash_ability: Callable = do_dash

func drop () -> void:
	position.y += 1
	
func do_wall_jump (wall_normal: Vector2) -> void:
	coyote.end()
	jump(WALL_JUMP_Y_FACTOR)
	velocity.x = wall_normal.x * WALL_JUMP_SPEED
	wall_jump.enable(true)
	

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("Parry"):
		parry.emit()
	
	var walled: bool = false
	var wall_normal: Vector2

	# get input from the user to establish direction
	var direction: Vector2 = Vector2.RIGHT * Input.get_axis("Left", "Right") + Vector2.DOWN * Input.get_axis("Up", "Down")
	
	direction_signal.emit(direction)
	
	# makes the sprite face which direction the user is pointing towards
	if direction.x != 0:
		if direction.x > 0:
			sprite.scale.x = abs(sprite.scale.x)
		else:
			sprite.scale.x = -abs(sprite.scale.x)

	# checks all current collisions and checks to see if colliding with a wall,
	# wall normal must be in the x direction (an up-down wall) to be considered walled for wall jumping
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if (col.get_normal().x != 0):
			walled = true
			wall_normal = col.get_normal()
	
	if climable and climb.actable() and jump_held and walled and wall_normal.x:
		climb.enable()

	# Add the gravity.
	# in the air
	if not is_on_floor():
		coyote.enable()
		
		if climb.is_acting():
			if not walled:
				#climb.end()
				climb.pause()
			else:
				velocity.y = direction.y * SPEED
		else:
			if (not dash.is_acting()):
				var factor: float = 1.0 if not hang.is_acting() else HANG_FACTOR
				velocity.y += gravity * factor * delta
				
			# damp once velocity hits a certain amount
			if (velocity.y < 0 and velocity.y > -HANG_SPEED_TARGET):
				jumping = false
				hang.enable()
			# undamp once velocity exitys symmetrical range
			if (velocity.y > 0 and velocity.y > HANG_SPEED_TARGET):
				hang.end()
			
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
		climb.refresh()
		
	# cannot dash then exploit coyote jump
	if dash.is_acting():
		coyote.end()

	# Handle Jump.
	if Input.is_action_just_pressed("Jump"):
		jump_held = true
		# normal jump, stop coyoting on a jump
		if (is_on_floor() and direction.y > 0):
			drop()
		elif (is_on_floor() or coyote.is_acting() or jumps > 0):
			coyote.end()
			jump()
			jumps -= 1
		# wall jump, damped normal jump and move away from wall
		# takes away manual control
		elif (walled and not is_on_floor()):
			do_wall_jump(wall_normal)
		else:
		# if not walled or grounded, buffer a jump
			buffer_jump.enable(true)

	if Input.is_action_just_released("Jump"):
		jump_held = false
		if climb.is_acting():
			if (direction.x):
				do_wall_jump(wall_normal)
			#climb.end()
			climb.pause()
			
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
	for timer: ActionTimer in timers:
		timer.elapse(delta)
	elapse_ability_time_signal.emit(delta)

	# this uses veolcity and calculates collisions for next frame
	move_and_slide()
