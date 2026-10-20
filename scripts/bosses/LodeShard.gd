class_name LodeShard
extends Area2D
## A lode shard (Golem.shed_shards): a splinter of the golem's lodestone, struck out of it by a
## parried strong attack. It flies out, falls, and lies where it lands. Taken (the wizard touching
## it while their empowered cast is spent, where a spell may be cast empowered: Empower.tempers_now),
## it makes that cast ready at once (Empower.refill) and is gone; while the cast is ready it is left
## lying, for the charge is one. Left lying too long, the golem calls it back (`called`: the golem
## flies it home along its way, through where the wizard stood, hurting them as a hazard does, and it
## regrows a shattered chunk). It is in accent (a reward), a little crystal with a glint of paper.
## Nothing here draws from any RNG.

const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")

## How hard it falls (px/s²), and how fast at most (px/s).
const GRAVITY: float = 2200.0
const FALL_MAX: float = 1400.0
## How big it is (px), its half-height: it lands this far over the floor, and is taken within it.
const SIZE: float = 32.0
## Seconds after it is shed before it can be taken, so it is seen to fly.
const SETTLE: float = 0.3
## The wizard's body's collision layer, which it watches for.
const WIZARD_LAYER: int = 64
## How fast it bobs (radians/s) once it lies, and how far (px).
const BOB: float = 3.0
const BOB_PX: float = 3.0

## The golem that shed it, and the level's cell size (px).
var golem: Golem
var cell: float = 128.0
## Its way (px/s), while it flies.
var velocity: Vector2 = Vector2.ZERO
var landed: bool = false
## Being called home: the golem moves it, it hurts, and it cannot be taken.
var called: bool = false
var touch: HitBox
var t: float = 0.0
var ink: InkCanvas


func _ready() -> void:
	collision_layer = 0
	collision_mask = WIZARD_LAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var round_shape: CircleShape2D = CircleShape2D.new()
	round_shape.radius = SIZE
	shape.shape = round_shape
	add_child(shape)
	touch = HIT_BOX.instantiate() as HitBox
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = SIZE
	var hurt_shape: CollisionShape2D = touch.get_node("CollisionShape2D") as CollisionShape2D
	hurt_shape.shape = reach
	hurt_shape.disabled = true
	add_child(touch)
	z_index = 3
	ink = InkCanvas.new()
	add_child(ink)


func _physics_process(delta: float) -> void:
	t += delta
	if touch.collision != null and touch.collision.disabled == called:
		touch.collision.set_deferred("disabled", not called)
	if called:
		return
	var info: MapInfo = MapInfo.instance
	if not landed and info != null and info.world != null:
		velocity.y = minf(velocity.y + GRAVITY * delta, FALL_MAX)
		var next: Vector2 = global_position + velocity * delta
		if velocity.x != 0.0 and info.world.is_ground(info.cell_at(next + Vector2(signf(velocity.x) * SIZE, 0.0))):
			velocity.x = 0.0
			next.x = global_position.x
		if velocity.y < 0.0 and info.world.is_ground(info.cell_at(next - Vector2(0.0, SIZE))):
			velocity.y = 0.0
			next.y = global_position.y
		var under: Vector2i = info.cell_at(next + Vector2(0.0, SIZE))
		if velocity.y > 0.0 and info.world.is_ground(under):
			next.y = info.cell_position(under).y - cell * 0.5 - SIZE
			landed = true
			velocity = Vector2.ZERO
		global_position = next
	if t < SETTLE:
		return
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			_take(body as Player)
			return


## Taken by `wizard`, if their empowered cast is spent where it can be cast: it is ready again.
func _take(wizard: Player) -> void:
	var empower: Empower = Empower.of(wizard)
	if empower == null or empower.wait <= 0.0 or not empower.tempers_now():
		return
	empower.refill()
	RisoFx.burst(&"gain", global_position, Vector2.UP, [RisoPrint.ACCENT, RisoPrint.BLUE])
	queue_free()


func _process(_delta: float) -> void:
	if ink == null:
		return
	var at: Vector2 = global_position + (Vector2(0.0, sin(t * BOB) * BOB_PX) if landed else Vector2.ZERO)
	var spin: float = 0.0 if landed and not called else t * 9.0
	var xf: Transform2D = Transform2D(spin, at)
	var crystal: PackedVector2Array = xf * PackedVector2Array([Vector2(0.0, -SIZE), Vector2(SIZE * 0.55, -SIZE * 0.2), Vector2(SIZE * 0.4, SIZE), Vector2(-SIZE * 0.4, SIZE), Vector2(-SIZE * 0.55, -SIZE * 0.2)])
	var glint: PackedVector2Array = xf * PackedVector2Array([Vector2(-SIZE * 0.1, -SIZE * 0.7), Vector2(SIZE * 0.2, -SIZE * 0.25), Vector2(-SIZE * 0.05, SIZE * 0.1)])
	ink.global_position = Vector2.ZERO
	ink.begin()
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [crystal])
	ink.ink(RisoPrint.ACCENT, 1.0, [crystal])
	ink.knock([RisoPrint.ACCENT], [glint])
	# Called home, it hurts: pink over it.
	if called:
		ink.ink(RisoPrint.PINK, 0.55, [crystal], false)
	ink.finish()
