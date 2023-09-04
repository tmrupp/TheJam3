extends TextureProgressBar

var duration = 0.0
var elapsed = 0.0

func enable (_duration, progress=Color.DARK_GREEN, under=Color.GRAY, over=Color.hex(0x0)):
	tint_over = over
	tint_progress = progress
	tint_under = under
	
	duration = _duration 
	value = 0
	elapsed = 0.0
	visible = true
	
func disable ():
	visible = false
	
func _ready():
#	enable(10.0)
	pass
	
func _process(delta):
	if visible:
		if (elapsed >= duration):
			disable()
		else:
			set_as_ratio(elapsed/duration)
			elapsed += delta
