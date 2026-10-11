class_name EggSac
extends Node2D
## An egg sac the spider (Spider) lobbed at the wizard. It flies in an arc (GRAVITY), aimed to come
## down where they were (lob); rock across its way stops it going across, and it lands on the first
## floor under it. Landed, it swells for HATCH seconds (sooner on a harder preset, Difficulty.attack)
## and bursts into Spider.BROOD spiderlings (Spiderling), scattering. Any blow bursts it first
## (BroodWound: a hex bolt or a dash, even one that only stuns). It goes with the spider. Printed as
## a ball of pale silk wound round, its eggs glowing pink through it as they near hatching.

## How hard it falls (px/s²), how long a lob takes (seconds, from, to: further takes longer, LOB_PX
## a second), and how far its middle sits over a floor (px).
const GRAVITY: float = 1400.0
const FLIGHT: Vector2 = Vector2(0.5, 1.1)
const LOB_PX: float = 700.0
const RADIUS: float = 30.0
## Seconds it swells before hatching, and how fast its spiderlings scatter (px/s).
const HATCH: float = 2.5
const SCATTER: float = 200.0

## The spider that lobbed it, how it flies (px/s), whether it has landed, and how far along it is
## to hatching (seconds).
var spider: Spider
var velocity: Vector2 = Vector2.ZERO
var landed: bool = false
var hatching: float = 0.0
var t: float = 0.0
var ink: InkCanvas


## The way to lob a sac from `from` to come down at `to`.
static func lob(from: Vector2, to: Vector2) -> Vector2:
	var time: float = clampf(from.distance_to(to) / LOB_PX, FLIGHT.x, FLIGHT.y)
	return Vector2((to.x - from.x) / time, (to.y - from.y) / time - 0.5 * GRAVITY * time)


func _init() -> void:
	var wound: BroodWound = BroodWound.new()
	wound.name = "Wound"
	add_child(wound)
	add_to_group(&"hex_target")


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
	t += delta
	if landed:
		hatching += delta * Difficulty.attack()
		if hatching >= HATCH:
			_hatch()
		return
	var info: MapInfo = spider.map_info
	velocity.y += GRAVITY * delta
	var at: Vector2 = global_position
	var to: Vector2 = at + velocity * delta
	if info.world.is_ground(info.cell_at(Vector2(to.x + signf(velocity.x) * RADIUS, at.y))):
		velocity.x = 0.0
		to.x = at.x
	if velocity.y < 0.0 and info.world.is_ground(info.cell_at(Vector2(to.x, to.y - RADIUS))):
		velocity.y = 0.0
		to.y = at.y
	var under: Vector2i = info.cell_at(Vector2(to.x, to.y + RADIUS))
	if velocity.y >= 0.0 and info.world.is_ground(under):
		to.y = info.cell_position(under).y - spider.cell * 0.5 - RADIUS
		landed = true
		velocity = Vector2.ZERO
		RisoFx.burst(&"impact", to + Vector2(0.0, RADIUS), Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
	global_position = to


## It bursts into spiderlings, scattering either way.
func _hatch() -> void:
	for i: int in range(Spider.BROOD):
		var young: Spiderling = Spiderling.new()
		young.spider = spider
		young.velocity = Vector2((float(i) - float(Spider.BROOD - 1) * 0.5) * SCATTER, -SCATTER * 1.5)
		spider.map_info.map_elements.add_child(young)
		young.global_position = global_position
		spider.brood.append(young)
	RisoFx.burst(&"gain", global_position, Vector2.UP, [RisoPrint.PINK, RisoPrint.BLUE])
	queue_free()


func _process(_delta: float) -> void:
	ink.begin()
	var u: float = clampf(hatching / HATCH, 0.0, 1.0)
	var wobble: float = sin(t * (8.0 + 30.0 * u)) * 0.12 * u
	var xf: Transform2D = Transform2D(wobble, global_position)
	var swell: float = 1.0 + 0.15 * u
	var ball: PackedVector2Array = xf * RisoShapes.ellipse(Vector2.ZERO, RADIUS * 0.9 * swell, RADIUS * swell, 18)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], Spider.WEB_LIFT, [ball])
	# Its eggs, pink through the silk, brighter as they near hatching.
	var eggs: Array[PackedVector2Array] = []
	for i: int in range(4):
		var p: Vector2 = Vector2(cos(float(i) * 1.9), sin(float(i) * 2.7)) * RADIUS * 0.4
		eggs.append(xf * RisoShapes.circle(p, RADIUS * (0.22 + 0.1 * u), 10))
	ink.ink(RisoPrint.PINK, 0.25 + 0.6 * u, eggs)
	# Silk wound round it.
	var wraps: Array[PackedVector2Array] = []
	for k: int in range(3):
		var y: float = (float(k) - 1.0) * RADIUS * 0.55
		wraps.append(xf * Spider.strand(Vector2(-RADIUS * 0.9, y - 5.0), Vector2(RADIUS * 0.9, y + 5.0), 3.5))
	ink.ink(RisoPrint.BLUE, 0.5, wraps, false)
	ink.finish()
