class_name Gondola
extends AnimatableBody2D
## A gondola, in crag levels (CragsArchetype.add_gondola): a cable car hung from a line between two
## stations up the cliff, two cells wide and two high, with a floor, a roof and open sides. It waits
## at one station. Stand in it for BOARD_TIME and its bars come down (pink: danger), shutting the
## wizard in, and it rides the line to the other station. On the way it calls up the castle's
## wraiths (Wraith), FOES_BASE of them and one more for every FOES_DEPTH rows from the start, out of
## the cliff ahead of it and to either side; they drift through the rock at the wizard, and the bars
## stay down at the far station until every one is put down (or HOLD_MOST seconds pass there, so
## nobody is shut in for good). Then the bars lift, and the wizard has to step out before it will
## carry them again. Standing at the station it is not at calls it over, empty and unbarred.
## Riders are carried as on any moving body (sync_to_physics). Nothing about it is kept in the
## record: on every visit it waits at its lower station. Nothing here draws from the world RNG.

## How fast it rides the line with someone in it, and comes when called empty (pixels a second).
const RIDE_SPEED: float = 150.0
const CALL_SPEED: float = 300.0
## How long the wizard stands in it before the bars come down, and how long they take to drop.
const BOARD_TIME: float = 0.5
const SHUT_TIME: float = 0.35
## The wraiths it calls up on a ride: FOES_BASE, and one more for every FOES_DEPTH rows from the start.
const FOES_BASE: int = 2
const FOES_DEPTH: int = 3
## Where each comes out of the cliff: this far to the side of the car, and this far ahead of it
## along the line (pixels).
const FOE_OUT: float = 430.0
const FOE_AHEAD: float = 220.0
## The longest its bars stay down at the far station while its wraiths are about (seconds).
const HOLD_MOST: float = 12.0
## How near the wizard stands to the station it is not at to call it (pixels): beside it will do.
const CALL_NEAR: float = 240.0
## How thick its floor, roof and walls are (pixels).
const SLAB: float = 14.0
## Salt for the side its first wraith comes from, hashed with the level seed and its cell.
const SIDE_DEAL: int = 9300

enum State { WAITING, RIDING, HELD }

## The car's floor (its bottom middle) at each station, in world pixels: the lower first.
var stations: Array[Vector2] = []
## The station it is at, or rides away from.
var at: int = 0
var state: State = State.WAITING
## How far along the line this ride is (0..1), whether someone rides it (else it was called empty),
## and the ride's length in pixels.
var progress: float = 0.0
var ridden: bool = false
var length: float = 1.0
## How far its bars are down (0 up, 1 down), for the art; and whether they are meant to be down.
var shut: float = 0.0
var sealed: bool = false
## How long the wizard has stood in it, waiting; whether they have stepped out since its last ride.
var boarding: float = 0.0
var stepped_out: bool = true
## The wraiths called up on this ride, how many it calls in all, and how long it has held at the far
## station.
var foes: Array[Node2D] = []
var foe_count: int = 0
var held: float = 0.0
## A cell's size in pixels, and the side (+1 right, -1 left) its first wraith comes from.
var cell_px: float = 128.0
var first_side: float = 1.0
var map_info: MapInfo
var depth: int = 0
var _walls: Array[CollisionShape2D] = []
var _inside: Area2D


## Hang it between its lower station `v` and its upper one, `upper` (cells: each the left of the two
## cells the car stands in).
func setup(info: MapInfo, v: Vector2i, upper: Variant) -> void:
	map_info = info
	depth = info.here.depth if info.here != null else 0
	var tm: TileMap = info.tile_map
	cell_px = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	var lift: Vector2 = Vector2(cell_px * 0.5, cell_px * 0.5)
	stations = [info.cell_position(v) + lift, info.cell_position(upper as Vector2i) + lift]
	length = maxf(1.0, stations[0].distance_to(stations[1]))
	@warning_ignore("integer_division")
	foe_count = FOES_BASE + depth / FOES_DEPTH
	first_side = 1.0 if RisoDecor.h(info.world.seed_for_colors, v, SIDE_DEAL) < 0.5 else -1.0
	var wide: float = cell_px * 2.0
	var tall: float = cell_px * 2.0
	_slab(Vector2(0.0, SLAB * 0.5), Vector2(wide - 4.0, SLAB))
	_slab(Vector2(0.0, -tall + SLAB * 0.5), Vector2(wide, SLAB))
	for side: float in [-1.0, 1.0]:
		var wall: CollisionShape2D = _slab(Vector2(side * (wide - SLAB) * 0.5, -tall * 0.5), Vector2(SLAB, tall))
		wall.disabled = true
		_walls.append(wall)
	_inside = Area2D.new()
	_inside.collision_layer = 0
	_inside.collision_mask = 1
	var room: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(wide - SLAB * 2.0 - 8.0, tall - SLAB * 2.0)
	room.shape = box
	room.position = Vector2(0.0, -tall * 0.5)
	_inside.add_child(room)
	add_child(_inside)
	_place(stations[0])


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


## The middle of the car, in world pixels.
func center() -> Vector2:
	return global_position + Vector2(0.0, -cell_px)


## Whether the wizard is in the car.
func has_rider() -> bool:
	var player: Player = map_info.player if map_info != null else null
	return player != null and is_instance_valid(player) and _inside != null and _inside.overlaps_body(player)


func _physics_process(delta: float) -> void:
	if stations.size() < 2:
		return
	var player: Player = map_info.player if map_info != null else null
	var inside: bool = has_rider()
	shut = move_toward(shut, 1.0 if sealed else 0.0, delta / SHUT_TIME)
	match state:
		State.WAITING:
			# Held at its station (a synced body set from outside a physics step drifts back).
			position = stations[at]
			if not inside:
				stepped_out = true
				boarding = 0.0
				# Called from the station it is not at.
				var other: Vector2 = stations[1 - at]
				if player != null and is_instance_valid(player) and player.is_on_floor() and player.global_position.distance_to(other) < CALL_NEAR:
					_set_off(false)
			elif stepped_out and player.is_on_floor():
				boarding += delta
				if boarding >= BOARD_TIME:
					_set_off(true)
		State.RIDING:
			# Ridden, it waits for its bars to come down before it moves.
			if ridden and shut < 1.0:
				return
			var before: float = progress
			progress = minf(1.0, progress + delta * (RIDE_SPEED if ridden else CALL_SPEED) / length)
			position = stations[at].lerp(stations[1 - at], smoothstep(0.0, 1.0, progress))
			if ridden:
				_call_foes(before, progress)
			if progress >= 1.0:
				at = 1 - at
				if ridden:
					state = State.HELD
					held = 0.0
				else:
					state = State.WAITING
		State.HELD:
			position = stations[at]
			held += delta
			var about: Array[Node2D] = []
			for i: int in range(foes.size()):
				if is_instance_valid(foes[i]) and not foes[i].is_queued_for_deletion():
					about.append(foes[i])
			foes = about
			if foes.is_empty() or held >= HOLD_MOST:
				_open()


## Set off along the line: ridden, its bars come down first and it calls up its wraiths on the way.
func _set_off(with_rider: bool) -> void:
	ridden = with_rider
	progress = 0.0
	state = State.RIDING
	foes.clear()
	if ridden:
		sealed = true
		stepped_out = false
		for wall: CollisionShape2D in _walls:
			wall.set_deferred(&"disabled", false)


## Lift the bars at the end of a ride; it waits for the wizard to step out before it carries them again.
func _open() -> void:
	sealed = false
	state = State.WAITING
	boarding = 0.0
	for wall: CollisionShape2D in _walls:
		wall.set_deferred(&"disabled", true)


## Call up the wraiths due between `from` and `to` along this ride: the k-th of foe_count at
## (k + 1) / (foe_count + 1) of the way, from alternate sides.
func _call_foes(from: float, to: float) -> void:
	for k: int in range(foe_count):
		var due: float = float(k + 1) / float(foe_count + 1)
		if from < due and to >= due:
			_call_foe(first_side * (1.0 if k % 2 == 0 else -1.0))


## One wraith, out of the cliff to `side` of the car and ahead of it along the line.
func _call_foe(side: float) -> void:
	var ahead: Vector2 = (stations[1 - at] - stations[at]).normalized()
	var spot: Vector2 = center() + ahead * FOE_AHEAD + Vector2(side * FOE_OUT, 0.0)
	var foe: Node2D = Placeables.scene(LevelGen.Type.WRAITH).instantiate() as Node2D
	LevelLoader.arm(foe, depth)
	map_info.map_elements.add_child(foe)
	foe.global_position = spot
	foes.append(foe)
	RisoFx.burst(&"impact", spot, Vector2(-side, 0.0), [RisoPrint.PINK, RisoPrint.NIGHT])
