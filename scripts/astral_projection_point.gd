extends Node2D

@onready var player: Player = $"/root/Main/Player"
var active: bool = false

const COOLDOWN_TIME: float = 5.0

func astral_project() -> void:
	if not active:
		#print("used the astral projection point named " + name)
		player.astral_projection_signal.emit()
		active = true
		await get_tree().create_timer(COOLDOWN_TIME).timeout
		active = false

func _ready() -> void:
	$Area2D/Interactable.interacted.connect(astral_project)
