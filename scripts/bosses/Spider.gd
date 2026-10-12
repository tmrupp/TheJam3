class_name Spider
extends Node2D
## The spider (Bosses.UP's first): the boss at the top of the crags, fought in its keep
## (SpiderKeep), built at the top of their gate level (docs/REGIONS_PLAN.md §6). It
## hangs in the dark under the roof, on a canopy of web, until the wizard comes within WAKE_RANGE;
## then it hunts them from up there:
## - It scuttles along the canopy to be over them, or, while they are under a floor, over the hole
##   nearest them, and waits. With them under it and nothing but air (and its own webs) between, it
##   rears for WARN, drops on its thread to where they were (DROP_SPEED), holds its bite there for
##   BITE_HOLD, and climbs back up (CLIMB_SPEED), resting REST before the next.
## - Its back is hard: a strike glances off it (SpiderWound). It is open only while it bites (its
##   face), while stunned, and once it is down on a floor.
## - A hex bolt or a dash across its thread cuts it (thread_across): it falls to the floor below,
##   tumbling, and lies there on its back for DOWNED; then it scurries along that floor to the
##   nearest spot with a clear line up to the roof (or off into a hole, to fall on down) and climbs
##   a new thread back up, which can be cut again. Open from the cut until it is back on a thread.
## - A parried bite stuns it on the spot (Stunner.parry_only: nothing else stuns it), hanging limp
##   on its thread; when the stun passes it climbs back up.
## - Its health is its eyes (EYES): each wound puts one out, whatever struck it. With the last it
##   curls up, falls and shrivels (DIE_TIME), it is slain, and its relic waits on the floor where it
##   lies (MapInfo.boss_slain).
## - Its webs (SpiderWeb) are strung across the holes of the keep's floors: sticky, slowing the
##   wizard and keeping their dash from coming back; a bolt or a dash tears one, and it spins it
##   again a while later.
## - It spits from the canopy: every SPIT_EVERY seconds, while it sees the wizard (within SPIT_RANGE,
##   nothing but air between) and is not about to drop on them, it rears for SPIT_WARN and spits a
##   glob of web at them (WebShot), which sticks where it lands, on the wizard or the rock, as a
##   small web of its own (splat) that holds them a while; every EGG_EVERY-th spit is an egg sac
##   instead (EggSac), lobbed at them, which hatches spiderlings (Spiderling) that run at the wizard
##   and wither away after a while. No more than BROOD_MOST of its brood are about at once.
## - Crossbows set in the keep's walls shoot into the hall at the wizard (SpiderKeep.arm), and their
##   arrows pierce its back (Bullet, pierce): lure it into their line.
## A lantern death brings it back whole, as the keep reloads. Nothing here draws from any RNG: its
## choices follow the wizard and the keep's layout.

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## Its eyes, the wounds it takes.
const EYES: int = 8
## How big it is, against the sizes its shapes are drawn at: everything about its size below
## grows with it (its abdomen's tip is 63 of these behind its middle, its head 26 ahead, its body
## 27 either side).
const ART: float = 2.6
## Its body, what a bolt or a dash must meet to strike it: BODY_R px round a line from BODY_BACK
## px behind its middle (toward its abdomen) to BODY_FRONT px ahead (toward its head). Its thread
## leaves its abdomen's tip, THREAD_TOP px behind its middle, clear of the body's reach, so a way
## over its back meets the thread rather than the body. Its bite reaches BITE_R px from its middle.
const BODY_R: float = 22.0 * ART
const BODY_BACK: float = 25.0 * ART
const BODY_FRONT: float = 25.0 * ART
const THREAD_TOP: float = 60.0 * ART
const BITE_R: float = 29.0 * ART
## How near (px) past its body a bolt strikes it.
const BOLT_REACH: float = 12.0
## Where its middle sits (px): under the roof on the canopy (hanging by its abdomen's tip), over a
## floor it stands on, and lying on its back on one.
const HANG: float = THREAD_TOP + 4.0
const STAND: float = 29.0 * ART
const LIE: float = 25.0 * ART
## How near (px) its middle comes to the hall's walls.
const EDGE: float = 30.0 * ART
## How near (cells) the wizard must come to wake it.
const WAKE_RANGE: float = 16.0
## How fast it goes (px/s): along the canopy, dropping, climbing a thread, scurrying on a floor;
## and how hard it falls (px/s²) and how fast at most.
const CRAWL: float = 230.0
const DROP_SPEED: float = 1500.0
const CLIMB_SPEED: float = 400.0
const SCURRY: float = 240.0
const FALL_GRAVITY: float = 2200.0
const FALL_MAX: float = 1500.0
## How near over the wizard (px across) it must be to drop on them: within its bite.
const DROP_SLACK: float = BITE_R
## Seconds: rearing before a drop (the warning), holding the bite at the bottom, resting on the
## canopy after a strike, lying on its back once fallen, and shrivelling as it dies.
const WARN: float = 0.45
const BITE_HOLD: float = 0.55
const REST: float = 0.9
const DOWNED: float = 2.8
const DIE_TIME: float = 1.3
## How near (px) a bolt's way, and a dash's, must pass its thread to cut it.
const THREAD_REACH: float = 16.0
const DASH_THREAD_REACH: float = 36.0
## How far (px) either side of its middle it looks for rock when it looks for a clear line: most of
## its body's width, so it drops and climbs only through the middle of a hole.
const SPAN: float = 18.0 * ART
## How fast it turns (rad/s) and tumbles as it falls.
const TURN: float = 12.0
const TUMBLE: float = 7.0
## Seconds an eye put out flashes pink, and a cut thread's end curls away.
const FLASH_TIME: float = 0.25
const CURL_TIME: float = 0.6
## The print: its body's covers of night and blue, its webs' and canopy's strands (how much ink
## they lift, and how wide), and its thread's.
const BODY_NIGHT: float = 0.92
const BODY_BLUE: float = 0.55
const WEB_LIFT: float = 1.0
const CANOPY_LIFT: float = 1.0
const STRAND: float = RisoDecor.WEB_W
const THREAD_LIFT: float = 0.85
const THREAD_W: float = 4.0
## How its webs are spun (plain_web): as the decor's cobwebs are, their strands as wide
## (RisoDecor.WEB_W, WEB_RING_W), and their lines WEB_SPREAD times as far apart as the decor's
## whatever their size, so a big web has more lines than a small one but is never a mesh. Its rings
## are RisoDecor.WEB_RING_GAP times that apart, the outer one RisoDecor.WEB_RINGS[1] of the way out.
## Its spokes stay about RisoDecor.WEB_SPOKE_GAP times that apart all the way out, as a real web's
## do: HUB_SPOKES to a whole turn run in to the hub, and wherever those about a ring have drawn
## SPLIT times that far apart, a new spoke starts from the ring between each two. Each web is a
## little uneven, hashed from where it is (no RNG): its spokes turned up to SPOKE_JITTER of a step
## and each its own length (SPOKE_LONG, of its reach), each ring off true by up to RING_JITTER of
## their spacing where it meets a spoke, and RING_GAPS of the rings' pieces left out. A web across a
## hole is two splats side by side; a corner web under the roof a quarter one CORNER_REACH cells
## long; a splat (a spat glob, stuck) a round one SPLAT cells across.
const CORNER_REACH: float = 2.8
const WEB_SPREAD: float = 1.2
const HUB_SPOKES: int = 6
const SPLIT: float = 1.4
const SPOKE_JITTER: float = 0.2
const SPOKE_LONG: Vector2 = Vector2(0.9, 1.05)
const RING_JITTER: float = 0.12
const RING_GAPS: float = 0.06
## A splat and a hole's webs join what they touch, and only that (_moor): rock or another web no
## further from their rim than ADJACENT of their rings' spacing. Against rock, each spoke runs to
## the rock's face (within its reach or just past it) and stops there, the rings past it left off,
## so the web lies flat against the rock as if spun on it. Two webs that touch share the line where
## they meet (the one the two circles' edges cross on, or would): each one's spokes run to it and
## stop, its rings stop short of it, and one thread runs along it (_draw_seams), so they read as one
## web.
const ADJACENT: float = 1.0
## How finely (px) a spoke's way is felt along for rock, before the rock's face is found to a pixel.
const MOOR_STEP: float = 6.0
## Its look: its abdomen's half-width and half-height and how much it tapers to a point behind, its
## head's half-width (its height follows), its legs' thickness, and its fangs' length (px).
const ABDOMEN: Vector2 = Vector2(27.0, 33.0)
const TAPER: float = 0.5
const HEAD_W: float = 19.5
const LEG_THICK: float = 1.0
const FANG: float = 16.0
## How its legs move: set poses, not worked out step by step. Each leg is a femur and a shank
## (FEMUR, SHANK long), set at fixed angles about its hip (a spread pose, and drawn in, `curl`, on
## its back, stunned, on its thread, dying), the shank's last TARSUS its foot. On a floor each shank
## reaches down to the floor instead (blended in as it gets up). Walking (along the canopy or a
## floor) its legs swing WALK_SWING either way about the pose, in two sets of four in turn, a
## stride every STRIDE px it goes, lifted STEP_LIFT off a floor as they swing forward. Its curl, its
## stance on a floor and its walking ease in at POSE_EASE (a second), so it never jumps between poses.
const FEMUR: float = 38.0
const SHANK: float = 52.0
const TARSUS: float = 0.27
const WALK_SWING: float = 0.3
const STRIDE: float = 150.0
const STEP_LIFT: float = 18.0
const POSE_EASE: float = 10.0
## How fast it must go (px/s) to walk in full stride; slower, its legs swing less.
const WALKING: float = 80.0
## Spitting (see the class description): seconds between spits (the first SPIT_FIRST after it
## wakes), and rearing before one (the tell); how far it sees to spit (cells); every EGG_EVERY-th
## spit is an egg sac; how many spiderlings a sac hatches and the most of its brood (sacs and
## spiderlings) about at once.
const SPIT_EVERY: float = 2.8
const SPIT_FIRST: float = 1.5
const SPIT_WARN: float = 0.4
const SPIT_RANGE: float = 12.0
const EGG_EVERY: int = 3
const BROOD: int = 3
const BROOD_MOST: int = 6
## How big a splat is (cells across), and how long it holds before it falls away (seconds).
const SPLAT: float = 1.4
const SPLAT_LIFE: float = 6.0

enum State { SLEEP, HUNT, WARN, DROP, BITE, CLIMB, FALL, DOWN, SCURRY, RECLIMB, DYING, SPIT }

var map_info: MapInfo
## Which boss it is (Bosses).
var boss: StringName = &""
## A cell's size in pixels, and the middle of cell (0, 0).
var cell: float = 64.0
var origin: Vector2 = Vector2.ZERO
## The keep (LevelGen.keep): its inside, in cells; and in pixels the roof's underside, the hall's
## walls, and how far across its middle goes.
var keep: Dictionary = {}
var inside: Rect2i = Rect2i()
var roof_y: float = 0.0
var hall_left: float = 0.0
var hall_right: float = 0.0
var left_x: float = 0.0
var right_x: float = 0.0
var state: State = State.SLEEP
## Seconds left of what it is doing (the rest, the warning, the bite, lying fallen).
var timer: float = 0.0
## Where its thread hangs from (a point on the roof), or null with no thread.
var anchor: Variant = null
## How far it drops; how fast it falls; the top of the floor it lies or stands on.
var drop_y: float = 0.0
var vy: float = 0.0
var ground_y: float = 0.0
## Where it scurries to on a floor, and whether it climbs there (else falls on into a hole).
var goal_x: float = 0.0
var goal_climbs: bool = true
## Whether it has come down on a floor since it last began to fall.
var landed: bool = false
var slain: bool = false
var wound: SpiderWound
var stunner: Stunner
## Its bite: a touch that hurts, on a node of its own (so its Stunner leaves it to sync_bite).
var bite: HitBox
var webs: Array[SpiderWeb] = []
var ink: InkCanvas
var t: float = 0.0
## The print: the way its head points, how far its legs have walked, the last eye put out (and
## when), when a strike last glanced off, and a cut thread curling away (from, to, when).
var angle: float = 0.0
var eye_t: float = -INF
var glance_t: float = -INF
var cut_from: Vector2 = Vector2.ZERO
var cut_at: Vector2 = Vector2.ZERO
var cut_t: float = -INF
var dead_t: float = 0.0
var _was_stunned: bool = false
## The columns (as x) with a clear line from the canopy down to the cell the wizard was last in.
var _aim_cell: Vector2i = Vector2i(-1, -1)
var _aims: Array[float] = []
## Spitting: seconds until it may spit again, and how many times it has spat (every EGG_EVERY-th
## is an egg sac).
var spit_wait: float = SPIT_FIRST
var spits: int = 0
## What it has spat still about: globs in flight, egg sacs and spiderlings (they go with it).
var brood: Array[Node2D] = []
## Its legs (see FEMUR): how far drawn in, how much it stands on a floor, how much it walks (each
## easing toward the pose it is in), how fast it is going (px/s, smoothed), how far through its
## stride, and where its middle was last frame.
var _curl: float = 0.25
var _floor_w: float = 0.0
var _gait: float = 0.0
var _pace: float = 0.0
var _stride: float = 0.0
var _was_at: Vector2 = Vector2.INF
## Its webs' strands once spun whole, by where and how big each is (they never change then), so they
## are worked out once rather than every frame; worked out again when its webs change (a splat stuck
## or gone, a web torn or spun again), as they are tied on to one another (_webs_now).
var _spun: Dictionary = {}
var _webs_now: int = -1


func _init() -> void:
	wound = SpiderWound.new()
	wound.name = "Wound"
	wound.hp = EYES
	add_child(wound)
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	stunner.parry_only = true
	add_child(stunner)
	var fangs: Node2D = Node2D.new()
	fangs.name = "Fangs"
	add_child(fangs)
	bite = HIT_BOX.instantiate() as HitBox
	bite.name = "HitBox"
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = BITE_R
	var shape: CollisionShape2D = bite.get_node("CollisionShape2D") as CollisionShape2D
	shape.shape = reach
	shape.disabled = true
	(bite.get_node("Damager") as Damager).attacker = self
	fangs.add_child(bite)
	add_to_group(&"hex_target")
	add_to_group(&"spider")


func _ready() -> void:
	# Over the terrain with the other things in a place (props, z 2).
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)


func setup(info: MapInfo, _v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	# It goes all over the keep: never put to sleep with the chunk its cell is in.
	remove_meta(&"cell")
	var tm: TileMap = info.tile_map
	cell = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	origin = info.cell_position(Vector2i.ZERO)
	keep = info.world.keep
	if keep.is_empty():
		return
	inside = keep["inside"]
	roof_y = center(inside.position).y - cell * 0.5
	hall_left = center(inside.position).x - cell * 0.5
	hall_right = center(Vector2i(inside.end.x - 1, inside.position.y)).x + cell * 0.5
	left_x = hall_left + EDGE
	right_x = hall_right - EDGE
	global_position = Vector2(clampf(global_position.x, left_x, right_x), canopy_y())
	for span: Rect2i in keep["webs"]:
		var area: Rect2 = Rect2(center(span.position) - Vector2.ONE * cell * 0.5, Vector2(span.size) * cell)
		var web: SpiderWeb = SpiderWeb.new(span, area)
		web.name = "Web%d" % webs.size()
		add_child(web)
		webs.append(web)


## The middle of cell `v`.
func center(v: Vector2i) -> Vector2:
	return origin + Vector2(v) * cell


## Where its body hangs on the canopy.
func canopy_y() -> float:
	return roof_y + HANG


# ------------------------------------------------------------------ what it is

## Whether it is stunned (by a parried bite).
func stunned() -> bool:
	return stunner.stunned()


## Whether it is dying or dead.
func dying() -> bool:
	return slain or state == State.DYING


## Whether a strike wounds it: while it bites, stunned, and fallen until it is back on a thread.
func open() -> bool:
	if dying():
		return false
	return stunned() or state in [State.BITE, State.FALL, State.DOWN, State.SCURRY]


## Whether it hangs on a thread (which a bolt or a dash can cut).
func threaded() -> bool:
	return anchor != null and not dying() and state in [State.DROP, State.BITE, State.CLIMB, State.RECLIMB]


## Its thread, from the roof down to its abdomen's tip.
func thread() -> PackedVector2Array:
	if anchor == null:
		return PackedVector2Array()
	return PackedVector2Array([anchor as Vector2, global_position - Vector2(0, THREAD_TOP)])


## Whether a bolt's way from `from` to `to` (or a dash's) comes within `reach` of its body (see
## BODY_R), which turns with it.
func struck_by(from: Vector2, to: Vector2, reach: float) -> bool:
	var axis: Vector2 = Vector2.DOWN.rotated(angle)
	var near: PackedVector2Array = Geometry2D.get_closest_points_between_segments(from, to, global_position - axis * BODY_BACK, global_position + axis * BODY_FRONT)
	return near[0].distance_to(near[1]) <= BODY_R + reach


## Its bite hurts while it drops, bites, climbs and scurries, and not while it is stunned, fallen
## or dying. Checked every frame, so nothing else turning it on (or off) lasts.
func sync_bite() -> void:
	var on: bool = state in [State.DROP, State.BITE, State.CLIMB, State.RECLIMB, State.SCURRY] and not stunned() and not dying()
	if bite.collision != null and bite.collision.disabled == on:
		bite.collision.set_deferred("disabled", not on)


# ------------------------------------------------------------------ struck

## A strike glanced off its back: sparks, and it wakes.
func glance(dir: Vector2) -> void:
	glance_t = t
	RisoFx.burst(&"hit", global_position - dir.normalized() * BODY_R, -dir, [RisoPrint.PINK, RisoPrint.ACCENT])
	Wound.shake(4.0, 0.08)
	if state == State.SLEEP:
		state = State.HUNT


## A wound put out an eye.
func lose_eye(dir: Vector2) -> void:
	eye_t = t
	RisoFx.burst(&"hit", global_position, dir, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(8.0, 0.16)


## Its thread is cut at `at` (a bolt, a dash): it falls.
func cut(at: Vector2) -> void:
	if not threaded():
		return
	cut_from = anchor as Vector2
	cut_at = at
	cut_t = t
	anchor = null
	state = State.FALL
	vy = 0.0
	landed = false
	RisoFx.burst(&"hit", at, Vector2.DOWN, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(6.0, 0.12)


## An arrow struck it heading `dir` (Bullet): it pierces its back and puts out an eye, and wakes it.
func pierce(dir: Vector2) -> void:
	if state == State.SLEEP:
		state = State.HUNT
	wound.pierce(dir)


## The first spider whose body a way from `from` to `to` meets (struck_by), or null.
static func body_across(tree: SceneTree, from: Vector2, to: Vector2) -> Spider:
	for node: Node in tree.get_nodes_in_group(&"spider"):
		var spider: Spider = node as Spider
		if spider != null and not spider.is_queued_for_deletion() and not spider.dying() and spider.struck_by(from, to, 0.0):
			return spider
	return null


## The first spider's thread a way from `from` to `to` passes within `reach` of, the nearest to
## `from`: {"spider": it, "at": the point on the thread, "d": how far along the way}; else {}.
static func thread_across(tree: SceneTree, from: Vector2, to: Vector2, reach: float) -> Dictionary:
	var best: Dictionary = {}
	for node: Node in tree.get_nodes_in_group(&"spider"):
		var spider: Spider = node as Spider
		if spider == null or spider.is_queued_for_deletion() or not spider.threaded():
			continue
		var line: PackedVector2Array = spider.thread()
		if line[1].y - line[0].y < 1.0:
			continue
		var near: PackedVector2Array = Geometry2D.get_closest_points_between_segments(from, to, line[0], line[1])
		if near[0].distance_to(near[1]) > reach:
			continue
		var d: float = from.distance_to(near[0])
		if best.is_empty() or d < float(best["d"]):
			best = {"spider": spider, "at": near[1], "d": d}
	return best


## Its last eye is out: it curls up and falls, and shrivels where it lands.
func die() -> void:
	if dying():
		return
	landed = state in [State.DOWN, State.SCURRY]
	state = State.DYING
	anchor = null
	vy = 0.0
	dead_t = 0.0
	remove_from_group(&"hex_target")
	_wither_brood()
	Wound.shake(14.0, 0.4)
	RisoFx.burst(&"gain", global_position, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])


## Slain at once (the F7 panel's Slay boss, MapInfo.slay_boss).
func slay() -> void:
	if slain:
		return
	wound.hp = 0
	ground_y = _floor_below(global_position.x, global_position.y)
	_slain()


## It is slain: its relic waits on the floor where it lies, and it is gone, webs and all.
func _slain() -> void:
	slain = true
	_wither_brood()
	if map_info != null:
		map_info.boss_slain(boss, relic_at())
	queue_free()


## Where its relic waits: on the floor it lies on, in the middle of the cell over it.
func relic_at() -> Vector2:
	if map_info == null:
		return global_position
	return map_info.cell_position(map_info.cell_at(Vector2(global_position.x, ground_y - cell * 0.5)))


# ------------------------------------------------------------------ what it does

func _physics_process(delta: float) -> void:
	if map_info == null or keep.is_empty() or slain:
		return
	# A harder preset runs it faster (Difficulty.haste).
	delta *= Difficulty.haste()
	var player: Player = map_info.player if map_info.player != null and is_instance_valid(map_info.player) else null
	for i: int in range(webs.size() - 1, -1, -1):
		var web: SpiderWeb = webs[i]
		web.regrow(delta, player != null and web.rect.has_point(player.global_position))
		if web.spent():
			webs.remove_at(i)
			web.queue_free()
	for i: int in range(brood.size() - 1, -1, -1):
		if not is_instance_valid(brood[i]) or brood[i].is_queued_for_deletion():
			brood.remove_at(i)
	var stun_now: bool = stunned()
	if _was_stunned and not stun_now:
		_after_stun()
	_was_stunned = stun_now
	if state == State.DYING:
		_dying(delta)
	elif state == State.FALL:
		_fall(delta)
	elif not stun_now:
		match state:
			State.SLEEP:
				if player != null and player.global_position.distance_to(global_position) <= WAKE_RANGE * cell:
					state = State.HUNT
			State.HUNT:
				_hunt(delta, player)
			State.WARN:
				timer -= delta
				if timer <= 0.0:
					_drop(player)
			State.SPIT:
				global_position.y = canopy_y()
				timer -= delta
				if timer <= 0.0:
					_spit(player)
					state = State.HUNT
					timer = REST * 0.5
					spit_wait = SPIT_EVERY
			State.DROP:
				# Judged on the step worked out: read back from the position (kept in 32 bits), it
				# can fall a hair short of the target.
				var y: float = move_toward(global_position.y, drop_y, DROP_SPEED * delta)
				global_position.y = y
				if y >= drop_y:
					state = State.BITE
					timer = BITE_HOLD
			State.BITE:
				timer -= delta
				if timer <= 0.0:
					state = State.CLIMB
			State.CLIMB, State.RECLIMB:
				var y: float = move_toward(global_position.y, canopy_y(), CLIMB_SPEED * delta)
				global_position.y = y
				if y <= canopy_y():
					anchor = null
					state = State.HUNT
					timer = REST
			State.DOWN:
				timer -= delta
				if timer <= 0.0:
					_scurry_off()
			State.SCURRY:
				_scurry(delta)
	sync_bite()


## A stun has passed: from a drop or a bite it climbs back up; rearing, it settles back.
func _after_stun() -> void:
	match state:
		State.WARN, State.SPIT:
			state = State.HUNT
			timer = REST
		State.DROP, State.BITE:
			state = State.CLIMB


## Along the canopy, to be over the wizard (or the hole nearest them), and drop when it is.
func _hunt(delta: float, player: Player) -> void:
	timer = maxf(0.0, timer - delta)
	if player == null:
		return
	var at: Vector2 = player.global_position
	var aim: Variant = _drop_x(at)
	var to: float = clampf(float(aim) if aim != null else _well_x(), left_x, right_x)
	global_position.x = move_toward(global_position.x, to, CRAWL * delta)
	global_position.y = canopy_y()
	spit_wait = maxf(0.0, spit_wait - delta)
	var over: bool = aim != null and absf(global_position.x - to) < 2.0 and absf(to - at.x) <= DROP_SLACK and at.y > global_position.y
	if timer <= 0.0 and over:
		state = State.WARN
		timer = WARN
	elif timer <= 0.0 and spit_wait <= 0.0 and sees(at):
		state = State.SPIT
		timer = SPIT_WARN


## The x nearest `at` across from which it can drop to it (nothing but air between the canopy and
## it), or null.
func _drop_x(at: Vector2) -> Variant:
	var at_cell: Vector2i = map_info.cell_at(at)
	if at_cell != _aim_cell:
		_aim_cell = at_cell
		_aims.clear()
		for c: int in range(inside.position.x, inside.end.x):
			var x: float = clampf(center(Vector2i(c, 0)).x, left_x, right_x)
			if clear(x, canopy_y(), at.y):
				_aims.append(x)
	var best: Variant = null
	var x0: float = clampf(at.x, left_x, right_x)
	if clear(x0, canopy_y(), at.y):
		best = x0
	for x: float in _aims:
		if best == null or absf(x - at.x) < absf(float(best) - at.x):
			best = x
	return best


## The middle of the keep's well, where it waits when it can reach the wizard nowhere.
func _well_x() -> float:
	return center(Vector2i(int(keep["well"]) + 1, 0)).x


## Whether a body at `x` has nothing but air from `top` down to `bottom` (px).
func clear(x: float, top: float, bottom: float) -> bool:
	for dx: float in [-SPAN, 0.0, SPAN]:
		var a: Vector2i = map_info.cell_at(Vector2(x + dx, top))
		var b: Vector2i = map_info.cell_at(Vector2(x + dx, bottom))
		for row: int in range(a.y, b.y + 1):
			if map_info.world.is_ground(Vector2i(a.x, row)):
				return false
	return true


## The top (px) of the first rock under `y` at `x`.
func _floor_below(x: float, y: float) -> float:
	var c: Vector2i = map_info.cell_at(Vector2(x, y))
	for row: int in range(maxi(c.y, 0), map_info.world.size.y):
		if map_info.world.is_ground(Vector2i(c.x, row)):
			return center(Vector2i(c.x, row)).y - cell * 0.5
	return center(Vector2i(c.x, map_info.world.size.y - 1)).y + cell * 0.5


## Drop on its thread to where the wizard is (no further than the floor under it).
func _drop(player: Player) -> void:
	var to: float = player.global_position.y if player != null else global_position.y + cell * 3.0
	drop_y = clampf(to, global_position.y, _floor_below(global_position.x, global_position.y) - STAND)
	anchor = Vector2(global_position.x, roof_y)
	state = State.DROP


## Falling (its thread cut, or dying): down to the floor below, where it lands on its back
## (`landed`).
func _fall(delta: float) -> void:
	vy = minf(vy + FALL_GRAVITY * delta, FALL_MAX)
	var under: float = _floor_below(global_position.x, global_position.y)
	global_position.y += vy * delta
	angle += TUMBLE * delta
	if global_position.y < under - LIE:
		return
	global_position.y = under - LIE
	ground_y = under
	vy = 0.0
	landed = true
	Wound.shake(9.0, 0.18)
	RisoFx.burst(&"impact", Vector2(global_position.x, under), Vector2.UP, [RisoPrint.NIGHT, RisoPrint.BLUE])
	if state == State.FALL:
		state = State.DOWN
		timer = DOWNED


## Up off its back, it scurries to the nearest spot on its floor with a clear line up to the roof
## (or off its floor's edge into a hole, to fall on down).
func _scurry_off() -> void:
	global_position.y = ground_y - STAND
	var w: LevelGen = map_info.world
	var floor_row: int = map_info.cell_at(Vector2(global_position.x, ground_y + 1.0)).y
	var c: int = map_info.cell_at(global_position).x
	var best: Dictionary = {}
	for dir: int in [-1, 1]:
		var cx: int = c
		while true:
			var stand: Vector2i = Vector2i(cx, floor_row - 1)
			if not w.is_valid(stand) or w.is_ground(stand):
				break
			var x: float = clampf(center(stand).x, left_x, right_x)
			var climbs: bool = clear(x, roof_y + 1.0, center(stand).y)
			var hole: bool = not w.is_ground(Vector2i(cx, floor_row))
			if climbs or hole:
				var better: bool = best.is_empty() or (climbs and not bool(best["climbs"])) or (climbs == bool(best["climbs"]) and absf(x - global_position.x) < absf(float(best["x"]) - global_position.x))
				if better:
					best = {"x": x, "climbs": climbs}
				break
			cx += dir
	goal_x = float(best.get("x", global_position.x))
	goal_climbs = bool(best.get("climbs", true))
	state = State.SCURRY


## Scurrying along its floor; there, it climbs a new thread, or falls on into the hole.
func _scurry(delta: float) -> void:
	var x: float = move_toward(global_position.x, goal_x, SCURRY * delta)
	global_position.x = x
	if x != goal_x:
		return
	if goal_climbs:
		anchor = Vector2(global_position.x, roof_y)
		state = State.RECLIMB
	else:
		state = State.FALL
		vy = 0.0
		landed = false


## Dying: down to the floor if it is not on one, then shrivelling there.
func _dying(delta: float) -> void:
	if not landed:
		_fall(delta)
		return
	dead_t += delta
	if dead_t >= DIE_TIME:
		_slain()


# ------------------------------------------------------------------ spitting

## Where it spits from: its mouth, between its fangs.
func mouth() -> Vector2:
	return global_position + Vector2.DOWN.rotated(angle) * BODY_FRONT


## Whether it sees `at` to spit at: within SPIT_RANGE of its mouth, with no rock between (ledges and
## webs let it through).
func sees(at: Vector2) -> bool:
	var from: Vector2 = mouth()
	if from.distance_to(at) > SPIT_RANGE * cell:
		return false
	var steps: int = ceili(from.distance_to(at) / (cell * 0.2))
	for i: int in range(1, steps):
		if map_info.world.is_ground(map_info.cell_at(from.lerp(at, float(i) / float(steps)))):
			return false
	return true


## How many of its brood are about: egg sacs and spiderlings (globs in flight are not counted).
func brood_count() -> int:
	var n: int = 0
	for b: Node2D in brood:
		if is_instance_valid(b) and not b.is_queued_for_deletion() and not b is WebShot:
			n += 1
	return n


## Spit at the wizard: a glob of web, or every EGG_EVERY-th time an egg sac (while there is room
## for its brood).
func _spit(player: Player) -> void:
	if player == null or map_info == null:
		return
	spits += 1
	var from: Vector2 = mouth()
	var shot: Node2D
	if spits % EGG_EVERY == 0 and brood_count() + BROOD <= BROOD_MOST:
		var sac: EggSac = EggSac.new()
		sac.spider = self
		sac.velocity = EggSac.lob(from, player.global_position)
		shot = sac
	else:
		var glob: WebShot = WebShot.new()
		glob.spider = self
		glob.velocity = (player.global_position - from).normalized() * WebShot.SPEED
		shot = glob
	map_info.map_elements.add_child(shot)
	shot.global_position = from
	brood.append(shot)
	RisoFx.burst(&"hit", from, Vector2.DOWN, [RisoPrint.BLUE, RisoPrint.NIGHT])


## A glob of its web stuck at `at`: a splat, SPLAT cells across, holding what is in it for
## SPLAT_LIFE seconds (or until torn).
func splat(at: Vector2) -> void:
	if dying():
		return
	var size: Vector2 = Vector2.ONE * SPLAT * cell
	var web: SpiderWeb = SpiderWeb.new(Rect2i(map_info.cell_at(at), Vector2i.ONE), Rect2(at - size * 0.5, size))
	web.life = SPLAT_LIFE
	web.name = "Splat%d" % spits
	add_child(web)
	webs.append(web)


## Its brood withers with it (dying, slain): globs, egg sacs and spiderlings alike.
func _wither_brood() -> void:
	for b: Node2D in brood:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			b.queue_free()
	brood.clear()


# ------------------------------------------------------------------ the print

## Its canopy and webs, its thread, and itself: strands of web lifted pale off the keep's dark,
## its body dark (night and blue) with a pink hourglass and pink fangs (danger), and its eyes, its
## health, as bare paper (accent while it is open to strikes), dark once put out. Dying, it all
## fades.
func _process(delta: float) -> void:
	t += delta
	if ink == null or keep.is_empty():
		return
	_turn(delta)
	ink.global_position = Vector2.ZERO
	ink.begin()
	var fade: float = 1.0 - clampf(dead_t / DIE_TIME, 0.0, 1.0) if state == State.DYING else 1.0
	_draw_canopy(fade)
	var now: int = webs.size()
	for web: SpiderWeb in webs:
		now = now * 3 + (1 if web.torn else (2 if web.spun < 1.0 else 0))
	if now != _webs_now:
		_webs_now = now
		_spun.clear()
	var circles: Array[Vector3] = _web_circles()
	for web: SpiderWeb in webs:
		_draw_web(web, fade, circles)
	_draw_seams(circles, fade)
	_draw_thread(fade)
	_draw_body(fade, minf(delta, 0.05))
	ink.finish()


## The way its head points: down while it hangs, the way it goes on a floor, sideways on its back,
## tumbling as it falls.
func _turn(delta: float) -> void:
	if state == State.FALL or (state == State.DYING and not landed):
		return
	var want: float = 0.0
	match state:
		State.SCURRY:
			want = -PI * 0.5 if goal_x >= global_position.x else PI * 0.5
		State.DOWN, State.DYING:
			want = PI * 0.5 if wrapf(angle, -PI, PI) >= 0.0 else -PI * 0.5
	angle = lerp_angle(angle, want, clampf(TURN * delta, 0.0, 1.0))


## A strand of web from `a` to `b`, `w` wide.
static func strand(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var n: Vector2 = (b - a).normalized().orthogonal() * w * 0.5
	return PackedVector2Array([a - n, b - n, b + n, a + n])


## A sagging strand from `a` to `b` (sagging `sag` px at its middle), in `steps` pieces.
static func festoon(a: Vector2, b: Vector2, sag: float, w: float, steps: int, out: Array[PackedVector2Array]) -> void:
	var last: Vector2 = a
	for i: int in range(1, steps + 1):
		var u: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, u) + Vector2(0.0, sag * 4.0 * u * (1.0 - u))
		out.append(strand(last, p, w))
		last = p


## A plain web, as the decor's cobwebs are, its lines as far apart all over (see WEB_SPREAD): about
## `hub`, `radius` long, its spokes across `from`..`to` radians (round the whole turn if `closed`),
## as far out as `spun` (0..1, while it is spun again), each thinning as it goes, and its rings
## strung straight from spoke to spoke (each once the spokes reach it). Its unevenness is hashed
## from `key`. Where `moor` is given (a spoke's way -> how far out it meets what it is tied to, INF
## for nothing), each spoke stops there (and the rings past it are left off) or reaches out to it.
## Strands go into `out`.
static func plain_web(hub: Vector2, radius: float, from: float, to: float, closed: bool, spun: float, key: Vector2i, out: Array[PackedVector2Array], moor: Callable = Callable()) -> void:
	var span: float = to - from
	var spoke_gap: float = RisoDecor.WEB_SPOKE_GAP * WEB_SPREAD
	var ring_gap: float = RisoDecor.WEB_RING_GAP * WEB_SPREAD
	# Its rings, outermost first.
	var rings: Array[float] = []
	var r: float = radius * RisoDecor.WEB_RINGS[1]
	while r >= ring_gap * 0.9:
		rings.append(r)
		r -= ring_gap
	# The spokes to the hub, then each new set, starting from the ring where those before them have
	# drawn SPLIT times their spacing apart (-1: from the hub).
	var hub_n: int = maxi(2, ceili(span * float(HUB_SPOKES) / TAU))
	var starts: Array[int] = [-1]
	while not rings.is_empty():
		var at: float = SPLIT * spoke_gap * float(hub_n * (1 << (starts.size() - 1))) / span
		if at >= rings[0]:
			break
		var from_ring: int = rings.size() - 1
		for k: int in range(rings.size()):
			if rings[k] <= at:
				from_ring = k
				break
		starts.append(from_ring)
	var levels: int = starts.size() - 1
	var n: int = hub_n << levels
	var count: int = n if closed else n + 1
	var dirs: Array[Vector2] = []
	var begins: Array[int] = []
	for i: int in range(count):
		var level: int = 0
		if i % (1 << levels) != 0:
			var z: int = 0
			var j: int = i
			while j % 2 == 0:
				@warning_ignore("integer_division")
				j /= 2
				z += 1
			level = levels - z
		var a: float = from + span * float(i) / float(n)
		if closed or (i > 0 and i < n):
			a += (_h(key + Vector2i(i, 0), 41) - 0.5) * 2.0 * SPOKE_JITTER * span / float(n)
		dirs.append(Vector2.from_angle(a))
		begins.append(starts[level])
	# Where each spoke meets each ring, a little off true.
	var at_ring: Callable = func(k: int, i: int) -> float:
		return rings[k] + (_h(key + Vector2i(i, k + 1), 43) - 0.5) * 2.0 * RING_JITTER * ring_gap
	var lengths: Array[float] = []
	for i: int in range(count):
		var length: float = radius * lerpf(SPOKE_LONG.x, SPOKE_LONG.y, _h(key + Vector2i(i, 0), 42))
		if moor.is_valid():
			var tie: float = float(moor.call(dirs[i]))
			if tie < INF:
				length = tie
		lengths.append(length)
		var inner: float = 0.0 if begins[i] < 0 else float(at_ring.call(begins[i], i))
		var outer: float = length * spun
		if outer > inner:
			out.append_array(RisoDecor.strip(PackedVector2Array([hub + dirs[i] * inner, hub + dirs[i] * outer]), RisoDecor.WEB_W, RisoDecor.WEB_W * RisoDecor.WEB_TIP))
	for k: int in range(rings.size()):
		if rings[k] > radius * spun:
			continue
		var here: Array[int] = []
		for i: int in range(count):
			if begins[i] < 0 or begins[i] >= k:
				here.append(i)
		for j: int in range(here.size() if closed else here.size() - 1):
			var i0: int = here[j]
			var i1: int = here[(j + 1) % here.size()]
			var r0: float = at_ring.call(k, i0)
			var r1: float = at_ring.call(k, i1)
			if _h(key + Vector2i(i0, k + 1), 44) < RING_GAPS or r0 > lengths[i0] - 2.0 or r1 > lengths[i1] - 2.0:
				continue
			out.append(strand(hub + dirs[i0] * r0, hub + dirs[i1] * r1, RisoDecor.WEB_RING_W))


## A plain web (see plain_web) into `out`: worked out once when it is whole and kept (_spun), and
## afresh while it is being spun again.
func _web(hub: Vector2, radius: float, from: float, to: float, closed: bool, spun: float, key: Vector2i, out: Array[PackedVector2Array], moor: Callable = Callable()) -> void:
	if spun < 1.0:
		plain_web(hub, radius, from, to, closed, spun, key, out, moor)
		return
	var at: Vector4 = Vector4(hub.x, hub.y, radius, from)
	if not _spun.has(at):
		var strands: Array[PackedVector2Array] = []
		plain_web(hub, radius, from, to, closed, 1.0, key, strands, moor)
		_spun[at] = strands
	out.append_array(_spun[at] as Array[PackedVector2Array])


## A number in [0, 1) hashed from `v` and `salt`: how the canopy's festoons hang.
static func _h(v: Vector2i, salt: int) -> float:
	return RisoDecor.h(6900, v, salt)


## The canopy under the roof, which it walks on: festoons of web sagging along the roof, each its
## own length and sag, and a plain web in each top corner of the hall.
func _draw_canopy(fade: float) -> void:
	var strands: Array[PackedVector2Array] = []
	var x0: float = hall_left
	var x1: float = hall_right
	var key: Vector2i = inside.position
	for layer: int in range(2):
		var x: float = x0 + cell * 0.7 * float(layer)
		var k: int = 0
		while x < x1 - cell * 0.5:
			var span: float = cell * (1.4 + 1.6 * _h(key + Vector2i(k, layer), 1))
			var sag: float = (12.0 + 26.0 * float(layer)) * (0.6 + 0.8 * _h(key + Vector2i(k, layer), 2))
			festoon(Vector2(x, roof_y), Vector2(minf(x + span, x1), roof_y), sag, STRAND, 7, strands)
			x += span * (0.8 + 0.3 * _h(key + Vector2i(k, layer), 3))
			k += 1
	for side: int in [-1, 1]:
		var corner: Vector2 = Vector2(x0 if side < 0 else x1, roof_y)
		var from: float = 0.0 if side < 0 else PI * 0.5
		_web(corner, CORNER_REACH * cell, from, from + PI * 0.5, false, 1.0, key + Vector2i(side * 50, -50), strands)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], CANOPY_LIFT * fade, strands)


## A web: across a hole, two splats' worth of round web side by side (their spokes reaching out and
## their rings after them as it is spun again; torn, a few ragged strands hanging from its edges);
## a splat, a small round one, fading as it comes away.
func _draw_web(web: SpiderWeb, fade: float, circles: Array[Vector3]) -> void:
	var r: Rect2 = web.rect
	var strands: Array[PackedVector2Array] = []
	var hub: Vector2 = r.get_center()
	if web.splat():
		var radius: float = r.size.x * 0.5
		_web(hub, radius, 0.0, TAU, true, 1.0, Vector2i(roundi(hub.x), roundi(hub.y)), strands, _moor(hub, radius, circles))
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], WEB_LIFT * fade * clampf(web.life / 0.6, 0.0, 1.0), strands)
		return
	if web.torn:
		for side: int in [-1, 1]:
			var edge: float = r.position.x if side < 0 else r.end.x
			for i: int in range(2):
				var top: Vector2 = Vector2(edge, r.position.y + 10.0 + float(i) * 30.0)
				var sway: float = 6.0 * sin(t * 1.7 + float(i) * 1.3 + float(side))
				festoon(top, top + Vector2(-float(side) * (30.0 + 16.0 * float(i)) + sway, 40.0 + 20.0 * float(i)), -8.0, STRAND, 3, strands)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], WEB_LIFT * fade, strands)
		return
	# Two splats' worth, side by side across it, tied on to each other and the floor's ends.
	var halves: Array[Vector3] = _hole_webs(web)
	for k: int in range(halves.size()):
		var at: Vector2 = Vector2(halves[k].x, halves[k].y)
		_web(at, halves[k].z, 0.0, TAU, true, web.spun, web.cells.position * 4 + Vector2i(k, 0), strands, _moor(at, halves[k].z, circles))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], WEB_LIFT * fade, strands)


## The two round webs across hole web `web`, side by side: (middle x, middle y, radius) each.
func _hole_webs(web: SpiderWeb) -> Array[Vector3]:
	var r: Rect2 = web.rect
	var radius: float = minf(SPLAT * cell * 0.5, r.size.x * 0.25)
	var out: Array[Vector3] = []
	for k: int in range(2):
		var at: Vector2 = r.position + Vector2(r.size.x * (0.25 + 0.5 * float(k)), r.size.y * 0.5)
		out.append(Vector3(at.x, at.y, radius))
	return out


## Every round web of its whole now, to tie others on to: (middle x, middle y, radius) each.
func _web_circles() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for web: SpiderWeb in webs:
		if web.torn or web.spun < 0.5:
			continue
		if web.splat():
			var c: Vector2 = web.rect.get_center()
			out.append(Vector3(c.x, c.y, web.rect.size.x * 0.5))
		else:
			out.append_array(_hole_webs(web))
	return out


## How far past its rim (px) a web reaches to join what is next to it (see ADJACENT).
func _adjacent() -> float:
	return RisoDecor.WEB_RING_GAP * WEB_SPREAD * ADJACENT


## Where two webs that touch meet (see ADJACENT): for a web about `hub`, `radius` across, and another
## `o` (middle x, middle y, radius), how far from `hub` toward it the line they share lies (the line
## their edges cross on, or would), or INF when they do not touch.
func _seam(hub: Vector2, radius: float, o: Vector3) -> float:
	var c: Vector2 = Vector2(o.x, o.y)
	var d: float = hub.distance_to(c)
	if d < 1.0 or d - radius - o.z > _adjacent():
		return INF
	return (d * d + radius * radius - o.z * o.z) / (2.0 * d)


## How a web about `hub`, `radius` across, joins what it touches (see ADJACENT): for a spoke's way,
## how far out it meets the face of rock (found to a pixel), or the line it shares with another of
## `circles` that touches it, within its reach and the gap it may cross; INF for neither.
func _moor(hub: Vector2, radius: float, circles: Array[Vector3]) -> Callable:
	var far: float = radius + _adjacent()
	var w: LevelGen = map_info.world
	var info: MapInfo = map_info
	var seams: Array[Vector3] = []
	for o: Vector3 in circles:
		var at: float = _seam(hub, radius, o)
		if at < INF:
			var n: Vector2 = (Vector2(o.x, o.y) - hub).normalized()
			seams.append(Vector3(n.x, n.y, at))
	return func(dir: Vector2) -> float:
		var best: float = INF
		for sm: Vector3 in seams:
			var along: float = dir.dot(Vector2(sm.x, sm.y))
			if along > 0.05:
				var t_at: float = sm.z / along
				if t_at < far:
					best = minf(best, t_at)
		var d: float = MOOR_STEP
		while d <= minf(far, best):
			if w.is_ground(info.cell_at(hub + dir * d)):
				# The rock's face, to a pixel, between the last step in the open and this one.
				var lo: float = d - MOOR_STEP
				var hi: float = d
				while hi - lo > 1.0:
					var mid: float = (lo + hi) * 0.5
					if w.is_ground(info.cell_at(hub + dir * mid)):
						hi = mid
					else:
						lo = mid
				return lo
			d += MOOR_STEP
		return best


## The threads along which webs that touch meet (see ADJACENT), one to each pair, as long as the
## spokes that reach it from either side span.
func _draw_seams(circles: Array[Vector3], fade: float) -> void:
	var strands: Array[PackedVector2Array] = []
	for i: int in range(circles.size()):
		for j: int in range(i + 1, circles.size()):
			var a: Vector3 = circles[i]
			var b: Vector3 = circles[j]
			var hub: Vector2 = Vector2(a.x, a.y)
			var at: float = _seam(hub, a.z, b)
			if at == INF:
				continue
			var d: float = hub.distance_to(Vector2(b.x, b.y))
			var n: Vector2 = (Vector2(b.x, b.y) - hub) / d
			var reach_a: float = a.z + _adjacent()
			var reach_b: float = b.z + _adjacent()
			var half: float = minf(sqrt(maxf(reach_a * reach_a - at * at, 0.0)), sqrt(maxf(reach_b * reach_b - (d - at) * (d - at), 0.0)))
			if half < 2.0:
				continue
			var mid: Vector2 = hub + n * at
			strands.append(strand(mid - n.orthogonal() * half, mid + n.orthogonal() * half, RisoDecor.WEB_RING_W))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], WEB_LIFT * fade, strands)



## Its thread, and a cut one's end curling back up to the roof.
func _draw_thread(fade: float) -> void:
	var lines: Array[PackedVector2Array] = []
	var line: PackedVector2Array = thread()
	if not line.is_empty() and line[1].y > line[0].y:
		lines.append(strand(line[0], line[1], THREAD_W))
	var since: float = t - cut_t
	if since < CURL_TIME:
		var u: float = since / CURL_TIME
		var end: Vector2 = cut_from.lerp(cut_at, 1.0 - u) + Vector2(sin(since * 30.0) * 8.0 * (1.0 - u), 0.0)
		lines.append(strand(cut_from, end, THREAD_W * (1.0 - 0.5 * u)))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], THREAD_LIFT * fade, lines)


## Where each eye is on its head (head toward +y), and how big, in two rows of four and the
## order they go out: the small ones at the back first, the two great ones in front last.
const EYE_SPOTS: Array[Vector3] = [
	Vector3(-15.0, 3.0, 3.2), Vector3(15.0, 3.0, 3.2),
	Vector3(-7.0, 6.0, 3.8), Vector3(7.0, 6.0, 3.8),
	Vector3(-15.0, 13.0, 4.2), Vector3(15.0, 13.0, 4.2),
	Vector3(-6.0, 17.0, 5.5), Vector3(6.0, 17.0, 5.5),
]


## Itself: legs, abdomen with its pink hourglass, head, fangs and eyes, in its own frame (head
## toward +y) turned by `angle`. Rearing it shivers; biting its fangs spread; on its back its legs
## curl and kick; stunned they hang limp and stars circle its head; dying it curls up and shrinks.
## Rearing to spit it shivers less, its fangs half spread. `dt` is this frame's step (seconds).
func _draw_body(fade: float, dt: float) -> void:
	var dying_u: float = clampf(dead_t / DIE_TIME, 0.0, 1.0) if state == State.DYING else 0.0
	var jitter: Vector2 = Vector2.ZERO
	if state == State.WARN:
		jitter = Vector2(sin(t * 61.0), cos(t * 47.0)) * 2.5
	elif state == State.SPIT:
		jitter = Vector2(sin(t * 53.0), cos(t * 41.0)) * 1.5
	var size: float = ART * (1.0 - 0.45 * dying_u)
	var xf: Transform2D = Transform2D(angle, global_position + jitter) * Transform2D(0.0, Vector2.ONE * size, 0.0, Vector2.ZERO)
	var curl: float = 0.25
	if state in [State.DOWN, State.FALL]:
		curl = 0.6
	elif state == State.DYING:
		curl = 0.6 + 0.4 * dying_u
	elif stunned():
		curl = 0.45
	elif state in [State.HUNT, State.SCURRY, State.SPIT]:
		curl = 0.05
	var kicking: bool = state == State.DOWN or (state == State.DYING and dying_u < 0.6)
	# Ease into the pose it is in (see FEMUR), and walk as far as it has gone.
	var ease: float = clampf(POSE_EASE * dt, 0.0, 1.0)
	_curl = lerpf(_curl, curl, ease)
	_floor_w = lerpf(_floor_w, 1.0 if state == State.SCURRY and not stunned() else 0.0, ease)
	var moved: float = 0.0 if _was_at == Vector2.INF else global_position.distance_to(_was_at)
	_was_at = global_position
	# Its pace, smoothed: it moves on physics steps, which not every frame has.
	_pace = lerpf(_pace, moved / dt if dt > 0.0 else 0.0, ease)
	_gait = lerpf(_gait, clampf(_pace / WALKING, 0.0, 1.0) if state in [State.HUNT, State.SCURRY] else 0.0, ease)
	_stride = fposmod(_stride + moved / STRIDE, 1.0)
	var legs: Array[PackedVector2Array] = _legs(xf, size, kicking)
	ink.ink(RisoPrint.NIGHT, BODY_NIGHT * fade, legs)
	ink.ink(RisoPrint.BLUE, BODY_BLUE * 0.8 * fade, legs, false)
	var size_ab: Vector2 = ABDOMEN
	var middle: Vector2 = Vector2(0.0, -2.0 - size_ab.y * 0.85)
	var abdomen: PackedVector2Array = xf * _abdomen(middle, size_ab.x, size_ab.y, TAPER)
	var head: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(0.0, 8.0), HEAD_W, HEAD_W * 0.9, 18)
	var flash: float = clampf(1.0 - (t - eye_t) / FLASH_TIME, 0.0, 1.0)
	ink.ink(RisoPrint.NIGHT, BODY_NIGHT * fade, [abdomen, head])
	ink.ink(RisoPrint.BLUE, BODY_BLUE * fade, [abdomen, head], false)
	if flash > 0.0:
		ink.ink(RisoPrint.PINK, 0.6 * flash * fade, [abdomen, head], false)
	# A gleam on its back, and its hourglass (danger).
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.3 * fade, [xf * RisoShapes.ellipse(middle + Vector2(-size_ab.x * 0.33, -size_ab.y * 0.45), 7.0, 4.0, 10, -0.5)])
	var marks: Array[PackedVector2Array] = []
	for shape: PackedVector2Array in _hourglass(middle):
		marks.append(xf * shape)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], fade, marks)
	ink.ink(RisoPrint.PINK, fade, marks)
	# Its fangs: shut, hooked in; spread wide as it rears and bites.
	var spread: float = 1.0 if state in [State.WARN, State.DROP, State.BITE] else 0.0
	if state == State.WARN:
		spread = 0.6 + 0.4 * absf(sin(t * 18.0))
	elif state == State.SPIT:
		spread = 0.5
	var fangs: Array[PackedVector2Array] = []
	for side: int in [-1, 1]:
		var s: float = float(side)
		var base: Vector2 = Vector2(s * 7.0, 22.0)
		var fang: float = FANG
		var tip: Vector2 = Vector2(s * lerpf(2.0, 15.0, spread), 22.0 + fang)
		var bend: Vector2 = Vector2(s * lerpf(10.0, 16.0, spread), 22.0 + fang * 0.56)
		fangs.append(xf * PackedVector2Array([base + Vector2(-4.5, 0.0), bend + Vector2(-2.0 * s, 0.0), tip, bend + Vector2(2.0 * s, -1.0), base + Vector2(4.5, 0.0)]))
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], fade, fangs)
	ink.ink(RisoPrint.PINK, fade, fangs)
	# Its eyes: lit as bare paper (accent while open to strikes), put out dark.
	var lit: Array[PackedVector2Array] = []
	var out: Array[PackedVector2Array] = []
	var newest: Array[PackedVector2Array] = []
	var left: int = clampi(wound.hp, 0, EYES)
	for i: int in range(EYES):
		var spot: Vector3 = EYE_SPOTS[i]
		var eye: PackedVector2Array = xf * RisoShapes.circle(Vector2(spot.x, spot.y), spot.z, 10)
		if i >= EYES - left:
			lit.append(eye)
		else:
			out.append(eye)
			if i == EYES - left - 1 and flash > 0.0:
				newest.append(eye)
	var eyes: Array[PackedVector2Array] = []
	eyes.append_array(lit)
	eyes.append_array(out)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], eyes)
	if open():
		ink.ink(RisoPrint.ACCENT, (0.7 + 0.3 * sin(t * 9.0)) * fade, lit, false)
	ink.ink(RisoPrint.NIGHT, 0.7 * fade, out, false)
	ink.ink(RisoPrint.PINK, flash * fade, newest, false)
	if fade < 1.0:
		ink.ink(RisoPrint.NIGHT, (1.0 - fade) * 0.8, lit, false)
	if stunned():
		_draw_stun(xf * Vector2(0.0, 34.0))


## Its abdomen about `c`, `rx` by `ry`, drawn out to a point behind (up, -y) by `taper`.
static func _abdomen(c: Vector2, rx: float, ry: float, taper: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(24):
		var a: float = TAU * float(i) / 24.0
		var back: float = maxf(0.0, -sin(a))
		out.append(c + Vector2(cos(a) * rx * (1.0 - 0.4 * taper * back * back), sin(a) * ry * (1.0 + 0.3 * taper * back)))
	return out


## The hourglass on its back, on an abdomen about `c`, in its own space: shapes to print pink on
## knocked-out paper.
static func _hourglass(c: Vector2) -> Array[PackedVector2Array]:
	return [
		RisoShapes.tri(Vector2(-9.0, c.y - 16.0), Vector2(9.0, c.y - 16.0), Vector2(0.0, c.y - 2.0)),
		RisoShapes.tri(Vector2(-9.0, c.y + 12.0), Vector2(9.0, c.y + 12.0), Vector2(0.0, c.y)),
	]


## On a floor, seen from the side: where each leg's foot stands, along the way it goes from its
## middle (in its own measures, back legs first), and how much nearer the legs on its far side
## stand; how much longer its legs reach than spread, and how high over its middle its hips sit (in
## its own measures), so its knees arch up over its back.
const FLOOR_FEET: Array[float] = [-78.0, -45.0, 35.0, 65.0]
const FAR_SIDE: float = 0.82
const FLOOR_LONG: float = 1.35
const HIP_RISE: float = 12.0


## Its eight legs this frame, printed in world space: each femur, shank and foot, its knee, and the
## bristles along it. `xf` places its body (its size in it, `size`); `kicking` whether its legs kick.
## Each leg is set at its pose (see FEMUR): spread, drawn in by its curl, swinging as it walks; on a
## floor, seen from the side, its hips along its body, each knee high and its foot on the floor
## ahead or behind (FLOOR_FEET), stepping as it goes.
func _legs(xf: Transform2D, size: float, kicking: bool) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var joints: Array[PackedVector2Array] = []
	# On a floor: the way it goes along it, from the way its head points.
	var ahead: float = signf(xf.basis_xform(Vector2.DOWN).x)
	if ahead == 0.0:
		ahead = 1.0
	for k: int in range(8):
		var side: float = -1.0 if k < 4 else 1.0
		var i: int = k % 4
		var a0: float = lerpf(-1.05, 0.95, float(i) / 3.0)
		# Two sets of four step in turn: the first and third legs of one side with the second and
		# fourth of the other.
		var phase: float = TAU * _stride + (PI if (i % 2 == 0) == (side < 0.0) else 0.0)
		var a: float = a0 + WALK_SWING * _gait * sin(phase)
		if kicking:
			a += sin(t * 22.0 + float(i) * 2.3 + side) * 0.25
		elif stunned():
			a += sin(t * 2.0 + float(i)) * 0.06
		var flip: Vector2 = Vector2(side, 1.0)
		var femur: float = FEMUR * size * (1.0 - 0.3 * _curl)
		var shank: float = SHANK * size * (1.0 - 0.35 * _curl)
		var hip_in: Vector2 = Vector2(cos(a0) * 16.0, 8.0 + sin(a0) * 14.0)
		var hip: Vector2 = xf * (hip_in * flip)
		var knee: Vector2 = xf * ((hip_in + Vector2.from_angle(a - 0.55) * FEMUR * (1.0 - 0.3 * _curl)) * flip)
		var foot: Vector2 = knee + xf.basis_xform(Vector2.from_angle(a + 0.6 + 1.7 * _curl) * flip).normalized() * shank
		if _floor_w > 0.0:
			# Seen from the side on a floor: its hips along its body, its feet on the floor.
			var f_hip: Vector2 = global_position + Vector2(ahead * hip_in.y, -HIP_RISE) * size
			var far: float = 1.0 if side * ahead < 0.0 else FAR_SIDE
			var swing: float = sin(phase) * STRIDE / TAU * _gait
			var lift: float = STEP_LIFT * _gait * maxf(0.0, cos(phase))
			var f_foot: Vector2 = Vector2(global_position.x + ahead * (FLOOR_FEET[i] * size * far + swing), ground_y - lift)
			var f_knee: Vector2 = _knee(f_hip, f_foot, femur * FLOOR_LONG, shank * FLOOR_LONG)
			hip = hip.lerp(f_hip, _floor_w)
			knee = knee.lerp(f_knee, _floor_w)
			foot = foot.lerp(f_foot, _floor_w)
		var ankle: Vector2 = knee.lerp(foot, 1.0 - TARSUS)
		out.append(_limb(hip, knee, 7.0 * LEG_THICK * size, 5.0 * LEG_THICK * size))
		out.append(_limb(knee, ankle, 5.0 * LEG_THICK * size, 2.6 * LEG_THICK * size))
		out.append(_limb(ankle, foot, 2.6 * LEG_THICK * size, 1.2 * size))
		joints.append(RisoShapes.circle(knee, 3.6 * LEG_THICK * size, 8))
		# Bristles along its legs, set slanting down each piece, away from its body.
		for piece: Array in [[hip, knee], [knee, ankle]]:
			var from: Vector2 = piece[0]
			var to: Vector2 = piece[1]
			var dir: Vector2 = (to - from).normalized()
			var outward: Vector2 = dir.orthogonal()
			if outward.dot(from.lerp(to, 0.5) - global_position) < 0.0:
				outward = -outward
			for n: int in range(1, 4):
				var at: Vector2 = from.lerp(to, float(n) / 4.0)
				out.append(_limb(at, at + (outward + dir * 0.6) * 7.0 * size, 1.6 * size, 0.6 * size))
	out.append_array(joints)
	return out


## The knee of a leg from `hip` to `foot`, its femur `femur` long and its shank `shank`, bent up
## and away from the foot, over the line from hip to foot (a foot never passes under its hip, so
## it never swaps sides).
static func _knee(hip: Vector2, foot: Vector2, femur: float, shank: float) -> Vector2:
	var to: Vector2 = foot - hip
	var d: float = clampf(to.length(), absf(femur - shank) + 1.0, femur + shank - 0.5)
	var dir: Vector2 = to.normalized() if to.length() > 0.01 else Vector2.DOWN
	var bend: float = acos(clampf((femur * femur + d * d - shank * shank) / (2.0 * femur * d), -1.0, 1.0))
	# The side of the line that is up.
	var up: Vector2 = dir.orthogonal() if dir.x >= 0.0 else -dir.orthogonal()
	return hip + dir * cos(bend) * femur + up * sin(bend) * femur


## A leg's piece from `a` to `b`, `wa` wide at `a` tapering to `wb` at `b`.
static func _limb(a: Vector2, b: Vector2, wa: float, wb: float) -> PackedVector2Array:
	var n: Vector2 = (b - a).normalized().orthogonal()
	return PackedVector2Array([a - n * wa * 0.5, b - n * wb * 0.5, b + n * wb * 0.5, a + n * wa * 0.5])


## Stars circling a stunned spider's head at `at`, fewer as the stun runs out.
func _draw_stun(at: Vector2) -> void:
	var frac: float = stunner.fraction()
	var stars: Array[PackedVector2Array] = []
	for i: int in range(3):
		var a: float = t * 1.3 + TAU * float(i) / 3.0
		var p: Vector2 = at + Vector2(cos(a) * 32.0, sin(a) * 8.0) * ART
		stars.append(Transform2D(t * 0.9 + float(i), p) * RisoShapes.sparkle(Vector2.ZERO, (7.0 + 4.0 * frac) * ART))
	ink.ink(RisoPrint.ACCENT, 0.9, stars)
