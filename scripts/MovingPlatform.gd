extends AnimatableBody2D
## A platform run that glides back and forth along an open track. One-way and rideable, like
## the static platforms (same collision layer, so dropping through works too).

# Exported so the track survives when the world is packed and revisited.
@export var length: int = 1
@export var axis: Vector2 = Vector2.RIGHT
@export var travel: float = 256.0
@export var start: Vector2
@export var period: float = 4.0
@export var phase: float = 0.0
@export var cell_size: float = 128.0
var t: float = 0.0


func setup(map_info: MapInfo, _v: Vector2i, info: Array) -> void:
	length = int(info[0])
	axis = Vector2(info[1] as Vector2i)
	var tm: TileMap = map_info.tile_map
	cell_size = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	travel = float(info[2]) * cell_size
	period = 1.8 * float(info[2]) + 1.2
	phase = map_info.world.rng.randf() * TAU
	start = position
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(float(length) * cell_size - 2.0, 33.0)
	var col: CollisionShape2D = $CollisionShape2D
	col.shape = shape
	col.position = Vector2(float(length - 1) * cell_size * 0.5, -cell_size * 0.5 + 16.5)
	# Plain stand-in for the unprinted view; a child, so it stays off the ink plates.
	var plain: ColorRect = ColorRect.new()
	plain.color = Color(0.55, 0.45, 0.3)
	plain.size = shape.size
	plain.position = col.position - shape.size * 0.5
	plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plain)
	plain.owner = owner
	position = start + offset_at(0.0)
	queue_redraw()


func offset_at(time: float) -> Vector2:
	return axis * travel * (0.5 - 0.5 * cos(time * TAU / period + phase))


func _physics_process(delta: float) -> void:
	t += delta
	position = start + offset_at(t)
