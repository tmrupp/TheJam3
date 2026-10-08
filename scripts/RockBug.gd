class_name RockBug
extends Stunnable
## A rock-bug, in crag levels (CragsArchetype.place_bugs, and called out by a gondola): a little
## stone-backed crawler that clings to rock and walks along it one way, floors, walls and ceilings
## alike, turning in at inner corners and wrapping round outer ones, and turning back, as a wisp
## does, only where it must: at thorns, a shut gate or another rock-bug in its way. It never hunts.
## A gondola's bugs come out onto its track ahead of the car (ride_track), walk along the cable to
## meet it and climb in (within LATCH cells), then walk its floor, turning back at its sides while
## they are barred; when the car stands with its sides up, a bug walking off its edge steps out onto
## the rock there if there is any (else it turns back), so a rider who times it can let one off.
## Stunned (a hex bolt or a parry), it lets go of a wall, a ceiling or the car and falls until it
## lands on rock, where it clings again once the stun wears off (on a floor it just stands). Its
## touch hurts, like any enemy's (its HitBox). Moved only from here: its body is a frozen kinematic
## RigidBody2D that collides with nothing, as a wraith's.

## How fast it walks along rock, along a gondola's cable and across a car's floor (pixels a second).
const CRAWL_SPEED: float = 100.0
const TRACK_SPEED: float = 200.0
const CAR_SPEED: float = 110.0
## How near a gondola's car on its track it climbs in (cells along the track).
const LATCH: float = 1.2
## How far its middle stands off the rock it clings to (pixels), and how fast it falls (pixels a
## second more each second, at most MAX_FALL).
const BODY: float = 27.0
const GRAVITY: float = 1500.0
const MAX_FALL: float = 900.0
## How near another rock-bug ahead of it turns it back (pixels).
const CROWD: float = 70.0
## What it turns back from: thorns, and gates not yet opened.
const BLOCKS: Array[LevelGen.Type] = [LevelGen.Type.SPIKES, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.TOLL]

enum Mode { ROCK, TRACK, CAR, FALLING }

@onready var rb: RigidBody2D = $".."
var map_info: MapInfo
var mode: Mode = Mode.FALLING
## Whether it has taken hold yet: placed with a level, it clings to the rock beside its cell (under it
## first) on its first step.
var placed: bool = false
## On rock: the open cell it is in and the way to the rock it clings to; the step it is walking (from
## where, to where, how far through, 0..1), the way it walks along the rock (+1 or -1, a quarter
## turn on from the rock's way), and the way the rock is from it at the step's end.
var cell: Vector2i = Vector2i.ZERO
var normal: Vector2i = Vector2i.DOWN
var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var u: float = 1.0
var way: int = 1
var to_normal: Vector2i = Vector2i.DOWN
## On a gondola's track or in its car: the gondola, how far along its track (cells), and where across
## the car's floor (pixels from its middle).
var gondola: Gondola
var track_s: float = 0.0
var car_x: float = 0.0
## Falling: how fast.
var fall_speed: float = 0.0
## The way its back faces (away from what it clings to), eased, for the art; whether it is walking.
var up: Vector2 = Vector2.UP
var walking: bool = false
var t: float = 0.0


func _ready() -> void:
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.collision_layer = 0
	rb.collision_mask = 0
	rb.add_to_group(&"rock_bugs")
	if map_info == null:
		map_info = MapInfo.instance


## Called out by gondola `g`: onto its track `along` cells along it, walking to meet the car.
func ride_track(g: Gondola, along: float) -> void:
	gondola = g
	map_info = g.map_info
	placed = true
	track_s = clampf(along, 0.0, float(g.path.size() - 1))
	mode = Mode.TRACK
	rb.global_position = _on_cable()


## Whether it is on gondola `g`'s track or in its car.
func riding(g: Gondola) -> bool:
	return gondola == g and (mode == Mode.TRACK or mode == Mode.CAR)


func _physics_process(delta: float) -> void:
	t += delta
	if map_info == null or map_info.world == null:
		return
	if not placed:
		placed = true
		if rb.has_meta(&"cell") and mode == Mode.FALLING:
			_cling(rb.get_meta(&"cell"))
	# Stunned, it lets go of a wall, a ceiling or the gondola (on a floor it just stays).
	if stunned and (mode == Mode.TRACK or mode == Mode.CAR or (mode == Mode.ROCK and normal != Vector2i.DOWN)):
		_let_go()
	walking = false
	match mode:
		Mode.ROCK:
			if not stunned:
				_walk_rock(delta)
		Mode.TRACK:
			_walk_track(delta)
		Mode.CAR:
			_walk_car(delta)
		Mode.FALLING:
			_fall(delta)


## Let go of whatever it clings to, and fall.
func _let_go() -> void:
	mode = Mode.FALLING
	fall_speed = 0.0
	gondola = null


## Cling to the rock beside open cell `v` (under it first, then either side, then over it), or fall
## if there is none.
func _cling(v: Vector2i) -> void:
	for n: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if _solid(v + n):
			cell = v
			normal = n
			to_normal = n
			mode = Mode.ROCK
			from_pos = _rest(v, n)
			to_pos = from_pos
			u = 1.0
			rb.global_position = from_pos
			return
	mode = Mode.FALLING


func _solid(v: Vector2i) -> bool:
	return map_info.solid_at(map_info.cell_position(v))


## Where its middle rests in open cell `v`, clinging to the rock the way `n` is.
func _rest(v: Vector2i, n: Vector2i) -> Vector2:
	return map_info.cell_position(v) + Vector2(n) * (_half() - BODY)


func _half() -> float:
	var tm: TileMap = map_info.tile_map
	return float(tm.tile_set.tile_size.x) * tm.global_scale.x * 0.5


## Walk along the rock a step at a time (see the class description).
func _walk_rock(delta: float) -> void:
	if u >= 1.0:
		cell = map_info.cell_at(to_pos)
		normal = to_normal
		if not _solid(cell + normal):
			_let_go()
			return
		if not _plan_step(way):
			if not _plan_step(-way):
				return
			way = -way
	u = minf(1.0, u + CRAWL_SPEED * delta / maxf(1.0, from_pos.distance_to(to_pos)))
	rb.global_position = from_pos.lerp(to_pos, u)
	up = up.lerp(-Vector2(normal).lerp(Vector2(to_normal), u).normalized(), minf(1.0, delta * 12.0))
	walking = true


## Plan the next step along the rock going `going` (in at an inner corner, round an outer one);
## false, planning nothing, if that way is blocked (see BLOCKS, CROWD).
func _plan_step(going: int) -> bool:
	var tangent: Vector2i = Vector2i(-normal.y, normal.x) * going
	var next_cell: Vector2i = cell
	var next_normal: Vector2i = normal
	if _solid(cell + tangent):
		# An inner corner: turn in to cling to the rock ahead.
		next_normal = tangent
	elif _solid(cell + tangent + normal):
		next_cell = cell + tangent
	else:
		# An outer corner: wrap round it.
		next_cell = cell + tangent + normal
		next_normal = -tangent
	if next_cell != cell and _blocked(next_cell):
		return false
	var next_pos: Vector2 = _rest(next_cell, next_normal)
	for other: Node in get_tree().get_nodes_in_group(&"rock_bugs"):
		var o: Node2D = other as Node2D
		if o == rb or not is_instance_valid(o):
			continue
		var gap: Vector2 = o.global_position - rb.global_position
		if gap.length() < CROWD and gap.dot(next_pos - rb.global_position) > 0.0:
			return false
	from_pos = rb.global_position
	to_pos = next_pos
	to_normal = next_normal
	u = 0.0
	return true


## Whether cell `v` holds thorns or a gate that is shut (a switch gate down, a door or toll gate not
## yet opened).
func _blocked(v: Vector2i) -> bool:
	var w: LevelGen = map_info.world
	if not w.is_valid(v) or not w.get_cell(v).type in BLOCKS:
		return false
	if w.get_cell(v).type == LevelGen.Type.SWITCH_GATE:
		return not map_info.gate_open(v)
	return w.get_cell(v).type == LevelGen.Type.SPIKES or not map_info.record().opened.has(v)


## On a gondola's cable: walk along it to meet the car, and climb in when it is near.
func _walk_track(delta: float) -> void:
	if gondola == null or not is_instance_valid(gondola):
		_let_go()
		return
	var gap: float = gondola.s - track_s
	if absf(gap) <= LATCH:
		# In over the side nearer where it came from, walking across the floor.
		mode = Mode.CAR
		var side: float = signf(rb.global_position.x - gondola.global_position.x)
		if side == 0.0:
			side = 1.0
		car_x = side * _car_edge()
		way = -int(side)
		return
	track_s += signf(gap) * TRACK_SPEED * delta / gondola.cell_px
	rb.global_position = _on_cable()
	up = up.lerp(Vector2.UP, minf(1.0, delta * 8.0))
	walking = true


## On top of the cable over `track_s`.
func _on_cable() -> Vector2:
	return gondola.world_at(track_s) + Vector2(0.0, -gondola.cell_px * 2.55 - BODY)


## How far either way across the car's floor it walks before its side.
func _car_edge() -> float:
	return gondola.cell_px - Gondola.SLAB - BODY * 0.6


## In the car: across its floor, turning back at a barred side; at an open one, out onto the rock
## beyond if there is any, else back.
func _walk_car(delta: float) -> void:
	if gondola == null or not is_instance_valid(gondola):
		_let_go()
		return
	car_x += float(way) * CAR_SPEED * delta
	var edge: float = _car_edge()
	if absf(car_x) >= edge:
		var k: int = 0 if car_x < 0.0 else 1
		var side: int = -1 if k == 0 else 1
		if gondola.side_shut[k] or gondola.running:
			car_x = float(side) * edge
			way = -side
		elif absf(car_x) >= gondola.cell_px:
			var beyond: Vector2i = map_info.cell_at(gondola.global_position + Vector2(float(side) * (gondola.cell_px + _half()), -_half()))
			if not _solid(beyond) and _solid(beyond + Vector2i.DOWN) and not _blocked(beyond):
				# Off, onto the rock beside the car.
				cell = beyond
				normal = Vector2i.DOWN
				to_normal = Vector2i.DOWN
				from_pos = rb.global_position
				to_pos = _rest(beyond, Vector2i.DOWN)
				u = 0.0
				mode = Mode.ROCK
				gondola = null
				return
			car_x = float(side) * gondola.cell_px
			way = -side
	rb.global_position = gondola.global_position + Vector2(car_x, -BODY)
	up = up.lerp(Vector2.UP, minf(1.0, delta * 12.0))
	walking = true


## Falling: down until it lands on rock, then cling there.
func _fall(delta: float) -> void:
	fall_speed = minf(fall_speed + GRAVITY * delta, MAX_FALL)
	var next: Vector2 = rb.global_position + Vector2(0.0, fall_speed * delta)
	if map_info.solid_at(next + Vector2(0.0, BODY)) and not map_info.solid_at(rb.global_position):
		_cling(map_info.cell_at(rb.global_position))
		return
	rb.global_position = next
	up = up.rotated(delta * 7.0)
