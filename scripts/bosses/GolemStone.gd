class_name GolemStone
extends Node2D
## A chunk the golem hurls (Golem: one of its HURLED chunks, `part`): it flies in an arc to where the
## wizard was, hurting them if it meets them, and lies where it lands until the golem calls it back
## (`called`: the golem flies it home along its way, through where the wizard stood, still hurting).
## A guard catches it as it catches thorns, with nothing to strike (Parry): it is no part of the
## golem while it is away. Printed as the chunk it is (Golem.chunk_inks), tumbling as it flies, pink
## over it while it flies or is called home and so hurts.

const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## How hard it falls (px/s²), and how fast at most.
const GRAVITY: float = 2200.0
const FALL_MAX: float = 1500.0

## The golem that hurled it, which of its chunks it is (Golem.PARTS' place), and the level's cell
## size (px).
var golem: Golem
var part: int = 0
var cell: float = 128.0
## Its way (px/s) while it flies.
var velocity: Vector2 = Vector2.ZERO
var landed: bool = false
## Being called home: the golem moves it.
var called: bool = false
var touch: HitBox
var ink: InkCanvas
var spin: float = 0.0


## The way (px/s) to throw from `from` to come down on `to` after `flight` seconds, falling as it does.
static func lob(from: Vector2, to: Vector2, flight: float) -> Vector2:
	return (to - from) / flight - Vector2(0.0, 0.5 * GRAVITY * flight)


func _ready() -> void:
	z_index = 3
	touch = HIT_BOX.instantiate() as HitBox
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = Golem.PARTS[part].z * 0.9
	(touch.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	add_child(touch)
	ink = InkCanvas.new()
	add_child(ink)


func _physics_process(delta: float) -> void:
	var info: MapInfo = MapInfo.instance
	# Hurting while it flies and while it is called home; lying, it is still.
	var hurts: bool = called or not landed
	if touch.collision != null and touch.collision.disabled == hurts:
		touch.collision.set_deferred("disabled", not hurts)
	if called or landed or info == null or info.world == null:
		return
	spin += delta * 6.0
	velocity.y = minf(velocity.y + GRAVITY * delta, FALL_MAX)
	var r: float = Golem.PARTS[part].z
	var next: Vector2 = global_position + velocity * delta
	if velocity.x != 0.0 and info.world.is_ground(info.cell_at(next + Vector2(signf(velocity.x) * r, 0.0))):
		velocity.x = 0.0
		next.x = global_position.x
	if velocity.y < 0.0 and info.world.is_ground(info.cell_at(next - Vector2(0.0, r))):
		velocity.y = 0.0
		next.y = global_position.y
	var under: Vector2i = info.cell_at(next + Vector2(0.0, r))
	if velocity.y > 0.0 and info.world.is_ground(under):
		next.y = info.cell_position(under).y - cell * 0.5 - r * 0.8
		landed = true
		velocity = Vector2.ZERO
		Wound.shake(6.0, 0.1)
	global_position = next


func _process(_delta: float) -> void:
	if ink == null:
		return
	ink.global_position = global_position
	ink.begin()
	var hurts: bool = called or not landed
	Golem.chunk_inks(ink, part, Vector2.ZERO, spin, Vector2.ZERO, 0.0, Golem.WARN_PINK * 0.6 if hurts else 0.0, 0.0, 1.0)
	ink.finish()
