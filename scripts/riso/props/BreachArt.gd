extends CreatureArt
## A breach in an institute floor (Breach): a jagged crack across the floor's top, dark, with the
## deep's pink light welling up out of it, pulsing; as something comes up it swells brighter and
## tentacle tips grope up out of the crack.

## How wide the crack is across the floor (px), and how high its glow wells up.
const WIDE: float = 92.0
const WELL: float = 70.0


func _draw_art() -> void:
	var b: Breach = host as Breach
	var g: float = _ground()
	var surge: float = clampf(b.surging / Breach.SURGE, 0.0, 1.0) if b != null and b.surging >= 0.0 else 0.0
	var pulse: float = 0.5 + 0.5 * sin(t * 2.0 + phase)
	# The glow welling up out of it.
	var glow: PackedVector2Array = RisoShapes.ellipse(Vector2(0, g - 8.0), WIDE * (0.55 + 0.15 * surge), WELL * (0.35 + 0.15 * pulse + 0.4 * surge), 24)
	ink.ink(RisoPrint.PINK, 0.22 + 0.1 * pulse + 0.3 * surge, [glow])
	# The crack: a jagged dark gash across the floor's lip, glowing pink inside.
	var top: PackedVector2Array = PackedVector2Array()
	var bottom: PackedVector2Array = PackedVector2Array()
	for i: int in range(9):
		var u: float = float(i) / 8.0
		var x: float = lerpf(-WIDE * 0.5, WIDE * 0.5, u)
		var open: float = sin(u * PI) * (9.0 + 3.0 * surge)
		var jag: float = (3.0 if i % 2 == 0 else -2.0) * sin(u * PI)
		top.append(Vector2(x, g - open * 0.4 + jag))
		bottom.append(Vector2(x, g + open + jag * 0.5))
	bottom.reverse()
	var gash: PackedVector2Array = top + bottom
	ink.ink(RisoPrint.NIGHT, 1.0, [gash], false)
	var inner: PackedVector2Array = Transform2D(0.0, Vector2(0.75, 0.5), 0.0, Vector2(0, g + 2.0)) * Transform2D(0.0, Vector2(0, -g)) * gash
	ink.ink(RisoPrint.PINK, 0.55 + 0.35 * pulse + 0.1 * surge, [inner])
	if surge > 0.0:
		var tips: Array[PackedVector2Array] = []
		for i: int in range(3):
			var x: float = (float(i) - 1.0) * 24.0
			var up: float = surge * (26.0 + float(i % 2) * 14.0)
			var sway: float = sin(t * 6.0 + float(i) * 2.0) * 6.0
			tips.append_array(RisoDecor.strip(PackedVector2Array([Vector2(x, g + 4.0), Vector2(x + sway * 0.5, g - up * 0.5), Vector2(x + sway, g - up)]), 7.0, 1.5))
		ink.ink(RisoPrint.PINK, 1.0, tips)
