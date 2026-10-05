extends Node

class_name Coins

var coins: int = 0
@onready var coin_collect_sfx: AudioStreamPlayer = $AudioStreamPlayer

func modify (delta: int) -> void:
	coins += delta
	if delta > 0:
		coin_collect_sfx.play()

