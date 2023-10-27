extends Node

@onready var player: Player = $".."
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.MAX_JUMPS = 2
	player.jumps = 2
	pass # Replace with function body.
