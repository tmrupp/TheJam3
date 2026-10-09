extends RefCounted
class_name RisoFog
## Fog options differ in their outer contour and negative space. One print treatment keeps
## colour and density consistent, so F7 compares the shape rather than decorative contents.

const LIFT_PLATES: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE]
const MID: Vector2 = Vector2(0, -SleepFog.RISE)


static func draw(ink: InkCanvas, t: float, phase: float, style: StringName) -> void:
	var bodies: Array[PackedVector2Array] = silhouette(t, phase, style)
	if style == &"shroud":
		_print_ribbons(ink, bodies)
		return
	if style == &"shroud_breath":
		_print_clouds(ink, [bodies[0]])
		var ribbons: Array[PackedVector2Array] = []
		for i: int in range(1, bodies.size()):
			ribbons.append(bodies[i])
		_print_ribbons(ink, ribbons)
		return
	_print_clouds(ink, bodies)


static func _print_clouds(ink: InkCanvas, bodies: Array[PackedVector2Array]) -> void:
	ink.lift_ink(LIFT_PLATES, 0.28, bodies)
	ink.ink(RisoPrint.ACCENT, 0.06, bodies, false)
	# A softer inner print follows each contour instead of imposing a common oval around it.
	var cores: Array[PackedVector2Array] = []
	var low: Array[PackedVector2Array] = []
	for body: PackedVector2Array in bodies:
		var centre: Vector2 = Vector2.ZERO
		for p: Vector2 in body:
			centre += p
		centre /= float(body.size())
		var core: PackedVector2Array = PackedVector2Array()
		var underside: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in body:
			core.append(centre + (p - centre) * Vector2(0.92, 0.76))
			underside.append(centre + Vector2(0, 10) + (p - centre) * Vector2(0.88, 0.52))
		cores.append(core)
		low.append(underside)
	ink.lift_ink(LIFT_PLATES, 0.10, cores)
	ink.ink(RisoPrint.PINK, 0.06, low, false)


## Each ribbon has a pale body and a pink upper band, all dissolving at both ends.
static func _print_ribbons(ink: InkCanvas, bodies: Array[PackedVector2Array]) -> void:
	for body: PackedVector2Array in bodies:
		_graded_ribbon(ink, body, 0.0, 1.0, 0.28, 0.28, true)
		_graded_ribbon(ink, body, 0.0, 1.0, 0.06, 0.06, false, RisoPrint.ACCENT)
		_graded_ribbon(ink, body, 0.18, 0.82, 0.10, 0.10, true)
		_graded_ribbon(ink, body, 0.0, 0.40, 0.55, 0.10, false, RisoPrint.PINK)


## Quads follow each ribbon cross-section, so alpha changes along its length reliably.
## Whole-outline triangulation can flatten a gradient when the pointed tips coincide.
static func _graded_ribbon(ink: InkCanvas, body: PackedVector2Array, upper: float, lower: float, top_cover: float, bottom_cover: float, lift: bool, plate: int = RisoPrint.NIGHT) -> void:
	var sections: int = body.size() / 2
	var polys: Array[PackedVector2Array] = []
	var alphas: Array[PackedFloat32Array] = []
	for i: int in range(sections - 1):
		var u0: float = float(i) / float(sections - 1)
		var u1: float = float(i + 1) / float(sections - 1)
		var fade0: float = ribbon_fade(u0)
		var fade1: float = ribbon_fade(u1)
		var a: Vector2 = body[i].lerp(body[body.size() - 1 - i], upper)
		var b: Vector2 = body[i + 1].lerp(body[body.size() - 2 - i], upper)
		var c: Vector2 = body[i + 1].lerp(body[body.size() - 2 - i], lower)
		var d: Vector2 = body[i].lerp(body[body.size() - 1 - i], lower)
		if i == 0:
			polys.append(PackedVector2Array([a, b, c]))
			alphas.append(PackedFloat32Array([top_cover * fade0, top_cover * fade1, bottom_cover * fade1]))
		elif i == sections - 2:
			polys.append(PackedVector2Array([a, b, d]))
			alphas.append(PackedFloat32Array([top_cover * fade0, top_cover * fade1, bottom_cover * fade0]))
		else:
			polys.append(PackedVector2Array([a, b, c, d]))
			alphas.append(PackedFloat32Array([top_cover * fade0, top_cover * fade1, bottom_cover * fade1, bottom_cover * fade0]))
	if lift:
		ink.lift_ink_graded(LIFT_PLATES, polys, alphas)
	else:
		ink.ink_graded(plate, polys, alphas, false)


## Keep the middle readable and dissolve roughly the outer quarter of each end.
static func ribbon_fade(u: float) -> float:
	return smoothstep(0.0, 0.24, u) * (1.0 - smoothstep(0.76, 1.0, u))


## Geometry can be compared without the ink or animation overlays.
static func silhouette(t: float, phase: float, style: StringName) -> Array[PackedVector2Array]:
	match style:
		&"shroud": return _ribbons(t, phase)
		&"breath": return [_bank(t, phase, &"billows")]
		&"bleed": return [_bank(t, phase, &"ragged")]
		&"faces": return [_bank(t, phase, &"spectral")]
		&"incense": return _plumes(t, phase)
		&"shroud_breath":
			var blend: Array[PackedVector2Array] = [_bank(t, phase, &"billows")]
			blend.append(_ribbon(-250, 245, -72, 12, t, phase + 1.1))
			blend.append(_ribbon(-190, 280, -38, 10, t, phase + 3.4))
			return blend
	return [_bank(t, phase, &"billows")]


## Separate, broad, torn wisps: long points and open gaps replace a solid cloud capsule.
static func _ribbons(t: float, phase: float) -> Array[PackedVector2Array]:
	return [
		_ribbon(-278, 225, -52, 20, t, phase),
		_ribbon(-235, 285, 1, 25, t, phase + 2.0),
		_ribbon(-280, 240, 56, 18, t, phase + 4.0),
	]


static func _ribbon(left: float, right: float, y: float, width: float, t: float, phase: float) -> PackedVector2Array:
	var top: PackedVector2Array = PackedVector2Array()
	var bottom: PackedVector2Array = PackedVector2Array()
	for i: int in range(41):
		var u: float = float(i) / 40.0
		var taper: float = pow(maxf(0.0, sin(u * PI)), 0.8)
		var x: float = lerpf(left, right, u) + sin(t * 0.35 + phase) * 9.0 * taper
		var curl: float = sin(u * TAU * 1.15 + phase + t * 0.55) * 19.0 * taper
		var tear: float = 0.52 if i % 5 == 0 else (0.80 if i % 5 == 1 else 1.0)
		top.append(MID + Vector2(x, y + curl - width * taper))
		bottom.append(MID + Vector2(x, y + curl + width * taper * tear))
	bottom.reverse()
	top.append_array(bottom)
	return top


## A single connected bank: each mode has a deliberately different top and bottom profile.
static func _bank(t: float, phase: float, kind: StringName) -> PackedVector2Array:
	var top: PackedVector2Array = PackedVector2Array()
	var bottom: PackedVector2Array = PackedVector2Array()
	var samples: int = 96
	for i: int in range(samples + 1):
		var u: float = float(i) / float(samples)
		var edge: float = pow(maxf(0.0, sin(PI * u)), 0.6)
		var x: float = (u - 0.5) * 576.0
		var pulse: float = sin(t * 0.55 + phase + u * 4.0)
		var upper: float
		var lower: float
		match kind:
			&"ragged":
				var grain: float = RisoShapes.hash1(float(i) * 2.31 + phase)
				var under: float = RisoShapes.hash1(float(i) * 3.71 + phase)
				upper = -edge * (35.0 + grain * 63.0 + pulse * 6.0)
				lower = edge * (23.0 + under * 46.0 + pulse * 7.0)
			&"spectral":
				# Tall, narrow hood-like crests and deep necks suggest shades in the outline.
				var crest: float = pow(absf(sin(u * PI * 3.0)), 0.65)
				upper = 22.0 - edge * (25.0 + crest * 94.0 + pulse * 5.0)
				lower = 22.0 + edge * (34.0 + sin(u * PI * 6.0 + t * 0.35) * 13.0)
			&"low":
				upper = 52.0 - edge * (20.0 + pulse * 4.0)
				lower = 52.0 + edge * 27.0
			_:
				# Big rounded lobes grow and subside as the whole bank exhales.
				var lobe: float = pow(absf(sin(u * PI * 5.0)), 0.65)
				upper = 24.0 - edge * (37.0 + lobe * 53.0 + pulse * 8.0)
				lower = 24.0 + edge * (35.0 + sin(u * PI * 5.0 + 0.6) * 9.0)
		top.append(MID + Vector2(x, upper))
		bottom.append(MID + Vector2(x, lower))
	bottom.reverse()
	top.append_array(bottom)
	return top


## Broad S-shaped smoke plumes grow out of a low bank, with deep gaps between rising curls.
static func _plumes(t: float, phase: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [_bank(t, phase, &"low")]
	for strand: int in range(4):
		var left: PackedVector2Array = PackedVector2Array()
		var right: PackedVector2Array = PackedVector2Array()
		var drift: float = t * 0.4 + phase + float(strand) * 1.5
		for i: int in range(33):
			var u: float = float(i) / 32.0
			var x: float = (float(strand) - 1.5) * 125 + sin(u * 7.0 - drift) * (12 + u * 25)
			var y: float = 63.0 - u * (150.0 + sin(drift) * 12.0)
			var width: float = pow(1.0 - u, 0.55) * (24.0 + 9.0 * sin(u * 9.0 + drift))
			left.append(MID + Vector2(x - width, y))
			right.append(MID + Vector2(x + width, y))
		right.reverse()
		left.append_array(right)
		out.append(left)
	return out
