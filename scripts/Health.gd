extends Node

class_name Health

@onready var player: Player = $".."
@onready var hurt_sfx: AudioStreamPlayer = $AudioStreamPlayer
@onready var camera: Camera2D = $/root/Main/Camera2D

var max_health: int = 3
var health: int = 3

func modify_health (delta: int) -> void:
	health += delta
	
	if delta < 0:
		hurt_sfx.play()
		camera.shake(15, 0.5)
	
	if health <= 0:
		player.die()

