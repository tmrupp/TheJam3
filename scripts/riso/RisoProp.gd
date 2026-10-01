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
var labels_used: int = 0


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
		&"orb": _orb()
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


## An ink well (it inks the map): a squat pot with a gold rim and a paper label, and a drop
## of ink rising out of it and falling back.
func _inkwell() -> void:
	var o: Vector2 = Vector2(0, sin(t * 2.2 + phase) * 5.0)
	var tilt: Transform2D = Transform2D(sin(t * 1.3 + phase) * 0.08, Vector2(1.25, 1.25), 0.0, o)
	ink.ink(RisoPrint.ACCENT, 0.22, [RisoShapes.ellipse(o + Vector2(0, -18), 40.0, 52.0, 28)])
	var pot: PackedVector2Array = tilt * RisoShapes.rrect(-17, -6, 34, 24, 10)
	var neck: PackedVector2Array = tilt * RisoShapes.rrect(-8, -14, 16, 10, 3)
	ink.ink(RisoPrint.BLUE, 1.0, [pot, neck])
	ink.ink(RisoPrint.NIGHT, 0.35, [tilt * RisoShapes.rrect(3, -4, 12, 20, 6)], false)
	ink.ink(RisoPrint.ACCENT, 1.0, [tilt * RisoShapes.rrect(-10, -17, 20, 5, 2.5)])
	ink.ink(RisoPrint.NIGHT, 1.0, [tilt * RisoShapes.ellipse(Vector2(0, -16), 6.0, 1.6, 12)])
	var label: PackedVector2Array = tilt * RisoShapes.rrect(-11, 1, 18, 10, 3)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [label])
	ink.ink(RisoPrint.NIGHT, 1.0, [tilt * RisoShapes.circle(Vector2(-2, 6), 2.4, 10)], false)
	# The drop: rises from the mouth, hangs, falls back in.
	var u: float = fmod(t * 0.7 + phase, 1.0)
	var lift: float = sin(u * PI) * 16.0
	var d: Vector2 = tilt * Vector2(0, -22.0 - lift)
	var drop: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([d + Vector2(0, -7), d + Vector2(4.5, 1), d + Vector2(0, 5), d + Vector2(-4.5, 1)]))
	ink.ink(RisoPrint.BLUE, 1.0, [drop])
	ink.knock([RisoPrint.BLUE, RisoPrint.ACCENT], [RisoShapes.circle(d + Vector2(-1.5, 0), 1.6, 8)])


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


## The shrine: a plinth across two cells. Left, a niche where the offered ability's mark floats
## over its tier pips; right, a bowl with an ember bead (mending). The plaques carved into the
## plinth name each and its price. Once used, the marks are gone and the trim dims.
func _shrine() -> void:
	var g: float = _ground()
	var used: bool = bool(host.call("used"))
	var bob: float = sin(t * 2.0 + phase) * 4.0
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.arch(-46, g - 142, 92, 120, 14)])
	var niche: PackedVector2Array = RisoShapes.arch(-38, g - 134, 76, 112, 14)
	ink.knock([RisoPrint.BLUE], [niche])
	ink.ink(RisoPrint.NIGHT, 1.0, [niche], false)
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(118, g - 70, 20, 50, 6), RisoShapes.ellipse(Vector2(128, g - 72), 28.0, 8.0, 22)])
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-56, g - 24, 240, 24, 8)])
	ink.ink(RisoPrint.ACCENT, 0.35 if used else 1.0, [RisoShapes.rrect(-50, g - 29, 228, 8, 4)])
	if used:
		return
	var a: StringName = StringName(host.call("offer"))
	if a != &"":
		var c: Vector2 = Vector2(0, g - 98 + bob)
		ink.ink(RisoPrint.ACCENT, 0.18, [RisoShapes.circle(c, 34.0 * (1.0 + 0.05 * sin(t * 3.0)), 28)])
		var mark: Array[PackedVector2Array] = RisoProp.glyph(a, c, t)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], mark)
		ink.ink(RisoPrint.ACCENT, 1.0, mark, false)
		if a == &"vigor":
			ink.ink(RisoPrint.PINK, 0.4, mark, false)
		var next: int = int(host.call("offer_tier"))
		var pips: Array[PackedVector2Array] = []
		for i: int in range(next):
			pips.append(RisoShapes.circle(Vector2(float(i) * 12.0 - float(next - 1) * 6.0, g - 60.0), 3.6, 10))
		ink.ink(RisoPrint.ACCENT, 1.0, pips)
		# The price on a paper tag at the foot of the niche; the name on the plinth, sliding left
		# when long so it never meets the mending plaque.
		_plaque(str(int(host.call("offer_price"))), Vector2(0, g - 38), 26, RisoPrint.ACCENT)
		var text: String = "%s %s" % [Abilities.NAMES[a], Abilities.roman(next)]
		_plaque(text, Vector2(minf(0.0, 60.0 - _plaque_width(text, 28) * 0.5), g - 12), 28, RisoPrint.ACCENT)
	# Mending: an ember bead over the bowl, like the HUD's health beads.
	var m: Vector2 = Vector2(128, g - 106 + bob * 0.8)
	var full: bool = not bool(host.call("can_mend"))
	ink.ink(RisoPrint.EYE, 0.12 if full else 0.25, [RisoShapes.circle(m, 30.0, 28)])
	var bead: PackedVector2Array = RisoShapes.circle(m, 14.0, 22)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [bead])
	ink.ink(RisoPrint.EYE, 0.5 if full else 1.0, [bead], false)
	ink.ink(RisoPrint.PINK, 0.35, [bead], false)
	ink.knock([RisoPrint.EYE, RisoPrint.PINK], [RisoShapes.circle(m + Vector2(-4, -4), 4.5, 12)])
	var mend: String = "mend · %d" % int(host.call("heal_price"))
	_plaque(mend, Vector2(maxf(128.0, 72.0 + _plaque_width(mend, 28) * 0.5), g - 12), 28, RisoPrint.PINK)


# ------------------------------------------------------------------ places

func _portal() -> void:
	var r: float = 46.0 * (1.0 + 0.04 * sin(t * 2.0 + phase))
	var a: float = t * 2.0 * (1.0 if int(phase * 10.0) % 2 == 0 else -1.0)
	var outer: int = RisoPrint.ACCENT if int(phase * 10.0) % 2 == 0 else RisoPrint.PINK
	var inner: int = RisoPrint.PINK if outer == RisoPrint.ACCENT else RisoPrint.ACCENT
	ink.ink(outer, 1.0, [RisoShapes.circle(Vector2.ZERO, r, 40)])
	ink.ink(inner, 1.0, [RisoShapes.circle(Vector2(cos(a), sin(a)) * 7.0, r * 0.7, 36)])
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.circle(Vector2(cos(a + 2.0), sin(a + 2.0)) * 5.0, r * 0.4, 28)])


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


func _lantern() -> void:
	var lit: bool = MapInfo.instance != null and MapInfo.instance.is_respawn_lantern(host)
	var sw: float = sin(t * 2.2 + phase) * 0.12
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
func _text(text: String, at: Vector2, px: int) -> float:
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
	label.position = at - label.size * 0.5
	label.visible = true
	return w


func _plaque_width(text: String, px: int) -> float:
	return RisoTheme.serif().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 22.0


## A bare-paper plaque with `text` on it, centred on `at`.
func _plaque(text: String, at: Vector2, px: int, tint: int) -> void:
	var w: float = _plaque_width(text, px)
	var h: float = float(px) * 1.25
	var plate: PackedVector2Array = RisoShapes.rrect(at.x - w * 0.5, at.y - h * 0.5, w, h, h * 0.35)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [plate])
	ink.ink(tint, 0.2, [plate], false)
	_text(text, at, px)


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
		&"hex":
			# A comet: a bold spark with a tapering tail behind it.
			return [RisoShapes.sparkle(c + Vector2(7, -5), 17.0), PackedVector2Array([c + Vector2(4, -12), c + Vector2(-22, 14), c + Vector2(-2, 0)])]
	return [RisoShapes.sparkle(c, 18.0)]


func _orb() -> void:
	# Dormant (astral not learned): printed dim, as if spent.
	var active: bool = bool(host.get("active")) or (host.has_method("usable") and not bool(host.call("usable")))
	var pulse: float = 1.0 + 0.1 * sin(t * 3.0 + phase)
	var g: float = _ground()
	var o: Vector2 = Vector2(0, g - 66 + sin(t * 1.6 + phase) * 4.0)
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-20, g - 20, 40, 20, 8)])
	ink.ink(RisoPrint.ACCENT, 0.15 if active else 0.3, [RisoShapes.circle(o, 34.0 * pulse, 28)])
	ink.ink(RisoPrint.ACCENT, 0.5 if active else 1.0, [RisoShapes.circle(o, 16.0, 24)])
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.crescent(o, 16.0, Vector2(7, -4))])


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
	var k: float = 3.6
	var bob: float = -3.0 - sin(t * 3.0 + phase) * 1.6
	# Its shadow on the floor, shrinking as it bobs up: it belongs to the ground it haunts.
	var g: float = _ground()
	ink.ink(RisoPrint.NIGHT, 0.35, [RisoShapes.ellipse(Vector2(0, g - 3.0), 26.0 + bob * 1.2, 5.0, 16)], false)
	# Flattened to 60% height, centred where the taller wisp used to float.
	var xf: Transform2D = Transform2D(0.0, Vector2(dir * k * 1.1, k * 0.6), 0.0, Vector2(0, 14.0 - 3.3 * k + bob * k * 0.7))
	var speed: float = 0.3 if stunned else 0.7
	var flicker: float = 0.85 + 0.15 * sin(t * 5.3 + phase) * sin(t * 2.1 + phase * 1.7)
	# The glow trails the wisp: strongest behind the head, thinning out past the tail.
	ink.ink(RisoPrint.PINK, 0.06 * flicker, [xf * RisoShapes.ellipse(Vector2(-10.5, -8.4), 11.0, 7.5, 28)])
	ink.ink(RisoPrint.PINK, 0.1 * flicker, [xf * RisoShapes.ellipse(Vector2(-6.0, -8.2), 9.5, 8.0, 28)])
	# Two lagging after-veils behind the body, then the body; each fades toward its tail.
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
		var top: float = (0.8 if layer == 0 else 0.3 / float(layer)) * flicker
		for p: Vector2 in pts:
			fade.append(top * lerpf(0.15, 1.0, clampf((p.x + 12.4) / 13.0, 0.0, 1.0)))
		var poly: PackedVector2Array = xf * (Transform2D(0.0, back) * pts)
		ink.ink_graded(RisoPrint.PINK, [poly], [fade])
		if layer == 0:
			var cool: PackedFloat32Array = PackedFloat32Array()
			for a: float in fade:
				cool.append(a * 0.4)
			ink.ink_graded(RisoPrint.BLUE, [poly], [cool])
	var eyes: Array[PackedVector2Array] = []
	for e: Vector2 in [Vector2(3.4, -9.2), Vector2(0.7, -9.4)]:
		eyes.append(xf * (RisoShapes.rrect(e.x - 1.0, e.y - 0.4, 2.0, 0.8, 0.4, 2) if stunned else RisoShapes.ellipse(e, 0.9, 1.9, 14)))
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], eyes)


var _last_shot: float = -10.0
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
		# As in the prototype: while the player is in range the eye charges toward its next shot,
		# widening and growing a ball of ink at the muzzle, then squints on the recoil.
		var cooldown: float = maxf(0.1, float(shooter.get("cooldown")))
		var since: float = t - _last_shot
		if bool(shooter.get("player_in_range")):
			charge = clampf(since / cooldown, 0.0, 1.0)
		recoil = clampf(1.0 - since * 5.0, 0.0, 1.0)
		stunned = bool(shooter.get("stunned"))
	var open: float = clampf(0.5 + 0.5 * charge - recoil * 0.6, 0.08, 1.0)
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
