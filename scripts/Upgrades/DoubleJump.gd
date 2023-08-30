extends Node

@onready var player = $".."
# Called when the node enters the scene tree for the first time.
func _ready():
	player.MAX_JUMPS = 2
	player.jumps = 2
	pass # Replace with function body.
