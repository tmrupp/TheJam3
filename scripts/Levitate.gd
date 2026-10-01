extends Node
class_name Levitate
## Levitate, a spell: press Spell to stop falling and float, drifting with the stick (up and down
## slowly, sideways at walking pace) until it runs out or you press Spell again. One float per
## touch of the ground (or a moon). Tiers make it last longer.

var duration: float = 1.5
var left: float = 0.0
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
	left = duration
	player.levitating = true
	player.velocity.y = 0.0
	player.visual_event.emit(&"levitate", player.global_position)
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"levitate")


func stop() -> void:
	player.levitating = false
	left = 0.0


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if floating():
		left -= delta
		if left <= 0.0:
			stop()
	if player.is_on_floor():
		if floating():
			stop()
		charged = true
