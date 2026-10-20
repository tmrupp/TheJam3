class_name GolemShock
extends Node2D
## A shockwave the golem sends along its floor (Golem): from where its fists come down in a slam, or
## where it lands a leap, one runs each way along the floor at SPEED, as far as REACH, stopping at a
## wall or the floor's end. It hurts the wizard it runs into, low along the floor, so it is jumped; a
## guard catches it as it catches thorns, with nothing to strike (Parry), for it is no part of the
## golem. In pink (danger): a low ripple of the floor's dust, lifted toward its front.

const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## How fast it runs (px/s), how far (px), and how high (px) over the floor its touch reaches, and how
## wide (px) it is.
const SPEED: float = 700.0
const REACH: float = 800.0
const HIGH: float = 64.0
const WIDE: float = 110.0

## The way it runs (1 right, -1 left), how far it has run, and the floor's top (px) it runs along.
var way: int = 1
var run: float = 0.0
var floor_y: float = 0.0
var ink: InkCanvas
var t: float = 0.0


## Send a shockwave each way from `at` along the floor whose top is `floor_y` (px), for `golem`.
static func send(golem: Golem, at: Vector2, floor_top: float) -> void:
	if golem.map_info == null:
		return
	for way: int in [-1, 1]:
		var shock: GolemShock = GolemShock.new()
		shock.way = way
		shock.floor_y = floor_top
		golem.map_info.map_elements.add_child(shock)
		shock.global_position = Vector2(at.x, floor_top)


func _ready() -> void:
	z_index = 3
	var box: HitBox = HIT_BOX.instantiate() as HitBox
	var reach: RectangleShape2D = RectangleShape2D.new()
	reach.size = Vector2(WIDE, HIGH)
	(box.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	box.position = Vector2(0.0, -HIGH * 0.5)
	add_child(box)
	ink = InkCanvas.new()
	add_child(ink)


func _physics_process(delta: float) -> void:
	var info: MapInfo = MapInfo.instance
	var step: float = SPEED * Difficulty.haste() * delta
	run += step
	var next: Vector2 = global_position + Vector2(float(way) * step, 0.0)
	var ahead: Vector2 = next + Vector2(float(way) * WIDE * 0.5, 0.0)
	var blocked: bool = info != null and info.world != null and (info.world.is_ground(info.cell_at(ahead + Vector2(0.0, -HIGH * 0.5))) or not info.world.is_ground(info.cell_at(ahead + Vector2(0.0, 8.0))))
	if run >= REACH or blocked:
		queue_free()
		return
	global_position = next


func _process(delta: float) -> void:
	t += delta
	if ink == null:
		return
	var fade: float = 1.0 - clampf(run / REACH, 0.0, 1.0) * 0.6
	var w: float = WIDE * 0.5
	var crest: PackedVector2Array = PackedVector2Array([
		Vector2(-w * float(way), 0.0), Vector2(-w * 0.3 * float(way), -HIGH * 0.45),
		Vector2(w * 0.4 * float(way), -HIGH * 0.8), Vector2(w * float(way), 0.0),
	])
	ink.global_position = global_position
	ink.begin()
	ink.ink(RisoPrint.PINK, 0.85 * fade, [RisoShapes.smooth(crest, 3)])
	ink.finish()
