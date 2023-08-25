extends Node

var coins = 100
@onready var amount = $"/root/Main/CanvasLayer/TopHUD/CoinAmount"

func modify (delta):
	coins += delta
	display()

func display ():
	amount.text = ": " + str(coins)

func _ready ():
	display()
