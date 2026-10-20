extends StaticBody2D
class_name PhaseBlock
## A sun block or a shade block, in the cemetery's crypts (Crypts.phase): a cell of dressed stone
## that is solid only to a wizard in the right light. A sun block is solid while the flame of the
## lantern they carry burns (MapInfo.flame_lit), a shade block while it is out; the other kind is a
## ghost of itself they pass straight through. In the cemetery a dash switches the light (MapInfo.
## dash_switch), so a run of blocks is climbed or crossed by switching in mid-move, at a charge of
## darkness for each time the dark is left. Like a light gate it turns solid only once the wizard is
## clear of it, so a switch never traps them. It stops only the wizard (its own physics layer, which
## nothing else looks at), never light or sight, and keeps no record.

## How fast it turns from a ghost to firm and back, for the art (its whole way a second, times this).
const FIRM_SPEED: float = 6.0

var map_info: MapInfo
## Its cell, and whether it is a sun block (else a shade block).
var cell: Vector2i = Vector2i(-1, -1)
var sun: bool = true
## 0 a ghost .. 1 firm (the art eases between them).
var firm: float = 0.0
## The physics layers it blocks on while firm (from the prefab).
var _layer: int = 0


func setup(info: MapInfo, v: Vector2i, is_sun: Variant) -> void:
	map_info = info
	cell = v
	sun = bool(is_sun)


func _ready() -> void:
	_layer = collision_layer
	collision_layer = 0


## Whether it would bear the wizard now: a sun block while their flame burns, a shade block while it
## is out; neither while they drift as an astral projection.
func bears() -> bool:
	if map_info == null or map_info.run == null:
		return sun
	var player: Player = map_info.player
	if player != null and is_instance_valid(player) and player.phasing:
		return false
	return map_info.flame_lit() == sun


## Whether it is solid now.
func solid() -> bool:
	return collision_layer != 0


## Whether the wizard's body overlaps the block's.
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
	if not bears():
		collision_layer = 0
	elif not solid() and not _holds_wizard():
		collision_layer = _layer
	firm = move_toward(firm, 1.0 if solid() else 0.0, FIRM_SPEED * delta)
