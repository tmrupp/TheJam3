extends RisoProp
## A jump pad of cloud, squashing as it throws.


## The Pad it dresses.
var pad: Pad:
	get:
		return host as Pad


## A jump pad (Pad): a squat cushion of cloud on the floor, printed bare paper with a sun band
## through it and two chevrons of sun bobbing over it, pointing up. Throwing, it squashes flat and
## springs back, and the chevrons shoot up and fade.
func _draw_art() -> void:
	var g: float = _ground()
	var since: float = pad.since_launch
	var squash: float = 0.0
	if since < 0.5:
		squash = sin(since * 26.0) * exp(-since * 7.0)
	var sy: float = 1.0 - 0.35 * squash
	var sx: float = 1.0 + 0.2 * squash
	var puffs: Array[PackedVector2Array] = []
	for k: int in range(3):
		var x: float = (-22.0 + 22.0 * float(k)) * sx
		var r: float = (17.0 if k == 1 else 14.0) * sx
		puffs.append(RisoShapes.ellipse(Vector2(x, g - 13.0 * sy - (5.0 if k == 1 else 0.0) * sy), r, r * 0.8 * sy, 18))
	puffs.append(RisoShapes.rrect(-40.0 * sx, g - 14.0 * sy, 80.0 * sx, 14.0 * sy, 6.0))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], puffs)
	ink.ink(RisoPrint.BLUE, 0.25, [RisoShapes.rrect(-40.0 * sx, g - 7.0 * sy, 80.0 * sx, 7.0 * sy, 3.0)], false)
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.rrect(-34.0 * sx, g - 18.0 * sy, 68.0 * sx, 4.0, 2.0)], false)
	var lift: float = clampf(since * 3.0, 0.0, 1.0) if since < 0.4 else 0.0
	var chevrons: Array[PackedVector2Array] = []
	for k: int in range(2):
		var y: float = g - 52.0 - 18.0 * float(k) + sin(t * 3.0 + phase + float(k)) * 4.0 - lift * 60.0
		chevrons.append(PackedVector2Array([Vector2(-14, y + 8), Vector2(0, y - 4), Vector2(14, y + 8), Vector2(14, y + 14), Vector2(0, y + 2), Vector2(-14, y + 14)]))
	ink.ink(RisoPrint.ACCENT, 0.85 * (1.0 - lift), chevrons)
