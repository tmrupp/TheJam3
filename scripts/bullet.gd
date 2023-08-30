extends Node2D
@onready var area = $HitBox
@onready var player = $"/root/Main/Player"
var velocity = Vector2(1, 1).normalized()
var exclude

func setup(v, ignore, sender):
	velocity = v
	exclude = ignore
	$HitBox/Damager.attacker = sender

func touch (other):
	if other not in exclude:
#		print("bullet colliding with=", other)
		queue_free()

func _ready() -> void:
	area.connect("body_entered", touch)
	
func _process(delta):
	position += velocity*delta
