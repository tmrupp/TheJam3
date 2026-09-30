extends Node2D
## Ink art for one spawned prefab. `kind` is set by RisoPrint's dresser from the prefab path.
## Drawn in world pixels (the owner's scale is cancelled); the owner's rotation still applies,
## so wall and ceiling spikes point the right way. Presentation only.

class_name RisoProp
const STATIC_KINDS: Array[StringName] = [&"door", &"ledge", &"thorns"]


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
var price_label: Label


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
	match kind:
		&"mote": _mote()
		&"key": _key()
		&"moon": _moon()
		&"portal": _portal()
		&"door": _door()
		&"lantern": _lantern()
		&"exit": _exit()
		&"orb": _orb()
		&"ledge": _ledge()
		&"lift": _lift()
		&"thorns": _thorns()
		&"ghost": _ghost()
		&"wisp": _wisp()
		&"watcher": _watcher()
		&"shard": _shard()
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


func _moon() -> void:
	var o: Vector2 = Vector2(0, sin(t * 2.2 + phase) * 6.0)
	var shard: PackedVector2Array = Transform2D(sin(t) * 0.25, o) * RisoShapes.crescent(Vector2.ZERO, 22.0, Vector2(10, -5))
	ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(o, 34.0, 28)])
	ink.ink(RisoPrint.ACCENT, 1.0, [shard])
	ink.ink(RisoPrint.BLUE, 0.5, [shard])


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
	# As in the prototype: a tall 2:3 arch, screened blue frame around a solid blue panel. It is set
	# into screened jambs that fill the rest of the cell, so the whole blocked doorway reads.
	var g: float = _ground()
	var top: float = g - 2.0 * half
	ink.ink(RisoPrint.BLUE, 0.5, [PackedVector2Array([Vector2(-half, top), Vector2(-40, top), Vector2(-40, g), Vector2(-half, g)]),
		PackedVector2Array([Vector2(40, top), Vector2(half, top), Vector2(half, g), Vector2(40, g)])])
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.arch(-44, g - 124, 88, 124, 14)])
	var panel: PackedVector2Array = RisoShapes.arch(-34, g - 114, 68, 114, 14)
	ink.knock([RisoPrint.NIGHT], [panel])
	ink.ink(RisoPrint.BLUE, 1.0, [panel])
	# The lock shows the colour of key the door needs.
	var lock: Array[PackedVector2Array] = RisoProp.key_shape(Vector2(-6, g - 58), 0.8)
	ink.knock([RisoPrint.BLUE], lock)
	for plate: int in RisoPrint.key_inks(int(host.get_meta(&"key_color", 0))):
		ink.ink(plate, 1.0, lock, false)


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
	var pulse: float = 1.0 + 0.08 * sin(t * 2.5 + phase)
	var g: float = _ground()
	var opening: PackedVector2Array = RisoShapes.arch(-44, g - 110, 88, 110, 14)
	var frame: int = RisoPrint.PINK if which == MapInfo.Exit.DEEPER else RisoPrint.BLUE
	ink.ink(frame, 1.0, [RisoShapes.arch(-52, g - 118, 104, 118, 14)])
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [opening])
	var star: PackedVector2Array = Transform2D(t * 0.4, Vector2(0, g - 58)) * RisoShapes.sparkle(Vector2.ZERO, 20.0 * pulse)
	if owed > 0:
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
	_price_text(owed, Vector2(0, g - 43))


## The stars an unpaid exit costs, printed in night ink on the plaque.
func _price_text(owed: int, at: Vector2) -> void:
	if owed <= 0:
		if price_label != null:
			price_label.visible = false
		return
	if price_label == null:
		price_label = Label.new()
		price_label.add_theme_font_override("font", RisoTheme.serif())
		price_label.add_theme_font_size_override("font_size", 34)
		price_label.add_theme_color_override("font_color", Color.WHITE)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.size = Vector2(80, 48)
		price_label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
		add_child(price_label)
	price_label.visible = true
	price_label.text = str(owed)
	price_label.position = at - price_label.size * 0.5


func _orb() -> void:
	var active: bool = bool(host.get("active"))
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
