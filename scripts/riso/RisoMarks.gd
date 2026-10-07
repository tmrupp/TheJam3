class_name RisoMarks
extends RefCounted
## Printed marks shared by the props, the printed map, the HUD and the prompts: keys and their
## bows (one shape per colour), padlocks and gates, the switch emblem, chains, the wizard's ghost,
## chevrons and a smoke thread. Pure shapes and ink, drawn into whatever InkCanvas is given.


## The same colour-to-shape identity on keys, lock faces and map marks.
## Sun = square, ember = triangle, moss = circle, plum = diamond; skeleton keys are a bone.
static func key_bow(c: Vector2, r: float, color: int) -> PackedVector2Array:
	if color == KeyRing.SKELETON:
		return bone(c, r, r * 0.7)
	match posmod(color, MapInfo.KEY_COLOR_COUNT):
		1: return RisoShapes.tri(c + Vector2(0, -r), c + Vector2(r, r), c + Vector2(-r, r))
		2: return RisoShapes.circle(c, r, 24)
		3: return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	return RisoShapes.rrect(c.x - r, c.y - r, r * 2.0, r * 2.0, r * 0.12)


## Teeth past the bit of a rarer key, one per step of rarity (MapInfo.KEY_RARITY): how far down
## each hangs, in turn.
const KEY_TEETH: Array[float] = [8.0, 10.0, 7.0]
## Teeth past a skeleton key's bit, as a moss key's (see KEY_TEETH).
const SKELETON_TEETH: int = 2


## A bone `hw` across and `hh` high from its middle out, centred on `c`: a bar with two round knobs
## at each end.
static func bone(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return Transform2D(0.0, Vector2(hw, hh), 0.0, c) * RisoShapes.smooth(PackedVector2Array([
		Vector2(-0.62, -0.42), Vector2(0.62, -0.42), Vector2(0.78, -1.0), Vector2(1.0, -0.62), Vector2(0.9, 0.0),
		Vector2(1.0, 0.62), Vector2(0.78, 1.0), Vector2(0.62, 0.42), Vector2(-0.62, 0.42), Vector2(-0.78, 1.0),
		Vector2(-1.0, 0.62), Vector2(-0.9, 0.0), Vector2(-1.0, -0.62), Vector2(-0.78, -1.0)]))


## A key with a colour-specific bow, in world pixels, centred near `o`. The rarer its colour, the
## longer its shaft and the more teeth on its bit (a plum key has four), so rarity reads at a glance.
static func key_shape(o: Vector2, s: float, color: int = 0) -> Array[PackedVector2Array]:
	# A skeleton key has the bit of a rare key (three teeth) and a bone's knobbed base for its bow.
	var skeleton: bool = color == KeyRing.SKELETON
	var extra: int = SKELETON_TEETH if skeleton else clampi(color, 0, KEY_TEETH.size())
	var c: Vector2 = o - Vector2(2.5 * extra, 0) * s
	var out: Array[PackedVector2Array] = []
	if skeleton:
		out.append(RisoShapes.circle(c + Vector2(-14, -5) * s, 6.0 * s, 16))
		out.append(RisoShapes.circle(c + Vector2(-14, 5) * s, 6.0 * s, 16))
		out.append(RisoShapes.rrect(c.x - 15.0 * s, c.y - 3.5 * s, 14.0 * s, 7.0 * s, 3.5 * s))
	else:
		out.append(key_bow(c + Vector2(-10, 0) * s, 11.0 * s, color))
	out.append(RisoShapes.rrect(c.x - 3.0 * s, c.y - 3.5 * s, (24.0 + 5.0 * extra) * s, 7.0 * s, 3.5 * s))
	out.append(RisoShapes.rrect(c.x + 12.0 * s, c.y, 6.0 * s, 11.0 * s, 3.0 * s))
	for k: int in range(extra):
		out.append(RisoShapes.rrect(c.x + (20.0 + 5.0 * k) * s, c.y, 3.0 * s, KEY_TEETH[k] * s, 1.5 * s))
	return out


## The wizard's astral silhouette where they died, in glow ink, with the stars it holds circling.
static func ghost_shape(at: Transform2D, facing: float = 1.0) -> Array[PackedVector2Array]:
	return [
		at * RisoShapes.smooth(PackedVector2Array([Vector2(-3.8, -15), Vector2(-6.6, -7), Vector2(-9, -2.2), Vector2(9, -2.2), Vector2(6.6, -7), Vector2(3.8, -15)])),
		at * RisoShapes.smooth(PackedVector2Array([Vector2(-5, -21.4), Vector2(-2.9, -28.4), Vector2(-facing * 4.6, -37), Vector2(2.9, -28.4), Vector2(5, -21.4)])),
	]


static func chevron(at: Vector2, dir: Vector2, k: float) -> PackedVector2Array:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	return PackedVector2Array([at + dir * 10.0 * k, at + (side * 22.0 - dir * 12.0) * k, at + (side * 16.0 - dir * 18.0) * k,
		at - dir * 2.0 * k, at + (-side * 16.0 - dir * 18.0) * k, at + (-side * 22.0 - dir * 12.0) * k])


## The switch emblem (also on its gate): a lever leaning out of a round base, about 20 * `s` wide.
static func switch_emblem(c: Vector2, s: float) -> Array[PackedVector2Array]:
	return [RisoShapes.rrect(c.x - 9.0 * s, c.y + 2.0 * s, 18.0 * s, 6.0 * s, 3.0 * s), Transform2D(0.55, c + Vector2(0, 3.0) * s) * RisoShapes.rrect(-1.8 * s, -12.0 * s, 3.6 * s, 13.0 * s, 1.8 * s),
		RisoShapes.circle(c + Vector2(6.6, -7.0) * s, 3.4 * s, 12)]


## A portcullis filling its corridor cell: a header beam at the ceiling, four iron bars ending
## in spikes just above the floor, and one cross-rail hung with a padlock in the key colour it
## needs (padlock; a switch gate shows the switch's emblem on a paper plate instead). `lift` (0 closed, 1 open) winches the grate up into the header: the bars
## shorten from the bottom. `fade` scales every ink.
static func portcullis(ink: InkCanvas, g: float, half: float, key_color: int, lift: float, fade: float) -> void:
	var top: float = g - 2.0 * half
	var bottom: float = lerpf(g - 14.0, top + 14.0, clampf(lift, 0.0, 1.0))
	var span: float = bottom - (top + 10.0)
	if span > 6.0:
		var iron: Array[PackedVector2Array] = []
		for k: int in range(4):
			var x: float = -39.0 + 26.0 * float(k)
			iron.append(RisoShapes.rrect(x - 6.0, top + 10.0, 12.0, span, 4.0))
			iron.append(RisoShapes.tri(Vector2(x - 8.0, bottom - 3.0), Vector2(x + 8.0, bottom - 3.0), Vector2(x, bottom + 12.0)))
		var ly: float = top + 10.0 + span * 0.5
		iron.append(RisoShapes.rrect(-52, ly - 6.0, 104, 12, 6))
		_gate_iron(ink, key_color, fade, iron)
		if span > 40.0:
			if key_color < 0:
				# A switch gate: the switch's emblem (a lever in a ring) on a paper plate.
				var plate: PackedVector2Array = RisoShapes.rrect(-19, ly - 14.0, 38, 28, 8)
				ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [plate])
				ink.ink(RisoPrint.NIGHT, fade, switch_emblem(Vector2(0, ly), 0.9), false)
			else:
				# A padlock in its key's colour hangs from the cross-rail, as on a cemetery's bells.
				padlock(ink, Vector2(0, ly - 4.0), key_color, 1.6, fade)
	_gate_iron(ink, key_color, fade, [RisoShapes.rrect(-half, top - 2.0, 2.0 * half, 14, 4)])


## A gate's ironwork: blue, or for a bone gate (a skeleton lock), pale bone grey.
static func _gate_iron(ink: InkCanvas, key_color: int, fade: float, polys: Array[PackedVector2Array]) -> void:
	if key_color == KeyRing.SKELETON:
		ink.lift_ink(RisoPrint.ALL_PLATES, 0.72 * fade, polys)
	else:
		ink.ink(RisoPrint.BLUE, fade, polys)


## A padlock on `c` (its body's top middle), `s` its size: a pale body tinted with its key's
## colour (pale, so it reads even on something of that colour), a dark shackle and keyhole.
## Bells, lateral exits and the garden's gates hang the same one.
static func padlock(ink: InkCanvas, c: Vector2, color: int, s: float, fade: float) -> void:
	var body: PackedVector2Array = RisoShapes.rrect(c.x - 11.0 * s, c.y, 22.0 * s, 17.0 * s, 4.0 * s)
	var shackle: Array[PackedVector2Array] = RisoDecor.strip(PackedVector2Array([c + Vector2(-6.5, 1) * s, c + Vector2(-6.5, -7) * s, c + Vector2(0, -12) * s, c + Vector2(6.5, -7) * s, c + Vector2(6.5, 1) * s]), 3.4 * s, 3.4 * s)
	ink.ink(RisoPrint.NIGHT, fade, shackle, false)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], 0.9 * fade, [body])
	# A skeleton lock's body stays bare bone-white; the rest are tinted with their colour.
	if color != KeyRing.SKELETON:
		for plate: int in RisoPrint.key_inks(color):
			ink.ink(plate, 0.8 * fade, [body], false)
	ink.ink(RisoPrint.NIGHT, fade, [key_bow(c + Vector2(0, 6.5) * s, 4.5 * s * (1.3 if color == KeyRing.SKELETON else 1.0), color)], false)


## A switch's plate on `c` where a padlock would hang: a dark plate with the switch emblem.
static func switch_plate(ink: InkCanvas, c: Vector2, s: float, fade: float) -> void:
	ink.ink(RisoPrint.NIGHT, fade * 0.9, [RisoShapes.rrect(c.x - 12.0 * s, c.y - 4.0 * s, 24.0 * s, 22.0 * s, 5.0 * s)], false)
	ink.ink(RisoPrint.ACCENT, fade, switch_emblem(c + Vector2(0, 7.0) * s, 0.55 * s), false)


## A chain along `path`: links `link` long, alternating an open loop seen face on and a bar seen
## edge on, `w` thick, in `plate`.
static func chain(ink: InkCanvas, path: PackedVector2Array, link: float, w: float, plate: int, cover: float) -> void:
	var polys: Array[PackedVector2Array] = []
	var k: int = 0
	for i: int in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var along: float = (b - a).angle()
		var n: int = maxi(1, int(a.distance_to(b) / (link * 0.78)))
		for j: int in range(n):
			var p: Vector2 = a.lerp(b, (float(j) + 0.5) / float(n))
			if k % 2 == 0:
				polys.append_array(RisoDecor.strip(loop_points(p, link * 0.55, link * 0.32, along), w, w))
			else:
				polys.append(Transform2D(along, p) * RisoShapes.rrect(-link * 0.45, -w * 0.75, link * 0.9, w * 1.5, w * 0.75))
			k += 1
	ink.ink(plate, cover, polys)


## Points round an oval `rx` by `ry` on `c`, turned by `angle`, closed (for a loop of chain).
static func loop_points(c: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in range(17):
		var a: float = TAU * float(k) / 16.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return out


static func arc_points(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in range(9):
		var a: float = lerpf(a0, a1, float(k) / 8.0)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## One narrow curling strand, attached to the wick and fading away as it rises. Used both on
## burned-out lanterns in the world and on the HUD's extinguished protection candle.
static func smoke_thread(canvas: InkCanvas, frame: Transform2D, time: float, height: float,
		width: float, drift: float, punch: bool = false) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var widths: PackedFloat32Array = PackedFloat32Array()
	var covers: PackedFloat32Array = PackedFloat32Array()
	const SECTIONS: int = 24
	for i: int in range(SECTIONS + 1):
		var u: float = float(i) / float(SECTIONS)
		var curl: float = drift * pow(u, 0.7) * sin(u * TAU - time * 1.8)
		points.append(Vector2(curl, -height * u))
		widths.append(width * 0.5 * lerpf(1.0, 0.35, u))
		covers.append(0.45 * (1.0 - smoothstep(0.4, 1.0, u)))
	# Keep the whole strand in one polygon: the print renderer discards tiny isolated shapes,
	# so individual cross-sections would disappear even when the full thread is visible.
	var outline: PackedVector2Array = PackedVector2Array()
	var alpha: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(SECTIONS + 1):
		outline.append(points[i] + Vector2(-widths[i], 0))
		alpha.append(covers[i])
	for i: int in range(SECTIONS, -1, -1):
		outline.append(points[i] + Vector2(widths[i], 0))
		alpha.append(covers[i])
	canvas.ink_graded(RisoPrint.PINK, [frame * outline], [alpha], punch)


## Bending, for the creatures: a point turns about the feet (the origin) by `amount`, scaled by how
## high it is over `tall` (squared), so a body curls rather than tilting stiffly or squashing.
static func bent_v(p: Vector2, amount: float, tall: float) -> Vector2:
	var u: float = clampf(-p.y / tall, 0.0, 1.4)
	return p.rotated(amount * u * u)


static func bent(poly: PackedVector2Array, amount: float, tall: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(poly.size())
	for i: int in range(poly.size()):
		out[i] = bent_v(poly[i], amount, tall)
	return out
