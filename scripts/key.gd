extends Area2D

@onready var player = $"../Player"

@onready var keys = $"/root/Main/CanvasLayer/HUD/Keys"

var code
func setup(_map_info, _v):
	code = _map_info.get_next_key()

func touch(other):
	if (other == player and other.get_parent() != null):
		keys.add_key(code)
		queue_free()
		
	
func _ready() -> void:
	connect("body_entered", touch)
	
