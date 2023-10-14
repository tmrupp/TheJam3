extends Node

@onready var player = $"/root/Main/Player"
signal interacted 
@onready var sprite = $Sprite2D

var touching = false
func untouch(other):
	if (other == player and other.get_parent() != null):
		touching = false
		sprite.visible = touching
	
func touch(other):
	if (other == player and other.get_parent() != null):
		touching = true
		sprite.visible = touching

func _input(event):
	if touching:
		if event.is_action_pressed("Discover"):
			interacted.emit()
		
func _ready():
	get_parent().connect("body_entered", touch)
	get_parent().connect("body_exited", untouch)
	sprite.visible = false
	sprite.global_scale = Vector2.ONE*4
	sprite.position += Vector2.UP*20
