extends Area2D

class_name Checkpoint

@onready var player: Player = $"/root/Main/Player"

func enabled (val: bool) -> void:
	$Sprite2D.self_modulate = Color.GREEN_YELLOW if val else Color.WHITE

func interacted () -> void:
	if player.respawn is Checkpoint:
		player.respawn.enabled(false)
	player.respawn = self
	enabled(true)

func _ready() -> void:
	$Interactable.connect("interacted", interacted)
	
