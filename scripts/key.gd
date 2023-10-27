extends Area2D

@onready var player: Player = $"/root/Main/Player"
@onready var keys: Node = $"/root/Main/CanvasLayer/HUD/Keys"

@export var code : String
func setup(_map_info: MapInfo, _v: Vector2) -> void:
	code = _map_info.get_next_key()

func touch(other: Node) -> void:
	if (other == player and other.get_parent() != null):
		keys.add_key(code)
		queue_free()
	
func _ready() -> void:
	connect("body_entered", touch)
	
