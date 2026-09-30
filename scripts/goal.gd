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
	# upgrade_menu.present()
	map_info.generate(code, map_code)

func interacted () -> void:
	# No code entry: step through to the next world with the first map still available.
	var map_codes: Array = map_info.all_map_codes.keys()
	if map_codes.is_empty():
		return
	crack(map_codes[0])
		
func _ready() -> void:
	$Interactable.connect("interacted", interacted)
	
