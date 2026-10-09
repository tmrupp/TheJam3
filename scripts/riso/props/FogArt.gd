extends RisoProp
## Sleep fog, in the shape the F7 panel picks (RisoFog), or the original banks of mist.


## Sleep fog: a bank of mist, low drifting bands each lifting the night toward the paper in soft
## steps (an outer wisp, then denser toward the middle), sliding to and fro at their own pace;
## a faint pink wash low down and a few pink motes rising through it say it is not harmless.
func _draw_art() -> void:
	var style: StringName = RisoPrint.instance.fog_style if RisoPrint.instance != null else &"shroud"
	if style == &"original":
		_fog_original()
	else:
		RisoFog.draw(ink, t, phase, style)


func _fog_original() -> void:
	var mid: Vector2 = Vector2(0, -float(SleepFog.RISE))
	var size: Vector2 = SleepFog.SIZE
	var lift: Array[PackedVector2Array] = []
	var lowest: Array[PackedVector2Array] = []
	for band: int in range(5):
		var r: float = RisoShapes.hash1(float(band) * 3.7 + phase)
		var cy: float = mid.y + (float(band) - 2.0) * size.y * 0.15
		var cx: float = sin(t * (0.18 + 0.07 * float(band)) + phase + float(band) * 1.7) * size.x * 0.1
		var long: float = size.x * (0.6 + 0.35 * r)
		for layer: int in range(3):
			var k: float = 1.0 - float(layer) * 0.3
			var thick: float = size.y * (0.13 + 0.06 * r) * k
			var top: PackedVector2Array = PackedVector2Array()
			var under: PackedVector2Array = PackedVector2Array()
			for i: int in range(17):
				var u: float = float(i) / 16.0
				var x: float = cx + (u - 0.5) * long * k
				var swell: float = pow(sin(PI * u), 0.7) * (1.0 + 0.3 * sin(u * 9.0 + t * 0.5 + float(band) * 2.0))
				top.append(Vector2(x, cy - thick * swell))
				under.append(Vector2(x, cy + thick * 0.55 * swell))
			under.reverse()
			top.append_array(under)
			var lens: PackedVector2Array = RisoShapes.smooth(top, 2)
			lift.append(lens)
			if band == 4 and layer == 0:
				lowest.append(lens)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.14, lift)
	ink.ink(RisoPrint.PINK, 0.12, lowest, false)
	var motes: Array[PackedVector2Array] = []
	var halos: Array[PackedVector2Array] = []
	for m: int in range(4):
		var u: float = fmod(t * 0.07 + float(m) * 0.25 + phase, 1.0)
		var x: float = (RisoShapes.hash1(float(m) * 5.1 + phase) - 0.5) * size.x * 0.7 + sin(t * 0.6 + float(m)) * 14.0
		var y: float = mid.y + size.y * 0.3 - u * size.y * 0.7
		var twinkle: float = 0.5 + 0.5 * sin(t * 3.0 + float(m) * 2.1)
		motes.append(RisoShapes.circle(Vector2(x, y), 5.0 + 3.0 * twinkle, 12))
		halos.append(RisoShapes.circle(Vector2(x, y), 16.0 + 6.0 * twinkle, 16))
	ink.ink(RisoPrint.PINK, 0.18, halos, false)
	ink.ink(RisoPrint.PINK, 0.8, motes, false)
