extends Area2D

@onready var collision: CollisionShape2D = $CollisionShape2D
var stunned: bool = false : set = set_stunned

func set_stunned (value: bool) -> void:
	collision.disabled = value
