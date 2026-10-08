class_name RockBug
extends Stunnable
## A rock-bug, in crag levels (CragsArchetype.place_bugs, and called up by a gondola): a little
## stone-backed crawler that clings to rock and walks along it, floors, walls and ceilings alike,
## turning in at inner corners and wrapping round outer ones. It wanders while the wizard is far and
## hunts them (along the rock, whichever way along it brings it nearer) within WAKE. A gondola's bugs
## come out onto its track ahead of the car (ride_track), crawl along the cable to meet it and climb
## on (within LATCH cells), then crawl round the inside of the car at its rider. Stunned (a hex bolt
## or a parry), it lets go and falls (out of the car too) until it lands on rock, where it clings
## again once the stun wears off. Its touch hurts, like any enemy's (its HitBox), and it backs off a
## moment after. Moved only from here: its body is a frozen kinematic RigidBody2D that collides with
## nothing, as a wraith's.

## How fast it walks wandering and hunting, along a gondola's cable and round the inside of a car
## (pixels a second).
const CRAWL_SPEED: float = 90.0
const HUNT_SPEED: float = 150.0
const TRACK_SPEED: float = 200.0
const CAR_SPEED: float = 140.0
## How near the wizard wakes it to hunt (pixels), and how near a gondola's car on its track it climbs
## on (cells along the track).
const WAKE: float = 760.0
const LATCH: float = 1.2
## How far its middle stands off the rock it clings to (pixels), how fast it falls (pixels a second
## more each second, at most MAX_FALL), and how long it backs off after a touch (seconds).
const BODY: float = 27.0
const GRAVITY: float = 1500.0
const MAX_FALL: float = 900.0
const RECOIL: float = 0.9
## How near the wizard its touch reaches, for backing off (pixels).
const TOUCH: float = 64.0

enum Mode { ROCK, TRACK, CAR, FALLING }

@onready var rb: RigidBody2D = $".."
var map_info: MapInfo
var mode: Mode = Mode.FALLING
## On rock: the open cell it is in and the way to the rock it clings to; the step it is walking (from
## where, to where, how far through, 0..1), the way it walks along the rock (+1 or -1), and the way
## the rock is from it at the step's end.
var cell: Vector2i = Vector2i.ZERO
var normal: Vector2i = Vector2i.DOWN
var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var u: float = 1.0
var way: int = 1
var to_normal: Vector2i = Vector2i.DOWN
## On a gondola's track or in its car: the gondola, how far along its track (cells), and how far round
## the inside of the car (pixels, from the floor's left end, along the floor first).
var gondola: Gondola
var track_s: float = 0.0
var car_p: float = 0.0
## Falling: how fast; and how long it still backs off after a touch.
var fall_speed: float = 0.0
var recoil: float = 0.0
## The way its back faces (away from what it clings to), eased, for the art; whether it is walking.
var up: Vector2 = Vector2.UP
var walking: bool = false
var t: float = 0.0


## Whether it has taken hold yet: placed with a level, it clings to the rock beside its cell (under it
## first) on its first step.
var placed: bool = false


func _ready() -> void:
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.collision_layer = 0
	rb.collision_mask = 0
	if map_info == null:
		map_info = MapInfo.instance


## Called up by gondola `g`: out onto its track `along` cells along it, crawling to meet the car.
func ride_track(g: Gondola, along: float) -> void:
	gondola = g
	map_info = g.map_info
	track_s = clampf(along, 0.0, float(g.path.size() - 1))
	mode = Mode.TRACK
	rb.global_position = _on_cable()


## Whether it is still on gondola `g` or its track (so the car holds its rider for it).
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
	recoil = maxf(0.0, recoil - delta)


## Let go of whatever it clings to, and fall.
func _let_go() -> void:
	mode = Mode.FALLING
	fall_speed = 0.0


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
			if rb != null:
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


func _wizard() -> Player:
	var p: Player = map_info.player
	return p if p != null and is_instance_valid(p) else null


## Walk along the rock a step at a time (see the class description).
func _walk_rock(delta: float) -> void:
	if u >= 1.0:
		cell = map_info.cell_at(to_pos)
		normal = to_normal
		if not _solid(cell + normal):
			_let_go()
			return
		_next_step()
	var wizard: Player = _wizard()
	var hunting: bool = wizard != null and wizard.global_position.distance_to(rb.global_position) < WAKE
	var gap: float = maxf(1.0, from_pos.distance_to(to_pos))
	var speed: float = HUNT_SPEED if hunting else CRAWL_SPEED
	if recoil > 0.0:
		speed *= 0.5
	u = minf(1.0, u + speed * delta / gap)
	rb.global_position = from_pos.lerp(to_pos, u)
	up = up.lerp(-Vector2(normal).lerp(Vector2(to_normal), u).normalized(), minf(1.0, delta * 12.0))
	walking = true


## Choose the next step along the rock: toward the wizard if hunting (and not backing off), else on
## the way it was going; in at an inner corner, round an outer one.
func _next_step() -> void:
	var along: Vector2i = Vector2i(-normal.y, normal.x)
	var wizard: Player = _wizard()
	if wizard != null and wizard.global_position.distance_to(rb.global_position) < WAKE:
		var d: float = Vector2(along).dot(wizard.global_position + Vector2(0, -40) - rb.global_position)
		if absf(d) > 8.0:
			way = 1 if d > 0.0 else -1
			if recoil > 0.0:
				way = -way
	var tangent: Vector2i = along * way
	from_pos = rb.global_position
	u = 0.0
	if _solid(cell + tangent):
		# An inner corner: turn in to cling to the rock ahead.
		to_normal = tangent
		to_pos = _rest(cell, tangent)
	elif _solid(cell + tangent + normal):
		to_normal = normal
		to_pos = _rest(cell + tangent, normal)
	else:
		# An outer corner: wrap round it.
		to_normal = -tangent
		to_pos = _rest(cell + tangent + normal, -tangent)


## On a gondola's cable: crawl along it to meet the car, and climb on when it is near.
func _walk_track(delta: float) -> void:
	if gondola == null or not is_instance_valid(gondola):
		_let_go()
		return
	var gap: float = gondola.s - track_s
	if absf(gap) <= LATCH:
		mode = Mode.CAR
		# Onto the car's roof, at the end it climbed on from.
		var w: Vector2 = _car_box()
		car_p = w.x + w.y + (w.x * 0.15 if signf(gap) * float(gondola.dir) > 0.0 else w.x * 0.85)
		return
	track_s += signf(gap) * TRACK_SPEED * delta / gondola.cell_px
	rb.global_position = _on_cable()
	up = up.lerp(Vector2.UP, minf(1.0, delta * 8.0))
	walking = true


## On top of the cable over `track_s`.
func _on_cable() -> Vector2:
	return gondola.world_at(track_s) + Vector2(0.0, -gondola.cell_px * 2.55 - BODY)


## The inside of the car it crawls round: its width and height (pixels), its middle kept BODY off
## the floor, walls and roof.
func _car_box() -> Vector2:
	var c: float = gondola.cell_px * 2.0 - Gondola.SLAB * 2.0 - BODY * 2.0
	return Vector2(c, c)


## A point `p` pixels round the inside of the car (along the floor from its left end, up the right
## wall, back along the roof, down the left wall), relative to the car's floor, and the way to what
## it clings to there.
func _car_point(p: float) -> Array:
	var box: Vector2 = _car_box()
	var q: float = fposmod(p, 2.0 * (box.x + box.y))
	var left: float = -box.x * 0.5
	var floor_y: float = -Gondola.SLAB - BODY
	if q <= box.x:
		return [Vector2(left + q, floor_y), Vector2.DOWN]
	if q <= box.x + box.y:
		return [Vector2(-left, floor_y - (q - box.x)), Vector2.RIGHT]
	if q <= 2.0 * box.x + box.y:
		return [Vector2(-left - (q - box.x - box.y), floor_y - box.y), Vector2.UP]
	return [Vector2(left, floor_y - box.y + (q - 2.0 * box.x - box.y)), Vector2.LEFT]


## In the car: crawl round its inside toward its rider (the shorter way round), backing off after a
## touch; with nobody in it, round and round.
func _walk_car(delta: float) -> void:
	if gondola == null or not is_instance_valid(gondola):
		_let_go()
		return
	var box: Vector2 = _car_box()
	var round_px: float = 2.0 * (box.x + box.y)
	var step: float = CAR_SPEED * delta
	var wizard: Player = _wizard()
	if wizard != null and gondola.has_rider():
		var aim: Vector2 = wizard.global_position + Vector2(0, -40) - gondola.global_position
		# The nearest point round the inside to the rider, found by sampling.
		var best: float = car_p
		var best_d: float = INF
		for k: int in range(32):
			var p: float = round_px * float(k) / 32.0
			var d: float = ((_car_point(p)[0] as Vector2) - aim).length()
			if d < best_d:
				best_d = d
				best = p
		var ahead: float = fposmod(best - car_p, round_px)
		var dir: float = 1.0 if ahead <= round_px * 0.5 else -1.0
		if recoil > 0.0:
			dir = -dir
		var room: float = minf(ahead, round_px - ahead)
		car_p += dir * (minf(step, room) if recoil <= 0.0 else step)
		if recoil <= 0.0 and wizard.global_position.distance_to(rb.global_position) < TOUCH:
			recoil = RECOIL
	else:
		car_p += step
	var at: Array = _car_point(car_p)
	rb.global_position = gondola.global_position + (at[0] as Vector2)
	up = up.lerp(-(at[1] as Vector2), minf(1.0, delta * 12.0))
	walking = true


## Falling: down until it lands on rock, then cling there.
func _fall(delta: float) -> void:
	fall_speed = minf(fall_speed + GRAVITY * delta, MAX_FALL)
	var next: Vector2 = rb.global_position + Vector2(0.0, fall_speed * delta)
	var below: Vector2 = next + Vector2(0.0, BODY)
	if map_info.solid_at(below) and not map_info.solid_at(rb.global_position):
		_cling(map_info.cell_at(rb.global_position))
		return
	rb.global_position = next
	up = up.rotated(delta * 7.0)
