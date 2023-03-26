extends Area2D

@onready var player = $"../Player"
@onready var main = get_tree().get_root().get_child(0)

func _ready() -> void:
	connect("body_entered", touch)
	map_info = main.find_child("CanvasLayer").find_child("MapInfo")
#	print(main)

var map_info
func setup(_map_info):
	map_info = _map_info

func touch(other):
	if other == player:
		map_info.discover_random_chunk()
		queue_free()
