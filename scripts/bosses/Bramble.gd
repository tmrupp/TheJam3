class_name Bramble
extends Node2D
## The bramble (the garden's way up's boss, Bands): the boss of the garden's way up, fought in its gate level
## (docs/REGIONS_PLAN.md §6). The way up is a tall shaft of rock (BrambleShaft), and the bramble is
## rooted at its head: its crown, a tangle of thorned canes (BrambleTangle) walling off the head
## beside the landing the way on stands on, so nothing gets past it to the way on (the knot, a solid
## body under the canes, BrambleKnot). Its roots run down the shaft's walls to:
## - its bulbs (BrambleBulb), BrambleShaft.BULBS.x to BULBS.y of them set in the walls, its weak
##   points: each takes BULB_HP hits from bolts or dashes (any strike wounds them, even one that only
##   stuns), and spits seeds at the wizard that a parry turns back into it. Only one is in bloom at a
##   time (`bloom`), the lowest first: the rest are shut in their bark, and only their own seeds
##   parried back wound them. Each wound to the bloom (or its bursting) sends its sap on, up the
##   roots and, to the other wall, through the head (a pulse of accent along the way, SAP_SPEED), to
##   the living bulb nearest it by the roots, which blooms when it arrives; nothing moves it on but
##   the wizard's blows;
## - its thorn vines (BrambleVine), rooted in the walls between: they lash out across the shaft and
##   pull back on a cadence, so the climb up the shaft's ledges is a matter of timing. A parried lash
##   recoils and stays back a while. Each vine feeds from the bulb nearest it, and withers when that
##   bulb bursts.
## Each bulb burst raises its fury (`fury`): the bulbs left spit sooner and, from
## BrambleBulb.TWIN_FURY, two seeds at once, and the vines left rest the shorter.
## Its crown is not grown until the wizard climbs near the head (WAKE_RANGE): then it grows out of
## the rock to close it. Struck anywhere (a bulb, its heart, a bolt into the crown), it quivers, the
## shudder running out along its canes from the blow. Hidden in the crown is its heart, a bud
## (_draw_bud): each bulb burst draws the canes back from round it a little (`bare`, up to PEEK),
## showing it; when the last bursts the canes draw right back to bare the bud (BrambleHeart,
## HEART_HP hits), which swells and drops down out of the crown, and it makes its last stand: every
## burst bulb opens again, wild, and spits seeds (no blow wounds a wild bulb), and every withered
## vine grows back and lashes again. Each wound to the heart shuts its sepals over it for a moment
## (BrambleHeart.SHUT_TIME). When the heart bursts the head of the shaft is open at once, and the
## bramble dies: its bulbs are husks again, its vines wither, a dry front runs out from the heart,
## each cane pales, thins and crinkles as it reaches it, then draws back into the rock it grew from,
## the husks of its bulbs and its heart pulled in with them, the roots last. When the last is in, it
## is slain, and its relic waits on the landing beside the way on (MapInfo.boss_slain), whose seal
## lifts. A lantern death brings it back whole, as the level reloads. Nothing here draws from the
## world RNG: the shaft and everything set in it come from the level's layout, and the rest is
## hashed from its seed.

const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## The hits each bulb takes.
const BULB_HP: int = 3
## How fast a bloom's sap runs to the next bulb (px a second), and the least time the run takes.
const SAP_SPEED: float = 1100.0
const SAP_MIN: float = 0.5
## The sap's pulse as printed: its radius (px), and how many drops trail it, how far apart (px).
const SAP_R: float = 12.0
const SAP_TRAIL: int = 4
const SAP_GAP: float = 16.0
## How near the knot (px) the wizard must climb, in the shaft, for its crown to grow; how much of the
## crown must be grown before its thorns hurt.
const WAKE_RANGE: float = 560.0
const THORNS_AT: float = 0.5
## The heart: the hits it takes, and how often it beats (seconds). How far its crown has drawn back
## from round it (`bare`, 0 to 1): PEEK once every bulb but the last has burst, a share for each
## before, and all the way once bared; it draws back BARE_TIME seconds for the whole way.
const HEART_HP: int = 4
const HEART_BEAT: float = 0.8
const PEEK: float = 0.4
const BARE_TIME: float = 1.2
## The heart is printed as a bud (_draw_bud): BUD_LONG long and BUD_WIDE across when bared, its cap
## BUD_TOP up inside the knot's underside, struck at BUD_MID of the way down it; hidden, it is
## BUD_HIDDEN of that size, tucked BUD_TUCK up in the knot, its accent BUD_DIM as strong. Its two
## long sepals flare BUD_SPREAD (radians) off it, and part BUD_PART more at each beat.
const BUD_LONG: float = 150.0
const BUD_WIDE: float = 116.0
const BUD_TOP: float = 60.0
const BUD_MID: float = 0.45
const BUD_HIDDEN: float = 0.55
const BUD_TUCK: float = 112.0
const BUD_DIM: float = 0.7
const BUD_SPREAD: float = 0.24
const BUD_PART: float = 0.12
## How hard (px, at the canes' tips) a blow makes the crown quiver: a bulb or the heart struck, a
## blow glancing off a bulb's bark, a bulb bursting, a bolt into the crown itself.
const QUIVER_STRUCK: float = 12.0
const QUIVER_WARDED: float = 5.0
const QUIVER_BURST: float = 22.0
const QUIVER_KNOT: float = 10.0
## A burst husk is pulled into the wall over this far (px) of its root's tip drawing back past it.
const HUSK_PULL: float = 40.0
## How far past the knot (px) its thorns hurt.
const KNOT_REACH: float = 10.0
## The bark of a bulb's cup and sepals, a bud's and a vine's: its covers of blue and night.
const BARK_BLUE: float = 0.9
const BARK_NIGHT: float = 0.55
## Dry, a husk's bark: how much blue it keeps.
const DRY_BLUE: float = 0.45
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
## The leaves shrouding a bulb (and a seed pod, PodArt), measured by the bulb as it is now (its
## radius 1, its middle at 0), so they swell with it: an upper and a lower leaf clasped round it,
## each rooted LEAF_ROOT_AT radians round from its front (behind the cup of bark, which they grow
## out from under), running LEAF_OUT out round it to a tip LEAF_TIP out and LEAF_TIP_AT radians past
## its middle, and back to the root along an inner edge bowed toward LEAF_CLASP (back toward the
## root and past the middle, for the upper leaf; the lower's mirrored), so the two overlap all the
## way to the cup and hide it whole; and behind each a narrower leaf, LEAF_BACK long and
## LEAF_BACK_WIDE across, standing out LEAF_BACK_AT radians from its way out. To bare it the clasped
## leaves swing back LEAF_SWING radians about their roots, the ones behind LEAF_BACK_SWING, all
## folding in to LEAF_FOLD of their size as they go, so they do not sprawl over the rock.
const LEAF_ROOT_AT: float = 2.6
const LEAF_OUT: float = 1.1
const LEAF_TIP: float = 1.24
const LEAF_TIP_AT: float = 0.14
const LEAF_CLASP: Vector2 = Vector2(-0.25, 0.7)
const LEAF_BACK: float = 1.45
const LEAF_BACK_WIDE: float = 0.42
const LEAF_BACK_AT: float = 0.95
const LEAF_SWING: float = 1.0
const LEAF_BACK_SWING: float = 0.5
const LEAF_FOLD: float = 0.8
## When they part: from LEAF_PART_FROM of the way to its next seed, wide apart as it spits, folding
## shut again over LEAF_CLOSE seconds after.
const LEAF_PART_FROM: float = 0.6
const LEAF_CLOSE: float = 0.4
## Their inks: the realm's green (blue) in full and a little night (the ones behind, the lower
## clasped leaf, the upper: darker further back), their midribs and veins lifted toward paper by
## LEAF_RIB and LEAF_VEIN, and how far they sway (radians).
const LEAF_BLUE: float = 1.0
const LEAF_NIGHT: PackedFloat32Array = [0.42, 0.32, 0.05]
const LEAF_RIB: float = 0.4
const LEAF_VEIN: float = 0.22
const LEAF_SWAY: float = 0.04
## How far into the shaft past the rock face the sap runs (px).
const SAP_OUT: float = 14.0
## A wild bulb (BrambleBulb.wild, the last stand): the pink screened over its accent, so it reads
## as a danger rather than a weak point.
const WILD_PINK: float = 0.45
## The heart shut (BrambleHeart.closed): how wide its outer sepals grow to close over it (a share of
## the bud's width).
const SHUT_WIDE: float = 0.62
const FLASH_TIME: float = 0.18
const BURST_TIME: float = 0.45
## A vine: its stem's half width at the root and at the tip (px), its thorns' spacing and length.
const STEM_ROOT: float = 16.0
const STEM_TIP: float = 5.0
const THORN_EVERY: float = 26.0
const THORN_LEN: float = 18.0

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
## The bulb in bloom (null while its sap runs to the next, and once all have burst).
var bloom: BrambleBulb = null
## The sap on its way: the bulb it runs to (null when none is), its way in pixels, how long that is,
## and how far along it is (0 to 1).
var sap_to: BrambleBulb = null
var sap_path: PackedVector2Array = PackedVector2Array()
var sap_len: float = 0.0
var sap_u: float = 0.0
## Its fury: a point for each bulb burst.
var fury: int = 0
## Its heart, once bared (null before), and how far its crown has drawn back from round it (0 to 1).
var heart: BrambleHeart = null
var bare: float = 0.0
## The knot's body (it walls off the head of the shaft) and its thorns' touch.
var knot: BrambleKnot
var knot_box: HitBox
## Its crown and roots, as they grow, quiver, draw back and die (BrambleTangle).
var tangle: BrambleTangle = BrambleTangle.new()
## Whether it is dying (the heart burst), the seconds since, the seconds its death takes (its last
## cane in), and whether it is slain.
var dying: bool = false
var dying_t: float = 0.0
var dying_end: float = 0.0
var slain: bool = false
var ink: InkCanvas
var t: float = 0.0
var level_seed: int = 0


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
	_grow_tangle()
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
	knot = BrambleKnot.new()
	knot.name = "Knot"
	knot.bramble = self
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
	# Its thorns hurt only once its crown has grown (see _physics_process).
	knot_box.collision.disabled = true


## Its crown over the knot and its roots down the walls, from the head to the lowest bulb or vine on
## each (BrambleTangle.grow).
func _grow_tangle() -> void:
	var walls: Array[float] = []
	var lows: Array[float] = []
	for side: int in [0, 1]:
		var out: float = 1.0 if side == 0 else -1.0
		walls.append(center(Vector2i(inside.position.x - 1 if side == 0 else inside.end.x, 0)).x + out * cell * 0.5)
		var low: float = knot_rect.end.y
		for vine: BrambleVine in vines:
			if signf(vine.way.x) == out:
				low = maxf(low, vine.global_position.y)
		for bulb: BrambleBulb in bulbs:
			if signf(bulb.way.x) == out:
				low = maxf(low, bulb.global_position.y)
		lows.append(low)
	var inner: float = 1.0 if relic_at.x >= knot_rect.get_center().x else -1.0
	tangle.grow(knot_rect, inner, knot_rect.get_center().x, knot_rect.end.y - BUD_TUCK, knot_rect.end.y - BUD_TOP, walls, lows, knot_rect.end.y, level_seed)


## Whether `at` (px) is in the shaft, from its foot up to the knot.
func in_shaft(at: Vector2) -> bool:
	var half: Vector2 = Vector2.ONE * cell * 0.5
	return Rect2(center(inside.position) - half, Vector2(inside.size) * cell).has_point(at)


## Its crown grows out of the rock now (the wizard has climbed near).
func wake() -> void:
	tangle.now = t
	tangle.wake()


## A blow `power` px hard at `at`: its crown and roots quiver from there.
func quiver(at: Vector2, power: float) -> void:
	tangle.now = t
	tangle.quiver(at, power)


## A bolt has struck the knot, heading `dir`: its crown quivers where it struck, as near the wizard
## as the knot reaches.
func struck_knot(dir: Vector2) -> void:
	var from: Vector2 = knot_rect.get_center() - dir * knot_rect.size.length()
	var player: Player = map_info.player if map_info != null else null
	if player != null and is_instance_valid(player):
		from = player.global_position
	quiver(Vector2(clampf(from.x, knot_rect.position.x, knot_rect.end.x), clampf(from.y, knot_rect.position.y, knot_rect.end.y)), QUIVER_KNOT)


## Bulb `bulb` blooms now, until it is wounded (the tests use it too).
func bloom_on(bulb: BrambleBulb) -> void:
	bloom = bulb
	sap_to = null
	sap_path = PackedVector2Array()


## Bulb or heart `bulb` has been wounded and lives: the bloom moves on from it (a heart shuts
## itself, BrambleHeart.struck).
func wounded(bulb: BrambleBulb) -> void:
	if bulb == bloom:
		_flow(bulb)


## The bloom leaves `from`: its sap runs to the living bulb nearest it along the roots (another,
## while there is one; else back to `from`), which blooms when it arrives.
func _flow(from: BrambleBulb) -> void:
	bloom = null
	var left: Array = bulbs.filter(func(b: BrambleBulb) -> bool: return b.alive and b != from)
	if left.is_empty() and from.alive:
		left = [from]
	if left.is_empty():
		return
	var next: BrambleBulb = LevelGen.best_of(left, func(b: BrambleBulb) -> float: return _length(_sap_path(from, b))) as BrambleBulb
	sap_to = next
	sap_path = _sap_path(from, next)
	sap_len = _length(sap_path)
	sap_u = 0.0


## How long a way is (px).
static func _length(way: PackedVector2Array) -> float:
	var long: float = 0.0
	for i: int in range(1, way.size()):
		long += way[i - 1].distance_to(way[i])
	return long


## The way the sap runs from bulb `a` to bulb `b` (px): along the wall's root when they share a
## wall, else up `a`'s root to the head, across under it, and down `b`'s.
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


## How far its crown should be drawn back from round its heart now: a share of PEEK for each bulb
## burst, and all the way once the heart is bared.
func bare_to() -> float:
	if heart != null:
		return 1.0
	if bulbs.is_empty():
		return 0.0
	return PEEK * float(fury) / float(maxi(bulbs.size() - 1, 1))


## Bulb `bulb` has burst: the vines it fed wither, its sap goes to the rest (fury) and, if it was
## in bloom, runs on to the next; with the last one the heart is bared. The heart burst, it dies.
func burst(bulb: BrambleBulb) -> void:
	if not bulb.alive:
		return
	bulb.pop()
	RisoFx.burst(&"gain", bulb.global_position, bulb.way, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(12.0, 0.25)
	quiver(bulb.global_position, QUIVER_BURST)
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


## The last bulb has burst: its crown draws back to bare its heart, and it makes its last stand:
## every bulb opens again, wild, and every vine grows back.
func _bare_heart() -> void:
	bloom = null
	sap_to = null
	wake()
	for bulb: BrambleBulb in bulbs:
		bulb.rouse()
	for vine: BrambleVine in vines:
		vine.rouse()
	heart = BrambleHeart.new(self, Vector2i(roundi((knot_rect.get_center().x - origin.x) / cell), roundi((knot_rect.end.y - origin.y) / cell)), Vector2.DOWN, HEART_HP)
	heart.name = "Heart"
	add_child(heart)
	heart.global_position = Vector2(knot_rect.get_center().x, knot_rect.end.y - BUD_TOP + BUD_LONG * BUD_MID)
	Wound.shake(14.0, 0.4)
	RisoFx.burst(&"hit", heart.global_position, Vector2.DOWN, [RisoPrint.ACCENT, RisoPrint.PINK])


## The heart has burst: nothing of it hurts now and the head of the shaft is open, and it dies from
## the heart out (BrambleTangle.die): every cane dries, then draws back into the rock.
func _open() -> void:
	dying = true
	dying_t = 0.0
	for bulb: BrambleBulb in bulbs:
		bulb.calm()
	for vine: BrambleVine in vines:
		vine.wither()
	for part: CollisionShape2D in [knot.get_child(0) as CollisionShape2D, knot_box.collision]:
		if part != null:
			part.set_deferred("disabled", true)
	var from: Vector2 = heart.global_position if heart != null else knot_rect.get_center()
	tangle.now = t
	tangle.wake()
	tangle.die(from)
	dying_end = tangle.end_time
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
	var player: Player = map_info.player if map_info != null else null
	if not tangle.awake() and player != null and is_instance_valid(player) and in_shaft(player.global_position) and player.global_position.distance_to(knot_rect.get_center()) <= WAKE_RANGE:
		wake()
	# Its thorns hurt once its crown has grown far enough.
	var off: bool = tangle.grown() < THORNS_AT
	if knot_box.collision != null and knot_box.collision.disabled != off:
		knot_box.collision.set_deferred("disabled", off)
	bare = move_toward(bare, bare_to(), delta / BARE_TIME)
	# A harder preset runs the sap on sooner (Difficulty.haste).
	if heart == null and sap_to != null:
		sap_u += delta * Difficulty.haste() * SAP_SPEED / maxf(sap_len, SAP_SPEED * SAP_MIN)
		if sap_u >= 1.0:
			bloom_on(sap_to)


## Slain at once (the F7 panel's Slay boss, MapInfo.slay_boss): every bulb bursts, and it dies
## without waiting for its canes to draw back.
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


# ------------------------------------------------------------------ the print

## Its roots down the walls, the vines, the bulbs, the bud in its hollow, and its crown over them
## all: bark in blue and night, thorns and vines in pink (danger), bulbs and the bud in accent (its
## weak points). Dying, every cane pales and draws back into the rock.
func _process(delta: float) -> void:
	t += delta
	tangle.now = t
	if ink == null or inside.size == Vector2i.ZERO:
		return
	ink.global_position = Vector2.ZERO
	ink.begin()
	tangle.set_hollow(_bud_middle(), _hollow_size())
	tangle.bud_y = _bud_top().y
	tangle.draw(ink, true)
	for vine: BrambleVine in vines:
		_draw_vine(vine)
	for bulb: BrambleBulb in bulbs:
		_draw_bulb(bulb)
	_draw_bud()
	tangle.draw(ink, false)
	_draw_sap()
	ink.finish()


## How far the husk or withered vine at `at`, on the wall its root faces `out` from, is still out of
## the rock as its root draws back past it, dying (1 out, 0 in).
func _root_pull(at: Vector2, out: float) -> float:
	if not dying:
		return 1.0
	var tip: Vector2 = tangle.root_tip(out)
	if not tip.is_finite():
		return 1.0
	return clampf((tip.y - at.y + HUSK_PULL) / HUSK_PULL, 0.0, 1.0)


## How dry a husk or withered vine at `at` is, dying (0 to 1): as dry as the root beside it.
func _dry_at(at: Vector2) -> float:
	if not dying:
		return 0.0
	return clampf((dying_t - at.distance_to(tangle.dry_from) / BrambleTangle.DRY_SPEED) / BrambleTangle.DRY_TIME, 0.0, 1.0)


## A vine: out, a pink stem tapering from its root with thorns along both edges and a hooked tip,
## writhing; warning, pink shoots poking out of the rock, trembling; resting or recoiled, a dark
## bud at its root; withered, a short dry curl, drying and pulled into the rock with its root as
## the bramble dies.
func _draw_vine(vine: BrambleVine) -> void:
	var root: Vector2 = vine.global_position
	var xf: Transform2D = Transform2D(vine.way.angle(), root)
	if vine.withered and vine.length < 2.0:
		var pull: float = _root_pull(root, signf(vine.way.x))
		if pull <= 0.01:
			return
		var dry: float = _dry_at(root)
		xf = xf * Transform2D.IDENTITY.scaled(Vector2(pull, pull))
		var curl: PackedVector2Array = PackedVector2Array()
		for n: int in range(9):
			var a: float = -0.4 + float(n) * 0.35
			curl.append(Vector2(10.0 + 18.0 * sin(a), -14.0 + 18.0 * cos(a)))
		for n: int in range(8, -1, -1):
			var a: float = -0.4 + float(n) * 0.35
			curl.append(Vector2(10.0 + 12.0 * sin(a), -14.0 + 12.0 * cos(a)))
		ink.lift_ink([RisoPrint.NIGHT], 1.0, [xf * curl])
		ink.ink(RisoPrint.BLUE, lerpf(0.7, DRY_BLUE, dry), [xf * curl])
		ink.ink(RisoPrint.NIGHT, lerpf(0.45, 0.1, dry), [xf * curl], false)
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


## A bulb: a swelling teardrop of accent out of the rock face, cupped in bark, a paper gleam on it
## and its hits left as dark dots; it swells as it readies a seed and flashes pink when struck.
## Shut (not in bloom), it is smaller and dimmer, and two sepals of bark close over it; they fold
## back against the wall as it blooms. Burst: a shrivelled husk, its petals flying for a moment;
## as the bramble dies, it dries with its root and is pulled into the wall as the root draws back
## past it. Wild (the last stand), it is open again but screened with pink, no hits left on it, a
## blow glancing off it blue.
func _draw_bulb(bulb: BrambleBulb) -> void:
	var base: Vector2 = bulb.global_position - bulb.way * BrambleBulb.OUT
	var xf: Transform2D = Transform2D(bulb.way.angle(), base)
	if not bulb.alive and not bulb.wild:
		var pull: float = _root_pull(bulb.global_position, signf(bulb.way.x))
		if pull <= 0.01:
			return
		var dry: float = _dry_at(bulb.global_position)
		xf = xf * Transform2D.IDENTITY.scaled(Vector2(pull, pull))
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
	ink_bulb(ink, xf, bulb.opened, bulb.charge, t * 3.0 + float(bulb.cell.y), clampf(1.0 - (t - bulb.struck_t) / FLASH_TIME, 0.0, 1.0),
			bulb.wild, clampf(1.0 - (t - bulb.warded_t) / FLASH_TIME, 0.0, 1.0), bulb.hits_left(), leaves_parted(bulb.charge, t - bulb.spat_t))


## A living bulb, printed on `canvas` from its root in the wall, laid out by `xf` (+x out of the rock):
## `open` how far it is in bloom (0 shut in its sepals, 1 open), `charge` how near its next seed it is
## (it swells), `wobble` the phase of its slow throb, `flash` how strongly it flashes pink from a
## blow that wounded it, `wild` whether it is wild (screened pink, the bramble's last stand), `glance`
## how strongly a blow just glanced off it, `hits` its hits left (dark dots), and `parted` how far
## the leaves shrouding it have swung back (leaves_parted). The bramble's bulbs (above) and the
## garden's seed pods (PodArt) alike.
static func ink_bulb(canvas: InkCanvas, xf: Transform2D, open: float, charge: float, wobble: float, flash: float, wild: bool, glance: float, hits: int, parted: float) -> void:
	var cup: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(7.0, 0.0), 20.0, BULB_R * 0.9, 16)
	var swell: float = 1.0 + BULB_SWELL * charge * charge + 0.04 * sin(wobble)
	var r: float = BULB_R * swell * lerpf(SHUT_SIZE, 1.0, open)
	var body: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(BrambleBulb.OUT * swell, 0.0), r * 0.95, r, 22)
	canvas.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 1.0, [body])
	canvas.ink(RisoPrint.ACCENT, lerpf(SHUT_ACCENT, 1.0, open), [body])
	if flash > 0.0:
		canvas.ink(RisoPrint.PINK, 0.8 * flash, [body], false)
	if wild:
		canvas.ink(RisoPrint.PINK, WILD_PINK * open, [body], false)
		if glance > 0.0:
			canvas.ink(RisoPrint.BLUE, 0.6 * glance, [body], false)
	# Its gleam, toward the open shaft.
	canvas.lift_ink([RisoPrint.ACCENT], 0.7 * open, [xf * RisoShapes.ellipse(Vector2(BrambleBulb.OUT * swell + r * 0.3, -r * 0.35), r * 0.22, r * 0.14, 10, 0.5)])
	canvas.ink(RisoPrint.BLUE, BARK_BLUE, [cup])
	canvas.ink(RisoPrint.NIGHT, BARK_NIGHT, [cup], false)
	# Its hits left, as dark dots down its middle.
	var dots: Array[PackedVector2Array] = []
	var n: int = hits
	for j: int in range(n):
		var off: float = (float(j) - float(n - 1) * 0.5) * r * 0.5
		dots.append(xf * RisoShapes.circle(Vector2(BrambleBulb.OUT * swell + 2.0, off), r * 0.13, 8))
	canvas.ink(RisoPrint.NIGHT, 0.85, dots, false)
	# Its sepals: closed over it while shut, folded back against the wall in bloom, and blue-bright
	# for a moment when a blow glances off them.
	if open < 0.99:
		var sepals: Array[PackedVector2Array] = []
		for side: float in [-1.0, 1.0]:
			var hinge: Vector2 = Vector2(4.0, side * BULB_R * SEPAL_HINGE)
			var leaf: Transform2D = Transform2D(lerpf(-side * SEPAL_SHUT, side * SEPAL_OPEN, open), hinge)
			sepals.append(xf * (leaf * RisoShapes.almond(Vector2(BULB_R * 0.95, 0.0), BULB_R, BULB_R * SEPAL_WIDE, 14)))
		var shut: float = 1.0 - open
		canvas.lift_ink([RisoPrint.NIGHT, RisoPrint.ACCENT], shut, sepals)
		canvas.ink(RisoPrint.BLUE, (BARK_BLUE - 0.4 * glance) * shut, sepals)
		canvas.ink(RisoPrint.NIGHT, BARK_NIGHT * (1.0 - glance) * shut, sepals, false)
	# Its leaves, shrouding it: a narrower one behind on either side, then a lower and an upper leaf
	# clasped round it, overlapping down its middle; all grow out from under the cup's rim, and
	# swing back about their roots to bare it as it readies a seed (`parted`).
	var swing: float = parted * parted * (3.0 - 2.0 * parted)
	var bud: Transform2D = xf * Transform2D(0.0, Vector2(r, r), 0.0, Vector2(BrambleBulb.OUT * swell, 0.0))
	var k: int = 0
	for layer: int in range(3):
		for side: float in ([-1.0, 1.0] if layer == 0 else [1.0 if layer == 1 else -1.0]):
			var root: Vector2 = Vector2.from_angle(side * LEAF_ROOT_AT) * (0.9 if layer == 0 else LEAF_OUT)
			var turn: float = side * (LEAF_BACK_SWING if layer == 0 else LEAF_SWING) * swing + LEAF_SWAY * sin(wobble + float(k))
			k += 1
			var fold: float = lerpf(1.0, LEAF_FOLD, swing)
			var pivot: Transform2D = bud * Transform2D(turn, Vector2(fold, fold), 0.0, root) * Transform2D(0.0, -root)
			var shape: PackedVector2Array
			var lines: Array[PackedVector2Array] = []
			if layer == 0:
				var out: Transform2D = Transform2D(side * LEAF_BACK_AT, root)
				shape = out * RisoShapes.almond(Vector2(LEAF_BACK * 0.5, 0.0), LEAF_BACK * 0.5, LEAF_BACK_WIDE * 0.5, 16)
				lines.append(out * RisoShapes.almond(Vector2(LEAF_BACK * 0.5, 0.0), LEAF_BACK * 0.42, 0.025, 8))
			else:
				shape = _clasped_leaf(side)
				lines = _leaf_veins(side)
			var leaf: Array[PackedVector2Array] = Geometry2D.clip_polygons(pivot * shape, cup)
			var veins: Array[PackedVector2Array] = []
			for line: PackedVector2Array in lines:
				veins.append_array(Geometry2D.clip_polygons(pivot * line, cup))
			canvas.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], 1.0, leaf)
			canvas.ink(RisoPrint.BLUE, LEAF_BLUE, leaf)
			canvas.ink(RisoPrint.NIGHT, LEAF_NIGHT[layer], leaf, false)
			if not veins.is_empty():
				canvas.lift_ink([RisoPrint.BLUE, RisoPrint.NIGHT], LEAF_RIB, [veins[0]])
				canvas.lift_ink([RisoPrint.BLUE, RisoPrint.NIGHT], LEAF_VEIN, veins.slice(1))


## A clasped leaf of a bulb's shroud, in the bulb's measure (see LEAF_ROOT_AT): side `side` (-1 the
## upper, 1 the lower), from its root round the bulb LEAF_OUT out to its tip just past the middle,
## and back along an inner edge bowed toward LEAF_CLASP, past the middle.
static func _clasped_leaf(side: float) -> PackedVector2Array:
	var root_at: float = side * LEAF_ROOT_AT
	var tip: Vector2 = Vector2.from_angle(-side * LEAF_TIP_AT) * LEAF_TIP
	var root: Vector2 = Vector2.from_angle(root_at) * LEAF_OUT
	var bow: Vector2 = Vector2(LEAF_CLASP.x, -side * LEAF_CLASP.y)
	var out: PackedVector2Array = PackedVector2Array()
	for n: int in range(21):
		var u: float = float(n) / 20.0
		out.append(Vector2.from_angle(lerpf(root_at, -side * LEAF_TIP_AT * 0.3, u)) * LEAF_OUT)
	out.append(tip)
	for n: int in range(1, 20):
		var u: float = float(n) / 20.0
		out.append(tip.lerp(bow, u).lerp(bow.lerp(root, u), u))
	return out


## A clasped leaf's midrib (first), from its root to its tip through the leaf's middle, tapering,
## and three veins off it toward the leaf's outer edge, slanting toward the tip.
static func _leaf_veins(side: float) -> Array[PackedVector2Array]:
	var root: Vector2 = Vector2.from_angle(side * LEAF_ROOT_AT) * LEAF_OUT
	var tip: Vector2 = Vector2.from_angle(-side * LEAF_TIP_AT) * LEAF_TIP
	var bend: Vector2 = Vector2(0.0, side * 0.75)
	var rib: Callable = func(u: float) -> Vector2: return root.lerp(bend, u).lerp(bend.lerp(tip, u), u)
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for n: int in range(13):
		var u: float = float(n) / 12.0
		var p: Vector2 = rib.call(u)
		var across: Vector2 = ((rib.call(minf(u + 0.02, 1.0)) as Vector2) - (rib.call(maxf(u - 0.02, 0.0)) as Vector2)).normalized().orthogonal()
		var half: float = lerpf(0.03, 0.004, u)
		left.append(p + across * half)
		right.append(p - across * half)
	right.reverse()
	left.append_array(right)
	var lines: Array[PackedVector2Array] = [left]
	for u: float in [0.35, 0.55, 0.75]:
		var p: Vector2 = rib.call(u)
		var way: Vector2 = p.normalized().rotated(-side * 0.55)
		var across: Vector2 = way.orthogonal() * 0.012
		lines.append(PackedVector2Array([p + across, p + way * 0.32, p - across]))
	return lines


## How far a bulb's leaves have swung back (0 folded over it, 1 apart): parting as it nears its next
## seed (`charge`, from LEAF_PART_FROM), wide apart as it spits, and folding shut over LEAF_CLOSE
## seconds after (`since`, seconds since it last spat). The bramble's bulbs and the seed pods alike.
static func leaves_parted(charge: float, since: float) -> float:
	var nearing: float = smoothstep(LEAF_PART_FROM, 1.0, charge)
	var after: float = 1.0 - clampf(since / LEAF_CLOSE, 0.0, 1.0)
	return maxf(nearing, smoothstep(0.0, 1.0, after))


## The bud's size now (a share of BUD_LONG by BUD_WIDE): BUD_HIDDEN tucked in the crown, growing as
## the crown draws back from it.
func _bud_grow() -> float:
	return lerpf(BUD_HIDDEN, 1.0, bare)


## Where the bud's cap is now: tucked BUD_TUCK up in the knot, dropping to BUD_TOP as it is bared.
func _bud_top() -> Vector2:
	return Vector2(knot_rect.get_center().x, knot_rect.end.y - lerpf(BUD_TUCK, BUD_TOP, bare))


## The middle of the bud now, which the crown's hollow is round.
func _bud_middle() -> Vector2:
	return _bud_top() + Vector2(0.0, BUD_LONG * _bud_grow() * 0.5)


## How far the crown has drawn back from round the bud (half sizes, px): nothing while it is whole,
## then round its middle, as wide as the bud and BrambleTangle.HOLLOW_PAD more once bared.
func _hollow_size() -> Vector2:
	if bare <= 0.001:
		return Vector2.ZERO
	var full: Vector2 = Vector2(BUD_WIDE * 0.5, BUD_LONG * 0.5) * _bud_grow() + Vector2.ONE * BrambleTangle.HOLLOW_PAD
	return full * sqrt(bare)


## The heart: a bud hanging from the tip of its own stalk (BrambleTangle.stalk_tip), hidden in the
## crown, glimpsed through it as the canes draw back; it sways and quivers with its stalk. A long
## teardrop of accent, point down, wrapped by two long sepals of bark hugging its sides and two
## shorter, paler ones within, a pink thorn at each long one's tip, under a cap of bark where the
## stalk meets it. Its accent shows down the middle, dimmer while hidden,
## with a paper gleam and, once bared, its hits left as dark dots. With each beat it swells and its
## sepals part a little; struck, it flashes pink, and while it is shut its outer sepals close over
## it (BrambleHeart.closed), a blow glancing off them pale. Burst, it is a dry husk, drawn up into
## the rock as its stalk draws back. Nothing of it shows until its stalk has grown down to it.
func _draw_bud() -> void:
	if not tangle.awake() or not (tangle.holds_bud() or dying):
		return
	var grow: float = _bud_grow()
	var top0: Vector2 = tangle.stalk_tip()
	if not top0.is_finite():
		return
	var long: float = BUD_LONG * grow
	var wide: float = BUD_WIDE * grow
	if dying or (heart != null and not heart.alive):
		# A dry husk, drawn up into the rock with its stalk.
		var keep: float = 1.0 - tangle.drawn_back(tangle.stalk) * 0.6
		if tangle.reaches()[tangle.canes.find(tangle.stalk)] < 4.0:
			return
		var since: float = t - (heart.burst_t if heart != null else t)
		var husk: PackedVector2Array = _teardrop(top0, long * 0.6 * keep, wide * 0.45 * keep)
		var dry: float = clampf(dying_t / BrambleTangle.DRY_TIME, 0.0, 1.0)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.ACCENT], 1.0, [husk])
		ink.ink(RisoPrint.BLUE, lerpf(BARK_BLUE, DRY_BLUE, dry), [husk])
		ink.ink(RisoPrint.NIGHT, 0.3 * (1.0 - dry), [husk], false)
		if since < BURST_TIME:
			var u: float = since / BURST_TIME
			var petals: Array[PackedVector2Array] = []
			for n: int in range(7):
				var dir: Vector2 = Vector2.from_angle(PI * 0.5 + (float(n) - 3.0) * 0.5)
				petals.append(RisoShapes.ellipse(top0 + Vector2(0.0, long * 0.45) + dir * (30.0 + 90.0 * u), 16.0 * (1.0 - u), 8.0 * (1.0 - u), 10, dir.angle()))
			ink.ink(RisoPrint.ACCENT, 1.0 - u, petals)
		return
	var cx: float = top0.x
	var top: float = top0.y
	var beat: float = pow(maxf(0.0, sin(t / HEART_BEAT * TAU)), 4.0)
	long *= 1.0 + 0.04 * beat
	wide *= 1.0 + 0.06 * beat
	var body: PackedVector2Array = _teardrop(top0, long, wide)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 1.0, [body])
	ink.ink(RisoPrint.ACCENT, lerpf(BUD_DIM, 1.0, bare), [body])
	ink.ink(RisoPrint.PINK, 0.15 * beat, [body], false)
	var flash: float = clampf(1.0 - (t - heart.struck_t) / FLASH_TIME, 0.0, 1.0) if heart != null else 0.0
	if flash > 0.0:
		ink.ink(RisoPrint.PINK, 0.8 * flash, [body], false)
	ink.lift_ink([RisoPrint.ACCENT], 0.7 * bare, [RisoShapes.ellipse(Vector2(cx - wide * 0.18, top + long * 0.36), wide * 0.08, wide * 0.13, 12, 0.3)])
	# Its sepals and cap, parting with the beat; wrapped closer while it is hidden, and closed over it
	# while it is shut.
	var shut: float = heart.closed if heart != null else 0.0
	var part: float = (BUD_SPREAD + BUD_PART * beat) * lerpf(0.4, 1.0, bare) * (1.0 - shut)
	var outer: Array[PackedVector2Array] = []
	var within: Array[PackedVector2Array] = []
	var thorns: Array[PackedVector2Array] = []
	for s: float in [-1.0, 1.0]:
		var base: Vector2 = Vector2(cx + s * wide * lerpf(0.16, 0.2, shut), top + 2.0)
		outer.append(_leaf(base, long * 0.86, wide * lerpf(0.3, SHUT_WIDE, shut), -s * part))
		within.append(_leaf(Vector2(cx + s * wide * 0.1, top + 2.0), long * 0.42, wide * 0.22, -s * (0.06 + 0.5 * (part - BUD_SPREAD))))
		var down: Vector2 = Vector2.DOWN.rotated(-s * part)
		var tip: Vector2 = base + down * (long * 0.86 + 2.0)
		thorns.append(PackedVector2Array([tip - down.orthogonal() * 4.0 - down * 4.0, tip + down * 14.0, tip + down.orthogonal() * 4.0 - down * 4.0]))
	var cap: PackedVector2Array = RisoShapes.ellipse(Vector2(cx, top + 8.0), wide * 0.24, 12.0 * grow, 20)
	var dark: Array[PackedVector2Array] = outer.duplicate()
	dark.append(cap)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.ACCENT], 1.0, dark)
	ink.ink(RisoPrint.BLUE, BARK_BLUE, dark)
	ink.ink(RisoPrint.NIGHT, BARK_NIGHT, dark, false)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.ACCENT], 1.0, within)
	ink.ink(RisoPrint.BLUE, BARK_BLUE, within)
	ink.ink(RisoPrint.NIGHT, 0.1, within, false)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 1.0, thorns)
	ink.ink(RisoPrint.PINK, 1.0, thorns)
	if heart == null:
		return
	var glanced: float = clampf(1.0 - (t - heart.warded_t) / FLASH_TIME, 0.0, 1.0) * shut
	if glanced > 0.0:
		ink.lift_ink([RisoPrint.NIGHT], glanced, outer)
	if shut > 0.5:
		return
	var dots: Array[PackedVector2Array] = []
	var n: int = heart.hits_left()
	for j: int in range(n):
		dots.append(RisoShapes.circle(Vector2(cx + (float(j) - float(n - 1) * 0.5) * wide * 0.14, top + long * 0.6), wide * 0.048, 8))
	ink.ink(RisoPrint.NIGHT, 0.85, dots, false)


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


## The sap on its way to the next bulb: a drop of accent running along the roots and under the
## head, a few smaller drops trailing it.
func _draw_sap() -> void:
	if sap_to == null or sap_path.size() < 2:
		return
	var drops: Array[PackedVector2Array] = []
	for k: int in range(SAP_TRAIL + 1):
		drops.append(RisoShapes.circle(sap_at(float(k) * SAP_GAP), SAP_R * (1.0 - float(k) / float(SAP_TRAIL + 1)), 12))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK], 1.0, drops)
	ink.ink(RisoPrint.ACCENT, 1.0, drops)
