class_name Bird
extends Node2D
## A swooping bird, in sky levels (MapInfo.World.populate_sky): it patrols back and forth along its
## own height, a stretch of open sky between two ends (`span`), wings beating. When the wizard passes
## below it, within REACH across and DROP down, and it has rested REST since its last swoop, it folds
## its wings and swoops: down through where the wizard was and up the far side in an arc, back to
## its patrol height, then patrols on. It only swoops where the arc is clear of rock. Its touch
## hurts, like any enemy's (its HitBox); the hex wounds it and the hex or a parry stuns it, in the
## air where it is. Moved only from here: its body is a frozen kinematic RigidBody2D that collides
## with nothing, as a wraith's.

const SPEED: float = 170.0
const REACH: float = 300.0
const DROP: float = 560.0
const SWOOP_TIME: float = 1.4
const REST: float = 1.5

@onready var rb: RigidBody2D = $".."
@onready var player: Player = get_node_or_null("/root/Main/Player") as Player
var stunned: bool = false
## Its patrol: the height it flies at, and the ends of its stretch (world x).
var height: float = 0.0
var span: Vector2 = Vector2.ZERO
var dir: float = 1.0
## +1 facing right, -1 left (the art).
var facing: float = 1.0
var velocity: Vector2 = Vector2.ZERO
## How far through a swoop (0..1), or -1 while patrolling; and its arc (start, low point, end).
var swoop: float = -1.0
var arc: Array[Vector2] = []
var since_swoop: float = 99.0
var t: float = 0.0


## `extra` holds the ends of its stretch, in cells: [first, last] along its row.
func setup(info: MapInfo, v: Vector2i, extra: Variant = null) -> void:
	height = info.cell_position(v).y
	if extra is Array and (extra as Array).size() == 2:
		span = Vector2(info.cell_position(Vector2i(int(extra[0]), v.y)).x, info.cell_position(Vector2i(int(extra[1]), v.y)).x)
	else:
		span = Vector2(info.cell_position(v).x - 384.0, info.cell_position(v).x + 384.0)


func _ready() -> void:
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.collision_layer = 0
	rb.collision_mask = 0


func swooping() -> bool:
	return swoop >= 0.0


func _physics_process(delta: float) -> void:
	t += delta
	if height == 0.0:
		height = rb.global_position.y
		span = Vector2(rb.global_position.x - 384.0, rb.global_position.x + 384.0)
	if stunned:
		velocity = Vector2.ZERO
		return
	var was: Vector2 = rb.global_position
	if swoop >= 0.0:
		swoop = minf(1.0, swoop + delta / SWOOP_TIME)
		rb.global_position = _on_arc(swoop)
		if swoop >= 1.0:
			swoop = -1.0
			since_swoop = 0.0
			dir = signf(arc[2].x - arc[0].x) if arc[2].x != arc[0].x else dir
	else:
		since_swoop += delta
		var at: Vector2 = rb.global_position
		at.x += dir * SPEED * delta
		if at.x > span.y:
			at.x = span.y
			dir = -1.0
		elif at.x < span.x:
			at.x = span.x
			dir = 1.0
		at.y = move_toward(at.y, height, SPEED * delta) + sin(t * 3.0) * 0.6
		rb.global_position = at
		_look()
	velocity = (rb.global_position - was) / maxf(delta, 0.0001)
	if absf(velocity.x) > 5.0:
		facing = signf(velocity.x)


## The wizard below, in reach, after a rest, with a clear arc: swoop.
func _look() -> void:
	if since_swoop < REST or player == null or not is_instance_valid(player):
		return
	var at: Vector2 = rb.global_position
	var target: Vector2 = player.global_position + Vector2(0, -30)
	var d: Vector2 = target - at
	if absf(d.x) > REACH or d.y < 80.0 or d.y > DROP:
		return
	var end_x: float = clampf(at.x + 2.0 * d.x if absf(d.x) > 40.0 else at.x + dir * 160.0, span.x, span.y)
	var path: Array[Vector2] = [at, target, Vector2(end_x, height)]
	var info: MapInfo = MapInfo.instance
	if info != null and info.world != null:
		var old: Array[Vector2] = arc
		arc = path
		for k: int in range(1, 12):
			if info.solid_at(_on_arc(float(k) / 12.0)):
				arc = old
				return
	arc = path
	swoop = 0.0


## The point `u` (0..1) along its swoop: a curve from the start through the low point (at half
## way) to the end.
func _on_arc(u: float) -> Vector2:
	var a: Vector2 = arc[0]
	var low: Vector2 = arc[1]
	var b: Vector2 = arc[2]
	var c: Vector2 = 2.0 * low - 0.5 * (a + b)
	return a * (1.0 - u) * (1.0 - u) + c * 2.0 * u * (1.0 - u) + b * u * u
