extends Sprite2D

@onready var player = $"../Player"
const parallax = 0.25

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position = player.position * parallax
