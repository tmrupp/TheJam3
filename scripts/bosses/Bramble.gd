class_name Bramble
extends Node2D
## The bramble (the garden's way up's boss, Bands): the boss of the garden's way up, fought in its gate level
## (docs/REGIONS_PLAN.md §6). The way up is a tall shaft of rock (BrambleShaft), and the bramble is
## rooted at its head: a knot of bark and thorns filling the head beside the landing the way on
## stands on, so nothing gets past it to the way on. Its roots run down the shaft's walls to:
## - its bulbs (BrambleBulb), BrambleShaft.BULBS.x to BULBS.y of them set in the walls, its weak
##   points: each takes BULB_HP hits from bolts or dashes (any strike wounds them, even one that only
##   stuns), and spits seeds at the wizard that a parry turns back into it. Only one is in bloom at a
##   time (`bloom`), the lowest first: the rest are shut in their bark, and only their own seeds
##   parried back wound them. A bloom lasts BLOOM_TIME (counted while the wizard is in the shaft);
##   then, or when it bursts, its sap runs up the roots, through the knot and down to the living bulb
##   furthest from the wizard (a pulse of accent along the way, SAP_SPEED), which blooms next;
## - its thorn vines (BrambleVine), rooted in the walls between: they lash out across the shaft and
##   pull back on a cadence, so the climb up the shaft's ledges is a matter of timing. A parried lash
##   recoils and stays back a while. Each vine feeds from the bulb nearest it, and withers for good
##   when that bulb bursts.
## Each bulb burst raises its fury (`fury`): the bulbs left spit sooner and, from
## BrambleBulb.TWIN_FURY, two seeds at once, and the vines left rest the shorter.
## Its health is its bulbs: one accent pip on the knot for each, put out as each bursts. When the
## last bursts every vine withers and the knot splits (SPLIT_TIME) to bare its heart (BrambleHeart,
## HEART_HP hits; a big bud wrapped in sepals, _draw_bud), which drops barbs down the shaft at the
## wizard. The knot itself is vines (Strand), grown from the level seed: dark ones packed close and
## bark stems over them with tendrils curling off, each grown out of the rock round the head,
## wandering, and reaching past the middle to weave with the other side's, until the knot splits
## and they tear there round the heart. When the heart bursts the head of the shaft is open
## at once, and the bramble dies vine by vine: a dry front runs out from the heart (DRY_SPEED), and
## each vine of the knot, each root down the walls and each withered vine's curl pales as it reaches
## it, then draws back into the rock it grows from, the burst husks pulled in with the roots. When
## the last is in, it is slain, and its relic waits on the landing beside the way on
## (MapInfo.boss_slain), whose seal lifts. A lantern death brings it back whole, as the level
## reloads. Nothing here draws from the world RNG: the shaft and everything set in it come from the
## level's layout, and the rest is hashed from its seed.

const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## The hits each bulb takes.
const BULB_HP: int = 3
## How long a bulb stays in bloom (seconds the wizard spends in the shaft, before Difficulty.haste),
## how fast its sap runs to the next (px a second), and the least time the run takes.
const BLOOM_TIME: float = 6.0
const SAP_SPEED: float = 900.0
const SAP_MIN: float = 0.5
## The sap's pulse as printed: its radius (px), and how many drops trail it, how far apart (px).
const SAP_R: float = 12.0
const SAP_TRAIL: int = 4
const SAP_GAP: float = 16.0
## The heart: the hits it takes, how long the knot takes to split and bare it, how far its halves
## part (a share of the knot's width), and how often it beats (seconds). It is printed as a bud
## (_draw_bud): BUD_LONG long and BUD_WIDE across when the knot is fully split, its cap BUD_TOP up
## inside the knot's underside, struck at BUD_MID of the way down it; its two long sepals flare
## BUD_SPREAD (radians) off it, and part BUD_PART more at each beat.
const HEART_HP: int = 4
const SPLIT_TIME: float = 0.8
const SPLIT_PULL: float = 0.1
const HEART_BEAT: float = 0.8
const BUD_LONG: float = 150.0
const BUD_WIDE: float = 116.0
const BUD_TOP: float = 8.0
const BUD_MID: float = 0.45
const BUD_SPREAD: float = 0.24
const BUD_PART: float = 0.12
## Its death, once the heart has burst: a dry front runs out from the heart at DRY_SPEED (px a
## second), reaching each vine at its nearest point, up to DRY_JITTER seconds later (hashed); the
## vine dries over DRY_TIME, and BACK_DELAY (plus up to BACK_JITTER) after the front reached it it
## draws back into the rock, over BACK_MIN seconds plus its length at BACK_SPEED.
const DRY_SPEED: float = 600.0
const DRY_JITTER: float = 0.25
const DRY_TIME: float = 0.45
const BACK_DELAY: float = 0.5
const BACK_JITTER: float = 0.15
const BACK_MIN: float = 0.3
const BACK_SPEED: float = 450.0
## Drying, how much thinner a vine grows (a share of its width), how far it crinkles (px), and its
## inks once dry: the blue left on a stem, root or curl, the blue and night on the knot's dark
## vines, and the pink on a thorn (blue screened over it, straw-pale). Printed in DRY_STEPS steps.
const DRY_THIN: float = 0.42
const DRY_CRINKLE: float = 3.0
const DRY_BLUE: float = 0.45
const DRY_BACK_BLUE: float = 0.5
const DRY_BACK_NIGHT: float = 0.3
const DRY_PINK: float = 0.35
const DRY_THORN_BLUE: float = 0.35
const DRY_STEPS: int = 8
## A burst husk is pulled into the wall over this far (px) of its root's tip drawing back past it.
const HUSK_PULL: float = 40.0
## The knot's vines, grown from the level seed: how far apart its dark ones lie (px), how wide
## they and its bark stems are (px, dealt between), how far a vine out of the wall may slant (px,
## between its two ends) and bow (a share of the knot's height), how far each wanders off its way
## (px, in two waves of hashed length), how far past the knot's middle it reaches (a share of half
## the knot's width: the two sides weave together, and tear apart only when the knot splits), how
## far into the rock their anchors sit (px), and how many points each has.
const BACK_GAP: float = 28.0
const BACK_WIDE: Vector2 = Vector2(44.0, 56.0)
const STEM_WIDE: Vector2 = Vector2(18.0, 30.0)
const BACK_SLANT: float = 16.0
const STEM_SLANT: float = 40.0
const BACK_BOW: float = 0.06
const STEM_BOW: float = 0.25
const BACK_WANDER: float = 7.0
const STEM_WANDER: float = 16.0
const KNOT_OVERLAP: float = 0.35
const ANCHOR_IN: float = 10.0
const STRAND_POINTS: int = 20
## Tendrils off the knot's bark stems (one or two each) and rootlets off the roots (about one every
## ROOTLET_EVERY px): how long (px, dealt between), how wide at their base (px), and how hard they
## curl (radians a px, growing toward the tip). The roots' own wander: how long its waves are (px).
const TENDRIL_LONG: Vector2 = Vector2(40.0, 70.0)
const TENDRIL_WIDE: float = 8.0
const ROOTLET_EVERY: float = 120.0
const ROOTLET_LONG: Vector2 = Vector2(28.0, 54.0)
const ROOTLET_WIDE: float = 7.0
const CURL: Vector2 = Vector2(0.03, 0.07)
const ROOT_WAVES: Vector2 = Vector2(180.0, 70.0)
## How far past the knot (px) its thorns hurt.
const KNOT_REACH: float = 10.0
## The bark: its covers of blue and night; and the dark mass of the knot the stems twist over (a
## darker green than the rock, darker still than the open shaft). Roots down the walls: how far out of the rock face they
## wave (px), and how thick they are.
const BARK_BLUE: float = 0.9
const BARK_NIGHT: float = 0.55
const KNOT_BLUE: float = 0.75
const KNOT_NIGHT: float = 0.75
const ROOT_SWAY: float = 10.0
const ROOT_WIDTH: float = 16.0
## A bulb: its radius (px) when still, how much it swells as it readies a seed, and how long it
## flashes when struck and its husk's petals fly when it bursts.
const BULB_R: float = 40.0
const BULB_SWELL: float = 0.22
## A shut bulb (not in bloom): how big it is beside one in bloom, how strong its accent is in the
## seam between its sepals, how far its sepals turn (radians) shut (in over it) and open (back
## against the wall), and how far apart their hinges are and how wide each is (shares of BULB_R),
## leaving a seam of accent down the middle.
const SHUT_SIZE: float = 0.85
const SHUT_ACCENT: float = 0.8
const SEPAL_SHUT: float = 0.08
const SEPAL_OPEN: float = 1.35
const SEPAL_HINGE: float = 0.55
const SEPAL_WIDE: float = 0.4
## How far into the shaft past the rock face the sap runs (px).
const SAP_OUT: float = 14.0
## A barb's warning tip (px): how wide at its foot, and how long at first and at the drop.
const WARN_WIDE: float = 13.0
const WARN_LONG: Vector2 = Vector2(30.0, 76.0)
const FLASH_TIME: float = 0.18
const BURST_TIME: float = 0.45
## A vine: its stem's half width at the root and at the tip (px), its thorns' spacing and length.
const STEM_ROOT: float = 16.0
const STEM_TIP: float = 5.0
const THORN_EVERY: float = 26.0
const THORN_LEN: float = 18.0
## How many bark stems twist over the knot (half from each side), and the salt for the level seed
## that lays its vines.
const KNOT_STEMS: int = 6
const KNOT_DEAL: int = 6660

var map_info: MapInfo
## Which boss it is (Bosses).
var boss: StringName = &""
## A cell's size in pixels, and the middle of cell (0, 0).
var cell: float = 64.0
var origin: Vector2 = Vector2.ZERO
## The shaft (BrambleShaft): its inside, and the knot (in pixels), and the relic's place.
var inside: Rect2i = Rect2i()
var knot_rect: Rect2 = Rect2()
var relic_at: Vector2 = Vector2.ZERO
var bulbs: Array[BrambleBulb] = []
var vines: Array[BrambleVine] = []
## The bulb in bloom (null while its sap runs to the next, and once all have burst), and the seconds
## it has left.
var bloom: BrambleBulb = null
var bloom_left: float = 0.0
## The sap on its way: the bulb it runs to (null when none is), its way in pixels, how long that is,
## and how far along it is (0 to 1).
var sap_to: BrambleBulb = null
var sap_path: PackedVector2Array = PackedVector2Array()
var sap_len: float = 0.0
var sap_u: float = 0.0
## Its fury: a point for each bulb burst.
var fury: int = 0
## Its heart, once bared (null before), and how far the knot has split round it (0 to 1).
var heart: BrambleHeart = null
var split: float = 0.0
## The knot's body (it walls off the head of the shaft) and its thorns' touch.
var knot: StaticBody2D
var knot_box: HitBox
## Whether it is dying (the heart burst), the seconds since, the seconds its death takes (its last
## vine in), and whether it is slain.
var dying: bool = false
var dying_t: float = 0.0
var dying_end: float = 0.0
var slain: bool = false
## Its vines as drawn (Strand): the knot's dark ones, its bark stems and their tendrils, its roots
## down the walls (the left wall's first) and their rootlets, and once it is dying, its withered
## vines' curls.
var knot_back: Array[Strand] = []
var knot_stems: Array[Strand] = []
var tendrils: Array[Strand] = []
var roots: Array[Strand] = []
var rootlets: Array[Strand] = []
var curls: Array[Strand] = []
var ink: InkCanvas
var t: float = 0.0
var level_seed: int = 0


## One of the bramble's vines as it is drawn and dies: a line of points out of the rock (its
## anchor first), how wide it is at each, its thorns, and when it dries and draws back.
class Strand:
	## &"back" (the knot's dark vines), &"stem" (its bark stems), &"root" or &"curl" (a withered
	## vine).
	var kind: StringName = &""
	## Which way the knot's split pulls it (-1 or 1; 0 for none), and for a root, the way out of its
	## wall into the shaft.
	var side: float = 0.0
	var wall: float = 0.0
	var pts: PackedVector2Array = PackedVector2Array()
	## How far along it each point is (px), and its whole length.
	var arc: PackedFloat32Array = PackedFloat32Array()
	var length: float = 0.0
	var widths: PackedFloat32Array = PackedFloat32Array()
	## Its thorns: the point each grows from, its edge (1 or -1, or 0 for straight down the shaft)
	## and how long it is (px).
	var thorns: Array[Vector3] = []
	## A knot vine reaches past the knot's middle: how far along it crosses it, where it tears when
	## the knot splits (its whole length for any other).
	var tear: float = 0.0
	## A tendril or rootlet: the vine it grows from, and how far along that vine (px).
	var parent: Strand = null
	var base_arc: float = 0.0
	## A number hashed for it (0 to 1); the seconds into the death it starts to dry and to draw back,
	## and how long drawing back takes.
	var salt: float = 0.0
	var dry_at: float = 0.0
	var back_at: float = 0.0
	var back_time: float = 1.0

	func _init(of: StringName, pull: float, points: PackedVector2Array, wide: PackedFloat32Array, k: float) -> void:
		kind = of
		side = pull
		pts = points
		widths = wide
		salt = k
		arc.resize(pts.size())
		for j: int in range(1, pts.size()):
			length += pts[j - 1].distance_to(pts[j])
			arc[j] = length
		tear = length


func _ready() -> void:
	# Over the terrain with the other things in a level (props, z 2).
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)


func setup(info: MapInfo, _v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	# It spans the whole shaft: never put to sleep with the chunk its cell is in.
	remove_meta(&"cell")
	var tm: TileMap = info.tile_map
	cell = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	origin = info.cell_position(Vector2i.ZERO)
	var w: LevelGen = info.world
	level_seed = w.seed_for_colors
	var shaft: Dictionary = w.shaft
	if shaft.is_empty():
		return
	inside = shaft["inside"]
	relic_at = info.cell_position(shaft["relic"] as Vector2i)
	var k: Rect2i = shaft["knot"]
	knot_rect = Rect2(center(k.position) - Vector2.ONE * cell * 0.5, Vector2(k.size) * cell)
	_grow_knot()
	for b: Array in shaft["bulbs"]:
		var bulb: BrambleBulb = BrambleBulb.new(self, b[0], Vector2(b[1] as Vector2i), BULB_HP)
		bulb.name = "Bulb%d" % bulbs.size()
		add_child(bulb)
		bulb.place(face(b[0], b[1]), level_seed)
		bulbs.append(bulb)
	for v: Array in shaft["vines"]:
		var vine: BrambleVine = BrambleVine.new(self, v[0], Vector2(v[1] as Vector2i))
		vine.name = "Vine%d" % vines.size()
		add_child(vine)
		vine.place(face(v[0], v[1]), cell, level_seed)
		vine.bulb = LevelGen.best_of(bulbs, func(b: BrambleBulb) -> float: return b.global_position.distance_to(vine.global_position)) as BrambleBulb
		vines.append(vine)
	_grow_strands(knot_rect)
	_grow_roots()
	# The lowest bulb, nearest the foot where the wizard comes in, blooms first.
	if not bulbs.is_empty():
		bloom_on(LevelGen.best_of(bulbs, func(b: BrambleBulb) -> float: return -b.global_position.y) as BrambleBulb)


## The middle of cell `v`.
func center(v: Vector2i) -> Vector2:
	return origin + Vector2(v) * cell


## The middle of the face of wall cell `wall` toward `out` (into the shaft).
func face(wall: Vector2i, out: Vector2i) -> Vector2:
	return center(wall) + Vector2(out) * cell * 0.5


## The knot: a solid body filling the head of the shaft beside the landing, and the touch of its
## thorns a little past it.
func _grow_knot() -> void:
	knot = StaticBody2D.new()
	knot.name = "Knot"
	# The environment's layer: the wizard stands on it and cannot get past it.
	knot.collision_layer = 4
	knot.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = knot_rect.size
	shape.shape = rect
	knot.add_child(shape)
	add_child(knot)
	knot.global_position = knot_rect.get_center()
	knot_box = HIT_BOX.instantiate() as HitBox
	knot_box.name = "HitBox"
	var reach: RectangleShape2D = RectangleShape2D.new()
	reach.size = knot_rect.size + Vector2.ONE * KNOT_REACH * 2.0
	(knot_box.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	knot.add_child(knot_box)


## Whether `at` (px) is in the shaft, from its foot up to the knot.
func in_shaft(at: Vector2) -> bool:
	var half: Vector2 = Vector2.ONE * cell * 0.5
	return Rect2(center(inside.position) - half, Vector2(inside.size) * cell).has_point(at)


## Bulb `bulb` blooms now, for BLOOM_TIME (the tests use it too).
func bloom_on(bulb: BrambleBulb) -> void:
	bloom = bulb
	bloom_left = BLOOM_TIME
	sap_to = null
	sap_path = PackedVector2Array()


## The bloom leaves `from`: its sap runs to the living bulb furthest from the wizard (another, while
## there is one), which blooms when it arrives.
func _flow(from: BrambleBulb) -> void:
	bloom = null
	var left: Array = bulbs.filter(func(b: BrambleBulb) -> bool: return b.alive and b != from)
	if left.is_empty() and from.alive:
		left = [from]
	if left.is_empty():
		return
	var player: Player = map_info.player if map_info != null else null
	var next: BrambleBulb = left[0]
	if player != null and is_instance_valid(player):
		var at: Vector2 = player.global_position
		next = LevelGen.best_of(left, func(b: BrambleBulb) -> float: return -b.global_position.distance_to(at)) as BrambleBulb
	sap_to = next
	sap_path = _sap_path(from, next)
	sap_len = 0.0
	for i: int in range(1, sap_path.size()):
		sap_len += sap_path[i - 1].distance_to(sap_path[i])
	sap_u = 0.0


## The way the sap runs from bulb `a` to bulb `b` (px): along the wall's root when they share a
## wall, else up `a`'s root to the knot, through it, and down `b`'s.
func _sap_path(a: BrambleBulb, b: BrambleBulb) -> PackedVector2Array:
	var from: Vector2 = a.global_position - a.way * (BrambleBulb.OUT - SAP_OUT)
	var to: Vector2 = b.global_position - b.way * (BrambleBulb.OUT - SAP_OUT)
	if a != b and signf(a.way.x) == signf(b.way.x):
		return PackedVector2Array([from, to])
	var y: float = knot_rect.end.y - cell * 0.5
	return PackedVector2Array([from, Vector2(from.x, y), Vector2(to.x, y), to])


## Where the sap is, `back` px behind its pulse.
func sap_at(back: float = 0.0) -> Vector2:
	var go: float = maxf(0.0, sap_u * sap_len - back)
	for i: int in range(1, sap_path.size()):
		var leg: float = sap_path[i - 1].distance_to(sap_path[i])
		if go <= leg or i == sap_path.size() - 1:
			return sap_path[i - 1].move_toward(sap_path[i], go)
		go -= leg
	return sap_path[0] if not sap_path.is_empty() else Vector2.ZERO


## How many bulbs are left.
func bulbs_left() -> int:
	return bulbs.filter(func(b: BrambleBulb) -> bool: return b.alive).size()


## Bulb `bulb` has burst: the vines it fed wither, its sap goes to the rest (fury) and, if it was
## in bloom, runs on to the next; with the last one the heart is bared. The heart burst, the knot
## tears open.
func burst(bulb: BrambleBulb) -> void:
	if not bulb.alive:
		return
	bulb.pop()
	RisoFx.burst(&"gain", bulb.global_position, bulb.way, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(12.0, 0.25)
	if bulb == heart:
		_open()
		return
	fury += 1
	for vine: BrambleVine in vines:
		if vine.bulb == bulb:
			vine.wither()
	if bulbs_left() == 0:
		_bare_heart()
	elif bloom == bulb or sap_to == bulb:
		_flow(bulb)


## The last bulb has burst: every vine withers, and the knot splits to bare its heart.
func _bare_heart() -> void:
	bloom = null
	sap_to = null
	for vine: BrambleVine in vines:
		vine.wither()
	heart = BrambleHeart.new(self, Vector2i(roundi((knot_rect.get_center().x - origin.x) / cell), roundi((knot_rect.end.y - origin.y) / cell)), Vector2.DOWN, HEART_HP)
	heart.name = "Heart"
	add_child(heart)
	heart.global_position = Vector2(knot_rect.get_center().x, knot_rect.end.y - BUD_TOP + BUD_LONG * BUD_MID)
	Wound.shake(14.0, 0.4)
	RisoFx.burst(&"hit", heart.global_position, Vector2.DOWN, [RisoPrint.ACCENT, RisoPrint.PINK])


## The heart has burst: nothing of it hurts now and the head of the shaft is open, and it dies vine
## by vine (see DRY_SPEED): every vine pales as the dry front from the heart reaches it, then draws
## back into the rock it grows from, the withered vines' curls with the rest.
func _open() -> void:
	dying = true
	dying_t = 0.0
	for vine: BrambleVine in vines:
		vine.wither()
	for part: CollisionShape2D in [knot.get_child(0) as CollisionShape2D, knot_box.collision]:
		if part != null:
			part.set_deferred("disabled", true)
	curls.clear()
	for i: int in range(vines.size()):
		curls.append(_curl_strand(vines[i], i))
	var from: Vector2 = heart.global_position if heart != null else knot_rect.get_center()
	dying_end = 0.0
	for s: Strand in all_strands():
		_time(s, from)
		dying_end = maxf(dying_end, s.back_at + s.back_time)
	Wound.shake(16.0, 0.5)
	RisoFx.burst(&"hit", from, Vector2.DOWN, [RisoPrint.PINK, RisoPrint.BLUE])


func _physics_process(delta: float) -> void:
	if slain:
		return
	if dying:
		dying_t += delta
		if dying_t >= dying_end:
			_die()
		return
	if heart != null:
		split = minf(1.0, split + delta / SPLIT_TIME)
		return
	# A harder preset moves the bloom on sooner (Difficulty.haste).
	var haste: float = Difficulty.haste()
	if bloom != null:
		var player: Player = map_info.player if map_info != null else null
		if player != null and is_instance_valid(player) and in_shaft(player.global_position):
			bloom_left -= delta * haste
		if bloom_left <= 0.0:
			_flow(bloom)
	elif sap_to != null:
		sap_u += delta * haste * SAP_SPEED / maxf(sap_len, SAP_SPEED * SAP_MIN)
		if sap_u >= 1.0:
			bloom_on(sap_to)


## Slain at once (the F7 panel's Slay boss, MapInfo.slay_boss): every bulb bursts, and it dies
## without waiting for its vines to draw back.
func slay() -> void:
	if slain:
		return
	for bulb: BrambleBulb in bulbs:
		burst(bulb)
	if heart != null:
		burst(heart)
	_die()


## It is slain: its relic waits on the landing beside the way on, and it is gone.
func _die() -> void:
	slain = true
	if map_info != null:
		map_info.boss_slain(boss, relic_at)
	queue_free()


# ------------------------------------------------------------------ its vines

## Every vine it has (Strand): the knot's, its roots, its withered vines' curls.
func all_strands() -> Array[Strand]:
	var out: Array[Strand] = []
	out.append_array(knot_back)
	out.append_array(knot_stems)
	out.append_array(tendrils)
	out.append_array(roots)
	out.append_array(rootlets)
	out.append_array(curls)
	return out


## A number from 0 to 1 hashed from the level seed and `k`.
func _deal(k: float) -> float:
	return RisoShapes.hash1(float(level_seed % 7919) * 0.37 + k * 1.7 + float(KNOT_DEAL))


## Points along the curve from `a`, bent toward `c`, to `b` (STRAND_POINTS + 1 of them).
static func _bow(a: Vector2, c: Vector2, b: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for m: int in range(STRAND_POINTS + 1):
		var u: float = float(m) / float(STRAND_POINTS)
		out.append(a.lerp(c, u).lerp(c.lerp(b, u), u))
	return out


## A vine's line from `a` to `b`, bent toward `c` (STRAND_POINTS + 1 points), wandering off its
## way by up to `wander` px in two waves along it, their lengths and phases hashed from `k`; none
## at its anchor.
func _wander(a: Vector2, c: Vector2, b: Vector2, wander: float, k: float) -> PackedVector2Array:
	var line: PackedVector2Array = _bow(a, c, b)
	var f1: float = lerpf(1.0, 2.2, _deal(k + 0.11))
	var f2: float = lerpf(3.0, 5.0, _deal(k + 0.23))
	var p1: float = _deal(k + 0.37) * TAU
	var p2: float = _deal(k + 0.41) * TAU
	var out: PackedVector2Array = PackedVector2Array()
	for m: int in range(line.size()):
		var u: float = float(m) / float(line.size() - 1)
		var push: float = (0.7 * sin(u * f1 * PI + p1) + 0.3 * sin(u * f2 * PI + p2)) * wander * minf(1.0, u * 3.0)
		out.append(line[m] + _across(line, m) * push)
	return out


## Widths for `n` points of a vine `w` px wide at its anchor: thinning a little toward its end and
## swelling and narrowing along it, in a wave hashed from `k`.
func _thickness(n: int, w: float, k: float) -> PackedFloat32Array:
	var f: float = lerpf(2.0, 4.0, _deal(k + 0.53))
	var p: float = _deal(k + 0.59) * TAU
	var out: PackedFloat32Array = PackedFloat32Array()
	for j: int in range(n):
		var u: float = float(j) / float(maxi(n - 1, 1))
		out.append(w * (1.0 - 0.2 * u) * (0.85 + 0.15 * sin(u * f * PI + p)))
	return out


## How far along strand `s` it first crosses x = `x` (its whole length if it never does).
static func _crossing(s: Strand, x: float) -> float:
	var from: float = signf(s.pts[0].x - x)
	for j: int in range(1, s.pts.size()):
		if signf(s.pts[j].x - x) != from:
			var u: float = (x - s.pts[j - 1].x) / (s.pts[j].x - s.pts[j - 1].x)
			return lerpf(s.arc[j - 1], s.arc[j], u)
	return s.length


## A tendril or rootlet off vine `from` (hashed by `k`), `along` px out along it, heading off its
## edge `side` (1 or -1) and a little on along it, `long` px long and `wide` px wide at its base,
## thinning to a curl at its tip; into `list`.
func _sprout(from: Strand, along: float, side: float, long: float, wide: float, k: float, list: Array[Strand]) -> void:
	var j: int = 1
	while j < from.pts.size() - 1 and from.arc[j] < along:
		j += 1
	var at: Vector2 = strand_at(from, along)
	var on: Vector2 = (from.pts[j] - from.pts[j - 1]).normalized()
	var heading: float = (_across(from.pts, j) * side * 0.8 + on * 0.6).angle()
	var curl: float = side * lerpf(CURL.x, CURL.y, _deal(k + 0.7))
	var steps: int = 10
	var step: float = long / float(steps)
	var pts: PackedVector2Array = PackedVector2Array([at])
	var widths: PackedFloat32Array = PackedFloat32Array([wide])
	for m: int in range(1, steps + 1):
		heading += curl * step * (1.0 + float(m) * 0.25)
		pts.append(pts[m - 1] + Vector2.from_angle(heading) * step)
		widths.append(wide * (1.0 - 0.75 * float(m) / float(steps)))
	var s: Strand = Strand.new(from.kind, from.side, pts, widths, _deal(k + 0.77))
	s.parent = from
	s.base_arc = along
	list.append(s)


## The knot's vines over rectangle `r`, grown from the level seed: on the side away from the
## landing each grows out of the shaft's wall, on the landing's side (open air over the landing)
## out of the roof, down past the landing's edge; each wanders across to a little past the middle
## (KNOT_OVERLAP), weaving with the other side's, and tears at the middle when the knot splits round
## its heart. Dark ones packed BACK_GAP apart (the lowest on each side running along the underside,
## its long thorns pointing down the shaft), and KNOT_STEMS bark stems over them, wandering more,
## thorned, with a tendril or two curling off each. The same every visit.
func _grow_strands(r: Rect2) -> void:
	knot_back.clear()
	knot_stems.clear()
	tendrils.clear()
	var cx: float = r.get_center().x
	var inner: float = 1.0 if relic_at.x >= cx else -1.0
	var inner_x: float = r.end.x if inner > 0.0 else r.position.x
	var outer_x: float = r.position.x if inner > 0.0 else r.end.x
	var top: float = r.position.y + 8.0
	var low: float = r.end.y - 14.0
	var over: float = r.size.x * 0.5 * KNOT_OVERLAP
	var k: int = 0
	for layer: StringName in [&"back", &"stem"]:
		var count: int = maxi(4, ceili(r.size.y / BACK_GAP)) if layer == &"back" else maxi(1, roundi(KNOT_STEMS * 0.5))
		var wide: Vector2 = BACK_WIDE if layer == &"back" else STEM_WIDE
		for half: float in [-inner, inner]:
			var bottom: Strand = null
			for i: int in range(count):
				k += 1
				var lowest: bool = layer == &"back" and i == count - 1
				var y_end: float = low if lowest else clampf(lerpf(top, low, (float(i) + 0.5) / float(count)) + (_deal(k) - 0.5) * 14.0, top, low)
				# A little past the middle, into the other side.
				var b: Vector2 = Vector2(cx - half * over, y_end)
				var a: Vector2
				var c: Vector2
				if half != inner:
					# Out of the wall, bowed up or down: the dark ones a little, packed close, the
					# stems across them.
					var slant: float = (STEM_SLANT if layer == &"stem" else BACK_SLANT) * (_deal(k + 0.3) - 0.5)
					var y_a: float = low if lowest else clampf(y_end + slant, top, low)
					a = Vector2(outer_x - inner * ANCHOR_IN, y_a)
					var bow: float = (STEM_BOW if layer == &"stem" else BACK_BOW) * r.size.y * (_deal(k + 0.6) - 0.5)
					c = (a + b) * 0.5 + Vector2(0.0, 0.0 if lowest else bow)
				else:
					# Out of the roof, down the landing's edge, then in across the middle.
					a = Vector2(lerpf(cx + inner * 8.0, inner_x - inner * 6.0, _deal(k + 0.3)), r.position.y - ANCHOR_IN)
					c = Vector2(lerpf(cx, inner_x, 0.85), lerpf(r.position.y, y_end, 0.9))
				var wander: float = 0.0 if lowest else (STEM_WANDER if layer == &"stem" else BACK_WANDER)
				var pts: PackedVector2Array = _wander(a, c, b, wander, float(k))
				var s: Strand = Strand.new(layer, half, pts, _thickness(pts.size(), lerpf(wide.x, wide.y, _deal(k + 0.9)), float(k)), _deal(k + 0.45))
				s.tear = _crossing(s, cx)
				if layer == &"stem":
					# A thorn now and then, on alternate edges, within the knot.
					var flip: float = 1.0 if k % 2 == 0 else -1.0
					for j: int in range(1, pts.size() - 1, 3):
						flip = -flip
						if r.grow(-4.0).has_point(pts[j]):
							s.thorns.append(Vector3(j, flip, 18.0 + 6.0 * _deal(k + float(j) * 0.11)))
					knot_stems.append(s)
					# A tendril or two, curling off its edges, on its own side of the middle.
					var sprouts: int = 1 + int(_deal(k + 0.81) * 1.99)
					for n: int in range(sprouts):
						var along: float = s.tear * lerpf(0.25, 0.75, _deal(k + 0.83 + float(n) * 0.17))
						_sprout(s, along, 1.0 if (k + n) % 2 == 0 else -1.0, lerpf(TENDRIL_LONG.x, TENDRIL_LONG.y, _deal(k + 0.87 + float(n) * 0.13)), TENDRIL_WIDE, float(k) + 0.5 + float(n) * 0.25, tendrils)
				else:
					knot_back.append(s)
					if lowest:
						bottom = s
			if bottom == null:
				continue
			# Along the underside, pointing down the shaft, on its own side of the middle.
			var count_under: int = maxi(3, int(r.size.x / 28.0))
			for n: int in range(count_under):
				var x: float = lerpf(r.position.x + 14.0, r.end.x - 14.0, (float(n) + 0.5) / float(count_under))
				if signf(x - cx) != half:
					continue
				var j: int = 0
				for m: int in range(1, bottom.pts.size()):
					if bottom.arc[m] < bottom.tear - 8.0 and bottom.pts[m].distance_to(Vector2(x, r.end.y)) < bottom.pts[j].distance_to(Vector2(x, r.end.y)):
						j = m
				bottom.thorns.append(Vector3(j, 0.0, 24.0 + 14.0 * RisoShapes.hash1(float(n) + float(level_seed % 97))))


## Its roots, one down the face of each wall (the left's first), from the knot to the lowest bulb or
## vine on it, which they grow from; anchored up in the knot. Each wanders off the rock face in two
## waves of hashed phase (ROOT_WAVES long), swells and narrows, and puts out a rootlet now and then,
## curling into the shaft.
func _grow_roots() -> void:
	roots.clear()
	rootlets.clear()
	for side: int in [0, 1]:
		var wall_x: float = center(Vector2i(inside.position.x - 1 if side == 0 else inside.end.x, 0)).x
		var out: float = 1.0 if side == 0 else -1.0
		var low: float = knot_rect.end.y
		for vine: BrambleVine in vines:
			if signf(vine.way.x) == out:
				low = maxf(low, vine.global_position.y)
		for bulb: BrambleBulb in bulbs:
			if signf(bulb.way.x) == out:
				low = maxf(low, bulb.global_position.y)
		var k: float = 500.0 + float(side) * 10.0
		var p1: float = _deal(k + 0.1) * TAU
		var p2: float = _deal(k + 0.2) * TAU
		var pts: PackedVector2Array = PackedVector2Array()
		var widths: PackedFloat32Array = PackedFloat32Array()
		var y: float = knot_rect.position.y + 20.0
		while y <= low + 16.0:
			var taper: float = clampf((low + 16.0 - y) / 120.0, 0.25, 1.0)
			var wave: float = 0.6 * sin(y * TAU / ROOT_WAVES.x + p1) + 0.4 * sin(y * TAU / ROOT_WAVES.y + p2)
			pts.append(Vector2(wall_x + out * (cell * 0.5 + ROOT_SWAY * (0.5 + 0.5 * wave)), y))
			widths.append(ROOT_WIDTH * taper * (0.75 + 0.25 * sin(y * TAU / ROOT_WAVES.y * 1.3 + p1)))
			y += 10.0
		var root: Strand = Strand.new(&"root", 0.0, pts, widths, _deal(k))
		root.wall = out
		roots.append(root)
		# Rootlets, curling off into the shaft.
		var n: int = 0
		var along: float = ROOTLET_EVERY * (0.6 + 0.6 * _deal(k + 0.3))
		while along < root.length - 40.0:
			var j: int = clampi(roundi(along / 10.0), 1, root.pts.size() - 1)
			var into: float = 1.0 if _across(root.pts, j).x * out > 0.0 else -1.0
			_sprout(root, along, into, lerpf(ROOTLET_LONG.x, ROOTLET_LONG.y, _deal(k + 0.4 + float(n) * 0.07)), ROOTLET_WIDE * minf(1.0, root.widths[j] / ROOT_WIDTH + 0.3), k + 1.0 + float(n), rootlets)
			n += 1
			along += ROOTLET_EVERY * (0.7 + 0.6 * _deal(k + 0.5 + float(n) * 0.07))


## Withered vine `vine` (the `i`th) as a strand: its dry curl out of the rock.
func _curl_strand(vine: BrambleVine, i: int) -> Strand:
	var xf: Transform2D = Transform2D(vine.way.angle(), vine.global_position)
	var pts: PackedVector2Array = PackedVector2Array()
	var widths: PackedFloat32Array = PackedFloat32Array()
	for n: int in range(9):
		var a: float = -0.4 + float(n) * 0.35
		pts.append(xf * Vector2(10.0 + 15.0 * sin(a), -14.0 + 15.0 * cos(a)))
		widths.append(6.0)
	return Strand.new(&"curl", 0.0, pts, widths, _deal(600.0 + float(i)))


## When strand `s` dries and draws back, the dry front setting out from `from`. A tendril or
## rootlet dries with its vine, and is in before the vine's tip draws back past it.
func _time(s: Strand, from: Vector2) -> void:
	if s.parent != null:
		s.dry_at = s.parent.dry_at
		s.back_at = s.parent.back_at
		s.back_time = maxf(0.1, s.parent.back_time * (1.0 - s.base_arc / maxf(_full(s.parent), 1.0)) * 0.8)
		return
	var near: float = INF
	for p: Vector2 in s.pts:
		near = minf(near, p.distance_to(from))
	s.dry_at = near / DRY_SPEED + DRY_JITTER * s.salt
	s.back_at = s.dry_at + BACK_DELAY + BACK_JITTER * s.salt
	s.back_time = BACK_MIN + _full(s) / BACK_SPEED


## How far strand `s` has dried (x) and drawn back (y), each 0 to 1, so far into its death.
func withering(s: Strand) -> Vector2:
	if not dying:
		return Vector2.ZERO
	return Vector2(clampf((dying_t - s.dry_at) / DRY_TIME, 0.0, 1.0), smoothstep(0.0, 1.0, (dying_t - s.back_at) / s.back_time))


## How long strand `s` is: a knot vine, once the knot splits, only as far as the middle, where it
## tore.
func _full(s: Strand) -> float:
	return s.tear if split > 0.0 or dying else s.length


## How much of strand `s` is out of the rock now (px).
func reach(s: Strand) -> float:
	return _full(s) * (1.0 - withering(s).y)


## The point `along` px out along strand `s`, as it lies at rest.
func strand_at(s: Strand, along: float) -> Vector2:
	for j: int in range(1, s.pts.size()):
		if along <= s.arc[j]:
			return s.pts[j - 1].lerp(s.pts[j], (along - s.arc[j - 1]) / maxf(s.arc[j] - s.arc[j - 1], 0.001))
	return s.pts[s.pts.size() - 1]


## Strand `s` as it lies now: pulled `gap` px toward its side by the split (the more, the further
## from its anchor; a tendril as far as where it grows), and only `keep` px of it out of the rock.
## [its points, how far along each is]
func _pose(s: Strand, gap: float, keep: float) -> Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var arc: PackedFloat32Array = PackedFloat32Array()
	for j: int in range(s.pts.size()):
		var pull: float = s.base_arc / maxf(s.parent.length, 1.0) if s.parent != null else s.arc[j] / maxf(s.length, 1.0)
		var p: Vector2 = s.pts[j] + Vector2(s.side * gap * pull, 0.0)
		if j == 0 or s.arc[j] <= keep:
			pts.append(p)
			arc.append(s.arc[j])
			continue
		var u: float = (keep - s.arc[j - 1]) / maxf(s.arc[j] - s.arc[j - 1], 0.001)
		pts.append(pts[pts.size() - 1].lerp(p, u))
		arc.append(keep)
		break
	return [pts, arc]


## Strand `s`'s width `along` px out.
func _width_at(s: Strand, along: float) -> float:
	for j: int in range(1, s.arc.size()):
		if along <= s.arc[j]:
			return lerpf(s.widths[j - 1], s.widths[j], (along - s.arc[j - 1]) / maxf(s.arc[j] - s.arc[j - 1], 0.001))
	return s.widths[s.widths.size() - 1]


## The way across points `pts` at point `j` (a unit vector).
static func _across(pts: PackedVector2Array, j: int) -> Vector2:
	var a: Vector2 = pts[maxi(j - 1, 0)]
	var b: Vector2 = pts[mini(j + 1, pts.size() - 1)]
	return (b - a).normalized().orthogonal()


## The outline of strand `s` laid along `pts` (`arc` along it): as wide as it is there, thinner and
## crinkled by `dry`, its end pointed by `point` (0 blunt, 1 to a point).
func _outline(s: Strand, pts: PackedVector2Array, arc: PackedFloat32Array, dry: float, point: float) -> PackedVector2Array:
	var top: PackedVector2Array = PackedVector2Array()
	var low: PackedVector2Array = PackedVector2Array()
	for j: int in range(pts.size()):
		var across: Vector2 = _across(pts, j)
		var w: float = _width_at(s, arc[j]) * 0.5 * (1.0 - DRY_THIN * dry)
		if j == pts.size() - 1:
			w *= lerpf(1.0, 0.35, point)
		var mid: Vector2 = pts[j] + across * sin(arc[j] * 0.4 + s.salt * 10.0) * DRY_CRINKLE * dry
		top.append(mid + across * w)
		low.append(mid - across * w)
	low.reverse()
	top.append_array(low)
	return top


## Thorn `th` of a strand laid along `pts`, `w` px wide: out of its edge (or straight down the shaft,
## from the underside), drooping back toward the strand's anchor as it dries (`dry`).
static func _thorn(pts: PackedVector2Array, th: Vector3, w: float, dry: float) -> PackedVector2Array:
	var j: int = int(th.x)
	var along: Vector2 = (pts[mini(j + 1, pts.size() - 1)] - pts[maxi(j - 1, 0)]).normalized()
	var out: Vector2 = Vector2.DOWN if th.y == 0.0 else _across(pts, j) * th.y
	var base: Vector2 = pts[j] + out * w * (0.35 if th.y == 0.0 else 0.45)
	var foot: float = 11.0 if th.y == 0.0 else 9.0
	var side: Vector2 = out.orthogonal() * foot
	var long: float = th.z * (1.0 - 0.2 * dry)
	var tip: Vector2 = base + out * long * (1.0 - 0.35 * dry) - along * long * 0.55 * dry
	return PackedVector2Array([base - side, tip, base + side])


# ------------------------------------------------------------------ the print

## Its roots down the walls, the vines, the bulbs, and the knot over them all: bark in blue and
## night, thorns and vines in pink (danger), bulbs in accent (its weak points). Dying, every vine
## pales and draws back into the rock.
func _process(delta: float) -> void:
	t += delta
	if ink == null or inside.size == Vector2i.ZERO:
		return
	ink.global_position = Vector2.ZERO
	ink.begin()
	_draw_strands(roots)
	_draw_strands(rootlets)
	for vine: BrambleVine in vines:
		# Dying, a withered vine's curl is one of its strands.
		if not (dying and vine.length < 2.0):
			_draw_vine(vine)
	_draw_strands(curls)
	for bulb: BrambleBulb in bulbs:
		_draw_bulb(bulb)
	_draw_knot()
	_draw_bud()
	_draw_sap()
	ink.finish()


## Strands `list` (all of one kind) as they are now: the knot's pulled apart by its split, and
## dying, each dried and drawn back as far as its death has come; with their thorns. The knot's dark
## vines print one by one, each over those before it, so where they cross their ink is laid once,
## not over itself; the rest print together by how dry they are, DRY_STEPS steps.
func _draw_strands(list: Array[Strand]) -> void:
	if list.is_empty():
		return
	var kind: StringName = list[0].kind
	var gap: float = knot_rect.size.x * SPLIT_PULL * split if kind == &"back" or kind == &"stem" else 0.0
	var point: float = 1.0 if dying else (split if gap > 0.0 else 0.0)
	var one_by_one: bool = kind == &"back"
	var bodies: Array = []
	var spikes: Array = []
	for _i: int in range(DRY_STEPS + 1):
		var none: Array[PackedVector2Array] = []
		var none2: Array[PackedVector2Array] = []
		bodies.append(none)
		spikes.append(none2)
	for s: Strand in list:
		# A tendril grows only where its vine is: not on the far side of a tear, nor once the vine
		# has drawn back past it.
		if s.parent != null and s.base_arc > reach(s.parent) - 2.0:
			continue
		var state: Vector2 = withering(s)
		var keep: float = _full(s) * (1.0 - state.y)
		if keep < 1.5:
			continue
		var pose: Array = _pose(s, gap, keep)
		var pts: PackedVector2Array = pose[0]
		var arc: PackedFloat32Array = pose[1]
		if pts.size() < 2:
			continue
		var step: int = roundi(state.x * float(DRY_STEPS))
		var dry: float = float(step) / float(DRY_STEPS)
		var body: Array[PackedVector2Array] = [_outline(s, pts, arc, dry, point)]
		var spike: Array[PackedVector2Array] = []
		for th: Vector3 in s.thorns:
			var j: int = int(th.x)
			# A thorn goes into the rock with the vine, a little ahead of its tip.
			if j >= pts.size() - 1 or s.arc[j] > keep - 6.0:
				continue
			spike.append(_thorn(pts, th, _width_at(s, s.arc[j]) * (1.0 - DRY_THIN * dry), dry))
		if one_by_one:
			_ink_strands(kind, body, spike, dry)
		else:
			(bodies[step] as Array[PackedVector2Array]).append_array(body)
			(spikes[step] as Array[PackedVector2Array]).append_array(spike)
	if one_by_one:
		return
	for step: int in range(DRY_STEPS + 1):
		_ink_strands(kind, bodies[step], spikes[step], float(step) / float(DRY_STEPS))


## Print strands of kind `kind`, their shapes `body` and their thorns `spike`, `dry` dried: bark in
## blue and night over the dark ground (the knot's dark vines darker, as the knot's depths), thorns
## in pink; dry, the bark pales and the thorns go straw-pale.
func _ink_strands(kind: StringName, body: Array[PackedVector2Array], spike: Array[PackedVector2Array], dry: float) -> void:
	if not body.is_empty():
		match kind:
			&"back":
				ink.lift_ink([RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.BLUE, RisoPrint.NIGHT], 1.0, body)
				ink.ink(RisoPrint.BLUE, lerpf(KNOT_BLUE, DRY_BACK_BLUE, dry), body, false)
				ink.ink(RisoPrint.NIGHT, lerpf(KNOT_NIGHT, DRY_BACK_NIGHT, dry), body, false)
			&"stem":
				ink.lift_ink([RisoPrint.NIGHT], 1.0, body)
				ink.ink(RisoPrint.BLUE, lerpf(BARK_BLUE, DRY_BLUE, dry), body)
				ink.ink(RisoPrint.NIGHT, 0.1 * (1.0 - dry), body, false)
			&"root":
				ink.lift_ink([RisoPrint.NIGHT], 1.0, body)
				ink.ink(RisoPrint.BLUE, lerpf(BARK_BLUE, DRY_BLUE, dry), body)
				ink.ink(RisoPrint.NIGHT, 0.3 * (1.0 - dry), body, false)
			_:
				ink.lift_ink([RisoPrint.NIGHT], 1.0, body)
				ink.ink(RisoPrint.BLUE, lerpf(0.7, DRY_BLUE, dry), body)
				ink.ink(RisoPrint.NIGHT, lerpf(0.45, 0.1, dry), body, false)
	if not spike.is_empty():
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 1.0, spike)
		ink.ink(RisoPrint.PINK, lerpf(1.0, DRY_PINK, dry), spike)
		ink.ink(RisoPrint.BLUE, DRY_THORN_BLUE * dry, spike, false)


## A vine: out, a pink stem tapering from its root with thorns along both edges and a hooked tip,
## writhing; warning, pink shoots poking out of the rock, trembling; resting or recoiled, a dark
## bud at its root; withered, a short dry curl.
func _draw_vine(vine: BrambleVine) -> void:
	var root: Vector2 = vine.global_position
	var xf: Transform2D = Transform2D(vine.way.angle(), root)
	if vine.withered and vine.length < 2.0:
		var curl: PackedVector2Array = PackedVector2Array()
		for n: int in range(9):
			var a: float = -0.4 + float(n) * 0.35
			curl.append(Vector2(10.0 + 18.0 * sin(a), -14.0 + 18.0 * cos(a)))
		for n: int in range(8, -1, -1):
			var a: float = -0.4 + float(n) * 0.35
			curl.append(Vector2(10.0 + 12.0 * sin(a), -14.0 + 12.0 * cos(a)))
		ink.lift_ink([RisoPrint.NIGHT], 1.0, [xf * curl])
		ink.ink(RisoPrint.BLUE, 0.7, [xf * curl])
		ink.ink(RisoPrint.NIGHT, 0.45, [xf * curl], false)
		return
	var bud: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(5.0, 0.0), 13.0, 20.0, 14)
	ink.ink(RisoPrint.BLUE, BARK_BLUE, [bud])
	ink.ink(RisoPrint.NIGHT, BARK_NIGHT, [bud], false)
	var state: Array = vine.phase()
	if vine.length < 2.0:
		if state[0] == &"warn" and not vine.recoiled():
			var u: float = state[1]
			var shoots: Array[PackedVector2Array] = []
			for n: int in range(3):
				var ang: float = (float(n) - 1.0) * 0.6 + 0.08 * sin(t * 37.0 + float(n) * 2.0)
				var tip: float = 22.0 + 34.0 * u
				var dir: Vector2 = Vector2.from_angle(ang)
				var side: Vector2 = dir.orthogonal() * 9.0
				shoots.append(xf * PackedVector2Array([side, dir * tip, -side]))
			ink.ink(RisoPrint.PINK, 0.55 + 0.45 * absf(sin(t * 14.0)), shoots)
		return
	# The stem, writhing, from the rock out to its tip.
	var length: float = vine.length
	var steps: int = maxi(4, ceili(length / 10.0))
	var top: PackedVector2Array = PackedVector2Array()
	var bottom: PackedVector2Array = PackedVector2Array()
	var spine: Array[Vector2] = []
	for n: int in range(steps + 1):
		var x: float = length * float(n) / float(steps)
		var k: float = x / maxf(length, 1.0)
		var y: float = sin(x * 0.04 - t * 9.0) * 9.0 * k
		var half: float = lerpf(STEM_ROOT, STEM_TIP, k)
		spine.append(Vector2(x, y))
		top.append(Vector2(x, y - half))
		bottom.append(Vector2(x, y + half))
	bottom.reverse()
	top.append_array(bottom)
	var thorns: Array[PackedVector2Array] = []
	var along: float = THORN_EVERY * 0.6
	var flip: float = 1.0
	while along < length - 4.0:
		var k: float = along / maxf(length, 1.0)
		var at: Vector2 = Vector2(along, sin(along * 0.04 - t * 9.0) * 9.0 * k)
		var half: float = lerpf(STEM_ROOT, STEM_TIP, k)
		var base: Vector2 = at + Vector2(0, flip * (half - 2.0))
		thorns.append(PackedVector2Array([base + Vector2(-9.0, 0), base + Vector2(5.0, flip * THORN_LEN), base + Vector2(9.0, 0)]))
		flip = -flip
		along += THORN_EVERY * 0.5
	# A hooked tip.
	var end: Vector2 = spine[spine.size() - 1]
	thorns.append(PackedVector2Array([end + Vector2(-7.0, -7.0), end + Vector2(18.0, -4.0), end + Vector2(4.0, 11.0)]))
	var stem: Array[PackedVector2Array] = [xf * top]
	var spikes: Array[PackedVector2Array] = []
	for th: PackedVector2Array in thorns:
		spikes.append(xf * th)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 1.0, stem)
	ink.ink(RisoPrint.PINK, 0.8, stem)
	ink.ink(RisoPrint.NIGHT, 0.2, stem, false)
	ink.ink(RisoPrint.PINK, 1.0, spikes)


## The root down the wall bulb `bulb` sits in (the way out of its wall), or null.
func root_of(bulb: BrambleBulb) -> Strand:
	for root: Strand in roots:
		if root.wall == signf(bulb.way.x):
			return root
	return null


## A bulb: a swelling teardrop of accent out of the rock face, cupped in bark, a paper gleam on it
## and its hits left as dark dots; it swells as it readies a seed and flashes pink when struck.
## Shut (not in bloom), it is smaller and dimmer, and two sepals of bark close over it; they fold
## back against the wall as it blooms. Burst: a shrivelled husk, its petals flying for a moment;
## as the bramble dies, it dries with its root and is pulled into the wall as the root draws back
## past it.
func _draw_bulb(bulb: BrambleBulb) -> void:
	var base: Vector2 = bulb.global_position - bulb.way * BrambleBulb.OUT
	var xf: Transform2D = Transform2D(bulb.way.angle(), base)
	if not bulb.alive:
		var dry: float = 0.0
		if dying:
			var root: Strand = root_of(bulb)
			if root != null:
				var tip: Vector2 = strand_at(root, reach(root))
				var pull: float = clampf((tip.y - bulb.global_position.y + HUSK_PULL) / HUSK_PULL, 0.0, 1.0)
				if pull <= 0.01:
					return
				xf = xf * Transform2D.IDENTITY.scaled(Vector2(pull, pull))
				dry = withering(root).x
		var cup0: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(7.0, 0.0), 20.0, BULB_R * 0.9, 16)
		var since: float = t - bulb.burst_t
		var husk: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(18.0, 0.0), 20.0, 15.0, 14)
		ink.lift_ink([RisoPrint.NIGHT], 1.0, [cup0, husk])
		ink.ink(RisoPrint.BLUE, lerpf(BARK_BLUE, DRY_BLUE, dry), [cup0, husk])
		ink.ink(RisoPrint.NIGHT, 0.6 * (1.0 - dry), [cup0], false)
		ink.ink(RisoPrint.NIGHT, 0.35 * (1.0 - dry), [husk], false)
		if since < BURST_TIME:
			var u: float = since / BURST_TIME
			var petals: Array[PackedVector2Array] = []
			for n: int in range(5):
				var dir: Vector2 = Vector2.from_angle((float(n) - 2.0) * 0.55)
				petals.append(xf * RisoShapes.ellipse(Vector2(22.0, 0.0) + dir * (25.0 + 70.0 * u), 13.0 * (1.0 - u), 7.0 * (1.0 - u), 10, dir.angle()))
			ink.ink(RisoPrint.ACCENT, 1.0 - u, petals)
		return
	var cup: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(7.0, 0.0), 20.0, BULB_R * 0.9, 16)
	var open: float = bulb.opened
	var swell: float = 1.0 + BULB_SWELL * bulb.charge * bulb.charge + 0.04 * sin(t * 3.0 + float(bulb.cell.y))
	var r: float = BULB_R * swell * lerpf(SHUT_SIZE, 1.0, open)
	var body: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(BrambleBulb.OUT * swell, 0.0), r * 0.95, r, 22)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 1.0, [body])
	ink.ink(RisoPrint.ACCENT, lerpf(SHUT_ACCENT, 1.0, open), [body])
	var flash: float = clampf(1.0 - (t - bulb.struck_t) / FLASH_TIME, 0.0, 1.0)
	if flash > 0.0:
		ink.ink(RisoPrint.PINK, 0.8 * flash, [body], false)
	# Its gleam, toward the open shaft.
	ink.lift_ink([RisoPrint.ACCENT], 0.7 * open, [xf * RisoShapes.ellipse(Vector2(BrambleBulb.OUT * swell + r * 0.3, -r * 0.35), r * 0.22, r * 0.14, 10, 0.5)])
	ink.ink(RisoPrint.BLUE, BARK_BLUE, [cup])
	ink.ink(RisoPrint.NIGHT, BARK_NIGHT, [cup], false)
	# Its hits left, as dark dots down its middle.
	var dots: Array[PackedVector2Array] = []
	var n: int = bulb.hits_left()
	for j: int in range(n):
		var off: float = (float(j) - float(n - 1) * 0.5) * r * 0.5
		dots.append(xf * RisoShapes.circle(Vector2(BrambleBulb.OUT * swell + 2.0, off), r * 0.13, 8))
	ink.ink(RisoPrint.NIGHT, 0.85, dots, false)
	# Its sepals: closed over it while shut, folded back against the wall in bloom, and blue-bright
	# for a moment when a blow glances off them.
	if open < 0.99:
		var sepals: Array[PackedVector2Array] = []
		for side: float in [-1.0, 1.0]:
			var hinge: Vector2 = Vector2(4.0, side * BULB_R * SEPAL_HINGE)
			var leaf: Transform2D = Transform2D(lerpf(-side * SEPAL_SHUT, side * SEPAL_OPEN, open), hinge)
			sepals.append(xf * (leaf * RisoShapes.almond(Vector2(BULB_R * 0.95, 0.0), BULB_R, BULB_R * SEPAL_WIDE, 14)))
		var glance: float = clampf(1.0 - (t - bulb.warded_t) / FLASH_TIME, 0.0, 1.0)
		var shut: float = 1.0 - open
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.ACCENT], shut, sepals)
		ink.ink(RisoPrint.BLUE, (BARK_BLUE - 0.4 * glance) * shut, sepals)
		ink.ink(RisoPrint.NIGHT, BARK_NIGHT * (1.0 - glance) * shut, sepals, false)


## The knot: a tangle of vines filling the head of the shaft (dark ones packed close, bark stems
## over them bristling with pink thorns, the longest along its underside, tendrils curling off), and a row of accent pips
## on a dark knot-hole, one for each bulb (dark once burst). Split round its heart, its halves part
## a little; dying, its vines pale and draw back into the rock.
func _draw_knot() -> void:
	var r: Rect2 = knot_rect
	_draw_strands(knot_back)
	_draw_strands(knot_stems)
	_draw_strands(tendrils)
	if dying or heart != null:
		return
	# Its health: a pip for each bulb, in a row on a dark knot-hole low on the knot.
	var n: int = bulbs.size()
	var mid: Vector2 = Vector2(r.get_center().x, r.end.y - 46.0)
	var hole: PackedVector2Array = RisoShapes.rrect(mid.x - float(n) * 15.0 - 6.0, mid.y - 17.0, float(n) * 30.0 + 12.0, 34.0, 17.0)
	ink.knock([RisoPrint.BLUE], [hole])
	ink.ink(RisoPrint.NIGHT, 1.0, [hole], false)
	var lit: Array[PackedVector2Array] = []
	var out: Array[PackedVector2Array] = []
	for i: int in range(n):
		var pip: PackedVector2Array = RisoShapes.circle(mid + Vector2((float(i) - float(n - 1) * 0.5) * 30.0, 0.0), 10.0, 14)
		if bulbs[i].alive:
			lit.append(pip)
		else:
			out.append(pip)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], lit)
	ink.ink(RisoPrint.ACCENT, 1.0, lit)
	ink.ink(RisoPrint.BLUE, 0.5, out, false)


## The heart, once bared: in the split down the knot's middle a dark hollow, and hanging from it a
## bud, growing as the knot splits: a long teardrop of accent, point down, wrapped by two long
## sepals of bark hugging its sides and two shorter, paler ones within, a pink thorn at each long
## one's tip, under a cap of bark on a short stem out of the knot. Its accent shows down the
## middle, with a paper gleam and its hits left as dark dots. With each beat it swells and its
## sepals part a little; struck, it flashes pink. Beside it, the tip of the next barb poking out of
## the knot's underside, pink and trembling, as it warns.
func _draw_bud() -> void:
	if heart == null or dying:
		return
	var r: Rect2 = knot_rect
	var gap: float = r.size.x * SPLIT_PULL * split * 2.0
	# The split: a hollow narrowing up into the knot from its underside.
	var cx: float = r.get_center().x
	var hollow: PackedVector2Array = PackedVector2Array([Vector2(cx - gap * 0.15, r.position.y + r.size.y * 0.3), Vector2(cx + gap * 0.15, r.position.y + r.size.y * 0.3), Vector2(cx + gap * 0.5 + 6.0, r.end.y), Vector2(cx - gap * 0.5 - 6.0, r.end.y)])
	ink.knock([RisoPrint.BLUE], [hollow])
	ink.ink(RisoPrint.NIGHT, 0.6, [hollow], false)
	if heart.alive:
		var beat: float = pow(maxf(0.0, sin(t / HEART_BEAT * TAU)), 4.0)
		var grow: float = 0.35 + 0.65 * split
		var long: float = BUD_LONG * grow * (1.0 + 0.04 * beat)
		var wide: float = BUD_WIDE * grow * (1.0 + 0.06 * beat)
		var top: float = r.end.y - BUD_TOP
		var body: PackedVector2Array = _teardrop(Vector2(cx, top), long, wide)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 1.0, [body])
		ink.ink(RisoPrint.ACCENT, 1.0, [body])
		ink.ink(RisoPrint.PINK, 0.15 * beat, [body], false)
		var flash: float = clampf(1.0 - (t - heart.struck_t) / FLASH_TIME, 0.0, 1.0)
		if flash > 0.0:
			ink.ink(RisoPrint.PINK, 0.8 * flash, [body], false)
		ink.lift_ink([RisoPrint.ACCENT], 0.7, [RisoShapes.ellipse(Vector2(cx - wide * 0.18, top + long * 0.36), wide * 0.08, wide * 0.13, 12, 0.3)])
		# Its sepals and cap, parting with the beat.
		var part: float = BUD_SPREAD + BUD_PART * beat
		var outer: Array[PackedVector2Array] = []
		var within: Array[PackedVector2Array] = []
		var thorns: Array[PackedVector2Array] = []
		for s: float in [-1.0, 1.0]:
			var base: Vector2 = Vector2(cx + s * wide * 0.16, top + 2.0)
			outer.append(_leaf(base, long * 0.86, wide * 0.3, -s * part))
			within.append(_leaf(Vector2(cx + s * wide * 0.1, top + 2.0), long * 0.42, wide * 0.22, -s * (0.06 + 0.5 * (part - BUD_SPREAD))))
			var down: Vector2 = Vector2.DOWN.rotated(-s * part)
			var tip: Vector2 = base + down * (long * 0.86 + 2.0)
			thorns.append(PackedVector2Array([tip - down.orthogonal() * 4.0 - down * 4.0, tip + down * 14.0, tip + down.orthogonal() * 4.0 - down * 4.0]))
		var stem: PackedVector2Array = PackedVector2Array([Vector2(cx - 9.0, r.end.y - 30.0), Vector2(cx + 9.0, r.end.y - 30.0), Vector2(cx + 7.0, top + 10.0), Vector2(cx - 7.0, top + 10.0)])
		var cap: PackedVector2Array = RisoShapes.ellipse(Vector2(cx, top + 8.0), wide * 0.24, 12.0 * grow, 20)
		var dark: Array[PackedVector2Array] = outer.duplicate()
		dark.append_array([stem, cap])
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.ACCENT], 1.0, dark)
		ink.ink(RisoPrint.BLUE, BARK_BLUE, dark)
		ink.ink(RisoPrint.NIGHT, BARK_NIGHT, dark, false)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.ACCENT], 1.0, within)
		ink.ink(RisoPrint.BLUE, BARK_BLUE, within)
		ink.ink(RisoPrint.NIGHT, 0.1, within, false)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 1.0, thorns)
		ink.ink(RisoPrint.PINK, 1.0, thorns)
		var dots: Array[PackedVector2Array] = []
		var n: int = heart.hits_left()
		for j: int in range(n):
			dots.append(RisoShapes.circle(Vector2(cx + (float(j) - float(n - 1) * 0.5) * wide * 0.14, top + long * 0.6), wide * 0.048, 8))
		ink.ink(RisoPrint.NIGHT, 0.85, dots, false)
	var warn: float = heart.warning()
	if warn >= 0.0:
		var x: float = heart.barb_x + 2.0 * sin(t * 40.0)
		var foot: float = r.end.y - 10.0
		var tip2: PackedVector2Array = RisoShapes.tri(Vector2(x - WARN_WIDE, foot), Vector2(x, foot + lerpf(WARN_LONG.x, WARN_LONG.y, warn)), Vector2(x + WARN_WIDE, foot))
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 1.0, [tip2])
		ink.ink(RisoPrint.PINK, 0.6 + 0.4 * absf(sin(t * 16.0)), [tip2])


## A teardrop hanging point down from `top`, `long` long and `wide` across at its widest: a narrow
## neck, widest a little under it, drawn to a point.
static func _teardrop(top: Vector2, long: float, wide: float) -> PackedVector2Array:
	var right: PackedVector2Array = PackedVector2Array()
	var left: PackedVector2Array = PackedVector2Array()
	var n: int = 32
	for i: int in range(n + 1):
		var u: float = float(i) / float(n)
		var w: float = wide * 0.5 * pow(sin(PI * u), 0.75) * (1.2 - 0.65 * u)
		right.append(top + Vector2(w, u * long))
		left.append(top + Vector2(-w, u * long))
	left.reverse()
	right.append_array(left)
	return right


## A leaf (a sepal) from `base`, `long` long and `wide` across, hanging down turned `rot` radians.
static func _leaf(base: Vector2, long: float, wide: float, rot: float) -> PackedVector2Array:
	var xf: Transform2D = Transform2D(rot, base)
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = 14
	for i: int in range(n + 1):
		var u: float = float(i) / float(n)
		out.append(xf * Vector2(pow(sin(PI * u), 0.85) * wide * 0.5, u * long))
	for i: int in range(n - 1, 0, -1):
		var u: float = float(i) / float(n)
		out.append(xf * Vector2(-pow(sin(PI * u), 0.85) * wide * 0.5, u * long))
	return out


## The sap on its way to the next bulb: a drop of accent running along the roots and through the
## knot, a few smaller drops trailing it.
func _draw_sap() -> void:
	if sap_to == null or sap_path.size() < 2:
		return
	var drops: Array[PackedVector2Array] = []
	for k: int in range(SAP_TRAIL + 1):
		drops.append(RisoShapes.circle(sap_at(float(k) * SAP_GAP), SAP_R * (1.0 - float(k) / float(SAP_TRAIL + 1)), 12))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 1.0, drops)
	ink.ink(RisoPrint.ACCENT, 1.0, drops)
