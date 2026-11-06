extends RisoProp
## A lodestone (Lodestone): the golem's body alone (Golem.body_shape, printed as its magnets are:
## dark iron with a paler rim), standing at a lean on its rounded end with rubble heaped round its foot,
## its point up; the golem's body is a lodestone of its own. Untouched, it is a beacon, meant to be seen from across
## the level: a breathing halo of accent behind it (the magnet stands dark against it), a beam of
## accent rising off its top, a ring of light pulsing out from its mark now and then, and sparks of
## iron drawn in, curling round it, to its mark. Its spell's mark (RisoGlyph.fit) fills a paper roundel
## knocked through the magnet's bulge, printed in accent. All of it is brighter when the wizard carries
## that spell. Touched, the halo, beam and sparks are gone and the mark is dull blue; for a moment
## after the touch it flares.

## The magnet: how many times the golem's body it is, half its length (px), how far it leans from
## upright (radians, its top toward the left), and where its middle stands from its spot on the ground
## (its rounded end resting a little into the ground).
const SCALE: float = 1.2
const HALF_LEN: float = Golem.BODY_LEN * SCALE
const LEAN: float = 0.3
const MIDDLE: Vector2 = Vector2(6.0, -105.0)
## Its roundel: how far along the magnet from its middle toward its top (px; where the golem's heart
## sits on its body), its radius, and how far from its middle the mark reaches against its radius.
const MARK_ALONG: float = 17.0
const ROUNDEL: float = 30.0
const MARK_FILL: float = 0.8
## The rubble heaped round its foot: how many stones, how far (px) the nearest lies from where the
## magnet goes into the ground and how much farther each next, and how big the biggest is.
const RUBBLE: int = 5
const RUBBLE_FROM: float = 34.0
const RUBBLE_STEP: float = 16.0
const RUBBLE_SIZE: float = 10.0
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
## How much the rubble at its foot is darkened (the magnet itself is printed as the golem's magnets
## are, dark iron with pale poles: Golem.print_magnet).
const RUBBLE_DARK: float = 0.25
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
	return _light(_mark(_ground()), RisoLight.BEACON, RisoPrint.ACCENT)


## The way along the magnet from its top to its foot.
static func _along() -> Vector2:
	return Vector2(sin(LEAN), cos(LEAN))


## Its middle, standing on ground `g`.
static func _middle(g: float) -> Vector2:
	return Vector2(MIDDLE.x, g + MIDDLE.y)


## Where its mark is, standing on ground `g`.
static func _mark(g: float) -> Vector2:
	return _middle(g) - _along() * MARK_ALONG


## The magnet as it shows over ground `g` (the little of its rounded end in the ground cut off).
static func _magnet(g: float) -> PackedVector2Array:
	var whole: PackedVector2Array = Golem.body_shape(_middle(g), (-_along()).angle(), SCALE)
	var over: PackedVector2Array = PackedVector2Array([Vector2(-HALF_LEN * 2.0, g - HALF_LEN * 3.0), Vector2(HALF_LEN * 2.0, g - HALF_LEN * 3.0), Vector2(HALF_LEN * 2.0, g), Vector2(-HALF_LEN * 2.0, g)])
	var shown: Array[PackedVector2Array] = Geometry2D.intersect_polygons(whole, over)
	return shown[0] if not shown.is_empty() else whole


## The stones heaped round its foot on ground `g`, either side of where it goes into the ground.
func _rubble(g: float) -> Array[PackedVector2Array]:
	var along: Vector2 = _along()
	var foot: float = MIDDLE.x + along.x * (-MIDDLE.y / along.y)
	var out: Array[PackedVector2Array] = []
	for k: int in range(RUBBLE):
		var side: float = -1.0 if k % 2 == 0 else 1.0
		@warning_ignore("integer_division")
		var step: int = k / 2
		var size: float = RUBBLE_SIZE * (1.0 - 0.18 * float(step)) * (0.8 + 0.4 * RisoShapes.hash1(phase + float(k) * 4.3))
		var x: float = foot + side * (RUBBLE_FROM + RUBBLE_STEP * float(step) + 6.0 * RisoShapes.hash1(phase + float(k)))
		out.append(RisoShapes.ellipse(Vector2(x, g - size * 0.55), size, size * 0.7, 10))
	return out


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


func _draw_art() -> void:
	var s: Lodestone = stone
	if s == null:
		return
	var g: float = _ground()
	var touched: bool = s.touched()
	var calling: bool = not touched and s.spell != &""
	var magnet: PackedVector2Array = _magnet(g)
	var breath: float = 0.5 + 0.5 * sin(t * 2.2 + phase)
	var bright: float = 1.0 if calling and s.matches() else HALO_WAIT / HALO_MATCH
	var mark_at: Vector2 = _mark(g)
	if calling:
		# The halo and the beam, behind the magnet (knocked out of it below, so it stands dark
		# against them).
		var halo: Array = _halo(mark_at, ROUNDEL, HALO * (0.92 + 0.08 * breath), HALO_MATCH * bright * (0.8 + 0.2 * breath))
		ink.ink_graded(RisoPrint.ACCENT, halo[0], halo[1])
		var top: Vector2 = _middle(g) - _along() * (HALF_LEN - 14.0)
		var sway: float = 1.0 + 0.1 * sin(t * 1.7 + phase)
		var beam: PackedVector2Array = PackedVector2Array([top + Vector2(-BEAM_FOOT, 0), top + Vector2(BEAM_FOOT, 0),
			top + Vector2(BEAM_HEAD * sway, -BEAM_TALL), top + Vector2(-BEAM_HEAD * sway, -BEAM_TALL)])
		var foot: float = BEAM_COVER * bright * (0.75 + 0.25 * breath)
		ink.ink_graded(RisoPrint.ACCENT, [beam], [PackedFloat32Array([foot, foot, 0.0, 0.0])])
		# A ring of light pulsing out from the mark.
		var call: float = fmod(t / CALL_EVERY + phase, 1.0)
		var r: float = lerpf(ROUNDEL + 4.0, HALO, call)
		ink.ink(RisoPrint.ACCENT, CALL_COVER * bright * (1.0 - call), RisoShapes.ring(mark_at, r, r + lerpf(8.0, 2.0, call), 40), false)
		ink.knock([RisoPrint.ACCENT], [magnet])
	Golem.print_magnet(ink, magnet, [], 0.0, 0.0, 1.0)
	var rubble: Array[PackedVector2Array] = _rubble(g)
	ink.knock([RisoPrint.ACCENT], rubble)
	ink.ink(RisoPrint.BLUE, 0.9, rubble)
	ink.ink(RisoPrint.NIGHT, RUBBLE_DARK, rubble, false)
	if s.spell == &"":
		return
	# Its spell's mark, filling a paper roundel knocked through the magnet's bulge.
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
