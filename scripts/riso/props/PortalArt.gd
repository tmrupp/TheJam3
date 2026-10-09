extends RisoProp
class_name PortalArt
## A portal: a level's teleporter (a gate) or one of the wizard's rifts. Its outline's
## geometry is shared with the portal trip's print (RisoPortalWarp).


## The Portal it dresses.
var gate: Portal:
	get:
		return host as Portal


## A portal: an upright doorway about the wizard's height, so it reads as a way through, shaped as
## a stadium (half circles top and bottom joined by straight sides). What fills it is the F7
## panel's choice (RisoPrint.portal_style): bands of TV static (the default), or ripples on a pool
## of water. A level's own portals are gates: a solid accent rim on a stone threshold, light
## pooled on the floor, and a sigil on top that its partner shares and no other pair in the level
## has while there are sigils to go round (Sigils), so a pair can be told apart.
## The wizard's rifts are torn in the air: a rim of flickering eye-yellow dashes (their own light;
## nothing here is dangerous, so no pink), no threshold, a spark for a sigil; one still waiting
## for its partner is a dim outline with nothing inside. With the wizard right at it (it takes
## standing close), the inside slows as if it waits for them and the rim brightens; the whole
## portal flares when someone comes through (meta "flare_at", see RisoPortalWarp).
const PORTAL_RX: float = 44.0
const PORTAL_RY: float = 72.0
## How far up a gate's oval stands off its threshold.
const PORTAL_LIFT: float = 8.0
## The sigil's disc over the rim: its radius, how far it stands above the oval, and the sigil's size.
const SIGIL_DISC: float = 25.0
const SIGIL_RISE: float = 32.0
const SIGIL_R: float = 17.0
## while the wizard is right at the portal (as if it waits for them).
var _portal_clock: float = 0.0
const PORTAL_SLOW: float = 0.35
## Its outline, rim and halo (at rest, not flaring), kept while it stands where they were worked
## out (_shape_center): they cost hundreds of square roots to lay out, every frame.
var _shape_center: Vector2 = Vector2.INF
var _mouth: PackedVector2Array = PackedVector2Array()
var _rim: Array[PackedVector2Array] = []
var _halo: Array[PackedVector2Array] = []
## The TV static's flecks, kept until the next flicker or a band's brightness changes: what they
## were made for (the flicker, each row's odds of snow, the centre), then the flecks themselves.
var _static_tick: float = -1.0
var _static_odds: PackedFloat32Array = PackedFloat32Array()
var _static_center: Vector2 = Vector2.INF
var _snow: Array[PackedVector2Array] = []
var _dark: Array[PackedVector2Array] = []


## The portal's centre in this prop's pixels: gates stand on their floor, rifts float where they
## were opened.
func portal_center() -> Vector2:
	return Vector2(0, -10) if host.has_meta(&"rift") else Vector2(0, _ground() - PORTAL_RY - PORTAL_LIFT)


## How far from the centre, along unit direction `d`, the edge of a stadium lies: half circles of
## radius `r` above and below, joined by straight sides `h` from the centre either way.
static func _stadium(d: Vector2, r: float, h: float) -> float:
	if absf(d.x) > 0.0001:
		var side: float = r / absf(d.x)
		if absf(d.y) * side <= h:
			return side
	var c: float = h * signf(d.y)
	var b: float = d.y * c
	return b + sqrt(maxf(0.0, b * b - c * c + r * r))


## A point on the portal's outline (a stadium, PORTAL_RX wide and PORTAL_RY tall either way from
## the middle), `k` of the way out from its centre, at `angle`.
static func portal_point(center: Vector2, angle: float, k: float) -> Vector2:
	var d: Vector2 = Vector2.from_angle(angle)
	return center + d * _stadium(d, PORTAL_RX, PORTAL_RY - PORTAL_RX) * k


## A point on the outline grown by `grow` pixels all round (so bands of it are even all round).
static func portal_edge(center: Vector2, angle: float, grow: float) -> Vector2:
	var d: Vector2 = Vector2.from_angle(angle)
	return center + d * _stadium(d, maxf(1.0, PORTAL_RX + grow), PORTAL_RY - PORTAL_RX)


## Half the portal's width at height `y` from its centre (0 past its ends).
static func portal_half_width(y: float) -> float:
	var h: float = PORTAL_RY - PORTAL_RX
	var over: float = absf(y) - h
	if over <= 0.0:
		return PORTAL_RX
	return sqrt(maxf(0.0, PORTAL_RX * PORTAL_RX - over * over))


## A band from `k0` to `k1` of the way out, as quads (from `a0`, `n` segments over `sweep`).
static func portal_band(center: Vector2, k0: float, k1: float, n: int = 48, a0: float = 0.0, sweep: float = TAU) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in range(n):
		var a: float = a0 + sweep * float(i) / float(n)
		var b: float = a0 + sweep * float(i + 1) / float(n)
		out.append(PackedVector2Array([portal_point(center, a, k0), portal_point(center, a, k1), portal_point(center, b, k1), portal_point(center, b, k0)]))
	return out


## A band of even thickness round the outline, from `g0` to `g1` pixels out of it.
static func portal_ring(center: Vector2, g0: float, g1: float, n: int = 48, a0: float = 0.0, sweep: float = TAU) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in range(n):
		var a: float = a0 + sweep * float(i) / float(n)
		var b: float = a0 + sweep * float(i + 1) / float(n)
		out.append(PackedVector2Array([portal_edge(center, a, g0), portal_edge(center, a, g1), portal_edge(center, b, g1), portal_edge(center, b, g0)]))
	return out


## The outline itself, `k` of the full size.
static func portal_oval(center: Vector2, k: float, n: int = 48) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(n):
		out.append(portal_point(center, TAU * float(i) / float(n), k))
	return out


func _draw_art() -> void:
	var rift: bool = host.has_meta(&"rift")
	var linked: bool = gate.linked
	var active: bool = linked or not rift
	var center: Vector2 = portal_center()
	var g: float = _ground()
	var ring: int = RisoPrint.EYE if rift else RisoPrint.ACCENT
	# Right at it (it takes standing close), it stirs: the inside slows as if waiting, the rim brightens.
	var player: Node2D = Stage.player()
	var near: float = 0.0
	if player != null and active:
		var d: Vector2 = (player.global_position - to_global(center)).abs()
		near = clampf(1.0 - (maxf(d.x - 18.0, 0.0) / 36.0 + maxf(d.y - 60.0, 0.0) / 50.0), 0.0, 1.0)
	var flare: float = clampf(1.0 - (Time.get_ticks_msec() / 1000.0 - float(host.get_meta(&"flare_at", -100.0))) / 0.6, 0.0, 1.0)
	# A rift's dashes turn round its rim, faster close by and as someone comes through.
	var turn: float = t * (0.9 + 1.6 * near + 3.0 * flare) + phase
	if not rift:
		# Light pooled on the floor, and the stone threshold the gate stands on.
		ink.ink(ring, 0.16 + 0.12 * near, [RisoShapes.ellipse(Vector2(0, g - 3.0), PORTAL_RX + 18.0, 7.0, 24)], false)
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-PORTAL_RX - 10.0, g - PORTAL_LIFT - 4.0, PORTAL_RX * 2.0 + 20.0, PORTAL_LIFT + 4.0, 4.0)])
		ink.ink(RisoPrint.NIGHT, 0.45, [RisoShapes.rrect(-PORTAL_RX - 4.0, g - PORTAL_LIFT - 4.0, PORTAL_RX * 2.0 + 8.0, 3.0, 1.5)], false)
	if center != _shape_center:
		_shape_center = center
		_mouth = portal_oval(center, 1.0)
		_rim = portal_ring(center, -1.5, 4.5)
		_halo = portal_ring(center, 0.0, 16.0)
	var mouth: PackedVector2Array = _mouth
	if not active:
		# Waiting for its partner: a dim outline of dashes, breathing.
		ink.ink(RisoPrint.BLUE, 0.3, [mouth])
		var waiting: Array[PackedVector2Array] = []
		for i: int in range(16):
			waiting.append_array(portal_ring(center, -2.5, 2.5, 2, TAU * float(i) / 16.0, TAU / 32.0))
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.6, waiting)
		ink.ink(ring, 0.7 + 0.2 * sin(t * 2.0 + phase), waiting, false)
		return
	ink.knock([RisoPrint.NIGHT], [mouth])
	_portal_clock += _dt * lerpf(1.0, PORTAL_SLOW, near)
	if RisoPrint.instance != null and RisoPrint.instance.portal_style == &"static":
		_portal_static(center, near, flare, ring, _portal_clock)
	else:
		_portal_ripples(center, near, flare, ring, _portal_clock)
	# The rim: solid on a gate, flickering dashes on a rift; a soft halo out from it.
	var glow: float = 0.75 + 0.25 * near + 0.5 * flare
	ink.ink_graded(ring, _halo if flare <= 0.0 else portal_ring(center, 0.0, 16.0 * (1.0 + flare)), _halo_fades(48, 0.28 * glow))
	if rift:
		var dashes: Array[PackedVector2Array] = []
		for i: int in range(14):
			var a: float = turn * 0.35 + TAU * float(i) / 14.0
			var thick: float = 3.0 + 1.8 * sin(t * 9.0 + float(i) * 2.3)
			dashes.append_array(portal_ring(center, -thick, thick, 3, a, TAU / 22.0))
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.8, dashes)
		ink.ink(ring, minf(1.0, 0.8 * glow + 0.2), dashes, false)
	else:
		var rim: Array[PackedVector2Array] = _rim
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.85, rim)
		ink.ink(ring, minf(1.0, glow), rim, false)
	# The sigil on top: the pair's (Sigils) on a gate, the wizard's spark on a rift.
	var top: Vector2 = center + Vector2(0, -PORTAL_RY - SIGIL_RISE)
	var disc: PackedVector2Array = RisoShapes.circle(top, SIGIL_DISC, 24)
	ink.ink(ring, 1.0, [RisoShapes.circle(top, SIGIL_DISC + 3.0, 26)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [disc])
	var pair: int = -1 if rift else Sigils.of(host)
	var mark: Array[PackedVector2Array] = [RisoShapes.sparkle(top, SIGIL_R * 1.1)]
	if pair >= 0:
		mark = RisoMarks.sigil(pair, top, SIGIL_R)
	ink.ink(RisoPrint.NIGHT, 1.0, mark, false)


## Inside, bands of TV static: thin rows of snow (flecks of bare paper and night, faintly tinted in
## the rim's ink) that flicker about 18 times a second, grouped in bands of a few rows, each band
## brighter or dimmer than the next, rolling down. Right at it, it slows (see _portal_clock) and snows
## harder; it floods white as someone comes through.
func _portal_static(center: Vector2, near: float, flare: float, ring: int, clock: float) -> void:
	ink.ink(RisoPrint.BLUE, 0.6, [_mouth], false)
	ink.ink(RisoPrint.NIGHT, 0.45, [_mouth], false)
	var tick: float = floorf(clock * 18.0)
	var row: float = 4.0
	var band: float = row * 4.0
	var scroll: float = clock * 12.0 + phase * 40.0
	var rows: int = int(PORTAL_RY * 2.0 / row)
	# Each row's odds of snow: the band it is in (bands roll down), and how bright that is.
	var odds_by_row: PackedFloat32Array = PackedFloat32Array()
	odds_by_row.resize(rows)
	for r: int in range(rows):
		var y0: float = -PORTAL_RY + float(r) * row
		var b: float = floorf((y0 - scroll) / band)
		var level: float = RisoShapes.hash1(b * 5.13 + phase * 9.0)
		odds_by_row[r] = (0.72 if level > 0.55 else 0.05 + 0.15 * level) + 0.12 * near + 0.6 * flare
	if tick != _static_tick or odds_by_row != _static_odds or center != _static_center:
		_static_tick = tick
		_static_odds = odds_by_row
		_static_center = center
		_static_flecks(center, tick, row, rows, odds_by_row)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.95, _snow)
	ink.ink(ring, 0.15 + 0.2 * near, _snow, false)
	ink.ink(RisoPrint.NIGHT, 0.9, _dark, false)


## The static's flecks for flicker `tick`: rows of cells of hashed widths, each snow (bare paper)
## at its row's odds, now and then dark, else nothing.
func _static_flecks(center: Vector2, tick: float, row: float, rows: int, odds_by_row: PackedFloat32Array) -> void:
	var snow: Array[PackedVector2Array] = []
	var dark: Array[PackedVector2Array] = []
	for r: int in range(rows):
		var y0: float = -PORTAL_RY + float(r) * row
		var hw: float = portal_half_width(y0 + row * 0.5) - 2.5
		if hw < 3.0:
			continue
		var odds: float = odds_by_row[r]
		var x: float = -hw
		var i: int = 0
		while x < hw:
			var seed_f: float = float(r) * 13.17 + float(i) * 7.31 + tick * 3.77 + phase * 50.0
			var w: float = minf(1.5 + RisoShapes.hash1(seed_f) * 7.0, hw - x)
			var v: float = RisoShapes.hash1(seed_f + 0.5)
			var cell: PackedVector2Array = PackedVector2Array([center + Vector2(x, y0), center + Vector2(x + w, y0), center + Vector2(x + w, y0 + row - 1.5), center + Vector2(x, y0 + row - 1.5)])
			if v < odds:
				snow.append(cell)
			elif v > 0.9:
				dark.append(cell)
			x += w
			i += 1
	_snow = snow
	_dark = dark


## Inside, a pool of water: deep blue, darker below, with rings spreading out from a drip in the
## middle and fading as they reach the rim, and a sheen of light across the top of the surface.
## The drips come slower right at it (see _portal_clock), and a big ring spreads as someone comes
## through.
func _portal_ripples(center: Vector2, near: float, flare: float, ring: int, clock: float) -> void:
	ink.ink(RisoPrint.BLUE, 0.75, [_mouth], false)
	ink.ink(RisoPrint.NIGHT, 0.35, [portal_oval(center + Vector2(0, PORTAL_RY * 0.25), 0.7, 32)], false)
	var rate: float = 0.26
	var tint: Array[PackedVector2Array] = []
	for i: int in range(5):
		var k: float = fposmod(clock * rate + float(i) / 5.0 + phase * 0.1, 1.0)
		var cover: float = sin(PI * k) * 0.8
		if cover < 0.05:
			continue
		var w: float = 0.03 + 0.03 * (1.0 - k)
		var band: Array[PackedVector2Array] = portal_band(center, maxf(0.02, k - w), k, 40)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], cover, band)
		tint.append_array(band)
	ink.ink(ring, 0.3, tint, false)
	if flare > 0.0:
		var big: float = 1.0 - flare
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], flare, portal_band(center, maxf(0.02, big - 0.08), big + 0.02, 40))
	# The drip: a bead of light at the middle that swells as each ring leaves it.
	var drip: float = fposmod(clock * rate * 5.0 + phase * 0.5, 1.0)
	var bead: PackedVector2Array = RisoShapes.circle(center, 2.0 + 4.0 * (1.0 - drip), 12)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [bead])
	ink.ink(RisoPrint.EYE, 0.8, [bead], false)
	# A sheen of light across the top of the water.
	var sheen: Array[PackedVector2Array] = []
	sheen.append_array(portal_band(center + Vector2(-PORTAL_RX * 0.15, -PORTAL_RY * 0.1), 0.62, 0.7, 10, -PI * 0.92, PI * 0.38))
	sheen.append_array(portal_band(center + Vector2(-PORTAL_RX * 0.15, -PORTAL_RY * 0.1), 0.46, 0.51, 6, -PI * 0.85, PI * 0.22))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.55, sheen)


## Fades for a halo band of `n` quads: `cover` at the rim, nothing at the outer edge.
static func _halo_fades(n: int, cover: float) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	for i: int in range(n):
		out.append(PackedFloat32Array([cover, 0.0, 0.0, cover]))
	return out
