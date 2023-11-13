extends Area2D

@onready var player: Player = $"/root/Main/Player"
@onready var code_menu: CodeMenu = $"/root/Main/CodeMenu"
@onready var map_info: MapInfo = $"/root/Main/CanvasLayer/MapInfo"
@onready var door: Node = $".."

func crack (key: String) -> void:
	map_info.remove_valid_key(key)
	door.queue_free()

func interacted () -> void:
	code_menu.enable("", map_info.valid_keys, crack)

func _ready() -> void:
	$Interactable.connect("interacted", interacted)
