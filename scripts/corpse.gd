extends Area2D

@onready var player: Player = $"/root/Main/Player"

var value := 1

func touch (other: Node) -> void:
	if other == player:
		player.collect(value)
		queue_free()
		
func player_died () -> void:
	queue_free()
		
func setup (_value) -> void:
	value = _value
	
# Called when the node enters the scene tree for the first time.
func _ready():
	connect("body_entered", touch)
	player.connect("died", player_died)
