extends Area2D
class_name HitBox
## An enemy's touch: it hurts the wizard, except while the enemy is stunned (see Stunner). It covers
## the enemy's body as printed (sized and placed in its prefab; an abomination fits its own round
## its blobs, fit), and spells strike the enemy anywhere in it (SpellStrike.body_of).

@onready var collision: CollisionShape2D = $CollisionShape2D
var stunned: bool = false : set = set_stunned


## Cover `rect` (from the enemy's origin, px), with a box of its own (the prefab's shape is shared by
## every enemy); nothing for an empty rect.
func fit(rect: Rect2) -> void:
	if not rect.has_area():
		return
	# In its own units: an enemy's prefab may be drawn at another scale.
	var s: Vector2 = global_scale.abs() if is_inside_tree() else Vector2.ONE
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size / s
	collision.shape = box
	position = Vector2.ZERO
	collision.position = rect.get_center() / s

func set_stunned (value: bool) -> void:
	stunned = value
	collision.set_deferred("disabled", value)
