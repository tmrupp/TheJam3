extends Node2D
## The night sheet behind everything: a solid night flood, slow-drifting stars and a few large
## abstract shapes per realm. Follows the camera; only the stars move with parallax.
##
## The stars and the far skyline are each printed once and then slid with the camera (their canvas
## moved, nothing drawn again) until they have slid further than the margin round the view
## (STAR_SLACK, SKYLINE_SLACK), when they are laid out afresh from where the camera is; and the
## realm's own shapes move on BACKDROP_RATE times a second (hyperspace's rushing streaks every
## frame), so a still camera reprints nothing on most frames.

const HTML_WIDTH: float = 480.0
## How many times a second the realm's backdrop moves on (its slow orreries, drifting clouds).
const BACKDROP_RATE: float = 30.0
## How far the stars and the skyline may slide before they are laid out again (px): well inside the
## margin they are laid out with past the view, so none is ever seen missing.
const STAR_SLACK: float = 60.0
const SKYLINE_SLACK: float = 160.0
var ink: InkCanvas
## The skyline's and the stars' canvases, slid with the camera between layouts.
var sky_ink: InkCanvas
var star_ink: InkCanvas
## Where the camera was when the skyline and the stars were last laid out, for what size of view
## (zero until they are), and what was laid out.
var _sky_at: Vector2 = Vector2.INF
var _sky_view: Vector2 = Vector2.ZERO
var _sky_far: Array[PackedVector2Array] = []
var _sky_near: Array[PackedVector2Array] = []
var _stars_at: Vector2 = Vector2.INF
var _stars_view: Vector2 = Vector2.ZERO
var _star_dots: Array[PackedVector2Array] = []
var _twinkle_at: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	z_index = -40
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)
	sky_ink = InkCanvas.new()
	add_child(sky_ink)
	star_ink = InkCanvas.new()
	add_child(star_ink)
	# The ground itself, not a thing seen on it (InkCanvas.punches_wall).
	for canvas: InkCanvas in [ink, sky_ink, star_ink]:
		canvas.punches_wall = false


func _process(_delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null or RisoPrint.instance == null:
		return
	var center: Vector2 = cam.get_screen_center_position()
	global_position = center
	var base: Vector2 = Vector2(get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var view: Vector2 = base / cam.zoom
	var k: float = view.x / HTML_WIDTH
	var now: float = Time.get_ticks_msec() / 1000.0
	var realm: StringName = RisoPrint.instance.realm
	var t: float = now if realm == &"hyperspace" else floorf(now * BACKDROP_RATE) / BACKDROP_RATE
	var half: Vector2 = view * 0.5 + Vector2(240, 240)
	# HTML-space (480 x 270) point to local space.
	var at: Callable = func(x: float, y: float) -> Vector2: return Vector2((x - 240.0) * k, (y - 135.0) * k)
	ink.begin()
	sky_ink.begin()
	star_ink.begin()
	# A dense screen rather than a solid: the night keeps a fine texture of paper, as in the prototype.
	ink.ink(RisoPrint.NIGHT, RisoPrint.NIGHT_FLOOD, [PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])], false)
	var backdrop: Callable = _backdrops.get(realm, _backdrop_night)
	if bool(backdrop.call(at, view, half, k, t, center)):
		_skyline(center, view, half)
		_stars(center, view, k, t)
	ink.finish()
	sky_ink.finish()
	star_ink.finish()


# ------------------------------------------------------------------ backdrops by realm
# Each draws a realm's big shapes over the night flood, from: `at` (a point in the prototype's
# 480 x 270 sheet to local space), the view's size, half the inked area, the sheet's scale `k`, the
# time `t` and the view's centre. Each says whether the skyline and the drifting stars go over it.

## The backdrops by realm, as RisoPrint.REALMS holds colours by realm; any realm not here (the
## garden's, the deep) gets the night's (_backdrop_night). A band with a backdrop of its own adds it.
var _backdrops: Dictionary = {}


func _init() -> void:
	_backdrops = {
		&"hyperspace": _backdrop_hyperspace,
		&"twilight": _backdrop_twilight,
		&"cemetery": _backdrop_cemetery,
		&"sky": _backdrop_sky,
		&"crags": _backdrop_crags,
		&"institute": _backdrop_institute,
		&"belly": _backdrop_belly,
		&"aurora": _backdrop_aurora,
	}


## Hyperspace: the warp streaks alone, with no skyline or stars.
func _backdrop_hyperspace(_at: Callable, view: Vector2, _half: Vector2, _k: float, t: float, center: Vector2) -> bool:
	_warp(center, view, t)
	return false


## Twilight: a low sun throwing rays, a pink moon, and dusk warming toward the bottom of the sheet.
func _backdrop_twilight(at: Callable, view: Vector2, half: Vector2, k: float, t: float, _center: Vector2) -> bool:
	var sun: Vector2 = at.call(330.0, 118.0)
	var rays: Array[PackedVector2Array] = []
	for i: int in range(0, 16, 2):
		var a0: float = t * 0.02 + float(i) * TAU / 16.0
		rays.append(PackedVector2Array([sun, sun + Vector2(cos(a0), sin(a0)) * view.x * 1.6, sun + Vector2(cos(a0 + TAU / 40.0), sin(a0 + TAU / 40.0)) * view.x * 1.6]))
	ink.ink(RisoPrint.ACCENT, 0.15, rays)
	ink.ink(RisoPrint.PINK, 0.15, [RisoShapes.circle(at.call(118.0 + sin(t * 0.07) * 26.0, 78.0), 40.0 * k, 40)])
	# Dusk warms toward the bottom of the sheet: a graded pink screen, no hard edge.
	var top: float = -10.0 * k
	ink.ink_graded(RisoPrint.PINK, [PackedVector2Array([Vector2(-half.x, top), Vector2(half.x, top), Vector2(half.x, half.y), Vector2(-half.x, half.y)])], [PackedFloat32Array([0.0, 0.0, 0.2, 0.2])])
	ink.ink(RisoPrint.ACCENT, 0.5, [RisoShapes.circle(sun, 20.0 * k, 32)])
	return true


## The cemetery: a pale moon low over the graves, faint through the night, with banks of mist
## drifting across.
func _backdrop_cemetery(at: Callable, _view: Vector2, _half: Vector2, k: float, t: float, _center: Vector2) -> bool:
	var moon: Vector2 = at.call(352.0, 64.0)
	ink.ink(RisoPrint.ACCENT, 0.1, [RisoShapes.circle(moon, 30.0 * k, 40)])
	ink.lift_ink([RisoPrint.NIGHT], 0.3, [RisoShapes.circle(moon, 17.0 * k, 40)])
	ink.ink(RisoPrint.BLUE, 0.15, [RisoShapes.circle(moon + Vector2(-4.0, 3.0) * k, 4.0 * k, 16), RisoShapes.circle(moon + Vector2(5.0, -5.0) * k, 3.0 * k, 12)])
	for i: int in range(3):
		var drift: float = fposmod(t * (4.0 + float(i) * 2.0) + float(i) * 170.0, 640.0) - 80.0
		ink.ink(RisoPrint.BLUE, 0.12, [_cloud(at.call(drift, 92.0 + float(i) * 34.0), (90.0 + float(i) * 30.0) * k, (16.0 + float(i) * 4.0) * k, i)])
	return true


## How the sky's storm clouds roll (px of the sheet a second): STORM_DRIFT still, STORM_PUSH more
## in a gust (MapInfo.gust_wind), its way, however many vanes set it (they make it last longer); they keep rolling
## the way it last blew between gusts. Lightning flashes about every
## FLASH_EVERY seconds (each its own, by a hash), lasting FLASH_TIME.
const STORM_DRIFT: float = 3.0
const STORM_PUSH: float = 8.0
const FLASH_EVERY: float = 7.0
const FLASH_TIME: float = 0.22
## How far the storm clouds have rolled (px of the sheet), and the way they roll.
var _storm_roll: float = 0.0
var _storm_way: float = 1.0


## The sky: up in a storm. Heavy banks of cloud in the islands' own pale ink roll over the dark,
## layer on layer, the way the level's wind blows, faster in a gust; now and then
## lightning flashes far off, a jagged bolt of bare paper down through the clouds and the sheet
## lit pale a moment. No moon, no stars.
func _backdrop_sky(at: Callable, _view: Vector2, half: Vector2, k: float, t: float, _center: Vector2) -> bool:
	var info: MapInfo = MapInfo.instance if MapInfo.instance != null and MapInfo.instance.world != null else null
	var wind: int = info.level_wind() if info != null else 0
	var gust: int = info.gust_wind() if info != null else 0
	_storm_way = -1.0 if wind < 0 else 1.0
	# The clouds roll on by their own clock: faster in a gust, so they surge with it.
	_storm_roll += _storm_way * get_process_delta_time() * (STORM_DRIFT + (STORM_PUSH if gust != 0 else 0.0))
	for i: int in range(7):
		var roll: float = fposmod(_storm_roll * (0.7 + 0.15 * float(i)) + float(i) * 113.0, 760.0) - 140.0
		var y: float = 30.0 + float(i) * 36.0
		var cover: float = 0.1 + 0.02 * float(i % 3)
		ink.ink(RisoPrint.BLUE, cover, [_cloud(at.call(roll, y), (150.0 + float(i) * 22.0) * k, (34.0 + float(i) * 5.0) * k, i + 3)])
	# In a gust, streaks rush across the whole sheet its way.
	if gust != 0:
		var streaks: Array[PackedVector2Array] = []
		for i: int in range(18):
			var u: float = fposmod(t * (1.2 + 0.4 * RisoShapes.hash1(float(i) * 3.3)) + RisoShapes.hash1(float(i) * 1.7), 1.0)
			var x: float = lerpf(-40.0, 520.0, u if gust > 0 else 1.0 - u)
			var y: float = 20.0 + 230.0 * RisoShapes.hash1(float(i) * 5.1)
			streaks.append(RisoShapes.almond(at.call(x, y), (40.0 + 30.0 * RisoShapes.hash1(float(i))) * k * sin(u * PI), 1.6 * k, 10))
		ink.lift_ink([RisoPrint.NIGHT], 0.35, streaks)
	# Lightning: within each FLASH_EVERY, a moment of it at a time and a place its own.
	var beat: int = floori(t / FLASH_EVERY)
	var into: float = t - float(beat) * FLASH_EVERY - FLASH_EVERY * 0.6 * RisoShapes.hash1(float(beat) * 3.1)
	if into >= 0.0 and into < FLASH_TIME:
		var u: float = 1.0 - into / FLASH_TIME
		ink.lift_ink([RisoPrint.NIGHT], 0.18 * u, [PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])])
		var x: float = 60.0 + 360.0 * RisoShapes.hash1(float(beat) * 7.7)
		var bolt: PackedVector2Array = PackedVector2Array()
		var y: float = 10.0
		var bx: float = x
		while y < 200.0:
			bolt.append(at.call(bx, y))
			y += 14.0 + 10.0 * RisoShapes.hash1(y * 0.37 + float(beat))
			bx += (RisoShapes.hash1(y * 0.71 + float(beat) * 1.9) - 0.5) * 30.0
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.9 * u, RisoDecor.strip(bolt, 3.0 * k, 1.0 * k))
	return false


## The belly's backdrop: seconds a breath; and its ribs, how far apart (sheet px), how much of the
## view's movement they slide by (they are far off), and how faint.
const BREATH: float = 4.0
const RIB_GAP: float = 140.0
const RIB_SLIDE: float = 0.35
const RIB_COVER: float = 0.11


## The whale's belly: no sky at all, only its dark, a slow swell of the walls' flesh breathing in
## it (BREATH seconds a breath), and behind it its ribs, faint arches of bone from top to bottom of
## the sheet RIB_GAP apart, bowing out a little more as it breathes in and sliding by RIB_SLIDE as
## fast as the view moves, so they read as far off. No stars.
func _backdrop_belly(at: Callable, _view: Vector2, _half: Vector2, k: float, t: float, center: Vector2) -> bool:
	var breath: float = 0.5 + 0.5 * sin(t / BREATH * TAU)
	for i: int in range(3):
		ink.ink(RisoPrint.BLUE, 0.06 + 0.05 * breath, [RisoShapes.ellipse(at.call(120.0 + float(i) * 120.0, 135.0 + 30.0 * sin(float(i) * 2.1)), (110.0 + 20.0 * breath) * k, (80.0 + 14.0 * breath) * k, 32)])
	var ribs: Array[PackedVector2Array] = []
	var slide: float = fposmod(-center.x * RIB_SLIDE / k, RIB_GAP)
	for i: int in range(-1, 5):
		var x: float = slide + float(i) * RIB_GAP
		var bow: float = 26.0 + 6.0 * breath
		var pts: PackedVector2Array = PackedVector2Array()
		for j: int in range(13):
			var f: float = float(j) / 12.0
			pts.append(at.call(x + sin(f * PI) * bow, -20.0 + f * 310.0))
		ribs.append_array(RisoDecor.strip(pts, 11.0 * k, 11.0 * k))
	ink.ink(RisoPrint.BLUE, RIB_COVER, ribs)
	return false


## The crags: dawn over the mountains. A faint sun just rising at the bottom of the sheet, its
## warmth rising with it; two ranges of jagged peaks, the nearer with a ruined castle on its summits,
## sliding a little as the camera climbs; and streaks of cloud torn along by the wind below the
## cliffs.
func _backdrop_crags(at: Callable, view: Vector2, half: Vector2, k: float, t: float, center: Vector2) -> bool:
	# Dawn warms toward the bottom of the sheet: a graded sun-ink screen, no hard edge.
	var top: float = -40.0 * k
	ink.ink_graded(RisoPrint.ACCENT, [PackedVector2Array([Vector2(-half.x, top), Vector2(half.x, top), Vector2(half.x, half.y), Vector2(-half.x, half.y)])], [PackedFloat32Array([0.0, 0.0, 0.26, 0.26])])
	var sun: Vector2 = at.call(388.0, 262.0)
	ink.ink(RisoPrint.ACCENT, 0.12, [RisoShapes.circle(sun, 64.0 * k, 48)])
	ink.lift_ink([RisoPrint.NIGHT], 0.2, [RisoShapes.circle(sun, 40.0 * k, 40)])
	ink.ink(RisoPrint.ACCENT, 0.22, [RisoShapes.circle(sun, 30.0 * k, 40)])
	# The far range, then the near one with its castle, each sliding a little as the camera moves.
	var far: float = view.y * 0.18 - center.y * 0.02
	var near: float = view.y * 0.3 - center.y * 0.035
	ink.ink(RisoPrint.BLUE, 0.1, [_peaks(center.x * 0.03, far, 90.0 * k, 150.0 * k, half, 1)], false)
	var ridge: PackedVector2Array = _peaks(center.x * 0.06, near, 70.0 * k, 110.0 * k, half, 2)
	ink.ink(RisoPrint.BLUE, 0.16, [ridge], false)
	ink.ink(RisoPrint.BLUE, 0.16, _castle(center.x * 0.06, near, 70.0 * k, half, k), false)
	# Cloud torn along by the wind, low down: long thin streaks, fast, the lower the fainter.
	var streaks: Array[PackedVector2Array] = []
	for i: int in range(6):
		var length: float = (150.0 + 90.0 * RisoShapes.hash1(float(i) * 3.7)) * k
		var x: float = fposmod(t * (24.0 + float(i) * 9.0) + float(i) * 211.0 - center.x * 0.08, view.x + length * 2.0) - half.x - length
		var y: float = view.y * (0.12 + 0.07 * float(i)) - center.y * 0.05
		streaks.append(RisoShapes.almond(Vector2(x, y), length * 0.5, (3.0 + 2.0 * RisoShapes.hash1(float(i) * 1.9)) * k, 16))
	ink.ink(RisoPrint.BLUE, 0.13, streaks, false)
	return true


## A range of jagged peaks across the view: a summit every so often (hashed from its place along
## the range, `which` telling ranges apart), `low` to `high` over the line `base`, and slid by
## `drift`. Filled down past the bottom of the view.
static func _peaks(drift: float, base: float, low: float, high: float, half: Vector2, which: int) -> PackedVector2Array:
	var step: float = (high + low) * 0.45
	var pts: PackedVector2Array = PackedVector2Array([Vector2(half.x, half.y + 10.0), Vector2(-half.x, half.y + 10.0)])
	var first: int = floori((-half.x + drift) / step) - 1
	for n: int in range(first, first + int(half.x * 2.0 / step) + 4):
		var x: float = float(n) * step - drift
		var tall: float = lerpf(low, high, RisoShapes.hash1(float(n) * 1.37 + float(which) * 9.1))
		var lean: float = (RisoShapes.hash1(float(n) * 2.91 + float(which) * 4.3) - 0.5) * step * 0.4
		pts.append(Vector2(x - step * 0.5, base - tall * 0.35))
		pts.append(Vector2(x + lean, base - tall))
	return pts


## A ruined castle on the summits of the near range (every fourth one): a keep with a broken top and
## a thin tower beside it, with the gaps of its battlements cut along their tops.
static func _castle(drift: float, base: float, low: float, half: Vector2, k: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var high: float = low * 110.0 / 70.0
	var step: float = (high + low) * 0.45
	var first: int = floori((-half.x + drift) / step) - 1
	for n: int in range(first, first + int(half.x * 2.0 / step) + 4):
		if posmod(n, 4) != 1:
			continue
		var x: float = float(n) * step - drift + (RisoShapes.hash1(float(n) * 2.91 + 8.6) - 0.5) * step * 0.4
		var y: float = base - lerpf(low, high, RisoShapes.hash1(float(n) * 1.37 + 18.2)) + 6.0 * k
		var w: float = 26.0 * k
		var tall: float = 30.0 * k
		out.append(RisoShapes.rrect(x - w * 0.5, y - tall, w, tall + 14.0 * k, 1.0))
		for m: int in range(3):
			out.append(RisoShapes.rrect(x - w * 0.5 + float(m) * w * 0.4, y - tall - 5.0 * k, w * 0.2, 6.0 * k, 0.5))
		out.append(RisoShapes.rrect(x + w * 0.55, y - tall * 1.6, 8.0 * k, tall * 1.6 + 14.0 * k, 1.0))
		out.append(RisoShapes.tri(Vector2(x + w * 0.55 - 2.0 * k, y - tall * 1.6), Vector2(x + w * 0.55 + 10.0 * k, y - tall * 1.6), Vector2(x + w * 0.55 + 4.0 * k, y - tall * 2.0)))
	return out


## The aurora: curtains of light, and a blue eye with a pink pupil.
func _backdrop_aurora(at: Callable, _view: Vector2, _half: Vector2, k: float, t: float, _center: Vector2) -> bool:
	for i: int in range(3):
		ink.ink(RisoPrint.PINK if i == 1 else RisoPrint.ACCENT, 0.15, [_aurora(i, t, k)])
	ink.ink(RisoPrint.BLUE, 0.15, [RisoShapes.almond(at.call(240.0, 62.0), 70.0 * k * (1.0 + 0.03 * sin(t * 0.6)), 12.0 * k, 16)])
	ink.ink(RisoPrint.PINK, 0.25, [RisoShapes.circle(at.call(240.0 + sin(t * 0.3) * 6.0, 62.0), 4.0 * k)])
	return true

## The institute, sunk in the earth: no sky, but the dark of a great vaulted hall. Two arcades of
## round arches on columns recede behind the level, the far one fainter and slower, sliding with
## the camera; a coffered vault spans the top of the sheet; and a few lamps hang far off in the
## dark, their glow faint gold. No stars, no skyline.
func _backdrop_institute(_at: Callable, view: Vector2, half: Vector2, k: float, t: float, center: Vector2) -> bool:
	for tier: int in range(2):
		var slide: float = 0.04 if tier == 0 else 0.08
		var span: float = (120.0 if tier == 0 else 170.0) * k
		var base: float = view.y * (0.05 if tier == 0 else 0.32) - center.y * slide * 0.5
		var tall: float = (110.0 if tier == 0 else 160.0) * k
		var cover: float = 0.07 if tier == 0 else 0.11
		var shapes: Array[PackedVector2Array] = []
		var x0: float = -fposmod(center.x * slide, span) - half.x - span
		var x: float = x0
		while x < half.x + span:
			# A column and the arch springing from it to the next.
			var w: float = span * 0.16
			shapes.append(RisoShapes.rrect(x - w * 0.5, base - tall, w, tall + half.y, 0.0))
			shapes.append(RisoShapes.rrect(x - w * 0.8, base - tall - w * 0.4, w * 1.6, w * 0.5, 0.0))
			var arch: PackedVector2Array = PackedVector2Array()
			var r_out: float = span * 0.5
			var r_in: float = span * 0.5 - w * 0.5
			var c: Vector2 = Vector2(x + span * 0.5, base - tall)
			for i: int in range(13):
				var a: float = PI + PI * float(i) / 12.0
				arch.append(c + Vector2(cos(a), sin(a)) * r_out)
			for i: int in range(12, -1, -1):
				var a: float = PI + PI * float(i) / 12.0
				arch.append(c + Vector2(cos(a), sin(a)) * r_in)
			shapes.append(arch)
			x += span
		ink.ink(RisoPrint.BLUE, cover, shapes, false)
	# The vault: rows of coffers across the top of the sheet.
	var coffers: Array[PackedVector2Array] = []
	var size: float = 46.0 * k
	var cx0: float = -fposmod(center.x * 0.03, size) - half.x
	for row: int in range(2):
		var y: float = -half.y + 30.0 * k + float(row) * size
		var cx: float = cx0
		while cx < half.x:
			coffers.append(RisoShapes.rrect(cx + size * 0.15, y + size * 0.15, size * 0.7, size * 0.7, size * 0.08))
			cx += size
	ink.ink(RisoPrint.BLUE, 0.06, coffers, false)
	# Lamps far off in the dark, swaying a little.
	var lamps: Array[PackedVector2Array] = []
	var glows: Array[PackedVector2Array] = []
	for i: int in range(4):
		var lx: float = fposmod(float(i) * 197.0 * k - center.x * 0.05, view.x + 200.0 * k) - half.x
		var ly: float = view.y * (0.1 + 0.08 * float(i % 2)) - center.y * 0.03 - half.y * 0.4 + sin(t * 0.6 + float(i)) * 3.0 * k
		lamps.append(RisoShapes.circle(Vector2(lx, ly), 2.6 * k, 10))
		glows.append(RisoShapes.circle(Vector2(lx, ly), 16.0 * k, 20))
	ink.ink(RisoPrint.ACCENT, 0.08, glows, false)
	ink.ink(RisoPrint.ACCENT, 0.35, lamps, false)
	return false



## The night, every other realm's: a slow orrery of blue discs with a pink one, and a pink crescent.
func _backdrop_night(at: Callable, _view: Vector2, _half: Vector2, k: float, t: float, _center: Vector2) -> bool:
	var orrery: Vector2 = at.call(380.0, 62.0)
	ink.ink(RisoPrint.BLUE, 0.12, [RisoShapes.circle(orrery, 44.0 * k, 48)])
	ink.ink(RisoPrint.BLUE, 0.12, [RisoShapes.circle(orrery + Vector2(cos(t * 0.1) * 9.0, sin(t * 0.1) * 5.0) * k, 28.0 * k, 40)])
	ink.ink(RisoPrint.PINK, 0.15, [RisoShapes.circle(orrery + Vector2(cos(t * 0.1 + 2.0) * 15.0, sin(t * 0.1 + 2.0) * 8.0) * k, 12.0 * k, 24)])
	ink.ink(RisoPrint.PINK, 0.25, [RisoShapes.crescent(at.call(96.0, 58.0), 20.0 * k, Vector2(9.0 * cos(t * 0.05), -5.0) * k, 48)])
	return true


## Stars: a fixed field that drifts at a quarter of the camera speed and wraps around the view.
func _stars(center: Vector2, view: Vector2, k: float, t: float) -> void:
	var span: Vector2 = view + Vector2(200, 200)
	var slide: Vector2 = -(center - _stars_at) * 0.25 if _stars_at != Vector2.INF else Vector2.INF
	if view != _stars_view or absf(slide.x) > STAR_SLACK or absf(slide.y) > STAR_SLACK:
		# Laid out afresh from here: each star where it falls, wrapped round the view.
		_stars_at = center
		_stars_view = view
		slide = Vector2.ZERO
		_star_dots = []
		_twinkle_at = PackedVector2Array()
		for i: int in range(70):
			var p: Vector2 = Vector2(RisoShapes.hash1(float(i) * 3.31 + 1.0) * span.x, RisoShapes.hash1(float(i) * 7.17 + 2.0) * span.y) - center * 0.25
			p = Vector2(fposmod(p.x, span.x), fposmod(p.y, span.y)) - span * 0.5
			if i < 14:
				_twinkle_at.append(p)
			else:
				var s: float = 0.4 + RisoShapes.hash1(float(i) * 1.93 + 3.0) * 1.2
				_star_dots.append(RisoShapes.circle(p, s * k * 0.55, 8))
	star_ink.position = slide
	var twinkles: Array[PackedVector2Array] = []
	for i: int in range(_twinkle_at.size()):
		var p: Vector2 = _twinkle_at[i]
		# Twinkles are hashed events, not cycles: each window a star may or may not flash,
		# at a random moment, strength and length, so no rhythm repeats.
		var period: float = 1.3 + RisoShapes.hash1(float(i) * 9.1) * 2.9
		var u: float = t / period + RisoShapes.hash1(float(i) * 2.7) * 7.0
		var n: float = floorf(u)
		var f: float = u - n
		var tw: float = 0.18
		if RisoShapes.hash1(n * 0.713 + float(i) * 5.31) < 0.6:
			var peak: float = 0.4 + RisoShapes.hash1(n * 1.37 + float(i) * 3.13) * 0.6
			var at_f: float = 0.1 + RisoShapes.hash1(n * 2.11 + float(i) * 1.77) * 0.6
			var width: float = 0.08 + RisoShapes.hash1(n * 3.7 + float(i) * 0.91) * 0.2
			tw = maxf(tw, peak * clampf(1.0 - absf(f - at_f) / width, 0.0, 1.0))
		twinkles.append(RisoShapes.sparkle(p, 2.4 * k * tw))
	star_ink.ink(RisoPrint.ACCENT, 1.0, _star_dots)
	star_ink.ink(RisoPrint.ACCENT, 1.0, twinkles)


## A cloud `w` across and about `h` high, its base on `c`: flat underneath, billowing on top in a
## row of rounded heaps (bigger in the middle), the same shape every time for `which`.
static func _cloud(c: Vector2, w: float, h: float, which: int) -> PackedVector2Array:
	var heaps: int = 4 + which % 2
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(w * 0.5, 0.0), c + Vector2(-w * 0.5, 0.0)])
	for i: int in range(heaps):
		var u: float = (float(i) + 0.5) / float(heaps)
		var middle: float = 1.0 - absf(u - 0.5) * 1.2
		var r: float = (w / float(heaps)) * (0.55 + 0.25 * RisoShapes.hash1(float(which * 7 + i) * 1.3))
		var top: float = h * (0.45 + 0.55 * middle)
		var cx: float = c.x - w * 0.5 + u * w
		for k: int in range(7):
			var a: float = PI + PI * float(k) / 6.0
			pts.append(Vector2(cx + cos(a) * r, c.y - top + r * 0.5 + sin(a) * minf(r, top)))
	return RisoShapes.smooth(pts, 2)


## Far off, in a faint blue screen: a band of ruined arches, towers and floating islands that
## slides at a tenth of the camera speed and repeats every SKY_SPAN. Each slot's piece is a
## hash of its index, so the skyline is the same wherever you stand.
const SKY_SPAN: float = 5200.0
const SKY_SLOTS: int = 13

func _skyline(center: Vector2, view: Vector2, half: Vector2) -> void:
	var slide: Vector2 = -(center - _sky_at) * Vector2(0.1, 0.04) if _sky_at != Vector2.INF else Vector2.INF
	if view == _sky_view and absf(slide.x) <= SKYLINE_SLACK and absf(slide.y) <= SKYLINE_SLACK:
		sky_ink.position = slide
		sky_ink.ink(RisoPrint.BLUE, 0.07, _sky_far, false)
		sky_ink.ink(RisoPrint.BLUE, 0.11, _sky_near, false)
		return
	_sky_at = center
	_sky_view = view
	sky_ink.position = Vector2.ZERO
	var far: Array[PackedVector2Array] = []
	var near: Array[PackedVector2Array] = []
	var slot_w: float = SKY_SPAN / float(SKY_SLOTS)
	var drift: float = center.x * 0.1
	var ground: float = view.y * 0.32 - center.y * 0.04
	var first: int = floori((drift - half.x) / slot_w) - 1
	for n: int in range(first, first + int(view.x / slot_w) + 4):
		var i: int = posmod(n, SKY_SLOTS)
		var x: float = float(n) * slot_w - drift + slot_w * 0.5
		var r1: float = RisoShapes.hash1(float(i) * 4.13 + 1.7)
		var r2: float = RisoShapes.hash1(float(i) * 2.71 + 8.3)
		var r3: float = RisoShapes.hash1(float(i) * 6.07 + 3.1)
		var into: Array[PackedVector2Array] = near if r3 < 0.5 else far
		if r1 < 0.4:
			# A colonnade of arches on a plinth.
			var w: float = 120.0 + r2 * 120.0
			var h: float = 140.0 + r3 * 160.0
			into.append(RisoShapes.rrect(x - w * 0.5, ground - h, w, h + half.y, 6))
			for k: int in range(3):
				var aw: float = w / 4.0
				into.append(RisoShapes.arch(x - w * 0.5 + aw * 0.3 + float(k) * aw * 1.25, ground - h * 0.7, aw, h * 0.7, 8))
		elif r1 < 0.7:
			# A tower with a pointed roof.
			var w: float = 50.0 + r2 * 40.0
			var h: float = 260.0 + r3 * 260.0
			into.append(RisoShapes.rrect(x - w * 0.5, ground - h, w, h + half.y, 4))
			into.append(RisoShapes.tri(Vector2(x - w * 0.7, ground - h + 2.0), Vector2(x + w * 0.7, ground - h + 2.0), Vector2(x, ground - h - w * 1.4)))
		else:
			# A floating island with a spire.
			var w: float = 160.0 + r2 * 160.0
			var y: float = ground - 260.0 - r3 * 200.0
			var rock: PackedVector2Array = PackedVector2Array()
			for k: int in range(13):
				var a: float = PI * float(k) / 12.0
				rock.append(Vector2(x + cos(a) * w * 0.5, y + sin(a) * w * (0.25 + 0.12 * sin(float(k) * 1.7 + r2 * 5.0))))
			into.append(rock)
			into.append(RisoShapes.tri(Vector2(x - 14.0, y + 2.0), Vector2(x + 14.0, y + 2.0), Vector2(x + 4.0, y - 70.0 - r2 * 50.0)))
	_sky_far = far
	_sky_near = near
	sky_ink.ink(RisoPrint.BLUE, 0.07, far, false)
	sky_ink.ink(RisoPrint.BLUE, 0.11, near, false)


## Hyperspace: no skyline and no still stars. A glow lies ahead (the way on is to the right) and
## streaks of light rush back past the view, the nearer ones longer, faster and bare paper.
const WARP_STREAKS: int = 56

func _warp(center: Vector2, view: Vector2, t: float) -> void:
	var ahead: Vector2 = Vector2(view.x * 0.25, -view.y * 0.05)
	ink.ink(RisoPrint.BLUE, 0.14, [RisoShapes.ellipse(ahead, view.x * 0.55, view.y * 0.42, 48)])
	ink.ink(RisoPrint.PINK, 0.1, [RisoShapes.ellipse(ahead, view.x * 0.3, view.y * 0.22, 40)])
	var span: Vector2 = view + Vector2(900, 200)
	var far: Array[PackedVector2Array] = []
	var near: Array[PackedVector2Array] = []
	for i: int in range(WARP_STREAKS):
		var depth: float = RisoShapes.hash1(float(i) * 5.13 + 0.7)
		var speed: float = 700.0 + 2600.0 * depth
		var x: float = fposmod(RisoShapes.hash1(float(i) * 8.91 + 2.2) * span.x - t * speed - center.x * (0.2 + 0.8 * depth), span.x) - span.x * 0.5
		var y: float = fposmod(RisoShapes.hash1(float(i) * 2.37 + 4.1) * span.y - center.y * (0.1 + 0.3 * depth), span.y) - span.y * 0.5
		var length: float = view.x * (0.04 + 0.22 * depth * depth)
		var width: float = view.y * (0.002 + 0.004 * depth)
		var streak: PackedVector2Array = PackedVector2Array([Vector2(x, y), Vector2(x + length * 0.12, y - width), Vector2(x + length, y), Vector2(x + length * 0.12, y + width)])
		(near if depth > 0.7 else far).append(streak)
	ink.ink(RisoPrint.ACCENT, 0.7, far, false)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 0.9, near)


func _aurora(i: int, t: float, k: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for x: int in range(-10, 491, 10):
		var y: float = 24.0 + float(i) * 14.0 + sin(float(x) * 0.018 + t * 0.5 + float(i) * 2.0) * 10.0
		pts.append(Vector2((float(x) - 240.0) * k, (y - 135.0) * k))
	for x: int in range(490, -11, -10):
		var y0: float = 24.0 + float(i) * 14.0 + sin(float(x) * 0.018 + t * 0.5 + float(i) * 2.0) * 10.0
		var y: float = y0 + 46.0 + sin(float(x) * 0.03 + t * 0.3 + float(i)) * 8.0
		pts.append(Vector2((float(x) - 240.0) * k, (y - 135.0) * k))
	return pts
