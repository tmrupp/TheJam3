extends Area2D

@onready var collision = $CollisionShape2D
var stunned = false : set = set_stunned

func set_stunned (value):
	collision.disabled = value
