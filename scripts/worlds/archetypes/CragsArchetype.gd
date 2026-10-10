class_name CragsArchetype
extends Archetype
## The crags: the first band up from the garden (docs/REGIONS_PLAN.md §7), tall cliffs with castle
## ruins on them, printed in a realm of their own (pale stone at dawn) with their own decor. The
## terrain is collapsed unturned from wfc_images/crags.png (drawn by tests/make_crags_sample.gd),
## taller than wide (SCALE); then a structure pass (shape) opens caverns of air in the cliff, cuts
## shafts up it, zigzagged with ledges, and builds castle ruins on it: keeps (two halls one over
## the other, doorways through their walls, a walkable roof) and towers (tall and narrow, a room on
## each storey, climbed inside by stair holes with ledges under them; most come out on their roof,
## some are roofed over a hoard of stars), their stone kept as masonry (LevelGen.masonry) for the
## decor, and the air inside them as LevelGen.interiors. Its gates are the keeps'
## and passages' doors and switch gates, and the climb itself. Its own thing is the gondola
## (cut_gates, populate, Gondola): a cable car climbing a line of stations from near the bottom of
## the level to near its top, in steps along rows and columns, all but one station shut behind a
## door, a switch gate or a toll gate. Rock-bugs (RockBug) crawl along its rock (place_bugs) and
## hatch from nests out on the cliff (BugNest), stalactites (Stalactite) hang from its ceilings,
## falling on whoever passes under, and crossbows (Crossbow) built into the towers' and keeps'
## walls shoot out at the wizard, stopped only from inside (finish).

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
const KEEP_WIDE: Vector2i = Vector2i(6, 9)
const KEEP_TALL: int = 7
const KEEP_APART: int = 1
## Rows of open air kept over a keep's roof, so it can be walked along.
const ROOF_AIR: int = 2

## Towers per 1000 cells (at least one): tall, narrow buildings TOWER_WIDE cells across (from, to,
## walls included) of TOWER_STOREYS storeys (from, to), clear of the shafts (though one may stand
## right beside a shaft) and kept apart from the keeps and one another as keeps are (KEEP_APART),
## with ROOF_AIR rows of air over the roof. Each storey is a room
## two rows high over a floor of masonry (STOREY rows in all). Every floor over a room has a stair
## hole STAIR cells wide at one end, the ends taking turns up the tower, with a one-way ledge under
## the hole in the top row of the room below, so each storey is climbed in two of the wizard's own
## hops. The ground floor has a doorway through each wall, with air outside it, and the tower's
## footing goes down through open air to the rock under it (at most TOWER_FOOTING rows and never to
## the level's bottom edge, or it is built elsewhere). A watchtower's stair goes on up through a hatch in its roof onto the roof, and
## each of its upper rooms has a window a cell high in either wall with open air outside it (a
## chance of TOWER_WINDOW each). A hoard tower (TOWER_HOARD_SHARE) has no hatch and no windows, and
## TOWER_HOARD stars in its top room (place_hoards).
const TOWERS_PER_K: float = 0.7
const TOWER_WIDE: Vector2i = Vector2i(5, 6)
const TOWER_STOREYS: Vector2i = Vector2i(2, 4)
const STOREY: int = 3
const STAIR: int = 2
const TOWER_FOOTING: int = 4
const TOWER_WINDOW: float = 0.3
const TOWER_HOARD_SHARE: float = 0.35
const TOWER_HOARD: int = 3

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
## Falling stalactites, per 1000 cells: each from a ceiling of plain rock (not built stone), over at
## least STALACTITE_DROP cells of open air, at least STALACTITE_CLEAR cells from the way in and
## STALACTITE_APART from one another.
const STALACTITES_PER_K: float = 1.6
const STALACTITE_DROP: int = 3
const STALACTITE_CLEAR: int = 6
const STALACTITE_APART: int = 3
## Rock-bug nests (BugNest): NESTS_PER_K out on the cliff's floors, never in a building, at least
## NEST_CLEAR cells from the way in and NEST_APART from one another.
const NESTS_PER_K: float = 0.4
const NEST_CLEAR: int = 10
const NEST_APART: int = 8
## Crossbows built into the towers' walls (Crossbow), shooting out through arrow slits: each spot
## where one fits (see place_crossbows) holds one by a chance of CROSSBOW_SHARE, dealt by the level
## seed (CROSSBOW_DEAL, no draw), at most CROSSBOWS_MOST to a tower (more on a harder preset,
## Difficulty.foes).
const CROSSBOW_SHARE: float = 0.85
const CROSSBOW_DEAL: int = 8150
const CROSSBOWS_MOST: int = 3
## Crossbows built into the keeps' walls: each spot where one fits (see place_keep_crossbows) holds
## one by a chance of KEEP_CROSSBOW_SHARE (more on a harder preset, Difficulty.foes), dealt by the
## level seed (KEEP_CROSSBOW_DEAL, no draw), at least KEEP_CROSSBOW_APART cells from another.
const KEEP_CROSSBOW_SHARE: float = 0.4
const KEEP_CROSSBOW_DEAL: int = 8230
const KEEP_CROSSBOW_APART: int = 3
## What a watchtower's top room holds (place_tower_rewards), the towers taking turns down this list
## from a start dealt by the level seed (TOWER_DEAL, no draw): one of the level's keys, the switch of
## a switch gate no more than TOWER_SWITCH_NEAR cells from the tower, or a mending bowl (MendWell: the
## shrine's mending station, healing to full for a price). When its turn's has none to bring, it has
## a mending bowl, if its top room has a floor to stand it on. (A hoard tower's top room holds its
## stars. The mending draught, Draught, is set aside for now: nothing places it.)
const TOWER_REWARDS: Array[StringName] = [&"key", &"switch", &"well"]
const TOWER_DEAL: int = 7310
const TOWER_SWITCH_NEAR: int = 24

## What shuts a station (all but the one nearest the way in): now and then (SWITCH_SHARE) a switch
## gate with its switch out in the level, near it (LevelGen.switch_floor) and reached from the way in
## with it shut; else, and wherever no such switch fits, a toll gate. Never a door: no key opens a
## station.
const SWITCH_SHARE: float = 0.15


func _init() -> void:
	name = &"crags"
	decor = &"crags"
	sample = SAMPLE
	symmetry = 1
	scale = SCALE


## Open caverns in the cliff, cut shafts up it and build its keeps (see the class description; the
## towers come once the gondola's line is laid, cut_gates).
func shape(w: LevelGen) -> void:
	open_caverns(w)
	var shafts: Dictionary = cut_shafts(w)
	for v: Vector2i in shafts:
		w.structures[v] = &"shaft"
	build_keeps(w, shafts)


## The gondola's line, once the caves are joined: its track and its stations' landings, carved and
## kept clear of everything laid after (lay_circuit). Then the towers, clear of it (build_towers),
## and the caves joined again round their walls, should a tower have shut any air off.
func cut_gates(w: LevelGen) -> void:
	lay_circuit(w)
	build_towers(w)
	var walls: Dictionary = {}
	for tower: Dictionary in w.towers:
		var box: Rect2i = tower["box"]
		for x: int in range(box.position.x, box.end.x):
			for y: int in range(box.position.y, box.end.y):
				if w.is_ground(Vector2i(x, y)):
					walls[Vector2i(x, y)] = true
	w.connect_caves(walls)


## Its rock-bugs (place_bugs), then, last, what shuts each station but one, and the gondola itself
## (shut_stations), and the hoard towers' stars (place_hoards).
func populate(w: LevelGen, def: NextWorldDef) -> void:
	place_bugs(w)
	shut_stations(w, def)
	place_hoards(w)


## Rock-bugs (RockBug): BUGS_PER_K, each in open air against rock (under it, or beside or over it),
## at least BUG_CLEAR cells from the way in and BUG_APART from one another.
static func place_bugs(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var spots: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.EMPTY and LevelGen.dist(v, start) >= BUG_CLEAR \
			and [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP].any(func(d: Vector2i) -> bool: return w.is_ground(v + d)))
	w.put_each(w.pick_apart(spots, w.foes_per_area(BUGS_PER_K), BUG_APART), LevelGen.Type.BUG)


## Last of all (so nothing else in the level moves for them): its falling stalactites
## (place_stalactites), then what the towers hold (place_tower_rewards), the rock-bug nests out on
## the cliff (place_nests), the crossbows built into the towers' walls (place_crossbows) and the
## keeps' (place_keep_crossbows).
func finish(w: LevelGen, _def: NextWorldDef) -> void:
	place_stalactites(w)
	place_tower_rewards(w)
	place_nests(w)
	place_crossbows(w)
	place_keep_crossbows(w)


## Stalactites (Stalactite): STALACTITES_PER_K, each in an empty cell under plain rock with at least
## STALACTITE_DROP open cells under it, clear of the gondola's line and the way in (see the consts).
static func place_stalactites(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var spots: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool:
		if w.get_cell(v).type != LevelGen.Type.EMPTY or w.keep_clear.has(v) or LevelGen.dist(v, start) < STALACTITE_CLEAR:
			return false
		var above: Vector2i = v + Vector2i.UP
		if not w.is_ground(above) or w.masonry.has(above) or w.get_cell(above).type == LevelGen.Type.CRACKED:
			return false
		for k: int in range(1, STALACTITE_DROP + 1):
			var below: Vector2i = v + Vector2i(0, k)
			if not w.is_valid(below) or w.is_ground(below) or w.keep_clear.has(below):
				return false
		return true)
	w.put_each(w.pick_apart(spots, w.foes_per_area(STALACTITES_PER_K), STALACTITE_APART), LevelGen.Type.STALACTITE)


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
## description), their stone kept as masonry and their cells in LevelGen.structures.
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
		for x: int in range(box.position.x, box.end.x):
			for y: int in range(box.position.y, box.end.y):
				w.structures[Vector2i(x, y)] = &"keep"


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
				w.interiors[Vector2i(x, y)] = true
		# A doorway through each wall at the hall's floor, with air outside it.
		for x: int in [box.position.x, box.end.x - 1]:
			_unbuild(w, Vector2i(x, top + 1))
		for x: int in [box.position.x - 1, box.end.x]:
			_open_at(w, Vector2i(x, top))
			_open_at(w, Vector2i(x, top + 1))
	var gap: int = box.end.x - 4 if stair_right else box.position.x + 2
	for x: int in [gap, gap + 1]:
		_unbuild(w, Vector2i(x, box.position.y + 3))
		w.interiors[Vector2i(x, box.position.y + 3)] = true


## Build towers (TOWERS_PER_K) where they fit (_site): each tried at a spot drawn at random and let
## down onto the rock under its middle; with none built so, the smallest tower at the first spot
## it fits, scanning the level (no draw), so every level has one if there is room anywhere. Each is
## noted in LevelGen.towers and its cells in LevelGen.structures.
static func build_towers(w: LevelGen) -> void:
	var want: int = w.per_area(TOWERS_PER_K)
	var built: Dictionary = {}
	for v: Vector2i in w.structures:
		if w.structures[v] != &"shaft":
			built[v] = true
	for attempt: int in range(want * 60):
		if w.towers.size() >= want:
			break
		var wide: int = w.rng.randi_range(TOWER_WIDE.x, TOWER_WIDE.y)
		var storeys: int = w.rng.randi_range(TOWER_STOREYS.x, TOWER_STOREYS.y)
		var tall: int = storeys * STOREY + 1
		var at: Vector2i = Vector2i(w.rng.randi_range(2, w.size.x - wide - 2), w.rng.randi_range(ROOF_AIR + 2, w.size.y - tall - 3))
		var site: Variant = _site(w, at, Vector2i(wide, tall), built)
		if site != null:
			_raise(w, site, built, w.rng.randf() < TOWER_HOARD_SHARE, w.rng.randf() < 0.5)
	if not w.towers.is_empty():
		return
	var least: Vector2i = Vector2i(TOWER_WIDE.x, TOWER_STOREYS.x * STOREY + 1)
	for y: int in range(ROOF_AIR + 2, w.size.y - least.y - 1):
		for x: int in range(2, w.size.x - least.x - 1):
			var site: Variant = _site(w, Vector2i(x, y), least, built)
			if site != null and (site[0] as Rect2i).position.y == y:
				_raise(w, site, built, false, x * 2 < w.size.x)
				return


## Where a tower `size` big drawn at `at` stands, let down onto the first rock under its middle, as
## [its box, its footing (_footing)]; null if it does not fit there: its box and the air over its
## roof must be clear of every structure (LevelGen.structures; a shaft may stand right beside it),
## kept KEEP_APART from the keeps and towers (`built`), clear of what other towers keep whole
## (LevelGen.kept_whole: their roof air, footing, doorsteps), its doorsteps and walls clear of the
## gondola's line, and its footing on rock.
static func _site(w: LevelGen, at: Vector2i, size: Vector2i, built: Dictionary) -> Variant:
	@warning_ignore("integer_division")
	var mid: int = at.x + size.x / 2
	var base: int = at.y + size.y
	while base < w.size.y - 1 and not w.is_ground(Vector2i(mid, base)):
		base += 1
	var box: Rect2i = Rect2i(Vector2i(at.x, base - size.y), size)
	var room: Rect2i = box.grow_individual(0, ROOF_AIR, 0, 0)
	if box.position.y < ROOF_AIR + 2 or box.end.y > w.size.y - 2 or _crosses(room, w.structures) or _crosses(room, w.kept_whole) or _crosses(room.grow(KEEP_APART), built) or _crosses(room.grow_individual(1, 0, 1, 0), w.keep_clear):
		return null
	var footing: Variant = _footing(w, box)
	if footing == null or (footing as Array).any(func(v: Vector2i) -> bool: return w.structures.has(v) or w.keep_clear.has(v) or w.kept_whole.has(v)):
		return null
	return [box, footing]


## Build a tower at `site` (from _site), a hoard tower if `hoard`, and keep its cells as built. Its
## box, footing (and the rock under it), doorsteps and the air over its roof are kept whole (LevelGen.kept_whole: nothing
## cracks, carves, fills or tunnels through them), and the cells of its two walls (doorways and
## windows included) are taken out of the free cells, so nothing big is set in a doorway and carves
## the wall over it.
static func _raise(w: LevelGen, site: Array, built: Dictionary, hoard: bool, right_first: bool) -> void:
	var box: Rect2i = site[0]
	var footing: Array[Vector2i] = site[1]
	_tower(w, box, footing, hoard, right_first)
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			w.structures[Vector2i(x, y)] = &"tower"
			built[Vector2i(x, y)] = true
			w.kept_whole[Vector2i(x, y)] = true
		for d: int in range(1, ROOF_AIR + 1):
			w.kept_whole[Vector2i(x, box.position.y - d)] = true
	for y: int in range(box.position.y, box.end.y):
		for x: int in [box.position.x, box.end.x - 1]:
			w.empties.erase(Vector2i(x, y))
	var ground: int = box.end.y - 1
	for x: int in [box.position.x - 1, box.end.x]:
		for y: int in [ground, ground - 1, ground - 2]:
			w.kept_whole[Vector2i(x, y)] = true
	# Its footing, and the rock it stands on under each column.
	for v: Vector2i in footing:
		w.kept_whole[v] = true
	for x: int in range(box.position.x - 1, box.end.x + 1):
		var under: Vector2i = Vector2i(x, box.end.y)
		while footing.has(under):
			under += Vector2i.DOWN
		if w.is_valid(under):
			w.kept_whole[under] = true


## The open cells under `box` (and under its doorsteps, a cell either side) down to the rock beneath
## it, as an Array[Vector2i] (empty if it stands right on rock); null if any column goes down more
## than TOWER_FOOTING rows or reaches the level's bottom edge (it would stand on nothing, or on
## stone the edge can't hold).
static func _footing(w: LevelGen, box: Rect2i) -> Variant:
	var cells: Array[Vector2i] = []
	for x: int in range(box.position.x - 1, box.end.x + 1):
		var y: int = box.end.y
		while w.is_valid(Vector2i(x, y)) and not w.is_ground(Vector2i(x, y)):
			if y - box.end.y >= TOWER_FOOTING or y >= w.size.y - 1:
				return null
			cells.append(Vector2i(x, y))
			y += 1
	return cells


## A tower in `box` (see the consts): masonry all round a room on each storey, its footing
## (`footing`) built down to the rock, a stair hole in each floor over a room at alternate ends
## (the lowest at the right if `right_first`) with a ledge under it, doorways at the ground floor
## with a doorstep outside each, and for a watchtower (not `hoard`) a hatch through the roof and
## windows. Noted in LevelGen.towers as
## {"box", "hoard", "holes": each stair hole's cells, "ledges": the cells of the ledges under them,
## "top": the top room's floor-level cells}.
static func _tower(w: LevelGen, box: Rect2i, footing: Array[Vector2i], hoard: bool, right_first: bool) -> void:
	var x0: int = box.position.x
	var x1: int = box.end.x - 1
	var roof: int = box.position.y
	var ground: int = box.end.y - 1
	for x: int in range(x0, x1 + 1):
		for y: int in range(roof, ground + 1):
			_rock_at(w, Vector2i(x, y))
			w.masonry[Vector2i(x, y)] = true
		for d: int in range(1, ROOF_AIR + 1):
			_open_at(w, Vector2i(x, roof - d))
	for x: int in [x0 - 1, x1 + 1]:
		_rock_at(w, Vector2i(x, ground))
		w.masonry[Vector2i(x, ground)] = true
	for v: Vector2i in footing:
		_rock_at(w, v)
		w.masonry[v] = true
	# The rooms, from the top: two rows of air over each floor.
	var floors: Array[int] = []
	for y: int in range(roof, ground, STOREY):
		floors.append(y)
		for x: int in range(x0 + 1, x1):
			for r: int in [y + 1, y + 2]:
				_unbuild(w, Vector2i(x, r))
				w.interiors[Vector2i(x, r)] = true
	# The stair: a hole in each floor over a room (the roof's only for a watchtower), at alternate
	# ends from the bottom up, with a ledge under it in the top row of the room below.
	var holes: Array[Vector2i] = []
	var ledges: Array[Vector2i] = []
	var right: bool = right_first
	for i: int in range(floors.size() - 1, -1, -1):
		var y: int = floors[i]
		if y == roof and hoard:
			break
		for k: int in range(STAIR):
			var hole: Vector2i = Vector2i(x1 - 1 - k if right else x0 + 1 + k, y)
			_unbuild(w, hole)
			if y != roof:
				w.interiors[hole] = true
			else:
				w.put(hole, LevelGen.Type.TRAPDOOR)
			holes.append(hole)
			var ledge: Vector2i = hole + Vector2i.DOWN
			w.put(ledge, LevelGen.Type.PLATFORM)
			ledges.append(ledge)
		right = not right
	# A doorway through each wall at the ground floor, with air outside it.
	for x: int in [x0, x1]:
		_unbuild(w, Vector2i(x, ground - 1))
	for x: int in [x0 - 1, x1 + 1]:
		_open_at(w, Vector2i(x, ground - 1))
		_open_at(w, Vector2i(x, ground - 2))
	# Windows: a cell high, at an upper room's floor (each room but the ground floor's), where open
	# air is outside already.
	if not hoard:
		for i: int in range(floors.size() - 1):
			var y: int = floors[i] + 2
			for side: Vector2i in [Vector2i(x0, y), Vector2i(x1, y)]:
				var out: Vector2i = side + (Vector2i.LEFT if side.x == x0 else Vector2i.RIGHT)
				if w.rng.randf() < TOWER_WINDOW and w.is_valid(out) and not w.is_ground(out):
					_unbuild(w, side)
	var top: Array[Vector2i] = []
	for x: int in range(x0 + 1, x1):
		top.append(Vector2i(x, roof + 2))
	w.towers.append({"box": box, "hoard": hoard, "holes": holes, "ledges": ledges, "top": top})


## A hoard tower's stars (TOWER_HOARD), spread along its top room a row over its floor, in cells
## still free.
static func place_hoards(w: LevelGen) -> void:
	for tower: Dictionary in w.towers:
		if not tower["hoard"]:
			continue
		var spots: Array[Vector2i] = []
		for v: Vector2i in tower["top"]:
			if w.get_cell(v).type == LevelGen.Type.EMPTY and w.empties.has(v):
				spots.append(v)
		var n: int = mini(TOWER_HOARD, spots.size())
		for i: int in range(n):
			@warning_ignore("integer_division")
			w.put(spots[(i * spots.size()) / n], LevelGen.Type.COIN)


## The free floor cells of a tower's room `storey` (0 the top room, counting down): open, holding
## nothing, over the room's floor (not over a stair hole), in order across.
static func room_floor(w: LevelGen, tower: Dictionary, storey: int) -> Array[Vector2i]:
	var box: Rect2i = tower["box"]
	var y: int = box.position.y + storey * STOREY + 2
	var out: Array[Vector2i] = []
	for x: int in range(box.position.x + 1, box.end.x - 1):
		var v: Vector2i = Vector2i(x, y)
		if w.get_cell(v).type == LevelGen.Type.EMPTY and w.empties.has(v) and w.is_ground(v + Vector2i.DOWN):
			out.append(v)
	return out


## What the watchtowers' top rooms hold (see TOWER_REWARDS): a key or a switch is brought in from where it
## was laid, keeping its place in the order things were laid (so the keys are dealt their colours
## as before); a mending bowl is new, and stands on the room's floor. Over the floor if there is
## room, else anywhere in the top room (but then no bowl).
static func place_tower_rewards(w: LevelGen) -> void:
	var turn: int = posmod(Rules.level_seed(w.seed_for_colors, TOWER_DEAL), TOWER_REWARDS.size())
	for tower: Dictionary in w.towers:
		if tower["hoard"]:
			continue
		var spots: Array[Vector2i] = room_floor(w, tower, 0)
		if spots.is_empty():
			# A full floor: over its stair hole, then.
			var top: Array = tower["top"]
			for v: Vector2i in top:
				if w.get_cell(v).type == LevelGen.Type.EMPTY and w.empties.has(v):
					spots.append(v)
		if spots.is_empty():
			continue
		@warning_ignore("integer_division")
		var at: Vector2i = spots[spots.size() / 2]
		var brought: bool = false
		for k: int in range(TOWER_REWARDS.size()):
			var kind: StringName = TOWER_REWARDS[(turn + k) % TOWER_REWARDS.size()]
			if kind == &"well":
				break
			if kind == &"key":
				brought = _bring_key(w, tower, at)
			elif kind == &"switch":
				brought = _bring_switch(w, tower, at)
			if brought:
				break
		turn += 1
		if not brought:
			if not w.is_ground(at + Vector2i.DOWN):
				continue
			w.put(at, LevelGen.Type.WELL)
		tower["reward"] = w.get_cell(at).type


## Move one of the keys the level deals (the last of them, not the start key, and not already in
## a tower) to `at` in `tower`; whether one was moved.
static func _bring_key(w: LevelGen, tower: Dictionary, at: Vector2i) -> bool:
	var dealt: Array[Vector2i] = []
	for v: Vector2i in w.objects:
		if w.get_cell(v).type == LevelGen.Type.KEY and w.get_cell(v).extra_info == null:
			dealt.append(v)
	dealt = dealt.slice(0, w.key_count())
	for i: int in range(dealt.size() - 1, -1, -1):
		var v: Vector2i = dealt[i]
		if v != w.start_key and w.structures.get(v, &"") != &"tower":
			_move_object(w, v, at)
			return true
	return false


## Move the switch of the switch gate nearest `tower` (no more than TOWER_SWITCH_NEAR cells from it,
## and not in a tower's top room already) to `at` in it, if `at` is reached from the way in with
## that gate shut, so the gate can still be opened from this side; whether one was moved.
static func _bring_switch(w: LevelGen, tower: Dictionary, at: Vector2i) -> bool:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	if not w.is_valid(start):
		return false
	var box: Rect2i = tower["box"]
	var middle: Vector2i = box.get_center()
	var gates: Array[Vector2i] = w.objects_of(LevelGen.Type.SWITCH_GATE).filter(func(g: Vector2i) -> bool:
		return LevelGen.dist(g, middle) <= TOWER_SWITCH_NEAR and w.get_cell(g).extra_info is Vector2i)
	gates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return LevelGen.dist(a, middle) < LevelGen.dist(b, middle) or (LevelGen.dist(a, middle) == LevelGen.dist(b, middle) and a < b))
	for gate: Vector2i in gates:
		var lever: Vector2i = w.get_cell(gate).extra_info
		if w.get_cell(lever).type != LevelGen.Type.SWITCH or w.towers.any(func(t: Dictionary) -> bool: return (t["top"] as Array).has(lever)):
			continue
		if not w.reach_from(start, func(n: Vector2i) -> bool: return n != gate).has(at):
			continue
		_move_object(w, lever, at)
		w.get_cell(gate).extra_info = at
		return true
	return false


## Move what is in cell `from` to free cell `to`, keeping its place among the level's objects.
static func _move_object(w: LevelGen, from: Vector2i, to: Vector2i) -> void:
	var cell: LevelGen.Cell = w.get_cell(from)
	w.objects[w.objects.find(from)] = to
	w.empties.erase(to)
	w.set_cell(to, cell)
	w.set_cell(from, LevelGen.Cell.new(LevelGen.Type.EMPTY))
	w.empties.append(from)


## Rock-bug nests (see NESTS_PER_K), out on the cliff on free floors, outside every building.
static func place_nests(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var floors: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool:
		return LevelGen.dist(v, start) >= NEST_CLEAR and not w.keep_clear.has(v) and not w.structures.has(v))
	w.put_each(w.pick_apart(floors, w.foes_per_area(NESTS_PER_K), NEST_APART), LevelGen.Type.NEST)


## Crossbows built into the towers' walls (see CROSSBOW_SHARE). A spot is a cell of a tower's wall
## that is whole stone (no window or doorway), with open air outside it and a free room cell inside
## it: the crossbow is set into that stone (the wall stays solid), and takes the room cell before it
## as its own in the level. One spot to a side of a room, its floor's row first; the top rooms
## first, down the tower. Its extra info is {"facing": +1 right or -1 left}, the way it shoots.
static func place_crossbows(w: LevelGen) -> void:
	var most: int = maxi(1, floori(float(CROSSBOWS_MOST) * Difficulty.foes()))
	for tower: Dictionary in w.towers:
		var box: Rect2i = tower["box"]
		var count: int = 0
		for y: int in range(box.position.y, box.end.y - 1, STOREY):
			for side: Array in [[box.position.x, -1], [box.end.x - 1, 1]]:
				var facing: int = int(side[1])
				for row: int in [y + 2, y + 1]:
					var wall: Vector2i = Vector2i(int(side[0]), row)
					var at: Vector2i = wall - Vector2i(facing, 0)
					var out: Vector2i = wall + Vector2i(facing, 0)
					if count >= most or not w.masonry.has(wall) or not w.is_ground(wall):
						continue
					if not w.is_valid(out) or w.is_ground(out):
						continue
					if w.get_cell(at).type != LevelGen.Type.EMPTY or not w.empties.has(at):
						continue
					var roll: int = posmod(Rules.level_seed(w.seed_for_colors, CROSSBOW_DEAL + wall.x * 977 + wall.y * 31), 1000)
					if float(roll) / 1000.0 < CROSSBOW_SHARE:
						w.put(at, LevelGen.Type.CROSSBOW, {"facing": facing})
						count += 1
					break


## Crossbows built into the keeps' walls (see KEEP_CROSSBOW_SHARE), as into the towers': a
## spot is a cell of a keep's wall that is whole stone, with open air outside it (not another
## building's room) and a free cell of the keep's hall inside it, and not stone a big thing under it
## needs for room (LevelGen.make_room carves that later). In order across the level, top to bottom.
## Its extra info is {"facing": +1 right or -1 left}.
static func place_keep_crossbows(w: LevelGen) -> void:
	var share: float = minf(1.0, KEEP_CROSSBOW_SHARE * Difficulty.foes())
	var walls: Array = w.masonry.keys()
	walls.sort()
	var placed: Array[Vector2i] = []
	for wall: Vector2i in walls:
		if w.structures.get(wall, &"") != &"keep" or not w.is_ground(wall) or _room_of_big(w, wall):
			continue
		for facing: int in [-1, 1]:
			var at: Vector2i = wall - Vector2i(facing, 0)
			var out: Vector2i = wall + Vector2i(facing, 0)
			if not w.interiors.has(at) or w.get_cell(at).type != LevelGen.Type.EMPTY or not w.empties.has(at):
				continue
			if not w.is_valid(out) or w.is_ground(out) or w.interiors.has(out):
				continue
			if placed.any(func(v: Vector2i) -> bool: return LevelGen.dist(v, at) < KEEP_CROSSBOW_APART):
				continue
			var roll: int = posmod(Rules.level_seed(w.seed_for_colors, KEEP_CROSSBOW_DEAL + wall.x * 977 + wall.y * 31), 1000)
			if float(roll) / 1000.0 < share:
				w.put(at, LevelGen.Type.CROSSBOW, {"facing": facing})
				placed.append(at)


## Whether cell `c` is within the box of a thing more than a cell big (Placeables.size: across and
## up from its own cell), which LevelGen.make_room clears of rock.
static func _room_of_big(w: LevelGen, c: Vector2i) -> bool:
	for dx: int in range(2):
		for dy: int in range(3):
			var o: Vector2i = c + Vector2i(-dx, dy)
			if (dx == 0 and dy == 0) or not w.is_valid(o):
				continue
			var size: Vector2i = Placeables.size(w.get_cell(o).type)
			if dx < size.x and dy < size.y:
				return true
	return false


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


## Shut every station but the one nearest the way in (see SWITCH_SHARE), then put the gondola, its
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
		if w.rng.randf() < SWITCH_SHARE:
			var lever: Variant = w.switch_floor(w.reach_from(start, func(n: Vector2i) -> bool: return n != gate), gate)
			if lever != null:
				w.put(gate, LevelGen.Type.SWITCH_GATE, lever)
				w.put(lever, LevelGen.Type.SWITCH, gate)
				continue
		w.put(gate, LevelGen.Type.TOLL, Rules.toll_price(def.depth))
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
