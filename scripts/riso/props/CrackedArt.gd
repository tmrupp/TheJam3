extends RisoProp
## Cracked rock: a few fine cracks over the terrain's rock (none on a secret room's).


## Cracked rock: the terrain prints the cell as rock; this adds a few fine cracks in night ink
## (a seeded zigzag from each of three edges toward the middle): quiet, but there if you look.
## A secret room's cells (its hidden rock and its false-wall entrance) get none: they are plain
## rock until the room opens.
func _draw_art() -> void:
	if host.has_meta(&"secret"):
		return
	var cracks: Array[PackedVector2Array] = []
	var seed_f: float = host.global_position.x * 0.013 + host.global_position.y * 0.029
	for k: int in range(3):
		var a: float = TAU * (float(k) / 3.0 + RisoShapes.hash1(seed_f + float(k)) * 0.2)
		var p: Vector2 = Vector2(cos(a), sin(a)) * half * 0.95
		var target: Vector2 = Vector2(RisoShapes.hash1(seed_f + 7.0) - 0.5, RisoShapes.hash1(seed_f + 9.0) - 0.5) * 20.0
		var width: float = 2.2
		for s: int in range(4):
			var q: Vector2 = p.lerp(target, 0.35) + Vector2(RisoShapes.hash1(seed_f + float(k * 5 + s)) - 0.5, RisoShapes.hash1(seed_f + float(k * 5 + s) + 3.0) - 0.5) * 22.0
			var n: Vector2 = (q - p).normalized().orthogonal()
			cracks.append(PackedVector2Array([p - n * width, q - n * width * 0.7, q + n * width * 0.7, p + n * width]))
			p = q
			width *= 0.75
	ink.ink(RisoPrint.NIGHT, 0.7, cracks, false)

func still() -> bool:
	return true
