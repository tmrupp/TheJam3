class_name RockBug
extends Stunnable
## A rock-bug, in crag levels (CragsArchetype.place_bugs, and called out by a gondola): a small
## pink crawler that clings to rock and walks along it one way, slowly, floors, walls and ceilings
## alike, turning in at inner corners and wrapping round outer ones, and turning back, as a wisp
## does, only where it must: at thorns, a shut gate or another rock-bug in its way. It never hunts.
## On rock it keeps to the rock's face: round an outer corner it walks to the corner and turns about
## it, and at an inner corner it walks into the corner and turns there, never cutting through.
## A gondola's bugs come out onto its cable ahead of the car (ride_track) and cling to it, making
## their way along to meet the car; when the top of the car reaches one, it crawls over the roof
## and in through the hatch in it, onto the inside of the roof, and from then on crawls round the
## inside of the car: along the roof, down a side (the rails its bars run in), across the floor and
## up the other side, all the way round, swinging with it. When the car stands with its sides up, a
## bug coming to the edge of its floor steps out onto the rock there if there is any (else it turns
## back across the floor), so a rider who times it can let one off.
## Stunned (a hex bolt or a parry), it lets go of a wall, a ceiling, the cable or the car and falls
## until it lands on rock, where it clings again once the stun wears off (on a floor it just
## stands). Its touch hurts, like any enemy's (its HitBox). Moved only from here: its body is a
## frozen kinematic RigidBody2D that collides with nothing, as a wraith's.

## How fast it walks along rock, makes its way along a gondola's cable, crawls in through a car's
## roof and round the inside of the car (pixels a second).
const CRAWL_SPEED: float = 55.0
const TRACK_SPEED: float = 90.0
const ENTER_SPEED: float = 70.0
const CAR_SPEED: float = 60.0
## How near the car's hanger wheel on the cable it gets onto the car (pixels between its middle and
## the wheel's, along the cable), and how fast it turns over going in through the hatch (radians a
## second).
const HIT: float = 24.0
const TUMBLE: float = 7.0
## How many steps an outer corner's quarter turn is walked in.
const ARC_STEPS: int = 6
## How far its middle stands off the rock it clings to (pixels), and how fast it falls (pixels a
## second more each second, at most MAX_FALL).
const BODY: float = 16.0
const GRAVITY: float = 1500.0
const MAX_FALL: float = 900.0
## How near another rock-bug ahead of it turns it back (pixels).
const CROWD: float = 50.0
## What it turns back from: thorns, and gates not yet opened.
const BLOCKS: Array[LevelGen.Type] = [LevelGen.Type.SPIKES, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.TOLL]

## Where it is: on rock, on a gondola's cable, crawling into a car through its roof, inside a car, or
## falling.
enum Mode { ROCK, TRACK, ENTER, CAR, FALLING }
## Which inside face of a car it clings to: the floor, the right side, the roof or the left side.
enum Face { FLOOR, RIGHT, ROOF, LEFT }

@onready var rb: RigidBody2D = $".."
var map_info: MapInfo
var mode: Mode = Mode.FALLING
## Whether it has taken hold yet: placed with a level, it clings to the rock beside its cell (under it
## first) on its first step.
var placed: bool = false
## On rock: the open cell it is in and the way to the rock it clings to; the step it is walking (the
## way along the rock's face a point at a time, its length and how far along it is, in pixels, and
## how far through, 0..1), the way it walks along the rock (+1 or -1, a quarter turn on from the
## rock's way), and the way the rock is from it at the step's end.
var cell: Vector2i = Vector2i.ZERO
var normal: Vector2i = Vector2i.DOWN
var step: PackedVector2Array = PackedVector2Array()
var step_len: float = 0.0
var step_d: float = 0.0
var u: float = 1.0
var way: int = 1
var to_normal: Vector2i = Vector2i.DOWN
## On a gondola's track or in its car: the gondola, how far along its track (cells), and where across
## Inside a car: the face it clings to, and where its middle is in the car (pixels from the middle of
## the car's floor, turned with the car); `way` is then the way it crawls along the face (+1 right
## along the floor and roof, +1 down the sides). Crawling in: where it is in the car, and whether
## it is through the hatch yet.
var gondola: Gondola
var track_s: float = 0.0
var face: Face = Face.FLOOR
var rel: Vector2 = Vector2.ZERO
var through: bool = false
## Falling: how fast.
var fall_speed: float = 0.0
## The way its back faces (away from what it clings to), eased, and the way it last moved (a unit
## vector; its head leads), for the art; whether it is walking.
var up: Vector2 = Vector2.UP
var heading: Vector2 = Vector2.RIGHT
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


## Called out by gondola `g`: onto its cable `along` cells along its track, hanging under it, to
## make its way to the car.
func ride_track(g: Gondola, along: float) -> void:
	gondola = g
	map_info = g.map_info
	placed = true
	track_s = clampf(along, 0.0, float(g.path.size() - 1))
	mode = Mode.TRACK
	up = _off_cable()
	rb.global_position = _on_cable()


## Whether it is on gondola `g`'s track or in its car.
func riding(g: Gondola) -> bool:
	return gondola == g and mode in [Mode.TRACK, Mode.ENTER, Mode.CAR]


func _physics_process(delta: float) -> void:
	t += delta
	if map_info == null or map_info.world == null:
		return
	if not placed:
		placed = true
		if rb.has_meta(&"cell") and mode == Mode.FALLING:
			_cling(rb.get_meta(&"cell"))
	# Stunned, it lets go of a wall, a ceiling or the gondola (on a floor it just stays).
	if stunned and (mode in [Mode.TRACK, Mode.ENTER, Mode.CAR] or (mode == Mode.ROCK and normal != Vector2i.DOWN)):
		_let_go()
	walking = false
	var before: Vector2 = rb.global_position
	match mode:
		Mode.ROCK:
			if not stunned:
				_walk_rock(delta)
		Mode.TRACK:
			_walk_track(delta)
		Mode.ENTER:
			_crawl_in(delta)
		Mode.CAR:
			_walk_car(delta)
		Mode.FALLING:
			_fall(delta)
	if mode == Mode.CAR:
		heading = (Vector2(float(way), 0.0) if face == Face.FLOOR or face == Face.ROOF else Vector2(0.0, float(way))).rotated(gondola.rotation)
	elif (mode == Mode.ROCK or mode == Mode.TRACK) and rb.global_position.distance_squared_to(before) > 0.0001:
		heading = (rb.global_position - before).normalized()


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
			rb.global_position = _rest(v, n)
			_set_step([rb.global_position])
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


## Walk along the rock a step at a time (see the class description), its back turning to face away
## from the rock it is coming to once it is halfway through the step.
func _walk_rock(delta: float) -> void:
	if u >= 1.0:
		cell = map_info.cell_at(rb.global_position)
		normal = to_normal
		if not _solid(cell + normal):
			_let_go()
			return
		if not _plan_step(way):
			if not _plan_step(-way):
				return
			way = -way
	step_d = minf(step_len, step_d + CRAWL_SPEED * delta)
	u = step_d / step_len if step_len > 0.0 else 1.0
	rb.global_position = _along_step(step_d)
	up = up.lerp(-Vector2(to_normal if u >= 0.5 else normal), minf(1.0, delta * 12.0))
	walking = true


## Walk `points` next, from the first to the last.
func _set_step(points: Array[Vector2]) -> void:
	step = PackedVector2Array(points)
	step_len = 0.0
	for i: int in range(1, step.size()):
		step_len += step[i - 1].distance_to(step[i])
	step_d = 0.0
	u = 0.0 if step_len > 0.0 else 1.0


## The point `d` pixels along the step.
func _along_step(d: float) -> Vector2:
	var left: float = d
	for i: int in range(1, step.size()):
		var piece: float = step[i - 1].distance_to(step[i])
		if left <= piece and piece > 0.0:
			return step[i - 1].lerp(step[i], left / piece)
		left -= piece
	return step[-1]


## Plan the next step along the rock going `going`, keeping to the rock's face: in at an inner corner
## (into the corner, then turning there), round an outer one (to the corner, a quarter turn about
## it, then down the new face); false, planning nothing, if that way is blocked (see BLOCKS, CROWD).
func _plan_step(going: int) -> bool:
	var tangent: Vector2i = Vector2i(-normal.y, normal.x) * going
	var t_v: Vector2 = Vector2(tangent)
	var n_v: Vector2 = Vector2(normal)
	var corner: Vector2 = map_info.cell_position(cell) + (t_v + n_v) * _half()
	var next_cell: Vector2i = cell
	var next_normal: Vector2i = normal
	var via: Array[Vector2] = []
	if _solid(cell + tangent):
		# An inner corner: into it, then turn to cling to the rock ahead.
		next_normal = tangent
		via.append(corner - (t_v + n_v) * BODY)
	elif _solid(cell + tangent + normal):
		next_cell = cell + tangent
	else:
		# An outer corner: wrap round it.
		next_cell = cell + tangent + normal
		next_normal = -tangent
		for k: int in range(ARC_STEPS + 1):
			via.append(corner + (-n_v).slerp(t_v, float(k) / float(ARC_STEPS)) * BODY)
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
	var points: Array[Vector2] = [rb.global_position]
	points.append_array(via)
	points.append(next_pos)
	_set_step(points)
	to_normal = next_normal
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


## On a gondola's cable: along it to meet the car, and onto the car when the top of the car (its
## hanger wheel) reaches it.
func _walk_track(delta: float) -> void:
	if gondola == null or not is_instance_valid(gondola):
		_let_go()
		return
	var gap: float = gondola.s - track_s
	if absf(gap) * gondola.cell_px <= HIT:
		mode = Mode.ENTER
		rel = gondola.to_local(rb.global_position)
		through = false
		return
	track_s += signf(gap) * minf(TRACK_SPEED * delta / gondola.cell_px, absf(gap))
	rb.global_position = _on_cable()
	up = up.lerp(_off_cable(), minf(1.0, delta * 8.0)).normalized()
	walking = true


## Clinging to the cable at `track_s`: under it where it slopes, beside it where it runs straight up.
func _on_cable() -> Vector2:
	return gondola.world_at(track_s) + Vector2(0.0, -gondola.cell_px * Gondola.CABLE_UP) + _off_cable() * BODY


## The way from the cable at `track_s` to its middle (its back faces that way): square to the cable,
## downward where it slopes, and to its right where it runs straight up.
func _off_cable() -> Vector2:
	var along: Vector2 = gondola.track_dir(track_s)
	var off: Vector2 = Vector2(-along.y, along.x)
	if absf(off.y) < 0.01:
		return Vector2.RIGHT
	return off if off.y > 0.0 else -off


## Crawling into the car, moving (and swinging) with it: onto its roof by the hatch, then in through
## the hatch, turning over, onto the inside of the roof (Mode.CAR), crawling toward the wizard.
func _crawl_in(delta: float) -> void:
	if gondola == null or not is_instance_valid(gondola):
		_let_go()
		return
	var on_roof: Vector2 = Vector2(Gondola.HATCH_X, -gondola.cell_px * 2.0 - Gondola.ROOF_RISE - BODY + 8.0)
	var inside: Vector2 = Vector2(Gondola.HATCH_X, _roof_y())
	rel = rel.move_toward(inside if through else on_roof, ENTER_SPEED * delta)
	var want: Vector2 = Vector2.DOWN if through else Vector2.UP
	up = up.rotated(clampf(up.angle_to(want.rotated(gondola.rotation)), -TUMBLE * delta, TUMBLE * delta))
	walking = true
	rb.global_position = gondola.to_global(rel)
	if not through and rel == on_roof:
		through = true
	elif through and rel == inside:
		mode = Mode.CAR
		face = Face.ROOF
		var player: Player = map_info.player
		way = 1 if player == null or player.global_position.x >= gondola.global_position.x else -1


## How far either way from the car's middle its middle comes on the floor and roof (to the rails at
## the car's sides), and how high it hangs on the inside of the roof (pixels, up being negative).
func _car_edge() -> float:
	return gondola.cell_px - Gondola.RAIL_IN - BODY


func _roof_y() -> float:
	return -gondola.cell_px * 2.0 + Gondola.SLAB + BODY


## Inside the car: round its inside faces (see the class description). At the edge of the floor,
## while the car stands with that side up, out onto the rock beyond if there is any, else back.
func _walk_car(delta: float) -> void:
	if gondola == null or not is_instance_valid(gondola):
		_let_go()
		return
	var edge: float = _car_edge()
	var top: float = _roof_y()
	var step: float = float(way) * CAR_SPEED * delta
	match face:
		Face.FLOOR, Face.ROOF:
			rel.x += step
			if absf(rel.x) >= edge:
				var k: int = 0 if rel.x < 0.0 else 1
				var side: int = -1 if k == 0 else 1
				if face == Face.FLOOR and not gondola.running and not gondola.side_shut[k]:
					# An open side: off onto the rock beyond, or back across the floor.
					if _step_off(side):
						return
					rel.x = float(side) * edge
					way = -side
					rb.global_position = gondola.to_global(rel)
					return
				# Round the inside corner, onto the side: up it from the floor, down it from the roof.
				way = -1 if face == Face.FLOOR else 1
				rel.x = float(side) * edge
				face = Face.LEFT if k == 0 else Face.RIGHT
		Face.LEFT, Face.RIGHT:
			rel.y += step
			var side: int = -1 if face == Face.LEFT else 1
			if rel.y <= top:
				rel.y = top
				face = Face.ROOF
				way = -side
			elif rel.y >= -BODY:
				rel.y = -BODY
				face = Face.FLOOR
				way = -side
	rb.global_position = gondola.to_global(rel)
	up = up.lerp(_face_up().rotated(gondola.rotation), minf(1.0, delta * 12.0)).normalized()
	walking = true


## The way its back faces on its face of the car, the car upright.
func _face_up() -> Vector2:
	match face:
		Face.RIGHT:
			return Vector2.LEFT
		Face.ROOF:
			return Vector2.DOWN
		Face.LEFT:
			return Vector2.RIGHT
	return Vector2.UP


## Off the floor's edge on side `side` (-1 left, +1 right), onto the rock beside the car, if there is
## open air over rock there and nothing shut in the way; whether it went.
func _step_off(side: int) -> bool:
	var beyond: Vector2i = map_info.cell_at(gondola.global_position + Vector2(float(side) * (gondola.cell_px + _half()), -_half()))
	if _solid(beyond) or not _solid(beyond + Vector2i.DOWN) or _blocked(beyond):
		return false
	cell = beyond
	normal = Vector2i.DOWN
	to_normal = Vector2i.DOWN
	way = -side
	_set_step([rb.global_position, _rest(beyond, Vector2i.DOWN)])
	mode = Mode.ROCK
	gondola = null
	return true


## Falling: down until it lands on rock, then cling there.
func _fall(delta: float) -> void:
	fall_speed = minf(fall_speed + GRAVITY * delta, MAX_FALL)
	var next: Vector2 = rb.global_position + Vector2(0.0, fall_speed * delta)
	if map_info.solid_at(next + Vector2(0.0, BODY)) and not map_info.solid_at(rb.global_position):
		_cling(map_info.cell_at(rb.global_position))
		return
	rb.global_position = next
	up = up.rotated(delta * 7.0)
