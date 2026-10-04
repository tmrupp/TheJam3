extends Node2D
## A trip through a portal, printed, in two parts either side of the cut to the far portal (see
## portal.gd and RisoPrint.portal_depart / portal_arrive). Presentation only.
## - In (part 0): the wizard, as a silhouette in their glow ink (as the dash's afterimages are),
##   is stretched tall and thin and pulled into the portal's core along streaks that converge on
##   it, while the rim flares; it ends in a flash at the core.
## - Out (part 1): the far portal's core flashes; a sliver of light there opens into the
##   silhouette, which drops to where the wizard stands just as they reappear (RisoWizard pops them
##   out tall and springs them back), and a ring, streaks and motes burst outward.

const IN_TIME: float = 0.3
const OUT_TIME: float = 0.45
## Into the out part, when the wizard is seen again (portal.gd REVEAL).
const REVEAL: float = 0.16
## The silhouette's middle over its feet, in art units (RisoProp.ghost_shape).
const MID: float = 19.0
const STREAKS: int = 9
const MOTES: int = 10
const PAPER_LIFT: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK]

var part: int = 0
var center: Vector2
var feet: Vector2
var facing: float = 1.0
var art_scale: float = 3.2
var ring: int = RisoPrint.ACCENT
var t: float = 0.0
var ink: InkCanvas


func _ready() -> void:
	z_index = 3
	add_to_group(&"riso_art")
	ink = InkCanvas.new()
	ink.top_level = true
	add_child(ink)


func _process(delta: float) -> void:
	t += delta
	var length: float = (IN_TIME + 0.12) if part == 0 else OUT_TIME
	if t >= length:
		queue_free()
		return
	ink.begin()
	if part == 0:
		_in(t / IN_TIME)
	else:
		_out(t / OUT_TIME)
	ink.finish()


## The silhouette, its middle at `mid`, `wide` and `tall` times its size, at `cover`.
func _silhouette(mid: Vector2, wide: float, tall: float, cover: float) -> void:
	if wide < 0.04 or cover <= 0.01:
		return
	var at: Transform2D = Transform2D(0.0, Vector2(art_scale * wide, art_scale * tall), 0.0, mid) * Transform2D(0.0, Vector2(0, MID))
	var shape: Array[PackedVector2Array] = RisoProp.ghost_shape(at, facing)
	ink.ink(RisoPrint.GLOW, cover, shape)
	ink.ink(ring, cover * 0.35, shape, false)


## Streaks along rays out of the core, from `k0` to `k1` of the portal's size out.
func _streaks(k0: float, k1: float, cover: float, turn: float) -> void:
	if cover <= 0.01:
		return
	var lines: Array[PackedVector2Array] = []
	for i: int in range(STREAKS):
		var a: float = TAU * (float(i) + 0.3) / float(STREAKS) + turn
		var p0: Vector2 = RisoProp.portal_point(center, a, k0)
		var p1: Vector2 = RisoProp.portal_point(center, a, k1)
		var n: Vector2 = (p1 - p0).normalized().orthogonal()
		lines.append(PackedVector2Array([p0 - n * 0.8, p1 - n * 2.6, p1 + n * 2.6, p0 + n * 0.8]))
	ink.lift_ink(PAPER_LIFT, cover * 0.7, lines)
	ink.ink(ring, cover, lines, false)


func _flash(r: float) -> void:
	if r < 2.0:
		return
	var spark: PackedVector2Array = Transform2D(t * 3.0, center) * RisoShapes.sparkle(Vector2.ZERO, r)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [spark])
	ink.ink(RisoPrint.EYE, 1.0, [spark], false)


func _in(e: float) -> void:
	var u: float = clampf(e, 0.0, 1.0)
	var pull: float = u * u
	# Drawn up tall and thin, and into the core.
	var mid: Vector2 = (feet + Vector2(0, -MID * art_scale)).lerp(center, pull)
	var tall: float = (1.0 + 0.8 * u) * (1.0 - pull * pull * 0.9)
	_silhouette(mid, pow(1.0 - pull, 1.4), tall, 0.95)
	# Streaks rushing in to the core.
	var k: float = lerpf(1.9, 0.25, u)
	_streaks(k, k + 0.55 * (1.0 - u) + 0.1, 0.9 * (1.0 - u * 0.3), u * 0.8)
	# The rim flares, then draws in after the wizard.
	var band: Array[PackedVector2Array] = RisoProp.portal_band(center, lerpf(1.0, 0.15, pull), lerpf(1.12, 0.3, pull), 32)
	ink.lift_ink(PAPER_LIFT, 0.5 * (1.0 - u * 0.5), band)
	ink.ink(ring, 0.6 + 0.4 * u, band, false)
	# A flash as they go.
	if e > 0.8:
		_flash(46.0 * (1.0 - absf(e - 1.05) / 0.25))


func _out(e: float) -> void:
	var out: float = 1.0 - pow(1.0 - e, 3.0)
	var fade: float = 1.0 - e
	# The core flashes first.
	_flash(48.0 * (1.0 - e / 0.3))
	# A sliver of light opens into the silhouette and drops to the wizard's feet; once the wizard
	# is seen again it fades off them.
	var r: float = clampf(e / (REVEAL / OUT_TIME), 0.0, 1.0)
	var open: float = r * r * (3.0 - 2.0 * r)
	var mid: Vector2 = center.lerp(feet + Vector2(0, -MID * art_scale), open)
	var after: float = clampf((e - REVEAL / OUT_TIME) / 0.3, 0.0, 1.0)
	_silhouette(mid, lerpf(0.08, 1.0, open), lerpf(1.6, 1.0, open), 0.95 * (1.0 - after))
	# A ring bursting out past the rim, streaks flying out, and motes.
	var band: Array[PackedVector2Array] = RisoProp.portal_band(center, lerpf(0.2, 1.5, out), lerpf(0.3, 1.58, out), 32)
	ink.lift_ink(PAPER_LIFT, 0.6 * fade, band)
	ink.ink(ring, 0.9 * fade, band, false)
	var k: float = lerpf(0.3, 1.9, out)
	_streaks(k, k + 0.45 * fade + 0.05, 0.9 * fade, -out * 0.6)
	var motes: Array[PackedVector2Array] = []
	var size: float = 3.6 * fade
	if size > 1.2:
		for i: int in range(MOTES):
			var a: float = TAU * (float(i) + 0.5) / float(MOTES) + out * 1.2
			motes.append(RisoShapes.circle(RisoProp.portal_point(center, a, lerpf(0.15, 1.7, out)), size, 10))
	ink.ink(RisoPrint.EYE, 0.95, motes)
