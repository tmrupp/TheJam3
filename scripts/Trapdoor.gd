extends StaticBody2D
class_name Trapdoor
## A trapdoor, in the hatch through a crag watchtower's roof (CragsArchetype._tower): a slab of
## stone across the top of its cell, walked on from the roof like the roof itself, that only opens
## from inside. Whenever the wizard comes up under it (in its Under area: its own cell and the one
## below, a cell either side, below the slab), it swings open for good, and the level record keeps
## it open (MapInfo.mark_opened), so the tower's top is a way out that is first earned from within.

## How thick the slab is, down from the top of its cell, and half a level cell (pixels; its prefab's
## shapes are drawn to these).
const SLAB: float = 18.0
const HALF: float = 64.0

var map_info: MapInfo

@onready var _under: Area2D = $Under


func _ready() -> void:
	map_info = MapInfo.instance
	_under.body_entered.connect(_came_under)


## Whether `body`, now in the Under area, is the wizard below the slab.
func _came_under(body: Node) -> void:
	var player: Player = body as Player
	if player == null or is_queued_for_deletion():
		return
	if player.global_position.y > global_position.y - HALF + SLAB:
		open()


## Swing open, for good.
func open() -> void:
	if is_queued_for_deletion():
		return
	RisoFx.burst(&"rubble", global_position + Vector2(0.0, -HALF + SLAB), Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
	if map_info != null:
		map_info.mark_opened(self)
		map_info.save_run()
	queue_free()
