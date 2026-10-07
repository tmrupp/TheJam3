extends Area2D
class_name HitBox
## An enemy's touch: it hurts the wizard, except while the enemy is stunned (see Stunner).

@onready var collision: CollisionShape2D = $CollisionShape2D
var stunned: bool = false : set = set_stunned

func set_stunned (value: bool) -> void:
	stunned = value
	collision.set_deferred("disabled", value)
