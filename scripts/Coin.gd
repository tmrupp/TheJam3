extends Area2D

@onready var player = $"/root/Main/Player"

func touch (other):
	if other == player:
		player.collect(1)
		queue_free()
		
func setup (_map_info, _v):
	pass
	
# Called when the node enters the scene tree for the first time.
func _ready():
	connect("body_entered", touch)
