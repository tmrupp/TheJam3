extends RisoProp
## Thorns. Still: printed once.


func _draw_art() -> void:
	var spikes: Array[PackedVector2Array] = []
	for i: int in range(4):
		var x: float = -47.25 + float(i) * 31.5
		spikes.append(RisoShapes.tri(Vector2(x - 13, half + 2.0), Vector2(x, half - 40.0), Vector2(x + 13, half + 2.0)))
	ink.ink(RisoPrint.PINK, 1.0, spikes)

func still() -> bool:
	return true
