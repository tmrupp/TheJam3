extends Area2D
class_name Coin
## A star (a star cluster gives `value` of them at once; MapInfo sets it, see cluster_value).

@onready var player: Player = Stage.player()

var value: int = 1

func touch (other: Node) -> void:
	if other == player:
		player.collect(value)
		RisoFx.burst(&"gain", global_position)
		if value > 1:
			RisoFx.burst(&"gain", global_position, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.EYE])
		if MapInfo.instance != null:
			MapInfo.instance.mark_taken(self)
			if value > 1:
				MapInfo.instance.save_run()
		queue_free()
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("body_entered", touch)
