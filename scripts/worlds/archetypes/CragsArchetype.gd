class_name CragsArchetype
extends Archetype
## The crags: the first band up from the garden (docs/REGIONS_PLAN.md §7), tall cliffs with castle
## ruins on them, printed in a realm of their own (pale stone at dawn) with their own decor. The
## terrain is collapsed unturned from wfc_images/crags.png (drawn by tests/make_crags_sample.gd),
## taller than wide (SCALE); then a structure pass (shape) cuts shafts up the cliff, zigzagged with
## ledges, and builds castle ruins on it: keeps (two halls one over the other, doorways through
## their walls, a walkable roof) and squat towers standing on its floors, their stone kept as
## masonry (LevelGen.masonry) for the decor. Its gates are the keeps' and passages' doors and
## switch gates, and the climb itself. Its own thing is the gondola (cut_gates, Gondola): a cable
## car up the cliff, which shuts its bars on whoever rides it and calls up the castle's wraiths
## until they are put down.

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

## Gondolas per 1000 cells (at least one): each climbs GONDOLA_RISE rows (from, to) from its lower
## station to its upper one, and leans at most GONDOLA_LEAN cells across for each row it climbs
## (so it is steep). The car is two cells wide and two high, with a row for its hanger above.
const GONDOLAS_PER_K: float = 0.3
const GONDOLA_RISE: Vector2i = Vector2i(9, 16)
const GONDOLA_LEAN: float = 0.5
## How many places for its lower station a gondola is sought among before giving up.
const GONDOLA_TRIES: int = 40


func _init() -> void:
	name = &"crags"
	decor = &"crags"
	sample = SAMPLE
	symmetry = 1
	scale = SCALE


## Cut shafts up the cliff and build the castle ruins on it (see the class description).
func shape(w: LevelGen) -> void:
	var shafts: Dictionary = cut_shafts(w)
	build_keeps(w, shafts)
	build_towers(w, shafts)


## The gondolas, once the caves are joined: each line carved clear and kept clear of everything laid
## after (see add_gondola).
func cut_gates(w: LevelGen) -> void:
	for i: int in range(w.per_area(GONDOLAS_PER_K)):
		add_gondola(w)


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


# ------------------------------------------------------------------ gondolas

## A gondola: its lower station on a floor two cells wide, its upper one GONDOLA_RISE rows up and
## leaning at most GONDOLA_LEAN across a row (both inside the level, clear of its walls). The line
## between is carved clear for the car (two cells wide, two high, a row for its hanger), each
## station gets rock under it and the cells beside it to step in from, and the car's cells along the
## line, and those beside each station, are kept clear (LevelGen.keep_clear, out of `empties`) of
## everything laid after. The car
## waits at the lower station, which holds the gondola, with its upper station's cell. Whether one
## was laid comes back.
static func add_gondola(w: LevelGen) -> bool:
	var free: Dictionary = {}
	for e: Vector2i in w.empties:
		free[e] = true
	var floors: Array[Vector2i] = []
	for x: int in range(2, w.size.x - 3):
		for y: int in range(GONDOLA_RISE.x + 4, w.size.y - 2):
			var v: Vector2i = Vector2i(x, y)
			if free.has(v) and free.has(v + Vector2i.RIGHT) and w.is_ground(v + Vector2i.DOWN) and w.is_ground(v + Vector2i(1, 1)) and not w.keep_clear.has(v):
				floors.append(v)
	for attempt: int in range(GONDOLA_TRIES):
		if floors.is_empty():
			return false
		var a: Vector2i = w.pop_pick(floors)
		var rise: int = w.rng.randi_range(GONDOLA_RISE.x, mini(GONDOLA_RISE.y, a.y - 4))
		var lean: int = int(float(rise) * GONDOLA_LEAN)
		var b: Vector2i = Vector2i(clampi(a.x + w.rng.randi_range(-lean, lean), 2, w.size.x - 4), a.y - rise)
		if b.y < 4:
			continue
		var line: Array[Vector2i] = line_cells(a, b)
		if line.any(func(c: Vector2i) -> bool: return w.keep_clear.has(c) or (w.get_cell(c).type != LevelGen.Type.EMPTY and w.get_cell(c).type != LevelGen.Type.GROUND)):
			continue
		var stepping: Array[Vector2i] = []
		for station: Vector2i in [a, b]:
			for dx: int in range(-1, 3):
				_rock_at(w, station + Vector2i(dx, 1))
				for dy: int in range(0, 3):
					_open_at(w, station + Vector2i(dx, -dy))
					if dx == -1 or dx == 2:
						stepping.append(station + Vector2i(dx, -dy))
		# The cells beside each station stay clear too, to step in from.
		line.append_array(stepping.filter(func(c: Vector2i) -> bool: return _inner(w, c)))
		for c: Vector2i in line:
			_open_at(w, c)
			w.empties.erase(c)
			w.keep_clear[c] = true
		w.put(a, LevelGen.Type.GONDOLA, b)
		return true
	return false


## The cells the car takes on its way from `a` to `b` (its lower left cells), with the cell over it
## and the row above for its hanger, a step at a time.
static func line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	for i: int in range(steps + 1):
		var p: Vector2 = Vector2(a).lerp(Vector2(b), float(i) / float(steps))
		var at: Vector2i = Vector2i(roundi(p.x), roundi(p.y))
		for dx: int in range(2):
			for dy: int in range(3):
				var c: Vector2i = at + Vector2i(dx, -dy)
				if not out.has(c):
					out.append(c)
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
