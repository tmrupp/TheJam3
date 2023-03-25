extends Area2D

const TIMER = 2.0
var disabled = 0.0
var touchable = true

func touch(other):
	print("i've been touched by", other)
	if (touchable):
		other.refresh_dash()
		touchable = false
		disabled = TIMER
	
func _ready() -> void:
	connect("body_entered", touch)

func _process(delta):
	if touchable:
		modulate = Color.WHITE
	else:
		modulate = Color.GRAY

	disabled -= delta
	if disabled <= 0.0:
		touchable = true
		
