extends Node2D
## Ink art for one spawned prefab. `kind` is set by RisoPrint's dresser from the prefab path.
## Drawn in world pixels (the owner's scale is cancelled); the owner's rotation still applies,
## so wall and ceiling spikes point the right way. Presentation only.

class_name RisoProp
const STATIC_KINDS: Array[StringName] = [&"door", &"ledge", &"thorns", &"cracked", &"gate"]


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
## Plaques and their text (prices, names, shrine pop-ups) are UI: they draw in the UI's canvas
## (RisoPrint.ui_canvas), printed finer than the scene, made the first time a plaque is needed.
var ui_node: Node2D = null
var ui_ink: InkCanvas = null
## Printed text (prices, names), reused frame to frame; see _text().
var labels: Array[Label] = []
## Wisp turning: the wisp turns round in one arc, a half turn that dips under its path (forward,
## down, back under and up onto its path facing the other way), its body following the path's
## heading. Timed by the art's own clock from the moment its facing changes, while its Mover holds
## still for the same time. The body is symmetric about its spine (y = -8.2), so half a turn of the
## old facing is the new facing upright; the eyes slide to their mirrored height on the way so
## they land exactly. WISP_LOOP_H is how deep the arc dips, at most (see _fit_loop).
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
	# First drawn when it first comes into view (see _process), so a level's hundreds of props are
	# not all printed in the frame it loads; still kinds then stop processing.
	set_process(true)


func _process(delta: float) -> void:
	t += delta
	_dt = minf(delta, 0.05)
	# Only animate what the camera can see; off-screen art keeps its last print. The camera's
	# reach is worked out once a frame and shared by every prop (a deep level has hundreds).
	var frame: int = Engine.get_process_frames()
	if frame != _view_frame:
		_view_frame = frame
		var cam: Camera2D = get_viewport().get_camera_2d()
		_view_on = cam != null
		if _view_on:
			_view_reach = Vector2(get_window().content_scale_size) / cam.zoom * 0.6 + Vector2(160, 160)
			_view_center = cam.get_screen_center_position()
	if _view_on and kind != &"laser":
		var d: Vector2 = (host.global_position - _view_center).abs()
		if d.x > _view_reach.x or d.y > _view_reach.y:
			return
	if not _drawn:
		_drawn = true
		_redraw()
		if STATIC_KINDS.has(kind):
			set_process(false)
		return
	if _star_ink != null:
		_mote_pose()
		return
	_redraw()


## Printed at least once (props are first printed as they come into view).
var _drawn: bool = false
static var _view_frame: int = -1
static var _view_on: bool = false
static var _view_reach: Vector2 = Vector2.ZERO
static var _view_center: Vector2 = Vector2.ZERO


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
	if ui_ink != null:
		ui_ink.begin()
		_sync_ui()
	labels_used = 0
	match kind:
		&"mote": _mote()
		&"key": _key()
		&"inkwell": _inkwell()
		&"portal": _portal()
		&"door": _door()
		&"gate": _gate()
		&"switch": _switch()
		&"relic": _relic()
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
		&"hopper": _hopper()
		&"laser": _laser()
		&"shard": _shard()
	for i: int in range(labels_used, labels.size()):
		labels[i].visible = false
	ink.finish()
	if ui_ink != null:
		ui_ink.finish()


## The UI canvas, made on first use and kept on this node.
func _ui() -> InkCanvas:
	if ui_ink == null:
		ui_node = RisoPrint.ui_canvas(self)
		ui_node.z_index = 50
		ui_node.z_as_relative = false
		ui_ink = InkCanvas.new()
		ui_ink.ui = true
		ui_node.add_child(ui_ink)
		ui_ink.begin()
		_sync_ui()
	return ui_ink


func _sync_ui() -> void:
	ui_node.global_transform = global_transform
	ui_node.visible = is_visible_in_tree()


# ------------------------------------------------------------------ pickups

## A star: printed once (a halo, and the star on a canvas of its own), then animated by moving the
## two canvases, bobbing, with the star squashed side to side as it spins. A deep level has
## hundreds, so they never re-lay their ink.
var _star_ink: InkCanvas = null


func _mote() -> void:
	if _star_ink == null:
		ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(Vector2.ZERO, 22.0, 24)])
		_star_ink = InkCanvas.new()
		add_child(_star_ink)
		_star_ink.begin()
		_star_ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.sparkle(Vector2.ZERO, 18.0)])
		_star_ink.finish()
	_mote_pose()


func _mote_pose() -> void:
	var y: float = sin(t * 3.0 + phase) * 4.0
	ink.position = Vector2(0, y)
	_star_ink.position = Vector2(0, y)
	_star_ink.scale = Vector2(maxf(0.25, absf(cos(t * 2.4 + phase))), 1.0)


func _key() -> void:
	var sprite: CanvasItem = host.get_node_or_null("Sprite2D") as CanvasItem
	if sprite != null and not sprite.visible:
		return
	var o: Vector2 = Vector2(0, sin(t * 3.0 + phase) * 4.0)
	var shape: Array[PackedVector2Array] = RisoProp.key_shape(o, 1.0)
	var inks: Array[int] = RisoPrint.key_inks(int(host.get_meta(&"key_color", 0)))
	# A halo in the key's own colour, as the stars have.
	var halo: Array[PackedVector2Array] = [RisoShapes.circle(o + Vector2(-2, 1), 26.0, 24)]
	for plate: int in inks:
		ink.ink(plate, 0.25, halo)
	for plate: int in inks:
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
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.GLOW, RisoPrint.ROBE], eyes)
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
## A secret room's cells (its hidden rock and its false-wall entrance) get none: they are plain
## rock until the room opens.
func _cracked() -> void:
	if host.has_meta(&"secret"):
		return
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
	var m: Vector2 = Vector2(mx, g - 94 + bob * 0.8)
	var full: bool = not bool(host.call("can_mend"))
	if full and bool(host.call("reads_relic")):
		# At full health: a small relic medallion with the move of the relic it can point to.
		var move: StringName = StringName(host.call("relic_move"))
		var disc: PackedVector2Array = RisoShapes.circle(m, 18.0, 24)
		ink.ink(RisoPrint.EYE, 0.25, [RisoShapes.circle(m, 28.0, 28)])
		ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(m, 22.0, 24)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [disc])
		ink.ink(RisoPrint.ACCENT, 0.18, [disc], false)
		var fit: Transform2D = Transform2D(0.0, Vector2(0.55, 0.55), 0.0, m)
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoProp.glyph(move, Vector2.ZERO, t):
			mark.append(fit * poly)
		ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
		var sr: float = _pop(2, Vector2(mx, g - 50))
		if sr > 0.0:
			_plaque("%s relic · where · %d" % [Abilities.NAMES[move], int(host.call("relic_price"))], Vector2(mx, g - POP_Y), 30, RisoPrint.ACCENT, sr)
		return
	# Mending: an ember bead over the bowl, like the HUD's health beads.
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
## Once the shrine is spent, a spell a swap left here floats in its niche instead, its pop-up
## offering to take it back.
func _shrine_niche(cx: float, i: int, g: float, bob: float, used: bool) -> void:
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.arch(cx - 36, g - 122, 72, 100, 12)])
	var niche: PackedVector2Array = RisoShapes.arch(cx - 29, g - 115, 58, 93, 12)
	ink.knock([RisoPrint.BLUE], [niche])
	ink.ink(RisoPrint.NIGHT, 1.0, [niche], false)
	var c: Vector2 = Vector2(cx, g - 84 + bob)
	if used:
		# A spell left here by a swap waits in the niche, to be taken back free.
		var left: Array = host.call("left_spell", i)
		if left.is_empty():
			return
		_niche_mark(left[0], c, i, int(left[1]), cx, g)
		var sl: float = _pop(i, Vector2(cx, g - 50))
		if sl > 0.0:
			_plaque("%s %s · take back" % [Abilities.NAMES[left[0]], Abilities.roman(int(left[1]))], Vector2(cx, g - POP_Y), 30, RisoPrint.ACCENT, sl)
			_plaque("swap", Vector2(cx, g - POP_Y - 40.0 * sl), 22, RisoPrint.PINK, sl)
		return
	var a: StringName = StringName(host.call("offer", i))
	if a == &"":
		return
	var next: int = int(host.call("offer_tier", i))
	_niche_mark(a, c, i, next, cx, g)
	# Name, tier and price pop up over the niche only while the wizard stands at it.
	var s: float = _pop(i, Vector2(cx, g - 50))
	if s <= 0.0:
		return
	_plaque("%s %s · %d" % [Abilities.NAMES[a], Abilities.roman(next), int(host.call("offer_price", i))], Vector2(cx, g - POP_Y), 30, RisoPrint.ACCENT, s)
	if bool(host.call("swap", i)):
		_plaque("swap", Vector2(cx, g - POP_Y - 40.0 * s), 22, RisoPrint.PINK, s)


## An ability's mark floating in a shrine niche at `c`, in a soft halo, over `pips_n` tier pips.
func _niche_mark(a: StringName, c: Vector2, i: int, pips_n: int, cx: float, g: float) -> void:
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
	var pips: Array[PackedVector2Array] = []
	for k: int in range(pips_n):
		pips.append(RisoShapes.circle(Vector2(cx + float(k) * 10.0 - float(pips_n - 1) * 5.0, g - 52.0), 3.2, 10))
	ink.ink(RisoPrint.ACCENT, 1.0, pips)


# ------------------------------------------------------------------ places

## A portal: an upright doorway about the wizard's height, so it reads as a way through, shaped as
## a stadium (half circles top and bottom joined by straight sides). What fills it is the F7
## panel's choice (RisoPrint.portal_style): bands of TV static (the default), or ripples on a pool
## of water. A level's own portals are gates: a solid accent rim on a stone threshold, light
## pooled on the floor, and a sigil on top that its partner shares, so a pair can be told apart.
## The wizard's rifts are torn in the air: a rim of flickering eye-yellow dashes (their own light;
## nothing here is dangerous, so no pink), no threshold, a spark for a sigil; one still waiting
## for its partner is a dim outline with nothing inside. With the wizard right at it (it takes
## standing close), the inside slows as if it waits for them and the rim brightens; the whole
## portal flares when someone comes through (meta "flare_at", see RisoPortalWarp).
const PORTAL_RX: float = 44.0
const PORTAL_RY: float = 72.0
## How far up a gate's oval stands off its threshold.
const PORTAL_LIFT: float = 8.0
var _sigil: int = -1
## The portal's own clock for what fills it: it runs at full speed, and slows to PORTAL_SLOW of it
## while the wizard is right at the portal (as if it waits for them).
var _portal_clock: float = 0.0
const PORTAL_SLOW: float = 0.35


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


## The pair's sigil (0..4): both ends of a pair of gates get the same one, dealt by their cells.
func _pair_sigil() -> int:
	if _sigil >= 0:
		return _sigil
	var info: MapInfo = MapInfo.instance
	if info == null or not host.has_meta(&"cell"):
		return 0
	var a: Vector2i = host.get_meta(&"cell")
	var b: Vector2i = info.cell_at(host.get("go_to_pos"))
	var lo: Vector2i = a if a < b else b
	var hi: Vector2i = b if a < b else a
	_sigil = MapInfo.level_seed(lo.x * 997 + lo.y, hi.x * 991 + hi.y) % 5
	return _sigil


## A sigil, about 2 * `r` across: a ring, a triangle, a square, a diamond or a spark.
static func sigil_shape(kind: int, c: Vector2, r: float) -> PackedVector2Array:
	match kind:
		0:
			return RisoShapes.circle(c, r * 0.8, 14)
		1:
			return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.95, r * 0.75), c + Vector2(-r * 0.95, r * 0.75)])
		2:
			return RisoShapes.rrect(c.x - r * 0.75, c.y - r * 0.75, r * 1.5, r * 1.5, r * 0.2)
		3:
			return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
	return RisoShapes.sparkle(c, r * 1.2)


func _portal() -> void:
	var rift: bool = host.has_meta(&"rift")
	var linked: bool = bool(host.get("linked"))
	var active: bool = linked or not rift
	var center: Vector2 = portal_center()
	var g: float = _ground()
	var ring: int = RisoPrint.EYE if rift else RisoPrint.ACCENT
	# Right at it (it takes standing close), it stirs: the inside slows as if waiting, the rim brightens.
	var player: Node2D = host.get_node_or_null("/root/Main/Player") as Node2D
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
	var mouth: PackedVector2Array = portal_oval(center, 1.0)
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
	ink.ink_graded(ring, portal_ring(center, 0.0, 16.0 * (1.0 + flare)), _halo_fades(48, 0.28 * glow))
	if rift:
		var dashes: Array[PackedVector2Array] = []
		for i: int in range(14):
			var a: float = turn * 0.35 + TAU * float(i) / 14.0
			var thick: float = 3.0 + 1.8 * sin(t * 9.0 + float(i) * 2.3)
			dashes.append_array(portal_ring(center, -thick, thick, 3, a, TAU / 22.0))
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.8, dashes)
		ink.ink(ring, minf(1.0, 0.8 * glow + 0.2), dashes, false)
	else:
		var rim: Array[PackedVector2Array] = portal_ring(center, -1.5, 4.5)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.85, rim)
		ink.ink(ring, minf(1.0, glow), rim, false)
	# The sigil on top: the pair's shape on a gate, the wizard's spark on a rift.
	var top: Vector2 = center + Vector2(0, -PORTAL_RY - 14.0)
	var disc: PackedVector2Array = RisoShapes.circle(top, 10.0, 18)
	ink.ink(ring, 1.0, [RisoShapes.circle(top, 12.0, 20)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [disc])
	ink.ink(RisoPrint.NIGHT, 1.0, [sigil_shape(4 if rift else _pair_sigil(), top, 6.0)], false)


## Inside, bands of TV static: thin rows of snow (flecks of bare paper and night, faintly tinted in
## the rim's ink) that flicker about 18 times a second, grouped in bands of a few rows, each band
## brighter or dimmer than the next, rolling down. Right at it, it slows (see _portal_clock) and snows
## harder; it floods white as someone comes through.
func _portal_static(center: Vector2, near: float, flare: float, ring: int, clock: float) -> void:
	ink.ink(RisoPrint.BLUE, 0.6, [portal_oval(center, 1.0)], false)
	ink.ink(RisoPrint.NIGHT, 0.45, [portal_oval(center, 1.0)], false)
	var tick: float = floorf(clock * 18.0)
	var row: float = 4.0
	var band: float = row * 4.0
	var scroll: float = clock * 12.0 + phase * 40.0
	var rows: int = int(PORTAL_RY * 2.0 / row)
	var snow: Array[PackedVector2Array] = []
	var dark: Array[PackedVector2Array] = []
	for r: int in range(rows):
		var y0: float = -PORTAL_RY + float(r) * row
		var hw: float = portal_half_width(y0 + row * 0.5) - 2.5
		if hw < 3.0:
			continue
		# The band this row is in (bands roll down), and how bright it is.
		var b: float = floorf((y0 - scroll) / band)
		var level: float = RisoShapes.hash1(b * 5.13 + phase * 9.0)
		var odds: float = (0.72 if level > 0.55 else 0.05 + 0.15 * level) + 0.12 * near + 0.6 * flare
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
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.95, snow)
	ink.ink(ring, 0.15 + 0.2 * near, snow, false)
	ink.ink(RisoPrint.NIGHT, 0.9, dark, false)


## Inside, a pool of water: deep blue, darker below, with rings spreading out from a drip in the
## middle and fading as they reach the rim, and a sheen of light across the top of the surface.
## The drips come slower right at it (see _portal_clock), and a big ring spreads as someone comes
## through.
func _portal_ripples(center: Vector2, near: float, flare: float, ring: int, clock: float) -> void:
	ink.ink(RisoPrint.BLUE, 0.75, [portal_oval(center, 1.0)], false)
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


## A switch gate: a portcullis like a door's, its lock plate showing the switch emblem.
func _gate() -> void:
	RisoProp.portcullis(ink, _ground(), half, -1, 0.0, 1.0)


## The switch emblem (also on its gate): a lever leaning out of a round base, about 20 * `s` wide.
static func switch_emblem(c: Vector2, s: float) -> Array[PackedVector2Array]:
	return [RisoShapes.rrect(c.x - 9.0 * s, c.y + 2.0 * s, 18.0 * s, 6.0 * s, 3.0 * s), Transform2D(0.55, c + Vector2(0, 3.0) * s) * RisoShapes.rrect(-1.8 * s, -12.0 * s, 3.6 * s, 13.0 * s, 1.8 * s),
		RisoShapes.circle(c + Vector2(6.6, -7.0) * s, 3.4 * s, 12)]


## A relic: a medallion (an accent ring round a disc of bare paper with the move's mark on it)
## floating over a small plinth in a ring of light, with three motes
## circling it; its name and tier pop up as the wizard steps up to it ("swap" too, when taking it
## would replace the spell in the slot).
func _relic() -> void:
	var g: float = _ground()
	var held: Array = host.call("holds")
	var a: StringName = held[0]
	var bob: float = sin(t * 2.0 + phase) * 4.0
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-30, g - 20, 60, 20, 6)])
	ink.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.rrect(-20, g - 28, 40, 10, 4)])
	var c: Vector2 = Vector2(0, g - 86 + bob)
	var breathe: float = 1.0 + 0.06 * sin(t * 3.0 + phase)
	ink.ink(RisoPrint.EYE, 0.25, [RisoShapes.circle(c, 54.0 * breathe, 32)], false)
	# A medallion: a solid accent ring round a disc of bare paper, the move's mark on it.
	var disc: PackedVector2Array = RisoShapes.circle(c, 33.0, 32)
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(c, 39.0, 32)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], [disc])
	ink.ink(RisoPrint.ACCENT, 0.18, [disc], false)
	var fit: Transform2D = Transform2D(0.0, Vector2(1.05, 1.05), 0.0, c)
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoProp.glyph(a, Vector2.ZERO, t):
		mark.append(fit * poly)
	ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
	var motes: Array[PackedVector2Array] = []
	for k: int in range(3):
		var ang: float = t * 1.4 + TAU * float(k) / 3.0
		motes.append(RisoShapes.sparkle(c + Vector2(cos(ang) * 52.0, sin(ang) * 18.0), 8.0))
	ink.ink(RisoPrint.ACCENT, 1.0, motes, false)
	var sl: float = _pop(0, Vector2(0, g - 50))
	if sl > 0.0:
		var owed: int = int(host.call("price"))
		var label: String = "%s %s" % [Abilities.NAMES[a], Abilities.roman(int(held[1]))]
		_plaque(label + (" · %d" % owed if owed > 0 else " · take back"), Vector2(0, g - POP_Y), 30, RisoPrint.ACCENT, sl)
		if bool(host.call("swap")):
			_plaque("swap", Vector2(0, g - POP_Y - 40.0 * sl), 22, RisoPrint.PINK, sl)


## A switch: a stone base on the floor with a lever in it. Before it is thrown the lever leans left
## with a pink knob, swaying a little; thrown, it leans right, its knob and a halo in accent ink.
func _switch() -> void:
	var g: float = _ground()
	var thrown: bool = bool(host.call("thrown")) if host.has_method("thrown") else false
	var base: PackedVector2Array = RisoShapes.rrect(-34, g - 30, 68, 30, 9)
	var slot: PackedVector2Array = RisoShapes.rrect(-20, g - 30, 40, 7, 3.5)
	var tilt: float = (0.6 if thrown else -0.6) + (0.0 if thrown else sin(t * 2.0 + phase) * 0.06)
	var pivot: Vector2 = Vector2(0, g - 27)
	var arm: Transform2D = Transform2D(tilt, pivot)
	var knob: Vector2 = arm * Vector2(0, -70)
	if thrown:
		ink.ink(RisoPrint.ACCENT, 0.3, [RisoShapes.circle(knob, 26.0, 22)])
	# The lever in blue, behind the base, so it reads against the night.
	ink.ink(RisoPrint.BLUE, 1.0, [arm * RisoShapes.rrect(-4.5, -68.0, 9.0, 68.0, 4.5)])
	ink.ink(RisoPrint.BLUE, 1.0, [base])
	ink.ink(RisoPrint.NIGHT, 0.35, [RisoShapes.rrect(-34, g - 10, 68, 10, 5)], false)
	ink.ink(RisoPrint.NIGHT, 0.6, [slot], false)
	var ball: PackedVector2Array = RisoShapes.circle(knob, 13.0, 20)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [ball])
	ink.ink(RisoPrint.ACCENT if thrown else RisoPrint.PINK, 1.0, [ball], false)
	ink.knock([RisoPrint.ACCENT, RisoPrint.PINK], [RisoShapes.circle(knob + Vector2(-2.5, -2.5), 2.6, 8)])


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
			if key_color < 0:
				# A switch gate: the switch's emblem (a lever in a ring) instead of a lock.
				ink.ink(RisoPrint.NIGHT, fade, RisoProp.switch_emblem(Vector2(0, ly), 0.9), false)
			else:
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
	# Where it leads and how grand it is are up to the place (a side world's door, or its way on).
	var place: NextWorldDef = MapInfo.instance.here if MapInfo.instance != null else null
	var grand: bool = place != null and place.exit_grand(which)
	var frame: int = RisoPrint.PINK if which == MapInfo.Exit.DEEPER or grand else RisoPrint.BLUE
	if grand:
		# A grand door: a second, wider frame of accent round the pink one, and a falling cascade
		# of chevrons over it (below).
		ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.arch(-64, g - 132, 128, 132, 16)])
		ink.ink(RisoPrint.NIGHT, 0.5, [RisoShapes.arch(-58, g - 125, 116, 125, 15)], false)
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
	var dir: Vector2 = place.exit_dir(which) if place != null else Vector2.DOWN
	var bob: float = sin(t * 3.0 + phase) * 3.0
	var at: Vector2 = Vector2(0, g - 140) + dir * bob
	var side: Vector2 = Vector2(-dir.y, dir.x)
	if grand:
		# Three chevrons falling one after another, fading as they drop: a long way down.
		for k: int in range(3):
			var u: float = fmod(t * 0.9 + float(k) / 3.0, 1.0)
			var c: Vector2 = Vector2(0, g - 196) + dir * (u * 60.0)
			ink.ink(RisoPrint.PINK, 1.0 - u * 0.8, [RisoProp.chevron(c, dir, 1.0)])
	else:
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
		_ui()
		ui_node.add_child(label)
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
	var u: InkCanvas = _ui()
	u.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [plate])
	u.ink(tint, 0.2, [plate], false)
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
		&"speed":
			# Three staggered speed lines streaming back from a running bead.
			return [RisoShapes.circle(c + Vector2(14, 0), 7.0, 14), RisoShapes.rrect(c.x - 20, c.y - 12, 26, 5, 2.5),
				RisoShapes.rrect(c.x - 26, c.y - 2.5, 32, 5, 2.5), RisoShapes.rrect(c.x - 16, c.y + 7, 22, 5, 2.5)]
		&"warp":
			# A ring it leaves by, a dotted way across, and the ring it comes out of.
			return [RisoShapes.circle(c + Vector2(-17, 8), 8.0, 16), RisoShapes.circle(c + Vector2(-5, -1), 2.6, 8), RisoShapes.circle(c + Vector2(4, -6), 2.6, 8),
				RisoShapes.circle(c + Vector2(16, -6), 11.0, 20)]
		&"hex":
			# A comet: a bold spark with a tapering tail behind it.
			return [RisoShapes.sparkle(c + Vector2(7, -5), 17.0), PackedVector2Array([c + Vector2(4, -12), c + Vector2(-22, 14), c + Vector2(-2, 0)])]
	return [RisoShapes.sparkle(c, 18.0)]


## A moon: a crescent in accent ink inside a soft halo, rocking as it floats. The moment the
## wizard touches it, it drops to a faint sliver (spent) until they leave, then grows back as it
## waxes.
func _moon() -> void:
	var full: float = 0.0 if bool(host.get("in_use")) else 1.0 - clampf(float(host.get("waning")) / 2.5, 0.0, 1.0)
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
		# The loop is drawn upside down: the wisp dips under its path rather than rising over it.
		loop_at = Vector2(side * (sample[0] as Vector2).x * wisp_loop_w, -(sample[0] as Vector2).y * wisp_loop_h)
		spin = -float(sample[1])
	var e_eyes: float = clampf(-spin / PI, 0.0, 1.0)
	var width: float = 1.0
	# Its shadow on the floor, shrinking as it bobs up: it belongs to the ground it haunts.
	var g: float = _ground()
	var lift: float = clampf(-loop_at.y / WISP_LOOP_H, 0.0, 1.0)
	# And darkening as it swoops down toward it on a turn.
	var dip: float = clampf(loop_at.y / WISP_LOOP_H, 0.0, 1.0)
	ink.ink(RisoPrint.NIGHT, 0.35 * (1.0 - lift * 0.6 + dip * 0.5), [RisoShapes.ellipse(Vector2(loop_at.x, g - 3.0), (26.0 + bob * 1.2) * (1.0 - lift * 0.4), 5.0, 16)], false)
	# The body follows the path its head has travelled (see _wisp_place): the head is placed on
	# its loop, and everything behind it lies along the recorded trail, so mid-turn the tail traces
	# the head's arc and after the turn it straightens out as the wisp moves off.
	_wp_k = k
	_wp_side = side
	_wp_bob = Vector2(0, bob * k * 0.7)
	var head: Vector2 = Vector2(0, 14.0 - 3.3 * k - 8.2 * k * 0.6) + loop_at
	_wp_head_dir = Vector2(side * cos(spin), -sin(spin)) if spinning else Vector2(side, 0)
	_wisp_trail_add(to_global(head))
	# Body, veils and glow reach about 22 art units back, scaled 1.1 k; plus the bend lookahead.
	_wisp_sample(22.0 * k * 1.1 + 8.0)
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
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], eyes)
	if stunned:
		_stun_mark(head + _wp_bob + Vector2(0, -52))


## Size the turning arc to the room: shallower over a near floor, tighter against a wall. The head
## floats about WISP_HEAD_Y over the wisp's origin, and dips to WISP_FLOOR_GAP over the floor.
const WISP_HEAD_Y: float = -23.0
const WISP_FLOOR_GAP: float = 29.0

func _fit_loop(forward: float) -> void:
	wisp_loop_w = WISP_LOOP_W
	wisp_loop_h = clampf(_ground() - WISP_HEAD_Y - WISP_FLOOR_GAP, 8.0, WISP_LOOP_H)
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return
	var c: Vector2i = info.cell_at(host.global_position)
	var f: Vector2i = Vector2i(int(signf(forward)), 0)
	if _wisp_blocked(info, c + f):
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
		_trail_measure()
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
	_trail_measure()


## The distance along the trail from the head to each of its points (for _trail_at).
var _trail_cum: PackedFloat32Array = PackedFloat32Array()


func _trail_measure() -> void:
	_trail_cum.resize(_trail.size())
	var total: float = 0.0
	for n: int in range(_trail.size()):
		if n > 0:
			total += _trail[n].distance_to(_trail[n - 1])
		_trail_cum[n] = total


## Where the trail was `d` px behind the head: [position (world), direction of travel there].
## A binary search over the measured trail (each wisp asks this hundreds of times a frame).
func _trail_at(d: float) -> Array:
	if d <= 0.0 or _trail.size() < 2:
		return [_trail[0] - _wp_head_dir * d if not _trail.is_empty() else Vector2.ZERO, _wp_head_dir]
	if _trail_cum.size() != _trail.size():
		_trail_measure()
	var n: int = _trail_cum.bsearch(d)
	while n < _trail.size() and n > 0 and _trail_cum[n] - _trail_cum[n - 1] <= 0.0001:
		n += 1
	if n >= 1 and n < _trail.size():
		var a: Vector2 = _trail[n - 1]
		var b: Vector2 = _trail[n]
		var f: float = (d - _trail_cum[n - 1]) / (_trail_cum[n] - _trail_cum[n - 1])
		return [a.lerp(b, f), (a - b).normalized()]
	var last: Vector2 = _trail[_trail.size() - 1]
	var tail_dir: Vector2 = (_trail[_trail.size() - 2] - last).normalized()
	return [last - tail_dir * (d - _trail_cum[_trail.size() - 1]), tail_dir]


## The trail sampled every WISP_STEP px from the head, once a frame (_wisp_sample): positions in
## this prop's space and directions of travel. Placing a wisp's hundreds of vertices reads this
## table instead of walking the trail for each.
const WISP_STEP: float = 2.0
var _ts_pos: PackedVector2Array = PackedVector2Array()
var _ts_dir: PackedVector2Array = PackedVector2Array()
## How sharply the trail bends at each sample: the turn from 6 px older to 6 px newer.
var _ts_turn: PackedFloat32Array = PackedFloat32Array()
var _lk_turn: float = 0.0
## The last lookup (_wisp_lookup), kept in fields so lookups allocate nothing.
var _lk_pos: Vector2 = Vector2.ZERO
var _lk_dir: Vector2 = Vector2.RIGHT


func _wisp_sample(max_d: float) -> void:
	var n: int = ceili(max_d / WISP_STEP) + 2
	_ts_pos.resize(n)
	_ts_dir.resize(n)
	for i: int in range(n):
		var at: Array = _trail_at(float(i) * WISP_STEP)
		_ts_pos[i] = to_local(at[0] as Vector2)
		_ts_dir[i] = at[1]
	_ts_turn.resize(n)
	var reach: int = ceili(6.0 / WISP_STEP)
	for i: int in range(n):
		var older: Vector2 = _ts_dir[mini(i + reach, n - 1)]
		var newer: Vector2 = _ts_dir[maxi(i - reach, 0)]
		_ts_turn[i] = older.angle_to(newer) if i > 0 else 0.0


## Where the trail was `d` px behind the head (in this prop's space), and its direction there,
## into _lk_pos and _lk_dir.
func _wisp_lookup(d: float) -> void:
	if d <= 0.0:
		_lk_dir = _wp_head_dir
		_lk_pos = _ts_pos[0] - _wp_head_dir * d
		_lk_turn = 0.0
		return
	var f: float = d / WISP_STEP
	var i: int = mini(int(f), _ts_pos.size() - 2)
	var u: float = f - float(i)
	_lk_pos = _ts_pos[i].lerp(_ts_pos[i + 1], u)
	_lk_dir = _ts_dir[i].lerp(_ts_dir[i + 1], u).normalized()
	_lk_turn = lerpf(_ts_turn[i], _ts_turn[i + 1], u)


func _wisp_place(poly: PackedVector2Array, _curl: bool) -> PackedVector2Array:
	var sx: float = _wp_k * 1.1
	var sy: float = _wp_k * 0.6
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(poly.size())
	var across_turn: float = _wp_side * PI * 0.5
	for n: int in range(poly.size()):
		var d: float = -poly[n].x * sx
		# On a tight bend, keep the inside edge within the bend's radius so the body bunches
		# instead of folding over itself (a folded outline can't be printed).
		_wisp_lookup(d)
		var turn: float = _lk_turn
		var dir: Vector2 = _lk_dir
		# Within the first stretch behind the head, ease from the head's heading to the trail's.
		if d < 14.0:
			dir = _wp_head_dir.lerp(dir, clampf(d / 14.0, 0.0, 1.0)).normalized()
		var off: Vector2 = dir.rotated(across_turn) * ((poly[n].y + 8.2) * sy)
		if absf(turn) > 0.02:
			var centre: Vector2 = dir.rotated(signf(turn) * PI * 0.5)
			if off.dot(centre) > 0.0:
				off = off.limit_length(0.8 * 12.0 / absf(turn))
		out[n] = _lk_pos + off + _wp_bob
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


## Stunned: three small stars of accent ink circle over the head at `c`, the ones passing behind
## smaller and fainter, circling slowly; they shrink as the stun runs out, and turn pink and blink
## in its last STUN_WARN seconds, when the enemy is about to wake.
const STUN_WARN: float = 1.0
func _stun_mark(c: Vector2) -> void:
	var stunner: Node = host.get_node_or_null("Stunner")
	var frac: float = float(stunner.call("fraction")) if stunner != null and stunner.has_method("fraction") else 1.0
	if frac <= 0.0:
		return
	# About to wake: the last STUN_WARN seconds the stars turn pink (danger) and blink, faster and
	# faster toward the end.
	var left: float = float(stunner.get("left")) if stunner != null else 99.0
	var plate: int = RisoPrint.ACCENT
	if left < STUN_WARN:
		plate = RisoPrint.PINK
		var rate: float = lerpf(9.0, 3.0, left / STUN_WARN)
		if fmod(t * rate, 1.0) > 0.6:
			return
	var front: Array[PackedVector2Array] = []
	var back: Array[PackedVector2Array] = []
	for i: int in range(3):
		var a: float = t * 1.3 + TAU * float(i) / 3.0
		var depth: float = sin(a)
		var p: Vector2 = c + Vector2(cos(a) * 34.0, depth * 10.0)
		var star: PackedVector2Array = Transform2D(t * 0.9 + float(i), p) * RisoShapes.sparkle(Vector2.ZERO, (9.0 + 6.0 * frac) * (0.75 + 0.25 * depth))
		(front if depth >= 0.0 else back).append(star)
	ink.ink(plate, 0.5, back)
	ink.ink(plate, 1.0, front)


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
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [xf * RisoShapes.almond(Vector2(0, yo), 8.2, maxf(0.3, 4.4 * open), 12)])
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
	if stunned:
		_stun_mark(xf * Vector2(0, -16))


## The hopper: a squat pink toad of a nightmare with a ridge of thorns down its back and two
## paper eye slits. It squashes as it crouches to leap (the slits narrow), stretches in the air
## over its shadow, and slumps as it lands.
func _hopper() -> void:
	var hop: Node = host.get_node_or_null("Hopper")
	var facing: float = 1.0
	var crouch: float = -1.0
	var vel: Vector2 = Vector2.ZERO
	var grounded: bool = true
	var landed: float = 10.0
	var stunned: bool = false
	if hop != null:
		facing = float(hop.get("facing"))
		crouch = float(hop.get("crouch"))
		vel = hop.get("velocity")
		grounded = bool(hop.get("grounded"))
		landed = float(hop.get("since_landing"))
		stunned = bool(hop.get("stunned"))
	var sx: float = 1.0
	var sy: float = 1.0 + 0.03 * sin(t * 3.0 + phase)
	if stunned:
		pass
	elif crouch >= 0.0:
		var c: float = crouch * crouch * (3.0 - 2.0 * crouch)
		sx = 1.0 + 0.3 * c
		sy = 1.0 - 0.3 * c
	elif not grounded:
		sy = 1.0 + 0.22 * clampf(absf(vel.y) / 700.0, 0.0, 1.0)
		sx = 1.0 / sy
	elif landed < 0.25:
		var l: float = 1.0 - landed / 0.25
		sx = 1.0 + 0.25 * l
		sy = 1.0 - 0.25 * l
	var k: float = 1.7
	var feet: Vector2 = Vector2(0, 16)
	var xf: Transform2D = Transform2D(0.0, Vector2(sx * facing * k, sy * k), 0.0, feet)
	if not grounded:
		var g: float = _ground()
		var high: float = clampf((g - feet.y) / 300.0, 0.0, 1.0)
		ink.ink(RisoPrint.NIGHT, 0.35 * (1.0 - high * 0.6), [RisoShapes.ellipse(Vector2(0, g - 3.0), 26.0 * (1.0 - high * 0.4), 5.0, 16)], false)
	var body: PackedVector2Array = xf * RisoShapes.smooth(PackedVector2Array([Vector2(-15, 0), Vector2(-16, -7), Vector2(-11, -15),
		Vector2(-2, -19), Vector2(8, -18), Vector2(15, -11), Vector2(17, -4), Vector2(15, 0)]))
	var thorns: Array[PackedVector2Array] = []
	for spike: Array in [[Vector2(-13, -12), Vector2(-7, -17), Vector2(-13, -23)], [Vector2(-5, -18), Vector2(2, -19), Vector2(-3, -27)], [Vector2(3, -19), Vector2(9, -17), Vector2(6, -25)]]:
		thorns.append(xf * RisoShapes.tri(spike[0], spike[1], spike[2]))
	var feet_nubs: Array[PackedVector2Array] = [xf * RisoShapes.ellipse(Vector2(-9, 0), 4.0, 2.0, 10), xf * RisoShapes.ellipse(Vector2(9, 0), 4.0, 2.0, 10)]
	ink.ink(RisoPrint.NIGHT, 0.8, feet_nubs, false)
	ink.ink(RisoPrint.PINK, 1.0, thorns)
	ink.ink(RisoPrint.NIGHT, 0.45, thorns, false)
	ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [body])
	ink.ink(RisoPrint.PINK, 1.0, [body])
	ink.ink(RisoPrint.BLUE, 0.35, [body], false)
	var eyes: Array[PackedVector2Array] = []
	for e: Vector2 in [Vector2(8.5, -11.5), Vector2(13.0, -10.5)]:
		if stunned:
			eyes.append(xf * RisoShapes.rrect(e.x - 1.6, e.y - 0.3, 3.2, 0.6, 0.3, 2))
		elif crouch >= 0.0:
			eyes.append(xf * PackedVector2Array([e + Vector2(-1.8, -1.2), e + Vector2(1.8, 0.2), e + Vector2(1.6, 1.0), e + Vector2(-1.8, 0.2)]))
		else:
			eyes.append(xf * RisoShapes.ellipse(e, 1.4, 2.2, 12))
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], eyes)
	if stunned:
		_stun_mark(xf * Vector2(0, -30))


## A laser set in the rock: a dark housing with a lens. Warming up, a thin flickering sight line
## runs out to the wall and the lens glows; firing, a broad pink beam with a bare-paper core, a
## flare at the lens and a splash where it strikes; resting, the lens goes dark.
func _laser() -> void:
	var dir: Vector2 = host.get("dir")
	var reach: float = float(host.get("reach"))
	var state: Array = host.call("phase")
	var u: float = float(state[1])
	var xf: Transform2D = Transform2D(dir.angle(), -dir * half)
	var muzzle: float = 30.0
	var housing: PackedVector2Array = xf * RisoShapes.rrect(-6.0, -20.0, 30.0, 40.0, 7.0)
	ink.ink(RisoPrint.BLUE, 1.0, [housing])
	ink.ink(RisoPrint.NIGHT, 0.45, [housing], false)
	ink.ink(RisoPrint.NIGHT, 0.8, [xf * RisoShapes.rrect(18.0, -13.0, 8.0, 26.0, 3.0)], false)
	var lens: PackedVector2Array = xf * RisoShapes.circle(Vector2(muzzle - 4.0, 0.0), 7.0, 16)
	var far: float = muzzle + reach
	match state[0]:
		&"warm":
			ink.ink(RisoPrint.PINK, 0.15 + 0.3 * u, [xf * RisoShapes.circle(Vector2(muzzle - 4.0, 0.0), 9.0 + 7.0 * u, 20)])
			ink.ink(RisoPrint.PINK, 1.0, [lens])
			if fmod(t * 18.0, 1.0) < 0.45 + 0.55 * u:
				ink.ink(RisoPrint.PINK, 0.3 + 0.4 * u, [xf * RisoShapes.rrect(muzzle, -1.2, reach, 2.4, 1.2)])
		&"fire":
			var s: float = clampf(minf(u, 1.0 - u) * 8.0, 0.0, 1.0)
			var w: float = 26.0 * (0.6 + 0.4 * s) * (1.0 + 0.06 * sin(t * 40.0))
			ink.ink(RisoPrint.PINK, 0.45 * s, [xf * RisoShapes.rrect(muzzle, -w * 0.85, reach, w * 1.7, w * 0.85)])
			ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.rrect(muzzle, -w * 0.5, reach, w, w * 0.5)])
			ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 0.9 * s, [xf * RisoShapes.rrect(muzzle, -w * 0.17, reach, w * 0.34, w * 0.17)])
			ink.ink(RisoPrint.PINK, 0.5 * s, [xf * RisoShapes.circle(Vector2(muzzle, 0.0), w * 1.3, 24), xf * RisoShapes.circle(Vector2(far, 0.0), w * 1.1, 24)])
			var splash: PackedVector2Array = xf * (Transform2D(t * 6.0, Vector2(far, 0.0)) * RisoShapes.sparkle(Vector2.ZERO, w * 0.9))
			ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 0.8 * s, [splash])
		_:
			ink.ink(RisoPrint.NIGHT, 0.6, [lens], false)


func _shard() -> void:
	var v: Variant = host.get("velocity")
	var ang: float = (v as Vector2).angle() if v is Vector2 else 0.0
	var xf: Transform2D = Transform2D(ang, Vector2.ZERO)
	ink.ink(RisoPrint.PINK, 0.5, [xf * RisoShapes.rrect(-34, -3, 30, 6, 3)])
	ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.sparkle(Vector2.ZERO, 10.0, 1.7)])
	ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.circle(Vector2(2, 0), 4.0, 10)])
