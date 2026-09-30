extends Area2D

class_name Checkpoint

@onready var player: Player = $"/root/Main/Player"

func enabled (val: bool) -> void:
	$Sprite2D.self_modulate = Color.GREEN_YELLOW if val else Color.WHITE

func interacted () -> void:
	# Lighting is optional: the last lantern lit, in any level, is where the player respawns.
	if MapInfo.instance != null:
		MapInfo.instance.light_lantern(self)
	enabled(true)

func _ready() -> void:
	$Interactable.connect("interacted", interacted)
	
