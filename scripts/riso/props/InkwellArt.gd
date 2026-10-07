extends RisoProp
## The ink well, its beam of light and its drop; dry once paid.


## The Inkwell it dresses.
var well: Inkwell:
	get:
		return host as Inkwell


## The ink well: a big gold-rimmed pot on the floor with a paper label, a pulsing halo, a drop of
## ink rising and falling and a quill resting in its mouth. Its price is a focused interaction
## tooltip. Once paid it is dry: no drop, no glow, a dim rim.
func _draw_art() -> void:
	var g: float = _ground()
	var dry: bool = well.used()
	var o: Vector2 = Vector2(0, g - 30.0)
	var pot_t: Transform2D = Transform2D(0.0, Vector2(2.3, 2.3), 0.0, o)
	var pulse: float = 1.0 + 0.08 * sin(t * 3.0 + phase)
	if not dry:
		# A beam of light rising out of the well, and a bright halo: you can spot it from afar.
		var beam: PackedVector2Array = PackedVector2Array([o + Vector2(-20, -10), o + Vector2(20, -10), o + Vector2(44 * pulse, -330), o + Vector2(-44 * pulse, -330)])
		ink.ink_graded(RisoPrint.ACCENT, [beam], [PackedFloat32Array([0.85, 0.85, 0.0, 0.0])])
		ink.ink(RisoPrint.ACCENT, 0.35, [RisoShapes.ellipse(o + Vector2(0, -50), 84.0 * pulse, 92.0 * pulse, 32)])
		ink.ink(RisoPrint.ACCENT, 0.6, [RisoShapes.ellipse(o + Vector2(0, -40), 52.0 * pulse, 58.0 * pulse, 28)])
	var pot: PackedVector2Array = pot_t * RisoShapes.rrect(-17, -10, 34, 24, 10)
	var neck: PackedVector2Array = pot_t * RisoShapes.rrect(-8, -18, 16, 10, 3)
	# A quill tucked into the neck, its shaft and feather behind the pot's lip.
	var quill_t: Transform2D = Transform2D(0.5, o + Vector2(0, -46))
	var feather: PackedVector2Array = quill_t * RisoShapes.almond(Vector2(0, -48), 11.0, 27.0, 20)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [feather])
	ink.ink(RisoPrint.BLUE, 0.25 if dry else 0.45, [feather], false)
	var quill_lines: Array[PackedVector2Array] = [quill_t * RisoShapes.rrect(-1.5, -72, 3, 82, 1.5)]
	for k: int in range(4):
		var y: float = -60.0 + float(k) * 9.0
		quill_lines.append_array(RisoDecor.strip(PackedVector2Array([quill_t * Vector2(-7, y - 5), quill_t * Vector2(0, y), quill_t * Vector2(7, y - 5)]), 1.4, 1.4))
	ink.ink(RisoPrint.NIGHT, 0.85, quill_lines, false)
	ink.ink(RisoPrint.BLUE, 1.0, [pot, neck])
	ink.ink(RisoPrint.NIGHT, 0.35, [pot_t * RisoShapes.rrect(3, -8, 12, 20, 6)], false)
	ink.ink(RisoPrint.ACCENT, 0.4 if dry else 1.0, [pot_t * RisoShapes.rrect(-10, -21, 20, 5, 2.5)])
	ink.ink(RisoPrint.NIGHT, 1.0, [pot_t * RisoShapes.ellipse(Vector2(0, -20), 6.0, 1.6, 12)])
	var label: PackedVector2Array = pot_t * RisoShapes.rrect(-11, -3, 18, 10, 3)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [label])
	ink.ink(RisoPrint.NIGHT, 1.0, [pot_t * RisoShapes.circle(Vector2(-2, 2), 2.4, 10)], false)
	if dry:
		return
	# The drop: rises from the mouth, hangs, falls back in.
	var u: float = fmod(t * 0.7 + phase, 1.0)
	var lift: float = sin(u * PI) * 24.0
	var d: Vector2 = pot_t * Vector2(0, -24.0) + Vector2(0, -lift)
	var drop: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([d + Vector2(0, -11), d + Vector2(7, 1), d + Vector2(0, 7), d + Vector2(-7, 1)]))
	ink.ink(RisoPrint.BLUE, 1.0, [drop])
	ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT], [RisoShapes.circle(d + Vector2(-2.5, 0), 2.4, 8)])
