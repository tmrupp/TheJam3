extends Node2D
## Ink art for one spawned prefab. `kind` is set by RisoPrint's dresser from the prefab path.
## Drawn in world pixels (the owner's scale is cancelled); the owner's rotation still applies,
## so wall and ceiling spikes point the right way. Presentation only.

const STATIC_KINDS: Array[StringName] = [&"door", &"ledge", &"thorns", &"altar"]

var kind: StringName = &""
var ink: InkCanvas
var host: Node2D
var t: float = 0.0
var phase: float = 0.0


func _ready() -> void:
	host = get_parent() as Node2D
	if host != null and host.scale.x != 0.0 and host.scale.y != 0.0:
		scale = Vector2(1.0 / host.scale.x, 1.0 / host.scale.y)
	phase = RisoShapes.hash1(float(host.get_instance_id() % 997)) * TAU if host != null else 0.0
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


func _redraw() -> void:
	ink.begin()
	match kind:
		&"mote": _mote()
		&"key": _key()
		&"moon": _moon()
		&"portal": _portal()
		&"door": _door()
		&"lantern": _lantern()
		&"gate": _gate()
		&"altar": _altar()
		&"orb": _orb()
		&"ledge": _ledge()
		&"thorns": _thorns()
		&"relic": _relic()
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
	var shape: Array[PackedVector2Array] = [
		RisoShapes.crescent(o + Vector2(-10, 0), 11.0, Vector2(5, -2)),
		RisoShapes.rrect(o.x - 3.0, o.y - 3.5, 24.0, 7.0, 3.5),
		RisoShapes.rrect(o.x + 12.0, o.y, 6.0, 11.0, 3.0),
	]
	ink.ink(RisoPrint.ACCENT, 1.0, shape)


func _moon() -> void:
	var o: Vector2 = Vector2(0, sin(t * 2.2 + phase) * 6.0)
	var shard: PackedVector2Array = Transform2D(sin(t) * 0.25, o) * RisoShapes.crescent(Vector2.ZERO, 22.0, Vector2(10, -5))
	ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(o, 34.0, 28)])
	ink.ink(RisoPrint.ACCENT, 1.0, [shard])
	ink.ink(RisoPrint.BLUE, 0.5, [shard])


func _relic() -> void:
	var o: Vector2 = Vector2(0, sin(t * 2.0 + phase) * 3.0)
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.crescent(o, 13.0, Vector2(6, -3))])
	ink.ink(RisoPrint.PINK, 1.0, [RisoShapes.circle(o + Vector2(4, 0), 3.5, 10)])


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
	var frame: PackedVector2Array = RisoShapes.arch(-62, -66, 124, 130, 12)
	var panel: PackedVector2Array = RisoShapes.arch(-50, -54, 100, 118, 12)
	ink.ink(RisoPrint.BLUE, 1.0, [frame])
	ink.ink(RisoPrint.PINK, 1.0, [panel])
	ink.ink(RisoPrint.NIGHT, 0.3, [PackedVector2Array([Vector2(-50, 10), Vector2(50, 10), Vector2(50, 64), Vector2(-50, 64)])], false)
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.crescent(Vector2(0, -8), 12.0, Vector2(5, -3))])


func _lantern() -> void:
	var player: Node = host.get_node_or_null("/root/Main/Player")
	var lit: bool = player != null and player.get("respawn") == host
	var sw: float = sin(t * 2.2 + phase) * 0.12
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-5, -70, 10, 102, 5), RisoShapes.rrect(-4, -72, 40, 8, 4)])
	var hang: Transform2D = Transform2D(sw, Vector2(30, -66))
	ink.ink(RisoPrint.BLUE, 1.0, [hang * RisoShapes.rrect(-2, 0, 4, 18, 2), hang * RisoShapes.rrect(-14, 14, 28, 8, 4)])
	var glass: PackedVector2Array = hang * RisoShapes.rrect(-12, 20, 24, 28, 10)
	if lit:
		ink.ink(RisoPrint.EYE, 0.25, [hang * RisoShapes.circle(Vector2(0, 34), 44.0, 32)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [glass])
		ink.ink(RisoPrint.EYE, 1.0, [glass], false)
		ink.knock([RisoPrint.EYE], [hang * RisoShapes.rrect(-4, 28, 8, 12, 4)])
	else:
		ink.ink(RisoPrint.BLUE, 1.0, [glass])
		ink.ink(RisoPrint.NIGHT, 0.4, [glass], false)


func _gate() -> void:
	var pulse: float = 1.0 + 0.08 * sin(t * 2.5 + phase)
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.arch(-58, -90, 116, 122, 14)])
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.arch(-44, -76, 88, 108, 14)])
	ink.ink(RisoPrint.EYE, 0.25, [RisoShapes.circle(Vector2(0, -26), 30.0 * pulse, 28)])
	var star: PackedVector2Array = Transform2D(t * 0.4, Vector2(0, -26)) * RisoShapes.sparkle(Vector2.ZERO, 20.0 * pulse)
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], [star])
	ink.ink(RisoPrint.EYE, 1.0, [star], false)


func _altar() -> void:
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-26, 8, 52, 24, 8)])
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.rrect(-22, 4, 44, 8, 4), RisoShapes.crescent(Vector2(0, -14), 12.0, Vector2(5, -3))])


func _orb() -> void:
	var active: bool = bool(host.get("active"))
	var pulse: float = 1.0 + 0.1 * sin(t * 3.0 + phase)
	var o: Vector2 = Vector2(0, -6 + sin(t * 1.6 + phase) * 4.0)
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-20, 12, 40, 20, 8)])
	ink.ink(RisoPrint.ACCENT, 0.15 if active else 0.3, [RisoShapes.circle(o, 34.0 * pulse, 28)])
	ink.ink(RisoPrint.ACCENT, 0.5 if active else 1.0, [RisoShapes.circle(o, 16.0, 24)])
	ink.ink(RisoPrint.BLUE, 0.5, [RisoShapes.crescent(o, 16.0, Vector2(7, -4))])


func _ledge() -> void:
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-63, -64, 126, 34, 12)])
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.rrect(-60, -67, 120, 12, 6)])


func _thorns() -> void:
	var spikes: Array[PackedVector2Array] = []
	for i: int in range(4):
		var x: float = -47.25 + float(i) * 31.5
		spikes.append(RisoShapes.tri(Vector2(x - 13, 32), Vector2(x, -6), Vector2(x + 13, 32)))
	ink.ink(RisoPrint.PINK, 1.0, spikes)


# ------------------------------------------------------------------ nightmares

func _paper_eyes(xf: Transform2D, eyes: Array[Vector2], rx: float, ry: float, look: float) -> void:
	var whites: Array[PackedVector2Array] = []
	var pupils: Array[PackedVector2Array] = []
	for e: Vector2 in eyes:
		whites.append(xf * RisoShapes.ellipse(e, rx, ry, 14))
		pupils.append(xf * RisoShapes.circle(e + Vector2(look * rx * 0.35, 0.15), minf(rx, ry) * 0.55, 10))
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], whites)
	ink.ink(RisoPrint.BLUE, 1.0, pupils)


func _look_dir() -> float:
	var player: Node2D = host.get_node_or_null("/root/Main/Player") as Node2D
	if player == null:
		return 1.0
	return signf(player.global_position.x - host.global_position.x)


func _wisp() -> void:
	var mover: Node = host.get_node_or_null("Mover")
	var dir: float = 1.0
	var stunned: bool = false
	if mover != null:
		dir = float(mover.get("direction"))
		stunned = bool(mover.get("stunned"))
	var k: float = 2.4
	var bob: float = -3.0 - sin(t * 3.0 + phase) * 1.6
	var xf: Transform2D = Transform2D(0.0, Vector2(dir * k, k), 0.0, Vector2(0, 14.0 + bob * k))
	var speed: float = 0.3 if stunned else 1.0
	var w: Array[float] = []
	for j: int in range(4):
		w.append(sin(t * 6.0 * speed - float(j)) * 1.4)
	var body: PackedVector2Array = xf * RisoShapes.smooth(PackedVector2Array([
		Vector2(5.6, -9), Vector2(4.6, -4.6), Vector2(1.6, -3), Vector2(-2, -3.8 + w[1] * 0.3), Vector2(-5.6, -4.8 + w[1]),
		Vector2(-9, -6.6 + w[2]), Vector2(-12.4, -8.6 + w[3]), Vector2(-8.8, -9.6 + w[2]), Vector2(-5.2, -11 + w[1] * 0.6),
		Vector2(-1.4, -13.2), Vector2(2.6, -13.4)]))
	ink.ink(RisoPrint.PINK, 1.0, [body])
	ink.ink(RisoPrint.BLUE, 0.5, [body])
	if stunned:
		ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE], [xf * RisoShapes.rrect(2.4, -9.4, 2, 0.5, 0.25, 2), xf * RisoShapes.rrect(-0.3, -9.6, 2, 0.5, 0.25, 2)])
	else:
		_paper_eyes(xf, [Vector2(3.4, -9.2), Vector2(0.7, -9.4)], 1.0, 1.35, _look_dir() * dir)


func _watcher() -> void:
	var shooter: Node = host.get_node_or_null("Shooter")
	var at: Vector2 = Vector2(0, -14.3)
	var open: float = 0.55
	if shooter != null:
		var point: Node2D = shooter.get_node_or_null("ShootPoint") as Node2D
		if point != null:
			at = to_local(point.global_position)
		if bool(shooter.get("player_in_range")):
			open = 1.0
		var sfx: AudioStreamPlayer = shooter.get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
		if sfx != null and sfx.playing:
			open = 0.15
		if bool(shooter.get("stunned")):
			open = 0.08
	var k: float = 2.6
	var xf: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, at + Vector2(0, sin(t * 2.0 + phase) * 3.0))
	var drips: Array[PackedVector2Array] = []
	for j: int in range(3):
		var x: float = -4.0 + float(j) * 4.0
		var l: float = 4.0 + sin(t * 2.0 + float(j)) * 1.5
		drips.append(xf * PackedVector2Array([Vector2(x - 1.4, 3), Vector2(x, 6 + l), Vector2(x + 1.4, 3)]))
	var lid: PackedVector2Array = xf * RisoShapes.almond(Vector2.ZERO, 10.0, 5.6, 12)
	ink.ink(RisoPrint.PINK, 1.0, [lid])
	ink.ink(RisoPrint.PINK, 1.0, drips)
	ink.ink(RisoPrint.BLUE, 0.5, [lid])
	var yo: float = lerpf(2.0, 0.0, open)
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [xf * RisoShapes.almond(Vector2(0, yo), 8.2, maxf(0.3, 4.4 * open), 12)])
	var player: Node2D = host.get_node_or_null("/root/Main/Player") as Node2D
	var look: Vector2 = Vector2.ZERO
	if player != null:
		var d: Vector2 = player.global_position - to_global(at)
		look = Vector2(clampf(d.x / 200.0, -1.0, 1.0) * 2.6, clampf(d.y / 200.0, -1.0, 1.0) * 1.2)
	ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.circle(look + Vector2(0, yo), 3.0 * maxf(0.35, open), 14)])
	ink.ink(RisoPrint.BLUE, 1.0, [xf * RisoShapes.circle(look + Vector2(0, yo), 1.3 * maxf(0.35, open), 10)])


func _shard() -> void:
	var v: Variant = host.get("velocity")
	var ang: float = (v as Vector2).angle() if v is Vector2 else 0.0
	var xf: Transform2D = Transform2D(ang, Vector2.ZERO)
	ink.ink(RisoPrint.PINK, 0.5, [xf * RisoShapes.rrect(-34, -3, 30, 6, 3)])
	ink.ink(RisoPrint.PINK, 1.0, [xf * RisoShapes.sparkle(Vector2.ZERO, 10.0, 1.7)])
	ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.circle(Vector2(2, 0), 4.0, 10)])
