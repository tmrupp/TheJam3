extends Area2D

@onready var player = $"/root/Main/Player"
@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"

var touching = false
func untouch(other):
	if (other == player and other.get_parent() != null):
		touching = false
	
func touch(other):
	if (other == player and other.get_parent() != null):
		touching = true

func _input(event):
	if touching:
		if event.is_action_pressed("Discover"):
			if map_info.can_backtrack():
				map_info.backtrack()

func setup(_map_info, _v):
	pass
		
func _ready():
	player.respawn = self
	connect("body_entered", touch)
	connect("body_exited", untouch)
