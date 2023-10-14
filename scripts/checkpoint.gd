extends Area2D

class_name Checkpoint

@onready var player = $"/root/Main/Player"
@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"

func setup(_map_info, _v):
	pass

func enabled (val):
	$Sprite2D.self_modulate = Color.GREEN_YELLOW if val else Color.WHITE

func interacted ():
	if player.respawn is Checkpoint:
		player.respawn.enabled(false)
	player.respawn = self
	enabled(true)

func _ready():
	$Interactable.connect("interacted", interacted)
	
