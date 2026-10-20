extends StaticBody2D
class_name LightGate
## A gate worked by light, across a crypt's doorway (Crypts): a sun gate is up only while light
## falls on it (Lamplight: the wizard's lit flame, a lantern's light), a shade gate only while none
## does, so it is passed with the flame snuffed (Snuffer) and shuts on a lit one. Light is looked
## for just either side of it, where it would fall on its face. It has no lock and keeps no record:
## it follows the light from moment to moment, and drops only once the wizard is clear of it, so it
## never shuts on them. The portcullis winches up and down (`lift`, printed by LightGateArt), and
## MapInfo.light_gates keeps whether each is up, for what light and sight pass (MapInfo.solid_at).

## How fast the portcullis winches up or down (its whole height a second, times this), and how far
## up it goes (as a switch gate's).
const LIFT_SPEED: float = 3.0
const UP_LIFT: float = 0.75
## How far either side of its middle (px, past half a cell) light is looked for, and how high.
const LOOK: Vector2 = Vector2(10.0, -20.0)

var map_info: MapInfo
## Its cell; whether it is a sun gate (else a shade gate); whether it is up, and how far (for the art).
var cell: Vector2i = Vector2i(-1, -1)
var sun: bool = true
var up: bool = false
var lift: float = 0.0
## The physics layers it blocks on while down (from the prefab).
var _layer: int = 4


func setup(info: MapInfo, v: Vector2i, is_sun: Variant) -> void:
	map_info = info
	cell = v
	sun = bool(is_sun)
	info.light_gates[v] = false


func _ready() -> void:
	_layer = collision_layer


## Whether light falls on it, either side.
func lit() -> bool:
	if map_info == null:
		return false
	var half: float = float(map_info.tile_map.tile_set.tile_size.x) * map_info.tile_map.global_scale.x * 0.5
	for side: float in [-1.0, 1.0]:
		if Lamplight.at(global_position + Vector2(side * (half + LOOK.x), LOOK.y)):
			return true
	return false


## Whether it blocks the way.
func shut() -> bool:
	return collision_layer != 0


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
	up = lit() == sun
	if up:
		collision_layer = 0
	elif not shut() and not _holds_wizard():
		collision_layer = _layer
	if map_info != null:
		map_info.light_gates[cell] = not shut()
	lift = move_toward(lift, 0.0 if shut() else UP_LIFT, LIFT_SPEED * delta)
