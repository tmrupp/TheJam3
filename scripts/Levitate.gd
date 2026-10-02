extends Node
class_name Levitate
## Levitate, a spell: press Spell in the air to stop falling and hold your height, moving
## sideways at walking pace, until you press Spell again (or land). One float per touch of the
## ground (or a moon). Tiers: II lets the stick drift you slowly up and down while floating;
## III brings the float back without landing.

## The stick moves you up and down while floating (tier II).
var drift: bool = false
## A new float is ready the moment the last one ends, without landing (tier III).
var free_recast: bool = false
## A float is ready (comes back on landing).
var charged: bool = true

@onready var player: Player = get_parent() as Player


func floating() -> bool:
	return player != null and player.levitating


func toggle() -> void:
	if floating():
		stop()
	elif charged and not player.is_on_floor():
		start()


func start() -> void:
	charged = false
	player.levitating = true
	player.velocity.y = 0.0
	player.visual_event.emit(&"levitate", player.global_position)
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"levitate")


func stop() -> void:
	player.levitating = false
	if free_recast:
		charged = true


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	if player.is_on_floor():
		if floating():
			stop()
		charged = true
