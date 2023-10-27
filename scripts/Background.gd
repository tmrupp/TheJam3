extends Sprite2D

var player: Player
const parallax: float = 0.25

func setup(_player: Player) -> void:
	player = _player

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player == null:
		pass
	else:
		position = player.position * parallax
