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
## How near (px) past its body a bolt and a dash strike it.
const BOLT_REACH: float = 12.0
const DASH_REACH: float = 28.0
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
const WEB_LIFT: float = 0.62
const CANOPY_LIFT: float = 0.4
const STRAND: float = 2.2
const THREAD_LIFT: float = 0.85
const THREAD_W: float = 3.0
## How its orb webs are spun, each its own, from a hash of where it is (no RNG): its spokes (from,
## to), each turned from the even step between them by up to SPOKE_JITTER of a step; how far out
## its frame sits on each spoke (a share of the way to the edge, from, to); its spiral's turns (from,
## to), wound out from SPIRAL_IN of the way to the frame to SPIRAL_OUT, each point on it set off by
## up to SPIRAL_JITTER; and the share of the spiral's pieces left out (GAPS), as in a real web.
const SPOKES: Vector2i = Vector2i(9, 13)
const SPOKE_JITTER: float = 0.35
const FRAME_AT: Vector2 = Vector2(0.72, 0.96)
const TURNS: Vector2i = Vector2i(5, 8)
const SPIRAL_IN: float = 0.14
const SPIRAL_OUT: float = 0.93
const SPIRAL_JITTER: float = 0.03
const GAPS: float = 0.08
## A corner web under the roof: its spokes (from, to) across the quarter turn, its reach (cells,
## from, to), and its spiral's rows (from, to).
const CORNER_SPOKES: Vector2i = Vector2i(5, 8)
const CORNER_REACH: Vector2 = Vector2(2.4, 3.4)
const CORNER_ROWS: Vector2i = Vector2i(4, 7)
## Salt for the hash its webs are spun from.
const WEB_DEAL: int = 6900
## Its look, dealt from its level's seed (_deal_look, no RNG), so each world's spider is its own:
## its abdomen's half-width and half-height (from, to) and how much it tapers to a point behind;
## its head's half-width (its height follows); its legs' length and thickness (shares of the plain
## ones, from, to), each leg a little more or less (LEG_VARY); the chance its legs are bristled;
## the marking on its back (one of MARKS); and its fangs' length (px, from, to).
const ABDOMEN_W: Vector2 = Vector2(23.0, 31.0)
const ABDOMEN_H: Vector2 = Vector2(28.0, 38.0)
const TAPER: Vector2 = Vector2(0.0, 1.0)
const HEAD_W: Vector2 = Vector2(17.0, 22.0)
const LEG_LONG: Vector2 = Vector2(0.85, 1.2)
const LEG_THICK: Vector2 = Vector2(0.8, 1.25)
const LEG_VARY: float = 0.08
const BRISTLED: float = 0.5
const MARKS: Array[StringName] = [&"hourglass", &"chevrons", &"spots", &"band"]
const FANG: Vector2 = Vector2(13.0, 20.0)
const LOOK_DEAL: int = 6950
## How its legs move (worked out as it goes, nothing keyframed). Holding on (to the web of its
## canopy, where its pose has its feet; to a floor, scurrying, the feet on the floor) each foot
## stays planted where it last stepped until it is more than STEP_FAR of the leg's reach from where
## it would rest now (or off the floor), then steps there in STEP_TIME, lifted by STEP_LIFT (off the
## floor, or down off the canopy) and set down a little ahead of the way the body is going
## (STEP_LEAD of a step's worth of its speed). A leg steps only while the
## legs beside it (the next on its side, and the one across from it) are planted, so they go in
## turn as a spider's do. Its planted feet rest PLANT_SPREAD as far out along the surface as its
## pose's. Off a surface (on its thread, falling, on its back, stunned, dying) each foot swings on a
## spring (FREE_PULL, FREE_DAMP) after the pose it would hold, so it trails, kicks and gathers with
## a lag. Each leg is a femur and a shank (FEMUR, SHANK long, at its look's length), bent at the
## knee to reach its foot (two-bone IK), the knee bent up off a floor, else away from its body;
## the shank's last
## TARSUS is its foot.
const STEP_FAR: float = 0.3
const STEP_TIME: float = 0.13
const STEP_LIFT: float = 22.0
const STEP_LEAD: float = 0.6
const PLANT_SPREAD: float = 1.25
const FREE_PULL: float = 160.0
const FREE_DAMP: float = 14.0
const FEMUR: float = 38.0
const SHANK: float = 52.0
const TARSUS: float = 0.27

enum State { SLEEP, HUNT, WARN, DROP, BITE, CLIMB, FALL, DOWN, SCURRY, RECLIMB, DYING }

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
## Its look (see ABDOMEN_W), dealt once it is set up.
var look: Dictionary = {}
## Its legs (see STEP_FAR), left legs first: each foot (world px) and how fast it swings while free;
## each step's start and end and how far along it is (negative while planted); where its middle was
## last frame; and this frame's step (seconds).
var _feet: PackedVector2Array = PackedVector2Array()
var _foot_v: PackedVector2Array = PackedVector2Array()
var _step_from: PackedVector2Array = PackedVector2Array()
var _step_to: PackedVector2Array = PackedVector2Array()
var _step_u: PackedFloat32Array = PackedFloat32Array()
var _was_at: Vector2 = Vector2.INF
var _frame_dt: float = 0.0


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
	look = _deal_look(info.world.seed_for_colors)
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
	for web: SpiderWeb in webs:
		web.regrow(delta, player != null and web.rect.has_point(player.global_position))
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
		State.WARN:
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
	if timer <= 0.0 and aim != null and absf(global_position.x - to) < 2.0 and absf(to - at.x) <= DROP_SLACK and at.y > global_position.y:
		state = State.WARN
		timer = WARN


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
	_frame_dt = minf(delta, 0.05)
	ink.global_position = Vector2.ZERO
	ink.begin()
	var fade: float = 1.0 - clampf(dead_t / DIE_TIME, 0.0, 1.0) if state == State.DYING else 1.0
	_draw_canopy(fade)
	for web: SpiderWeb in webs:
		_draw_web(web, fade)
	_draw_thread(fade)
	_draw_body(fade)
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


## A number in [0, 1) hashed from `v` and `salt`: what its webs are spun from.
static func _h(v: Vector2i, salt: int) -> float:
	return RisoDecor.h(WEB_DEAL, v, salt)


## The canopy under the roof, which it walks on: festoons of web sagging along the roof, each its
## own length and sag, and an orb web spun into each top corner of the hall, each its own.
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
		_corner_web(corner, side, key + Vector2i(side, 0), strands)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], CANOPY_LIFT * fade, strands)


## A web spun into a top corner at `corner`, opening away from the wall on `side`: spokes across the
## quarter turn, each its own length, a frame from end to end, and the spiral's rows strung across
## the spokes (as such a web is spun, back and forth), all hashed from `key`.
func _corner_web(corner: Vector2, side: int, key: Vector2i, out: Array[PackedVector2Array]) -> void:
	var n: int = CORNER_SPOKES.x + int(_h(key, 10) * float(CORNER_SPOKES.y - CORNER_SPOKES.x + 1))
	var ends: Array[Vector2] = []
	for i: int in range(n):
		var u: float = (float(i) + (_h(key, 20 + i) - 0.5) * SPOKE_JITTER) / float(n - 1)
		var a: float = PI * 0.5 * clampf(u, 0.0, 1.0)
		var reach: float = cell * lerpf(CORNER_REACH.x, CORNER_REACH.y, _h(key, 40 + i))
		ends.append(corner + Vector2(-float(side) * cos(a), sin(a)) * reach)
	for p: Vector2 in ends:
		out.append(strand(corner, p, STRAND))
	for i: int in range(n - 1):
		festoon(ends[i], ends[i + 1], 8.0, STRAND * 0.8, 3, out)
	var rows: int = CORNER_ROWS.x + int(_h(key, 11) * float(CORNER_ROWS.y - CORNER_ROWS.x + 1))
	for r: int in range(rows):
		for i: int in range(n - 1):
			if _h(key + Vector2i(r, i), 60) < GAPS:
				continue
			var f: float = lerpf(0.22, 0.9, float(r) / float(maxi(1, rows - 1)))
			var fa: float = f + (_h(key + Vector2i(r, i), 61) - 0.5) * SPIRAL_JITTER * 2.0
			var fb: float = f + (_h(key + Vector2i(r, i + 1), 61) - 0.5) * SPIRAL_JITTER * 2.0
			festoon(corner.lerp(ends[i], fa), corner.lerp(ends[i + 1], fb), 3.0 + 5.0 * f, STRAND * 0.75, 2, out)


## A web across a hole: an orb web of its own (_web_pattern), tied to the floor's ends either side;
## being spun, its spokes reach out and its spiral winds out after them; torn, ragged strands hang
## from its edges.
func _draw_web(web: SpiderWeb, fade: float) -> void:
	var r: Rect2 = web.rect
	var strands: Array[PackedVector2Array] = []
	if web.torn:
		for side: int in [-1, 1]:
			var edge: float = r.position.x if side < 0 else r.end.x
			for i: int in range(4):
				var top: Vector2 = Vector2(edge, r.position.y + 4.0 + float(i) * 12.0)
				var hang: float = 30.0 + 16.0 * float(i)
				var sway: float = 6.0 * sin(t * 1.7 + float(i) * 1.3 + float(side))
				festoon(top, top + Vector2(-float(side) * (22.0 + 12.0 * float(i)) + sway, hang), -8.0, STRAND, 4, strands)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], WEB_LIFT * fade, strands)
		return
	var pattern: Dictionary = _web_pattern(web)
	var hub: Vector2 = pattern["hub"]
	var ends: Array[Vector2] = pattern["ends"]
	var spiral: Array[Vector2] = pattern["spiral"]
	var shares: PackedFloat32Array = pattern["shares"]
	var gaps: PackedByteArray = pattern["gaps"]
	var reach: float = web.spun
	for p: Vector2 in ends:
		strands.append(strand(hub, hub.lerp(p, reach), STRAND))
	if reach >= 1.0:
		for i: int in range(ends.size()):
			festoon(ends[i], ends[(i + 1) % ends.size()], 4.0, STRAND, 2, strands)
		for moor: Array in (pattern["moorings"] as Array):
			festoon(moor[0], moor[1], 3.0, STRAND, 2, strands)
	for i: int in range(spiral.size() - 1):
		if gaps[i] == 1 or shares[i + 1] > reach:
			continue
		festoon(spiral[i], spiral[i + 1], 2.5, STRAND * 0.8, 2, strands)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], WEB_LIFT * fade, strands)


## How web `web` is spun, worked out once from where it is and kept on it (SpiderWeb.pattern): a hub
## off its middle; spokes out from it at uneven turns, each ending on its frame short of the hole's
## edge; threads mooring the frame's sideways ends to the floor's ends either side of the hole;
## and a spiral wound out across the spokes, a few of its pieces left out. "hub" and "ends" (world
## points), "moorings" ([from, to] each), "spiral" (its points in order), "shares" (how far out each
## point is, a share of the way to the frame) and "gaps" (1 for each piece left out).
func _web_pattern(web: SpiderWeb) -> Dictionary:
	if not web.pattern.is_empty():
		return web.pattern
	var r: Rect2 = web.rect
	var key: Vector2i = web.cells.position
	var hub: Vector2 = r.position + r.size * Vector2(0.36 + 0.28 * _h(key, 1), 0.42 + 0.26 * _h(key, 2))
	var n: int = SPOKES.x + int(_h(key, 3) * float(SPOKES.y - SPOKES.x + 1))
	var start: float = _h(key, 4) * TAU
	var ends: Array[Vector2] = []
	var dirs: Array[Vector2] = []
	for i: int in range(n):
		var a: float = start + TAU * (float(i) + (_h(key, 10 + i) - 0.5) * 2.0 * SPOKE_JITTER) / float(n)
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var out: float = INF
		if absf(dir.x) > 0.001:
			out = minf(out, ((r.end.x if dir.x > 0.0 else r.position.x) - hub.x) / dir.x)
		if absf(dir.y) > 0.001:
			out = minf(out, ((r.end.y if dir.y > 0.0 else r.position.y) - hub.y) / dir.y)
		ends.append(hub + dir * out * lerpf(FRAME_AT.x, FRAME_AT.y, _h(key, 40 + i)))
		dirs.append(dir)
	var moorings: Array = []
	for i: int in range(n):
		if absf(dirs[i].x) < 0.75:
			continue
		var edge: float = r.end.x if dirs[i].x > 0.0 else r.position.x
		var y: float = clampf(ends[i].y + (_h(key, 70 + i) - 0.5) * r.size.y * 0.4, r.position.y + 4.0, r.end.y - 4.0)
		moorings.append([ends[i], Vector2(edge, y)])
	var turns: int = TURNS.x + int(_h(key, 5) * float(TURNS.y - TURNS.x + 1))
	var spiral: Array[Vector2] = []
	var shares: PackedFloat32Array = PackedFloat32Array()
	var gaps: PackedByteArray = PackedByteArray()
	var steps: int = n * turns
	for st: int in range(steps + 1):
		var f: float = lerpf(SPIRAL_IN, SPIRAL_OUT, float(st) / float(steps)) + (_h(key + Vector2i(st, 0), 80) - 0.5) * 2.0 * SPIRAL_JITTER
		spiral.append(hub.lerp(ends[st % n], f))
		shares.append(f)
		gaps.append(1 if _h(key + Vector2i(st, 1), 81) < GAPS else 0)
	web.pattern = {"hub": hub, "ends": ends, "moorings": moorings, "spiral": spiral, "shares": shares, "gaps": gaps}
	return web.pattern


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
func _draw_body(fade: float) -> void:
	var dying_u: float = clampf(dead_t / DIE_TIME, 0.0, 1.0) if state == State.DYING else 0.0
	var jitter: Vector2 = Vector2(sin(t * 61.0), cos(t * 47.0)) * 2.5 if state == State.WARN else Vector2.ZERO
	var size: float = ART * (1.0 - 0.45 * dying_u)
	var xf: Transform2D = Transform2D(angle, global_position + jitter) * Transform2D(0.0, Vector2.ONE * size, 0.0, Vector2.ZERO)
	var curl: float = 0.25
	if state in [State.DOWN, State.FALL]:
		curl = 0.6
	elif state == State.DYING:
		curl = 0.6 + 0.4 * dying_u
	elif stunned():
		curl = 0.45
	elif state in [State.HUNT, State.SCURRY]:
		curl = 0.05
	var kicking: bool = state == State.DOWN or (state == State.DYING and dying_u < 0.6)
	if look.is_empty():
		look = _deal_look(0)
	var legs: Array[PackedVector2Array] = _legs(xf, size, curl, kicking)
	ink.ink(RisoPrint.NIGHT, BODY_NIGHT * fade, legs)
	ink.ink(RisoPrint.BLUE, BODY_BLUE * 0.8 * fade, legs, false)
	var size_ab: Vector2 = look["abdomen"]
	var middle: Vector2 = Vector2(0.0, -2.0 - size_ab.y * 0.85)
	var abdomen: PackedVector2Array = xf * _abdomen(middle, size_ab.x, size_ab.y, look["taper"])
	var head_w: float = look["head"]
	var head: PackedVector2Array = xf * RisoShapes.ellipse(Vector2(0.0, 8.0), head_w, head_w * 0.9, 18)
	var flash: float = clampf(1.0 - (t - eye_t) / FLASH_TIME, 0.0, 1.0)
	ink.ink(RisoPrint.NIGHT, BODY_NIGHT * fade, [abdomen, head])
	ink.ink(RisoPrint.BLUE, BODY_BLUE * fade, [abdomen, head], false)
	if flash > 0.0:
		ink.ink(RisoPrint.PINK, 0.6 * flash * fade, [abdomen, head], false)
	# A gleam on its back, and its hourglass (danger).
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.3 * fade, [xf * RisoShapes.ellipse(middle + Vector2(-size_ab.x * 0.33, -size_ab.y * 0.45), 7.0, 4.0, 10, -0.5)])
	var marks: Array[PackedVector2Array] = []
	for shape: PackedVector2Array in _mark(look["mark"], middle, size_ab.x, size_ab.y):
		marks.append(xf * shape)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], fade, marks)
	ink.ink(RisoPrint.PINK, fade, marks)
	# Its fangs: shut, hooked in; spread wide as it rears and bites.
	var spread: float = 1.0 if state in [State.WARN, State.DROP, State.BITE] else 0.0
	if state == State.WARN:
		spread = 0.6 + 0.4 * absf(sin(t * 18.0))
	var fangs: Array[PackedVector2Array] = []
	for side: int in [-1, 1]:
		var s: float = float(side)
		var base: Vector2 = Vector2(s * 7.0, 22.0)
		var fang: float = look["fang"]
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


## Its look, hashed from level seed `level_seed` (see ABDOMEN_W): "abdomen" (half-width,
## half-height), "taper", "head" (half-width), "long" and "thick" (its legs'), "legs" (each leg's
## own share of the length, left legs first), "bristled", "mark" and "fang".
static func _deal_look(level_seed: int) -> Dictionary:
	var h: Callable = func(salt: int) -> float: return RisoDecor.h(level_seed, Vector2i(salt, 0), LOOK_DEAL)
	var legs: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(8):
		legs.append(1.0 + (float(h.call(20 + i)) - 0.5) * 2.0 * LEG_VARY)
	return {
		"abdomen": Vector2(lerpf(ABDOMEN_W.x, ABDOMEN_W.y, h.call(1)), lerpf(ABDOMEN_H.x, ABDOMEN_H.y, h.call(2))),
		"taper": lerpf(TAPER.x, TAPER.y, h.call(3)),
		"head": lerpf(HEAD_W.x, HEAD_W.y, h.call(4)),
		"long": lerpf(LEG_LONG.x, LEG_LONG.y, h.call(5)),
		"thick": lerpf(LEG_THICK.x, LEG_THICK.y, h.call(6)),
		"legs": legs,
		"bristled": float(h.call(7)) < BRISTLED,
		"mark": MARKS[mini(int(float(h.call(8)) * float(MARKS.size())), MARKS.size() - 1)],
		"fang": lerpf(FANG.x, FANG.y, h.call(9)),
	}


## Its abdomen about `c`, `rx` by `ry`, drawn out to a point behind (up, -y) by `taper`.
static func _abdomen(c: Vector2, rx: float, ry: float, taper: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(24):
		var a: float = TAU * float(i) / 24.0
		var back: float = maxf(0.0, -sin(a))
		out.append(c + Vector2(cos(a) * rx * (1.0 - 0.4 * taper * back * back), sin(a) * ry * (1.0 + 0.3 * taper * back)))
	return out


## The marking on its back (`mark`, one of MARKS) on an abdomen about `c`, `rx` by `ry`, in its own
## space: shapes to print pink on knocked-out paper.
static func _mark(mark: StringName, c: Vector2, rx: float, ry: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	match mark:
		&"chevrons":
			for k: int in range(3):
				var y: float = c.y - ry * 0.55 + float(k) * ry * 0.4
				var w: float = rx * (0.55 - 0.1 * float(k))
				out.append(_limb(Vector2(-w, y - 6.0), Vector2(0.0, y + 4.0), 5.0, 5.0))
				out.append(_limb(Vector2(0.0, y + 4.0), Vector2(w, y - 6.0), 5.0, 5.0))
		&"spots":
			for k: int in range(3):
				var y: float = c.y - ry * 0.5 + float(k) * ry * 0.42
				var r: float = 5.0 - float(k)
				for side: float in [-1.0, 1.0]:
					out.append(RisoShapes.circle(Vector2(side * rx * 0.36, y), r, 10))
		&"band":
			out.append(RisoShapes.rrect(-rx * 0.62, c.y - 4.0, rx * 1.24, 8.0, 3.0))
			out.append(RisoShapes.tri(Vector2(-5.0, c.y - ry * 0.7), Vector2(5.0, c.y - ry * 0.7), Vector2(0.0, c.y - 6.0)))
		_:
			out.append(RisoShapes.tri(Vector2(-9.0, c.y - 16.0), Vector2(9.0, c.y - 16.0), Vector2(0.0, c.y - 2.0)))
			out.append(RisoShapes.tri(Vector2(-9.0, c.y + 12.0), Vector2(9.0, c.y + 12.0), Vector2(0.0, c.y)))
	return out


## The surface its feet hold to now, as [its height (world y), the way off it (+1 down from the
## roof, -1 up from a floor)], or [] while they hold to none.
func _surface() -> Array:
	if stunned() or dying():
		return []
	if state in [State.SLEEP, State.HUNT, State.WARN] and global_position.y <= canopy_y() + 4.0:
		return [roof_y, 1.0]
	if state == State.SCURRY:
		return [ground_y, -1.0]
	return []


## Its eight legs this frame, moved (see STEP_FAR) and printed in world space: each bone, its knee,
## and its bristles if it has them. `xf` places its body (its size in it, `size`), `curl` how far
## its free legs draw in, `kicking` whether they kick.
func _legs(xf: Transform2D, size: float, curl: float, kicking: bool) -> Array[PackedVector2Array]:
	var long: float = look["long"]
	var thick: float = look["thick"]
	var each: PackedFloat32Array = look["legs"]
	var dt: float = _frame_dt
	var first: bool = _feet.size() != 8
	if first:
		_feet.resize(8)
		_foot_v.resize(8)
		_step_from.resize(8)
		_step_to.resize(8)
		_step_u.resize(8)
		_step_u.fill(-1.0)
	var surface: Array = _surface()
	var speed: Vector2 = Vector2.ZERO if _was_at == Vector2.INF or dt <= 0.0 else (global_position - _was_at) / dt
	_was_at = global_position
	var hips: Array[Vector2] = []
	var targets: Array[Vector2] = []
	var bones: PackedFloat32Array = PackedFloat32Array()
	for k: int in range(8):
		var side: float = -1.0 if k < 4 else 1.0
		var i: int = k % 4
		var a: float = lerpf(-1.05, 0.95, float(i) / 3.0)
		if kicking:
			a += sin(t * 22.0 + float(i) * 2.3 + side) * 0.25
		elif stunned():
			a += sin(t * 2.0 + float(i)) * 0.06
		var reach: float = long * each[k]
		var flip: Vector2 = Vector2(side, 1.0)
		var hip: Vector2 = Vector2(cos(a) * 16.0, 8.0 + sin(a) * 14.0)
		var knee: Vector2 = hip + Vector2.from_angle(a - 0.55) * FEMUR * reach * (1.0 - 0.3 * curl)
		var pose: Vector2 = xf * ((knee + Vector2.from_angle(a + 0.6 + 1.7 * curl) * SHANK * reach * (1.0 - 0.35 * curl)) * flip)
		# On the canopy its feet grip the web about it where its pose has them; on a floor, the floor.
		var target: Vector2 = pose
		if not surface.is_empty() and float(surface[1]) < 0.0:
			target = Vector2(global_position.x + (pose.x - global_position.x) * PLANT_SPREAD, float(surface[0]))
		hips.append(xf * (hip * flip))
		targets.append(target)
		bones.append(reach * size)
	for k: int in range(8):
		var full: float = (FEMUR + SHANK) * bones[k]
		if first:
			_feet[k] = targets[k]
			_foot_v[k] = Vector2.ZERO
			continue
		if surface.is_empty():
			_step_u[k] = -1.0
			_foot_v[k] += (targets[k] - _feet[k]) * FREE_PULL * dt
			_foot_v[k] *= exp(-FREE_DAMP * dt)
			_feet[k] += _foot_v[k] * dt
			continue
		_foot_v[k] = Vector2.ZERO
		if _step_u[k] >= 0.0:
			_step_u[k] += dt / STEP_TIME
			if _step_u[k] >= 1.0:
				_step_u[k] = -1.0
				_feet[k] = _step_to[k]
			else:
				var u: float = _step_u[k]
				_feet[k] = _step_from[k].lerp(_step_to[k], u * u * (3.0 - 2.0 * u)) + Vector2(0.0, float(surface[1]) * STEP_LIFT * sin(PI * u))
			continue
		var off: bool = float(surface[1]) < 0.0 and absf(_feet[k].y - targets[k].y) > 2.0
		var stretched: bool = hips[k].distance_to(_feet[k]) > full
		var far: bool = _feet[k].distance_to(targets[k]) > STEP_FAR * full
		if off or stretched or (far and _neighbors_planted(k)):
			_step_from[k] = _feet[k]
			_step_to[k] = targets[k] + speed * STEP_TIME * STEP_LEAD
			_step_u[k] = 0.0
	var out: Array[PackedVector2Array] = []
	var joints: Array[PackedVector2Array] = []
	for k: int in range(8):
		var femur: float = FEMUR * bones[k]
		var shank: float = SHANK * bones[k]
		var hip: Vector2 = hips[k]
		var to_foot: Vector2 = _feet[k] - hip
		var d: float = clampf(to_foot.length(), absf(femur - shank) + 1.0, femur + shank - 0.5)
		var dir: Vector2 = to_foot.normalized() if to_foot.length() > 0.01 else Vector2.DOWN
		var bend: float = acos(clampf((femur * femur + d * d - shank * shank) / (2.0 * femur * d), -1.0, 1.0))
		var k1: Vector2 = hip + dir.rotated(bend) * femur
		var k2: Vector2 = hip + dir.rotated(-bend) * femur
		# On a floor the knee bends up, off it; else away from the body.
		var knee: Vector2 = k1 if k1.distance_squared_to(global_position) > k2.distance_squared_to(global_position) else k2
		if not surface.is_empty() and float(surface[1]) < 0.0:
			knee = k1 if k1.y < k2.y else k2
		var foot: Vector2 = hip + dir * d
		var ankle: Vector2 = knee.lerp(foot, 1.0 - TARSUS)
		out.append(_limb(hip, knee, 7.0 * thick * size, 5.0 * thick * size))
		out.append(_limb(knee, ankle, 5.0 * thick * size, 2.6 * thick * size))
		out.append(_limb(ankle, foot, 2.6 * thick * size, 1.2 * size))
		joints.append(RisoShapes.circle(knee, 3.6 * thick * size, 8))
		if bool(look["bristled"]):
			# Bristles along its legs, set slanting down each piece, away from its body.
			for piece: Array in [[hip, knee], [knee, ankle]]:
				var from: Vector2 = piece[0]
				var to: Vector2 = piece[1]
				var along: Vector2 = (to - from).normalized()
				var outward: Vector2 = along.orthogonal()
				if outward.dot(from.lerp(to, 0.5) - global_position) < 0.0:
					outward = -outward
				for n: int in range(1, 4):
					var at: Vector2 = from.lerp(to, float(n) / 4.0)
					out.append(_limb(at, at + (outward + along * 0.6) * 7.0 * size, 1.6 * size, 0.6 * size))
	out.append_array(joints)
	return out


## Whether the legs beside leg `k` (the next on its side, and the one across from it) are planted,
## so it may step.
func _neighbors_planted(k: int) -> bool:
	@warning_ignore("integer_division")
	var side: int = k / 4 * 4
	for n: int in [k - 1, k + 1]:
		if n >= side and n < side + 4 and _step_u[n] >= 0.0:
			return false
	return _step_u[(k + 4) % 8] < 0.0


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
