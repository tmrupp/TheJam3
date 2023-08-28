extends Area2D

@onready var player = $"../Player"
@onready var map_info = $"../CanvasLayer/MapInfo"

@onready var upgrade_menu = $"/root/Main/UpgradeMenu"
@onready var main = get_tree().get_root().get_child(0)

func setup(_map_info, _v):
	pass

func touch(other):
	if (other == player and other.get_parent() != null):
		upgrade_menu.present()
		map_info.generate()
	
func _ready() -> void:
	connect("body_entered", touch)
	
