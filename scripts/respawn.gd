extends Area2D

@onready var player = $"/root/Main/Player"
@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"

func setup(_map_info, _v):
	pass
	
func interacted ():
	if map_info.can_backtrack():
		map_info.backtrack()

func _ready():
	player.respawn = self
	$Interactable.connect("interacted", interacted)
