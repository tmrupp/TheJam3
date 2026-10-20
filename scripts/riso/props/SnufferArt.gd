extends RisoProp
## A snuffing font (Snuffer): a stone basin in blue on a short pedestal, its lip bare paper round
## black water. While its darkness is still to be taken, the water glows pale from within, slowly
## pulsing, and shines a cold light (RisoLight; light only to the eye: Lamplight does not count it),
## a glint spreads across it and pale motes and twinkling sparks rise off it, drifting and fading.
## Just after a flame is put out here, rings spread across the water and a curl of smoke rises from
## it as the water drains away. Dry, the basin is empty, its stone dark inside, with a ring of stain
## where the water stood, and no glow or motes. Just after darkness is poured back in, the water
## wells up black from the bottom of the basin, rings spreading across it, and it glows again.


## The Snuffer it dresses.
var font: Snuffer:
	get:
		return host as Snuffer


## How big it is drawn, against the sizes its shapes are drawn at.
const SCALE: float = 1.35
## How high the water lies over the ground, and how wide it and the lip round it are, in those sizes.
const WATER_Y: float = -58.0
const WATER: Vector2 = Vector2(26.0, 4.0)
const LIP: Vector2 = Vector2(31.0, 6.5)
## How far over the water its light shines from, and the light (as RisoLight.SPARK and the rest:
## how far it reaches in px, how much night it lifts, how much it tints in blue): wider and
## brighter than a beacon's, to be seen from afar.
const LIGHT_RISE: float = 8.0
const LIGHT: Vector3 = Vector3(340.0, 0.26, 0.16)
## The motes rising off the water while it shines: how many, how long each takes to rise (s), how
## high it rises and how big it is at the water, in the sizes it is drawn at, and how much it is
## lifted to paper at its brightest.
const MOTES: int = 14
const MOTE_LIFE: float = 3.2
const MOTE_RISE: float = 120.0
const MOTE_R: float = 4.0
const MOTE_LIFT: float = 0.95
## Every this many motes, one is a twinkling four-pointed spark instead, this much bigger.
const SPARK_EVERY: int = 3
const SPARK_SIZE: float = 2.8
## How much the water's glow lifts it to paper, at the least and the most of its pulse, and how
## fast it pulses (radians a second).
const GLOW: Vector2 = Vector2(0.4, 0.7)
const GLOW_PULSE: float = 2.0
## After a flame is put out here: how long the rings spread (s), and how long the smoke rises.
const RING_TIME: float = 1.6
const SMOKE_TIME: float = 2.6
## A dry basin: how much night ink darkens the stone where the water was, how much the stain ring
## prints, and how far under the lip it lies (in the sizes it is drawn at).
const DRY_DARK: float = 0.45
const STAIN: float = 0.6
const STAIN_DROP: float = 1.6


func shines() -> bool:
	return true


## A cold blue gleam off the water, while there is a flame to put out.
func light() -> Array:
	if font == null or not font.can_snuff():
		return []
	return _light(Vector2(0, _ground() + (WATER_Y - LIGHT_RISE) * SCALE), LIGHT, RisoPrint.BLUE)


func _draw_art() -> void:
	var g: float = _ground()
	var waiting: bool = font != null and font.can_snuff()
	var dipped: float = font.dipped if font != null else INF
	var filled: float = font.filled if font != null else INF
	var xf: Transform2D = Transform2D(0.0, Vector2.ONE * SCALE, 0.0, Vector2(0, g))
	# The pedestal, its foot and the bowl, in blue stone, lit down the stem's left with bare paper.
	var foot: PackedVector2Array = xf * RisoShapes.rrect(-22.0, -10.0, 44.0, 10.0, 3.0)
	var stem: PackedVector2Array = xf * PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(7, -44), Vector2(-7, -44)])
	var bowl: PackedVector2Array = xf * RisoShapes.smooth(PackedVector2Array([Vector2(-30, WATER_Y), Vector2(30, WATER_Y), Vector2(25, -48), Vector2(12, -42), Vector2(-12, -42), Vector2(-25, -48)]), 2)
	ink.ink(RisoPrint.BLUE, 1.0, [foot, stem, bowl])
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.55, [xf * RisoShapes.rrect(-6.0, -42.0, 3.0, 30.0, 1.5)])
	# Its lip, bare paper, round the black water brimming in it.
	var lip: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(0, WATER_Y), LIP.x, LIP.y, 28)
	var water: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(0, WATER_Y), WATER.x, WATER.y, 28)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.9, [lip])
	if font != null and font.dry():
		# The stone inside the empty basin, and the stain round it where the water stood; just
		# after it was drained, the last of the water going.
		ink.ink(RisoPrint.NIGHT, DRY_DARK, [water])
		var stain: Array[PackedVector2Array] = []
		for arc: Vector2 in [Vector2(0.08, 0.92), Vector2(1.08, 1.92)]:
			stain.append(xf * _arc_band(Vector2(0, WATER_Y + STAIN_DROP), WATER - Vector2(2.5, 0.8), 1.4, arc * PI))
		ink.ink(RisoPrint.NIGHT, STAIN, stain, false)
		if dipped < RING_TIME:
			ink.knock([RisoPrint.BLUE], [water])
			ink.ink(RisoPrint.NIGHT, 1.0 - dipped / RING_TIME, [water], false)
	elif filled < RING_TIME:
		# Poured back in: the water welling up from the middle of the basin to its brim.
		var k: float = filled / RING_TIME
		var rising: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(0, WATER_Y), WATER.x * lerpf(0.3, 1.0, k), WATER.y * lerpf(0.3, 1.0, k), 28)
		ink.ink(RisoPrint.NIGHT, DRY_DARK, [water])
		ink.knock([RisoPrint.BLUE], [rising])
		ink.ink(RisoPrint.NIGHT, 1.0, [rising], false)
	else:
		ink.knock([RisoPrint.BLUE], [water])
		ink.ink(RisoPrint.NIGHT, 1.0, [water], false)
	if waiting:
		# The water's glow, from within.
		var pulse: float = 0.5 + 0.5 * sin(t * GLOW_PULSE + phase)
		ink.lift_ink([RisoPrint.NIGHT], lerpf(GLOW.x, GLOW.y, pulse), [xf * RisoShapes.ellipse(Vector2(0, WATER_Y + 0.4), WATER.x * 0.85, WATER.y * 0.7, 24)])
	if minf(dipped, filled) < RING_TIME:
		_rings(xf, minf(dipped, filled) / RING_TIME)
	elif waiting:
		# A glint spreading across the water.
		var k: float = fmod(t * 0.6 + phase, 1.0)
		var glint: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(-4.0 + 6.0 * k, WATER_Y), 3.0 + 18.0 * k, 0.8 + 2.4 * k, 20)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.7 * (1.0 - k), [glint])
	if waiting and dipped >= SMOKE_TIME:
		_motes(xf)
	if dipped < SMOKE_TIME:
		var rise: Transform2D = Transform2D(0.0, Vector2(0, g + (WATER_Y - 2.0) * SCALE))
		RisoMarks.smoke_thread(ink, rise, t + phase, 58.0, 3.4, 5.0, false, true, 1.6 * (1.0 - dipped / SMOKE_TIME))


## Pale motes rising off the water, each from its own spot, swaying as it goes and fading in and
## out, every few a twinkling spark (hashed by its number, so nothing is drawn from the world's RNG).
func _motes(xf: Transform2D) -> void:
	for i: int in range(MOTES):
		var u: float = fmod(t / MOTE_LIFE + RisoShapes.hash1(float(i) + phase * 13.0), 1.0)
		var from: float = (RisoShapes.hash1(float(i) * 7.3 + 2.1) * 2.0 - 1.0) * WATER.x * 0.8
		var sway: float = sin(t * 2.1 + float(i) * 1.7) * 7.0 * u
		var at: Vector2 = Vector2(from + sway, WATER_Y - 1.0 - MOTE_RISE * u)
		var r: float = MOTE_R * lerpf(1.0, 0.5, u)
		var shape: PackedVector2Array = RisoShapes.circle(at, r, 8)
		if i % SPARK_EVERY == 0:
			shape = RisoShapes.sparkle(at, r * SPARK_SIZE * (0.6 + 0.4 * absf(sin(t * 5.0 + float(i)))))
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], MOTE_LIFT * sin(u * PI), [xf * shape])


## Rings spreading out across the water from where the flame went in, `k` of the way through.
func _rings(xf: Transform2D, k: float) -> void:
	var rings: Array[PackedVector2Array] = []
	for lag: float in [0.0, 0.35]:
		var u: float = clampf((k - lag) / (1.0 - lag), 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			continue
		var r: Vector2 = Vector2(4.0, 0.7).lerp(WATER - Vector2(2.0, 0.6), u)
		var w: float = lerpf(1.6, 0.5, u)
		# The near and far sides of each ring, open at the ends so it is never an outline.
		for arc: Vector2 in [Vector2(0.15, 0.85), Vector2(1.15, 1.85)]:
			rings.append(xf * _arc_band(Vector2(0, WATER_Y), r, w, arc * PI))
	ink.lift_ink([RisoPrint.NIGHT], 0.7 * (1.0 - k), rings)


## A band of width `w` along the ellipse of radii `r` about `c`, between the angles `span`.
func _arc_band(c: Vector2, r: Vector2, w: float, span: Vector2) -> PackedVector2Array:
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	const N: int = 12
	for i: int in range(N + 1):
		var a: float = lerpf(span.x, span.y, float(i) / float(N))
		var d: Vector2 = Vector2(cos(a), sin(a))
		outer.append(c + d * (r + Vector2(w, w * 0.4) * 0.5))
		inner.append(c + d * (r - Vector2(w, w * 0.4) * 0.5))
	inner.reverse()
	outer.append_array(inner)
	return outer
