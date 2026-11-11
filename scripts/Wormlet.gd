class_name Wormlet
extends Stunnable
## A small worm, in the garden (GardenArchetype.finish, and a swarm round a big plant, MapInfo):
## the size of a wisp, it lives in the rock and bursts out where the wizard is. Hidden, it waits
## until the wizard comes within WAKE cells of its home; then the rock where it will come out throbs
## pink for WARN_TIME (the boss worm's own warning, Worm.ink_warning): the floor under the wizard,
## or one time in CEILING_CHANCE (where there is rock overhead) the ceiling over them, from which it
## drops onto them. Up from a floor it opens a burrow hole (as the boss's, Burrow), comes up out of
## it and over onto the floor toward the wizard, knocking them up (BUMP) if they stand over it. Out,
## it inches along the floor for OUT_TIME, its touch hurting, then dives head first into a new hole
## and rests for REST_TIME before it can come again; its holes fall in behind it. Underground
## nothing touches it; out, one blow slays it (one hit point), and it stays slain until the wizard
## dies, as any enemy.
## Its body is frozen and moved only from here. Nothing here draws from the world RNG: where it comes
## out is the wizard's place and a hash of the level seed, its home and how often it has come out.

## How near (cells) the wizard must come to its home for it to stir, how long the rock throbs before
## it comes out, how long it takes to rise out of the floor and to sink back, how long it squirms,
## and how long it rests below after (seconds; the waits shorter on a harder preset,
## Difficulty.attack).
const WAKE: int = 7
const WARN_TIME: float = 0.7
const RISE_TIME: float = 0.6
const SINK_TIME: float = 0.35
const OUT_TIME: float = 1.6
const REST_TIME: float = 2.5
## How fast it squirms along the floor (px/s; a little faster on a harder preset, Difficulty.speed),
## and how fast it falls from a ceiling (px/s more each second, at most MAX_FALL).
const SQUIRM_SPEED: float = 35.0
const GRAVITY: float = 1800.0
const MAX_FALL: float = 900.0
## One time in CEILING_CHANCE it drops from the ceiling, if there is rock over the wizard within
## CEILING_REACH cells; else it comes up from the floor under them, within FLOOR_REACH cells down.
const CEILING_CHANCE: int = 3
const CEILING_REACH: int = 4
const FLOOR_REACH: int = 3
## Its body: how long it is and how thick (px), for its art and where it stands.
const LENGTH: float = 64.0
const GIRTH: float = 28.0
## How hard it knocks the wizard up as it bursts out of the floor under them (px/s up; a jump is
## 600), and how far from its middle across (px) a wizard standing on that floor is over it.
const BUMP: float = -380.0
const BUMP_REACH: float = 60.0
## Its holes: how long one takes to open, how long it stays open once the worm is through it, and how
## long it then takes to fall in (seconds).
const HOLE_OPEN: float = 0.12
const HOLE_LINGER: float = 1.2
const HOLE_CLOSE: float = 0.5
## Salt for the level seed, for where it comes out each time.
const EMERGE_DEAL: int = 6660
## How many come up round a garden plot whose plant has grown, by the plant's tier (Plot.tier: a
## white flower, a great bloom), how far from the plot (cells) their homes lie, and the salt for
## choosing them (MapInfo._spawn_swarm).
const SWARM: Array[int] = [0, 0, 3, 6]
const SWARM_REACH: int = 8
const SWARM_DEAL: int = 6661

enum State { HIDDEN, WARN, RISE, OUT, DROP, SINK }


## A hole it came out of or went into: the middle of its mouth at the rock face (world px), the way
## out of the rock, when it opened and when it starts to fall in (its clock, t).
class Burrow:
	var mouth: Vector2
	var out: Vector2
	var opened: float
	var closes: float

## Its body (the prefab's root), what it is doing, how long that has left (seconds), and its clock.
var rb: RigidBody2D
var state: State = State.HIDDEN
var timer: float = 0.0
var t: float = 0.0
## The cell it lives under, the open cell it comes out into (from the floor under it, or the
## ceiling over it), and how many times it has come out.
var home: Vector2i = Vector2i.ZERO
var face: Vector2i = Vector2i.ZERO
var from_ceiling: bool = false
var emerges: int = 0
## How much of it is out of the rock (0 to 1), the way it squirms (-1 left, 1 right), and how fast it
## is falling (px/s).
var out: float = 0.0
var heading: float = 1.0
var fall: float = 0.0
## Where across (world px) the hole it is coming up out of or diving into opens in the floor, and
## its holes still open (Burrow), for its art.
var mouth_x: float = 0.0
var burrows: Array[Burrow] = []
## Its body's collision layer when out (none while it is in the rock).
var _layer: int = 0


func _ready() -> void:
	rb = get_parent() as RigidBody2D
	rb.gravity_scale = 0.0
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	_layer = rb.collision_layer
	var wound: Wound = rb.get_node_or_null("Wound") as Wound
	if wound != null:
		wound.hp = 1
	timer = REST_TIME * 0.5
	_set_out(false)
	_home.call_deferred()


## Its home, once the loader has put it on its cell.
func _home() -> void:
	if rb.has_meta(&"cell"):
		home = rb.get_meta(&"cell")


## Whether it can be seen and touched (out of the rock, or falling).
func shown() -> bool:
	return state in [State.RISE, State.OUT, State.DROP, State.SINK]


## How near it is to coming out while the rock throbs (0 to 1).
func warn_near() -> float:
	return clampf(1.0 - timer / Difficulty.tell(WARN_TIME), 0.0, 1.0) if state == State.WARN else 0.0


## Where the rock throbs or opens for it: the face of the floor under its cell, or the ceiling over
## it (world px), and the way out of the rock.
func face_point() -> Vector2:
	var info: MapInfo = MapInfo.instance
	if info == null:
		return rb.global_position
	var half: float = _cell_px() * 0.5
	return info.cell_position(face) + Vector2(0, -half if from_ceiling else half)


func face_way() -> Vector2:
	return Vector2.DOWN if from_ceiling else Vector2.UP


## Where the rock throbs and then opens for it (world px): in a ceiling, over the wizard's cell; in a
## floor, behind where it will lie, so it comes up out of the hole and over onto the floor toward
## them, lying across the middle of their cell.
func mouth() -> Vector2:
	if from_ceiling:
		return face_point()
	return face_point() - Vector2(heading * (LENGTH * 0.5 + GIRTH * 0.5), 0.0)


## How far open hole `b` is now (0 to 1): opening over HOLE_OPEN, falling in over HOLE_CLOSE.
func open_of(b: Burrow) -> float:
	return clampf((t - b.opened) / HOLE_OPEN, 0.0, 1.0) * clampf(1.0 - (t - b.closes) / HOLE_CLOSE, 0.0, 1.0)


## A hole opening at `at` out of the rock along `way`, open for `busy` seconds while the worm comes
## through it and HOLE_LINGER after.
func _open_burrow(at: Vector2, way: Vector2, busy: float) -> void:
	var b: Burrow = Burrow.new()
	b.mouth = at
	b.out = way
	b.opened = t
	b.closes = t + busy + HOLE_LINGER
	burrows.append(b)


func _cell_px() -> float:
	var info: MapInfo = MapInfo.instance
	return (info.cell_position(Vector2i(1, 0)) - info.cell_position(Vector2i.ZERO)).x if info != null else 128.0


## Out of the rock or into it: touchable or not, a hex target or not.
func _set_out(on: bool) -> void:
	rb.collision_layer = _layer if on else 0
	var box: Node = rb.get_node_or_null("HitBox")
	if box != null:
		for shape: Node in box.get_children():
			if shape is CollisionShape2D:
				(shape as CollisionShape2D).set_deferred(&"disabled", not on)
	if on:
		rb.add_to_group(&"hex_target")
	else:
		rb.remove_from_group(&"hex_target")


func _physics_process(delta: float) -> void:
	t += delta
	for i: int in range(burrows.size() - 1, -1, -1):
		if t >= burrows[i].closes + HOLE_CLOSE:
			burrows.remove_at(i)
	var info: MapInfo = MapInfo.instance
	var player: Player = Stage.player()
	if info == null or info.world == null or player == null or not is_instance_valid(player):
		return
	match state:
		State.HIDDEN:
			timer -= delta
			if timer <= 0.0 and LevelGen.dist(info.cell_at(player.global_position), home) <= WAKE and _choose(info, player):
				state = State.WARN
				timer = Difficulty.tell(WARN_TIME)
		State.WARN:
			timer -= delta
			if timer <= 0.0:
				_burst(info, player)
		State.RISE:
			out = minf(1.0, out + delta / RISE_TIME)
			if out >= 1.0:
				state = State.OUT
				timer = OUT_TIME
		State.OUT:
			if not stunned:
				timer -= delta
				_squirm(info, delta)
			if timer <= 0.0:
				_sink(info)
		State.DROP:
			fall = minf(MAX_FALL, fall + GRAVITY * delta)
			var next: Vector2 = rb.global_position + Vector2(0, fall * delta)
			var below: Vector2i = info.cell_at(next + Vector2(0, GIRTH * 0.5))
			if info.world.is_ground(below) or not info.world.is_valid(below):
				# Landed on the floor: it squirms there.
				face = below + Vector2i.UP
				rb.global_position = _on_floor(info, rb.global_position.x, face)
				state = State.OUT
				timer = OUT_TIME
			else:
				rb.global_position = next
		State.SINK:
			out = maxf(0.0, out - delta / SINK_TIME)
			if out <= 0.0:
				state = State.HIDDEN
				timer = REST_TIME / Difficulty.attack()
				_set_out(false)


## Where it comes out this time, near the wizard: the ceiling over them now and then, else the
## floor under them (see the consts). Whether there is anywhere.
func _choose(info: MapInfo, player: Player) -> bool:
	var w: LevelGen = info.world
	var at: Vector2i = info.cell_at(player.global_position)
	var ceiling: Variant = null
	for k: int in range(1, CEILING_REACH + 1):
		var v: Vector2i = at + Vector2i(0, -k)
		if not w.is_valid(v) or w.is_ground(v):
			if w.is_valid(v) and k > 1:
				ceiling = v + Vector2i.DOWN
			break
	var floor_cell: Variant = null
	for k: int in range(0, FLOOR_REACH + 1):
		var v: Vector2i = at + Vector2i(0, k)
		if not w.is_valid(v) or w.is_ground(v):
			break
		if w.is_valid(v + Vector2i.DOWN) and w.is_ground(v + Vector2i.DOWN):
			floor_cell = v
			break
	var drop: bool = ceiling != null and RisoDecor.h(w.seed_for_colors, home, EMERGE_DEAL + emerges) * float(CEILING_CHANCE) < 1.0
	if drop or (floor_cell == null and ceiling != null):
		face = ceiling
		from_ceiling = true
	elif floor_cell != null:
		face = floor_cell
		from_ceiling = false
	else:
		return false
	emerges += 1
	heading = signf(player.global_position.x - info.cell_position(face).x)
	if heading == 0.0:
		heading = 1.0
	return true


## Out of the rock at its face, through a new hole: up from the floor (knocking up a wizard standing
## over it), or dropping from the ceiling.
func _burst(info: MapInfo, player: Player) -> void:
	_set_out(true)
	_open_burrow(mouth(), face_way(), 0.0 if from_ceiling else RISE_TIME)
	if from_ceiling:
		rb.global_position = face_point() + Vector2(0, GIRTH * 0.5)
		fall = 0.0
		out = 1.0
		state = State.DROP
	else:
		mouth_x = mouth().x
		rb.global_position = _on_floor(info, info.cell_position(face).x, face)
		out = 0.0
		state = State.RISE
		_bump(info, player)


## A wizard standing on the floor it bursts out of, over where it comes to lie, is knocked up.
func _bump(info: MapInfo, player: Player) -> void:
	if not player.is_on_floor() or info.cell_at(player.global_position) != face:
		return
	if absf(player.global_position.x - rb.global_position.x) > BUMP_REACH:
		return
	player.velocity.y = minf(player.velocity.y, BUMP)


## Down into the floor again, head first, through a new hole: just ahead of its head where there is
## floor, else (turning about) behind its tail, else right under its head.
func _sink(info: MapInfo) -> void:
	state = State.SINK
	var reach: float = LENGTH * 0.5 + GIRTH * 0.5
	var x: float = rb.global_position.x
	if not _floor_at(info, x + heading * reach):
		if _floor_at(info, x - heading * reach):
			heading = -heading
		else:
			reach = LENGTH * 0.5
	mouth_x = x + heading * reach
	_open_burrow(Vector2(mouth_x, rb.global_position.y + GIRTH * 0.5), Vector2.UP, SINK_TIME)


## Whether there is floor at `x` across, level with where it lies: an open cell with rock under it.
func _floor_at(info: MapInfo, x: float) -> bool:
	var w: LevelGen = info.world
	var v: Vector2i = info.cell_at(Vector2(x, rb.global_position.y))
	return w.is_valid(v) and not w.is_ground(v) and w.is_valid(v + Vector2i.DOWN) and w.is_ground(v + Vector2i.DOWN)


## Where its middle stands on the floor under open cell `cell`, at `x` across.
func _on_floor(info: MapInfo, x: float, cell: Vector2i) -> Vector2:
	return Vector2(x, info.cell_position(cell).y + _cell_px() * 0.5 - GIRTH * 0.5)


## Squirm along the floor, turning back where the floor ends or rock stands in its way.
func _squirm(info: MapInfo, delta: float) -> void:
	var w: LevelGen = info.world
	var step: float = heading * SQUIRM_SPEED * Difficulty.speed() * delta
	var front: Vector2 = rb.global_position + Vector2(heading * (LENGTH * 0.5 + absf(step)), 0)
	var ahead: Vector2i = info.cell_at(front)
	if not w.is_valid(ahead) or w.is_ground(ahead) or not w.is_ground(ahead + Vector2i.DOWN):
		heading = -heading
		return
	rb.global_position.x += step
