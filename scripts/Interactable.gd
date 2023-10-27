extends Node

@onready var player: Player = $"/root/Main/Player"
signal interacted 
@onready var sprite: Sprite2D = $Sprite2D

var touching: bool = false
func untouch(other: Node) -> void:
	if (other == player and other.get_parent() != null):
		touching = false
		sprite.visible = touching
	
func touch(other: Node) -> void:
	if (other == player and other.get_parent() != null):
		touching = true
		sprite.visible = touching

func _input(event: InputEvent) -> void:
	if touching:
		if event.is_action_pressed("Discover"):
			interacted.emit()
		
func _ready() -> void:
	get_parent().connect("body_entered", touch)
	get_parent().connect("body_exited", untouch)
	sprite.visible = false
	sprite.global_scale = Vector2.ONE*4
	sprite.position += Vector2.UP*20
