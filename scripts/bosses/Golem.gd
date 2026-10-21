class_name Golem
extends Shaped
## The lodestone golem (Bosses.UP's first, docs/REGIONS_PLAN.md §6): the boss at the top of the
## crags, fought in its hall (LodeHall) at the top of their gate level. A hulking
## figure of dark stone: chunks of lodestone (PARTS: two legs, a belly, a chest plate in two, two
## shoulders, two arms and a head) held by their pull round its heart.
## - It sleeps in its lair until the wizard comes into its hall (or strikes it); then it hunts them,
##   walking its floor after them (WALK, never off the floor's end nor over its gap, though it steps
##   over a stair hole) and turning to face them.
## - The slam, its strong attack: the wizard near it on its floor, it raises both fists in pink
##   (SLAM_WARN) and brings them down in front of it (SLAM_HOLD), sending a shockwave along the floor
##   both ways (GolemShock), jumped. Its fists' touch hurts, and a guard up as they land parries
##   them: it is stunned (Parry.STUN), and SHARDS lode shards fly out of it (shed_shards,
##   LodeShard), each one taken making the wizard's spent empowered cast ready at once
##   (Empower.refill). In its hall every damage spell may be cast empowered (LodeHall.tempers).
## - The hurl: the wizard far off (HURL_MIN) and in its sight, every HURL_EVERY seconds at most, it
##   tears off a chunk of its own (HURLED: a shoulder, then the head), holds it up (HURL_WARN) and
##   lobs it to land where they are (GolemStone). The chunk lies where it lands until called back.
## - The leap: the wizard on another storey of the hall (LEAP_AFTER), it goes to the gap between
##   (LodeHall's gaps) and, the spot it will land on marked in pink (LEAP_WARN), leaps up through it
##   or drops down it (LEAP_TIME), landing with a shockwave.
## - The recall: anything of it lying loose (shards, a hurled chunk) RECALL_DELAY seconds, it calls it
##   all back, pink lines warning (RECALL_WARN); then each flies home (RECALL_SPEED) through where
##   the wizard stood, hurting on the way. A hurled chunk is whole again; a shard regrows a
##   shattered chunk (one over its heart first).
## - The shockwave, a hurled chunk and a recalled shard each hurt as a hazard does: a guard catches
##   them, with nothing to strike. Only its fists are its own touch.
## - A blow meets the first part of it in its way, on the line from where the blow came from to its
##   heart (part_met): a spell's (blow), a parry's, an arrow's (arrow_hit). So what stands in the way
##   is broken first: from the side, an arm, then the chest plate.
## - Its chunks break only to an empowered spell (Empower): one shatters the chunk it meets; a plain
##   blow glances off it with grit.
## - Its heart is covered while any of the chunks over it (COVERS: the belly and the chest plate) is
##   whole. Bare, any blow, an arrow or a parry wounds it: HEART wounds, shown as cracks in it. With
##   the last it falls apart into a heap (DIE_TIME), it is slain, and its relic waits where it stood
##   (MapInfo.boss_slain).
## A harder preset runs its clock faster (Difficulty.haste); a stun's length is not changed. A lantern
## death brings it back whole, as the hall reloads. Nothing here draws from any RNG: its choices
## follow the wizard and the hall's layout.

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## What it is doing.
enum State { SLEEP, HUNT, SLAM_WARN, SLAM, HURL_WARN, LEAP_WARN, LEAP, RECALL_WARN, RECALL, REST }
## Its heart's wounds, its health.
const HEART: int = 3
## Its chunks, each (x, y, radius) in px from its feet (y up is negative), facing right: two legs, a
## belly, the chest plate's two halves, two shoulders, two arms and a head.
const PARTS: Array[Vector3] = [
	Vector3(-52.0, -58.0, 50.0), Vector3(52.0, -58.0, 50.0),
	Vector3(0.0, -128.0, 56.0),
	Vector3(-40.0, -205.0, 50.0), Vector3(40.0, -205.0, 50.0),
	Vector3(-112.0, -232.0, 46.0), Vector3(112.0, -232.0, 46.0),
	Vector3(-138.0, -138.0, 44.0), Vector3(138.0, -138.0, 44.0),
	Vector3(0.0, -292.0, 40.0),
]
## The chunks over its heart (PARTS' places): the belly and the chest plate's two halves. A shard
## called home regrows one of these first.
const COVERS: Array[int] = [2, 3, 4]
## Its arms and its legs (PARTS' places): its arms raise its fists and slam, its legs step.
const ARMS: Array[int] = [7, 8]
const LEGS: Array[int] = [0, 1]
## Its head (PARTS' place), where its eyes are.
const HEAD: int = 9
## The chunks it hurls, in the order it takes them (PARTS' places): its shoulders, then its head.
const HURLED: Array[int] = [5, 6, 9]
## Its heart: where it sits from its feet (px), and how big.
const HEART_AT: Vector2 = Vector2(0.0, -180.0)
const HEART_R: float = 34.0
## What a blow's or an arrow's meeting is called when it meets the heart (part_met).
const AT_HEART: int = -1
## How many lode shards a parried slam sheds, and how hard (px/s, out and up) the outermost are
## thrown; the rest are spread between.
const SHARDS: int = 2
const SHARD_KICK: Vector2 = Vector2(260.0, -560.0)
## How fast it walks (px/s); how near (px) its middle keeps to the hall's walls, and to a floor's end
## (its feet); and the widest hole in a floor (cells) it steps over (a stair hole, never its gap).
const WALK: float = 120.0
const EDGE: float = 190.0
const FOOT: float = 100.0
const STEP_OVER: int = 2
## The slam: how near across (px) the wizard must be on its floor; seconds raising its fists (the
## warning), holding them down (their touch hurts, and a guard up then parries them) and resting
## after; how high (px) it raises its fists; where they land (px from its feet, facing the wizard),
## and how far their touch reaches.
const SLAM_RANGE: float = 300.0
const SLAM_WARN: float = 0.7
const SLAM_HOLD: float = 0.35
const SLAM_REST: float = 0.8
const RAISE: float = 120.0
const FIST_AT: Vector2 = Vector2(170.0, -50.0)
const FIST_R: float = 60.0
## The hurl: seconds between hurls at least (the first this long after it wakes), how far (px) the
## wizard must be, seconds holding the chunk up (the warning) and how high over its head, and seconds
## the chunk flies to where they were.
const HURL_EVERY: float = 5.0
const HURL_MIN: float = 520.0
const HURL_WARN: float = 0.6
const HURL_UP: float = 340.0
const HURL_FLIGHT: float = 0.9
## The leap: seconds the wizard is on another storey before it goes after them; seconds crouching,
## the spot it will land on marked (the warning); seconds in the air, and how high (px) over the
## higher floor it rises; and how far (px) from the gap's edge it lands on a floor above.
const LEAP_AFTER: float = 1.0
const LEAP_WARN: float = 0.8
const LEAP_TIME: float = 0.9
const LEAP_OVER: float = 200.0
const LEAP_CLEAR: float = 40.0
## The recall: seconds anything of it lies loose before it calls it back, seconds of warning (pink
## lines along the ways home), and how fast (px/s) what it calls flies.
const RECALL_DELAY: float = 3.0
const RECALL_WARN: float = 0.8
const RECALL_SPEED: float = 900.0
## Seconds it rests after a hurl, a leap, a recall or a stun.
const REST: float = 0.6
## How finely (px) it looks along its sight for rock.
const SIGHT_STEP: float = 32.0
## Seconds: falling apart as it dies, a part flashing when struck, and a shattered chunk's bits
## flying.
const DIE_TIME: float = 1.4
const FLASH_TIME: float = 0.2
const SHATTER_TIME: float = 0.5
## Its poses: how far its height is squashed asleep and crouching to leap (of its height), and
## seconds rising as it wakes; walking, how far (px) it goes in a step, how high (px) a foot lifts and
## how much its body bobs; stunned, how far (px) its chunks sag out from its heart, its pull gone
## slack; and in the air, how far (px) its legs tuck up.
const SLUMP: float = 0.78
const CROUCH: float = 0.86
const WAKE_TIME: float = 0.6
const STRIDE: float = 150.0
const STEP_LIFT: float = 18.0
const BOB: float = 6.0
const LOOSE: float = 24.0
const TUCK: float = 30.0
## The print, after the lodestones' own (LodestoneArt): its chunks' blue darkened to iron with night,
## more night on each one's shaded side (below and to the right: the light comes from above at the
## left) and a lift of ink off its lit face, patches of ore in night and a glint of paper; how many
## corners a chunk has, how far (of its radius) each corner is pulled in at most, and how much of
## each edge its bevels take off at either end.
const STONE_BLUE: float = 0.95
const STONE_NIGHT: float = 0.5
const SHADE: float = 0.4
const LIT: float = 0.18
const ORE: float = 0.55
const CORNERS: int = 6
const DENT: float = 0.25
const BEVEL: float = 0.14
## Its pull: a vein of accent ore in each chunk, running in from its edge nearest its heart for
## VEIN_LONG of its radius, kinked (px wide), and how much accent in it (dark ore asleep, below
## VEIN_LIT, and flickering stunned); its heart's glow behind its chunks, seen through
## the gaps between them (how far out, of its radius, and how much accent); and sparks of iron drawn
## in to its heart, as to a lodestone (how many at once, and seconds for each to arrive).
const VEIN_W: float = 8.0
const VEIN: float = 0.8
const VEIN_LONG: float = 0.6
const VEIN_LIT: float = 0.4
const GLOW: float = 3.2
const GLOW_COVER: float = 0.5
const FILINGS: int = 6
const FILING_TRIP: float = 1.8
## Its eyes: slits of paper on its head (px long and high, and how far apart), shut asleep and pink
## while it warns.
const EYE: Vector2 = Vector2(14.0, 6.0)
const EYES_APART: float = 13.0
## Its heart's cracks (px wide), how far its bits fly, a warning's pink, the landing mark (px high)
## and a recall's lines (px wide).
const CRACK_W: float = 5.0
const BITS_FLY: float = 140.0
const WARN_PINK: float = 0.7
const MARK_H: float = 26.0
const RECALL_W: float = 16.0
## Salts for the hashes that shape its chunks, its heart's cracks and its bits (one look everywhere).
const SHAPE_DEAL: int = 6900
const CRACK_DEAL: int = 6910
const BITS_DEAL: int = 6920
const ORE_DEAL: int = 6930

var map_info: MapInfo
## Which boss it is (Bosses).
var boss: StringName = &""
## The level's cell size (px).
var cell: float = 128.0
## Which of its chunks are whole, and which are away (hurled, lying until called back) (PARTS'
## places).
var whole: Array[bool] = []
var thrown: Array[bool] = []
var wound: GolemWound
var stunner: Stunner
## Its fists' touch, there only while they are down in a slam.
var fists: HitBox
var state: State = State.SLEEP
var timer: float = 0.0
## The way it faces: 1 right, -1 left.
var face: int = 1
## Its hall (LodeHall): the air inside, its galleries' rows (top first), the gaps through them, and
## the hall's walls (px).
var inside: Rect2i = Rect2i()
var floors: Array[int] = []
var gaps: Array[Rect2i] = []
var hall_left: float = 0.0
var hall_right: float = 0.0
## Seconds until it may hurl again; seconds the wizard has been on another storey; seconds anything
## of it has lain loose.
var hurl_wait: float = HURL_EVERY
var apart_t: float = 0.0
var loose_t: float = 0.0
## The chunk it holds up to hurl (PARTS' place), or -1.
var hurling: int = -1
## A leap: where from and where to (its feet), and whether it goes down.
var leap_from: Vector2 = Vector2.ZERO
var leap_to: Vector2 = Vector2.ZERO
var leap_down: bool = false
## The shards it has shed and the chunks it has hurled, not yet lost or home.
var shards: Array[LodeShard] = []
var stones: Array[GolemStone] = []
## What it calls home, each with its way home (`way`, set by the recall) and what it regrows.
var called: Array[Node2D] = []
var dying: bool = false
var slain: bool = false
var ink: InkCanvas
var t: float = 0.0
var dead_t: float = 0.0
## When each part was last struck and each chunk shattered (its clock, t), and its heart wounded.
var struck_t: Array[float] = []
var shattered_t: Array[float] = []
var heart_t: float = -INF
var _was_stunned: bool = false
## Its poses (see SLUMP): how far risen (0 asleep, 1 awake), how much of its height it stands to now,
## how far it has walked (px, for its steps) and how much it is walking (0 to 1).
var rise: float = 0.0
var squash: float = SLUMP
var stride: float = 0.0
var gait: float = 0.0
var _last_x: float = INF


func _init() -> void:
	wound = GolemWound.new()
	wound.name = "Wound"
	wound.hp = HEART
	add_child(wound)
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	stunner.parry_only = true
	add_child(stunner)
	# Its fists' touch, under a node of its own so the stun leaves it to sync_fists.
	var hands: Node2D = Node2D.new()
	hands.name = "Hands"
	add_child(hands)
	fists = HIT_BOX.instantiate() as HitBox
	fists.name = "HitBox"
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = FIST_R
	var shape: CollisionShape2D = fists.get_node("CollisionShape2D") as CollisionShape2D
	shape.shape = reach
	shape.disabled = true
	(fists.get_node("Damager") as Damager).attacker = self
	hands.add_child(fists)
	for i: int in range(PARTS.size()):
		whole.append(true)
		thrown.append(false)
		struck_t.append(-INF)
		shattered_t.append(-INF)
	add_to_group(&"hex_target")


func _ready() -> void:
	# Over the terrain with the other things in a place (props, z 2).
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)


func setup(info: MapInfo, _v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	# It goes all over its hall: never put to sleep with the chunk its cell is in.
	remove_meta(&"cell")
	var tm: TileMap = info.tile_map
	cell = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	# It stands on the floor of its cell.
	global_position.y += cell * 0.5
	var keep: Dictionary = info.world.keep
	if keep.has("lair"):
		inside = keep["inside"]
		floors = keep["floors"]
		gaps = keep["gaps"]
		hall_left = info.cell_position(inside.position).x - cell * 0.5
		hall_right = info.cell_position(Vector2i(inside.end.x - 1, inside.position.y)).x + cell * 0.5


# ------------------------------------------------------------------ what it is

## Whether a parry has it stunned.
func stunned() -> bool:
	return stunner.stunned()


## Out of the fight (Shaped): dying or dead.
func done() -> bool:
	return dying or slain


## Whether its heart is covered: some chunk over it is whole.
func covered() -> bool:
	return COVERS.any(func(i: int) -> bool: return whole[i])


## How many of its chunks are whole.
func chunks_left() -> int:
	return whole.count(true)


## Where its heart is (bobbing as it walks).
func heart_center() -> Vector2:
	return global_position + Vector2(HEART_AT.x, HEART_AT.y * squash) + _bob()


## Where chunk `i` is (PARTS, turned the way it faces, as it is posed now).
func part_center(i: int) -> Vector2:
	return global_position + _rest(i) + _pose(i)


## Where chunk `i` rests from its feet, turned the way it faces and squashed as it slumps or crouches.
func _rest(i: int) -> Vector2:
	return Vector2(PARTS[i].x * float(face), PARTS[i].y * squash)


## How far its body bobs up as it walks, at the top of each step.
func _bob() -> Vector2:
	return Vector2(0.0, -absf(sin(stride / STRIDE * TAU)) * BOB * gait)


## How far chunk `i` is moved from its rest by what it is doing: a foot lifted as it steps (and the
## rest of it bobbing), its legs tucked in a leap, its chunks sagging out from its heart while it is
## stunned (all but those over its heart, which stays covered), its arms raised for a slam and down
## in it, and a chunk held up to hurl.
func _pose(i: int) -> Vector2:
	var rest: Vector2 = _rest(i)
	var out: Vector2 = Vector2.ZERO
	if i in LEGS:
		var lift: float = maxf(0.0, sin(stride / STRIDE * TAU) * (1.0 if i == LEGS[0] else -1.0)) * STEP_LIFT * gait
		out += Vector2(float(face) * lift * 0.6, -lift)
		if state == State.LEAP:
			out.y -= TUCK
	else:
		out += _bob()
	if stunned() and not i in COVERS:
		var from_heart: Vector2 = rest - Vector2(HEART_AT.x, HEART_AT.y * squash)
		out += from_heart.normalized() * LOOSE * sqrt(stunner.fraction()) + Vector2(sin(t * 7.0 + float(i)), cos(t * 5.0 + float(i) * 2.0)) * 3.0
	if i in ARMS:
		if state == State.SLAM_WARN:
			return out + Vector2(0.0, -RAISE * clampf(1.0 - timer / SLAM_WARN, 0.0, 1.0))
		if state == State.SLAM:
			var side: float = 1.0 if i == ARMS[1] else -1.0
			return Vector2(FIST_AT.x * float(face) + side * PARTS[i].z * 0.7, FIST_AT.y) - rest
	if i == hurling and state == State.HURL_WARN:
		return out + (Vector2(0.0, -HURL_UP) - rest) * clampf(1.0 - timer / HURL_WARN, 0.0, 1.0)
	return out


## What a blow can meet: its whole chunks (PARTS' places), and its heart (AT_HEART) once bare.
func _targets() -> Array[int]:
	var out: Array[int] = []
	for i: int in range(PARTS.size()):
		if whole[i]:
			out.append(i)
	if not covered():
		out.append(AT_HEART)
	return out


## The middle of what `k` names (a chunk, or AT_HEART), and its radius.
func _center_of(k: int) -> Vector2:
	return heart_center() if k == AT_HEART else part_center(k)


func _radius_of(k: int) -> float:
	return HEART_R if k == AT_HEART else PARTS[k].z


## Whether a way from `from` to `to` comes within `reach` of a whole chunk, or of its bare heart.
func struck_by(from: Vector2, to: Vector2, reach: float) -> bool:
	for k: int in _targets():
		var c: Vector2 = _center_of(k)
		if Geometry2D.get_closest_point_to_segment(c, from, to).distance_to(c) <= _radius_of(k) + reach:
			return true
	return false


## The part a blow from `from` meets (a chunk's place in PARTS, or AT_HEART): of those a blow can
## meet, the first the line from `from` to its heart goes into; failing that (a blow from inside it),
## the one whose edge is nearest `from`.
func part_met(from: Vector2) -> int:
	var to: Vector2 = heart_center()
	var way: Vector2 = to - from
	var long: float = way.length()
	var along: Vector2 = way / long if long > 0.0 else Vector2.ZERO
	var best: int = AT_HEART
	var best_in: float = INF
	var nearest: int = AT_HEART
	var nearest_d: float = INF
	for k: int in _targets():
		var c: Vector2 = _center_of(k)
		var r: float = _radius_of(k)
		var edge: float = from.distance_to(c) - r
		if edge < nearest_d:
			nearest_d = edge
			nearest = k
		var mid: float = (c - from).dot(along)
		var off: float = absf((c - from).cross(along))
		if off > r or mid < -r or mid > long + r:
			continue
		var enter: float = maxf(mid - sqrt(r * r - off * off), 0.0)
		if enter < best_in:
			best_in = enter
			best = k
	return best if best_in < INF else nearest


## The storey of its hall a point is on, by the rows: 0 the top (over the top gallery), 1 the middle,
## 2 the ground storey.
func storey_of(at: Vector2) -> int:
	var row: int = map_info.cell_at(at).y
	for k: int in range(floors.size()):
		if row < floors[k]:
			return k
	return floors.size()


## Its own storey (by its feet).
func storey() -> int:
	return storey_of(global_position + Vector2(0.0, -cell * 0.5))


## The top (px) of storey `k`'s floor.
func floor_y(k: int) -> float:
	var row: int = floors[k] if k < floors.size() else inside.end.y
	return map_info.cell_position(Vector2i(inside.position.x, row)).y - cell * 0.5


## How far (px, its middle's least and most x) it may walk along storey `k`'s floor from `x`: to the
## floor's ends (stepping over holes no wider than STEP_OVER) less its feet, and no nearer the walls
## than EDGE.
func reach_along(k: int, x: float) -> Vector2:
	var row: int = floors[k] if k < floors.size() else inside.end.y
	var c: int = clampi(map_info.cell_at(Vector2(x, floor_y(k) + 1.0)).x, inside.position.x, inside.end.x - 1)
	var ends: Array[int] = []
	for step: int in [-1, 1]:
		var last: int = c
		var hole: int = 0
		var i: int = c
		while i >= inside.position.x and i < inside.end.x:
			if map_info.world.is_ground(Vector2i(i, row)):
				last = i
				hole = 0
			else:
				hole += 1
				if hole > STEP_OVER:
					break
			i += step
		ends.append(last)
	var lo: float = maxf(map_info.cell_position(Vector2i(ends[0], row)).x - cell * 0.5 + FOOT, hall_left + EDGE)
	var hi: float = minf(map_info.cell_position(Vector2i(ends[1], row)).x + cell * 0.5 - FOOT, hall_right - EDGE)
	if lo > hi:
		var mid: float = (lo + hi) * 0.5
		return Vector2(mid, mid)
	return Vector2(lo, hi)


## The middle (px across) of gap `g`, and its edges.
func _gap_mid(g: Rect2i) -> float:
	return (_gap_left(g) + _gap_right(g)) * 0.5


func _gap_left(g: Rect2i) -> float:
	return map_info.cell_position(g.position).x - cell * 0.5


func _gap_right(g: Rect2i) -> float:
	return map_info.cell_position(Vector2i(g.end.x - 1, g.position.y)).x + cell * 0.5


## Whether the wizard is in its hall.
func _in_hall(player: Player) -> bool:
	return not floors.is_empty() and (map_info.world.keep["box"] as Rect2i).has_point(map_info.cell_at(player.global_position))


## Whether it sees `at` from its heart: no rock between.
func sees(at: Vector2) -> bool:
	var from: Vector2 = heart_center()
	var steps: int = ceili(from.distance_to(at) / SIGHT_STEP)
	for i: int in range(1, steps):
		if map_info.world.is_ground(map_info.cell_at(from.lerp(at, float(i) / float(steps)))):
			return false
	return true


## The chunk it would hurl now (HURLED's first whole one), or -1.
func _to_hurl() -> int:
	for i: int in HURLED:
		if whole[i]:
			return i
	return -1


# ------------------------------------------------------------------ struck

## A blow (Shaped): it meets the first part in its way from `from` (part_met), and wakes it. It
## always takes the blow itself.
func blow(from: Vector2, dir: Vector2, _damage: int, empowered: bool) -> bool:
	if not done():
		_wake()
		_strike(part_met(from), dir, empowered)
	return true


## An arrow met it at `at`: as a plain blow from there (part_met).
func arrow_hit(at: Vector2, dir: Vector2) -> void:
	if not done():
		_wake()
		_strike(part_met(at), dir, false)


## A blow heading `dir` on `k` (a chunk, or AT_HEART): a bare heart is wounded by anything; a chunk
## shatters to an `empowered` blow and is glanced off by a plain one.
func _strike(k: int, dir: Vector2, empowered: bool) -> void:
	if k == AT_HEART:
		_wound(dir)
	elif empowered:
		shatter(k, dir)
	else:
		_glance(k, dir)


## A plain blow glanced off chunk `i`: grit, and it shows.
func _glance(i: int, dir: Vector2) -> void:
	struck_t[i] = t
	RisoFx.burst(&"hit", part_center(i) - dir.normalized() * PARTS[i].z, -dir, [RisoPrint.BLUE, RisoPrint.NIGHT])
	Wound.shake(3.0, 0.06)


## Chunk `i` shatters (an empowered blow heading `dir`).
func shatter(i: int, dir: Vector2) -> void:
	if not whole[i]:
		return
	whole[i] = false
	shattered_t[i] = t
	RisoFx.burst(&"hit", part_center(i), dir, [RisoPrint.BLUE, RisoPrint.NIGHT])
	Wound.shake(10.0, 0.2)


## Its bare heart is wounded (heading `dir`): one crack, and with the last it dies.
func _wound(dir: Vector2) -> void:
	wound.hp -= 1
	heart_t = t
	RisoFx.burst(&"hit", heart_center(), dir, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(8.0, 0.16)
	Wound.hit_stop(Wound.KILL_STOP if wound.hp <= 0 else Wound.HIT_STOP)
	if wound.hp <= 0:
		die()


## A parried slam: SHARDS lode shards fly out of it, spread from one side to the other, to fall and lie
## where they land (LodeShard).
func shed_shards() -> void:
	if map_info == null or done():
		return
	for i: int in range(SHARDS):
		var side: float = lerpf(-1.0, 1.0, float(i) / float(maxi(SHARDS - 1, 1)))
		var shard: LodeShard = LodeShard.new()
		shard.golem = self
		shard.cell = cell
		shard.velocity = Vector2(SHARD_KICK.x * side, SHARD_KICK.y)
		map_info.map_elements.add_child(shard)
		shard.global_position = heart_center()
		shards.append(shard)
	loose_t = 0.0
	RisoFx.burst(&"gain", heart_center(), Vector2.UP, [RisoPrint.ACCENT, RisoPrint.BLUE])


## Its heart's last wound: it falls apart.
func die() -> void:
	if done():
		return
	dying = true
	dead_t = 0.0
	remove_from_group(&"hex_target")
	Wound.shake(14.0, 0.4)
	RisoFx.burst(&"gain", heart_center(), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])


## Slain at once (the F7 panel's Slay boss, MapInfo.slay_boss).
func slay() -> void:
	if slain:
		return
	wound.hp = 0
	_slain()


## It is slain: its relic waits where it stood, and it is gone, all of it lying loose with it.
func _slain() -> void:
	slain = true
	for loose: Node2D in _loose():
		loose.queue_free()
	shards.clear()
	stones.clear()
	called.clear()
	if map_info != null:
		map_info.boss_slain(boss, relic_at())
	queue_free()


## Where its relic waits: in the middle of the cell it stands in, or, that over a hole it was
## stepping over, the nearest beside it with floor under it.
func relic_at() -> Vector2:
	if map_info == null:
		return global_position
	var at: Vector2i = map_info.cell_at(global_position + Vector2(0.0, -cell * 0.5))
	for d: int in range(STEP_OVER + 2):
		for side: int in [-d, d]:
			var c: Vector2i = at + Vector2i(side, 0)
			if map_info.world.is_ground(c + Vector2i.DOWN) and not map_info.world.is_ground(c):
				return map_info.cell_position(c)
	return map_info.cell_position(at)


# ------------------------------------------------------------------ what it does

func _physics_process(delta: float) -> void:
	_let_go()
	if dying:
		dead_t += delta
		if dead_t >= DIE_TIME and not slain:
			_slain()
		sync_fists()
		return
	if map_info == null or floors.is_empty() or slain:
		return
	# A harder preset runs it faster (Difficulty.haste).
	delta *= Difficulty.haste()
	var player: Player = map_info.player if map_info.player != null and is_instance_valid(map_info.player) else null
	var stun_now: bool = stunned()
	if stun_now and not _was_stunned and state == State.SLAM:
		shed_shards()
	if _was_stunned and not stun_now:
		state = State.REST
		timer = REST
	_was_stunned = stun_now
	if not _loose().is_empty() and not stun_now and state != State.RECALL:
		loose_t += delta
	_pose_step(delta)
	if not stun_now:
		match state:
			State.SLEEP:
				if player != null and _in_hall(player):
					_wake()
			State.HUNT:
				_hunt(delta, player)
			State.REST:
				timer -= delta
				if timer <= 0.0:
					state = State.HUNT
			State.SLAM_WARN:
				timer -= delta
				if timer <= 0.0:
					state = State.SLAM
					timer = SLAM_HOLD
					var at: Vector2 = global_position + Vector2(FIST_AT.x * float(face), 0.0)
					GolemShock.send(self, at, floor_y(storey()))
					Wound.shake(12.0, 0.2)
			State.SLAM:
				timer -= delta
				if timer <= 0.0:
					state = State.REST
					timer = SLAM_REST
			State.HURL_WARN:
				timer -= delta
				if timer <= 0.0:
					_hurl(player)
			State.LEAP_WARN:
				timer -= delta
				if timer <= 0.0:
					state = State.LEAP
					timer = LEAP_TIME
			State.LEAP:
				_leap(delta)
			State.RECALL_WARN:
				timer -= delta
				if timer <= 0.0:
					state = State.RECALL
			State.RECALL:
				_recall(delta)
	sync_fists()


## Its pose for this step: rising as it wakes (slumped asleep, crouched to leap), and its steps by
## how far it has walked.
func _pose_step(delta: float) -> void:
	rise = move_toward(rise, 0.0 if state == State.SLEEP else 1.0, delta / WAKE_TIME)
	var want: float = lerpf(SLUMP, 1.0, rise) * (CROUCH if state == State.LEAP_WARN else 1.0)
	squash = move_toward(squash, want, delta * 1.5)
	var moved: float = 0.0 if _last_x == INF or state == State.LEAP else absf(global_position.x - _last_x)
	_last_x = global_position.x
	stride += moved
	gait = move_toward(gait, 1.0 if moved > 0.2 else 0.0, delta * 5.0)


## Its fists hurt only while they are down in a slam, and not while it is stunned or dying.
func sync_fists() -> void:
	var on: bool = state == State.SLAM and not stunned() and not done()
	fists.position = Vector2(FIST_AT.x * float(face), FIST_AT.y)
	if fists.collision != null and fists.collision.disabled == on:
		fists.collision.set_deferred("disabled", not on)


## Woken (the wizard in its hall, or struck): it hunts.
func _wake() -> void:
	if state == State.SLEEP:
		state = State.HUNT
		timer = 0.0


## Everything of it lying loose or flying: its shards and its hurled chunks.
func _loose() -> Array[Node2D]:
	var out: Array[Node2D] = []
	out.append_array(shards)
	out.append_array(stones)
	return out


## Shards taken and anything freed are let go (a typed filter cannot hold a freed one).
func _let_go() -> void:
	for i: int in range(shards.size() - 1, -1, -1):
		if not is_instance_valid(shards[i]) or shards[i].is_queued_for_deletion():
			shards.remove_at(i)
	for i: int in range(stones.size() - 1, -1, -1):
		if not is_instance_valid(stones[i]) or stones[i].is_queued_for_deletion():
			stones.remove_at(i)
	for i: int in range(called.size() - 1, -1, -1):
		if not is_instance_valid(called[i]) or called[i].is_queued_for_deletion():
			called.remove_at(i)
	if _loose().is_empty():
		loose_t = 0.0


## After the wizard: facing them, it calls back what lies loose, slams them near, hurls at them far
## off, walks after them along its floor, or, them on another storey, goes to the gap between and
## leaps.
func _hunt(delta: float, player: Player) -> void:
	hurl_wait = maxf(0.0, hurl_wait - delta)
	if player == null or not _in_hall(player):
		apart_t = 0.0
		return
	var at: Vector2 = player.global_position
	if absf(at.x - global_position.x) > 4.0:
		face = 1 if at.x > global_position.x else -1
	if loose_t >= RECALL_DELAY:
		_call_back(at)
		return
	var mine: int = storey()
	var theirs: int = storey_of(at)
	var far: bool = absf(at.x - global_position.x) >= HURL_MIN or theirs != mine
	if hurl_wait <= 0.0 and far and _to_hurl() >= 0 and sees(at):
		hurling = _to_hurl()
		state = State.HURL_WARN
		timer = HURL_WARN
		return
	var span: Vector2 = reach_along(mine, global_position.x)
	if theirs == mine:
		apart_t = 0.0
		if absf(at.x - global_position.x) <= SLAM_RANGE:
			state = State.SLAM_WARN
			timer = SLAM_WARN
			return
		global_position.x = move_toward(global_position.x, clampf(at.x, span.x, span.y), WALK * delta)
		return
	apart_t += delta
	var gap: Rect2i = gaps[mine - 1] if theirs < mine else gaps[mine]
	var to: float = clampf(_gap_mid(gap), span.x, span.y)
	global_position.x = move_toward(global_position.x, to, WALK * delta)
	if absf(global_position.x - to) < 2.0 and apart_t >= LEAP_AFTER:
		_plan_leap(theirs < mine, gap, at)


## Crouch to leap up through `gap` (`up`) to the gallery over it, beside the gap on the wizard's
## side, or down it to the floor under it; the spot marked (LEAP_WARN).
func _plan_leap(up: bool, gap: Rect2i, at: Vector2) -> void:
	var mine: int = storey()
	var to_storey: int = mine - 1 if up else mine + 1
	var x: float = _gap_mid(gap)
	if up:
		x = _gap_left(gap) - FOOT - LEAP_CLEAR if at.x < _gap_mid(gap) else _gap_right(gap) + FOOT + LEAP_CLEAR
	var span: Vector2 = reach_along(to_storey, x)
	leap_from = global_position
	leap_to = Vector2(clampf(x, span.x, span.y), floor_y(to_storey))
	leap_down = not up
	state = State.LEAP_WARN
	timer = LEAP_WARN
	apart_t = 0.0


## In the air: up first and then across onto the gallery (a leap up), or across the gap's edge first
## and then down (a leap down); landing, a shockwave both ways.
func _leap(delta: float) -> void:
	timer -= delta
	var u: float = clampf(1.0 - timer / LEAP_TIME, 0.0, 1.0)
	var apex: float = minf(leap_from.y, leap_to.y) - LEAP_OVER
	var y: float = lerpf(leap_from.y, apex, 1.0 - pow(1.0 - u * 2.0, 2.0)) if u < 0.5 else lerpf(apex, leap_to.y, pow(u * 2.0 - 1.0, 2.0))
	var across: float = smoothstep(0.0, 0.5, u) if leap_down else smoothstep(0.5, 1.0, u)
	global_position = Vector2(lerpf(leap_from.x, leap_to.x, across), y)
	if u >= 1.0:
		global_position = leap_to
		GolemShock.send(self, leap_to, leap_to.y)
		Wound.shake(14.0, 0.25)
		state = State.REST
		timer = REST


## Hurl the chunk it holds up at where the wizard is now: gone from it while it flies and lies
## (thrown), a GolemStone.
func _hurl(player: Player) -> void:
	var i: int = hurling
	hurling = -1
	state = State.REST
	timer = REST
	hurl_wait = HURL_EVERY
	if i < 0 or not whole[i] or player == null:
		return
	var from: Vector2 = global_position + Vector2(0.0, -HURL_UP)
	whole[i] = false
	thrown[i] = true
	var stone: GolemStone = GolemStone.new()
	stone.golem = self
	stone.part = i
	stone.cell = cell
	stone.velocity = GolemStone.lob(from, player.global_position, HURL_FLIGHT)
	map_info.map_elements.add_child(stone)
	stone.global_position = from
	stones.append(stone)
	Wound.shake(6.0, 0.12)


## Call back all that lies loose: each is given its way home, through `at` (where the wizard is) to
## where it belongs, and the warning starts (RECALL_WARN).
func _call_back(at: Vector2) -> void:
	called = _loose()
	var regrow: Array[int] = []
	for i: int in COVERS:
		if not whole[i] and not thrown[i]:
			regrow.append(i)
	for i: int in range(PARTS.size()):
		if not whole[i] and not thrown[i] and not i in regrow:
			regrow.append(i)
	for loose: Node2D in called:
		var part: int = -1
		if loose is GolemStone:
			part = (loose as GolemStone).part
		elif not regrow.is_empty():
			part = int(regrow.pop_front())
		loose.set_meta(&"part", part)
		var home: Vector2 = part_center(part) if part >= 0 else heart_center()
		loose.set_meta(&"way", PackedVector2Array([loose.global_position, at, home]))
		if loose is LodeShard:
			(loose as LodeShard).called = true
		elif loose is GolemStone:
			(loose as GolemStone).called = true
	state = State.RECALL_WARN
	timer = RECALL_WARN
	loose_t = 0.0


## What it called flies home along its way, hurting on the way; home, a hurled chunk is whole again
## and a shard regrows the chunk it was given. All home, it rests.
func _recall(delta: float) -> void:
	for k: int in range(called.size() - 1, -1, -1):
		if not is_instance_valid(called[k]) or called[k].is_queued_for_deletion():
			continue
		var loose: Node2D = called[k]
		var way: PackedVector2Array = loose.get_meta(&"way")
		var part: int = int(loose.get_meta(&"part"))
		# Home moves with its pose; the rest of the way is as it was set.
		way[2] = part_center(part) if part >= 0 else heart_center()
		var leg: int = 1 if loose.global_position.distance_to(way[1]) > 1.0 and not loose.has_meta(&"passed") else 2
		var next: Vector2 = loose.global_position.move_toward(way[leg], RECALL_SPEED * delta)
		loose.global_position = next
		if leg == 1 and next.distance_to(way[1]) <= 1.0:
			loose.set_meta(&"passed", true)
		if leg == 2 and next.distance_to(way[2]) <= 1.0:
			_home(loose, part)
	_let_go()
	if called.is_empty():
		state = State.REST
		timer = REST


## `loose` is home: its chunk `part` whole again (none for a shard with nothing to regrow), and it is
## gone.
func _home(loose: Node2D, part: int) -> void:
	if part >= 0:
		whole[part] = true
		thrown[part] = false
	RisoFx.burst(&"hit", loose.global_position, Vector2.ZERO, [RisoPrint.BLUE, RisoPrint.NIGHT])
	Wound.shake(4.0, 0.08)
	called.erase(loose)
	loose.queue_free()


# ------------------------------------------------------------------ the print

## Its heart in accent, bare paper about it, cracked in night as it is wounded, glowing out behind its
## chunks so the glow shows through the gaps between them; its chunks over it, iron-blue lodestone
## (chunk_inks), each with a vein of accent ore running in toward its heart, paler a moment when a
## blow glances off; sparks of iron drawn in to its heart; its eyes, slits of paper on its head; a
## shattered chunk's bits flying off and fading. Asleep it is slumped and dim, its eyes shut;
## stunned, its chunks sag loose, its veins flicker and stars circle its head. Its warnings in pink:
## its fists as it raises them and its eyes, the chunk it holds up to hurl, the spot it will land a
## leap on, and the ways home of what it calls back. Dying, its chunks fall to the floor in a heap
## and it all fades.
func _process(delta: float) -> void:
	t += delta
	if ink == null:
		return
	ink.global_position = Vector2.ZERO
	ink.begin()
	var u: float = clampf(dead_t / DIE_TIME, 0.0, 1.0) if dying else 0.0
	var fade: float = 1.0 - u
	var breath: float = 0.5 + 0.5 * sin(t * 2.4)
	var stun: bool = stunned()
	var hc: Vector2 = heart_center()
	var warning: bool = state in [State.SLAM_WARN, State.HURL_WARN, State.LEAP_WARN, State.RECALL_WARN]
	var pulse: float = WARN_PINK * (0.7 + 0.3 * sin(t * 18.0))
	if not dying:
		var glow: float = GLOW_COVER * lerpf(0.35, 1.0, rise) * (0.8 + 0.2 * breath) * (0.5 if stun else 1.0)
		_glow(hc, HEART_R, HEART_R * GLOW, glow)
	var heart: PackedVector2Array = RisoShapes.circle(hc, HEART_R * (1.0 - 0.4 * u), 20)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [heart])
	var flash: float = clampf(1.0 - (t - heart_t) / FLASH_TIME, 0.0, 1.0)
	ink.ink(RisoPrint.ACCENT, fade * lerpf(0.6, 1.0, rise), [heart])
	if flash > 0.0:
		ink.ink(RisoPrint.PINK, 0.6 * flash * fade, [heart], false)
	var cracks: Array[PackedVector2Array] = []
	for k: int in range(HEART - maxi(wound.hp, 0)):
		var a: float = TAU * RisoDecor.h(0, Vector2i(k, 0), CRACK_DEAL)
		var from: Vector2 = hc + Vector2.from_angle(a) * HEART_R * 0.15
		var bend: Vector2 = hc + Vector2.from_angle(a + 0.4) * HEART_R * 0.55
		cracks.append(RisoShapes.strand(from, bend, CRACK_W))
		cracks.append(RisoShapes.strand(bend, hc + Vector2.from_angle(a - 0.2) * HEART_R, CRACK_W * 0.7))
	ink.ink(RisoPrint.NIGHT, fade, cracks)
	ink.knock([RisoPrint.ACCENT], [RisoShapes.sparkle(hc + Vector2(-HEART_R * 0.35, -HEART_R * 0.35), 6.0)])
	# Its chunks: the accent of its glow and heart knocked out under them all first, so neither shows
	# through a chunk, then each printed.
	var floor_at: float = global_position.y
	var at: Array[Vector2] = []
	var stones: Array[PackedVector2Array] = []
	var bits: Array[PackedVector2Array] = []
	for i: int in range(PARTS.size()):
		var c: Vector2 = part_center(i)
		# Dying, each chunk drops to the floor where it is.
		c.y = lerpf(c.y, floor_at - PARTS[i].z * 0.7, u * u)
		at.append(c)
		if whole[i]:
			stones.append(chunk_shape(i, c))
		elif not thrown[i] and t - shattered_t[i] < SHATTER_TIME:
			_bits(i, (t - shattered_t[i]) / SHATTER_TIME, bits)
	ink.knock([RisoPrint.ACCENT], stones)
	var vein: float = VEIN * lerpf(0.35, 1.0, rise) * (0.25 + 0.75 * absf(sin(t * 23.0)) if stun else 0.85 + 0.15 * breath)
	for i: int in range(PARTS.size()):
		if not whole[i]:
			continue
		var warned: bool = (state == State.SLAM_WARN and i in ARMS) or (state == State.HURL_WARN and i == hurling)
		var pale: float = 0.35 if t - struck_t[i] < FLASH_TIME else 0.0
		chunk_inks(ink, i, at[i], 0.0, (hc - at[i]).normalized(), vein * fade, pulse if warned else 0.0, pale, fade)
	ink.ink(RisoPrint.NIGHT, STONE_NIGHT + 0.3, bits)
	ink.ink(RisoPrint.BLUE, STONE_BLUE, bits, false)
	if not dying:
		_eyes(warning, pulse)
		if not stun and rise > 0.5:
			_filings(hc, breath)
		if stun:
			_stars(part_center(HEAD) + Vector2(0.0, -PARTS[HEAD].z - 30.0))
	var marks: Array[PackedVector2Array] = []
	if state in [State.LEAP_WARN, State.LEAP]:
		marks.append(RisoShapes.rrect(leap_to.x - FOOT * 1.6, leap_to.y - MARK_H, FOOT * 3.2, MARK_H, MARK_H * 0.5))
	if state == State.RECALL_WARN:
		for k: int in range(called.size()):
			if not is_instance_valid(called[k]):
				continue
			var loose: Node2D = called[k]
			if loose.has_meta(&"way"):
				var way: PackedVector2Array = loose.get_meta(&"way")
				marks.append(RisoShapes.strand(loose.global_position, way[1], RECALL_W))
				marks.append(RisoShapes.strand(way[1], way[2], RECALL_W))
	ink.ink(RisoPrint.PINK, WARN_PINK * (0.6 + 0.4 * sin(t * 14.0)), marks)
	ink.finish()


## Its heart's glow: accent from `r0` round `c` (at `cover`) fading out to `r1`.
func _glow(c: Vector2, r0: float, r1: float, cover: float) -> void:
	var quads: Array[PackedVector2Array] = []
	var fades: Array[PackedFloat32Array] = []
	var n: int = 32
	for i: int in range(n):
		var a: Vector2 = Vector2.from_angle(TAU * float(i) / float(n))
		var b: Vector2 = Vector2.from_angle(TAU * float(i + 1) / float(n))
		quads.append(PackedVector2Array([c + a * r0, c + a * r1, c + b * r1, c + b * r0]))
		fades.append(PackedFloat32Array([cover, 0.0, 0.0, cover]))
	ink.ink_graded(RisoPrint.ACCENT, quads, fades)


## Its eyes on its head, if its head is whole: slits of paper, slanting in toward the way it faces,
## opening as it wakes (a dark line asleep), pink while it warns (`warning`, at `pulse`).
func _eyes(warning: bool, pulse: float) -> void:
	if not whole[HEAD]:
		return
	var head: Vector2 = part_center(HEAD) + Vector2(float(face) * 8.0, -4.0)
	var slits: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var c: Vector2 = head + Vector2(side * EYES_APART, 0.0)
		var slant: float = side * 0.25
		slits.append(Transform2D(slant, c) * RisoShapes.almond(Vector2.ZERO, EYE.x, maxf(EYE.y * rise, 1.5), 8))
	if rise < 0.3:
		ink.ink(RisoPrint.NIGHT, 0.8, slits, false)
		return
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], slits)
	if warning:
		ink.ink(RisoPrint.PINK, pulse, slits)


## Sparks of iron drawn in to its heart at `hc`, curling as they come, as to a lodestone.
func _filings(hc: Vector2, breath: float) -> void:
	for k: int in range(FILINGS):
		var u: float = fmod(t / FILING_TRIP + float(k) / float(FILINGS), 1.0)
		var a: float = TAU * RisoDecor.h(0, Vector2i(k, 1), SHAPE_DEAL) + u * 2.4
		var p: Vector2 = hc + Vector2.from_angle(a) * lerpf(HEART_R * GLOW * 1.3, HEART_R + 6.0, u * u)
		ink.ink(RisoPrint.ACCENT, sin(u * PI) * (0.7 + 0.3 * breath), [RisoShapes.sparkle(p, lerpf(3.0, 7.0, u))])


## Stars circling over its head at `at` while it is stunned, fewer as the stun wears off.
func _stars(at: Vector2) -> void:
	var frac: float = stunner.fraction()
	var stars: Array[PackedVector2Array] = []
	for i: int in range(3):
		var a: float = t * 2.6 + TAU * float(i) / 3.0
		var p: Vector2 = at + Vector2(cos(a) * 70.0, sin(a) * 16.0)
		stars.append(Transform2D(t * 1.8 + float(i), p) * RisoShapes.sparkle(Vector2.ZERO, 10.0 + 6.0 * frac))
	ink.ink(RisoPrint.ACCENT, 0.9, stars)


## Chunk `i` as a stone round `c`: CORNERS corners, each pulled in a little (hashed, the same
## everywhere), and each bevelled (BEVEL): a broken block of ore.
static func chunk_shape(i: int, c: Vector2) -> PackedVector2Array:
	var r: float = PARTS[i].z
	var corners: PackedVector2Array = PackedVector2Array()
	for k: int in range(CORNERS):
		var a: float = TAU * (float(k) + 0.35 * RisoDecor.h(0, Vector2i(i, k), SHAPE_DEAL)) / float(CORNERS)
		var dent: float = 1.0 - DENT * RisoDecor.h(0, Vector2i(i, k), SHAPE_DEAL + 1)
		corners.append(c + Vector2.from_angle(a) * r * dent)
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in range(CORNERS):
		var corner: Vector2 = corners[k]
		pts.append(corner.lerp(corners[(k - 1 + CORNERS) % CORNERS], BEVEL))
		pts.append(corner.lerp(corners[(k + 1) % CORNERS], BEVEL))
	return pts


## Print chunk `i` round `c`, turned `turn` (radians), on `ink`, at `fade`: iron-blue lodestone with
## its shaded side, its lit face, patches of ore and a glint; a vein of ore running in from its edge
## the way `toward` points, in accent at `vein` (dark ore below VEIN_LIT; none at 0); pink over it
## at `pink` (a warning, or a hazard on its way), and its ink lifted at `pale` (a blow glancing
## off). The accent under it is the caller's to knock out first.
static func chunk_inks(ink: InkCanvas, i: int, c: Vector2, turn: float, toward: Vector2, vein: float, pink: float, pale: float, fade: float) -> void:
	var r: float = PARTS[i].z
	var xf: Transform2D = Transform2D(turn, c)
	var stone: PackedVector2Array = xf * chunk_shape(i, Vector2.ZERO)
	ink.ink(RisoPrint.BLUE, STONE_BLUE * fade, [stone])
	ink.ink(RisoPrint.NIGHT, STONE_NIGHT * fade, [stone], false)
	var shaded: PackedVector2Array = PackedVector2Array([c + Vector2(-2.0 * r, 0.45 * r), c + Vector2(2.0 * r, -0.15 * r), c + Vector2(2.0 * r, 2.0 * r), c + Vector2(-2.0 * r, 2.0 * r)])
	ink.ink(RisoPrint.NIGHT, SHADE * fade, Geometry2D.intersect_polygons(stone, shaded), false)
	var lit: PackedVector2Array = PackedVector2Array([c + Vector2(-2.0 * r, -2.0 * r), c + Vector2(0.2 * r, -2.0 * r), c + Vector2(-2.0 * r, -0.1 * r)])
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], LIT * fade, Geometry2D.intersect_polygons(stone, lit))
	var ore: Array[PackedVector2Array] = []
	for k: int in range(2):
		var p: Vector2 = xf * (Vector2(RisoDecor.h(0, Vector2i(i, k), ORE_DEAL) - 0.5, RisoDecor.h(0, Vector2i(i, k), ORE_DEAL + 1) - 0.5) * r * 0.9)
		ore.append(RisoShapes.ellipse(p, r * 0.16, r * 0.09, 10, RisoDecor.h(0, Vector2i(i, k), ORE_DEAL + 2) * PI))
	ink.ink(RisoPrint.NIGHT, ORE * fade, ore, false)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.sparkle(xf * Vector2(-0.38 * r, -0.42 * r), 4.0 + r * 0.04)])
	if vein > 0.0 and toward != Vector2.ZERO:
		var bend: float = (RisoDecor.h(0, Vector2i(i, 7), ORE_DEAL) - 0.5) * 1.2
		var side: Vector2 = toward.orthogonal() * (RisoDecor.h(0, Vector2i(i, 8), ORE_DEAL) - 0.5) * r * 0.5
		var mouth: Vector2 = c + toward * r + side
		var line: PackedVector2Array = PackedVector2Array([mouth, mouth - toward.rotated(bend) * r * VEIN_LONG * 0.5, mouth - toward.rotated(-bend * 0.5) * r * VEIN_LONG])
		var veins: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in RisoDecor.strip(line, VEIN_W, VEIN_W * 0.3):
			veins.append_array(Geometry2D.intersect_polygons(piece, stone))
		if vein >= VEIN_LIT:
			ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], veins)
			ink.ink(RisoPrint.ACCENT, vein, veins, false)
		else:
			ink.ink(RisoPrint.NIGHT, ORE * fade, veins, false)
	if pink > 0.0:
		ink.ink(RisoPrint.PINK, pink, [stone], false)
	if pale > 0.0:
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], pale, [stone])


## The bits of shattered chunk `i`, `u` of the way through flying off (0 to 1), into `out`.
func _bits(i: int, u: float, out: Array[PackedVector2Array]) -> void:
	var c: Vector2 = part_center(i)
	var size: float = PARTS[i].z * 0.35 * (1.0 - u)
	for k: int in range(5):
		var a: float = TAU * RisoDecor.h(0, Vector2i(i, k), BITS_DEAL)
		var at: Vector2 = c + Vector2.from_angle(a) * BITS_FLY * u + Vector2(0.0, BITS_FLY * u * u)
		out.append(RisoShapes.tri(at + Vector2.from_angle(a) * size, at + Vector2.from_angle(a + 2.2) * size, at + Vector2.from_angle(a + 4.1) * size))
