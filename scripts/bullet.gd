extends Area2D

@onready var player = $"/root/Main/Player"
var velocity = Vector2(1, 1).normalized()
var exclude

func setup(v, ignore):
	velocity = v
	exclude = ignore

func touch (other):
	if other not in exclude:
		print("bullet colliding with=", other)
		queue_free()

func _ready() -> void:
	connect("body_entered", touch)
	
func _process(delta):
	position += velocity*delta
