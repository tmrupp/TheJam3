extends Node

var coins: int = 100
@onready var amount: Label = $"/root/Main/CanvasLayer/HUD/TopHUD/CoinAmount"
@onready var coin_collect_sfx: AudioStreamPlayer = $AudioStreamPlayer

func modify (delta: int) -> void:
	coins += delta
	display()
	if delta > 0:
		coin_collect_sfx.play()

func display () -> void:
	amount.text = ": " + str(coins)

func _ready () -> void:
	display()
