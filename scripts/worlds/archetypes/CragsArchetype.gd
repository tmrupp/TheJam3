class_name CragsArchetype
extends Archetype
## The crags: the first band up from the garden (docs/REGIONS_PLAN.md §7), tall cliffs with castle
## ruins on them, printed in a realm of their own (pale stone at dawn) with their own decor. The
## terrain is collapsed unturned from wfc_images/crags.png (drawn by tests/make_crags_sample.gd),
## taller than wide (SCALE); then a structure pass (shape) opens caverns of air in the cliff, cuts
## shafts up it, zigzagged with ledges, and builds castle ruins on it: keeps (two halls one over
## the other, doorways through their walls, a walkable roof) and squat towers standing on its
## floors, their stone kept as masonry (LevelGen.masonry) for the decor. Its gates are the keeps'
## and passages' doors and switch gates, and the climb itself. Its own thing is the gondola
## (cut_gates, populate, Gondola): a cable car running a circuit round the level, its stations on
## the circuit's two sides, all but one shut behind a door, a switch gate or a toll gate.

const SAMPLE: String = "res://wfc_images/crags.png"
## A crag level is this much the size of a cave level of its depth (Rules.level_size), across and
## down: narrower and much taller, a cliff to climb.
const SCALE: Vector2 = Vector2(0.8, 1.6)

## Shafts: one for every SHAFT_EVERY cells across (at least one), SHAFT_WIDE cells of open air
## between walls a cell thick, from near the bottom of the level to near its top. Each wanders a
## cell left or right every SHAFT_WANDER rows (from, to). Its walls stand in runs of WALL_RUN rows
## (from, to) with a gap of two rows between, where it opens on the cliff beside it. A ledge LEDGE
## cells long juts from one wall and then the other every LEDGE_EVERY rows, so a shaft is climbed
## in a zigzag (a relic's hop, or wall jumps).
const SHAFT_EVERY: int = 16
const SHAFT_WIDE: int = 4
const SHAFT_WANDER: Vector2i = Vector2i(5, 8)
const WALL_RUN: Vector2i = Vector2i(3, 7)
const LEDGE: int = 2
const LEDGE_EVERY: int = 3

## Keeps per 1000 cells (at least one), how wide one is (from, to), and the cells kept clear between
## a keep and a shaft or another keep. A keep is KEEP_TALL rows: a roof, a hall two rows high, a
## floor (with a stair gap two cells wide near one end), another hall, and a base.
const KEEPS_PER_K: float = 0.8
const KEEP_WIDE: Vector2i = Vector2i(8, 12)
const KEEP_TALL: int = 7
const KEEP_APART: int = 2
## Rows of open air kept over a keep's roof, so it can be walked along.
const ROOF_AIR: int = 2

## Towers per 1000 cells: blocks of masonry TOWER_WIDE cells across (from, to) and TOWER_TALL rows
## high (from, to), standing on a floor with that much open air over it and a row more.
const TOWERS_PER_K: float = 1.2
const TOWER_WIDE: Vector2i = Vector2i(2, 4)
const TOWER_TALL: Vector2i = Vector2i(3, 5)

## Caverns: CAVERNS_PER_K (at least one) ellipses of open air carved through the cliff, CAVERN_RX
## cells across from their middle and CAVERN_RY down (from, to), so it is not all rock.
const CAVERNS_PER_K: float = 1.4
const CAVERN_RX: Vector2i = Vector2i(3, 6)
const CAVERN_RY: Vector2i = Vector2i(3, 7)

## The gondola's circuit: a rectangle CIRCUIT_SIDE cells in from the level's left and right edges,
## CIRCUIT_TOP from its top and CIRCUIT_BOTTOM from its bottom (the car's floor row). The car is two
## cells wide and two high, with a row for its hanger over it, and the corridor it runs in is carved
## clear all the way round. Its stations stand on the circuit's two sides (the car's open sides face
## into the level only there), about STATION_GAP rows apart (give or take STATION_JITTER), at least
## STATIONS_MIN in all (closer together where the level is short), each a
## doorway a cell high from the car onto a landing carved into the level until it meets open air
## (at most LANDING_REACH cells).
const CIRCUIT_SIDE: int = 3
const CIRCUIT_TOP: int = 4
const CIRCUIT_BOTTOM: int = 3
const STATION_GAP: int = 14
const STATIONS_MIN: int = 4
const STATION_JITTER: int = 2
const LANDING_REACH: int = 8
## What shuts a station (all but the one nearest the way in): a toll gate (TOLL_SHARE), a switch
## gate with its switch out in the level (SWITCH_SHARE), else a door in a dealt key colour. A switch
## is at least SWITCH_REACH cells from its gate, somewhere reached from the way in with it shut.
const TOLL_SHARE: float = 0.3
const SWITCH_SHARE: float = 0.3
const SWITCH_REACH: int = 8


func _init() -> void:
	name = &"crags"
	decor = &"crags"
	sample = SAMPLE
	symmetry = 1
	scale = SCALE


## Open caverns in the cliff, cut shafts up it and build the castle ruins on it (see the class
## description).
func shape(w: LevelGen) -> void:
	open_caverns(w)
	var shafts: Dictionary = cut_shafts(w)
	build_keeps(w, shafts)
	build_towers(w, shafts)


## The gondola's circuit, once the caves are joined: its corridor and its stations' landings,
## carved and kept clear of everything laid after (lay_circuit).
func cut_gates(w: LevelGen) -> void:
	lay_circuit(w)


## Last: what shuts each station but one, and the gondola itself (shut_stations).
func populate(w: LevelGen, def: NextWorldDef) -> void:
	shut_stations(w, def)


# ------------------------------------------------------------------ caverns

## Carve the caverns (see CAVERNS_PER_K), anywhere in the level.
static func open_caverns(w: LevelGen) -> void:
	for i: int in range(w.per_area(CAVERNS_PER_K)):
		var r: Vector2i = Vector2i(w.rng.randi_range(CAVERN_RX.x, CAVERN_RX.y), w.rng.randi_range(CAVERN_RY.x, CAVERN_RY.y))
		var c: Vector2i = Vector2i(w.rng.randi_range(2, w.size.x - 3), w.rng.randi_range(2, w.size.y - 3))
		for x: int in range(c.x - r.x, c.x + r.x + 1):
			for y: int in range(c.y - r.y, c.y + r.y + 1):
				var d: Vector2 = Vector2(float(x - c.x) / float(r.x), float(y - c.y) / float(r.y))
				if d.length_squared() <= 1.0:
					_open_at(w, Vector2i(x, y))


# ------------------------------------------------------------------ shafts

## Cut the level's shafts (see SHAFT_EVERY), and return the cells they take (walls included), so
## nothing built after stands in them.
static func cut_shafts(w: LevelGen) -> Dictionary:
	var taken: Dictionary = {}
	@warning_ignore("integer_division")
	var n: int = maxi(1, (w.size.x + 6) / SHAFT_EVERY)
	for i: int in range(n):
		var cx: int = clampi(int((float(i) + 0.5) * float(w.size.x) / float(n)) + w.rng.randi_range(-2, 2), 4, w.size.x - 5)
		var wander: int = w.rng.randi_range(SHAFT_WANDER.x, SHAFT_WANDER.y)
		var wall: int = w.rng.randi_range(WALL_RUN.x, WALL_RUN.y)
		var left: bool = w.rng.randf() < 0.5
		var bottom: int = w.size.y - 3
		for y: int in range(bottom, 1, -1):
			wander -= 1
			if wander <= 0:
				cx = clampi(cx + w.rng.randi_range(-1, 1), 4, w.size.x - 5)
				wander = w.rng.randi_range(SHAFT_WANDER.x, SHAFT_WANDER.y)
			@warning_ignore("integer_division")
			var x0: int = cx - SHAFT_WIDE / 2
			var x1: int = x0 + SHAFT_WIDE - 1
			for x: int in range(x0, x1 + 1):
				_open_at(w, Vector2i(x, y))
				taken[Vector2i(x, y)] = true
			# Its walls, in runs with a gap of two rows between.
			wall -= 1
			var solid: bool = wall >= 0
			if wall <= -2:
				wall = w.rng.randi_range(WALL_RUN.x, WALL_RUN.y)
			for x: int in [x0 - 1, x1 + 1]:
				if solid:
					_rock_at(w, Vector2i(x, y))
				else:
					_open_at(w, Vector2i(x, y))
				taken[Vector2i(x, y)] = true
			# A ledge from one wall, then the other.
			if (bottom - y) % LEDGE_EVERY == LEDGE_EVERY - 1 and y < bottom - 1:
				for k: int in range(LEDGE):
					_rock_at(w, Vector2i(x0 + k if left else x1 - k, y))
				left = not left
	return taken


# ------------------------------------------------------------------ castle ruins

## Build keeps (KEEPS_PER_K) where they fit clear of the shafts and of each other (see the class
## description), their stone kept as masonry.
static func build_keeps(w: LevelGen, shafts: Dictionary) -> void:
	var keeps: Array[Rect2i] = []
	var want: int = w.per_area(KEEPS_PER_K)
	for attempt: int in range(want * 30):
		if keeps.size() >= want:
			break
		var wide: int = w.rng.randi_range(KEEP_WIDE.x, KEEP_WIDE.y)
		var at: Vector2i = Vector2i(w.rng.randi_range(2, w.size.x - wide - 3), w.rng.randi_range(ROOF_AIR + 2, w.size.y - KEEP_TALL - 3))
		var box: Rect2i = Rect2i(at, Vector2i(wide, KEEP_TALL))
		var room: Rect2i = box.grow_individual(KEEP_APART, KEEP_APART + ROOF_AIR, KEEP_APART, 0)
		if keeps.any(func(k: Rect2i) -> bool: return room.intersects(k)) or _crosses(room, shafts):
			continue
		keeps.append(box)
		_keep(w, box, w.rng.randf() < 0.5)


## A keep in `box`: masonry all round two halls (rows 1-2 and 4-5 of it), doorways through both its
## walls at each hall's floor, a stair gap in the floor between them (near the left end, or the
## right if `stair_right`), open air over its roof and beside its doorways.
static func _keep(w: LevelGen, box: Rect2i, stair_right: bool) -> void:
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			_rock_at(w, Vector2i(x, y))
			w.masonry[Vector2i(x, y)] = true
		for d: int in range(1, ROOF_AIR + 1):
			_open_at(w, Vector2i(x, box.position.y - d))
	for top: int in [box.position.y + 1, box.position.y + 4]:
		for x: int in range(box.position.x + 1, box.end.x - 1):
			for y: int in [top, top + 1]:
				_unbuild(w, Vector2i(x, y))
		# A doorway through each wall at the hall's floor, with air outside it.
		for x: int in [box.position.x, box.end.x - 1]:
			_unbuild(w, Vector2i(x, top + 1))
		for x: int in [box.position.x - 1, box.end.x]:
			_open_at(w, Vector2i(x, top))
			_open_at(w, Vector2i(x, top + 1))
	var gap: int = box.end.x - 4 if stair_right else box.position.x + 2
	for x: int in [gap, gap + 1]:
		_unbuild(w, Vector2i(x, box.position.y + 3))


## Build towers (TOWERS_PER_K) on floors with room over them, clear of the shafts.
static func build_towers(w: LevelGen, shafts: Dictionary) -> void:
	var floors: Array[Vector2i] = []
	for x: int in range(2, w.size.x - 2):
		for y: int in range(TOWER_TALL.y + 3, w.size.y - 2):
			var v: Vector2i = Vector2i(x, y)
			if w.get_cell(v).type == LevelGen.Type.EMPTY and w.is_ground(v + Vector2i.DOWN) and not w.masonry.has(v + Vector2i.DOWN):
				floors.append(v)
	var built: int = 0
	var want: int = w.per_area(TOWERS_PER_K)
	for attempt: int in range(want * 20):
		if built >= want or floors.is_empty():
			break
		var at: Vector2i = w.pick(floors)
		var wide: int = w.rng.randi_range(TOWER_WIDE.x, TOWER_WIDE.y)
		var tall: int = w.rng.randi_range(TOWER_TALL.x, TOWER_TALL.y)
		var box: Rect2i = Rect2i(at.x, at.y - tall + 1, wide, tall)
		if box.end.x > w.size.x - 2 or _crosses(box.grow(1), shafts):
			continue
		var fits: bool = true
		for x: int in range(box.position.x, box.end.x):
			fits = fits and w.is_ground(Vector2i(x, at.y + 1))
			for y: int in range(box.position.y - 1, box.end.y):
				fits = fits and w.get_cell(Vector2i(x, y)).type == LevelGen.Type.EMPTY and not w.masonry.has(Vector2i(x, y))
		if not fits:
			continue
		for x: int in range(box.position.x, box.end.x):
			for y: int in range(box.position.y, box.end.y):
				_rock_at(w, Vector2i(x, y))
				w.masonry[Vector2i(x, y)] = true
		built += 1


## Whether `r` takes in any of `cells`.
static func _crosses(r: Rect2i, cells: Dictionary) -> bool:
	for x: int in range(r.position.x, r.end.x):
		for y: int in range(r.position.y, r.end.y):
			if cells.has(Vector2i(x, y)):
				return true
	return false


# ------------------------------------------------------------------ the gondola

## Carve the gondola's circuit (see CIRCUIT_SIDE) and its stations, keeping the corridor and every
## station's doorway out of `empties` and in LevelGen.keep_clear, and note them in
## LevelGen.circuit: {"loop": the rectangle the car's floor cell runs round (its left and top, its
## width and height in cells), "stops": the car's floor cell at each station, in order round the
## circuit, "gates": each station's doorway cell, "inner": the way each faces into the level (+1
## right, -1 left)}. A level too small for one gets none.
static func lay_circuit(w: LevelGen) -> void:
	var loop: Rect2i = Rect2i(CIRCUIT_SIDE, CIRCUIT_TOP, w.size.x - CIRCUIT_SIDE * 2 - 2, w.size.y - CIRCUIT_BOTTOM - CIRCUIT_TOP)
	if loop.size.x < 8 or loop.size.y < STATION_GAP:
		return
	for p: Vector2i in loop_cells(loop):
		for c: Vector2i in car_cells(p):
			_open_at(w, c)
			w.empties.erase(c)
			w.keep_clear[c] = true
	var stations: Array = []
	# Stations stand clear of the top and bottom stretches (whose corridor would take the rock over
	# or under a doorway): from four rows over the bottom one to three under the top one.
	var span: int = loop.size.y - 7
	@warning_ignore("integer_division")
	var gap: int = mini(STATION_GAP, maxi(4, span / maxi(1, STATIONS_MIN / 2 - 1)))
	for inner: int in [1, -1]:
		var x: int = loop.position.x if inner > 0 else loop.end.x
		var y: int = loop.end.y - 4
		while y >= loop.position.y + 3:
			var row: int = clampi(y + w.rng.randi_range(-STATION_JITTER, STATION_JITTER), loop.position.y + 3, loop.end.y - 4)
			var stop: Vector2i = Vector2i(x, row)
			var gate: Vector2i = stop + Vector2i(2 if inner > 0 else -1, 0)
			_landing(w, gate, inner)
			stations.append([along(loop, stop), stop, gate, inner])
			y -= gap
	stations.sort()
	var stops: Array[Vector2i] = []
	var gates: Array[Vector2i] = []
	var inners: Array[int] = []
	for st: Array in stations:
		stops.append(st[1])
		gates.append(st[2])
		inners.append(st[3])
	w.circuit = {"loop": loop, "stops": stops, "gates": gates, "inner": inners}


## A station's doorway at `gate` (rock over and under it, kept clear), and its landing on into the
## level the way `inner` faces: open air two rows high over rock, until it meets air that was open
## already (at most LANDING_REACH cells).
static func _landing(w: LevelGen, gate: Vector2i, inner: int) -> void:
	_rock_at(w, gate + Vector2i.UP)
	_rock_at(w, gate + Vector2i.DOWN)
	_open_at(w, gate)
	w.empties.erase(gate)
	w.keep_clear[gate] = true
	for k: int in range(1, LANDING_REACH + 1):
		var c: Vector2i = gate + Vector2i(inner * k, 0)
		if not _inner(w, c) or w.keep_clear.has(c):
			break
		var was_open: bool = w.get_cell(c).type == LevelGen.Type.EMPTY and w.get_cell(c + Vector2i.UP).type == LevelGen.Type.EMPTY
		_open_at(w, c)
		_open_at(w, c + Vector2i.UP)
		_rock_at(w, c + Vector2i.DOWN)
		if was_open and k >= 2:
			break


## Shut every station but the one nearest the way in (see TOLL_SHARE), then put the gondola, its
## car waiting at that open station, on its floor cell: its extra info is LevelGen.circuit and
## "start", the open station's number.
static func shut_stations(w: LevelGen, def: NextWorldDef) -> void:
	if w.circuit.is_empty() or not w.exits.has(MapInfo.Exit.BACK):
		return
	var start: Vector2i = w.exits[MapInfo.Exit.BACK]
	var gates: Array[Vector2i] = w.circuit["gates"]
	var open: int = 0
	for i: int in range(gates.size()):
		if LevelGen.dist(gates[i], start) < LevelGen.dist(gates[open], start):
			open = i
	for i: int in range(gates.size()):
		# The rock over and under every doorway stays whole (no cracked wall to break round a gate).
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
			if w.get_cell(gates[i] + d).type == LevelGen.Type.CRACKED:
				w._to_rock(gates[i] + d)
		if i == open:
			continue
		var gate: Vector2i = gates[i]
		var r: float = w.rng.randf()
		if r < TOLL_SHARE:
			w.put(gate, LevelGen.Type.TOLL, Rules.toll_price(def.depth))
			continue
		if r < TOLL_SHARE + SWITCH_SHARE:
			var lever: Variant = w._pick_floor_in(w.reach_from(start, func(n: Vector2i) -> bool: return n != gate), gate, SWITCH_REACH)
			if lever != null:
				w.put(gate, LevelGen.Type.SWITCH_GATE, lever)
				w.put(lever, LevelGen.Type.SWITCH, gate)
				continue
		w.put(gate, LevelGen.Type.DOOR)
	var info: Dictionary = w.circuit.duplicate()
	info["start"] = open
	w.put((w.circuit["stops"] as Array[Vector2i])[open], LevelGen.Type.GONDOLA, info)


## The car's floor cell all the way round `loop`, a cell at a time: up its left side from its
## bottom left, along its top, down its right side and back along its bottom (each corner once).
static func loop_cells(loop: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in range(perimeter(loop)):
		out.append(Vector2i(point(loop, float(i)).round()))
	return out


## How far round `loop` it is, in cells.
static func perimeter(loop: Rect2i) -> int:
	return 2 * (loop.size.x + loop.size.y)


## The car's floor cell (as a point, in cells) `s` cells round `loop` from its bottom left.
static func point(loop: Rect2i, s: float) -> Vector2:
	var w: float = float(loop.size.x)
	var h: float = float(loop.size.y)
	var u: float = fposmod(s, float(perimeter(loop)))
	var lo: Vector2 = Vector2(loop.position.x, loop.end.y)
	if u <= h:
		return lo + Vector2(0.0, -u)
	if u <= h + w:
		return Vector2(loop.position.x + (u - h), loop.position.y)
	if u <= h + w + h:
		return Vector2(loop.end.x, loop.position.y + (u - h - w))
	return Vector2(loop.end.x - (u - h - w - h), loop.end.y)


## How far round `loop` (cells from its bottom left) the floor cell `c` on it is.
static func along(loop: Rect2i, c: Vector2i) -> float:
	var w: int = loop.size.x
	var h: int = loop.size.y
	if c.x == loop.position.x and c.y > loop.position.y:
		return float(loop.end.y - c.y)
	if c.y == loop.position.y:
		return float(h + c.x - loop.position.x)
	if c.x == loop.end.x:
		return float(h + w + c.y - loop.position.y)
	return float(h + w + h + loop.end.x - c.x)


## The cells the car takes with its floor cell (the left of the two) at `p`: two across, its two
## rows and the hanger's row over them.
static func car_cells(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx: int in range(2):
		for dy: int in range(3):
			out.append(p + Vector2i(dx, -dy))
	return out


# ------------------------------------------------------------------ cells

## Rock at `v`, if inside the level, not its outer edge, and not kept clear (a gondola's line).
static func _rock_at(w: LevelGen, v: Vector2i) -> void:
	if _inner(w, v) and not w.is_ground(v) and not w.keep_clear.has(v):
		w._to_rock(v)


## Open air at `v`, if inside the level and not its outer edge.
static func _open_at(w: LevelGen, v: Vector2i) -> void:
	if _inner(w, v) and w.get_cell(v).type != LevelGen.Type.EMPTY:
		w._to_open(v)


## Open air at `v`, no longer masonry.
static func _unbuild(w: LevelGen, v: Vector2i) -> void:
	_open_at(w, v)
	w.masonry.erase(v)


static func _inner(w: LevelGen, v: Vector2i) -> bool:
	return v.x >= 1 and v.y >= 1 and v.x < w.size.x - 1 and v.y < w.size.y - 1
