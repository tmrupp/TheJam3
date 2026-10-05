extends Node2D
## The night sheet behind everything: a solid night flood, slow-drifting stars and a few large
## abstract shapes per realm. Follows the camera; only the stars move with parallax.

const HTML_WIDTH: float = 480.0
var ink: InkCanvas


func _ready() -> void:
	z_index = -40
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)


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
	var t: float = Time.get_ticks_msec() / 1000.0
	var realm: StringName = RisoPrint.instance.realm
	var half: Vector2 = view * 0.5 + Vector2(240, 240)
	# HTML-space (480 x 270) point to local space.
	var at: Callable = func(x: float, y: float) -> Vector2: return Vector2((x - 240.0) * k, (y - 135.0) * k)
	ink.begin()
	# A dense screen rather than a solid: the night keeps a fine texture of paper, as in the prototype.
	ink.ink(RisoPrint.NIGHT, 0.94, [PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])], false)
	if realm == &"hyperspace":
		_warp(center, view, t)
		ink.finish()
		return
	if realm == &"twilight":
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
	elif realm == &"cemetery":
		# A pale moon low over the graves, faint through the night, with banks of mist drifting across.
		var moon: Vector2 = at.call(352.0, 64.0)
		ink.ink(RisoPrint.ACCENT, 0.1, [RisoShapes.circle(moon, 30.0 * k, 40)])
		ink.lift_ink([RisoPrint.NIGHT], 0.3, [RisoShapes.circle(moon, 17.0 * k, 40)])
		ink.ink(RisoPrint.BLUE, 0.15, [RisoShapes.circle(moon + Vector2(-4.0, 3.0) * k, 4.0 * k, 16), RisoShapes.circle(moon + Vector2(5.0, -5.0) * k, 3.0 * k, 12)])
		for i: int in range(3):
			var drift: float = fposmod(t * (4.0 + float(i) * 2.0) + float(i) * 170.0, 640.0) - 80.0
			ink.ink(RisoPrint.BLUE, 0.12, [_cloud(at.call(drift, 92.0 + float(i) * 34.0), (90.0 + float(i) * 30.0) * k, (16.0 + float(i) * 4.0) * k, i)])
	elif realm == &"aurora":
		for i: int in range(3):
			ink.ink(RisoPrint.PINK if i == 1 else RisoPrint.ACCENT, 0.15, [_aurora(i, t, k)])
		ink.ink(RisoPrint.BLUE, 0.15, [RisoShapes.almond(at.call(240.0, 62.0), 70.0 * k * (1.0 + 0.03 * sin(t * 0.6)), 12.0 * k, 16)])
		ink.ink(RisoPrint.PINK, 0.25, [RisoShapes.circle(at.call(240.0 + sin(t * 0.3) * 6.0, 62.0), 4.0 * k)])
	else:
		var orrery: Vector2 = at.call(380.0, 62.0)
		ink.ink(RisoPrint.BLUE, 0.12, [RisoShapes.circle(orrery, 44.0 * k, 48)])
		ink.ink(RisoPrint.BLUE, 0.12, [RisoShapes.circle(orrery + Vector2(cos(t * 0.1) * 9.0, sin(t * 0.1) * 5.0) * k, 28.0 * k, 40)])
		ink.ink(RisoPrint.PINK, 0.15, [RisoShapes.circle(orrery + Vector2(cos(t * 0.1 + 2.0) * 15.0, sin(t * 0.1 + 2.0) * 8.0) * k, 12.0 * k, 24)])
		ink.ink(RisoPrint.PINK, 0.25, [RisoShapes.crescent(at.call(96.0, 58.0), 20.0 * k, Vector2(9.0 * cos(t * 0.05), -5.0) * k, 48)])
	_skyline(center, view, half)
	# Stars: fixed field that drifts at a quarter of the camera speed and wraps around the view.
	var span: Vector2 = view + Vector2(200, 200)
	var dots: Array[PackedVector2Array] = []
	var twinkles: Array[PackedVector2Array] = []
	for i: int in range(70):
		var p: Vector2 = Vector2(RisoShapes.hash1(float(i) * 3.31 + 1.0) * span.x, RisoShapes.hash1(float(i) * 7.17 + 2.0) * span.y) - center * 0.25
		p = Vector2(fposmod(p.x, span.x), fposmod(p.y, span.y)) - span * 0.5
		var s: float = 0.4 + RisoShapes.hash1(float(i) * 1.93 + 3.0) * 1.2
		if i < 14:
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
		else:
			dots.append(RisoShapes.circle(p, s * k * 0.55, 8))
	ink.ink(RisoPrint.ACCENT, 1.0, dots)
	ink.ink(RisoPrint.ACCENT, 1.0, twinkles)
	ink.finish()


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
	ink.ink(RisoPrint.BLUE, 0.07, far, false)
	ink.ink(RisoPrint.BLUE, 0.11, near, false)


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
