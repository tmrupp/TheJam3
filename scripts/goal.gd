extends Area2D

@onready var player: Player = $"/root/Main/Player"
@onready var map_info: MapInfo = $"/root/Main/CanvasLayer/MapInfo"

@onready var upgrade_menu: Node = $"/root/Main/UpgradeMenu"
@onready var code_menu: Node = $"/root/Main/CodeMenu"

@export var code: String
func setup(_map_info: MapInfo, _v: Vector2i) -> void:
	code = _map_info.world.next_code()

# code will be useful with branching
func crack (map_code: String) -> void:
	upgrade_menu.present()
	map_info.generate(code, map_code)
	
func interacted () -> void:
	code_menu.enable(code, map_info.all_map_codes.keys(), crack)
		
func _ready() -> void:
	$Interactable.connect("interacted", interacted)
	
