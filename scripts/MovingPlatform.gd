extends AnimatableBody2D
class_name MovingPlatform
## A platform run that glides back and forth along an open track. One-way and rideable, like
## the static platforms (same collision layer, so dropping through works too). A lift with a
## switch (LevelGen.place_lift_switches) stays parked at the start of its track until the switch is
## thrown, then runs for good, starting from where it was parked.

# Exported so the track survives when the world is packed and revisited.
@export var length: int = 1
@export var axis: Vector2 = Vector2.RIGHT
@export var travel: float = 256.0
@export var start: Vector2
@export var period: float = 4.0
@export var phase: float = 0.0
@export var cell_size: float = 128.0
var t: float = 0.0
## Salt for the lift's phase, hashed from the level seed and its cell (see LevelLoader.place_cell).
const PHASE_DEAL: int = 9900
## The cell of the switch that starts it (none: it always runs), and whether it is still waiting.
var switch_cell: Vector2i = Vector2i(-1, -1)
var waiting: bool = false


func setup(map_info: MapInfo, v: Vector2i, info: Array) -> void:
	length = int(info[0])
	axis = Vector2(info[1] as Vector2i)
	var tm: TileMap = map_info.tile_map
	cell_size = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	travel = float(info[2]) * cell_size
	period = 1.8 * float(info[2]) + 1.2
	phase = RisoDecor.h(map_info.world.seed_for_colors, v, PHASE_DEAL) * TAU
	# The track starts at the platform's cell. (Not `position`: a physics-synced body reverts
	# direct moves until the next physics step, so it still reads as the origin here.)
	start = tm.to_global(tm.map_to_local(v))
	if info.size() > 3:
		switch_cell = info[3]
		waiting = not map_info.record().switched.has(switch_cell)
		if not waiting:
			run()
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
	_place(start if waiting else start + offset_at(t))
	queue_redraw()


## Teleport without sweeping: physics sync is off for the move, so nothing is pushed along
## the way from wherever the body was.
func _place(at: Vector2) -> void:
	sync_to_physics = false
	position = at
	sync_to_physics = true


func offset_at(time: float) -> Vector2:
	return axis * travel * (0.5 - 0.5 * cos(time * TAU / period + phase))


## Its switch is thrown: start running from the parked spot (the start of the track), without a jump.
func run() -> void:
	waiting = false
	t = -phase * period / TAU


func _physics_process(delta: float) -> void:
	if waiting:
		position = start
		return
	t += delta
	position = start + offset_at(t)
