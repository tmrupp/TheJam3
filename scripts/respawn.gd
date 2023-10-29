extends Area2D

@onready var player: Player = $"/root/Main/Player"
@onready var map_info: MapInfo = $"/root/Main/CanvasLayer/MapInfo"
	
func interacted () -> void:
	if map_info.can_backtrack():
		map_info.backtrack()

func _ready() -> void:
	player.respawn = self
	$Interactable.connect("interacted", interacted)
