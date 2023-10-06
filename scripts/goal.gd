extends Area2D

@onready var player = $"/root/Main/Player"
@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"

@onready var upgrade_menu = $"/root/Main/UpgradeMenu"
@onready var code_menu = $"/root/Main/CodeMenu"
@onready var main = get_tree().get_root().get_child(0)

func setup(_map_info, _v):
	pass

# code will be useful with branching
func crack (_code):
	upgrade_menu.present()
	map_info.generate()

func touch(other):
	if (other == player and other.get_parent() != null):
		code_menu.enable(map_info.world.code, [map_info.map.code], crack)
		
func _ready() -> void:
	connect("body_entered", touch)
	
