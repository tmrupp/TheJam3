class_name Gondola
extends AnimatableBody2D
## A gondola, in crag levels (CragsArchetype.lay_circuit, shut_stations): a cable car running a
## circuit round the level, straight along the rows and columns of its cells (never slantwise), two
## cells wide and two high, with a floor, a roof and two sides that shut. Its stations stand on the
## circuit's two sides, each a doorway onto a landing into the level. One is open from the first;
## each of the others is shut by a gate across its doorway (a door, a switch gate or a toll gate,
## its record kept as any gate's) until opened.
##
## The car runs from station to station, stopping at each, and runs a stretch between two stations
## only if at least one of them is open: from an open station to a shut one and back, never from
## one shut station to the next. A lever inside works it (interact while in the car): pulled while
## it stands, it sets off (on the way it was going when it last came to a station, or back the
## other way after it was stopped on the way); pulled while it runs, it stops it where it is. A
## stretch it may not run makes the lever balk (a pink spark), and the next pull tries the other way.
## Standing on the landing of an open station it is not at calls it over, empty, by the shortest
## way round it may take.
##
## Whoever rides it is shut in while it runs or stands between stations, its sides barred pink
## (danger): on each stretch it calls up the castle's wraiths (Wraith) out of the cliff, FOES_BASE of
## them and one more for every FOES_DEPTH rows from the start, and at the station it stays barred
## until they are put down (or HOLD_MOST seconds pass, so nobody is shut in for good). Standing at
## a station its side facing the level opens. Riders are carried as on any moving body. Nothing
## about where it is is kept: on every visit it waits at its open station. Nothing here draws from
## the world RNG.

const INTERACTABLE: PackedScene = preload("res://prefabs/interactable.tscn")
## How fast it runs with a rider, and called empty (pixels a second), and how quickly it gets up to
## speed and slows for a station (pixels a second, each second).
const RIDE_SPEED: float = 360.0
const CALL_SPEED: float = 560.0
const ACCEL: float = 520.0
## How long its bars take to come down or lift.
const SHUT_TIME: float = 0.35
## The wraiths it calls up on each stretch a rider rides: FOES_BASE, and one more for every
## FOES_DEPTH rows from the start.
const FOES_BASE: int = 1
const FOES_DEPTH: int = 4
## Where each comes out of the cliff: this far to the side of the car, and this far ahead of it
## (pixels).
const FOE_OUT: float = 430.0
const FOE_AHEAD: float = 220.0
## The longest its bars stay down at a station while its wraiths are about (seconds).
const HOLD_MOST: float = 12.0
## How near a station's landing the wizard stands to call it there (pixels).
const CALL_NEAR: float = 330.0
## How thick its floor, roof and sides are (pixels).
const SLAB: float = 14.0
## Salt for the side its first wraith comes from, hashed with the level seed and its cell.
const SIDE_DEAL: int = 9300
## What shuts a station: a gate of one of these in its doorway, not yet opened.
const GATES: Array[LevelGen.Type] = [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.TOLL]

var map_info: MapInfo
var depth: int = 0
## A cell's size in pixels, and the middle of the level's first cell.
var cell_px: float = 128.0
var origin: Vector2 = Vector2.ZERO
## The circuit (see CragsArchetype.lay_circuit), how far round it is (cells), and its stations: the
## car's floor cell at each, how far round each is, each one's doorway, the way each faces into the
## level (+1 right, -1 left), and the car's floor at each in world pixels.
var loop: Rect2i
var round_cells: float = 1.0
var stops: Array[Vector2i] = []
var stops_s: Array[float] = []
var gates: Array[Vector2i] = []
var inner: Array[int] = []
var stations: Array[Vector2] = []
## Where it is (cells round the circuit), the station it stands at (-1 between stations), the way
## it runs or last ran (+1 on round the circuit, -1 back), and the way the lever sets it off next.
var s: float = 0.0
var at_station: int = 0
var dir: int = 1
var next_dir: int = 1
## Whether it is running, how fast, to where (cells round, not wrapped) and which station, the
## run's length (cells) and its top speed; and whether the run carries a rider (who is barred in,
## and for whom it calls up wraiths).
var running: bool = false
var speed: float = 0.0
var target_s: float = 0.0
var bound_for: int = -1
var run_length: float = 1.0
var top_speed: float = RIDE_SPEED
var ridden: bool = false
## Whether its rider is shut in; whether its left and right sides are shut, and how far their bars
## are down (0 up, 1 down), for the art.
var sealed: bool = false
var side_shut: Array[bool] = [true, true]
var shut: Array[float] = [1.0, 1.0]
## The wraiths called up on this ride, how many a stretch calls, how long it has held at a station
## for them, and the side the first comes from (+1 right, -1 left of its way).
var foes: Array[Node2D] = []
var foe_count: int = 0
var held: float = 0.0
var first_side: float = 1.0
var _walls: Array[CollisionShape2D] = []
var _inside: Area2D
var _lever: Interactable


## Lay it on its circuit: `circuit` is LevelGen.circuit (CragsArchetype.lay_circuit) with "start",
## the open station it waits at.
func setup(info: MapInfo, v: Vector2i, circuit: Variant) -> void:
	map_info = info
	depth = info.here.depth if info.here != null else 0
	var tm: TileMap = info.tile_map
	cell_px = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	origin = info.cell_position(Vector2i.ZERO)
	var c: Dictionary = circuit
	loop = c["loop"]
	round_cells = float(CragsArchetype.perimeter(loop))
	stops = c["stops"]
	gates = c["gates"]
	inner = c["inner"]
	for stop: Vector2i in stops:
		stops_s.append(CragsArchetype.along(loop, stop))
		stations.append(world_at(CragsArchetype.along(loop, stop)))
	at_station = int(c["start"])
	s = stops_s[at_station]
	@warning_ignore("integer_division")
	foe_count = FOES_BASE + depth / FOES_DEPTH
	first_side = 1.0 if RisoDecor.h(info.world.seed_for_colors, v, SIDE_DEAL) < 0.5 else -1.0
	var wide: float = cell_px * 2.0
	var tall: float = cell_px * 2.0
	_slab(Vector2(0.0, SLAB * 0.5), Vector2(wide - 4.0, SLAB))
	_slab(Vector2(0.0, -tall + SLAB * 0.5), Vector2(wide, SLAB))
	for side: float in [-1.0, 1.0]:
		_walls.append(_slab(Vector2(side * (wide - SLAB) * 0.5, -tall * 0.5), Vector2(SLAB, tall)))
	_inside = Area2D.new()
	_inside.collision_layer = 0
	_inside.collision_mask = 1
	var room: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(wide - SLAB * 2.0 - 8.0, tall - SLAB * 2.0)
	room.shape = box
	room.position = Vector2(0.0, -tall * 0.5)
	_inside.add_child(room)
	# The lever: interacting anywhere in the car pulls it.
	_lever = INTERACTABLE.instantiate() as Interactable
	_inside.add_child(_lever)
	add_child(_inside)
	_lever.interacted.connect(pull)
	_set_walls()
	for k: int in range(2):
		shut[k] = 1.0 if side_shut[k] else 0.0
	_place(world_at(s))


## A solid slab of the car centred at `at`, `size` across and down.
func _slab(at: Vector2, size: Vector2) -> CollisionShape2D:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	add_child(shape)
	return shape


## Move without sweeping anything along the way (physics sync off for the move).
func _place(to: Vector2) -> void:
	sync_to_physics = false
	position = to
	sync_to_physics = true


## The car's floor (its bottom middle) in world pixels, `along` cells round the circuit.
func world_at(along: float) -> Vector2:
	return origin + CragsArchetype.point(loop, along) * cell_px + Vector2(cell_px * 0.5, cell_px * 0.5)


## The middle of the car, in world pixels.
func center() -> Vector2:
	return global_position + Vector2(0.0, -cell_px)


## Whether the wizard is in the car.
func has_rider() -> bool:
	var player: Player = map_info.player if map_info != null else null
	return player != null and is_instance_valid(player) and _inside != null and _inside.overlaps_body(player)


## Whether station `i` is open: no gate in its doorway, or its gate opened.
func is_open(i: int) -> bool:
	var g: Vector2i = gates[i]
	return not map_info.world.get_cell(g).type in GATES or map_info.record().opened.has(g)


## The next station on from `from` (cells round), the way `way` runs, and how far that is (cells):
## [station, cells], or [-1, INF] if there is none.
func next_station(from: float, way: int) -> Array:
	var best: int = -1
	var gap: float = INF
	for i: int in range(stops_s.size()):
		var d: float = fposmod((stops_s[i] - from) * float(way), round_cells)
		if d > 0.001 and d < gap:
			gap = d
			best = i
	return [best, gap]


## Whether it may run on from where it is the way `way` runs, to the next station: from a station,
## if that one or the next is open; between stations, always (it got there).
func may_run(way: int) -> bool:
	var next: int = int(next_station(s, way)[0])
	if next < 0:
		return false
	return at_station < 0 or is_open(at_station) or is_open(next)


## The lever, pulled: stop if it runs; if it stands, set off (balking if it may not run that way).
func pull() -> void:
	if running:
		running = false
		speed = 0.0
		next_dir = -dir
		at_station = _station_here()
		if at_station >= 0:
			next_dir = dir
		_set_walls()
		return
	if not may_run(next_dir):
		next_dir = -next_dir
		RisoFx.burst(&"hit", center(), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
		return
	var way: Array = next_station(s, next_dir)
	_set_off(next_dir, int(way[0]), float(way[1]), has_rider())


## The station it is right at, or -1.
func _station_here() -> int:
	for i: int in range(stops_s.size()):
		if absf(fposmod(s - stops_s[i] + round_cells * 0.5, round_cells) - round_cells * 0.5) < 0.01:
			return i
	return -1


## Run `cells` round the way `way` runs, to station `to`; `with_rider` bars it and calls up wraiths.
func _set_off(way: int, to: int, cells: float, with_rider: bool) -> void:
	dir = way
	bound_for = to
	target_s = s + float(way) * cells
	run_length = maxf(cells, 0.001)
	ridden = with_rider
	top_speed = RIDE_SPEED if ridden else CALL_SPEED
	running = true
	at_station = -1
	held = 0.0
	_set_walls()


## Called from the landing of open station `to`: the shortest way round to it running only stretches
## it may run (each with an open end), if there is one.
func _call_to(to: int) -> void:
	var best_way: int = 0
	var best: float = INF
	for way: int in [1, -1]:
		var cells: float = fposmod((stops_s[to] - s) * float(way), round_cells)
		if cells <= 0.001 or cells >= best:
			continue
		var ok: bool = true
		var from: int = at_station
		var here: float = s
		var gone: float = 0.0
		while ok and gone < cells - 0.001:
			var step: Array = next_station(here, way)
			var next: int = int(step[0])
			if from >= 0 and not is_open(from) and not is_open(next):
				ok = false
			from = next
			here = stops_s[next]
			gone += float(step[1])
		if ok:
			best = cells
			best_way = way
	if best_way != 0:
		_set_off(best_way, to, best, false)


## The wraiths it called up that are still about.
func _about() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for i: int in range(foes.size()):
		if is_instance_valid(foes[i]) and not foes[i].is_queued_for_deletion():
			out.append(foes[i])
	return out


## Its sides: both shut while it runs, stands between stations or holds its rider; at a station
## otherwise, open on the side facing the level.
func _set_walls() -> void:
	var open_side: int = 0
	if not running and not sealed and at_station >= 0:
		open_side = inner[at_station]
	for k: int in range(2):
		side_shut[k] = (-1 if k == 0 else 1) != open_side
		_walls[k].set_deferred(&"disabled", not side_shut[k])


func _physics_process(delta: float) -> void:
	if stations.is_empty():
		return
	var inside: bool = has_rider()
	if running:
		var remaining: float = absf(target_s - s) * cell_px
		speed = move_toward(speed, minf(top_speed, sqrt(2.0 * ACCEL * remaining) + 20.0), ACCEL * delta)
		var step: float = minf(remaining, speed * delta)
		var before: float = 1.0 - remaining / (run_length * cell_px)
		s += float(dir) * step / cell_px
		position = world_at(s)
		if ridden:
			_call_foes(before, 1.0 - (remaining - step) / (run_length * cell_px))
		if remaining - step <= 0.01:
			_arrive()
	else:
		position = world_at(s)
		if not inside and not ridden:
			_listen_for_calls()
	foes = _about()
	# At a station, the ride is over once its wraiths are put down (or it has held long enough).
	if ridden and not running and at_station >= 0:
		held += delta
		if foes.is_empty() or held >= HOLD_MOST:
			ridden = false
	var shut_in: bool = ridden and (running or at_station < 0 or not foes.is_empty())
	if shut_in != sealed:
		sealed = shut_in
		_set_walls()
	for k: int in range(2):
		shut[k] = move_toward(shut[k], 1.0 if side_shut[k] else 0.0, delta / SHUT_TIME)
	_lever.available = inside


## At the station it ran to: it stands there, the lever set to carry on the same way.
func _arrive() -> void:
	running = false
	speed = 0.0
	at_station = bound_for
	s = stops_s[at_station]
	position = world_at(s)
	next_dir = dir
	held = 0.0
	_set_walls()


## Standing empty: the wizard on the landing of an open station it is not at calls it there.
func _listen_for_calls() -> void:
	var player: Player = map_info.player
	if player == null or not is_instance_valid(player) or not player.is_on_floor():
		return
	for i: int in range(stations.size()):
		if i == at_station or not is_open(i):
			continue
		var landing: Vector2 = stations[i] + Vector2(float(inner[i]) * cell_px * 1.5, 0.0)
		if player.global_position.distance_to(landing) < CALL_NEAR:
			_call_to(i)
			return


## Call up the wraiths due between `from` and `to` of the way along this run: the k-th of foe_count
## at (k + 1) / (foe_count + 1) of the way, from alternate sides.
func _call_foes(from: float, to: float) -> void:
	for k: int in range(foe_count):
		var due: float = float(k + 1) / float(foe_count + 1)
		if from < due and to >= due:
			_call_foe(first_side * (1.0 if k % 2 == 0 else -1.0))


## One wraith, out of the cliff to `side` of the car and ahead of it on its way.
func _call_foe(side: float) -> void:
	var on: Vector2 = world_at(s + float(dir) * 0.5) - world_at(s)
	var way: Vector2 = on.normalized() if on.length() > 0.01 else Vector2.UP
	var spot: Vector2 = center() + way * FOE_AHEAD + way.orthogonal() * side * FOE_OUT
	var foe: Node2D = Placeables.scene(LevelGen.Type.WRAITH).instantiate() as Node2D
	LevelLoader.arm(foe, depth)
	map_info.map_elements.add_child(foe)
	foe.global_position = spot
	foes.append(foe)
	RisoFx.burst(&"impact", spot, -way.orthogonal() * side, [RisoPrint.PINK, RisoPrint.NIGHT])
