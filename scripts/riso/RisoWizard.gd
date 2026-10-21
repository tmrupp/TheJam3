extends Node2D
class_name RisoWizard
## The player, printed in ink as the Fool (RisoCostume draws them). A small spring rig drives them
## from the real Player: planted feet, a cloth hem that swings and billows, a springy hat, body bob
## with a lagging head, eased turns, breathing and blinks; and it leaves the dash's afterimages,
## the lantern's smoke and the parry's guard. Art units match the HTML prototype (the Player's
## scale of 4 turns them into world pixels). Presentation only; collision is untouched.

const STRIDE: float = 22.0
## How high the wizard lifts a foot mid-step; a traveler may walk differently (`RisoCostume.gait`).
const STEP_LIFT: float = 1.9
const MAXV: float = 88.0
const VX_SCALE: float = 88.0 / 300.0
const VY_SCALE: float = 0.5
const ALL: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
## Art scale around the feet: at 0.8 the robe fits the ~62 px collider. Collision is unchanged.
const ART_SCALE: float = 0.8

var player: Player
var body: InkCanvas
var world: InkCanvas
## The parry guard, printed over the figure (see _draw_guard).
var guard: InkCanvas
## The other printed travelers use this same body canvas and spring rig.
var costume: RisoCostume
## Positions, age and curl of the smoke left by the lantern: pink while unprotected, and pale for a
## little while after it is snuffed at a font (MapInfo.flame_snuffed).
var lantern_smoke: Array[Vector4] = []
## Smoke thins away in this many seconds and leaves a new point at this interval.
const SMOKE_LIFE: float = 1.4
const SMOKE_STEP: float = 0.06
## The smoke's rise and width in the player's art units.
const SMOKE_RISE: float = 19.0
const SMOKE_WIDTH: float = 0.85
## Smoke drifts sideways away from the traveler, wherever they stand, about this far over its life
## (art units). "Away" is judged from a point a little in front of the figure, so a centred chest
## flame's smoke drifts back past the helmet, and from within this distance it eases off.
const SMOKE_DRIFT: float = 24.0
const SMOKE_AHEAD: float = 2.0
const SMOKE_EASE: float = 4.0
## A snuffed wick smokes for this long (s), thinning away, in pale smoke lifted to paper at this
## cover (against the pink smoke's).
const SNUFF_SMOKE: float = 2.6
const SNUFF_SMOKE_LIFT: float = 0.5
## How long the lantern has been snuffed (s), for the pale smoke.
var _snuffed_for: float = 0.0
## Time until the next smoke point, and its deterministic curl phase.
var _smoke_wait: float = 0.0
var _smoke_phase: float = 0.0

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
## The body bows above the waist like cloth on a frame, never squashing: positive bows toward the
## way the wizard faces (landing throws it forward, taking off back), the more the higher up, so
## the hat whips furthest (see _bowv). A spring settles it.
var bow: float = 0.0
var bow_v: float = 0.0
## Where the bow bends from, in art units (feet at 0, up is negative).
const WAIST: float = -7.0
## Gone into a portal and not yet out of the far one: the wizard is not printed.
var vanished: bool = false
var hem_x: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
var hem_y: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
var hem_vx: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
var hem_vy: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
## Dash afterimages: x, y = feet (world), z = facing, w = life 1..0. One is left each time the
## dash has carried the wizard ECHO_GAP art units on from the last.
var echoes: Array[Vector4] = []
const ECHO_GAP: float = 12.0
const ECHO_LIFE: float = 0.3
const ECHO_COVER: float = 0.55
## Where this dash left its last afterimage (INF between dashes).
var _echo_at: Vector2 = Vector2.INF
var ghosts: Array[Vector4] = []  # x, y, facing, life 0..1
## The carried keys trailing the wizard (see _trail_keys): their colours, newest first, then any
## skeleton keys, and where each is now (empty after a teleport: they start over at the shoulder).
var key_colors: Array[int] = []
var key_trail: Array[Vector2] = []
## How far each key hangs behind the one before it (world pixels, before facing).
const KEY_LINK: Vector2 = Vector2(-30, 8)
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
	body.rig()
	body.keeps_shapes = true
	# Printed in its own inks over an indoor realm's back wall (InkCanvas.punches_wall).
	body.punches_wall = true
	add_child(body)
	guard = InkCanvas.new()
	guard.z_index = 1
	add_child(guard)
	world = InkCanvas.new()
	world.top_level = true
	world.z_index = 9
	world.z_as_relative = false
	add_child(world)
	costume = RisoCostume.new(self)
	if player != null:
		player.visual_event.connect(_on_event)


func _feet_offset() -> float:
	var shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D if player != null else null
	if shape != null and shape.shape is RectangleShape2D:
		return shape.position.y + (shape.shape as RectangleShape2D).size.y * shape.scale.y * 0.5
	return 7.75


## The way a damage spell just cast went, for the bindle to point: a nova's burst straight up over
## the head, a lunge's along its thrust, the rest the way the wizard aims (SpellStrike.aim).
func _cast_way() -> Vector2:
	match Abilities.spell(player):
		&"nova":
			return Vector2.UP
		&"lunge":
			var lunge: Lunge = player.get_node_or_null("Lunge") as Lunge
			return Vector2(lunge.side if lunge != null else signf(fs), 0.0)
	return SpellStrike.aim(player)


func _on_event(kind: StringName, at: Vector2) -> void:
	if kind == &"jump":
		# Thrown back as the jump lifts the wizard, the hat tip trailing down.
		bow_v -= 3.2
		tip_v -= signf(fs) * 1.5
	elif kind == &"cast":
		costume.cast(_cast_way())
	elif kind == &"projection_start":
		ghosts.append(Vector4(at.x, at.y, signf(fs), 1.0))
	elif kind == &"teleport":
		lantern_smoke.clear()
		# Out of the portal: the robe and hat catch the air like cloth flicked out, and settle.
		bow_v += 3.5
		tip_v += signf(fs) * 4.0
		for i: int in range(hem_vy.size()):
			hem_vy[i] -= 26.0 + 6.0 * absf(float(i - 2))
			hem_vx[i] += float(i - 2) * 9.0
		key_trail.clear()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var dashing: bool = player.dash.is_acting()
	_rig(delta, dashing)
	costume.step(delta)
	_step_smoke(delta)
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
	_trail_keys(delta)


## Every key carried trails the wizard on a soft lag: the newest just behind and above the
## shoulder, each older one hanging behind the one before it (a chain), skeleton keys last.
func _trail_keys(delta: float) -> void:
	var colors: Array[int] = player.keyring.all()
	colors.reverse()
	for i: int in range(player.keyring.skeletons()):
		colors.append(KeyRing.SKELETON)
	if colors != key_colors:
		key_colors = colors
		key_trail.resize(mini(key_trail.size(), colors.size()))
	var s: float = player.global_scale.y * ART_SCALE
	var target: Vector2 = global_position + Vector2(-signf(fs) * 11.0, -24.0) * s
	var link: Vector2 = Vector2(KEY_LINK.x * signf(fs), KEY_LINK.y)
	for i: int in range(colors.size()):
		if i >= key_trail.size():
			key_trail.append(target)
		# Each follows the one before it a little more loosely.
		key_trail[i] = key_trail[i].lerp(target, minf(1.0, delta * (8.0 - 1.5 * float(mini(i, 3)))))
		target = key_trail[i] + link


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
		# The weight carries on: the body bows forward over its feet and springs back.
		bow_v += clampf(pvy * 0.012, 0.0, 9.0)
	fs += (face - fs) * minf(1.0, dt * 16.0)
	sp += ((clampf(absf(vx) / MAXV, 0.0, 1.0) if ground else 0.0) - sp) * minf(1.0, dt * 10.0)
	if ground:
		dist += absf(vx) * dt
	var ph: float = fposmod(dist / costume.gait().x, 1.0)
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
	# The bow springs back to upright (a little back while rising, a little forward while falling,
	# as the air pushes on the cloth).
	var bow_t: float = 0.0 if ground else clampf(vy / 900.0, -0.08, 0.08)
	bow_v += ((bow_t - bow) * 170.0 - bow_v * 12.0) * dt
	bow = clampf(bow + bow_v * dt, -0.5, 0.5)
	pvx = vx
	pvy = vy
	pg = ground


func _feet() -> Array[Vector2]:
	var gait: Vector3 = costume.gait()
	var ph: float = fposmod(dist / gait.x, 1.0)
	var a: float = gait.x / 4.0
	var face: float = signf(fs) if fs != 0.0 else 1.0
	var dir: float = signf(player.velocity.x) if absf(player.velocity.x) > 1.0 else face
	var out: Array[Vector2] = []
	for k: int in range(2):
		var rest: float = (1.9 if k == 1 else -1.9) * gait.z
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
			y = -sin(PI * u) * gait.y
		out.append(Vector2(lerpf(rest, x * dir + (0.8 if k == 1 else -0.8) * gait.z, sp), y * sp))
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


## The bow (see `bow`): a point above the waist turns about it, the more the higher it is, so the
## body curves like cloth over a frame rather than tilting stiffly; below the waist, nothing moves.
func _bowv(v: Vector2) -> Vector2:
	var u: float = clampf((WAIST - v.y) / 18.0, 0.0, 1.5)
	var amount: float = bow * (costume.bow_scale() if costume != null else 1.0)
	if u <= 0.0 or absf(amount) < 0.0005:
		return v
	var pivot: Vector2 = Vector2(0.0, WAIST)
	return pivot + (v - pivot).rotated(amount * (1.0 if fs >= 0.0 else -1.0) * u * u)


## The body bowed, then against the wall: cloth past a knee near the wall face lies flat on it (it
## never passes through, and is never squeezed out of shape).
func _smv(v: Vector2) -> Vector2:
	v = _bowv(v)
	if wall <= 0.001:
		return v
	var knee: float = WALL_X - 3.5
	var s: float = v.x * wall_side
	if s <= knee:
		return v
	var over: float = s - knee
	var flat: float = 3.5 * tanh(over / 3.5)
	return v.lerp(Vector2(wall_side * (knee + flat), v.y), wall)


## `poly` bowed and laid against the wall (_smv), point by point. Bowed alone (most of the time it
## is anything), the bow is worked out here in one loop rather than a call or two a point: the
## figure holds over a thousand points.
func _sm(poly: PackedVector2Array) -> PackedVector2Array:
	var amount: float = bow * (costume.bow_scale() if costume != null else 1.0)
	if wall <= 0.001 and absf(amount) < 0.0005:
		return poly
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(poly.size())
	if wall > 0.001:
		for i: int in range(poly.size()):
			out[i] = _smv(poly[i])
		return out
	var turn: float = amount * (1.0 if fs >= 0.0 else -1.0)
	for i: int in range(poly.size()):
		var v: Vector2 = poly[i]
		var u: float = clampf((WAIST - v.y) / 18.0, 0.0, 1.5)
		out[i] = v if u <= 0.0 else Vector2(0.0, WAIST) + (v - Vector2(0.0, WAIST)).rotated(turn * u * u)
	return out


func _process(_delta: float) -> void:
	if player == null or not visible:
		return
	# Mid-way through a portal (see RisoPortalWarp): nothing of the wizard is printed.
	if vanished:
		body.begin()
		body.finish()
		world.begin()
		world.finish()
		guard.begin()
		guard.finish()
		return
	_draw_body()
	_draw_world()
	_draw_guard()


func _draw_body() -> void:
	costume.draw()


## The part of a circle of radius `rad` round `c` below a level `frac` of its height up from the
## bottom (a vial filled to `frac`), or an empty array.
func _filled(c: Vector2, rad: float, frac: float) -> PackedVector2Array:
	if frac <= 0.02:
		return PackedVector2Array()
	var level: float = c.y + rad - 2.0 * rad * clampf(frac, 0.0, 1.0)
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(24):
		var a: float = TAU * float(i) / 24.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * rad
		out.append(Vector2(p.x, maxf(p.y, level)))
	return out


## A band `w` thick on a circle of radius `rad` round `c`, from the top clockwise over `frac` of it.
func _arc(c: Vector2, rad: float, w: float, frac: float) -> PackedVector2Array:
	var n: int = maxi(2, int(ceil(28.0 * frac)))
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	for i: int in range(n + 1):
		var a: float = -PI * 0.5 + TAU * frac * float(i) / float(n)
		var d: Vector2 = Vector2(cos(a), sin(a))
		outer.append(c + d * (rad + w))
		inner.append(c + d * (rad - w))
	inner.reverse()
	outer.append_array(inner)
	return outer


func _draw_world() -> void:
	var s: float = player.global_scale.y * ART_SCALE
	world.begin()
	_draw_smoke(s)
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
	var projection: AstralProjection = player.get_node_or_null("AstralProjection") as AstralProjection
	if projection != null:
		var o: Node2D = projection.false_player_origin
		if o != null and is_instance_valid(o):
			marks.append(Vector4(o.global_position.x, o.global_position.y + _feet_offset() * s, signf(fs), 1.0))
	if player.levitating:
		# Levitating: two slow rings of glow turning under the boots.
		var feet: Vector2 = global_position + Vector2(0, 4.0 * s)
		for k: int in range(2):
			var r: float = (9.0 + 4.0 * float(k) + sin(t * 4.0 + float(k)) * 1.2) * s
			var ring: PackedVector2Array = RisoShapes.ellipse(feet + Vector2(0, float(k) * 3.0 * s), r, r * 0.28, 24)
			world.ink(RisoPrint.GLOW, 0.5 - 0.2 * float(k), [ring])
	for i: int in range(mini(key_colors.size(), key_trail.size())):
		var bob: Vector2 = Vector2(0, sin(t * 3.0 - float(i) * 0.7) * 3.0)
		RisoPrint.ink_key(world, key_colors[i], 1.0, RisoMarks.key_shape(key_trail[i] + bob, 1.0, key_colors[i]))
	for g: Vector4 in marks:
		var at: Transform2D = Transform2D(0.0, Vector2(s, s), 0.0, Vector2(g.x, g.y - (1.0 - g.w) * 6.0 * s))
		world.ink(RisoPrint.GLOW, 0.25 if g.w > 0.5 else 0.15, _silhouette(at, g.z))
	# The ward perk's ring of plates (Ward), round the wizard.
	var ward: Ward = player.get_node_or_null("Ward") as Ward
	if ward != null and not player.phasing:
		ward.print_ring(world, player.global_position + Ward.CENTER)
	world.finish()


## The parry guard over the figure (art units): its middle, how far out the gleam reaches, and
## the gleam band's width.
const GUARD_AT: Vector2 = Vector2(0, -16)
const GUARD_R: float = 21.0
const GLEAM_W: float = 2.6


## Parry (see Parry), in front of the figure and the same all round, as it guards every side: a
## thin bright band of gleam (in a softer, wider one) sweeping across the figure once over the
## window, as light runs over polished metal, with no bubble or ring round it. (A catch bursts in
## RisoFx and shimmers the figure gold.)
func _draw_guard() -> void:
	guard.begin()
	var parry: Parry = player.get_node_or_null("Parry") as Parry
	if parry == null or player.phasing:
		guard.finish()
		return
	var c: Vector2 = GUARD_AT + Vector2(0, bob)
	var left: float = parry.guard_left()
	if left >= 0.0:
		var pop: float = clampf((parry.clock - parry.raised_at) / 0.06, 0.0, 1.0)
		var r: float = GUARD_R * (1.3 - 0.3 * pop) * (0.9 + 0.1 * left)
		var x: float = lerpf(-r * 1.4, r * 1.4, 1.0 - left)
		var disc: PackedVector2Array = RisoShapes.circle(c, r, 32)
		for k: int in range(2):
			var w: float = GLEAM_W * (3.0 if k == 0 else 1.0)
			var band: PackedVector2Array = PackedVector2Array([
				c + Vector2(x - w - r * 0.5, r * 1.2), c + Vector2(x + w - r * 0.5, r * 1.2),
				c + Vector2(x + w + r * 0.5, -r * 1.2), c + Vector2(x - w + r * 0.5, -r * 1.2)])
			var gleam: Array[PackedVector2Array] = Geometry2D.intersect_polygons(band, disc)
			if k == 1:
				guard.knock(RisoPrint.ALL_PLATES, gleam)
			guard.ink(RisoPrint.EYE, 0.35 if k == 0 else 0.8, gleam, false)
	guard.finish()


## Whether the figure's flash is a parry's gold shimmer rather than the hurt pink.
func parry_glory() -> bool:
	var parry: Parry = player.get_node_or_null("Parry") as Parry
	return parry != null and parry.glory()


## The Fool's outline (RisoCostume.silhouette), feet at the origin of `at`.
func _silhouette(at: Transform2D, facing: float) -> Array[PackedVector2Array]:
	return RisoCostume.silhouette(at, facing, Abilities.spell(player), costume)


## Leave smoke at the lantern's past positions, drifting away from the traveler, without drawing
## from the world's RNG.
func _step_smoke(delta: float) -> void:
	# A level change or a respawn moves the traveler far in one step: the old trail would be
	# strung across the screen to the new place, so it goes and starts afresh on arrival.
	if MapInfo.instance != null and MapInfo.instance.travelling:
		lantern_smoke.clear()
		_smoke_wait = 0.0
		return
	var s: float = player.global_scale.y * ART_SCALE if player != null else ART_SCALE
	var from: float = global_position.x + signf(fs if fs != 0.0 else 1.0) * SMOKE_AHEAD * s
	for i: int in range(lantern_smoke.size() - 1, -1, -1):
		lantern_smoke[i].z += delta
		if lantern_smoke[i].z >= SMOKE_LIFE:
			lantern_smoke.remove_at(i)
			continue
		var away: float = tanh((lantern_smoke[i].x - from) / (SMOKE_EASE * s))
		lantern_smoke[i].x += away * SMOKE_DRIFT / SMOKE_LIFE * delta * s
	var snuffed: bool = MapInfo.instance != null and MapInfo.instance.flame_snuffed()
	_snuffed_for = _snuffed_for + delta if snuffed else 0.0
	if vanished or MapInfo.instance == null or MapInfo.instance.flame_lit() or (snuffed and _snuffed_for > SNUFF_SMOKE):
		_smoke_wait = 0.0
		return
	_smoke_wait -= delta
	if _smoke_wait <= 0.0:
		_smoke_wait = SMOKE_STEP
		_smoke_phase += 0.7
		var at: Vector2 = to_global(costume.lantern_position())
		lantern_smoke.append(Vector4(at.x, at.y, 0.0, _smoke_phase))


## A tapered strand curls upward from the unlit lantern and trails where it has moved: pink while
## unprotected, pale and thinning away once snuffed.
func _draw_smoke(s: float) -> void:
	if lantern_smoke.size() < 2:
		return
	var snuffed: bool = MapInfo.instance != null and MapInfo.instance.flame_snuffed()
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var covers: PackedFloat32Array = PackedFloat32Array()
	for point: Vector4 in lantern_smoke:
		var age: float = point.z / SMOKE_LIFE
		var at: Vector2 = Vector2(point.x, point.y) + Vector2(sin(point.w + t * 1.3) * age * 2.0, -point.z * SMOKE_RISE) * s
		var width: float = SMOKE_WIDTH * (1.0 - age * 0.75) * s
		left.append(at - Vector2(width, 0))
		right.append(at + Vector2(width, 0))
		covers.append(0.65 * pow(1.0 - age, 1.5) * (AstralProjection.PROJECTION_COVER if player.phasing else 1.0))
	right.reverse()
	left.append_array(right)
	var back: PackedFloat32Array = covers.duplicate()
	back.reverse()
	covers.append_array(back)
	if snuffed:
		for i: int in range(covers.size()):
			covers[i] *= SNUFF_SMOKE_LIFT
		world.lift_ink_graded([RisoPrint.NIGHT, RisoPrint.BLUE], [left], [covers])
	else:
		world.ink_graded(RisoPrint.PINK, [left], [covers])
