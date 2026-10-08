class_name Gondola
extends AnimatableBody2D
## A gondola, in crag levels (CragsArchetype.lay_circuit, shut_stations): a cable car climbing a line
## of stations from near the bottom of the level to near its top, straight up and up 45° diagonals
## between them, two cells wide and two high, with a floor, a roof and two sides that come down
## while it runs. Each station is a doorway onto a landing into the level,
## where the car stands on an upright run of its track. One is open from the first;
## each of the others is shut by a gate across its doorway (a door, a switch gate or a toll gate,
## its record kept as any gate's) until opened.
##
## The car runs from station to station, stopping at each, and runs a stretch between two stations
## only if at least one of them is open: from an open station to a shut one and back, never from
## one shut station to the next. A lever inside works it (interact while in the car): pulled while
## it stands, it sets off (on the way it was going when it last came to a station, or back the
## other way after it was stopped on the way); pulled while it runs, it stops it where it is. A
## stretch it may not run makes the lever balk (a pink spark), and the next pull tries the other way.
## Standing on the landing of an open station it is not at calls it over, empty, if every stretch on
## the way has an open end.
##
## Its sides come down while it runs (pink with a rider: danger) and always lift when it stands, at
## a station or between them, so a rider can always step off where it stops. Halfway along each
## stretch a rider rides it calls a rock-bug (RockBug) out onto its track ahead of the car, which
## walks along the cable to meet it, climbs in and walks its floor; the bug can be stunned off, or
## let off when the car stands with its sides up. Faint grey bars stand across its back wall, behind
## whoever rides. Riders are carried as on any moving body. Nothing about where it is
## is kept: on every visit it waits at its open station. Nothing here draws from the world RNG.

const INTERACTABLE: PackedScene = preload("res://prefabs/interactable.tscn")
## How fast it runs with a rider, and called empty (pixels a second), and how quickly it gets up to
## speed and slows for a station (pixels a second, each second).
const RIDE_SPEED: float = 360.0
const CALL_SPEED: float = 560.0
const ACCEL: float = 520.0
## How long its bars take to come down or lift.
const SHUT_TIME: float = 0.35
## How far ahead of the car along its track a rock-bug comes out (cells), and how far through the
## stretch.
const FOE_AHEAD: float = 4.0
const FOE_DUE: float = 0.5
## How near a station's landing the wizard stands to call it there (pixels).
const CALL_NEAR: float = 330.0
## How thick its floor, roof and sides are (pixels).
const SLAB: float = 14.0
## What shuts a station: a gate of one of these in its doorway, not yet opened.
const GATES: Array[LevelGen.Type] = [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.TOLL]

var map_info: MapInfo
var depth: int = 0
## A cell's size in pixels, and the middle of the level's first cell.
var cell_px: float = 128.0
var origin: Vector2 = Vector2.ZERO
## Its track (the car's floor cell a cell at a time, CragsArchetype.lay_circuit), and its stations:
## the car's floor cell at each, how far along the track each is (cells), each one's doorway, the way
## each faces into the level (+1 right, -1 left), and the car's floor at each in world pixels.
var path: Array[Vector2i] = []
var stops: Array[Vector2i] = []
var stops_s: Array[float] = []
var gates: Array[Vector2i] = []
var inner: Array[int] = []
var stations: Array[Vector2] = []
## Where it is (cells along the track), the station it stands at (-1 between stations), the way it
## runs or last ran (+1 up the line, -1 down), and the way the lever sets it off next.
var s: float = 0.0
var at_station: int = 0
var dir: int = 1
var next_dir: int = 1
## Whether it is running, how fast, to where (cells along) and which station, the
## run's length (cells) and its top speed; and whether the run carries a rider (who is barred in,
## and for whom it calls up rock-bugs).
var running: bool = false
var speed: float = 0.0
var target_s: float = 0.0
var bound_for: int = -1
var run_length: float = 1.0
var top_speed: float = RIDE_SPEED
var ridden: bool = false
## How far through its run it is (0..1), for when its rock-bugs come out.
var run_progress: float = 0.0
## Whether its rider is shut in (it runs with one); whether its left and right sides are down, and
## how far their bars are down (0 up, 1 down), for the art.
var sealed: bool = false
var side_shut: Array[bool] = [true, true]
var shut: Array[float] = [1.0, 1.0]
## The rock-bugs it has called out.
var foes: Array[Node2D] = []
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
	path = c["path"]
	gates = c["gates"]
	inner = c["inner"]
	for i: int in c["stops"]:
		stops.append(path[i])
		stops_s.append(float(i))
		stations.append(world_at(float(i)))
	at_station = int(c["start"])
	s = stops_s[at_station]
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


## The car's floor (its bottom middle) in world pixels, `along` cells along its track.
func world_at(along: float) -> Vector2:
	return origin + CragsArchetype.point(path, along) * cell_px + Vector2(cell_px * 0.5, cell_px * 0.5)


## The middle of the car, in world pixels.
func center() -> Vector2:
	return global_position + Vector2(0.0, -cell_px)


## Whether the wizard is in the car.
func has_rider() -> bool:
	var player: Player = map_info.player if map_info != null else null
	return player != null and is_instance_valid(player) and _inside != null and _inside.overlaps_body(player)


## Whether station `i` is open: no gate in its doorway, or its gate opened (a switch gate: up).
func is_open(i: int) -> bool:
	var g: Vector2i = gates[i]
	var type: LevelGen.Type = map_info.world.get_cell(g).type
	if type == LevelGen.Type.SWITCH_GATE:
		return map_info.gate_open(g)
	return not type in GATES or map_info.record().opened.has(g)


## The next station on from `from` (cells round), the way `way` runs, and how far that is (cells):
## [station, cells], or [-1, INF] if there is none.
func next_station(from: float, way: int) -> Array:
	var best: int = -1
	var gap: float = INF
	for i: int in range(stops_s.size()):
		var d: float = (stops_s[i] - from) * float(way)
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
		ridden = false
		sealed = false
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
		if absf(s - stops_s[i]) < 0.01:
			return i
	return -1


## Run `cells` along the way `way` runs, to station `to`; `with_rider` bars it and calls up rock-bugs.
func _set_off(way: int, to: int, cells: float, with_rider: bool) -> void:
	dir = way
	bound_for = to
	target_s = s + float(way) * cells
	run_length = maxf(cells, 0.001)
	ridden = with_rider
	top_speed = RIDE_SPEED if ridden else CALL_SPEED
	running = true
	run_progress = 0.0
	at_station = -1
	sealed = ridden
	_set_walls()


## Called from the landing of open station `to`: it comes, if every stretch on the way has an open
## end.
func _call_to(to: int) -> void:
	var cells: float = absf(stops_s[to] - s)
	if cells <= 0.001:
		return
	var way: int = 1 if stops_s[to] > s else -1
	var from: int = at_station
	var here: float = s
	while absf(stops_s[to] - here) > 0.001:
		var next: int = int(next_station(here, way)[0])
		if next < 0 or (from >= 0 and not is_open(from) and not is_open(next)):
			return
		from = next
		here = stops_s[next]
	_set_off(way, to, cells, false)


## Its sides: both down while it runs, both up while it stands.
func _set_walls() -> void:
	var down: bool = running
	for k: int in range(2):
		side_shut[k] = down
		_walls[k].set_deferred(&"disabled", not down)


func _physics_process(delta: float) -> void:
	if stations.is_empty():
		return
	var inside: bool = has_rider()
	if running:
		var remaining: float = absf(target_s - s) * cell_px
		speed = move_toward(speed, minf(top_speed, sqrt(2.0 * ACCEL * remaining) + 20.0), ACCEL * delta)
		var step: float = minf(remaining, speed * delta)
		# A diagonal step is longer than a cell: the same speed covers less of the track there.
		var i: int = clampi(floori(s) if dir > 0 else ceili(s) - 1, 0, path.size() - 2)
		var stretch: float = Vector2(path[i + 1] - path[i]).length()
		s += float(dir) * step / (cell_px * stretch)
		if step >= remaining or (target_s - s) * float(dir) < 0.0:
			s = target_s
		position = world_at(s)
		if ridden:
			var now: float = 1.0 - absf(target_s - s) / run_length
			if run_progress < FOE_DUE and now >= FOE_DUE:
				_call_foe()
			run_progress = now
		if absf(target_s - s) <= 0.0001:
			_arrive()
	else:
		position = world_at(s)
		if not inside and not ridden:
			_listen_for_calls()
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
	ridden = false
	sealed = false
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


## One rock-bug, out onto the track FOE_AHEAD cells ahead of the car (behind it, near the end of the
## track), to crawl along the cable and climb on.
func _call_foe() -> void:
	var last: float = float(path.size() - 1)
	var at: float = s + float(dir) * FOE_AHEAD
	if at < 0.0 or at > last:
		at = clampf(s - float(dir) * FOE_AHEAD, 0.0, last)
	var foe: Node2D = Placeables.scene(LevelGen.Type.BUG).instantiate() as Node2D
	LevelLoader.arm(foe, depth)
	map_info.map_elements.add_child(foe)
	(foe.get_node("RockBug") as RockBug).ride_track(self, at)
	foes.append(foe)
	RisoFx.burst(&"impact", foe.global_position, Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
