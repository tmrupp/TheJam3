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
const ALL: Array[int] = [0, 1, 2, 3, 4, 5, 6]
## Cleared under the robe and hat so the robe ink prints true over whatever is behind.
const UNDER: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW]
## Night shade on the collar, sleeve and hat cone, setting them off from the robe.
const TRIM_SHADE: float = 0.22
## Art scale around the feet: at 0.8 the robe fits the ~62 px collider. Collision is unchanged.
const ART_SCALE: float = 0.8

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
## The wand's tip flare, set when a spell is cast (the hat's flare is the dash's).
var wand_flare_amount: float = 0.0
## Dash afterimages: x, y = feet (world), z = facing, w = life 1..0. One is left each time the
## dash has carried the wizard ECHO_GAP art units on from the last.
var echoes: Array[Vector4] = []
const ECHO_GAP: float = 12.0
const ECHO_LIFE: float = 0.3
const ECHO_COVER: float = 0.55
## Where this dash left its last afterimage (INF between dashes).
var _echo_at: Vector2 = Vector2.INF
var ghosts: Array[Vector4] = []  # x, y, facing, life 0..1
var _was_dashing: bool = false
var key_pos: Vector2 = Vector2.INF
var _was_climbing: bool = false
## Pressed-against-wall pose: `wall` blends 0..1, `wall_side` is +1 when the wall is to the right.
var wall: float = 0.0
var wall_side: float = 1.0
var push_t: float = 0.0
var climb_y: float = 0.0
## Wall face in art units: the collider's half-width divided by ART_SCALE.
const WALL_X: float = 9.2


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


## A spell was cast: the wand's tip flares.
func wand_flare() -> void:
	wand_flare_amount = 1.0


## How ready the spell in the slot is, 0..1 (the wand tip's brightness), or -1 with no spell.
func _spell_ready() -> float:
	match Abilities.spell(player):
		&"":
			return -1.0
		&"hex":
			var hex: Hex = player.get_node_or_null("Hex") as Hex
			return hex.readiness() if hex != null else 1.0
		&"levitate":
			var lev: Levitate = player.get_node_or_null("Levitate") as Levitate
			return 1.0 if lev == null or lev.charged or lev.floating() else 0.0
		&"parry":
			var parry: Node = player.get_node_or_null("Parry")
			var cd: ActionTimer = parry.get("cooldown") as ActionTimer if parry != null else null
			if cd == null or not cd.acted:
				return 1.0
			return 1.0 - clampf(cd.acting / cd.MAX_TIME, 0.0, 1.0) if cd.is_acting() else 0.0
	return 1.0


func _on_event(kind: StringName, at: Vector2) -> void:
	if kind == &"jump":
		squash_v += 4.5
	elif kind == &"projection_start":
		ghosts.append(Vector4(at.x, at.y, signf(fs), 1.0))
	elif kind == &"teleport":
		# Out of the portal tall and thin; the squash spring settles it back.
		squash = 1.32
		squash_v = 0.0
		key_pos = Vector2.INF


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
		var gap: float = ECHO_GAP * player.global_scale.y * ART_SCALE
		if _echo_at == Vector2.INF or _echo_at.distance_to(feet) >= gap:
			echoes.append(Vector4(feet.x, feet.y, signf(fs), 1.0))
			_echo_at = feet
	else:
		_echo_at = Vector2.INF
	for i: int in range(echoes.size() - 1, -1, -1):
		var e: Vector4 = echoes[i]
		e.w -= delta / ECHO_LIFE
		if e.w <= 0.0:
			echoes.remove_at(i)
		else:
			echoes[i] = e
	for i: int in range(ghosts.size() - 1, -1, -1):
		var g: Vector4 = ghosts[i]
		g.w -= delta / 1.4
		if g.w <= 0.0:
			ghosts.remove_at(i)
		else:
			ghosts[i] = g
	flare_amount = maxf(0.0, flare_amount - delta * 2.2)
	wand_flare_amount = maxf(0.0, wand_flare_amount - delta * 2.2)
	# A carried key trails the wizard on a soft lag, just behind and above the shoulder.
	var s: float = player.global_scale.y * ART_SCALE
	var target: Vector2 = global_position + Vector2(-signf(fs) * 11.0, -24.0) * s
	if key_pos == Vector2.INF or not player.has_meta(&"carried_key"):
		key_pos = target
	key_pos = key_pos.lerp(target, minf(1.0, delta * 8.0))


func _rig(dt: float, dashing: bool) -> void:
	var vx: float = player.velocity.x * VX_SCALE
	var vy: float = player.velocity.y * VY_SCALE
	var ground: bool = player.is_on_floor()
	var face: float = signf(player.sprite.scale.x) if player.sprite != null else 1.0
	t += dt
	var normal: Vector2 = player.get_wall_normal() if player.is_on_wall() else Vector2.ZERO
	var pushing: bool = absf(normal.x) > 0.5 and Input.get_axis("Left", "Right") * normal.x < -0.1
	var clinging: bool = absf(normal.x) > 0.5 and player.climb.is_acting()
	if pushing or clinging:
		wall_side = -signf(normal.x)
	wall += ((1.0 if (pushing or clinging) and not dashing else 0.0) - wall) * minf(1.0, dt * 12.0)
	push_t += dt * wall
	if clinging:
		climb_y += absf(vy) * dt
	var landed: bool = ground and not pg and pvy > 80.0
	ax += (clampf((vx - pvx) / dt, -3000.0, 3000.0) - ax) * minf(1.0, dt * 25.0)
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
	# Straining against the wall: sink a little and tremble.
	bob_t += (-0.5 + sin(t * 41.0) * 0.12 + sin(push_t * 4.4) * 0.2) * wall if ground else 0.0
	bob += (bob_t - bob) * minf(1.0, dt * 30.0)
	head_v += ((bob - head_y) * 260.0 - head_v * 18.0) * dt
	head_y += head_v * dt
	var lean_t: float = clampf(vx / MAXV, -1.0, 1.0) * 0.07 + clampf(ax / 1500.0, -1.0, 1.0) * 0.06 + (face * 0.16 if dashing else 0.0)
	lean_t += wall_side * (0.2 if ground else 0.08) * wall
	lean_v += ((lean_t - lean) * 180.0 - lean_v * 16.0) * dt
	lean += lean_v * dt
	var hat_t: float = -clampf(ax / 1500.0, -1.0, 1.0) * 0.2 - clampf(vx / MAXV, -1.0, 1.0) * 0.1 + (0.0 if ground else clampf(vy / 300.0, -1.0, 1.0) * 0.08 * fsn)
	# The brim meets the wall first, so the hat is shoved back off it.
	hat_t -= wall_side * 0.24 * wall
	hat_v += ((hat_t - hat_a) * 150.0 - hat_v * 11.0) * dt
	hat_a += hat_v * dt
	var tip_t: float = -fsn * 0.38 - clampf(vx / MAXV, -1.0, 1.0) * 0.28 + (0.0 if ground else -fsn * clampf(-vy / 300.0, -1.0, 1.0) * 0.22) + sin(t * 0.9) * 0.06 * (1.0 - sp) + (-face * 0.4 if dashing else 0.0)
	tip_t -= wall_side * 0.35 * wall
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
		elif vy > 0.0:
			# Sliding down the wall drags the wall-side hem up.
			ty -= wall * maxf(0.0, side * wall_side) * 2.6 * clampf(vy / 150.0, 0.0, 1.0)
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
	# No squash while dashing: the dash reads through the lean, the hem and the afterimages instead.
	var squash_t: float = 1.0 if ground or dashing else 1.0 + clampf(absf(vy) / 2600.0, 0.0, 0.12)
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
	if wall > 0.01:
		# Against a wall: braced on the ground (the back foot scrabbles for grip), or one sole
		# flat on the wall in the air, stepping up it while climbing.
		var near: int = 1 if wall_side > 0.0 else 0
		var braced: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
		if pg:
			var q: float = fposmod(push_t * 1.3, 1.0)
			var slide: float = q / 0.82 if q < 0.82 else 1.0 - (q - 0.82) / 0.18
			braced[near] = Vector2(wall_side * 3.4, 0.0)
			braced[1 - near] = Vector2(-wall_side * (3.0 + 1.6 * slide), -sin(clampf((q - 0.82) / 0.18, 0.0, 1.0) * PI) * 1.3)
		else:
			var step: float = sin(climb_y * 0.3)
			braced[near] = Vector2(wall_side * (WALL_X - 2.4), -3.6 + step * 1.2)
			braced[1 - near] = Vector2(-wall_side * 0.6, -1.4 - step * 0.8)
		for k: int in range(2):
			out[k] = out[k].lerp(braced[k], wall)
	return out


func _soft(v: float, m: float) -> float:
	return m * tanh(v / m)


## Smoosh against the wall: points past a knee near the wall face flatten onto it, and the
## squeezed-out material spreads up and down along the wall.
func _smv(v: Vector2) -> Vector2:
	if wall <= 0.001:
		return v
	var knee: float = WALL_X - 3.5
	var s: float = v.x * wall_side
	if s <= knee:
		return v
	var over: float = s - knee
	var flat: float = 3.5 * tanh(over / 3.5)
	var pressed: Vector2 = Vector2(wall_side * (knee + flat), v.y + (v.y + 11.0) * (over - flat) * 0.08)
	return v.lerp(pressed, wall)


func _sm(poly: PackedVector2Array) -> PackedVector2Array:
	if wall <= 0.001:
		return poly
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(poly.size())
	for i: int in range(poly.size()):
		out[i] = _smv(poly[i])
	return out


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
	# Squeezed against the wall: compressed toward the wall face, which stays put.
	if wall > 0.001:
		var anchor: Vector2 = Vector2(wall_side * WALL_X, 0.0)
		m = Transform2D(0.0, Vector2(1.0 - 0.16 * wall, 1.0 + 0.06 * wall), 0.0, anchor) * Transform2D(0.0, -anchor) * m
	var mh: Transform2D = m * Transform2D(hat_a + lean * 0.4, Vector2(fsc * 0.05, -21.3 + hy))
	var hem: Array[Vector2] = []
	var hem_lim: float = lerpf(20.0, WALL_X - 0.6, wall)
	for i: int in range(5):
		var hy_i: float = _soft(hem_y[i], 1.5) if hem_y[i] > 0.0 else _soft(hem_y[i], 5.5)
		var hx: float = HEMX[i] + _soft(hem_x[i], 6.0)
		hx = wall_side * minf(hx * wall_side, hem_lim)
		hem.append(Vector2(hx, minf(-0.6, -2.4 + hy_i)))
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
	# Palm flat on the wall: shoulder height when pushing, reaching up (alternating) when climbing.
	var plant: Vector2 = Vector2(wall_side * (WALL_X - 2.0), (-11.8 + bob * 0.5) if pg else (-15.2 + sin(climb_y * 0.3 + 1.6) * 1.6))
	hand = hand.lerp(plant, wall if f == wall_side else 0.0)
	var sleeve: PackedVector2Array = m * RisoShapes.smooth(PackedVector2Array([
		Vector2(fsc * 0.8, -14.4 + bob), Vector2(fsc * 4.2, -13.6 + bob), hand + Vector2(f * 1.9, -0.2),
		hand + Vector2(f * 0.9, 2.0), hand + Vector2(-f * 1.4, 1.7), Vector2(fsc * 1.6, -9.8 + bob)]))
	var collar: PackedVector2Array = m * RisoShapes.smooth(PackedVector2Array([
		Vector2(-4.9, -14.9 + bob), Vector2(-3.2, -17.6 + bob), Vector2(-0.8, -16.4 + bob), Vector2(0.8, -16.4 + bob),
		Vector2(3.2, -17.6 + bob), Vector2(4.9, -14.9 + bob), Vector2(0, -13.6 + bob)]))
	var face: PackedVector2Array = m * RisoShapes.ellipse(Vector2(fsc * 0.35, -18.5 + hy), 3.8 * (0.72 + 0.28 * af), 3.3, 22)
	var look: float = fsc * 0.25 * sp
	var gap: float = 1.45 * (0.8 + 0.2 * af)
	var eye_ry: float = (0.45 + 0.55 * af) * (1.0 - 0.45 * wall if pg else 1.0)
	var eye_c: Array[Vector2] = [Vector2(fsc * 0.9 + look - gap, -18.5 + hy), Vector2(fsc * 0.9 + look + gap, -18.5 + hy)]
	var ta: float = 1.1 * tanh(tip_a / 1.1)
	var d2: Vector2 = Vector2(sin(ta), -cos(ta))
	var pp: Vector2 = Vector2(cos(ta), sin(ta))
	var tip: Vector2 = Vector2(d2.x * 8.8, -7.4 + d2.y * 8.8)
	var cone: PackedVector2Array = mh * RisoShapes.smooth(PackedVector2Array([
		Vector2(-5.1, -0.25), Vector2(-3.1 + tip.x * 0.3, -7.3), tip - d2 * 1.6 - pp * 1.15, tip + d2 * 0.55,
		tip - d2 * 1.6 + pp * 1.15, Vector2(3.1 + tip.x * 0.3, -7.3), Vector2(5.1, -0.25), Vector2(0, 0.55)]))
	var brim: PackedVector2Array = mh * RisoShapes.ellipse(Vector2(-wall_side * 1.6 * wall, 0.0), 9.2 * (1.0 - 0.2 * wall), 1.8, 28)
	var band: PackedVector2Array = mh * RisoShapes.smooth(PackedVector2Array([Vector2(-5.4, -0.3), Vector2(0, -0.1), Vector2(5.4, -0.3), Vector2(4.6, -3.3), Vector2(0, -3.5), Vector2(-4.6, -3.3)]))
	var bead: Vector2 = _smv(mh * (tip - d2 * 0.6))
	var boots: Array[PackedVector2Array] = []
	for p: Vector2 in _feet():
		var boot: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([Vector2(-1.9, 0.1), Vector2(1.2, 0.1), Vector2(3.3, -0.1), Vector2(3.5, -1.2), Vector2(2.3, -2.0), Vector2(1.0, -2.2), Vector2(0.9, -4.6), Vector2(-1.6, -4.6), Vector2(-2.0, -1.6)]), 3)
		boots.append(_sm(m * (Transform2D(0.0, Vector2(f, 1), 0.0, p) * boot)))
	var robe_m: PackedVector2Array = _sm(m * robe)
	if wall > 0.001:
		face = _sm(face)
		sleeve = _sm(sleeve)
		collar = _sm(collar)
		cone = _sm(cone)
		brim = _sm(brim)
		band = _sm(band)
		for i: int in range(folds.size()):
			folds[i] = _sm(folds[i])
	body.begin()
	body.ink(RisoPrint.NIGHT, 1.0, boots, false)
	body.ink(RisoPrint.BLUE, 1.0, boots, false)
	body.knock(UNDER, [robe_m])
	body.ink(RisoPrint.ROBE, 1.0, [robe_m], false)
	body.ink(RisoPrint.NIGHT, 0.18, [_sm(m * back_shade)], false)
	body.ink(RisoPrint.NIGHT, 0.42, folds, false)
	body.ink(RisoPrint.NIGHT, 1.0, [face], false)
	body.ink(RisoPrint.BLUE, 1.0, [face], false)
	var eyes: Array[PackedVector2Array] = []
	for c: Vector2 in eye_c:
		eyes.append(_sm(m * (RisoShapes.ellipse(c, 1.0, 1.0 * eye_ry, 12) if not blink else RisoShapes.rrect(c.x - 1.0, c.y - 0.25, 2.0, 0.5, 0.25, 2))))
	if not blink:
		body.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.ROBE], eyes)
	body.ink(RisoPrint.EYE, 1.0, eyes, false)
	if not blink and eye_ry > 0.7:
		var cores: Array[PackedVector2Array] = []
		for c: Vector2 in eye_c:
			cores.append(_sm(m * RisoShapes.circle(c + Vector2(fsc * 0.25, -0.2), 0.4, 8)))
		body.knock([RisoPrint.EYE], cores)
	body.knock(UNDER, [collar])
	body.ink(RisoPrint.ROBE, 1.0, [collar], false)
	body.ink(RisoPrint.NIGHT, TRIM_SHADE, [collar], false)
	body.knock(UNDER, [sleeve])
	body.ink(RisoPrint.ROBE, 1.0, [sleeve], false)
	body.ink(RisoPrint.NIGHT, TRIM_SHADE, [sleeve], false)
	_focus(m, hand, f)
	body.knock(UNDER, [cone, brim])
	body.ink(RisoPrint.ROBE, 1.0, [cone, brim], false)
	body.ink(RisoPrint.NIGHT, TRIM_SHADE, [cone], false)
	body.ink(RisoPrint.ACCENT, 1.0, [band])
	var pulse: float = 1.0 + 0.08 * sin(t * 3.0)
	var ready: bool = not player.dash.acted
	if MapInfo.instance != null and MapInfo.instance.vulnerable:
		_cracked_bead(bead)
	else:
		_bead(bead, pulse, ready)
	if hurt:
		var pieces: Array[PackedVector2Array] = []
		pieces.append_array(boots)
		pieces.append_array([robe_m, collar, sleeve, face, cone, brim])
		for piece: PackedVector2Array in pieces:
			body.knock(ALL, [piece])
			body.ink(RisoPrint.PINK, 1.0, [piece], false)
		var whites: Array[PackedVector2Array] = []
		for c: Vector2 in eye_c:
			whites.append(_sm(m * RisoShapes.circle(c, 1.0, 10)))
		body.knock([RisoPrint.PINK], whites)
	body.finish()


## The hat's tip is the dash: lit with its halo while the dash is ready, dark (a dim bead, no
## halo) from the moment it is used until it comes back (landing, or a moon).
func _bead(bead: Vector2, pulse: float, ready: bool) -> void:
	if ready or flare_amount > 0.05:
		body.ink(RisoPrint.GLOW, 0.15, [RisoShapes.circle(bead, (4.6 + flare_amount * 7.0) * pulse, 24)])
		body.ink(RisoPrint.GLOW, 0.25, [RisoShapes.circle(bead, (3.2 + flare_amount * 4.0) * pulse, 20)])
		body.ink(RisoPrint.GLOW, 0.5, [RisoShapes.circle(bead, 2.2 + flare_amount * 1.5, 16)])
	body.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.ROBE], [RisoShapes.circle(bead, 1.35, 12)])
	body.ink(RisoPrint.GLOW, 1.0 if ready else 0.2, [RisoShapes.circle(bead, 1.35, 12)], false)
	if not ready:
		body.ink(RisoPrint.NIGHT, 0.45, [RisoShapes.circle(bead, 1.35, 12)], false)
	if ready:
		body.knock([RisoPrint.GLOW], [RisoShapes.circle(bead - Vector2(0.3, 0.3), 0.5 + flare_amount * 0.3, 8)])


## The spell's focus (chosen on the F7 panel: RisoPrint.spell_focus): what carries the spell's
## readiness, in accent ink, dim when spent and brightening as it recharges, and flares on a cast.
func _focus(m: Transform2D, hand: Vector2, f: float) -> void:
	var r: float = _spell_ready()
	if r < 0.0:
		return
	var kind: StringName = RisoPrint.instance.spell_focus if RisoPrint.instance != null else &"orb"
	match kind:
		&"orb":
			_orb(m, f, r)
		&"book":
			_book(m, hand, f, r)
		&"hand":
			_glowing_hand(m, hand, f, r)
		_:
			_wand(m, hand, f, r)


## A spark of spell light at `at` (canvas space): a halo while charged or flaring, a core whose
## ink grows with readiness `r` (night dims it while spent) and a paper-white heart once ready.
func _spell_light(at: Vector2, size: float, r: float, star: bool) -> void:
	var glow: float = r * r
	if glow > 0.05 or wand_flare_amount > 0.05:
		body.ink(RisoPrint.ACCENT, 0.15 * glow + 0.2 * wand_flare_amount, [RisoShapes.circle(at, size * 1.8 + wand_flare_amount * 5.0 + glow * 1.0, 20)], false)
	var core: PackedVector2Array = Transform2D(t * 1.5, at) * RisoShapes.sparkle(Vector2.ZERO, size * (0.7 + 0.3 * r) + wand_flare_amount * 1.2) if star \
		else RisoShapes.circle(at, size * (0.8 + 0.2 * r) + wand_flare_amount * 0.6, 16)
	body.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.BLUE, RisoPrint.GLOW, RisoPrint.ROBE], [core])
	body.ink(RisoPrint.ACCENT, lerpf(0.2, 1.0, r), [core], false)
	if r < 1.0:
		body.ink(RisoPrint.NIGHT, 0.5 * (1.0 - r), [core], false)
	else:
		body.knock([RisoPrint.ACCENT], [RisoShapes.circle(at + (Vector2.ZERO if star else Vector2(-0.35, -0.35) * size), 0.35 * maxf(1.0, size * 0.5), 8)])


## An orb of spell light floating at the shoulder away from the hand, bobbing; once ready a mote
## circles it.
func _orb(m: Transform2D, f: float, r: float) -> void:
	var at: Vector2 = m * Vector2(-f * 10.0, -17.5 + sin(t * 2.2) * 1.0)
	_spell_light(at, 2.8, r, false)
	if r >= 1.0:
		var a: float = t * 3.0
		body.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(at + Vector2(cos(a) * 4.8, sin(a) * 1.8), 0.7, 8)], false)


## A small dark tome held in the hand, its page edge bare paper and a rune of spell light on the
## cover; a cast lifts a rune off the page.
func _book(m: Transform2D, hand: Vector2, f: float, r: float) -> void:
	var c: Vector2 = hand + Vector2(f * 1.4, -1.0)
	var tilt: Transform2D = m * Transform2D(-f * 0.25, c)
	var cover: PackedVector2Array = tilt * RisoShapes.rrect(-2.0, -1.6, 4.0, 3.2, 0.5)
	var pages: PackedVector2Array = tilt * RisoShapes.rrect(-1.7, -2.2, 3.4, 0.8, 0.3)
	body.knock([RisoPrint.PINK, RisoPrint.GLOW, RisoPrint.ROBE], [cover])
	body.ink(RisoPrint.BLUE, 1.0, [cover], false)
	body.ink(RisoPrint.NIGHT, 0.7, [cover], false)
	body.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.GLOW, RisoPrint.ROBE], [pages])
	_spell_light(tilt * Vector2(0.0, 0.2), 1.1, r, true)
	if wand_flare_amount > 0.05:
		var rise: Vector2 = tilt * Vector2(0.0, -2.6) + Vector2(0, -(1.0 - wand_flare_amount) * 6.0)
		body.ink(RisoPrint.ACCENT, wand_flare_amount, [Transform2D(t * 4.0, rise) * RisoShapes.sparkle(Vector2.ZERO, 1.6)], false)


## No object: the palm itself glows, and motes gather round it one by one as the spell charges.
func _glowing_hand(m: Transform2D, hand: Vector2, f: float, r: float) -> void:
	var palm: Vector2 = m * (hand + Vector2(f * 0.9, 0.5))
	_spell_light(palm, 1.3, r, false)
	var motes: Array[PackedVector2Array] = []
	for i: int in range(3):
		if float(i) >= r * 3.0 - 0.001 and r < 1.0:
			continue
		var a: float = t * 2.4 + TAU * float(i) / 3.0
		motes.append(RisoShapes.circle(palm + Vector2(cos(a) * 3.6, sin(a) * 2.4), 0.8, 8))
	if not motes.is_empty():
		body.ink(RisoPrint.ACCENT, 1.0, motes, false)


## The spell's wand, held in the sleeve's hand and tipped with a spark of spell light (accent
## ink) whose brightness is the spell's readiness: dim when spent, brightening as it recharges,
## with a soft halo and a paper-white core once ready. Flares when a spell is cast.
func _wand(m: Transform2D, hand: Vector2, f: float, r: float) -> void:
	var a: Vector2 = hand + Vector2(f * 0.6, -0.4)
	var b: Vector2 = hand + Vector2(f * 4.4, -3.7)
	var n: Vector2 = (b - a).normalized().orthogonal()
	body.ink(RisoPrint.NIGHT, 1.0, [m * PackedVector2Array([a - n * 0.5, b - n * 0.32, b + n * 0.32, a + n * 0.5])], false)
	_spell_light(m * (b + (b - a).normalized() * 0.6), 2.6, r, true)


## Vulnerable: the hat's glow is out. The bead splits into two pink halves with a gap between
## them, and the glow only sputters back now and then.
func _cracked_bead(bead: Vector2) -> void:
	var sputter: float = maxf(0.0, sin(t * 5.3) * sin(t * 2.1 + 1.0))
	if sputter > 0.05:
		body.ink(RisoPrint.GLOW, 0.3 * sputter, [RisoShapes.circle(bead, 3.4, 20)])
	var halves: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var half_disc: PackedVector2Array = PackedVector2Array()
		for i: int in range(9):
			var a: float = side * PI * 0.5 + PI * float(i) / 8.0
			half_disc.append(Vector2(cos(a), sin(a)) * 1.6)
		var nudge: Vector2 = Vector2(-side * 0.45, -side * 0.2)
		halves.append(Transform2D(0.25, bead + nudge) * half_disc)
	body.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], halves)
	body.ink(RisoPrint.PINK, 1.0, halves, false)


func _draw_world() -> void:
	var s: float = player.global_scale.y * ART_SCALE
	world.begin()
	# Dash afterimages: silhouettes of the wizard left behind along the dash, printed in the hat's
	# glow ink (the ability's colour) and fading fast, newest strongest. Whole silhouettes read
	# the same in every direction, so there is no sideways/upward special case.
	for e: Vector4 in echoes:
		var at: Transform2D = Transform2D(0.0, Vector2(s, s), 0.0, Vector2(e.x, e.y))
		world.ink(RisoPrint.GLOW, ECHO_COVER * pow(e.w, 1.5), _silhouette(at, e.z))
	if not echoes.is_empty():
		# Not over the wizard: the glow would overprint the blue robe purple.
		world.knock([RisoPrint.GLOW], _silhouette(Transform2D(0.0, Vector2(s, s) * 1.08, 0.0, global_position), signf(fs)))
	# Astral projection: a glowing silhouette holds the return point; a short afterimage marks each start.
	var marks: Array[Vector4] = []
	marks.append_array(ghosts)
	var projection: Node = player.get_node_or_null("AstralProjection")
	if projection != null:
		var origin: Variant = projection.get("false_player_origin")
		if origin is Node2D and is_instance_valid(origin):
			var o: Node2D = origin as Node2D
			marks.append(Vector4(o.global_position.x, o.global_position.y + _feet_offset() * s, signf(fs), 1.0))
	if bool(player.get("levitating")):
		# Levitating: two slow rings of glow turning under the boots.
		var feet: Vector2 = global_position + Vector2(0, 4.0 * s)
		for k: int in range(2):
			var r: float = (9.0 + 4.0 * float(k) + sin(t * 4.0 + float(k)) * 1.2) * s
			var ring: PackedVector2Array = RisoShapes.ellipse(feet + Vector2(0, float(k) * 3.0 * s), r, r * 0.28, 24)
			world.ink(RisoPrint.GLOW, 0.5 - 0.2 * float(k), [ring])
	if player.has_meta(&"carried_key"):
		var bob: Vector2 = Vector2(0, sin(t * 3.0) * 3.0)
		for plate: int in RisoPrint.key_inks(int(player.get_meta(&"carried_key"))):
			world.ink(plate, 1.0, RisoProp.key_shape(key_pos + bob, 1.0))
	for g: Vector4 in marks:
		var at: Transform2D = Transform2D(0.0, Vector2(s, s), 0.0, Vector2(g.x, g.y - (1.0 - g.w) * 6.0 * s))
		world.ink(RisoPrint.GLOW, 0.25 if g.w > 0.5 else 0.15, _silhouette(at, g.z))
	world.finish()


## The wizard's outline (robe and hat, the tip bent toward `facing`), feet at the origin of `at`.
func _silhouette(at: Transform2D, facing: float) -> Array[PackedVector2Array]:
	return [
		at * RisoShapes.smooth(PackedVector2Array([Vector2(-3.8, -15), Vector2(-6.6, -7), Vector2(-9, -2.2), Vector2(9, -2.2), Vector2(6.6, -7), Vector2(3.8, -15)])),
		at * RisoShapes.smooth(PackedVector2Array([Vector2(-5, -21.4), Vector2(-2.9, -28.4), Vector2(-facing * 4.6, -37), Vector2(2.9, -28.4), Vector2(5, -21.4)])),
	]
