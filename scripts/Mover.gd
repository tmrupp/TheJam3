extends Stunnable
class_name Mover
## Wisp patrol: walk along the floor, turning round at walls, ledges and other wisps, and lurch at
## the wizard when they are close in front of it on its floor (see LURCH_SIGHT).
## The body is a frozen (kinematic) RigidBody2D moved only from here, falling under its own
## gravity until it lands, so the physics engine never bounces it on the floor. Standing on
## something that moves (a gondola's car, a lift), it is carried with it each step, first of all,
## so a rising floor never pushes into it and a sinking one never leaves it behind; how far it has
## been carried all told is kept (carried), and how far it has dropped (fallen), so its art can
## tell being carried or dropping from walking.


const SPEED: float = 60.0
const JUMP_VELOCITY: float = -400.0
const MAX_FALL: float = 900.0
## Two wisps meeting both turn round at this distance, centre to centre, leaving each room for
## its turning drop (WispArt) in the half of the way between them, so the drops meet nose to nose.
const WISP_GAP: float = 100.0
## A wisp turns round when its front comes within WALL_ROOM of a wall, rather than at the wall, so
## its turning drop (WispArt) swings round in the open instead of into the rock.
const WALL_ROOM: float = 40.0
## The wall probe is lifted this far off the floor, so the floor it walks on never reads as a wall.
const WALL_LIFT: float = 4.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var tilemap: TileMap = Stage.tile_map() # $\"../TileMap\"
@onready var dcast: RayCast2D = $DownCast
@onready var rb: RigidBody2D = $".."
@onready var sprite: Sprite2D = $"../Sprite2D"
## Turning round: the wisp holds still for TURN_TIME while its art swoops round its turning drop
## (WispArt times the drop by it).
const TURN_TIME: float = 0.7
var turn_left: float = 0.0
var fall_speed: float = 0.0
## Standing on something (only then does it walk, or look for ledges).
var grounded: bool = false
## How fast what it stands on was moving at the last step (px/s), and how far it has been carried
## by what it stands on, all told (px).
var under_velocity: Vector2 = Vector2.ZERO
var carried: Vector2 = Vector2.ZERO
## How far it has dropped under its own weight, all told (px): settling onto its floor, falling, and
## keeping to a floor that sinks away under it. Its art moves its whole body down by as much, so a
## drop never bends it as walking would.
var fallen: float = 0.0
## How far (px) a floor that drops away from under it (a gondola's car slowing on its way up, a lift
## setting off down) may have gone in a step for it to settle back onto it at once.
const SNAP: float = 12.0
## Put at its cell's centre, it settles onto the floor on its first step, looking this far (px, a
## cell) under where it was put. Not on being added: the level moves it to its cell only after
## adding it (LevelLoader.place_cell), so settling then left it floating at its cell's centre, to
## fall into place when its chunk first woke.
const SETTLE: float = 128.0
## Whether it has settled onto its floor (on its first step).
var settled: bool = false
## The lurch: walking with the wizard in front of it, within LURCH_SIGHT.x and no more than
## LURCH_SIGHT.y above or below it, with no rock between, a wisp stops and winds up for WIND_UP
## seconds (its art rears up, glowing hotter: WispArt), then lurches at them, LURCH_SPEED px/s at
## first and slowing to nothing over LURCH_TIME seconds (about LURCH_SPEED * LURCH_TIME / 2 px in
## all), stopping short at a ledge, a wall or another wisp. It gathers itself for LURCH_REST seconds
## after, and walks LURCH_AGAIN seconds before it may lurch again. A harder preset winds up, rests
## and lurches again sooner (Difficulty.attack); a stun breaks it off.
const LURCH_SIGHT: Vector2 = Vector2(230.0, 48.0)
const WIND_UP: float = 0.55
const LURCH_SPEED: float = 880.0
const LURCH_TIME: float = 0.3
const LURCH_REST: float = 0.5
const LURCH_AGAIN: float = 1.6
## How far up (px) the wizard is looked for from the wisp's origin: its body's middle.
const LURCH_EYE: float = 16.0
## How far into the wind-up (0 to 1), and into the lurch (0 to 1) it is, each -1 when not; and the
## seconds left resting after a lurch, and before it may lurch again.
var winding: float = -1.0
var lurching: float = -1.0
var resting: float = 0.0
var lurch_wait: float = 0.0


func _ready() -> void:
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.add_to_group(&"wisps")
	# Stepped after what it may stand on (a gondola, a lift), so it is carried by this step's motion
	# rather than lagging a step behind, sunk into a rising floor.
	process_physics_priority = 1


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
	# Spawned at its cell's centre: on its first step, standing where it was put, it settles onto
	# the floor at once rather than falling into place (see SETTLE).
	if not settled:
		settled = true
		_drop(SETTLE)
	# Carried with what it stands on, before anything else.
	if grounded and under_velocity != Vector2.ZERO:
		var carry: Vector2 = under_velocity * delta
		rb.global_position += carry
		carried += carry
	_fall(delta)
	if stunned or not grounded:
		# Knocked out of it (or off its floor): the wind-up or lurch is lost.
		if winding >= 0.0 or lurching >= 0.0:
			winding = -1.0
			lurching = -1.0
			lurch_wait = LURCH_AGAIN
		return
	if turn_left > 0.0:
		turn_left = maxf(0.0, turn_left - delta)
		return
	if _lurch(delta):
		return

	# A little faster on a harder preset (Difficulty.speed).
	var collision: KinematicCollision2D = rb.move_and_collide(Vector2(SPEED * Difficulty.speed(), 0)*delta*direction)

	# Only a wall faced head-on turns it, never a seam or corner of the floor it walks on.
	if collision and absf(collision.get_normal().x) > 0.7 and signf(collision.get_normal().x) == -float(direction):
		turn()
	elif _wall_near() or _wisp_ahead():
		turn()
	elif not _floor_ahead():
		if not down_wait:
			turn()
			wait_to_down()

	if direction != 0:
		if direction > 0:
			sprite.scale.x = abs(sprite.scale.x)
		else:
			sprite.scale.x = -abs(sprite.scale.x)


## The lurch, a step of it (see LURCH_SIGHT): whether it holds the walk this step.
func _lurch(delta: float) -> bool:
	var pace: float = Difficulty.attack()
	if lurching >= 0.0:
		lurching += delta / LURCH_TIME
		var step: float = LURCH_SPEED * maxf(0.0, 1.0 - lurching) * delta * float(direction)
		var stop: bool = lurching >= 1.0 or _wisp_ahead() or not _floor_ahead(step)
		if not stop:
			var hit: KinematicCollision2D = rb.move_and_collide(Vector2(step, 0.0))
			stop = hit != null and absf(hit.get_normal().x) > 0.7
		if stop:
			lurching = -1.0
			resting = LURCH_REST
		return true
	if resting > 0.0:
		resting = maxf(0.0, resting - delta * pace)
		if resting <= 0.0:
			lurch_wait = LURCH_AGAIN
		return true
	if winding >= 0.0:
		winding += delta * pace / WIND_UP
		if winding >= 1.0:
			winding = -1.0
			lurching = 0.0
			# Dust kicked up behind it as it goes.
			RisoFx.burst(&"lurch", rb.global_position + Vector2(-float(direction) * 12.0, LURCH_EYE), Vector2(-float(direction), 0.0))
		return true
	if lurch_wait > 0.0:
		lurch_wait = maxf(0.0, lurch_wait - delta * pace)
		return false
	if _sees_wizard():
		winding = 0.0
		return true
	return false


## The wizard in front of it on its floor, near enough to lurch at, with no rock between (see
## LURCH_SIGHT).
func _sees_wizard() -> bool:
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player) or player.phasing:
		return false
	var eye: Vector2 = rb.global_position + Vector2(0.0, -LURCH_EYE)
	var d: Vector2 = player.global_position - eye
	if d.x * float(direction) <= 0.0 or absf(d.x) > LURCH_SIGHT.x or absf(d.y) > LURCH_SIGHT.y:
		return false
	# Only rock (layer 3) blocks the view.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(eye, player.global_position, 4, [rb.get_rid()])
	return rb.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Fall until something is underfoot; resting on the floor, stay put (no bounce).
func _fall(delta: float) -> void:
	fall_speed = minf(fall_speed + gravity * delta, MAX_FALL)
	var hit: KinematicCollision2D = _drop(fall_speed * delta)
	grounded = hit != null and hit.get_normal().y < -0.7
	if not grounded and hit == null and under_velocity != Vector2.ZERO:
		# Its moving floor dropped away from under it this step: back onto it.
		var snap: KinematicCollision2D = rb.move_and_collide(Vector2(0, SNAP), true)
		if snap != null and snap.get_normal().y < -0.7:
			_drop(SNAP)
			hit = snap
			grounded = true
	under_velocity = hit.get_collider_velocity() if grounded else Vector2.ZERO
	if hit != null:
		fall_speed = 0.0


## Move the body down `dy` px, stopping at whatever it meets, and count how far it went (fallen).
func _drop(dy: float) -> KinematicCollision2D:
	var from: float = rb.global_position.y
	var hit: KinematicCollision2D = rb.move_and_collide(Vector2(0, dy))
	fallen += rb.global_position.y - from
	return hit


## Whether there is floor under the body just past its leading edge. A body-shape probe tests
## the same floor the wisp stands on, ground and one-way platforms alike; the old short ray
## misread the seams where a platform meets ground as ledges.
## `step` px further on (a lurch's step) is looked at, past where it stands.
func _floor_ahead(step: float = 0.0) -> bool:
	var ahead: Transform2D = rb.global_transform.translated(Vector2(absf(dcast.position.x) * 1.8 * float(direction) + step, 0.0))
	return rb.test_move(ahead, Vector2(0, 10))


## What the wall probe last hit (one kept, so probing every frame makes nothing new).
var _wall_hit: KinematicCollision2D = KinematicCollision2D.new()


## A wall in front, within WALL_ROOM of the body: one a head-on bump would turn it at, seen sooner.
func _wall_near() -> bool:
	var lifted: Transform2D = rb.global_transform.translated(Vector2(0, -WALL_LIFT))
	if not rb.test_move(lifted, Vector2(WALL_ROOM * float(direction), 0), _wall_hit):
		return false
	return absf(_wall_hit.get_normal().x) > 0.7 and signf(_wall_hit.get_normal().x) == -float(direction)


## Another wisp within this height is on the same floor.
const SAME_FLOOR: float = 24.0
## The level's wisps by band of height (WISP_BAND px tall), sorted once a physics step by where
## they stood when the first wisp looked (or again when wisps come or go), so a wisp looks only at
## those in the bands its own floor can reach rather than at every wisp in the level (a level holds
## dozens, and each looks every step). A wisp that has moved since is still found where it is
## now, unless it moved more than BAND_SLACK px up or down within that step.
const WISP_BAND: float = 64.0
const BAND_SLACK: float = 64.0
static var _bands: Dictionary = {}
static var _bands_step: int = -1
static var _bands_count: int = -1


## Another wisp in front on the same floor, closer than WISP_GAP.
func _wisp_ahead() -> bool:
	var tree: SceneTree = get_tree()
	var step: int = Engine.get_physics_frames()
	var count: int = tree.get_node_count_in_group(&"wisps")
	if step != _bands_step or count != _bands_count:
		_bands_step = step
		_bands_count = count
		_bands.clear()
		for other: Node in tree.get_nodes_in_group(&"wisps"):
			var band: int = floori((other as Node2D).global_position.y / WISP_BAND)
			if not _bands.has(band):
				_bands[band] = []
			(_bands[band] as Array).append(other)
	var here: Vector2 = rb.global_position
	for band: int in range(floori((here.y - SAME_FLOOR - BAND_SLACK) / WISP_BAND), floori((here.y + SAME_FLOOR + BAND_SLACK) / WISP_BAND) + 1):
		for entry: Variant in _bands.get(band, []):
			if not is_instance_valid(entry) or entry == rb:
				continue
			var d: Vector2 = (entry as Node2D).global_position - here
			if absf(d.y) < SAME_FLOOR and d.x * float(direction) > 0.0 and absf(d.x) < WISP_GAP:
				return true
	return false
