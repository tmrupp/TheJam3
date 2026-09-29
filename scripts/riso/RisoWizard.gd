extends Node2D
## The faceless wizard, printed in ink. A small spring rig drives it from the real Player:
## planted feet, a cloth hem that swings and billows, a two-spring floppy hat, body bob with a
## lagging head, eased turns, breathing and blinks. Art units match the HTML prototype
## (the Player's scale of 4 turns them into world pixels). Presentation only; collision is untouched.

const STRIDE: float = 22.0
const MAXV: float = 88.0
const HEMX: Array[float] = [-8.8, -4.5, 0.0, 4.5, 8.8]
const VX_SCALE: float = 88.0 / 300.0
const VY_SCALE: float = 0.5
const ALL: Array[int] = [0, 1, 2, 3, 4, 5]
## Art scale around the feet. Level cells are 128 px while the player collider is ~62 px,
## so the prototype's proportions (body about one tile tall) need the art a little larger
## than the collider. Collision is unchanged.
const ART_SCALE: float = 1.3

var player: Player
var body: InkCanvas
var world: InkCanvas

var t: float = 0.0
var fs: float = 1.0
var dist: float = 0.0
var sp: float = 0.0
var bob: float = 0.0
var head_y: float = 0.0
var head_v: float = 0.0
var lean: float = 0.0
var lean_v: float = 0.0
var hat_a: float = 0.0
var hat_v: float = 0.0
var tip_a: float = -0.35
var tip_v: float = 0.0
var ax: float = 0.0
var pvx: float = 0.0
var pvy: float = 0.0
var pg: bool = true
var squash: float = 1.0
var squash_v: float = 0.0
var hem_x: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
var hem_y: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
var hem_vx: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
var hem_vy: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
var flare_amount: float = 0.0
var trail: Array[Vector3] = []  # x, y = feet position (world), z = life 0..1
var ghosts: Array[Vector4] = []  # x, y, facing, life 0..1
var _was_dashing: bool = false
var _was_climbing: bool = false


func _ready() -> void:
	player = get_parent() as Player
	position = Vector2(0, _feet_offset())
	scale = Vector2(ART_SCALE, ART_SCALE)
	z_index = 10
	body = InkCanvas.new()
	add_child(body)
	world = InkCanvas.new()
	world.top_level = true
	world.z_index = 9
	world.z_as_relative = false
	add_child(world)
	if player != null:
		player.visual_event.connect(_on_event)


func _feet_offset() -> float:
	var shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D if player != null else null
	if shape != null and shape.shape is RectangleShape2D:
		return shape.position.y + (shape.shape as RectangleShape2D).size.y * shape.scale.y * 0.5
	return 7.75


func flare() -> void:
	flare_amount = 1.0


func _on_event(kind: StringName, at: Vector2) -> void:
	if kind == &"jump":
		squash_v += 4.5
	elif kind == &"projection_start":
		ghosts.append(Vector4(at.x, at.y, signf(fs), 1.0))
	elif kind == &"dash":
		squash_v -= 3.0


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var dashing: bool = player.dash.is_acting()
	if dashing and not _was_dashing:
		if RisoPrint.instance != null:
			RisoPrint.instance.flare(&"blink" if player.has_node("Blink") else &"dash")
		else:
			flare()
	_was_dashing = dashing
	var climbing: bool = player.climb.is_acting()
	if climbing and not _was_climbing and RisoPrint.instance != null:
		RisoPrint.instance.flare(&"climb")
	_was_climbing = climbing
	_rig(delta, dashing)
	var feet: Vector2 = global_position
	if dashing:
		trail.append(Vector3(feet.x, feet.y, 1.0))
	for i: int in range(trail.size() - 1, -1, -1):
		var pt: Vector3 = trail[i]
		pt.z -= delta / 0.24
		if pt.z <= 0.0:
			trail.remove_at(i)
		else:
			trail[i] = pt
	for i: int in range(ghosts.size() - 1, -1, -1):
		var g: Vector4 = ghosts[i]
		g.w -= delta / 1.4
		if g.w <= 0.0:
			ghosts.remove_at(i)
		else:
			ghosts[i] = g
	flare_amount = maxf(0.0, flare_amount - delta * 2.2)


func _rig(dt: float, dashing: bool) -> void:
	var vx: float = player.velocity.x * VX_SCALE
	var vy: float = player.velocity.y * VY_SCALE
	var ground: bool = player.is_on_floor()
	var face: float = signf(player.sprite.scale.x) if player.sprite != null else 1.0
	t += dt
	ax += (clampf((vx - pvx) / dt, -3000.0, 3000.0) - ax) * minf(1.0, dt * 25.0)
	var landed: bool = ground and not pg and pvy > 80.0
	var took: bool = not ground and pg and vy < -100.0
	if landed:
		squash_v -= pvy * 0.016
	fs += (face - fs) * minf(1.0, dt * 16.0)
	sp += ((clampf(absf(vx) / MAXV, 0.0, 1.0) if ground else 0.0) - sp) * minf(1.0, dt * 10.0)
	if ground:
		dist += absf(vx) * dt
	var ph: float = fposmod(dist / STRIDE, 1.0)
	var fsn: float = clampf(fs, -1.0, 1.0)
	var bob_t: float = (-(0.5 - 0.5 * cos(ph * 4.0 * PI)) * 1.1 * sp + (sin(t * 2.1) - 1.0) * 0.3 * (1.0 - sp)) if ground else -0.4
	bob += (bob_t - bob) * minf(1.0, dt * 30.0)
	head_v += ((bob - head_y) * 260.0 - head_v * 18.0) * dt
	head_y += head_v * dt
	var lean_t: float = clampf(vx / MAXV, -1.0, 1.0) * 0.07 + clampf(ax / 1500.0, -1.0, 1.0) * 0.06 + (face * 0.16 if dashing else 0.0)
	lean_v += ((lean_t - lean) * 180.0 - lean_v * 16.0) * dt
	lean += lean_v * dt
	var hat_t: float = -clampf(ax / 1500.0, -1.0, 1.0) * 0.2 - clampf(vx / MAXV, -1.0, 1.0) * 0.1 + (0.0 if ground else clampf(vy / 300.0, -1.0, 1.0) * 0.08 * fsn)
	hat_v += ((hat_t - hat_a) * 150.0 - hat_v * 11.0) * dt
	hat_a += hat_v * dt
	var tip_t: float = -fsn * 0.38 - clampf(vx / MAXV, -1.0, 1.0) * 0.28 + (0.0 if ground else -fsn * clampf(-vy / 300.0, -1.0, 1.0) * 0.22) + sin(t * 0.9) * 0.06 * (1.0 - sp) + (-face * 0.4 if dashing else 0.0)
	tip_v += ((tip_t - tip_a) * 85.0 - tip_v * 5.5) * dt - hat_v * dt * 7.0
	tip_a = clampf(tip_a + tip_v * dt, -1.6, 1.6)
	var spread: float = 0.0 if ground else clampf(vy / 300.0, 0.0, 1.3) * 3.0
	var lift: float = 0.0 if ground else clampf(vy / 300.0, -0.6, 1.3) * 3.4
	var spd: float = clampf(absf(vx) / MAXV, 0.0, 1.5)
	for i: int in range(5):
		var side: float = float(i - 2) / 2.0
		var k: float = 95.0 - absf(side) * 35.0
		var tx: float = -3.4 * tanh(vx / 80.0) * (1.0 + absf(side) * 0.3) + side * spread + (-face * 2.5 if dashing else 0.0)
		var ty: float = -lift * (0.55 + 0.45 * absf(side)) - spd * 0.7 * absf(side)
		tx += sin(t * 7.5 - float(i) * 1.1) * 0.55 * spd + sin(t * 1.3 + float(i) * 0.8) * 0.25 * (1.0 - sp)
		ty += sin(t * 7.5 - float(i) * 1.1 + 1.2) * 0.45 * spd
		if ground:
			tx += sin(ph * TAU + float(i) * 0.7) * 0.8 * sp
			ty += sin(ph * TAU * 2.0 + float(i) * 0.9) * 0.5 * sp
		if landed:
			hem_vx[i] += side * 20.0
			hem_vy[i] += 12.0
		if took:
			hem_vy[i] += 16.0
		hem_vx[i] += ((tx - hem_x[i]) * k - hem_vx[i] * 4.8 - ax * 0.12) * dt
		hem_vy[i] += ((ty - hem_y[i]) * k - hem_vy[i] * 4.8) * dt
		hem_x[i] = clampf(hem_x[i] + hem_vx[i] * dt, -10.0, 10.0)
		hem_y[i] = clampf(hem_y[i] + hem_vy[i] * dt, -8.0, 4.0)
	if landed:
		head_v += 34.0
		tip_v += fsn * 2.5
	if took:
		head_v -= 16.0
		tip_v -= fsn * 2.0
	var squash_t: float = 0.8 if dashing else (1.0 if ground else 1.0 + clampf(absf(vy) / 2600.0, 0.0, 0.12))
	squash_v += ((squash_t - squash) * 260.0 - squash_v * 15.0) * dt
	squash = clampf(squash + squash_v * dt, 0.68, 1.32)
	pvx = vx
	pvy = vy
	pg = ground


func _feet() -> Array[Vector2]:
	var ph: float = fposmod(dist / STRIDE, 1.0)
	var a: float = STRIDE / 4.0
	var face: float = signf(fs) if fs != 0.0 else 1.0
	var dir: float = signf(player.velocity.x) if absf(player.velocity.x) > 1.0 else face
	var out: Array[Vector2] = []
	for k: int in range(2):
		var rest: float = 1.9 if k == 1 else -1.9
		if not pg:
			out.append(Vector2(rest * 0.8 + (0.6 if k == 1 else -0.6) * face, -1.5))
			continue
		var phi: float = fposmod(ph + float(k) * 0.5, 1.0)
		var x: float
		var y: float = 0.0
		if phi < 0.5:
			x = lerpf(a, -a, phi / 0.5)
		else:
			var u: float = (phi - 0.5) / 0.5
			x = lerpf(-a, a, u * u * (3.0 - 2.0 * u))
			y = -sin(PI * u) * 1.9
		out.append(Vector2(lerpf(rest, x * dir + (0.8 if k == 1 else -0.8), sp), y * sp))
	return out


func _soft(v: float, m: float) -> float:
	return m * tanh(v / m)


func _process(_delta: float) -> void:
	if player == null or not visible:
		return
	_draw_body()
	_draw_world()


func _draw_body() -> void:
	var f: float = 1.0 if fs >= 0.0 else -1.0
	var af: float = absf(clampf(fs, -1.0, 1.0))
	var fsc: float = clampf(fs, -1.0, 1.0)
	var hy: float = head_y
	var dashing: bool = player.dash.is_acting()
	var hurt: bool = player.invulnerable.is_acting() and int(t * 16.0) % 2 == 0
	var cyc: float = fposmod(t, 3.9)
	var blink: bool = cyc < 0.11 or (int(t / 3.9) % 3 == 0 and cyc > 0.2 and cyc < 0.3)
	var m: Transform2D = Transform2D(Vector2(1.0 / squash, 0), Vector2(0, squash), Vector2.ZERO) * Transform2D(lean, Vector2.ZERO)
	var mh: Transform2D = m * Transform2D(hat_a + lean * 0.4, Vector2(fsc * 0.2, -21.3 + hy))
	var hem: Array[Vector2] = []
	for i: int in range(5):
		var hy_i: float = _soft(hem_y[i], 1.5) if hem_y[i] > 0.0 else _soft(hem_y[i], 5.5)
		hem.append(Vector2(HEMX[i] + _soft(hem_x[i], 6.0), minf(-0.6, -2.4 + hy_i)))
	var robe: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(-2.4, -15.9 + bob), Vector2(-4.8, -14.8 + bob), Vector2(-6.3 + (hem[0].x + 8.8) * 0.45, -8.4 + bob * 0.5),
		Vector2(hem[0].x - 0.5, hem[0].y + 0.3), hem[1], hem[2], hem[3], Vector2(hem[4].x + 0.5, hem[4].y + 0.3),
		Vector2(6.3 + (hem[4].x - 8.8) * 0.45, -8.4 + bob * 0.5), Vector2(4.8, -14.8 + bob), Vector2(2.4, -15.9 + bob)]))
	var hb: Vector2 = hem[0] if f > 0.0 else hem[4]
	var mid: Vector2 = hem[1] if f > 0.0 else hem[3]
	var back_shade: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(-f * 0.8, -13.8 + bob), Vector2(-f * 4.3, -10.0 + bob * 0.6), Vector2(hb.x + f * 0.9, hb.y - 0.2),
		Vector2(mid.x, mid.y - 0.3), Vector2(-f * 1.6 + mid.x * 0.3, -7.0 + bob * 0.5)]))
	var folds: Array[PackedVector2Array] = []
	for i: int in [1, 2, 3]:
		var sw: float = hem[i].x - HEMX[i]
		var top: Vector2 = Vector2(HEMX[i] * 0.3 + sw * 0.15, -13.0 + bob)
		var mx: float = (top.x + hem[i].x) * 0.5 + sw * 0.35 + float(i - 2) * 0.5
		var w: float = 0.9 + absf(float(i - 2)) * 0.25
		var my: float = (top.y + hem[i].y) * 0.5
		folds.append(m * RisoShapes.smooth(PackedVector2Array([
			top + Vector2(-0.15, 0), Vector2(mx - w * 0.45, my), Vector2(hem[i].x - w, hem[i].y - 0.3),
			Vector2(hem[i].x, hem[i].y - 1.4), Vector2(hem[i].x + w, hem[i].y - 0.3), Vector2(mx + w * 0.45, my), top + Vector2(0.15, 0)]), 3))
	var ph: float = fposmod(dist / STRIDE, 1.0)
	var swing: float = -sin(ph * TAU) * 1.7 * sp
	var hand: Vector2 = Vector2(fsc * 4.4 + swing * f + (-f * 2.5 if dashing else 0.0), (-7.2 if pg else -9.2) + bob * 0.8)
	var sleeve: PackedVector2Array = m * RisoShapes.smooth(PackedVector2Array([
		Vector2(fsc * 0.8, -14.4 + bob), Vector2(fsc * 4.2, -13.6 + bob), hand + Vector2(f * 1.9, -0.2),
		hand + Vector2(f * 0.9, 2.0), hand + Vector2(-f * 1.4, 1.7), Vector2(fsc * 1.6, -9.8 + bob)]))
	var collar: PackedVector2Array = m * RisoShapes.smooth(PackedVector2Array([
		Vector2(-4.9, -14.9 + bob), Vector2(-3.2, -17.6 + bob), Vector2(-0.8, -16.4 + bob), Vector2(0.8, -16.4 + bob),
		Vector2(3.2, -17.6 + bob), Vector2(4.9, -14.9 + bob), Vector2(0, -13.6 + bob)]))
	var face: PackedVector2Array = m * RisoShapes.ellipse(Vector2(fsc * 0.9, -18.5 + hy), 3.8 * (0.72 + 0.28 * af), 3.3, 22)
	var look: float = fsc * 0.35 * sp
	var gap: float = 1.45 * (0.8 + 0.2 * af)
	var eye_ry: float = 0.45 + 0.55 * af
	var eye_c: Array[Vector2] = [Vector2(fsc * 1.6 + look - gap, -18.5 + hy), Vector2(fsc * 1.6 + look + gap, -18.5 + hy)]
	var ta: float = 1.1 * tanh(tip_a / 1.1)
	var d2: Vector2 = Vector2(sin(ta), -cos(ta))
	var pp: Vector2 = Vector2(cos(ta), sin(ta))
	var tip: Vector2 = Vector2(d2.x * 8.8, -7.4 + d2.y * 8.8)
	var cone: PackedVector2Array = mh * RisoShapes.smooth(PackedVector2Array([
		Vector2(-5.1, -0.25), Vector2(-3.1 + tip.x * 0.3, -7.3), tip - d2 * 1.6 - pp * 1.15, tip + d2 * 0.55,
		tip - d2 * 1.6 + pp * 1.15, Vector2(3.1 + tip.x * 0.3, -7.3), Vector2(5.1, -0.25), Vector2(0, 0.55)]))
	var brim: PackedVector2Array = mh * RisoShapes.ellipse(Vector2.ZERO, 9.2, 1.8, 28)
	var band: PackedVector2Array = mh * RisoShapes.smooth(PackedVector2Array([Vector2(-5.4, -0.3), Vector2(0, -0.1), Vector2(5.4, -0.3), Vector2(4.6, -3.3), Vector2(0, -3.5), Vector2(-4.6, -3.3)]))
	var bead: Vector2 = mh * (tip - d2 * 0.6)
	var boots: Array[PackedVector2Array] = []
	for p: Vector2 in _feet():
		var boot: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([Vector2(-1.9, 0.1), Vector2(1.2, 0.1), Vector2(3.3, -0.1), Vector2(3.5, -1.2), Vector2(2.3, -2.0), Vector2(1.0, -2.2), Vector2(0.9, -4.6), Vector2(-1.6, -4.6), Vector2(-2.0, -1.6)]), 3)
		boots.append(m * (Transform2D(0.0, Vector2(f, 1), 0.0, p) * boot))
	var robe_m: PackedVector2Array = m * robe
	body.begin()
	body.ink(RisoPrint.NIGHT, 1.0, boots, false)
	body.ink(RisoPrint.BLUE, 1.0, boots, false)
	body.ink(RisoPrint.BLUE, 1.0, [robe_m])
	body.ink(RisoPrint.NIGHT, 0.18, [m * back_shade], false)
	body.ink(RisoPrint.NIGHT, 0.42, folds, false)
	body.ink(RisoPrint.NIGHT, 1.0, [face], false)
	body.ink(RisoPrint.BLUE, 1.0, [face], false)
	var eyes: Array[PackedVector2Array] = []
	for c: Vector2 in eye_c:
		eyes.append(m * (RisoShapes.ellipse(c, 1.0, 1.0 * eye_ry, 12) if not blink else RisoShapes.rrect(c.x - 1.0, c.y - 0.25, 2.0, 0.5, 0.25, 2)))
	if not blink:
		body.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT], eyes)
	body.ink(RisoPrint.EYE, 1.0, eyes, false)
	if not blink and eye_ry > 0.7:
		var cores: Array[PackedVector2Array] = []
		for c: Vector2 in eye_c:
			cores.append(m * RisoShapes.circle(c + Vector2(fsc * 0.25, -0.2), 0.4, 8))
		body.knock([RisoPrint.EYE], cores)
	body.knock([RisoPrint.NIGHT, RisoPrint.EYE], [collar])
	body.ink(RisoPrint.BLUE, 1.0, [collar])
	body.ink(RisoPrint.PINK, 0.25, [collar])
	body.knock([RisoPrint.NIGHT], [sleeve])
	body.ink(RisoPrint.BLUE, 1.0, [sleeve])
	body.ink(RisoPrint.PINK, 0.25, [sleeve])
	body.knock([RisoPrint.NIGHT, RisoPrint.EYE], [cone, brim])
	body.ink(RisoPrint.BLUE, 1.0, [cone, brim])
	body.ink(RisoPrint.PINK, 0.25, [cone])
	body.ink(RisoPrint.ACCENT, 1.0, [band])
	var pulse: float = 1.0 + 0.08 * sin(t * 3.0)
	var ready: bool = not player.dash.acted
	body.ink(RisoPrint.GLOW, 0.15, [RisoShapes.circle(bead, (4.6 + flare_amount * 7.0) * pulse, 24)])
	body.ink(RisoPrint.GLOW, 0.25, [RisoShapes.circle(bead, (3.2 + flare_amount * 4.0) * pulse, 20)])
	body.ink(RisoPrint.GLOW, 0.5, [RisoShapes.circle(bead, 2.2 + flare_amount * 1.5, 16)])
	body.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE], [RisoShapes.circle(bead, 1.35, 12)])
	body.ink(RisoPrint.GLOW, 1.0 if ready else 0.5, [RisoShapes.circle(bead, 1.35, 12)], false)
	if ready:
		body.knock([RisoPrint.GLOW], [RisoShapes.circle(bead - Vector2(0.3, 0.3), 0.5 + flare_amount * 0.3, 8)])
	if hurt:
		var pieces: Array[PackedVector2Array] = []
		pieces.append_array(boots)
		pieces.append_array([robe_m, collar, sleeve, face, cone, brim])
		for piece: PackedVector2Array in pieces:
			body.knock(ALL, [piece])
			body.ink(RisoPrint.PINK, 1.0, [piece], false)
		var whites: Array[PackedVector2Array] = []
		for c: Vector2 in eye_c:
			whites.append(m * RisoShapes.circle(c, 1.0, 10))
		body.knock([RisoPrint.PINK], whites)
	body.finish()


func _draw_world() -> void:
	var s: float = player.global_scale.y * ART_SCALE
	world.begin()
	# Dash smear: a continuous ribbon along the dash path (oldest point first), thin and faint at
	# the tail, full height at the wizard. Built from per-segment quads offset along each
	# segment's normal, so vertical and diagonal dashes smear correctly and never fold over.
	if trail.size() > 0:
		var head: Vector2 = global_position
		var pts: Array[Vector3] = []
		pts.append_array(trail)
		pts.append(Vector3(head.x, head.y, 1.0))
		var n: int = pts.size()
		var quads: Array[PackedVector2Array] = []
		var fades: Array[PackedFloat32Array] = []
		var lift: Vector2 = Vector2(0, -17.0 * s)
		for i: int in range(n - 1):
			var a: Vector2 = Vector2(pts[i].x, pts[i].y) + lift
			var b: Vector2 = Vector2(pts[i + 1].x, pts[i + 1].y) + lift
			if a.distance_to(b) < 1.0:
				continue
			var nrm: Vector2 = (b - a).normalized().orthogonal()
			var ua: float = float(i) / float(n - 1)
			var ub: float = float(i + 1) / float(n - 1)
			var ha: float = lerpf(2.5, 16.0, pow(ua, 0.8)) * s
			var hb: float = lerpf(2.5, 16.0, pow(ub, 0.8)) * s
			var fa: float = 0.72 * pow(ua, 1.3) * pts[i].z
			var fb: float = 0.72 * pow(ub, 1.3) * pts[i + 1].z
			quads.append(PackedVector2Array([a - nrm * ha, b - nrm * hb, b + nrm * hb * 0.95, a + nrm * ha * 0.95]))
			fades.append(PackedFloat32Array([fa, fb, fb, fa]))
		if not quads.is_empty():
			world.ink_graded(RisoPrint.BLUE, quads, fades)
	# Astral projection: a glowing silhouette holds the return point; a short afterimage marks each start.
	var marks: Array[Vector4] = []
	marks.append_array(ghosts)
	var projection: Node = player.get_node_or_null("AstralProjection")
	if projection != null:
		var origin: Variant = projection.get("false_player_origin")
		if origin is Node2D and is_instance_valid(origin):
			var o: Node2D = origin as Node2D
			marks.append(Vector4(o.global_position.x, o.global_position.y + _feet_offset() * s, signf(fs), 1.0))
	for g: Vector4 in marks:
		var at: Transform2D = Transform2D(0.0, Vector2(s, s), 0.0, Vector2(g.x, g.y - (1.0 - g.w) * 6.0 * s))
		var ghost: Array[PackedVector2Array] = [
			at * RisoShapes.smooth(PackedVector2Array([Vector2(-3.8, -15), Vector2(-6.6, -7), Vector2(-9, -2.2), Vector2(9, -2.2), Vector2(6.6, -7), Vector2(3.8, -15)])),
			at * RisoShapes.smooth(PackedVector2Array([Vector2(-5, -21.4), Vector2(-2.9, -28.4), Vector2(-g.z * 4.6, -37), Vector2(2.9, -28.4), Vector2(5, -21.4)])),
		]
		world.ink(RisoPrint.GLOW, 0.25 if g.w > 0.5 else 0.15, ghost)
	world.finish()
