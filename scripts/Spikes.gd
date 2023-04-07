extends Area2D
@onready var player = $"../Player"
func touch(other):
	if other == player:
		other.die()

func _ready() -> void:
	connect("body_entered", touch)
