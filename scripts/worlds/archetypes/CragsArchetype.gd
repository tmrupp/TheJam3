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
## (cut_gates, populate, Gondola): a cable car climbing a line of stations from near the bottom of
## the level to near its top, in steps along rows and columns, all but one station shut behind a
## door, a switch gate or a toll gate. Rock-bugs (RockBug) crawl along its rock (place_bugs).

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

## The gondola's line: STATIONS_MIN or more stations from near the bottom of the level to near its
## top, about STATION_GAP rows apart (give or take STATION_JITTER; closer in a short level), each
## anywhere across the level, the track climbing from each to the next. The car is two cells wide and
## two high, with a row for its hanger over it, and runs straight up and up 45° diagonals only: it
## leaves a station straight up for LEAVE rows, climbs toward the next up a diagonal (a cell across
## and a row up a step), and comes straight up into the next station for the last ARRIVE rows or
## more. Each station is placed within a diagonal's reach of the one under it, so the track never
## runs flat or in steps. So at a station it always stands on an upright run with its sides to the
## level, and the climb between never touches a station's doorway or landing. Each station is a doorway a cell
## high from the car onto a landing on the side nearer the middle of the level, carved into it until
## it meets open air (at most LANDING_REACH cells).
const STATION_GAP: int = 13
const STATIONS_MIN: int = 4
const STATION_JITTER: int = 2
const LEAVE: int = 3
const ARRIVE: int = 4
const LANDING_REACH: int = 8
## Rock-bugs on the rock, per 1000 cells, and how far from the way in and from one another (cells).
const BUGS_PER_K: float = 0.6
const BUG_CLEAR: int = 8
const BUG_APART: int = 5

## What shuts a station (all but the one nearest the way in): a toll gate (TOLL_SHARE), a switch
## gate with its switch out in the level (SWITCH_SHARE), else a door in a dealt key colour. A switch
## is near its gate (LevelGen.switch_floor), somewhere reached from the way in with it shut.
const TOLL_SHARE: float = 0.3
const SWITCH_SHARE: float = 0.3


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


## The gondola's line, once the caves are joined: its track and its stations' landings, carved and
## kept clear of everything laid after (lay_circuit).
func cut_gates(w: LevelGen) -> void:
	lay_circuit(w)


## Its rock-bugs (place_bugs), then, last, what shuts each station but one, and the gondola itself
## (shut_stations).
func populate(w: LevelGen, def: NextWorldDef) -> void:
	place_bugs(w)
	shut_stations(w, def)


## Rock-bugs (RockBug): BUGS_PER_K, each in open air against rock (under it, or beside or over it),
## at least BUG_CLEAR cells from the way in and BUG_APART from one another.
static func place_bugs(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var spots: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.EMPTY and LevelGen.dist(v, start) >= BUG_CLEAR \
			and [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP].any(func(d: Vector2i) -> bool: return w.is_ground(v + d)))
	w.put_each(w.pick_apart(spots, w.per_area(BUGS_PER_K), BUG_APART), LevelGen.Type.BUG)


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

## Lay the gondola's line (see STATION_GAP) and carve it: the car's cells all along it, and every
## station's doorway, kept out of `empties` and in LevelGen.keep_clear; then note it in
## LevelGen.circuit: {"path": the car's floor cell (the left of its two) a cell at a time from the
## first station to the last, "stops": where along the path each station is (an index into it),
## "gates": each station's doorway cell, "inner": the way each faces into the level (+1 right, -1
## left)}. A level too short for one gets none.
static func lay_circuit(w: LevelGen) -> void:
	var top: int = 4 + LEAVE
	var bottom: int = w.size.y - 3
	var rows: int = bottom - top
	@warning_ignore("integer_division")
	var gap: int = mini(STATION_GAP, rows / (STATIONS_MIN - 1))
	if gap < LEAVE + ARRIVE + 1:
		return
	var points: Array[Vector2i] = []
	var y: int = bottom
	while y >= top:
		var row: int = clampi(y + w.rng.randi_range(-STATION_JITTER, STATION_JITTER), top, bottom)
		if not points.is_empty() and points[-1].y - row < LEAVE + ARRIVE + 1:
			row = points[-1].y - LEAVE - ARRIVE - 1
		if row < top:
			break
		# Across, no further from the station under it than a diagonal reaches.
		var lo: int = 3
		var hi: int = w.size.x - 5
		if not points.is_empty():
			var reach: int = points[-1].y - row - LEAVE - ARRIVE
			lo = maxi(lo, points[-1].x - reach)
			hi = mini(hi, points[-1].x + reach)
		points.append(Vector2i(w.rng.randi_range(lo, hi), row))
		y -= gap
	if points.size() < STATIONS_MIN:
		return
	var path: Array[Vector2i] = [points[0]]
	var stops: Array[int] = [0]
	for i: int in range(1, points.size()):
		path.append_array(leg(points[i - 1], points[i]))
		stops.append(path.size() - 1)
	for i: int in range(path.size()):
		for c: Vector2i in swept_cells(path[i], path[mini(i + 1, path.size() - 1)]):
			_open_at(w, c)
			w.empties.erase(c)
			w.keep_clear[c] = true
	var gates: Array[Vector2i] = []
	var inners: Array[int] = []
	for p: Vector2i in points:
		var inner: int = 1 if 2 * (p.x + 1) < w.size.x else -1
		var gate: Vector2i = p + Vector2i(2 if inner > 0 else -1, 0)
		_landing(w, gate, inner)
		gates.append(gate)
		inners.append(inner)
	w.circuit = {"path": path, "stops": stops, "gates": gates, "inner": inners}


## The car's floor cells from station `a` up to station `b` (not `a` itself), a step at a time: up
## LEAVE rows, up a diagonal toward `b` until straight under it, then straight up into it (`b` is
## within a diagonal's reach, see lay_circuit).
static func leg(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at: Vector2i = a
	var across: int = signi(b.x - a.x)
	for k: int in range(LEAVE):
		at += Vector2i.UP
		out.append(at)
	while at.x != b.x and at.y - 1 >= b.y + ARRIVE:
		at += Vector2i(across, -1)
		out.append(at)
	while at.y > b.y:
		at += Vector2i.UP
		out.append(at)
	return out


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
			var lever: Variant = w.switch_floor(w.reach_from(start, func(n: Vector2i) -> bool: return n != gate), gate)
			if lever != null:
				w.put(gate, LevelGen.Type.SWITCH_GATE, lever)
				w.put(lever, LevelGen.Type.SWITCH, gate)
				continue
		w.put(gate, LevelGen.Type.DOOR)
	var info: Dictionary = w.circuit.duplicate()
	info["start"] = open
	var path: Array[Vector2i] = w.circuit["path"]
	w.put(path[(w.circuit["stops"] as Array[int])[open]], LevelGen.Type.GONDOLA, info)


## The car's floor (as a point, in cells) `s` cells along `path` (clamped to its ends).
static func point(path: Array[Vector2i], s: float) -> Vector2:
	var u: float = clampf(s, 0.0, float(path.size() - 1))
	var i: int = mini(floori(u), path.size() - 2)
	if path.size() < 2:
		return Vector2(path[0])
	return Vector2(path[i]).lerp(Vector2(path[i + 1]), u - float(i))


## Where `path` turns (indexes into it), its ends included.
static func turns(path: Array[Vector2i]) -> Array[int]:
	var out: Array[int] = [0]
	for i: int in range(1, path.size() - 1):
		if path[i] - path[i - 1] != path[i + 1] - path[i]:
			out.append(i)
	out.append(path.size() - 1)
	return out


## The cells the car sweeps going from floor cell `a` to the next, `b` (a step along a row, a column
## or a diagonal): every cell of the box round where it is at both.
static func swept_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 2):
		for y: int in range(mini(a.y, b.y) - 2, maxi(a.y, b.y) + 1):
			out.append(Vector2i(x, y))
	return out


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
