extends StaticBody2D
class_name Shutter
## A shutter across the gondola's chute where it passes through a band of rock between two tiers of
## the crags (CragsArchetype.cut_tiers): shut, it stops the wizard (and anything else) as rock does;
## it opens only while the gondola's car is in it or right at it (OPEN_NEAR), so the tiers are
## crossed riding the car, in it or on its roof, and never alone, up or down.

## How near the car's box must come to the shutter's (pixels) for it to open.
const OPEN_NEAR: float = 150.0

var map_info: MapInfo
## The chute's cells it shuts (level cells), and the same in world pixels.
var cells: Rect2i = Rect2i()
var area: Rect2 = Rect2()
## How open it is (0 shut, 1 open), for the art; and the layers it blocks on while shut.
var open: float = 0.0
var _layer: int = 4
var _gondola: Gondola = null


func setup(info: MapInfo, _v: Vector2i, box: Rect2i) -> void:
	map_info = info
	cells = box
	var size: float = absf((info.cell_position(Vector2i(1, 0)) - info.cell_position(Vector2i.ZERO)).x)
	var corner: Vector2 = info.cell_position(box.position) - Vector2(size, size) * 0.5
	area = Rect2(corner, Vector2(box.size) * size)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = area.size
	var col: CollisionShape2D = $CollisionShape2D
	col.shape = shape
	col.global_position = area.get_center()


## The level's gondola (found once).
func gondola() -> Gondola:
	if _gondola != null and is_instance_valid(_gondola):
		return _gondola
	_gondola = null
	if map_info != null and is_instance_valid(map_info.map_elements):
		for node: Node in map_info.map_elements.get_children():
			if node is Gondola:
				_gondola = node as Gondola
	return _gondola


## Whether the car is in it or right at it.
func car_here() -> bool:
	var g: Gondola = gondola()
	if g == null or g.stale():
		return false
	var c: Vector2 = g.center()
	var car: Rect2 = Rect2(c - Vector2(g.cell_px, g.cell_px), Vector2(g.cell_px, g.cell_px) * 2.0)
	return car.grow(OPEN_NEAR).intersects(area)


func _physics_process(delta: float) -> void:
	var here: bool = car_here()
	collision_layer = 0 if here else _layer
	open = move_toward(open, 1.0 if here else 0.0, delta * 4.0)


func _ready() -> void:
	_layer = collision_layer
