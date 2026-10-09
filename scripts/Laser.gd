extends Node2D
class_name Laser
## A laser set in the rock: on a steady cadence it warms up (a faint flickering sight line), fires
## a beam straight out from the rock until it meets a wall, then rests. Only the firing beam hurts.
## The beam's reach is found by a ray each frame, so ledges and lifts in its way stop it too.

const WARM_TIME: float = 0.9
const FIRE_TIME: float = 0.7
const REST_TIME: float = 1.6
const PERIOD: float = WARM_TIME + FIRE_TIME + REST_TIME
const MAX_REACH: float = 128.0 * 40.0
## Half the beam's thickness that hurts, in world pixels.
const HALF_WIDTH: float = 14.0

## Out of the rock, along the beam.
var dir: Vector2 = Vector2.DOWN
var t: float = 0.0
## How far the beam reaches from the muzzle, in world pixels.
var reach: float = 0.0
@onready var beam: Area2D = $Beam
@onready var shape: CollisionShape2D = $Beam/CollisionShape2D
var _box: RectangleShape2D = RectangleShape2D.new()


func setup(map_info: MapInfo, v: Vector2i, info: Variant = null) -> void:
	if info is Vector2i:
		dir = Vector2(info as Vector2i)
	# Out of step with its neighbours, but the same on every visit.
	t = float(Rules.level_seed(v.x, v.y) % 1000) / 1000.0 * PERIOD
	var tm: TileMap = map_info.tile_map
	var half: float = float(tm.tile_set.tile_size.x) * tm.global_scale.x * 0.5
	beam.position = muzzle_offset(half)
	beam.rotation = dir.angle()
	# Not put to sleep with its chunk (MapInfo sleeps only things with a cell): its beam reaches far.
	remove_meta(&"cell")


## Where the beam leaves the housing, from the cell's centre: just out from the rock face.
func muzzle_offset(half: float) -> Vector2:
	return -dir * (half - 30.0)


func _ready() -> void:
	shape.shape = _box
	shape.disabled = true


## "warm", "fire" or "rest", and how far through it (0..1).
func phase() -> Array:
	var u: float = fposmod(t, PERIOD)
	if u < WARM_TIME:
		return [&"warm", u / WARM_TIME]
	if u < WARM_TIME + FIRE_TIME:
		return [&"fire", (u - WARM_TIME) / FIRE_TIME]
	return [&"rest", (u - WARM_TIME - FIRE_TIME) / REST_TIME]


func firing() -> bool:
	return phase()[0] == &"fire"


func _physics_process(delta: float) -> void:
	t += delta
	var from: Vector2 = beam.global_position
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, from + dir * MAX_REACH, 4)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	reach = from.distance_to(hit.position) if not hit.is_empty() else MAX_REACH
	_box.size = Vector2(maxf(reach, 1.0), HALF_WIDTH * 2.0)
	shape.position = Vector2(reach * 0.5, 0)
	var hot: bool = firing()
	if shape.disabled == hot:
		shape.set_deferred("disabled", not hot)
