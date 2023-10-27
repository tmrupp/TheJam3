extends Area2D

const TIMER: float = 2.0
var disabled: float = 0.0
var touchable: bool = true

@onready var player: Player = $"../Player"

func touch(other: Node) -> void:
	print("i've been touched by", other)
	if (touchable and other == player):
		other.refresh_dash()
		touchable = false
		disabled = TIMER
	
func _ready() -> void:
	connect("body_entered", touch)

func _process(delta: float) -> void:
	if touchable:
		modulate = Color.WHITE
	else:
		modulate = Color.GRAY

	disabled -= delta
	if disabled <= 0.0:
		touchable = true
		
