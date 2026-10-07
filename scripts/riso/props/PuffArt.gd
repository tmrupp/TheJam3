extends RisoProp
## A cloud that gives way, thinning as it wears.


## The Puff it dresses.
var puff: Puff:
	get:
		return host as Puff


## A cloud that gives way (Puff), across the top of its cell where a ledge would be: a row of
## overlapping puffs, pale (lifted night and a blue tint). Stood on, it trembles and thins as it
## wears; once it gives way it is gone, and gathers again faintly in its last second away.
func _draw_art() -> void:
	var worn: float = puff.worn()
	var gone: float = puff.gone
	var top: float = -64.0
	var grow: float = 1.0
	if gone >= 0.0:
		grow = clampf((gone - (Puff.REFORM - 1.0)) / 1.0, 0.0, 1.0)
		if grow <= 0.0:
			return
	var shake: float = sin(t * 40.0) * 3.0 * worn * worn
	var blobs: Array[PackedVector2Array] = []
	for k: int in range(5):
		var x: float = -52.0 + 26.0 * float(k) + shake
		var r: float = (16.0 + 5.0 * sin(float(k) * 2.3 + phase)) * (1.0 - 0.35 * worn) * (0.5 + 0.5 * grow)
		blobs.append(RisoShapes.circle(Vector2(x, top + 14.0 - 4.0 * sin(float(k) * 1.7 + phase)), r, 16))
	blobs.append(RisoShapes.rrect(-60.0 + shake, top + 8.0, 120.0, 18.0 * (1.0 - 0.4 * worn), 9.0))
	var solid: float = (0.85 - 0.45 * worn) * (0.35 if gone >= 0.0 else 1.0) * grow
	ink.lift_ink([RisoPrint.NIGHT], solid, blobs)
	ink.ink(RisoPrint.BLUE, 0.3 * grow, blobs, false)
	ink.ink(RisoPrint.NIGHT, 0.12 * grow, [RisoShapes.rrect(-56.0 + shake, top + 20.0, 112.0, 6.0, 3.0)], false)
