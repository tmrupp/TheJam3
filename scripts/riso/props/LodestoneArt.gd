extends RisoProp
## A lodestone (Lodestone): a standing stone of iron ore two cells high, leaning a little, in blue
## (the band's pale stone) darkened to iron with night, swelling out in a round boss where its mark
## is, with dark night patches of ore and a few paper glints. Untouched, it is a
## beacon, meant to be seen from across the level: a breathing halo of accent behind it (the stone
## stands dark against it), a beam of accent rising off its top, veins of accent ore glowing through
## it, a ring of light pulsing out from its mark now and then, and sparks of iron drawn in, curling
## round it, to its mark. Its spell's mark (RisoGlyph.fit) fills a paper roundel knocked through the
## stone, printed in accent. All of it is brighter when the wizard carries that spell. Touched, the
## halo, beam and sparks are gone, the veins go dark and the mark is dull blue; for a moment after
## the touch it flares.

## The stone: how wide at its foot and its shoulder, how tall (px), and how far it leans (radians).
const FOOT: float = 112.0
const SHOULDER: float = 92.0
const TALL: float = 228.0
const LEAN: float = 0.05
## Its roundel: how high its middle stands over the ground, its radius, and how far from its middle
## the mark reaches against its radius.
const MARK_UP: float = 140.0
const ROUNDEL: float = 38.0
const MARK_FILL: float = 0.8
## How far (px) the stone bulges out past the roundel's rim, round its mark.
const BULGE: float = 16.0
## The halo round the roundel: how far it reaches (px), and how much accent at its heart while it
## waits (more when the wizard carries its spell).
const HALO: float = 150.0
const HALO_WAIT: float = 0.6
const HALO_MATCH: float = 0.85
## The beam rising off its top: how tall (px), how wide at its foot and its head, and how much accent
## at its foot.
const BEAM_TALL: float = 360.0
const BEAM_FOOT: float = 26.0
const BEAM_HEAD: float = 70.0
const BEAM_COVER: float = 0.6
## The ring of light pulsing out from the mark: seconds between rings, and how much accent it starts
## with.
const CALL_EVERY: float = 1.6
const CALL_COVER: float = 0.6
## Sparks of iron drawn in to the mark: how many at once, and seconds for each to arrive.
const FILINGS: int = 7
const FILING_TRIP: float = 2.4
## Its veins of ore: the way each runs from the roundel (radians, 0 to the right, down positive),
## and how wide (px).
const VEINS: Array[float] = [-2.1, -1.2, 1.25, 2.2]
const VEIN_WIDE: float = 8.0
## How much night darkens the stone to iron, so it stands dark against its halo and apart from the
## pale rock.
const DARK: float = 0.45
## How long (seconds) its mark flares once touched.
const FLARE: float = 0.8


## The Lodestone it dresses.
var stone: Lodestone:
	get:
		return host as Lodestone


func shines() -> bool:
	return true


## It shines at its mark until touched.
func light() -> Array:
	if stone == null or stone.touched():
		return []
	return _light(Vector2(0, _ground() - MARK_UP), RisoLight.BEACON, RisoPrint.ACCENT)


## The stone's lean, standing on ground `g`.
func _lean(g: float) -> Transform2D:
	return Transform2D(LEAN, Vector2(0, g)) * Transform2D(0.0, Vector2(0, -g))


## The stone's outline, standing on ground `g`: a tapering slab with a rounded, uneven top, swelling
## out round its mark in a boss of ore.
func _slab(g: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-FOOT * 0.5, g), Vector2(FOOT * 0.5, g),
		Vector2(SHOULDER * 0.5 + 4.0, g - TALL * 0.55),
		Vector2(SHOULDER * 0.5, g - TALL * 0.88), Vector2(SHOULDER * 0.18, g - TALL),
		Vector2(-SHOULDER * 0.3, g - TALL * 0.96), Vector2(-SHOULDER * 0.5, g - TALL * 0.8),
		Vector2(-SHOULDER * 0.5 - 6.0, g - TALL * 0.45),
	])
	var boss: PackedVector2Array = RisoShapes.circle(Vector2(-4.0, g - MARK_UP), ROUNDEL + BULGE, 32)
	var whole: Array[PackedVector2Array] = Geometry2D.merge_polygons(RisoShapes.smooth(pts, 3), boss)
	return _lean(g) * whole[0]


## A band of quads round `c` from radius `r0` (at `cover`) out to `r1` (nothing), and their fades.
static func _halo(c: Vector2, r0: float, r1: float, cover: float, n: int = 36) -> Array:
	var quads: Array[PackedVector2Array] = []
	var fades: Array[PackedFloat32Array] = []
	for i: int in range(n):
		var a: Vector2 = Vector2.from_angle(TAU * float(i) / float(n))
		var b: Vector2 = Vector2.from_angle(TAU * float(i + 1) / float(n))
		quads.append(PackedVector2Array([c + a * r0, c + a * r1, c + b * r1, c + b * r0]))
		fades.append(PackedFloat32Array([cover, 0.0, 0.0, cover]))
	return [quads, fades]


## The veins of ore, from the roundel's rim out to the stone's edge, wandering a little.
func _veins(g: float, mark_at: Vector2, slab: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for k: int in range(VEINS.size()):
		var d: Vector2 = Vector2.from_angle(VEINS[k] + 0.3 * (RisoShapes.hash1(phase + float(k) * 5.3) - 0.5))
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(5):
			var along: float = ROUNDEL + 4.0 + float(i) * 30.0
			var sway: float = (RisoShapes.hash1(phase + float(k) * 11.0 + float(i)) - 0.5) * 16.0
			pts.append(mark_at + d * along + d.orthogonal() * sway)
		for piece: PackedVector2Array in RisoDecor.strip(pts, VEIN_WIDE, VEIN_WIDE * 0.4):
			out.append_array(Geometry2D.intersect_polygons(piece, slab))
	return out


func _draw_art() -> void:
	var s: Lodestone = stone
	if s == null:
		return
	var g: float = _ground()
	var touched: bool = s.touched()
	var calling: bool = not touched and s.spell != &""
	var slab: PackedVector2Array = _slab(g)
	var breath: float = 0.5 + 0.5 * sin(t * 2.2 + phase)
	var bright: float = 1.0 if calling and s.matches() else HALO_WAIT / HALO_MATCH
	var mark_at: Vector2 = _lean(g) * Vector2(-4.0, g - MARK_UP)
	if calling:
		# The halo and the beam, behind the stone (knocked out of it below, so it stands dark
		# against them).
		var halo: Array = _halo(mark_at, ROUNDEL, HALO * (0.92 + 0.08 * breath), HALO_MATCH * bright * (0.8 + 0.2 * breath))
		ink.ink_graded(RisoPrint.ACCENT, halo[0], halo[1])
		var top: Vector2 = _lean(g) * Vector2(SHOULDER * 0.05, g - TALL + 12.0)
		var sway: float = 1.0 + 0.1 * sin(t * 1.7 + phase)
		var beam: PackedVector2Array = PackedVector2Array([top + Vector2(-BEAM_FOOT, 0), top + Vector2(BEAM_FOOT, 0),
			top + Vector2(BEAM_HEAD * sway, -BEAM_TALL), top + Vector2(-BEAM_HEAD * sway, -BEAM_TALL)])
		var foot: float = BEAM_COVER * bright * (0.75 + 0.25 * breath)
		ink.ink_graded(RisoPrint.ACCENT, [beam], [PackedFloat32Array([foot, foot, 0.0, 0.0])])
		# A ring of light pulsing out from the mark.
		var call: float = fmod(t / CALL_EVERY + phase, 1.0)
		var r: float = lerpf(ROUNDEL + 4.0, HALO, call)
		ink.ink(RisoPrint.ACCENT, CALL_COVER * bright * (1.0 - call), RisoShapes.ring(mark_at, r, r + lerpf(8.0, 2.0, call), 40), false)
		ink.knock([RisoPrint.ACCENT], [slab])
	ink.ink(RisoPrint.BLUE, 0.95, [slab])
	ink.ink(RisoPrint.NIGHT, DARK, [slab], false)
	# Patches of ore in night down its shaded side and across it, and glints of paper.
	var ore: Array[PackedVector2Array] = []
	var glints: Array[PackedVector2Array] = []
	for k: int in range(6):
		var p: Vector2 = Vector2((RisoShapes.hash1(phase + float(k) * 3.1) - 0.3) * SHOULDER * 0.7, g - TALL * (0.08 + 0.84 * RisoShapes.hash1(phase + float(k) * 7.7)))
		if p.distance_to(mark_at) < ROUNDEL + 12.0:
			continue
		ore.append(RisoShapes.ellipse(p, 7.0 + 6.0 * RisoShapes.hash1(phase + float(k)), 4.0 + 3.0 * RisoShapes.hash1(phase + float(k) + 0.5), 10, RisoShapes.hash1(float(k)) * PI))
		glints.append(RisoShapes.sparkle(p + Vector2(-5.0, -4.0), 3.2, 1.0))
	var shade: Array[PackedVector2Array] = Geometry2D.intersect_polygons(slab, RisoShapes.rrect(FOOT * 0.12, g - TALL - 10.0, FOOT, TALL + 10.0, 0.0))
	if not shade.is_empty():
		ore.append(shade[0])
	ink.ink(RisoPrint.NIGHT, 0.55, ore, false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], glints)
	if s.spell == &"":
		return
	# Veins of ore running out from the mark: glowing accent until touched, then dark.
	var veins: Array[PackedVector2Array] = _veins(g, mark_at, slab)
	if calling:
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], veins)
		ink.ink(RisoPrint.ACCENT, (0.7 + 0.3 * breath) * maxf(bright, 0.85), veins, false)
	else:
		ink.ink(RisoPrint.NIGHT, 0.5, veins, false)
	# Its spell's mark, filling a paper roundel knocked through the stone.
	var roundel: PackedVector2Array = RisoShapes.circle(mark_at, ROUNDEL, 32)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [roundel])
	var mark: Array[PackedVector2Array] = RisoGlyph.fit(s.spell, mark_at, ROUNDEL * MARK_FILL, t)
	var flare: float = clampf(1.0 - (Lodestone.now() - s.touched_at) / FLARE, 0.0, 1.0)
	if touched:
		ink.ink(RisoPrint.BLUE, 0.55, mark, false)
		if flare > 0.0:
			var burst: Array[PackedVector2Array] = mark.duplicate()
			burst.append_array(RisoShapes.ring(mark_at, ROUNDEL, ROUNDEL + 40.0 * flare, 32))
			ink.ink(RisoPrint.ACCENT, flare, burst, false)
		return
	ink.ink(RisoPrint.ACCENT, 0.85 + 0.15 * breath, mark, false)
	# Sparks of iron drawn in to the mark, curling round it as they come.
	var sparks: Array[PackedVector2Array] = []
	var covers: Array[float] = []
	for k: int in range(FILINGS):
		var u: float = fmod(t / FILING_TRIP + float(k) / float(FILINGS) + phase, 1.0)
		var a: float = TAU * RisoShapes.hash1(phase + float(k) * 2.9) + u * 2.4
		var at: Vector2 = mark_at + Vector2.from_angle(a) * lerpf(HALO, ROUNDEL + 6.0, u * u)
		sparks.append(RisoShapes.sparkle(at, lerpf(3.0, 6.5, u), 1.0))
		covers.append(sin(u * PI))
	for k: int in range(sparks.size()):
		ink.ink(RisoPrint.ACCENT, covers[k] * maxf(bright, 0.8), [sparks[k]], false)
