extends Node2D

@onready var player: Player = $"/root/Main/Player"
var active: bool = false

func astral_project() -> void:
	if not active:
		#print("used the astral projection point named " + name)
		player.astral_projection_signal.emit()
		active = true

func _ready() -> void:
	$Area2D/Interactable.interacted.connect(astral_project)
