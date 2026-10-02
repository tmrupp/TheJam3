extends Node2D
## Ink art for one spawned prefab. `kind` is set by RisoPrint's dresser from the prefab path.
## Drawn in world pixels (the owner's scale is cancelled); the owner's rotation still applies,
## so wall and ceiling spikes point the right way. Presentation only.

class_name RisoProp
const STATIC_KINDS: Array[StringName] = [&"door", &"ledge", &"thorns", &"cracked"]


## A crescent-bowed key, in world pixels, centred near `o`.
static func key_shape(o: Vector2, s: float) -> Array[PackedVector2Array]:
	return [
		RisoShapes.crescent(o + Vector2(-10, 0) * s, 11.0 * s, Vector2(5, -2) * s),
		RisoShapes.rrect(o.x - 3.0 * s, o.y - 3.5 * s, 24.0 * s, 7.0 * s, 3.5 * s),
		RisoShapes.rrect(o.x + 12.0 * s, o.y, 6.0 * s, 11.0 * s, 3.0 * s),
	]

var kind: StringName = &""
var ink: InkCanvas
var host: Node2D
var t: float = 0.0
var phase: float = 0.0
var half: float = 64.0
## Printed text (prices, names), reused frame to frame; see _text().
var labels: Array[Label] = []
## Wisp turning: the wisp swoops round a tight circle to face the other way (forward, up and
## over, back down), its body following the path's heading. Timed by the art's own clock from the
## moment its facing changes, while its Mover holds still for the same time. The body is symmetric about its spine (y = -8.2), so half a turn of the old facing is
## the new facing upright; the eyes slide to their mirrored height on the way so they land exactly.
const WISP_LOOP_W: float = 30.0
const WISP_LOOP_H: float = 26.0
const WISP_TURN_TIME: float = 0.5
var wisp_turn_t0: float = -100.0
static var _loop: PackedVector2Array = PackedVector2Array()
static var _loop_heading: PackedFloat32Array = PackedFloat32Array()
var wisp_from: float = 0.0
var wisp_to: float = 0.0
## This turn's loop size, fitted to the open space around the wisp when the turn starts.
var wisp_loop_w: float = WISP_LOOP_W
var wisp_loop_h: float = WISP_LOOP_H
## A springy lean that the wizard sets going as they pass (lanterns).
var brush_a: float = 0.0
var brush_v: float = 0.0
var _dt: float = 0.0
var labels_used: int = 0
## Shrine labels pop up over an offer while the wizard is within POP_REACH of it (see _pop()).
const POP_REACH: Vector2 = Vector2(40, 110)
## Pop-up centre height over the ground: above the interact prompt over the wizard's head.
const POP_Y: float = 255.0
var pops: Array[float] = []


func _ready() -> void:
	host = get_parent() as Node2D
	if host != null and host.scale.x != 0.0 and host.scale.y != 0.0:
		scale = Vector2(1.0 / host.scale.x, 1.0 / host.scale.y)
	phase = RisoShapes.hash1(float(host.get_instance_id() % 997)) * TAU if host != null else 0.0
	var tm: TileMap = get_node_or_null("/root/Main/TileMap") as TileMap
	if tm != null and tm.tile_set != null:
		half = float(tm.tile_set.tile_size.y) * tm.global_scale.y * 0.5
	ink = InkCanvas.new()
	add_child(ink)
	z_index = 2
	_redraw()
	set_process(not STATIC_KINDS.has(kind))


func _process(delta: float) -> void:
	t += delta
	_dt = minf(delta, 0.05)
	# Only animate what the camera can see; off-screen art keeps its last print.
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		var reach: Vector2 = Vector2(get_window().content_scale_size) / cam.zoom * 0.6 + Vector2(160, 160)
		var d: Vector2 = (host.global_position - cam.get_screen_center_position()).abs()
		if d.x > reach.x or d.y > reach.y:
			return
	_redraw()


## Distance from the host's origin down to the ground surface of its cell, in world pixels.
## Measured live because some prefabs (checkpoints) shift themselves after spawning.
func _ground() -> float:
	var tm: TileMap = get_node_or_null("/root/Main/TileMap") as TileMap
	if tm == null or host == null:
		return half
	var cell: Vector2i = tm.local_to_map(tm.to_local(host.global_position))
	return tm.to_global(tm.map_to_local(cell)).y + half - host.global_position.y


func _redraw() -> void:
	ink.begin()
	labels_used = 0
	match kind:
		&"mote": _mote()
		&"key": _key()
		&"inkwell": _inkwell()
		&"portal": _portal()
		&"door": _door()
		&"lantern": _lantern()
		&"exit": _exit()
		&"moon": _moon()
		&"ledge": _ledge()
		&"lift": _lift()
		&"thorns": _thorns()
		&"ghost": _ghost()
		&"shrine": _shrine()
		&"cracked": _cracked()
		&"wisp": _wisp()
		&"watcher": _watcher()
		&"shard": _shard()
	for i: int in range(labels_used, labels.size()):
		labels[i].visible = false
	ink.finish()


# ------------------------------------------------------------------ pickups

func _mote() -> void:
	var y: float = sin(t * 3.0 + phase) * 4.0
	var spin: float = maxf(0.25, absf(cos(t * 2.4 + phase)))
	var star: PackedVector2Array = Transform2D(0.0, Vector2(spin, 1.0), 0.0, Vector2(0, y)) * RisoShapes.sparkle(Vector2.ZERO, 18.0)
	ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(Vector2(0, y), 22.0, 24)])
	ink.ink(RisoPrint.ACCENT, 1.0, [star])


func _key() -> void:
	var sprite: CanvasItem = host.get_node_or_null("Sprite2D") as CanvasItem
	if sprite != null and not sprite.visible:
		return
	var o: Vector2 = Vector2(0, sin(t * 3.0 + phase) * 4.0)
	var shape: Array[PackedVector2Array] = RisoProp.key_shape(o, 1.0)
	for plate: int in RisoPrint.key_inks(int(host.get_meta(&"key_color", 0))):
		ink.ink(plate, 1.0, shape)


## The ink well: a big gold-rimmed pot on the floor with a paper label, a pulsing halo, a drop of
## ink rising and falling, a rolled map floating over it with motes circling, and its price on a
## plaque. Once paid it is dry: no drop, no map, no glow, a dim rim.
func _inkwell() -> void:
	var g: float = _ground()
	var dry: bool = bool(host.call("used")) if host.has_method("used") else false
	var o: Vector2 = Vector2(0, g - 30.0)
	var pot_t: Transform2D = Transform2D(0.0, Vector2(2.3, 2.3), 0.0, o)
	var pulse: float = 1.0 + 0.08 * sin(t * 3.0 + phase)
	if not dry:
		# A beam of light rising out of the well, and a bright halo: you can spot it from afar.
		var beam: PackedVector2Array = PackedVector2Array([o + Vector2(-20, -10), o + Vector2(20, -10), o + Vector2(44 * pulse, -330), o + Vector2(-44 * pulse, -330)])
		ink.ink_graded(RisoPrint.ACCENT, [beam], [PackedFloat32Array([0.85, 0.85, 0.0, 0.0])])
		ink.ink(RisoPrint.ACCENT, 0.35, [RisoShapes.ellipse(o + Vector2(0, -50), 84.0 * pulse, 92.0 * pulse, 32)])
		ink.ink(RisoPrint.ACCENT, 0.6, [RisoShapes.ellipse(o + Vector2(0, -40), 52.0 * pulse, 58.0 * pulse, 28)])
	var pot: PackedVector2Array = pot_t * RisoShapes.rrect(-17, -10, 34, 24, 10)
	var neck: PackedVector2Array = pot_t * RisoShapes.rrect(-8, -18, 16, 10, 3)
	ink.ink(RisoPrint.BLUE, 1.0, [pot, neck])
	ink.ink(RisoPrint.NIGHT, 0.35, [pot_t * RisoShapes.rrect(3, -8, 12, 20, 6)], false)
	ink.ink(RisoPrint.ACCENT, 0.4 if dry else 1.0, [pot_t * RisoShapes.rrect(-10, -21, 20, 5, 2.5)])
	ink.ink(RisoPrint.NIGHT, 1.0, [pot_t * RisoShapes.ellipse(Vector2(0, -20), 6.0, 1.6, 12)])
	var label: PackedVector2Array = pot_t * RisoShapes.rrect(-11, -3, 18, 10, 3)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [label])
	ink.ink(RisoPrint.NIGHT, 1.0, [pot_t * RisoShapes.circle(Vector2(-2, 2), 2.4, 10)], false)
	if dry:
		return
	# The drop: rises from the mouth, hangs, falls back in.
	var u: float = fmod(t * 0.7 + phase, 1.0)
	var lift: float = sin(u * PI) * 24.0
	var d: Vector2 = pot_t * Vector2(0, -24.0) + Vector2(0, -lift)
	var drop: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([d + Vector2(0, -11), d + Vector2(7, 1), d + Vector2(0, 7), d + Vector2(-7, 1)]))
	ink.ink(RisoPrint.BLUE, 1.0, [drop])
	ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT], [RisoShapes.circle(d + Vector2(-2.5, 0), 2.4, 8)])
	# A rolled map floating above: paper sheet with ink lines, rolled ends in blue.
	var m: Vector2 = Vector2(0, g - 178.0 + sin(t * 1.8 + phase) * 6.0)
	var sheet_t: Transform2D = Transform2D(sin(t * 1.1 + phase) * 0.08, m)
	var sheet: PackedVector2Array = sheet_t * RisoShapes.rrect(-26, -15, 52, 30, 3)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [sheet])
	ink.ink(RisoPrint.BLUE, 0.15, [sheet], false)
	var lines: Array[PackedVector2Array] = []
	for k: int in range(3):
		lines.append(sheet_t * RisoShapes.rrect(-18, -8 + float(k) * 7.0, 26.0 - float(k) * 6.0, 2.2, 1.1))
	lines.append(sheet_t * RisoShapes.circle(Vector2(13, 4), 4.0, 10))
	ink.ink(RisoPrint.NIGHT, 0.8, lines, false)
	ink.ink(RisoPrint.BLUE, 1.0, [sheet_t * RisoShapes.rrect(-31, -17, 7, 34, 3.5), sheet_t * RisoShapes.rrect(24, -17, 7, 34, 3.5)])
	var motes: Array[PackedVector2Array] = []
	for k: int in range(3):
		var a: float = t * 1.4 + TAU * float(k) / 3.0
		motes.append(RisoShapes.sparkle(m + Vector2(cos(a) * 44.0, sin(a) * 18.0), 6.0))
	ink.ink(RisoPrint.ACCENT, 1.0, motes)
	_plaque("map · %d" % int(host.call("price")), Vector2(0, g - 104.0), 26, RisoPrint.BLUE)


## The wizard's astral silhouette where they died, in glow ink, with the stars it holds circling.
static func ghost_shape(at: Transform2D, facing: float = 1.0) -> Array[PackedVector2Array]:
	return [
		at * RisoShapes.smooth(PackedVector2Array([Vector2(-3.8, -15), Vector2(-6.6, -7), Vector2(-9, -2.2), Vector2(9, -2.2), Vector2(6.6, -7), Vector2(3.8, -15)])),
		at * RisoShapes.smooth(PackedVector2Array([Vector2(-5, -21.4), Vector2(-2.9, -28.4), Vector2(-facing * 4.6, -37), Vector2(2.9, -28.4), Vector2(5, -21.4)])),
	]


func _ghost() -> void:
	var s: float = 3.2
	var drift: float = sin(t * 1.7 + phase) * 5.0
	var at: Transform2D = Transform2D(sin(t * 1.1 + phase) * 0.04, Vector2(s, s), 0.0, Vector2(0, 34 + drift))
	var body: Array[PackedVector2Array] = RisoProp.ghost_shape(at)
	ink.ink(RisoPrint.GLOW, 0.12, [RisoShapes.circle(Vector2(0, -30 + drift), 70.0 * (1.0 + 0.05 * sin(t * 2.3)), 32)])
	ink.ink(RisoPrint.GLOW, 0.45, body)
	# The faceless hood between robe and hat, dark, with the eyes still lit inside it.
	var hood: PackedVector2Array = at * RisoShapes.smooth(PackedVector2Array([Vector2(-3.8, -14.4), Vector2(-5.0, -18.0), Vector2(-5.4, -22.0), Vector2(5.4, -22.0), Vector2(5.0, -18.0), Vector2(3.8, -14.4)]))
	ink.ink(RisoPrint.NIGHT, 0.7, [hood])
	ink.ink(RisoPrint.GLOW, 0.2, [hood], false)
	var eyes: Array[PackedVector2Array] = [RisoShapes.circle(at * Vector2(-1.4, -18.5), 3.0, 10), RisoShapes.circle(at * Vector2(1.4, -18.5), 3.0, 10)]
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.GLOW], eyes)
	ink.ink(RisoPrint.EYE, 1.0, eyes, false)
	var count: int = mini(int(host.get("stars")), 8)
	var motes: Array[PackedVector2Array] = []
	for i: int in range(count):
		var a: float = t * 1.3 + TAU * float(i) / float(count)
		var c: Vector2 = Vector2(0, -30 + drift) + Vector2(cos(a) * 52.0, sin(a) * 22.0)
		motes.append(RisoShapes.sparkle(c, 8.0))
	if not motes.is_empty():
		ink.ink(RisoPrint.ACCENT, 1.0, motes)


## Cracked rock: the terrain prints the cell as rock; this adds a few fine cracks in night ink
## (a seeded zigzag from each of three edges toward the middle): quiet, but there if you look.
func _cracked() -> void:
	var cracks: Array[PackedVector2Array] = []
	var seed_f: float = host.global_position.x * 0.013 + host.global_position.y * 0.029
	for k: int in range(3):
		var a: float = TAU * (float(k) / 3.0 + RisoShapes.hash1(seed_f + float(k)) * 0.2)
		var p: Vector2 = Vector2(cos(a), sin(a)) * half * 0.95
		var target: Vector2 = Vector2(RisoShapes.hash1(seed_f + 7.0) - 0.5, RisoShapes.hash1(seed_f + 9.0) - 0.5) * 20.0
		var width: float = 2.2
		for s: int in range(4):
			var q: Vector2 = p.lerp(target, 0.35) + Vector2(RisoShapes.hash1(seed_f + float(k * 5 + s)) - 0.5, RisoShapes.hash1(seed_f + float(k * 5 + s) + 3.0) - 0.5) * 22.0
			var n: Vector2 = (q - p).normalized().orthogonal()
			cracks.append(PackedVector2Array([p - n * width, q - n * width * 0.7, q + n * width * 0.7, p + n * width]))
			p = q
			width *= 0.75
	ink.ink(RisoPrint.NIGHT, 0.7, cracks, false)


## The shrine: a plinth across two cells carrying three stations side by side: two niches where
## an offered ability's mark floats over its tier pips, then a bowl with an ember bead (mending).
## Each one's name and price pop up over it as the wizard steps up to it. Once used, the marks
## are gone and the trim dims.
func _shrine() -> void:
	var g: float = _ground()
	var used: bool = bool(host.call("used"))
	var bob: float = sin(t * 2.0 + phase) * 3.0
	# Station centres come from the scene (Boon, Boon2, Mend), packed across two cells.
	var xs: Array[float] = []
	for station: String in ["Boon", "Boon2", "Mend"]:
		xs.append((host.get_node(station) as Node2D).position.x * host.scale.x)
	# The plinth runs under all three: two niches, then the mending bowl.
	var left: float = xs[0] - 40.0
	var right: float = xs[2] + 40.0
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(left, g - 22, right - left, 22, 8)])
	ink.ink(RisoPrint.ACCENT, 0.35 if used else 1.0, [RisoShapes.rrect(left + 6, g - 27, right - left - 12, 7, 3.5)])
	for i: int in range(2):
		_shrine_niche(xs[i], i, g, bob * (1.0 if i == 0 else -1.0), used)
	var mx: float = xs[2]
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(mx - 9, g - 62, 18, 42, 6), RisoShapes.ellipse(Vector2(mx, g - 64), 24.0, 7.0, 22)])
	if used:
		return
	# Mending: an ember bead over the bowl, like the HUD's health beads.
	var m: Vector2 = Vector2(mx, g - 94 + bob * 0.8)
	var full: bool = not bool(host.call("can_mend"))
	ink.ink(RisoPrint.EYE, 0.12 if full else 0.25, [RisoShapes.circle(m, 25.0, 28)])
	var bead: PackedVector2Array = RisoShapes.circle(m, 12.0, 22)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [bead])
	ink.ink(RisoPrint.EYE, 0.5 if full else 1.0, [bead], false)
	ink.ink(RisoPrint.PINK, 0.35, [bead], false)
	ink.knock([RisoPrint.EYE, RisoPrint.PINK], [RisoShapes.circle(m + Vector2(-3.5, -3.5), 4.0, 12)])
	var s: float = _pop(2, Vector2(mx, g - 50))
	if s > 0.0:
		_plaque("mend · %d" % int(host.call("heal_price")), Vector2(mx, g - POP_Y), 30, RisoPrint.PINK, s)


## One of the shrine's two niches at x = `cx`: the ability's mark floating over its tier pips and,
## while the wizard is at it, a pop-up with its name, tier and price, topped by a "swap" tag when
## it would replace the spell in the slot.
func _shrine_niche(cx: float, i: int, g: float, bob: float, used: bool) -> void:
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.arch(cx - 36, g - 122, 72, 100, 12)])
	var niche: PackedVector2Array = RisoShapes.arch(cx - 29, g - 115, 58, 93, 12)
	ink.knock([RisoPrint.BLUE], [niche])
	ink.ink(RisoPrint.NIGHT, 1.0, [niche], false)
	if used:
		return
	var a: StringName = StringName(host.call("offer", i))
	if a == &"":
		return
	var c: Vector2 = Vector2(cx, g - 84 + bob)
	ink.ink(RisoPrint.ACCENT, 0.18, [RisoShapes.circle(c, 27.0 * (1.0 + 0.05 * sin(t * 3.0 + float(i))), 28)])
	# The mark at 0.75 size, to fit the narrower niche.
	var fit: Transform2D = Transform2D(0.0, Vector2(0.75, 0.75), 0.0, c)
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoProp.glyph(a, Vector2.ZERO, t):
		mark.append(fit * poly)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], mark)
	ink.ink(RisoPrint.ACCENT, 1.0, mark, false)
	if a == &"vigor":
		ink.ink(RisoPrint.PINK, 0.4, mark, false)
	var next: int = int(host.call("offer_tier", i))
	var pips: Array[PackedVector2Array] = []
	for k: int in range(next):
		pips.append(RisoShapes.circle(Vector2(cx + float(k) * 10.0 - float(next - 1) * 5.0, g - 52.0), 3.2, 10))
	ink.ink(RisoPrint.ACCENT, 1.0, pips)
	# Name, tier and price pop up over the niche only while the wizard stands at it.
	var s: float = _pop(i, Vector2(cx, g - 50))
	if s <= 0.0:
		return
	_plaque("%s %s · %d" % [Abilities.NAMES[a], Abilities.roman(next), int(host.call("offer_price", i))], Vector2(cx, g - POP_Y), 30, RisoPrint.ACCENT, s)
	if bool(host.call("swap", i)):
		_plaque("swap", Vector2(cx, g - POP_Y - 40.0 * s), 22, RisoPrint.PINK, s)


# ------------------------------------------------------------------ places

func _portal() -> void:
	if host.has_meta(&"rift"):
		_rift()
		return
	var r: float = 46.0 * (1.0 + 0.04 * sin(t * 2.0 + phase))
	var a: float = t * 2.0 * (1.0 if int(phase * 10.0) % 2 == 0 else -1.0)
	var outer: int = RisoPrint.ACCENT if int(phase * 10.0) % 2 == 0 else RisoPrint.PINK
	var inner: int = RisoPrint.PINK if outer == RisoPrint.ACCENT else RisoPrint.ACCENT
	ink.ink(outer, 1.0, [RisoShapes.circle(Vector2.ZERO, r, 40)])
	ink.ink(inner, 1.0, [RisoShapes.circle(Vector2(cos(a), sin(a)) * 7.0, r * 0.7, 36)])
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.circle(Vector2(cos(a + 2.0), sin(a + 2.0)) * 5.0, r * 0.4, 28)])


## The wizard's own rift: a ring of glow ink (the hat's colour) round a turning night-ink eye;
## dim and still until its partner is open.
func _rift() -> void:
	var linked: bool = bool(host.get("linked"))
	var r: float = 40.0 * (1.0 + 0.05 * sin(t * 3.0 + phase))
	var a: float = t * (3.0 if linked else 0.6)
	ink.ink(RisoPrint.GLOW, 0.3 if linked else 0.15, [RisoShapes.circle(Vector2.ZERO, r * 1.35, 36)])
	var ring: PackedVector2Array = RisoShapes.circle(Vector2.ZERO, r, 36)
	ink.ink(RisoPrint.GLOW, 1.0 if linked else 0.5, [ring])
	var hole: PackedVector2Array = RisoShapes.circle(Vector2(cos(a), sin(a)) * 4.0, r * 0.62, 32)
	ink.knock([RisoPrint.GLOW], [hole])
	ink.ink(RisoPrint.NIGHT, 1.0, [hole], false)
	ink.ink(RisoPrint.GLOW, 0.6, [Transform2D(a, Vector2.ZERO) * RisoShapes.sparkle(Vector2.ZERO, r * 0.35)], false)


func _door() -> void:
	RisoProp.portcullis(ink, _ground(), half, int(host.get_meta(&"key_color", 0)), 0.0, 1.0)


## A portcullis filling its corridor cell: a header beam at the ceiling, four iron bars ending
## in spikes just above the floor, and one cross-rail carrying a paper lock plate in the key
## colour it needs. `lift` (0 closed, 1 open) winches the grate up into the header: the bars
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
		ink.ink(RisoPrint.BLUE, fade, iron)
		if span > 40.0:
			var plate: PackedVector2Array = RisoShapes.rrect(-19, ly - 14.0, 38, 28, 8)
			ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [plate])
			var lock: Array[PackedVector2Array] = RisoProp.key_shape(Vector2(-3, ly), 0.65)
			for plate_ink: int in RisoPrint.key_inks(key_color):
				ink.ink(plate_ink, fade, lock, false)
	ink.ink(RisoPrint.BLUE, fade, [RisoShapes.rrect(-half, top - 2.0, 2.0 * half, 14, 4)])


## Spring a lean toward `target`, pushed by the wizard passing near `at` (within `reach`).
func _brush(at: Vector2, reach: float) -> float:
	var player: Player = host.get_node_or_null("/root/Main/Player") as Player
	var target: float = 0.0
	if player != null:
		var d: Vector2 = to_global(at) - player.global_position
		var close: float = clampf(1.0 - d.length() / reach, 0.0, 1.0)
		if close > 0.0:
			target = (signf(d.x) * 0.1 - clampf(player.velocity.x / 300.0, -1.0, 1.0) * 0.22) * sqrt(close)
	brush_v += ((target - brush_a) * 24.0 - brush_v * 4.0) * _dt
	brush_a += brush_v * _dt
	return brush_a


func _lantern() -> void:
	var lit: bool = MapInfo.instance != null and MapInfo.instance.is_respawn_lantern(host)
	var spent: bool = MapInfo.instance != null and MapInfo.instance.is_lantern_spent(host)
	var sw: float = sin(t * 2.2 + phase) * 0.12 - _brush(Vector2(30, _ground() - 80.0), 140.0)
	var g: float = _ground()
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-4, g - 110, 8, 110, 4), RisoShapes.rrect(-3, g - 111, 38, 6, 3)])
	var hang: Transform2D = Transform2D(sw, Vector2(30, g - 106))
	ink.ink(RisoPrint.BLUE, 1.0, [hang * RisoShapes.rrect(-2, 0, 4, 18, 2), hang * RisoShapes.rrect(-14, 14, 28, 8, 4)])
	var glass: PackedVector2Array = hang * RisoShapes.rrect(-12, 20, 24, 28, 10)
	if lit:
		ink.ink(RisoPrint.EYE, 0.25, [hang * RisoShapes.circle(Vector2(0, 34), 44.0, 32)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [glass])
		ink.ink(RisoPrint.EYE, 1.0, [glass], false)
		ink.knock([RisoPrint.EYE], [hang * RisoShapes.rrect(-4, 28, 8, 12, 4)])
	elif spent:
		# Empty glass and a charred wick: this lantern has already absorbed a death.
		ink.ink(RisoPrint.NIGHT, 0.6, [glass], false)
		ink.ink(RisoPrint.BLUE, 0.5, [hang * RisoShapes.rrect(-3, 38, 6, 6, 2)], false)
	else:
		# Unclaimed: a low ember behind the glass, waiting to be lit.
		var flick: float = 0.8 + 0.2 * sin(t * 7.0 + phase)
		ink.ink(RisoPrint.EYE, 0.12, [hang * RisoShapes.circle(Vector2(0, 34), 24.0 * flick, 24)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [glass])
		ink.ink(RisoPrint.EYE, 0.5, [glass], false)
		ink.ink(RisoPrint.BLUE, 0.35, [glass], false)


func _exit() -> void:
	# A doorway out of the level. Open exits are lit (cleared to paper, washed yellow, a star);
	# an unpaid deeper exit stays dark and prints its price. A chevron shows where it leads.
	var which: int = int(host.get("exit"))
	var owed: int = int(host.call("price")) if host.has_method("price") else 0
	var needs: int = int(host.call("lock")) if host.has_method("lock") else -1
	var pulse: float = 1.0 + 0.08 * sin(t * 2.5 + phase)
	var g: float = _ground()
	var opening: PackedVector2Array = RisoShapes.arch(-44, g - 110, 88, 110, 14)
	var frame: int = RisoPrint.PINK if which == MapInfo.Exit.DEEPER else RisoPrint.BLUE
	ink.ink(frame, 1.0, [RisoShapes.arch(-52, g - 118, 104, 118, 14)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [opening])
	var star: PackedVector2Array = Transform2D(t * 0.4, Vector2(0, g - 58)) * RisoShapes.sparkle(Vector2.ZERO, 20.0 * pulse)
	if needs >= 0:
		# Locked: dark, with a lock in the colour of key it needs, as on the doors.
		ink.ink(RisoPrint.NIGHT, 1.0, [opening], false)
		ink.ink(RisoPrint.BLUE, 0.35, [opening], false)
		var lock: Array[PackedVector2Array] = RisoProp.key_shape(Vector2(-6, g - 58), 0.9)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], lock)
		for plate: int in RisoPrint.key_inks(needs):
			ink.ink(plate, 1.0, lock, false)
	elif owed > 0:
		ink.ink(RisoPrint.NIGHT, 1.0, [opening], false)
		ink.ink(RisoPrint.BLUE, 0.35, [opening], false)
		# The price on a bare-paper plaque, with a star above it.
		var plaque: PackedVector2Array = RisoShapes.rrect(-28, g - 62, 56, 38, 12)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [plaque])
		ink.ink(RisoPrint.ACCENT, 0.2, [plaque], false)
		var mote: PackedVector2Array = Transform2D(t * 0.4, Vector2(0, g - 82)) * RisoShapes.sparkle(Vector2.ZERO, 13.0 * pulse)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [mote])
		ink.ink(RisoPrint.ACCENT, 1.0, [mote], false)
	else:
		ink.ink(RisoPrint.EYE, 0.3, [opening], false)
		ink.ink(RisoPrint.EYE, 0.35, [RisoShapes.circle(Vector2(0, g - 58), 30.0 * pulse, 28)], false)
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [star])
		ink.ink(RisoPrint.EYE, 1.0, [star], false)
	# Chevron above the arch, pointing the way this exit leads.
	var dir: Vector2 = Vector2.DOWN
	match which:
		MapInfo.Exit.BACK: dir = Vector2.UP
		MapInfo.Exit.LEFT: dir = Vector2.LEFT
		MapInfo.Exit.RIGHT: dir = Vector2.RIGHT
	var bob: float = sin(t * 3.0 + phase) * 3.0
	var at: Vector2 = Vector2(0, g - 140) + dir * bob
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var chevron: PackedVector2Array = PackedVector2Array([at + dir * 10.0, at + side * 22.0 - dir * 12.0, at + side * 16.0 - dir * 18.0,
		at - dir * 2.0, at - side * 16.0 - dir * 18.0, at - side * 22.0 - dir * 12.0])
	ink.ink(frame, 1.0, [chevron])
	if owed > 0:
		_text(str(owed), Vector2(0, g - 43), 34)


## Night-ink serif text centred on `at` (in this prop's pixels); returns its width.
func _text(text: String, at: Vector2, px: int, s: float = 1.0) -> float:
	if labels_used >= labels.size():
		var label: Label = Label.new()
		label.add_theme_font_override("font", RisoTheme.serif())
		label.add_theme_color_override("font_color", Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
		# A same-ink outline thickens the strokes so they print solid instead of screening away.
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		add_child(label)
		labels.append(label)
	var label: Label = labels[labels_used]
	labels_used += 1
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_constant_override("outline_size", maxi(2, px / 9))
	var w: float = RisoTheme.serif().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	label.size = Vector2(w + 8.0, float(px) * 1.4)
	label.text = text
	label.scale = Vector2(s, s)
	label.position = at - label.size * s * 0.5
	label.visible = true
	return w * s


func _plaque_width(text: String, px: int) -> float:
	return RisoTheme.serif().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 22.0


## A bare-paper plaque with `text` on it, centred on `at`, scaled by `s`.
func _plaque(text: String, at: Vector2, px: int, tint: int, s: float = 1.0) -> void:
	var w: float = _plaque_width(text, px) * s
	var h: float = float(px) * 1.25 * s
	var plate: PackedVector2Array = RisoShapes.rrect(at.x - w * 0.5, at.y - h * 0.5, w, h, h * 0.35)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [plate])
	ink.ink(tint, 0.2, [plate], false)
	_text(text, at, px, s)


## Pop-up `i` eased toward 1 while the wizard stands within reach of `at` (local, world pixels)
## and back to 0 as they leave; returns its scale, with a little overshoot as it opens.
func _pop(i: int, at: Vector2) -> float:
	var player: Player = host.get_node_or_null("/root/Main/Player") as Player
	var target: float = 0.0
	if player != null:
		var d: Vector2 = (to_global(at) - player.global_position).abs()
		target = 1.0 if d.x < POP_REACH.x and d.y < POP_REACH.y else 0.0
	while pops.size() <= i:
		pops.append(0.0)
	pops[i] = move_toward(pops[i], target, _dt * 5.0)
	var p: float = pops[i] - 1.0
	return 0.0 if pops[i] < 0.02 else 1.0 + 2.7 * p * p * p + 1.7 * p * p


static func chevron(at: Vector2, dir: Vector2, k: float) -> PackedVector2Array:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	return PackedVector2Array([at + dir * 10.0 * k, at + (side * 22.0 - dir * 12.0) * k, at + (side * 16.0 - dir * 18.0) * k,
		at - dir * 2.0 * k, at + (-side * 16.0 - dir * 18.0) * k, at + (-side * 22.0 - dir * 12.0) * k])


## An ability's mark, centred on `c`: what a shrine teaches.
static func glyph(a: StringName, c: Vector2, t: float) -> Array[PackedVector2Array]:
	match a:
		&"dash":
			return [chevron(c + Vector2(-8, 0), Vector2.RIGHT, 0.8), chevron(c + Vector2(12, 0), Vector2.RIGHT, 0.8)]
		&"double_jump":
			return [chevron(c + Vector2(0, -10), Vector2.UP, 0.8), chevron(c + Vector2(0, 12), Vector2.UP, 0.8)]
		&"wall_climb":
			return [RisoShapes.rrect(c.x - 22, c.y - 26, 9, 52, 4), RisoShapes.crescent(c + Vector2(6, -4), 14.0, Vector2(-6, 0)), RisoShapes.circle(c + Vector2(4, 18), 5.0, 12)]
		&"blink":
			return [RisoShapes.circle(c + Vector2(-18, 0), 7.0, 14), RisoShapes.circle(c + Vector2(-4, 0), 2.5, 8), RisoShapes.circle(c + Vector2(5, 0), 2.5, 8), RisoShapes.circle(c + Vector2(18, 0), 10.0, 18)]
		&"parry":
			return [RisoShapes.crescent(c, 22.0, Vector2(9, 0))]
		&"astral":
			return ghost_shape(Transform2D(0.0, Vector2(1.5, 1.5), 0.0, c + Vector2(0, 28)))
		&"vigor":
			var bead: PackedVector2Array = RisoShapes.circle(c, 14.0, 24)
			return [bead]
		&"levitate":
			# A feather of three rising arcs over a ring.
			return [RisoShapes.ellipse(c + Vector2(0, 14), 18.0, 5.0, 18), RisoShapes.almond(c + Vector2(0, -6), 7.0, 18.0, 12),
				RisoShapes.rrect(c.x - 1.6, c.y - 4, 3.2, 16, 1.6)]
		&"rift":
			# Two linked rings.
			return [RisoShapes.circle(c + Vector2(-11, 0), 9.0, 18), RisoShapes.circle(c + Vector2(11, 0), 9.0, 18), RisoShapes.rrect(c.x - 6, c.y - 1.6, 12, 3.2, 1.6)]
		&"awareness":
			# An open eye with a lit pupil.
			return [RisoShapes.almond(c, 22.0, 11.0, 14), RisoShapes.circle(c, 5.0, 12)]
		&"hex":
			# A comet: a bold spark with a tapering tail behind it.
			return [RisoShapes.sparkle(c + Vector2(7, -5), 17.0), PackedVector2Array([c + Vector2(4, -12), c + Vector2(-22, 14), c + Vector2(-2, 0)])]
	return [RisoShapes.sparkle(c, 18.0)]


## A moon: a crescent in accent ink inside a soft halo, rocking as it floats. While it wanes
## (just used) it shrinks to a faint sliver and grows back.
func _moon() -> void:
	var full: float = 1.0 - clampf(float(host.get("waning")) / 2.5, 0.0, 1.0)
	var o: Vector2 = Vector2(0, sin(t * 2.2 + phase) * 6.0)
	var k: float = lerpf(0.55, 1.0, full)
	var crescent: PackedVector2Array = Transform2D(sin(t) * 0.25, Vector2(k, k), 0.0, o) * RisoShapes.crescent(Vector2.ZERO, 22.0, Vector2(10, -5))
	if full >= 1.0:
		ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(o, 34.0, 28)])
		ink.ink(RisoPrint.ACCENT, 1.0, [crescent])
		ink.ink(RisoPrint.BLUE, 0.5, [crescent])
	else:
		ink.ink(RisoPrint.ACCENT, 0.3 * full + 0.1, [crescent])


func _ledge() -> void:
	# Neighbouring platforms (or rock) on the same row join into one ledge: joined ends run to
	# the cell edge and stay square; free ends are rounded.
	var left: bool = _ledge_joined(-1)
	var right: bool = _ledge_joined(1)
	var x0: float = -half if left else -half + 1.0
	var x1: float = half if right else half - 1.0
	ink.ink(RisoPrint.BLUE, 1.0, [_bar(x0, -64.0, x1, -30.0, 12.0, not left, not right)])
	ink.ink(RisoPrint.ACCENT, 1.0, [_bar(x0 + (0.0 if left else 3.0), -67.0, x1 - (0.0 if right else 3.0), -55.0, 6.0, not left, not right)])


## A moving ledge: the static ledge's bar and cap, a pink rune glowing beneath, and its track
## printed as a faint dotted line that stays put while the ledge slides along it.
func _lift() -> void:
	var n: int = int(host.get("length"))
	var x1: float = -half + float(n) * half * 2.0
	var mid: Vector2 = Vector2(float(n - 1) * half, -half + 17.0)
	var start: Vector2 = host.get("start") as Vector2
	var holder: Node2D = host.get_parent() as Node2D
	var a: Vector2 = to_local(holder.to_global(start) if holder != null else start) + mid
	var b: Vector2 = a + (host.get("axis") as Vector2) * float(host.get("travel"))
	var dots: Array[PackedVector2Array] = []
	var steps: int = maxi(1, int(a.distance_to(b) / 26.0))
	for i: int in range(steps + 1):
		dots.append(RisoShapes.circle(a.lerp(b, float(i) / float(steps)), 3.5, 8))
	ink.ink(RisoPrint.BLUE, 0.35, dots)
	var pulse: float = 0.8 + 0.2 * sin(t * 3.0 + phase)
	for i: int in range(n):
		var c: Vector2 = Vector2(float(i) * half * 2.0, -half + 44.0)
		ink.ink(RisoPrint.PINK, 0.25, [RisoShapes.ellipse(c, 26.0 * pulse, 9.0 * pulse, 20)])
		ink.ink(RisoPrint.PINK, 1.0, [RisoShapes.almond(c, 10.0, 4.0, 8)])
	ink.ink(RisoPrint.BLUE, 1.0, [_bar(-half + 1.0, -half, x1 - 1.0, -half + 34.0, 12.0, true, true)])
	ink.ink(RisoPrint.ACCENT, 1.0, [_bar(-half + 1.0, -half - 3.0, x1 - 1.0, -half + 14.0, 8.0, true, true)])


func _ledge_joined(side: int) -> bool:
	var target: Vector2 = host.global_position + Vector2(float(side) * half * 2.0, 0.0)
	for other: Node in host.get_parent().get_children():
		if other != host and other.scene_file_path == host.scene_file_path and (other as Node2D).global_position.distance_to(target) < 2.0:
			return true
	var tm: TileMap = get_node_or_null("/root/Main/TileMap") as TileMap
	if tm != null:
		return tm.get_cell_source_id(0, tm.local_to_map(tm.to_local(target))) != -1
	return false


## A horizontal bar whose left/right ends are rounded only when free.
func _bar(x0: float, y0: float, x1: float, y1: float, r: float, round_left: bool, round_right: bool) -> PackedVector2Array:
	r = minf(r, (y1 - y0) * 0.5)
	var out: PackedVector2Array = PackedVector2Array()
	if round_left:
		for s: int in range(5):
			var t: float = PI + PI * 0.5 * float(s) / 4.0
			out.append(Vector2(x0 + r, y0 + r) + Vector2(cos(t), sin(t)) * r)
	else:
		out.append(Vector2(x0, y0))
	if round_right:
		for s: int in range(5):
			var t: float = -PI * 0.5 + PI * 0.5 * float(s) / 4.0
			out.append(Vector2(x1 - r, y0 + r) + Vector2(cos(t), sin(t)) * r)
		for s: int in range(5):
			var t: float = PI * 0.5 * float(s) / 4.0
			out.append(Vector2(x1 - r, y1 - r) + Vector2(cos(t), sin(t)) * r)
	else:
		out.append(Vector2(x1, y0))
		out.append(Vector2(x1, y1))
	if round_left:
		for s: int in range(5):
			var t: float = PI * 0.5 + PI * 0.5 * float(s) / 4.0
			out.append(Vector2(x0 + r, y1 - r) + Vector2(cos(t), sin(t)) * r)
	else:
		out.append(Vector2(x0, y1))
	return out


func _thorns() -> void:
	var spikes: Array[PackedVector2Array] = []
	for i: int in range(4):
		var x: float = -47.25 + float(i) * 31.5
		spikes.append(RisoShapes.tri(Vector2(x - 13, half + 2.0), Vector2(x, half - 40.0), Vector2(x + 13, half + 2.0)))
	ink.ink(RisoPrint.PINK, 1.0, spikes)


# ------------------------------------------------------------------ nightmares

func _wisp() -> void:
	var mover: Node = host.get_node_or_null("Mover")
	var dir: float = 1.0
	var stunned: bool = false
	if mover != null:
		dir = float(mover.get("direction"))
		stunned = bool(mover.get("stunned"))
		# Falling (as when it settles after spawning): keep the body straight rather than letting
		# the trail record the drop and hang it tail-up.
		if not bool(mover.get("grounded")):
			_trail = PackedVector2Array()
	var k: float = 3.6
	var bob: float = -3.0 - sin(t * 3.0 + phase) * 1.6
	if wisp_to == 0.0:
		wisp_from = dir
		wisp_to = dir
	if dir != wisp_to:
		wisp_from = wisp_to
		wisp_to = dir
		_fit_loop(wisp_from)
		wisp_turn_t0 = t
	var u: float = clampf((t - wisp_turn_t0) / WISP_TURN_TIME, 0.0, 1.0)
	var spinning: bool = u < 1.0
	var side: float = wisp_from if spinning else wisp_to
	var loop_at: Vector2 = Vector2.ZERO
	var spin: float = 0.0
	if spinning:
		var e: float = u * u * (3.0 - 2.0 * u)
		var sample: Array = RisoProp.wisp_loop(e)
		loop_at = Vector2(side * (sample[0] as Vector2).x * wisp_loop_w, (sample[0] as Vector2).y * wisp_loop_h)
		spin = float(sample[1])
	var turning: float = sin(clampf(spin / PI, 0.0, 1.0) * PI)
	var e_eyes: float = clampf(spin / PI, 0.0, 1.0)
	var width: float = 1.0
	# Its shadow on the floor, shrinking as it bobs up: it belongs to the ground it haunts.
	var g: float = _ground()
	var lift: float = clampf(-loop_at.y / WISP_LOOP_H, 0.0, 1.0)
	ink.ink(RisoPrint.NIGHT, 0.35 * (1.0 - lift * 0.6), [RisoShapes.ellipse(Vector2(loop_at.x, g - 3.0), (26.0 + bob * 1.2) * (1.0 - lift * 0.4), 5.0, 16)], false)
	# The body follows the path its head has travelled (see _wisp_place): the head is placed on
	# its loop, and everything behind it lies along the recorded trail, so mid-turn the tail traces
	# the head's arc and after the turn it straightens out as the wisp moves off.
	_wp_k = k
	_wp_side = side
	_wp_bob = Vector2(0, bob * k * 0.7)
	var head: Vector2 = Vector2(0, 14.0 - 3.3 * k - 8.2 * k * 0.6) + loop_at
	_wp_head_dir = Vector2(side * cos(spin), -sin(spin)) if spinning else Vector2(side, 0)
	_wisp_trail_add(to_global(head))
	var speed: float = 0.3 if stunned else 0.7
	var flicker: float = 0.85 + 0.15 * sin(t * 5.3 + phase) * sin(t * 2.1 + phase * 1.7)
	# The glow trails the wisp: strongest behind the head, thinning out past the tail.
	ink.ink(RisoPrint.PINK, 0.06 * flicker, [_wisp_place(RisoShapes.ellipse(Vector2(-10.5, -8.4), 11.0, 7.5, 28), true)])
	ink.ink(RisoPrint.PINK, 0.1 * flicker, [_wisp_place(RisoShapes.ellipse(Vector2(-6.0, -8.2), 9.5, 8.0, 28), true)])
	# Two lagging after-veils behind the body, then the body. The body is solid ink with only its
	# tail tip thinning; the veils stay faint.
	for layer: int in [2, 1, 0]:
		var lag: float = float(layer) * 0.55
		var w: Array[float] = []
		for j: int in range(4):
			w.append(sin(t * 6.0 * speed - float(j) - lag) * 1.4)
		var back: Vector2 = Vector2(-2.6, -0.4) * float(layer)
		var pts: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
			Vector2(5.6, -9), Vector2(4.6, -4.6), Vector2(1.6, -3), Vector2(-2, -3.8 + w[1] * 0.3), Vector2(-5.6, -4.8 + w[1]),
			Vector2(-9, -6.6 + w[2]), Vector2(-12.4, -8.6 + w[3]), Vector2(-8.8, -9.6 + w[2]), Vector2(-5.2, -11 + w[1] * 0.6),
			Vector2(-1.4, -13.2), Vector2(2.6, -13.4)]))
		var fade: PackedFloat32Array = PackedFloat32Array()
		var top: float = (1.0 if layer == 0 else 0.3 / float(layer)) * (1.0 if layer == 0 else flicker)
		for p: Vector2 in pts:
			# Along the body from the tail tip (0) to the head (1). The body is solid ink from about
			# the middle forward and tapers to nothing at the tail tip; the veils stay faint.
			var along: float = clampf((p.x + 12.4) / 18.0, 0.0, 1.0)
			var solid: float = clampf(along / 0.45, 0.0, 1.0)
			fade.append(top * (solid * solid * (3.0 - 2.0 * solid) if layer == 0 else lerpf(0.15, 1.0, along)))
		var poly: PackedVector2Array = _wisp_place(Transform2D(0.0, back) * pts, true)
		if layer == 0:
			# Opaque: clear the inks of whatever is behind (grass, light, glow) under the body.
			ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [_wisp_place(RisoShapes.smooth(PackedVector2Array([
				Vector2(5.6, -9), Vector2(4.6, -4.6), Vector2(1.6, -3), Vector2(-2, -3.8), Vector2(-4.5, -4.8), Vector2(-4.5, -11),
				Vector2(-1.4, -13.2), Vector2(2.6, -13.4)])), true)])
		ink.ink_graded(RisoPrint.PINK, [poly], [fade])
		if layer == 0:
			var cool: PackedFloat32Array = PackedFloat32Array()
			for a: float in fade:
				cool.append(a * 0.35)
			ink.ink_graded(RisoPrint.BLUE, [poly], [cool])
	var eyes: Array[PackedVector2Array] = []
	for eye: Vector2 in [Vector2(3.4, -9.2), Vector2(0.7, -9.4)]:
		# Mid-spin the eyes slide to their mirrored height about the spine, so after half a turn
		# they sit exactly where the upright wisp's eyes do.
		var ep: Vector2 = Vector2(eye.x, lerpf(eye.y, -16.4 - eye.y, e_eyes)) if spinning else eye
		var shape: PackedVector2Array = RisoShapes.rrect(ep.x - 1.0, ep.y - 0.4, 2.0, 0.8, 0.4, 2) if stunned else RisoShapes.ellipse(ep, 0.9, 1.9, 14)
		eyes.append(_wisp_place(shape, false))
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], eyes)


## Size the turning loop to the room: lower under a near ceiling, tighter against a wall.
func _fit_loop(forward: float) -> void:
	wisp_loop_w = WISP_LOOP_W
	wisp_loop_h = WISP_LOOP_H
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return
	var c: Vector2i = info.cell_at(host.global_position)
	var open_above: int = 0
	while open_above < 2 and info.world.is_valid(c + Vector2i(0, -open_above - 1)) and not _wisp_blocked(info, c + Vector2i(0, -open_above - 1)):
		open_above += 1
	# The wisp floats in the lower part of its cell: about 50 px clear above it in its own cell.
	wisp_loop_h = clampf(50.0 + 128.0 * float(open_above) - 24.0, 18.0, WISP_LOOP_H)
	var f: Vector2i = Vector2i(int(signf(forward)), 0)
	if _wisp_blocked(info, c + f) or (open_above > 0 and _wisp_blocked(info, c + f + Vector2i(0, -1))):
		wisp_loop_w = 16.0


func _wisp_blocked(info: MapInfo, v: Vector2i) -> bool:
	if not info.world.is_valid(v):
		return true
	var kind: int = info.world.get_cell(v).type
	return kind == MapInfo.Type.GROUND or kind == MapInfo.Type.CRACKED


## The wisp's turning loop at `e` (0..1): [position (x forward, y up negative, roughly within
## 0..1 x -1..0), heading in radians (0 forward, PI back)]. The heading sweeps from forward, up
## over the top, past backward on the way down, and levels out backward; the path is closed so it
## ends where it began. Built once by integrating the heading.
static func wisp_loop(e: float) -> Array:
	if _loop.is_empty():
		var n: int = 96
		# Heading theta(u) = PI u + c sin(PI u); pick c so the path comes back down to its start.
		var lo: float = 0.0
		var hi: float = 3.0
		var c: float = 1.0
		for it: int in range(40):
			c = (lo + hi) * 0.5
			var ys: float = 0.0
			for i: int in range(n):
				var uu: float = (float(i) + 0.5) / float(n)
				ys += sin(PI * uu + c * sin(PI * uu))
			if ys > 0.0:
				lo = c
			else:
				hi = c
		var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
		var p: Vector2 = Vector2.ZERO
		for i: int in range(n):
			var uu: float = (float(i) + 0.5) / float(n)
			var th: float = PI * uu + c * sin(PI * uu)
			p += Vector2(cos(th), -sin(th)) / float(n)
			pts.append(p)
		var drift: Vector2 = pts[n]
		var top: float = 0.001
		for i: int in range(n + 1):
			pts[i] -= drift * float(i) / float(n)
			top = maxf(top, -pts[i].y)
		var wide: float = 0.001
		for i: int in range(n + 1):
			pts[i] /= top
			wide = maxf(wide, absf(pts[i].x))
		for i: int in range(n + 1):
			pts[i].x /= wide
		_loop = pts
		_loop_heading = PackedFloat32Array()
		for i: int in range(n + 1):
			var a: Vector2 = pts[maxi(0, i - 1)]
			var b: Vector2 = pts[mini(n, i + 1)]
			var d: Vector2 = b - a
			var h: float = atan2(-d.y, d.x)
			if i > 0 and h < _loop_heading[i - 1] - PI:
				h += TAU
			_loop_heading.append(h)
		_loop_heading[0] = 0.0
		_loop_heading[n] = PI
	var f: float = clampf(e, 0.0, 1.0) * float(_loop.size() - 1)
	var i0: int = mini(int(f), _loop.size() - 2)
	var t0: float = f - float(i0)
	return [_loop[i0].lerp(_loop[i0 + 1], t0), lerpf(_loop_heading[i0], _loop_heading[i0 + 1], t0)]


## Place a wisp shape on screen by following its trail. A point's local x is how far it lies
## behind the head (x = 0) along the body, and its local y how far it sits off the spine
## (y = -8.2). Points behind the head go where the head was that distance ago, offset across the
## trail's direction there; points ahead of it extend along the head's heading. The head's
## positions are recorded in world space without the bob, which is added to the whole shape.
const WISP_TRAIL_LEN: float = 260.0
var _wp_k: float = 3.6
var _wp_side: float = 1.0
var _wp_bob: Vector2 = Vector2.ZERO
var _wp_head_dir: Vector2 = Vector2.RIGHT
var _trail: PackedVector2Array = PackedVector2Array()


func _wisp_trail_add(at: Vector2) -> void:
	# Start (or after a jump, restart) with a straight trail behind the facing.
	if _trail.is_empty() or _trail[0].distance_to(at) > 120.0:
		_trail = PackedVector2Array()
		for n: int in range(66):
			_trail.append(at - _wp_head_dir * 4.0 * float(n))
		return
	if _trail[0].distance_to(at) < 0.5:
		return
	_trail.insert(0, at)
	var total: float = 0.0
	for n: int in range(1, _trail.size()):
		total += _trail[n].distance_to(_trail[n - 1])
		if total > WISP_TRAIL_LEN:
			_trail.resize(n + 1)
			break


## Where the trail was `d` px behind the head: [position (world), direction of travel there].
func _trail_at(d: float) -> Array:
	if d <= 0.0 or _trail.size() < 2:
		return [_trail[0] - _wp_head_dir * d if not _trail.is_empty() else Vector2.ZERO, _wp_head_dir]
	var walked: float = 0.0
	for n: int in range(1, _trail.size()):
		var a: Vector2 = _trail[n - 1]
		var b: Vector2 = _trail[n]
		var seg: float = a.distance_to(b)
		if walked + seg >= d and seg > 0.0001:
			var f: float = (d - walked) / seg
			# Blend the direction toward the head's own heading right at the head, so the front
			# of the body turns with it.
			var dir: Vector2 = (a - b).normalized()
			return [a.lerp(b, f), dir]
		walked += seg
	var last: Vector2 = _trail[_trail.size() - 1]
	var tail_dir: Vector2 = (_trail[_trail.size() - 2] - last).normalized()
	return [last - tail_dir * (d - walked), tail_dir]


func _wisp_place(poly: PackedVector2Array, _curl: bool) -> PackedVector2Array:
	var sx: float = _wp_k * 1.1
	var sy: float = _wp_k * 0.6
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(poly.size())
	for n: int in range(poly.size()):
		var d: float = -poly[n].x * sx
		var at: Array = _trail_at(d)
		var dir: Vector2 = at[1]
		# Within the first stretch behind the head, ease from the head's heading to the trail's.
		if d < 14.0:
			dir = _wp_head_dir.lerp(dir, clampf(d / 14.0, 0.0, 1.0)).normalized()
		var across: Vector2 = dir.rotated(_wp_side * PI * 0.5)
		var off: Vector2 = across * ((poly[n].y + 8.2) * sy)
		# On a tight bend, keep the inside edge within the bend's radius so the body bunches
		# instead of folding over itself (a folded outline can't be printed).
		if d > 0.0:
			var older: Vector2 = _trail_at(d + 6.0)[1]
			var newer: Vector2 = _trail_at(maxf(0.0, d - 6.0))[1]
			var turn: float = older.angle_to(newer)
			if absf(turn) > 0.02:
				var centre: Vector2 = dir.rotated(signf(turn) * PI * 0.5)
				if off.dot(centre) > 0.0:
					off = off.limit_length(0.8 * 12.0 / absf(turn))
		out[n] = to_local(at[0] as Vector2) + off + _wp_bob
	# Wide shapes (glow, veils) can still cross over themselves on the tightest bend: print their
	# outline hull instead of nothing.
	if Geometry2D.triangulate_polygon(out).is_empty():
		var hull: PackedVector2Array = Geometry2D.convex_hull(out)
		if hull.size() > 3:
			hull.remove_at(hull.size() - 1)
			return _resample_loop(hull, out.size(), out[0])
	return out


## `loop` resampled evenly to `count` points (so per-vertex shading still lines up), starting
## at the point nearest `start`.
func _resample_loop(loop: PackedVector2Array, count: int, start: Vector2) -> PackedVector2Array:
	var m: int = loop.size()
	var first: int = 0
	for n: int in range(m):
		if loop[n].distance_squared_to(start) < loop[first].distance_squared_to(start):
			first = n
	var total: float = 0.0
	for n: int in range(m):
		total += loop[n].distance_to(loop[(n + 1) % m])
	var out: PackedVector2Array = PackedVector2Array()
	var seg: int = first
	var walked: float = 0.0
	var seg_len: float = loop[seg].distance_to(loop[(seg + 1) % m])
	for n: int in range(count):
		var want: float = total * float(n) / float(count)
		while walked + seg_len < want and seg_len >= 0.0:
			walked += seg_len
			seg = (seg + 1) % m
			seg_len = loop[seg].distance_to(loop[(seg + 1) % m])
		var f: float = (want - walked) / maxf(seg_len, 0.0001)
		out.append(loop[seg].lerp(loop[(seg + 1) % m], clampf(f, 0.0, 1.0)))
	return out


var _last_shot: float = -10.0
## The watcher's lid: eased toward its shooter's charge, so it opens slowly and closes gently.
var watch_open: float = 0.1
var _was_firing: bool = false


func _watcher() -> void:
	var shooter: Node = host.get_node_or_null("Shooter")
	var at: Vector2 = Vector2(0, -26.0)
	var charge: float = 0.0
	var recoil: float = 0.0
	var stunned: bool = false
	var fired: bool = false
	if shooter != null:
		var point: Node2D = shooter.get_node_or_null("ShootPoint") as Node2D
		if point != null:
			at = to_local(point.global_position) + Vector2(0, -4)
		var sfx: AudioStreamPlayer = shooter.get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
		var firing: bool = sfx != null and sfx.playing
		fired = firing and not _was_firing
		if fired:
			_last_shot = t
		_was_firing = firing
		# The eye opens as it charges, which happens only while it can see the wizard; losing
		# sight resets the charge and the lid drifts shut. A ball of ink swells at the muzzle near
		# the end, and it squints on the recoil.
		charge = clampf(float(shooter.get("charge")), 0.0, 1.0)
		var since: float = t - _last_shot
		recoil = clampf(1.0 - since * 5.0, 0.0, 1.0)
		stunned = bool(shooter.get("stunned"))
	var target: float = 0.1 + 0.9 * charge
	watch_open = move_toward(watch_open, target, _dt * (0.9 if target > watch_open else 1.6))
	var open: float = clampf(watch_open - recoil * 0.6, 0.06, 1.0)
	if stunned:
		open = 0.08
		charge = 0.0
	var k: float = 2.8
	var xf: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, at + Vector2(0, sin(t * 2.0 + phase) * 3.0))
	# A stalk rooted in the floor, swaying under the eye: the watcher grows here.
	var g: float = _ground()
	var eye: Vector2 = xf * Vector2(0, 4)
	if g - eye.y > 12.0:
		var sway: float = sin(t * 1.6 + phase) * 6.0
		var stalk: PackedVector2Array = PackedVector2Array()
		for j: int in range(6):
			var f: float = float(j) / 5.0
			stalk.append(Vector2(sway * sin(f * PI) * 0.8, lerpf(g, eye.y, f)))
		ink.ink(RisoPrint.BLUE, 1.0, RisoDecor.strip(stalk, 9.0, 4.0))
		ink.ink(RisoPrint.NIGHT, 0.3, RisoDecor.strip(stalk, 9.0, 4.0), false)
		ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.ellipse(Vector2(0, g - 2.0), 14.0, 5.0, 14)])
	var drips: Array[PackedVector2Array] = []
	for j: int in range(3):
		var x: float = -4.0 + float(j) * 4.0
		var l: float = 4.0 + sin(t * 2.0 + float(j)) * 1.5
		drips.append(xf * PackedVector2Array([Vector2(x - 1.4, 3), Vector2(x, 6 + l), Vector2(x + 1.4, 3)]))
	var lid: PackedVector2Array = xf * RisoShapes.almond(Vector2.ZERO, 10.0, 5.6, 12)
	# Solid pink over solid blue: the deep purple lid of the prototype.
	ink.ink(RisoPrint.PINK, 1.0, [lid])
	ink.ink(RisoPrint.PINK, 1.0, drips)
	ink.ink(RisoPrint.BLUE, 1.0, [lid])
	var yo: float = lerpf(2.0, 0.0, open)
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [xf * RisoShapes.almond(Vector2(0, yo), 8.2, maxf(0.3, 4.4 * open), 12)])
	var player: Node2D = host.get_node_or_null("/root/Main/Player") as Node2D
	var look: Vector2 = Vector2.ZERO
	if player != null:
		var d: Vector2 = player.global_position - to_global(at)
		look = Vector2(clampf(d.x / 200.0, -1.0, 1.0) * 2.6, clampf(d.y / 200.0, -1.0, 1.0) * 1.2)
	ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.circle(look + Vector2(0, yo), 3.0 * maxf(0.35, open), 14)])
	ink.ink(RisoPrint.BLUE, 1.0, [xf * RisoShapes.circle(look + Vector2(0, yo), 1.3 * maxf(0.35, open), 10)])
	if fired and player != null:
		var side: float = signf(look.x) if look.x != 0.0 else -1.0
		var from: Vector2 = xf * Vector2(side * 9.6, -0.6)
		RisoFx.burst(&"shot", to_global(from), (player.global_position - to_global(from)).normalized())
	if charge > 0.0:
		# The charge: a solid eye-yellow ball swelling at the corner of the eye nearest the player.
		var aim: float = signf(look.x) if look.x != 0.0 else -1.0
		var ball: float = (0.35 + charge * charge * 2.0) * k
		var corner: Vector2 = xf * Vector2(aim * 9.6, -0.6)
		var core: PackedVector2Array = RisoShapes.circle(corner, ball, 20)
		ink.ink(RisoPrint.EYE, 0.2, [RisoShapes.circle(corner, ball * 1.6, 24)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [core])
		ink.ink(RisoPrint.EYE, 1.0, [core], false)


func _shard() -> void:
	var v: Variant = host.get("velocity")
	var ang: float = (v as Vector2).angle() if v is Vector2 else 0.0
	var xf: Transform2D = Transform2D(ang, Vector2.ZERO)
	ink.ink(RisoPrint.PINK, 0.5, [xf * RisoShapes.rrect(-34, -3, 30, 6, 3)])
	ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.sparkle(Vector2.ZERO, 10.0, 1.7)])
	ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.circle(Vector2(2, 0), 4.0, 10)])
