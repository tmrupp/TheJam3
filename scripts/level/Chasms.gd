class_name Chasms
extends RefCounted
## Chasms and gaps, the gates of the levels whose archetype has them (Archetype.chasmed): cut
## across long floors in a cemetery and bridged by planks once a bell is rung, or taken from the
## open air between islands in the sky and blown over by a vane's wind (SkyArchetype.cut_gates).
## Each is kept in LevelGen.chasms as {"planks": cells, "row": the floor row, "left": the last floor
## cell before it, "right": the first after}. Static functions on the level being laid out (`w`).

## Chasms per 1000 cells (at least CHASMS_MIN, as many as fit).
const CHASMS_PER_K: float = 1.2
const CHASMS_MIN: int = 2
## A cut chasm's width (from, to) and depth in cells, with thorns at the bottom and rock under them.
const CHASM_WIDTH: Vector2i = Vector2i(8, 10)
const CHASM_DEPTH: int = 2
## Floor kept whole either side of a chasm: as much as can be, else less.
const CHASM_SHORES: Array[int] = [4, 3, 2]
## Open air over a chasm kept clear of ledges, lifts, moons and everything else, so nothing but
## the bridge (or a move found later) gets you over.
const CHASM_CLEAR: int = 4
## A bell's switch stands at least this many cells from its bell (see place_bells).
const BELL_SWITCH: int = 6
## Salt for the level seed when dealing which crossings are left to relic moves (relax_crossings).
const RELIC_DEAL: int = 9500


## How many chasms level `w` wants.
static func wanted(w: LevelGen) -> int:
	return maxi(CHASMS_MIN, w.per_area(CHASMS_PER_K))


## A cemetery's gates: chasms cut across long stretches of floor (CHASM_WIDTH cells across,
## CHASM_DEPTH deep, with thorns at the bottom and rock under them): too wide to jump without a
## move found later. Across the top of each lie the planks of a bridge (Type.BRIDGE, holding the
## chasm's number), not there until the chasm's bell is rung (see place_bells). Cut right after the
## caves are joined, so everything else lands round them.
static func carve(w: LevelGen) -> void:
	var want: int = wanted(w)
	# Which cells are floors (open, with rock under), looked up many times below.
	var floors: PackedByteArray = PackedByteArray()
	floors.resize(w.size.x * w.size.y)
	for v: Vector2i in w.empties:
		if w.get_cell(v).type == LevelGen.Type.EMPTY and w.is_ground(v + Vector2i.DOWN):
			floors[v.x * w.size.y + v.y] = 1
	# Spots for each width of shore, widest first: a chasm takes the widest shores left. A spot
	# is a stretch of floor (shore, chasm, shore) whose every column has its floor within a cell
	# of one row: cutting it levels the floor to that row (see _level_floor), so the graveyard's
	# stepping terraces still have room for wide chasms.
	var by_shore: Array = []
	for shore: int in CHASM_SHORES:
		var spots: Array = []
		for y: int in range(2, w.size.y - CHASM_DEPTH - 3):
			for span: int in range(CHASM_WIDTH.x, CHASM_WIDTH.y + 1):
				for a: int in range(shore, w.size.x - shore - span + 1):
					var ok: bool = true
					for x: int in range(a - shore, a + span + shore):
						if _floor_near(w, floors, x, y) == -1:
							ok = false
							break
					if not ok:
						continue
					# Under the cut, nothing but rock or air (no thorns), down to the pit's floor.
					for x: int in range(a, a + span):
						for d: int in range(1, CHASM_DEPTH + 2):
							if not w.is_valid(Vector2i(x, y + d)) or w.get_cell(Vector2i(x, y + d)).type == LevelGen.Type.SPIKES:
								ok = false
					if ok:
						spots.append([y, a, span, shore])
		by_shore.append(spots)
	while w.chasms.size() < want:
		var spots: Array = []
		for list: Array in by_shore:
			if not list.is_empty():
				spots = list
				break
		if spots.is_empty():
			break
		var choice: Array = w.pick(spots)
		var y: int = choice[0]
		var a: int = choice[1]
		var span: int = choice[2]
		var shore: int = choice[3]
		for x: int in range(a - shore, a + span + shore):
			_level_floor(w, floors, x, y)
		# Keep clear of chasms already cut.
		for i: int in range(by_shore.size()):
			by_shore[i] = (by_shore[i] as Array).filter(func(sp: Array) -> bool: return absi(int(sp[0]) - y) > CHASM_DEPTH + 2 or int(sp[1]) + int(sp[2]) + CHASM_SHORES[0] < a or a + span + CHASM_SHORES[0] < int(sp[1]))
		var id: int = w.chasms.size()
		var planks: Array[Vector2i] = []
		for x: int in range(a, a + span):
			for d: int in range(1, CHASM_DEPTH + 1):
				w._to_open(Vector2i(x, y + d))
			var bottom: Vector2i = Vector2i(x, y + CHASM_DEPTH + 1)
			w.grounds.erase(bottom)
			w.empties.erase(bottom)
			w.objects.append(bottom)
			w.cells[bottom.x][bottom.y] = LevelGen.Cell.new(LevelGen.Type.SPIKES)
			var under: Vector2i = bottom + Vector2i.DOWN
			if w.is_valid(under) and w.get_cell(under).type != LevelGen.Type.GROUND:
				w._to_rock(under)
			# The pit and the air over it are kept clear (out of `empties`, so nothing is placed).
			for d: int in range(-CHASM_CLEAR, CHASM_DEPTH + 1):
				w.empties.erase(Vector2i(x, y + d))
			var plank: Vector2i = Vector2i(x, y + 1)
			w.put(plank, LevelGen.Type.BRIDGE, id)
			planks.append(plank)
		w.chasms.append(_record(planks, y, a, span))


## A gap of open air `span` cells across from cell `a` on floor row `y`, crossed on the wind: its
## air is kept clear as a chasm's is, and one current (Type.WIND, {chasm, width}) spans it, held in
## its first cell, the row under the floor (SkyArchetype).
static func add_gap(w: LevelGen, y: int, a: int, span: int) -> void:
	var id: int = w.chasms.size()
	var planks: Array[Vector2i] = []
	for x: int in range(a, a + span):
		planks.append(Vector2i(x, y + 1))
		for d: int in range(-CHASM_CLEAR, CHASM_DEPTH + 1):
			w.empties.erase(Vector2i(x, y + d))
	w.put(planks[0], LevelGen.Type.WIND, {"chasm": id, "width": span})
	w.chasms.append(_record(planks, y, a, span))


## The record kept of a chasm `span` cells across from cell `a` on floor row `y`.
static func _record(planks: Array[Vector2i], y: int, a: int, span: int) -> Dictionary:
	return {"planks": planks, "row": y, "left": Vector2i(a - 1, y), "right": Vector2i(a + span, y)}


## Whether cell `c` is in or beside any chasm's or gap's kept air: within two columns of a plank,
## from a row over the air kept clear above it to a row under its pit.
static func near(w: LevelGen, c: Vector2i) -> bool:
	for chasm: Dictionary in w.chasms:
		var row: int = chasm["row"]
		if c.y < row - CHASM_CLEAR - 1 or c.y > row + CHASM_DEPTH + 1:
			continue
		for plank: Vector2i in chasm["planks"]:
			if absi(plank.x - c.x) <= 2:
				return true
	return false


## `spots` ([.., row, first cell, width] at the end of each) less those too near a chasm on row
## `y` from `a`, `span` cells wide.
static func apart(spots: Array, y: int, a: int, span: int) -> Array:
	return spots.filter(func(sp: Array) -> bool:
		var n: int = sp.size()
		return absi(int(sp[n - 3]) - y) > CHASM_DEPTH + 3 or int(sp[n - 2]) + int(sp[n - 1]) + CHASM_SHORES[0] < a or a + span + CHASM_SHORES[0] < int(sp[n - 2]))


## The row of the floor (an open cell with rock under it, marked in `floors`) in column `x` at
## `y`, a cell above or a cell below; -1 if there is none.
static func _floor_near(w: LevelGen, floors: PackedByteArray, x: int, y: int) -> int:
	if x < 0 or x >= w.size.x:
		return -1
	for r: int in [y, y - 1, y + 1]:
		if r < 0 or r >= w.size.y:
			continue
		if floors[x * w.size.y + r] == 1:
			# Room to stand over the levelled floor.
			if r == y + 1 and w.get_cell(Vector2i(x, y)).type != LevelGen.Type.EMPTY:
				continue
			return r
	return -1


## Level column `x`'s floor to row `y`: a step up is cut away, a step down filled in.
static func _level_floor(w: LevelGen, floors: PackedByteArray, x: int, y: int) -> void:
	var r: int = _floor_near(w, floors, x, y)
	if r == y - 1:
		w._to_open(Vector2i(x, y))
	elif r == y + 1:
		w._to_rock(Vector2i(x, y + 1))


## Each chasm's crossings (`crossing`: a bell, or a vane in the sky): one on the floor of each
## side, a few cells from the edge, so it can be crossed from either side. Each is chained up on
## its own: by a padlock in a key colour (any key of it, or a skeleton key, frees it), or, about
## half the time, to a switch on a floor on its own side (reachable from it without crossing any
## chasm, and within `switch_reach` cells unless that is -1), at least BELL_SWITCH cells off
## (throwing it frees that one). A crossing's cell holds [chasm, lock]: lock is the key colour, or
## -1 for a switch.
static func place_bells(w: LevelGen, crossing: LevelGen.Type, switch_reach: int) -> void:
	for id: int in range(w.chasms.size()):
		var chasm: Dictionary = w.chasms[id]
		for side: int in [-1, 1]:
			var edge: Vector2i = chasm["left"] if side < 0 else chasm["right"]
			var at: Variant = null
			for d: int in [2, 3, 1, 4]:
				var v: Vector2i = edge + Vector2i(side * (d - 1), 0)
				if w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.EMPTY and w.empties.has(v) and w.ground_below(v):
					at = v
					break
			if at == null:
				continue
			w.add_object_at(at)
			# One draw, as randi_range was, so the rest of the level lands where it did.
			var lock: int = Rules.rarity_color(int(w.rng.randi()))
			if w.rng.randf() < 0.5:
				var lever: Variant = _bell_switch(w, at, switch_reach)
				if lever != null:
					lock = -1
					w.put(lever, LevelGen.Type.SWITCH, at)
			w.set_kind(at, crossing, [id, lock])


## A floor for the switch that frees the bell at `bell`: on its side, reachable from it through
## open air without crossing any chasm (and within `reach` cells, unless that is -1), at least
## BELL_SWITCH cells off; null if there is none.
static func _bell_switch(w: LevelGen, bell: Vector2i, reach_cells: int) -> Variant:
	var blocked: Dictionary = {}
	for chasm: Dictionary in w.chasms:
		var row: int = chasm["row"]
		for plank: Vector2i in chasm["planks"]:
			for d: int in range(-CHASM_CLEAR - 1, CHASM_DEPTH + 2):
				blocked[Vector2i(plank.x, row + d)] = true
	var reach: Dictionary = w.reach_from(bell, func(n: Vector2i) -> bool: return not blocked.has(n) and (reach_cells < 0 or LevelGen.dist(n, bell) <= reach_cells))
	return w._pick_floor_in(reach, bell, BELL_SWITCH)


## Deep down (Rules.relic_need), some chasms and gaps are left to the relic moves: their bells
## or vanes go, with the switches that free them, and their bridge's planks or their wind. Dealt
## by the level seed per chasm, never the world RNG, and done last: the level is laid out as it
## always was, then these are taken away. Kept in LevelGen.relic_chasms.
static func relax_crossings(w: LevelGen, def: NextWorldDef) -> void:
	var need: int = Rules.relic_need(def.depth)
	if need <= 0:
		return
	for id: int in range(w.chasms.size()):
		if Rules.level_seed(w.seed_for_colors, RELIC_DEAL + id) % 100 < need:
			w.relic_chasms.append(id)
	if w.relic_chasms.is_empty():
		return
	var gone: Dictionary = {}
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		var chasm: int = -1
		if cell.type in [LevelGen.Type.BELL, LevelGen.Type.VANE]:
			chasm = int((cell.extra_info as Array)[0])
		elif cell.type == LevelGen.Type.BRIDGE:
			chasm = int(cell.extra_info)
		elif cell.type == LevelGen.Type.WIND and cell.extra_info is Dictionary and (cell.extra_info as Dictionary).has("chasm"):
			chasm = int((cell.extra_info as Dictionary)["chasm"])
		if chasm in w.relic_chasms:
			gone[v] = true
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		if cell.type == LevelGen.Type.SWITCH and cell.extra_info is Vector2i and gone.has(cell.extra_info):
			gone[v] = true
	for v: Vector2i in gone:
		w._to_open(v)
