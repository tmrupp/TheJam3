extends Sprite2D

var player
const parallax = 0.25

func setup(_player):
	player = _player

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if player == null:
		pass
	else:
		position = player.position * parallax
