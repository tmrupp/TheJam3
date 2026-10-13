class_name Necromancer
extends Node2D
## The necromancer (Bosses.DOWN's first): the boss at the bottom of the cemetery, fought in the
## first crypt of its gate level (Crypts, LevelGen.place_boss), dark inside (docs/REGIONS_PLAN.md
## §6). It stands among its graves (the crypt's floors) until the wizard comes into the crypt or
## within WAKE_RANGE; then:
## - It raises skeletons (Skeleton.raise), the same as sleep in every crypt, out of the grave
##   nearest the wizard (not right under them), every RAISE_EVERY seconds while fewer than
##   RAISE_MOST of its own walk. A blow or a stun knocks a skeleton to pieces for a while, as any
##   (it cannot be killed).
## - It blinks between its graves every BLINK_EVERY seconds, and at once when wounded: to the grave
##   deepest in the dark (furthest from every light, Lamplight), fading out and in (BLINK_TIME).
## - It cannot be wounded in the dark: only while light falls on it (Lamplight: the wizard's lit
##   flame, a lantern's light) does a strike land (NecromancerWound); in the dark a strike passes
##   through it like smoke. So the fight wants the flame lit, and close.
## - Its touch hurts (its HitBox), and a parry stuns it a moment (it raises and blinks nothing while
##   stunned).
## - Its health is the candles on its staff (CANDLES): each wound puts one out. With the last it
##   crumbles to dust (DIE_TIME), its skeletons with it, it is slain, and its relic waits where it
##   stood (MapInfo.boss_slain).
## A lantern death brings it back whole, as the crypt reloads. Nothing here draws from any RNG.

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
const SKELETON: String = "res://prefabs/skeleton_enemy.tscn"
## Its candles, the wounds it takes.
const CANDLES: int = 7
## How near (px) the wizard comes to wake it, if not inside its crypt.
const WAKE_RANGE: float = 520.0
## Seconds between raisings (shorter on a harder preset, Difficulty.haste), and the most of its own
## skeletons walking at once.
const RAISE_EVERY: float = 4.0
const RAISE_MOST: int = 3
## A skeleton is raised at least RAISE_APART cells from the wizard.
const RAISE_APART: int = 3
## Seconds between blinks (shorter on a harder preset), and how long a blink takes, out and in.
const BLINK_EVERY: float = 6.0
const BLINK_TIME: float = 0.6
## How long its crumbling takes (s).
const DIE_TIME: float = 1.4
## How big it is drawn, against the sizes its shapes are drawn at (TALL of these high).
const ART: float = 1.6
const TALL: float = 104.0
## Its body (px), for what a strike or its touch meets: round its middle, BODY_R px.
const BODY_R: float = 26.0 * ART
## Where light is looked for on it (px over its feet): its chest.
const LIGHT_RISE: float = 56.0 * ART

var map_info: MapInfo
## Which boss it is (Bosses).
var boss: StringName = &""
var wound: NecromancerWound
var stunner: Stunner
var touch: HitBox
var ink: InkCanvas
## Its eyes and candle flames, printed over the darkness (RisoLight.SHADE_Z), so in the dark they
## are all of it that shows.
var glow_ink: InkCanvas
## Its graves: the floors of its crypt (cells), and the crypt's box.
var graves: Array[Vector2i] = []
var box: Rect2i = Rect2i()
## Fighting (woken), and the clocks to its next raising and blink.
var awake: bool = false
var raise_in: float = RAISE_EVERY
var blink_in: float = BLINK_EVERY
## Blinking: seconds into it (-1 while not), and the grave it goes to.
var blinking: float = -1.0
var blink_to: Vector2i = Vector2i(-1, -1)
## Its skeletons, raised and walking.
var raised: Array[Node2D] = []
## Seconds since a strike passed through it in the dark (the art shimmers), and since a wound.
var glanced: float = 9.0
var hurt: float = 9.0
## Dying: seconds into it (-1 while not); slain once crumbled.
var dying_t: float = -1.0
var slain: bool = false
var facing: float = -1.0
var t: float = 0.0


func _init() -> void:
	wound = NecromancerWound.new()
	wound.name = "Wound"
	wound.hp = CANDLES
	add_child(wound)
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	add_child(stunner)
	touch = HIT_BOX.instantiate() as HitBox
	touch.name = "HitBox"
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = BODY_R
	(touch.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	touch.position = Vector2(0, -TALL * ART * 0.45)
	(touch.get_node("Damager") as Damager).attacker = self
	add_child(touch)
	add_to_group(&"hex_target")


func _ready() -> void:
	z_index = 2
	ink = InkCanvas.new()
	glow_ink = InkCanvas.new()
	glow_ink.z_index = RisoLight.SHADE_Z + 1
	glow_ink.z_as_relative = false
	add_child(glow_ink)
	add_child(ink)
	add_to_group(&"riso_art")


func setup(info: MapInfo, v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	# It goes all over its crypt: never put to sleep with the chunk its cell is in.
	remove_meta(&"cell")
	global_position = _feet(v)
	if info.world == null or info.world.crypts.is_empty():
		graves = [v]
		return
	var crypt: Dictionary = info.world.crypts[0]
	box = crypt["box"]
	for g: Vector2i in crypt["floors"]:
		graves.append(g)
	if graves.is_empty():
		graves = [v]


## Where it stands on grave `v`: its feet on the floor.
func _feet(v: Vector2i) -> Vector2:
	if map_info == null:
		return global_position
	var half: float = float(map_info.tile_map.tile_set.tile_size.y) * map_info.tile_map.global_scale.y * 0.5
	return map_info.cell_position(v) + Vector2(0, half)


## Whether light falls on it now: then, and only then, a strike wounds it.
func lit() -> bool:
	return Lamplight.at(global_position + Vector2(0, -LIGHT_RISE))


func dying() -> bool:
	return dying_t >= 0.0 or slain


## A strike passed through it in the dark.
func glance(dir: Vector2) -> void:
	glanced = 0.0
	RisoFx.burst(&"hit", global_position + Vector2(0, -LIGHT_RISE), dir, [RisoPrint.BLUE, RisoPrint.NIGHT])


## A strike landed: a candle goes out, and it blinks away into the dark.
func wounded(dir: Vector2) -> void:
	hurt = 0.0
	RisoFx.burst(&"hit", global_position + Vector2(0, -LIGHT_RISE), dir, [RisoPrint.PINK, RisoPrint.GLOW])
	Wound.shake(9.0, 0.18)
	if wound.hp > 0:
		_blink()


## Its last candle is out: it crumbles, and its skeletons with it.
func die() -> void:
	if dying():
		return
	dying_t = 0.0
	remove_from_group(&"hex_target")
	(touch.get_node("CollisionShape2D") as CollisionShape2D).set_deferred("disabled", true)
	_unraise()
	Wound.shake(14.0, 0.4)
	RisoFx.burst(&"gain", global_position + Vector2(0, -LIGHT_RISE), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])


## Slain at once (the F7 panel's Slay boss, MapInfo.slay_boss).
func slay() -> void:
	if slain:
		return
	wound.hp = 0
	_slain()


## Its skeletons fall back into their graves.
func _unraise() -> void:
	for skeleton: Variant in raised:
		if is_instance_valid(skeleton) and not (skeleton as Node2D).is_queued_for_deletion():
			(skeleton as Node2D).queue_free()
	raised.clear()


func _slain() -> void:
	slain = true
	_unraise()
	if map_info != null:
		map_info.boss_slain(boss, map_info.cell_position(map_info.cell_at(global_position + Vector2(0, -8))))
	queue_free()


func _physics_process(delta: float) -> void:
	t += delta
	glanced += delta
	hurt += delta
	if slain:
		return
	if dying_t >= 0.0:
		dying_t += delta
		if dying_t >= DIE_TIME:
			_slain()
		return
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player) or map_info == null:
		return
	var walking: Array[Node2D] = []
	for skeleton: Variant in raised:
		if is_instance_valid(skeleton) and not (skeleton as Node2D).is_queued_for_deletion():
			walking.append(skeleton as Node2D)
	raised = walking
	if absf(player.global_position.x - global_position.x) > 8.0:
		facing = signf(player.global_position.x - global_position.x)
	if not awake:
		awake = box.has_point(map_info.cell_at(player.global_position)) or player.global_position.distance_to(global_position) <= WAKE_RANGE
		if not awake:
			return
	if blinking >= 0.0:
		blinking += delta
		if blinking >= BLINK_TIME * 0.5 and blink_to != Vector2i(-1, -1):
			global_position = _feet(blink_to)
			blink_to = Vector2i(-1, -1)
		if blinking >= BLINK_TIME:
			blinking = -1.0
		return
	if stunner.stunned():
		return
	var haste: float = Difficulty.haste()
	raise_in -= delta * haste
	blink_in -= delta * haste
	if raise_in <= 0.0:
		raise_in = RAISE_EVERY
		if raised.size() < RAISE_MOST:
			_raise(player)
	if blink_in <= 0.0:
		_blink()


## Raise a skeleton out of the grave nearest the wizard, at least RAISE_APART cells from them.
func _raise(player: Player) -> void:
	var at: Vector2i = map_info.cell_at(player.global_position)
	var spot: Variant = null
	var best: int = 1 << 30
	for g: Vector2i in graves:
		var d: int = LevelGen.dist(g, at)
		if d >= RAISE_APART and d < best and map_info.cell_at(global_position + Vector2(0, -8)) != g:
			best = d
			spot = g
	if spot == null:
		return
	var skeleton: Node2D = (load(SKELETON) as PackedScene).instantiate() as Node2D
	LevelLoader.arm(skeleton, map_info.here.depth if map_info.here != null else 0)
	(skeleton.get_node("Wound") as Wound).stars = false
	(skeleton.get_node("Skeleton") as Skeleton).raise()
	map_info.map_elements.add_child(skeleton)
	skeleton.global_position = map_info.cell_position(spot)
	raised.append(skeleton)
	RisoFx.burst(&"gain", map_info.cell_position(spot) + Vector2(0, 24), Vector2.UP, [RisoPrint.NIGHT, RisoPrint.PINK])


## Blink to the grave deepest in the dark: the furthest from every light (Lamplight.lights, the
## wizard's flame among them), not where it stands.
func _blink() -> void:
	blink_in = BLINK_EVERY
	var here: Vector2i = map_info.cell_at(global_position + Vector2(0, -8))
	var lights: Array[Vector3] = Lamplight.lights(map_info)
	var best: Variant = null
	var best_d: float = -1.0
	for g: Vector2i in graves:
		if g == here:
			continue
		var p: Vector2 = map_info.cell_position(g)
		var d: float = 1e9
		for light: Vector3 in lights:
			d = minf(d, p.distance_to(Vector2(light.x, light.y)) - light.z)
		if d > best_d:
			best_d = d
			best = g
	if best == null:
		return
	blink_to = best
	blinking = 0.0
	RisoFx.burst(&"hit", global_position + Vector2(0, -LIGHT_RISE), Vector2.ZERO, [RisoPrint.NIGHT, RisoPrint.BLUE])


# ------------------------------------------------------------------ how it looks

## A tall hooded figure, its face a dark hollow with two pale points, holding a staff crowned with
## its candles, pink flames on those still lit. In the dark it is half there, a shadow (a strike
## passing through it shimmers it), all that shows of it its eyes and its candles' flames; in
## light it stands out of the dark in a pale robe. It fades out and in as it blinks, and crumbles
## to dust as it dies.
func _process(_delta: float) -> void:
	if ink == null:
		return
	ink.begin()
	glow_ink.begin()
	var shown: float = 1.0
	if blinking >= 0.0:
		shown = absf(blinking / (BLINK_TIME * 0.5) - 1.0)
	if dying_t >= 0.0:
		shown = maxf(0.0, 1.0 - dying_t / DIE_TIME)
	var in_light: bool = lit()
	var solid: float = (1.0 if in_light else 0.45 + 0.1 * sin(t * 6.0)) * shown
	if glanced < 0.4:
		solid *= 0.5 + 0.5 * glanced / 0.4
	var xf: Transform2D = Transform2D(0.0, Vector2(facing, 1.0) * ART, 0.0, Vector2.ZERO)
	var sway: float = sin(t * 1.6) * 3.0
	var robe: PackedVector2Array = xf * RisoShapes.smooth(PackedVector2Array([
		Vector2(-6, -TALL), Vector2(8, -TALL + 2), Vector2(16, -TALL + 22), Vector2(20, -50),
		Vector2(28 + sway, -4), Vector2(18, 0), Vector2(-18, 0), Vector2(-26 + sway, -6), Vector2(-20, -52), Vector2(-15, -TALL + 22)]), 2)
	if solid > 0.0:
		if in_light:
			# Caught in the light: a pale robe, lifted out of the dark round it.
			ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.85 * solid, [robe])
			ink.ink(RisoPrint.BLUE, 0.35 * solid, [robe], false)
			# A dark fold down its front.
			ink.ink(RisoPrint.NIGHT, 0.5 * solid, [xf * RisoShapes.rrect(-4.0, -TALL + 30.0, 4.0, TALL - 34.0, 2.0)], false)
		else:
			# In the dark, a shadow.
			ink.ink(RisoPrint.NIGHT, 0.85 * solid, [robe], false)
			ink.ink(RisoPrint.BLUE, 0.3 * solid, [robe], false)
		# The hood's hollow and its two pale points.
		var face: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(4, -TALL + 18), 7.0, 9.0, 16)
		ink.ink(RisoPrint.NIGHT, solid, [face], false)
		var eyes: Array[PackedVector2Array] = []
		for e: Vector2 in [Vector2(2, -TALL + 17), Vector2(8, -TALL + 17)]:
			eyes.append(xf * RisoShapes.circle(e, 1.6, 8))
		glow_ink.ink(RisoPrint.PINK, 0.7 * shown, eyes)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], solid, eyes)
		# The staff, held forward, and its candles.
		var staff: PackedVector2Array = xf * RisoShapes.rrect(22.0, -TALL - 12.0, 4.0, TALL + 12.0, 2.0)
		var crown: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(24, -TALL - 10), 14.0, 4.0, 16)
		ink.ink(RisoPrint.NIGHT, solid, [staff, crown], false)
		var flames: Array[PackedVector2Array] = []
		var wax: Array[PackedVector2Array] = []
		var left: int = wound.hp if wound != null else 0
		for i: int in range(CANDLES):
			var a: float = (float(i) - float(CANDLES - 1) * 0.5) * 0.36
			var base: Vector2 = Vector2(24, -TALL - 8) + Vector2(sin(a), -cos(a)) * 22.0
			wax.append(xf * RisoShapes.rrect(base.x - 2.0, base.y - 7.0, 4.0, 8.0, 1.5))
			if i < left:
				var flick: float = 1.0 + 0.2 * sin(t * 11.0 + float(i) * 1.7)
				flames.append(xf * RisoShapes.ellipse(base + Vector2(0, -11), 2.4, 4.2 * flick, 10))
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.8 * solid, wax)
		ink.ink(RisoPrint.PINK, solid, flames)
		glow_ink.ink(RisoPrint.PINK, 0.8 * shown, flames)
		if hurt < 0.3:
			ink.ink(RisoPrint.PINK, 0.4 * (1.0 - hurt / 0.3), [robe], false)
	if dying_t >= 0.0:
		var dust: Array[PackedVector2Array] = []
		for i: int in range(10):
			var k: float = dying_t / DIE_TIME
			var p: Vector2 = Vector2((float(i) - 4.5) * 5.0, -TALL * (1.0 - k) * (0.2 + 0.08 * float(i % 4)))
			dust.append(RisoShapes.circle((p + Vector2(0, -6.0)) * ART, 3.0 * ART * (1.0 - k * 0.5), 8))
		ink.ink(RisoPrint.NIGHT, 0.6, dust, false)
	if stunner.stunned():
		_stun_stars(Vector2(0, -(TALL + 24.0) * ART))
	ink.finish()
	glow_ink.finish()


## The stars circling a stunned head (as CreatureArt's).
func _stun_stars(c: Vector2) -> void:
	var stars: Array[PackedVector2Array] = []
	for i: int in range(3):
		var a: float = t * 1.3 + TAU * float(i) / 3.0
		var p: Vector2 = c + Vector2(cos(a) * 30.0, sin(a) * 8.0)
		stars.append(Transform2D(t * 0.9 + float(i), p) * RisoShapes.sparkle(Vector2.ZERO, 12.0))
	ink.ink(RisoPrint.ACCENT, 1.0, stars)
