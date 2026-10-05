extends CharacterBody2D

class_name Player

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var health: Health = $Health
@onready var coins: Coins = $Coins


@onready var jump_sfx: AudioStreamPlayer = $JumpSFX
@onready var dash_sfx: AudioStreamPlayer = $DashSFX
@onready var death_sfx: AudioStreamPlayer = $DeathSFX

signal astral_projection_signal
signal elapse_ability_time_signal(time: float)
signal parry
signal died
signal visual_event(kind: StringName, world_position: Vector2)
signal corpse_created(corpse: Node2D)
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
		visual_event.emit(&"hurt", global_position)
		pulse_fourier(0.9)
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
## Running speed now: SPEED raised by the speed perk (see Abilities).
var run_speed: float = SPEED
# JUMP_VELOCITY: how quickly and high the player jumps
const JUMP_VELOCITY: float = -600.0
const JUMP_GRAVITY_FACTOR: float = 0.7
const JUMP_END_CUT_FACTOR: float = 0.5
var jumps: int = 1
var MAX_JUMPS: int = 1
## Floating on the levitate spell: no gravity, holding height (see Levitate).
var levitating: bool = false
## Projected (see AstralProjection): no gravity and nothing solid in the way. The projection
## floats wherever the stick points at PHASE_SPEED, kept inside the level.
var phasing: bool = false
const PHASE_SPEED: float = 360.0
const LEVITATE_DRIFT: float = 140.0
## Ability tiers learned at shrines (see Abilities).
var tiers: Dictionary = Abilities.start_tiers()
## Seconds of drowsiness left (sleep fog, see SleepFog): while drowsy the spell is off.
var drowsy: float = 0.0
const DROWSY_LINGER: float = 0.25


func is_drowsy() -> bool:
	return drowsy > 0.0


## In sleep fog: drowsy for a moment more. Becoming drowsy ends whatever spell is running.
func make_drowsy() -> void:
	if drowsy <= 0.0:
		levitating = false
		var projection: Node = get_node_or_null("AstralProjection")
		if projection != null and bool(projection.call("projecting")):
			projection.call("end_projection", projection.get("projection_timer"))
		var aware: Node = get_node_or_null("Awareness")
		if aware != null:
			aware.set("sensing", 0.0)
	drowsy = DROWSY_LINGER

func _enter_tree() -> void:
	Abilities.ensure_input()


# DASH_SPEED: how quickly the player dashes
# DASH_TIME: how long the dash takes
# Y_DASH_FACTOR: how much the dash is diminished in the Y direction
const DASH_SPEED: float = 750.0
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
## Falling while pressed against a wall (holding toward it) slides down it no faster than this.
const WALL_SLIDE_SPEED: float = 160.0
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
const CLIMB_TIME: float = 1.0
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
	# The last lantern lit may be in another level: MapInfo loads it and places the player.
	if MapInfo.instance != null and MapInfo.instance.respawn_elsewhere():
		MapInfo.instance.respawn_in_other_level()
		velocity = Vector2.ZERO
		knock = Vector2.ZERO
		return
	position = respawn.position
	reset_fourier_motion()
	velocity = Vector2.ZERO	
	knock = Vector2.ZERO
	await get_tree().physics_frame

func reset_fourier_motion() -> void:
	var visual: Node = get_node_or_null("FourierVisual")
	if visual != null:
		visual.reset_motion()
		visual.pulse(0.7)

func pulse_fourier(strength: float) -> void:
	var visual: Node = get_node_or_null("FourierVisual")
	if visual != null:
		visual.pulse(strength)

# kills the player and puts them back at respawn
func die() -> void:
	visual_event.emit(&"death", global_position)
	died.emit()
	var pos: Vector2 = position
	death_sfx.play()
	# MapInfo burns the lit lantern and drops a ghost, or ends an unprotected run.
	if MapInfo.instance != null:
		MapInfo.instance.player_died(pos)
	else:
		health.health = 1
		health.display_health()
		reset_position()

# does a jump and triggers the jumping animation
var animating_jumping: bool = false
var jumping: bool = false
var jump_held: bool = false
func jump(factor: float=1.0) -> void:
	visual_event.emit(&"jump", global_position)
	pulse_fourier(0.55)
	velocity.y = JUMP_VELOCITY * factor
	# animation_player.play("hop", -1, 4)
	# animation_player.queue("falling")
	jumping = true

	animating_jumping = true
	
	$"ParticleController".Jump()
	jump_sfx.play()

# does a dash moving rapidly in one direction
func do_dash(dash_direction: Vector2) -> void:
	visual_event.emit(&"dash", global_position)
	velocity = dash_direction * DASH_SPEED
	velocity.y *= Y_DASH_FACTOR
	$"DashTrail".make_trail()
	dash_sfx.play()
var dash_ability: Callable = do_dash

## Drop through the one-way ledge underfoot, static or moving: it is ignored for a moment. (A
## one-pixel nudge alone only cleared the scaled static ledges; a moving platform's unscaled
## one-way margin caught the wizard straight back.)
func drop () -> void:
	var under: Array[CollisionObject2D] = []
	for i: int in range(get_slide_collision_count()):
		var hit: KinematicCollision2D = get_slide_collision(i)
		var body: CollisionObject2D = hit.get_collider() as CollisionObject2D
		if body != null and hit.get_normal().y < -0.5:
			under.append(body)
	# A lift going down can have moved off the feet since the last step (no collision this frame):
	# look just under them too.
	var below: KinematicCollision2D = move_and_collide(Vector2(0, 12), true)
	if below != null and below.get_normal().y < -0.5 and below.get_collider() is CollisionObject2D:
		under.append(below.get_collider() as CollisionObject2D)
	for body: CollisionObject2D in under:
		if _one_way(body):
			add_collision_exception_with(body)
			get_tree().create_timer(0.3).timeout.connect(func() -> void:
				if is_instance_valid(body):
					remove_collision_exception_with(body))
	position.y += 1

func _one_way (body: CollisionObject2D) -> bool:
	for child: Node in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).one_way_collision:
			return true
	return false
	
func do_wall_jump (wall_normal: Vector2) -> void:
	coyote.end()
	jumps = mini(jumps, MAX_JUMPS - 1)
	jump(WALL_JUMP_Y_FACTOR)
	velocity.x = wall_normal.x * WALL_JUMP_SPEED
	wall_jump.enable(true)
	

func _physics_process(delta: float) -> void:
	drowsy = maxf(0.0, drowsy - delta)
	# The Spell button uses whatever spell is in the slot.
	if Input.is_action_just_pressed(Abilities.SPELL_ACTION):
		Abilities.cast(self)
	if phasing:
		_phase(delta)
		return

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
		if climb.is_acting():
			if not walled:
				#climb.end()
				climb.pause()
			else:
				velocity.y = direction.y * SPEED
		else:
			if levitating:
				# Hold the height the float began at; from tier II the stick drifts it up and down.
				var lev: Levitate = get_node_or_null("Levitate") as Levitate
				velocity.y = direction.y * LEVITATE_DRIFT if lev != null and lev.drift else 0.0
			elif (not dash.is_acting()):
				var factor: float = 1.0 if not hang.is_acting() else HANG_FACTOR
				velocity.y += gravity * factor * delta
				# Sliding down a wall while holding toward it: the fall is slowed.
				if walled and direction.x * wall_normal.x < 0.0 and velocity.y > WALL_SLIDE_SPEED:
					velocity.y = WALL_SLIDE_SPEED
				
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
		
		# Arm coyote time only while grounded. Taking a jump spends it; falling cannot rearm it.
		dash.refresh()
		coyote.enable(true)
		hang.refresh()
		climb.refresh()

		# if a jump was buffered, jump
		if (buffer_jump.is_acting()):
			buffer_jump.end()
			coyote.end()
			jump()
			jumps -= 1
		
	# cannot dash then exploit coyote jump
	if dash.is_acting():
		coyote.end()
	# Once the ledge grace period ends, only learned air jumps remain. The ground jump cannot
	# be saved indefinitely by walking off instead of jumping.
	if not is_on_floor() and not coyote.is_acting():
		jumps = mini(jumps, MAX_JUMPS - 1)

	# Handle Jump.
	if Input.is_action_just_pressed("Jump"):
		jump_held = true
		# normal jump, stop coyoting on a jump
		if (is_on_floor() and direction.y > 0):
			coyote.end()
			jumps = mini(jumps, MAX_JUMPS - 1)
			drop()
		elif (is_on_floor() or coyote.is_acting()):
			coyote.end()
			jump()
			jumps -= 1
		# wall jump, damped normal jump and move away from wall
		# takes away manual control; on a wall it comes before an air jump, which is kept
		elif (walled and not is_on_floor()):
			do_wall_jump(wall_normal)
		elif jumps > 0:
			jump()
			jumps -= 1
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
			velocity.x = direction.x * run_speed
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED/10)
			
	if knock != Vector2.ZERO:
		velocity = knock
		knock = Vector2.ZERO
		
	# get dash input and dash if necessary
	if Input.is_action_just_pressed("Dash"):
		if not dash.acted:
			# Forced, so a dash given back mid-dash (by a moon) starts a fresh one: full length,
			# and spent again, rather than only turning the one still running.
			dash.enable(true)
			dash_ability.bind(direction).call()
	
	# elapse the time in all timers
	for timer: ActionTimer in timers:
		timer.elapse(delta)
	elapse_ability_time_signal.emit(delta)

	# The wind (sky levels): an updraft eases the rise toward its speed; a crosswind carries the
	# wizard along (a move of its own, so it never builds up in the velocity) and holds them up.
	# Up/down moves within that gust; steering out through its bottom restores normal falling.
	var push: Vector2 = Wind.push_at(get_tree(), global_position)
	if push.y < 0.0 and not dash.is_acting():
		velocity.y = move_toward(velocity.y, push.y, Wind.LIFT_ACCEL * delta)
		jumping = false
	if push.x != 0.0:
		if not is_on_floor() and velocity.y > Wind.GLIDE:
			velocity.y = Wind.GLIDE
		move_and_collide(Vector2(push.x * delta, 0.0))
		if manual_control and not is_on_floor() and direction.y != 0.0:
			# Separate moves preserve sideways carry when vertical steering meets a floor or ceiling.
			# Steering is displacement too: releasing the stick leaves no vertical drift behind.
			move_and_collide(Vector2(0.0, direction.y * Wind.STEER_SPEED * delta))

	# this uses veolcity and calculates collisions for next frame
	move_and_slide()
	_footing()


## Sky levels: the last rock the wizard stood on (`footing`, in the level `footing_at`). Falling out
## of the bottom of the level (FALL_MARGIN below its last row) costs a heart and puts them back
## there (fall_back).
const FALL_MARGIN: float = 200.0
var footing: Vector2 = Vector2.ZERO
var footing_at: Vector2i = Vector2i(-99999, -99999)


func _footing() -> void:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null or info.travelling or not info.here.sky():
		return
	if is_on_floor():
		for i: int in range(get_slide_collision_count()):
			var hit: KinematicCollision2D = get_slide_collision(i)
			if hit.get_normal().y < -0.5 and hit.get_collider() is TileMap:
				footing = global_position
				footing_at = info.coord
	if global_position.y > info.level_rect().end.y + FALL_MARGIN:
		fall_back()


## Out of the bottom of a sky level: back on the last rock stood on (or at the way in, if none in
## this level yet), a heart the poorer.
func fall_back() -> void:
	var info: MapInfo = MapInfo.instance
	velocity = Vector2.ZERO
	knock = Vector2.ZERO
	if info != null and footing_at == info.coord:
		global_position = footing
	else:
		position = respawn.position
	visual_event.emit(&"hurt", global_position)
	invulnerable.enable()
	show_invulnerable()
	health.modify_health(-1)


## Drifting as an astral projection (see phasing): steered on both axes, through anything solid,
## but not out of the level.
func _phase(delta: float) -> void:
	var steer: Vector2 = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Up", "Down")).limit_length(1.0)
	direction_signal.emit(steer)
	if steer.x != 0.0:
		sprite.scale.x = absf(sprite.scale.x) * signf(steer.x)
	velocity = steer * PHASE_SPEED
	for timer: ActionTimer in timers:
		timer.elapse(delta)
	elapse_ability_time_signal.emit(delta)
	move_and_slide()
	if MapInfo.instance != null and MapInfo.instance.world != null:
		var bounds: Rect2 = MapInfo.instance.level_rect()
		global_position = global_position.clamp(bounds.position, bounds.end)
