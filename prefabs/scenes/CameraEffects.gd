extends Camera2D

var stored_delta: float = 0
var rng = RandomNumberGenerator.new()

# in order to have access to delta time in a non-process function
# we save it into a stored value here
func _process(delta):
	stored_delta = delta

# shake the camera by applying random offsets to the camera's location
# intensity: the radius of square within which a single camera position jump can be
# sustain: the time, in seconds, that the camera will be shaking
#
# as the duration of the shake goes on, the intensity is linearly decayed to 0
func shake(intensity: float, sustain: float, direction: Vector2 = Vector2.ZERO) -> void:
	var current_intensity = intensity
	var accumulated_time = 0
	
	while accumulated_time <= sustain:
		offset = Vector2(rng.randf_range(-current_intensity, current_intensity), rng.randf_range(-current_intensity, current_intensity))
		current_intensity = lerpf(intensity, 0, accumulated_time / sustain)
		accumulated_time += stored_delta
		await get_tree().process_frame
		
	offset = Vector2.ZERO
