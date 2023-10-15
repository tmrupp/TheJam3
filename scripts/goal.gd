extends Area2D

@onready var player = $"/root/Main/Player"
@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"

@onready var upgrade_menu = $"/root/Main/UpgradeMenu"
@onready var code_menu = $"/root/Main/CodeMenu"
@onready var main = get_tree().get_root().get_child(0)

@export var code : String
func setup(_map_info, _v):
	code = _map_info.world.next_code()

# code will be useful with branching
func crack (map_code):
	upgrade_menu.present()
	map_info.generate(code, map_code)

func touch(other):
	if (other == player and other.get_parent() != null):
#		print("self=", self, " player.position=", player.position, " collision=", player.get_collision())
		code_menu.enable(code, map_info.all_map_codes.keys(), crack)
		
func _ready() -> void:
	connect("body_entered", touch)
	
