extends Area2D
class_name Draught
## A mending draught, a reward kept in a crag tower's room (CragsArchetype.place_tower_rewards): a
## drop of ember light floating in the air. Touched while hurt, it mends HEAL health and is gone
## for good (the level record keeps it taken); at full health it is left where it is, for later.

## Health it mends.
const HEAL: int = 1


func _ready() -> void:
	body_entered.connect(_touch)


func _process(_delta: float) -> void:
	# A wizard already standing in it when it is wanted (hurt while touching it).
	for body: Node2D in get_overlapping_bodies():
		_touch(body)


func _touch(body: Node) -> void:
	var player: Player = body as Player
	if player == null or is_queued_for_deletion() or player.health.health >= player.health.max_health:
		return
	player.health.health = mini(player.health.health + HEAL, player.health.max_health)
	RisoFx.burst(&"gain", global_position, Vector2.ZERO, [RisoPrint.EYE, RisoPrint.ACCENT])
	if MapInfo.instance != null:
		MapInfo.instance.mark_taken(self)
		MapInfo.instance.save_run()
	queue_free()
