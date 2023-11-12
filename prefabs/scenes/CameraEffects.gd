extends Camera2D

var stored_delta: float = 0
var rng = RandomNumberGenerator.new()
	
func _process(delta):
	stored_delta = delta

func shake(intensity: float, direction: Vector2 = Vector2.ZERO) -> void:
	while intensity > 0.01:
		print("intensity: " + str(intensity))
		offset = Vector2(rng.randf_range(-intensity, intensity), rng.randf_range(-intensity, intensity))
		intensity = lerpf(intensity, 0, 1 - pow(0.1, stored_delta))
		await get_tree().process_frame
	offset = Vector2.ZERO
