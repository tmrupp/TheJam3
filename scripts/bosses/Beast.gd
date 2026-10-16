class_name Beast
extends Node2D
## The eldritch beast (Bosses.DOWN's last): the boss at the bottom of the institute, lying in the
## middle of its chamber's floor in its gate level (Institute, LevelGen.place_boss;
## docs/REGIONS_PLAN.md §6). The abominations rising into the institute are its. It sleeps until the
## wizard comes into its chamber or within WAKE_RANGE, or strikes it; then:
## - The first time it wakes in a run, it sends its souls out across the run (MapInfo.beast_woke,
##   BeastSouls): into levels the wizard has visited and a few beside them, in any band and column.
##   It has one eye for each soul sent; each soul destroyed shuts one, for good.
## - While any soul lives it cannot be wounded: a strike glances off it, its open eyes flaring
##   (glance). With every eye shut, its great eye opens: then any hex bolt, dash or parry wounds it
##   (BeastWound), CORE_HP blows in all, shown as pips over it.
## - Awake, it strikes with its tentacles (BeastTentacle) every ATTACK_EVERY seconds (sooner on a
##   harder preset): bursting up out of the floor under the wizard, and every SWEEP_EVERY strikes,
##   lashing along the floor from its flank toward them, to be jumped. Its body's touch hurts too.
##   A parry stuns it a moment (its tentacles whip back), and wounds it once its eyes are shut.
## - With its last blow it sinks back into the deep (DIE_TIME), it is slain, whatever souls are
##   left go with it, and its relic waits where it lay (MapInfo.boss_slain).
## A lantern death brings it back whole, as the level reloads; destroyed souls stay destroyed.
## Nothing here draws from any RNG.

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## The blows its great eye takes once every soul is destroyed.
const CORE_HP: int = 9
## How near (px) the wizard comes to wake it, if not inside its chamber.
const WAKE_RANGE: float = 700.0
## How big it is drawn, against the sizes its shapes are given at (LOBES, EYES, ARMS).
const ART: float = 1.35
## How far over the floor its middle is (px): where a strike meets it and its touch is centred.
const RISE: float = 110.0
## Its touch: a circle this big (px) round its middle.
const TOUCH_R: float = 130.0
## Its blows left, as pips over it: how high over its feet (px, as drawn), how far apart, how big.
const PIPS_UP: float = 310.0
const PIP_GAP: float = 34.0
const PIP_R: float = 12.0
## Seconds before its first strike once awake, and between strikes (shorter on a harder preset,
## Difficulty.haste); every SWEEP_EVERY strikes is a sweep along the floor, the rest burst up under
## the wizard.
const ATTACK_FIRST: float = 1.2
const ATTACK_EVERY: float = 2.4
const SWEEP_EVERY: int = 3
## A tentacle bursting up: how far (cells) and how thick (px). One lashing along the floor: how
## thick (px) and how high its middle is over the floor (low enough to jump).
const SLAM_REACH: float = 2.6
const SLAM_THICK: float = 56.0
const SWEEP_THICK: float = 44.0
const SWEEP_RISE: float = 30.0
## How long its sinking takes (s).
const DIE_TIME: float = 1.8
## Its body's blobs, from its feet (across, up, radius, px): the great central one first. Drawn in
## AbominationArt's gumdrops, as its abominations are.
const LOBES: Array[Vector3] = [
	Vector3(0, -95, 105), Vector3(-120, -55, 62), Vector3(125, -60, 66), Vector3(-70, -170, 58),
	Vector3(80, -175, 60), Vector3(-178, -30, 40), Vector3(182, -32, 42), Vector3(5, -215, 46),
]
## Its great eye, the weak point (across, up, radius, px), and its small eyes, one for each soul
## it can send (BeastSouls.SOULS_MOST), in the order they shut.
const GREAT_EYE: Vector3 = Vector3(0, -100, 36)
const EYES: Array[Vector3] = [
	Vector3(-120, -62, 15), Vector3(125, -66, 16), Vector3(-72, -178, 14), Vector3(82, -182, 15),
	Vector3(5, -222, 12), Vector3(-178, -36, 10), Vector3(182, -38, 11),
]
## Its writhing arms (idle ones, for show): from which blob, at what angle (up is -PI/2), how long.
const ARMS: Array[Vector3] = [
	Vector3(1, -2.6, 90), Vector3(2, -0.5, 95), Vector3(3, -2.2, 70), Vector3(4, -0.9, 75),
	Vector3(5, -2.9, 60), Vector3(6, -0.2, 60), Vector3(7, -1.7, 55), Vector3(0, -1.2, 80),
]

var map_info: MapInfo
## Which boss it is (Bosses).
var boss: StringName = &""
var wound: BeastWound
var stunner: Stunner
var touch: HitBox
var ink: InkCanvas
## Its striking tentacles: one bursting up, one lashing along the floor.
var slam: BeastTentacle
var sweep: BeastTentacle
## Its chamber's inside (cells), and the floor's line and ends in the world (px).
var box: Rect2i = Rect2i()
var floor_y: float = 0.0
var x_min: float = 0.0
var x_max: float = 0.0
var cell_px: float = 128.0
## Fighting (woken), the clock to its next strike and how many it has made.
var awake: bool = false
var attack_in: float = ATTACK_FIRST
var attacks: int = 0
## Seconds since a strike glanced off it (its eyes flare), and since a wound.
var glanced: float = 9.0
var hurt: float = 9.0
## Dying: seconds into it (-1 while not); slain once sunk.
var dying_t: float = -1.0
var slain: bool = false
var t: float = 0.0


func _init() -> void:
	wound = BeastWound.new()
	wound.name = "Wound"
	wound.hp = CORE_HP
	add_child(wound)
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	add_child(stunner)
	touch = HIT_BOX.instantiate() as HitBox
	touch.name = "HitBox"
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = TOUCH_R
	(touch.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	touch.position = Vector2(0, RISE - 95.0 * ART)
	(touch.get_node("Damager") as Damager).attacker = self
	add_child(touch)
	slam = BeastTentacle.new(self)
	slam.name = "Slam"
	add_child(slam)
	sweep = BeastTentacle.new(self)
	sweep.name = "Sweep"
	add_child(sweep)
	add_to_group(&"hex_target")


func _ready() -> void:
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)
	move_child(ink, 0)
	add_to_group(&"riso_art")


func setup(info: MapInfo, v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	# It reaches all over its chamber: never put to sleep with the chunk its cell is in.
	remove_meta(&"cell")
	if info.tile_map != null:
		cell_px = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y
	var feet: Vector2 = info.cell_position(v) + Vector2(0, cell_px * 0.5)
	global_position = feet + Vector2(0, -RISE)
	floor_y = feet.y
	var chamber: Dictionary = Institute.chamber(info.world) if info.world != null else {}
	box = chamber["inside"] if not chamber.is_empty() else Rect2i(v - Vector2i(8, 4), Vector2i(17, 5))
	x_min = info.cell_position(Vector2i(box.position.x, v.y)).x - cell_px * 0.5
	x_max = info.cell_position(Vector2i(box.end.x - 1, v.y)).x + cell_px * 0.5


## Whether its great eye is open: awake (so its souls are sent) and every one destroyed (or none
## could be sent). Only then does a strike wound it.
func open() -> bool:
	if map_info == null:
		return awake
	return awake and BeastSouls.alive(map_info.run) == 0


## Its small eyes: how many it has (one for each soul sent; none before it first wakes), and how many
## are open (one for each soul alive).
func eyes() -> Vector2i:
	if map_info == null:
		return Vector2i.ZERO
	var sent: int = mini(map_info.run.souls_sent, EYES.size())
	return Vector2i(sent, mini(BeastSouls.alive(map_info.run), sent))


func dying() -> bool:
	return dying_t >= 0.0 or slain


## A strike glanced off it (a soul still lives): its open eyes flare. A strike wakes it.
func glance(dir: Vector2) -> void:
	glanced = 0.0
	RisoFx.burst(&"hit", global_position, dir, [RisoPrint.BLUE, RisoPrint.NIGHT])
	if not awake:
		_wake()


## A strike landed on its great eye.
func wounded(dir: Vector2) -> void:
	hurt = 0.0
	RisoFx.burst(&"hit", global_position + Vector2(GREAT_EYE.x, GREAT_EYE.y + RISE), dir, [RisoPrint.PINK, RisoPrint.GLOW])
	Wound.shake(10.0, 0.2)


## Its last blow: it sinks back into the deep.
func die() -> void:
	if dying():
		return
	dying_t = 0.0
	remove_from_group(&"hex_target")
	(touch.get_node("CollisionShape2D") as CollisionShape2D).set_deferred("disabled", true)
	slam.stop()
	sweep.stop()
	Wound.shake(16.0, 0.5)
	RisoFx.burst(&"gain", global_position, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])


## Slain at once (the F7 panel's Slay boss, MapInfo.slay_boss).
func slay() -> void:
	if slain:
		return
	wound.hp = 0
	_slain()


func _slain() -> void:
	slain = true
	if map_info != null:
		var feet: Vector2 = global_position + Vector2(0, RISE - 8.0)
		map_info.boss_slain(boss, map_info.cell_position(map_info.cell_at(feet)))
	queue_free()


func _wake() -> void:
	awake = true
	attack_in = ATTACK_FIRST
	Wound.shake(12.0, 0.4)
	RisoFx.burst(&"rubble", global_position + Vector2(0, RISE), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
	if map_info != null:
		map_info.beast_woke()


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
	if not awake:
		if box.has_point(map_info.cell_at(player.global_position)) or player.global_position.distance_to(global_position) <= WAKE_RANGE:
			_wake()
		return
	if stunner.stunned():
		return
	attack_in -= delta * Difficulty.haste()
	if attack_in <= 0.0 and not slam.busy() and not sweep.busy():
		attack_in = ATTACK_EVERY
		attacks += 1
		if attacks % SWEEP_EVERY == 0:
			_sweep(player)
		else:
			_slam(player)


## A tentacle bursting up out of the floor where the wizard stands (within its chamber).
func _slam(player: Player) -> void:
	var x: float = clampf(player.global_position.x, x_min + SLAM_THICK, x_max - SLAM_THICK)
	slam.strike(Vector2(x, floor_y), Vector2.UP, SLAM_REACH * cell_px, SLAM_THICK)


## A tentacle lashing along the floor from its flank toward the wizard, to its chamber's wall.
func _sweep(player: Player) -> void:
	var way: float = 1.0 if player.global_position.x >= global_position.x else -1.0
	var root: Vector2 = Vector2(global_position.x + way * LOBES[0].z * 0.9 * ART, floor_y - SWEEP_RISE)
	var end: float = x_max if way > 0.0 else x_min
	sweep.strike(root, Vector2(way, 0.0), maxf(cell_px, absf(end - root.x)), SWEEP_THICK)


# ------------------------------------------------------------------ how it looks

## A great mound of pink blobs on the floor, breathing, arms writhing up off it; on its blobs its
## eyes, one for each soul it sent, open (paper, night pupils turned on the wizard) while its soul
## lives and shut (a dark slit) once destroyed, all shut while it sleeps; in its middle its great
## eye, shut while any soul lives and open once all are gone (paper, an accent iris: the weak
## point), its blows left as pips over it. A strike that glances off flares its open eyes; a wound
## flashes it pink. It sinks into the floor as it dies.
func _process(_delta: float) -> void:
	if ink == null:
		return
	ink.begin()
	var sink: float = clampf(dying_t / DIE_TIME, 0.0, 1.0) if dying_t >= 0.0 else 0.0
	var breath: float = 1.0 + (0.03 if awake else 0.015) * sin(t * (2.2 if awake else 0.9))
	var xf: Transform2D = Transform2D(0.0, Vector2(ART, ART * breath * (1.0 - 0.85 * sink)), 0.0, Vector2(0, RISE))
	var player: Player = Stage.player()
	var look: Vector2 = Vector2.ZERO
	if player != null and is_instance_valid(player):
		look = (player.global_position - global_position).normalized()
	# Its underside, dark on the floor.
	ink.ink(RisoPrint.NIGHT, 0.6, [xf * RisoShapes.ellipse(Vector2(0, -4), 230.0, 12.0, 24)], false)
	# Arms writhing up off it.
	var arms: Array[PackedVector2Array] = []
	for arm: Vector3 in ARMS:
		var lobe: Vector3 = LOBES[int(arm.x)]
		var ang: float = arm.y
		var at: Vector2 = Vector2(lobe.x, lobe.y) + Vector2.from_angle(ang) * lobe.z * 0.8
		var pts: PackedVector2Array = PackedVector2Array()
		for j: int in range(7):
			pts.append(at)
			ang += sin(t * (1.4 if awake else 0.5) + arm.x * 1.3 + float(j) * 0.7) * 0.3
			at += Vector2.from_angle(ang) * arm.z / 6.0
			at.y = minf(at.y, -3.0)
		for poly: PackedVector2Array in RisoDecor.strip(pts, 12.0, 2.0):
			arms.append(xf * poly)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], arms)
	ink.ink(RisoPrint.PINK, 1.0, arms, false)
	ink.ink(RisoPrint.BLUE, 0.45, arms, false)
	var body: Array[PackedVector2Array] = []
	for i: int in range(LOBES.size()):
		var l: Vector3 = LOBES[i]
		var wob: Vector2 = Vector2(sin(t * 1.3 + float(i) * 1.7), cos(t * 1.1 + float(i))) * 3.0
		body.append(xf * AbominationArt.gumdrop(Vector2(l.x, l.y) + wob, l.z))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], body)
	ink.ink(RisoPrint.PINK, 1.0, body, false)
	ink.ink(RisoPrint.BLUE, 0.35, body, false)
	if hurt < 0.3:
		ink.ink(RisoPrint.PINK, 0.5 * (1.0 - hurt / 0.3), body, false)
	if glanced < 0.4:
		ink.ink(RisoPrint.BLUE, 0.35 * (1.0 - glanced / 0.4), body, false)
	# Its small eyes.
	var count: Vector2i = eyes()
	var shown: int = count.x if count.x > 0 else EYES.size()
	var whites: Array[PackedVector2Array] = []
	var pupils: Array[PackedVector2Array] = []
	var slits: Array[PackedVector2Array] = []
	var flares: Array[PackedVector2Array] = []
	for i: int in range(shown):
		var e: Vector3 = EYES[i]
		var c: Vector2 = Vector2(e.x, e.y)
		var lit: bool = awake and sink == 0.0 and i < count.y
		if not lit:
			slits.append(xf * RisoShapes.almond(c, e.z * 1.1, 2.0))
			continue
		var blink: bool = fposmod(t * 0.6 + float(i) * 0.43, 5.0) < 0.1
		if blink or stunner.stunned():
			slits.append(xf * RisoShapes.almond(c, e.z * 1.1, 2.0))
			continue
		whites.append(xf * RisoShapes.circle(c, e.z, 16))
		pupils.append(xf * RisoShapes.circle(c + look * e.z * 0.4, e.z * 0.48, 12))
		if glanced < 0.4:
			flares.append_array(RisoShapes.ring(xf * c, e.z * 1.3, e.z * (1.5 + 1.5 * glanced / 0.4), 20))
	# Its great eye: shut while any soul lives, open once all are gone.
	var great: Vector2 = Vector2(GREAT_EYE.x, GREAT_EYE.y)
	var r: float = GREAT_EYE.z
	var weak: bool = open() and sink == 0.0
	if weak and not stunner.stunned():
		whites.append(xf * RisoShapes.almond(great, r * 1.3, r * 0.85))
	else:
		slits.append(xf * RisoShapes.almond(great, r * 1.3, 3.0))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], whites)
	if weak and not stunner.stunned():
		ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.circle(great + look * r * 0.35, r * 0.62, 20)])
		pupils.append(xf * RisoShapes.ellipse(great + look * r * 0.4, r * 0.18, r * 0.5, 14))
	ink.ink(RisoPrint.NIGHT, 1.0, pupils, false)
	ink.ink(RisoPrint.NIGHT, 0.9, slits, false)
	if not flares.is_empty():
		ink.ink(RisoPrint.PINK, 0.8, flares)
	# Its blows left, as pips over it, once it can be wounded.
	if weak:
		var whole: Array[PackedVector2Array] = []
		var gone: Array[PackedVector2Array] = []
		for i: int in range(CORE_HP):
			var at: Vector2 = Vector2((float(i) - float(CORE_HP - 1) * 0.5) * PIP_GAP, RISE - PIPS_UP * ART)
			var pip: PackedVector2Array = PackedVector2Array([at + Vector2(0, -PIP_R), at + Vector2(PIP_R, 0), at + Vector2(0, PIP_R), at + Vector2(-PIP_R, 0)])
			if i < wound.hp:
				whole.append(pip)
			else:
				gone.append(pip)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], whole)
		ink.ink(RisoPrint.PINK, 1.0, whole, false)
		ink.ink(RisoPrint.NIGHT, 0.35, gone, false)
	if stunner.stunned():
		var stars: Array[PackedVector2Array] = []
		for i: int in range(3):
			var a: float = t * 1.3 + TAU * float(i) / 3.0
			var p: Vector2 = xf * Vector2(cos(a) * 60.0, -PIPS_UP + 40.0 + sin(a) * 10.0)
			stars.append(Transform2D(t * 0.9 + float(i), p) * RisoShapes.sparkle(Vector2.ZERO, 20.0))
		ink.ink(RisoPrint.ACCENT, 1.0, stars)
	if dying_t >= 0.0:
		var dust: Array[PackedVector2Array] = []
		for i: int in range(14):
			var p: Vector2 = Vector2((float(i) - 6.5) * 32.0, -10.0 - 60.0 * sink * (0.4 + 0.1 * float(i % 5)))
			dust.append(RisoShapes.circle(xf * p, 8.0 * (1.0 - sink * 0.5), 8))
		ink.ink(RisoPrint.NIGHT, 0.6, dust, false)
	ink.finish()
