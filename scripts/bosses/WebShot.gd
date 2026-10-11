class_name WebShot
extends Node2D
## A glob of web the spider (Spider) spat at the wizard. It flies straight at SPEED; meeting the
## wizard (within CATCH of them) it sticks to them, and meeting rock it sticks there, short of it,
## either way as a splat (Spider.splat), a small web that holds whoever is in it as the spider's
## webs do. Ledges and webs let it through. It does not hurt, and nothing stops it in flight; after
## LIFE seconds it comes apart. Printed as a knot of pale strands with a pink heart (danger),
## trailing a thread.

## How fast it flies (px/s), how near the wizard it sticks to them (px), and how long it flies at
## most (seconds).
const SPEED: float = 600.0
const CATCH: float = 44.0
const LIFE: float = 3.0
## How big its knot is (px), and how long a thread it trails.
const KNOT: float = 24.0
const TRAIL: float = 70.0

## The spider that spat it, and how it flies (px/s).
var spider: Spider
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0
var ink: InkCanvas


func _ready() -> void:
	ink = InkCanvas.new()
	ink.top_level = true
	ink.z_as_relative = false
	ink.z_index = 3
	add_child(ink)


func _physics_process(delta: float) -> void:
	if spider == null or not is_instance_valid(spider) or spider.dying() or spider.map_info == null:
		queue_free()
		return
	age += delta
	if age >= LIFE:
		queue_free()
		return
	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta
	var player: Player = spider.map_info.player
	if player != null and is_instance_valid(player):
		var near: Vector2 = Geometry2D.get_closest_point_to_segment(player.global_position, from, to)
		if near.distance_to(player.global_position) <= CATCH:
			_stick(player.global_position)
			return
	if spider.map_info.world.is_ground(spider.map_info.cell_at(to)):
		_stick(from)
		return
	global_position = to


## It sticks at `at`, as a splat.
func _stick(at: Vector2) -> void:
	spider.splat(at)
	RisoFx.burst(&"hit", at, -velocity.normalized(), [RisoPrint.BLUE, RisoPrint.NIGHT])
	queue_free()


func _process(_delta: float) -> void:
	ink.begin()
	var at: Vector2 = global_position
	var back: Vector2 = -velocity.normalized() if velocity != Vector2.ZERO else Vector2.UP
	var strands: Array[PackedVector2Array] = [Spider.strand(at, at + back * TRAIL, 3.0)]
	for i: int in range(3):
		var dir: Vector2 = Vector2.from_angle(age * 9.0 + TAU * float(i) / 6.0)
		strands.append(Spider.strand(at - dir * KNOT, at + dir * KNOT, Spider.THREAD_W))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], Spider.WEB_LIFT, strands)
	ink.ink(RisoPrint.PINK, 0.8, [RisoShapes.circle(at, 8.0, 12)])
	ink.finish()
