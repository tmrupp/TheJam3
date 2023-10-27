extends Area2D

@onready var player: Player = $"/root/Main/Player"

func touch (other: Node) -> void:
	if other == player:
		player.collect(1)
		queue_free()
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("body_entered", touch)
