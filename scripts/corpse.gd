extends Area2D

@onready var player = $"/root/Main/Player"

var value = 1

func touch (other):
	if other == player:
		player.collect(value)
		queue_free()
		
func player_died ():
	queue_free()
		
func setup (_value):
	value = _value
	pass
	
# Called when the node enters the scene tree for the first time.
func _ready():
	connect("body_entered", touch)
	player.connect("died", player_died)
