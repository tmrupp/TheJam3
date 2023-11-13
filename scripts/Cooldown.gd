extends TextureProgressBar

class_name Cooldown

var duration: float = 0.0
var elapsed: float = 0.0

func enable (_duration: float, 
	progress: Color=Color.DARK_GREEN, 
	under: Color=Color.GRAY, 
	over: Color=Color.hex(0x0)) -> void:

	tint_over = over
	tint_progress = progress
	tint_under = under
	
	duration = _duration 
	value = 0
	elapsed = 0.0
	visible = true
	
func disable () -> void:
	visible = false
	
func _process(delta: float) -> void:
	if visible:
		if (elapsed >= duration):
			disable()
		else:
			set_as_ratio(elapsed/duration)
			elapsed += delta
