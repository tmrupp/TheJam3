extends Node

var coins: int = 100
@onready var amount: Label = $"/root/Main/CanvasLayer/HUD/TopHUD/CoinAmount"

func modify (delta: int) -> void:
	coins += delta
	display()

func display () -> void:
	amount.text = ": " + str(coins)

func _ready () -> void:
	display()
