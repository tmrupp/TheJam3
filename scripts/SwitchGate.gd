extends StaticBody2D
class_name SwitchGate
## A gate across a corridor, worked by its switch elsewhere in the level (Switch): lifted while
## the switch is on, down while it is off. It has no lock: nothing else opens it. It drops only
## once the wizard is clear of it, so it never shuts on them. The portcullis winches up and down
## (`lift`, printed by GateArt).

## How fast the portcullis winches up or down (its whole height a second, times this), and how far
## up it goes: not out of sight, so its bars still hang from the ceiling where the gate is.
const LIFT_SPEED: float = 3.0
const UP_LIFT: float = 0.75

var map_info: MapInfo
## The cell of the switch that works it.
var switch_cell: Vector2i = Vector2i(-1, -1)
## Whether its switch has it up, and how far up it is (0 down, UP_LIFT up) for the art.
var up: bool = false
var lift: float = 0.0
## The physics layers it blocks on while down (from the prefab).
var _layer: int = 4


func setup(info: MapInfo, _v: Vector2i, lever: Vector2i) -> void:
	map_info = info
	switch_cell = lever
	up = info.switch_on(lever)
	lift = UP_LIFT if up else 0.0
	_block(not up)


## Its switch was turned: up at once, or down as soon as the wizard is clear of it.
func set_up(on: bool) -> void:
	up = on
	if on:
		_block(false)


## Whether it blocks the way.
func shut() -> bool:
	return collision_layer != 0


func _block(on: bool) -> void:
	collision_layer = _layer if on else 0


## Whether the wizard's body overlaps the gate's.
func _holds_wizard() -> bool:
	var player: Player = map_info.player if map_info != null else null
	if player == null or not is_instance_valid(player) or player.collider == null or player.collider.shape == null:
		return false
	var mine: CollisionShape2D = $CollisionShape2D
	var a: Rect2 = mine.shape.get_rect()
	a = Rect2(mine.global_position + a.position * mine.global_scale, a.size * mine.global_scale)
	var b: Rect2 = player.collider.shape.get_rect()
	b = Rect2(player.collider.global_position + b.position * player.collider.global_scale, b.size * player.collider.global_scale)
	return a.intersects(b)


func _physics_process(delta: float) -> void:
	if not up and not shut() and not _holds_wizard():
		_block(true)
	lift = move_toward(lift, 0.0 if shut() else UP_LIFT, LIFT_SPEED * delta)


func _ready() -> void:
	# The printed portcullis shows a switch emblem where a door shows its lock (RisoProp).
	set_meta(&"key_color", -1)
	_layer = collision_layer
