extends Control

class_name MapInfo

const CLOSE_ONE_KEY: bool = false
const CODE_LENGTH: int = 4 # 8 is more reasonable
## Keys and doors are dealt these colours in turn; a key opens doors of its own colour.
const KEY_COLOR_COUNT: int = 4
## Counts per 1000 cells of level, so a level's contents scale with its size (see per_area).
const KEYS_PER_K: float = 2.0
const DOORS_PER_K: float = 3.0
## Switch gates: a gate across a corridor, lifted for good by a switch elsewhere in the level.
const SWITCH_GATES_PER_K: float = 0.6
## Lanterns beyond the one at the way back (the arrival going deeper): scarce, so a lit one is
## worth keeping (at least one per level).
const LANTERNS_PER_K: float = 0.4
const MOONS_PER_K: float = 3.0
const CRACKS_PER_K: float = 2.5
## Natural teleporter pairs scale with level area, without a fixed cap.
const PORTAL_PAIRS_PER_K: float = 0.75
const MOON_CLEARANCE: int = 1
const MOON_SPACING: int = 6
## Share of platform runs (up to 3 cells long) that glide along a track instead of staying put.
const MOVING_PLATFORM_CHANCE: float = 0.35
## Hoppers (enemies that leap at the wizard) from depth 1, per 1000 cells.
const HOPPERS_PER_K: float = 2.0
## Share (%) of levels from depth 1 whose secret room holds a skeleton key (see KeyRing).
const SKELETON_CHANCE: int = 30
## Cemetery levels (NextWorldDef.archetype): moth swarms (one by each lantern, and these more),
## banks of sleep fog and wraiths, per 1000 cells.
const MOTHS_PER_K: float = 0.6
const FOG_PER_K: float = 0.7
const WRAITHS_PER_K: float = 0.9
## A cemetery's gates: chasms cut across its floors, bridged by planks that only appear once their
## bell is rung (see World.carve_chasms, Bell, Bridge), per 1000 cells (at least one).
const CHASMS_PER_K: float = 0.5

enum Type {
	EMPTY,
	GROUND,
	MOON,
	GOAL,
	SPIKES,
	ENEMY,
	SHOOTER,
	COIN,
	KEY,
	DOOR,
	RESPAWN,
	CHECKPOINT,
	PORTAL,
	ASTRAL_PROJECTION_POINT,
	PLATFORM,
	MOVING_PLATFORM,
	EXIT,
	SHRINE,
	CRACKED,
	INKWELL,
	SWITCH_GATE,
	SWITCH,
	HOPPER,
	LASER,
	RELIC,
	CLUSTER,
	MOTHS,
	FOG,
	WRAITH,
	BRIDGE,
	BELL,
}

## A level's ways out. Deeper and back move along the seed's column; left and right step to the
## neighbouring seed at the same depth, as if a run had started there; a level a side world leads
## into has an ordinary way up as well (RETURN). Where each leads is up to the place's definition
## (NextWorldDef.lead); doors into side worlds are numbered from Worlds.DOOR_BASE.
enum Exit { DEEPER, BACK, LEFT, RIGHT, RETURN }

class Cell:
	var type: Type = Type.GROUND
	var extra_info: Variant = null

	func _init(_type: Type) -> void:
		type = _type

class World:
	var cells: Array
	var size: Vector2i = Vector2i.ZERO
	var rng: RandomNumberGenerator
	var empties: Array[Vector2i] = []
	var grounds: Array[Vector2i] = []
	var objects: Array[Vector2i] = []

	## Exit -> cell, and the lantern cell placed beside each exit (the start lantern at depth 0).
	var exits: Dictionary = {}
	var exit_lanterns: Dictionary = {}
	## At depth 0, the side door placed near the start (Exit.LEFT or RIGHT; -1 for none), the
	## footholds hopped to from the start (see Reach.tree), and the cells on the way from the start
	## to that door and its key, which doors and gates keep off (see place_start_key).
	var start_side: int = -1
	var start_reach: Dictionary = {}
	var keep_clear: Dictionary = {}
	## The shrine's cell (its boon side; mending is the cell to the right), or (-1, -1).
	var shrine: Vector2i = Vector2i(-1, -1)

	var color_to_type: Dictionary = {
		Color.WHITE: 	Type.EMPTY,
		Color.BLACK: 	Type.GROUND,
		Color.RED: 		Type.SPIKES,
	}

	func new_cell_by_color (c: Color) -> Cell:
		return Cell.new(color_to_type[Color(c)])

	func is_valid (v: Vector2i) -> bool:
		return not (v.x >= size.x or v.x < 0 or v.y >= size.y or v.y < 0)

	var neighbor_offsets: Array[Vector2i] = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
	func get_neighbors (v: Vector2i) -> Array[Vector2i]:
		var vs: Array[Vector2i] = []
		for offset: Vector2i in neighbor_offsets:
			var n: Vector2i = v + offset
			if is_valid(n):
				vs.append(n)
		return vs

	func is_ground (v: Vector2i) -> bool:
		return is_valid(v) and get_cell(v).type == Type.GROUND

	func get_cell (v: Vector2i) -> Cell:
		return cells[v.x][v.y]

	func set_cell (v: Variant, cell: Cell) -> void:
		if v != null:
			cells[v.x][v.y] = cell

	func get_random_cell () -> Vector2i:
		return Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))

	func ground_adjacent (v: Vector2i) -> bool:
		return get_neighbors(v).any(is_ground)

	func ground_flanking (v: Vector2i) -> bool:
		for n: int in range(0, 2, len(neighbor_offsets)):
			var a: Vector2i = v+neighbor_offsets[n]
			var b: Vector2i = v+neighbor_offsets[n+1]
			if is_ground(a) and is_ground(b):
				return true

		return false

	func ground_below (v: Vector2i) -> bool:
		var n: Vector2i = v+Vector2i(0,1)
		return is_ground(n)

	func add_object_at (v: Vector2i) -> void:
		empties.erase(v)
		grounds.erase(v)
		objects.append(v)

	## Places the four exits by position: back near the top, deeper near the bottom and at least
	## exit_distance(depth) cells from back, left and right at the sides. A lantern goes beside the
	## way back, where a dive arrives. At depth 0 there is no way back: that spot holds the run's
	## start lantern instead.
	func place_exits (depth: int, debug: bool = false) -> void:
		var spots: Array[Vector2i] = []
		for v: Vector2i in empties:
			if ground_below(v):
				spots.append(v)
		if spots.size() < 8:
			return
		spots.sort()
		var lo: Vector2i = spots[0]
		var hi: Vector2i = spots[0]
		for v: Vector2i in spots:
			lo = Vector2i(mini(lo.x, v.x), mini(lo.y, v.y))
			hi = Vector2i(maxi(hi.x, v.x), maxi(hi.y, v.y))
		@warning_ignore("integer_division")
		var band_y: int = maxi(2, size.y / 4)
		@warning_ignore("integer_division")
		var band_x: int = maxi(2, size.x / 5)
		var chosen: Array[Vector2i] = []
		var back: Vector2i = _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.y <= lo.y + band_y)
		chosen.append(back)
		if debug:
			_place_exits_near(spots, chosen, back, depth)
			return
		var reach: int = MapInfo.exit_distance(depth)
		var deeper: Variant = _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.y >= hi.y - band_y and absi(v.x - back.x) + absi(v.y - back.y) >= reach, true)
		if deeper == null:
			# No spot low and far enough: take the one furthest from the way back.
			var best: Vector2i = spots[0]
			for v: Vector2i in spots:
				if not chosen.has(v) and absi(v.x - back.x) + absi(v.y - back.y) > absi(best.x - back.x) + absi(best.y - back.y):
					best = v
			deeper = best
		chosen.append(deeper)
		# At depth 0, one side door stands near the start, on floors the wizard can hop to from it,
		# so every run can get out of its first level (its key: place_start_key).
		var near: Variant = _start_door(spots, chosen, back) if depth == 0 else null
		if near != null:
			chosen.append(near)
			start_side = Exit.LEFT if (near as Vector2i).x < back.x else Exit.RIGHT
		var left: Vector2i = near if start_side == Exit.LEFT else _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.x <= lo.x + band_x)
		if start_side != Exit.LEFT:
			chosen.append(left)
		var right: Vector2i = near if start_side == Exit.RIGHT else _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.x >= hi.x - band_x)
		if start_side != Exit.RIGHT:
			chosen.append(right)
		exits = {Exit.BACK: back, Exit.DEEPER: deeper, Exit.LEFT: left, Exit.RIGHT: right}
		_finish_exits(spots, chosen, depth)

	## The start's side door and key: at least START_DOOR cells from the start, and found with hops
	## START_ACROSS wide, a little short of the wizard's reach, so getting to them is easy.
	const START_DOOR: int = 5
	const START_ACROSS: int = 3

	## The floor spot nearest the start (`back`), at least START_DOOR cells from it, that the wizard
	## can hop to from it; null if there is none.
	func _start_door (spots: Array[Vector2i], chosen: Array[Vector2i], back: Vector2i) -> Variant:
		start_reach = Reach.tree(self, back, START_ACROSS)
		var best: Variant = null
		var best_d: int = 1 << 30
		for v: Vector2i in spots:
			var d: int = absi(v.x - back.x) + absi(v.y - back.y)
			if d >= START_DOOR and d < best_d and not chosen.has(v) and start_reach.has(v):
				best_d = d
				best = v
		return best

	## A key for the start's side door (in that door's lock colour), on a floor the wizard can hop
	## to from the start, as near the way to the door as can be; the cells on the way from the start
	## to the door and to the key are kept clear of doors and gates.
	func place_start_key (def: NextWorldDef) -> void:
		if start_side < 0:
			return
		var start: Vector2i = exits[Exit.BACK]
		var door: Vector2i = exits[start_side]
		var md: Callable = func(a: Vector2i, b: Vector2i) -> int: return absi(a.x - b.x) + absi(a.y - b.y)
		var floors: Array[Vector2i] = []
		for v: Vector2i in start_reach:
			floors.append(v)
		floors.sort()
		var best: Variant = null
		var best_score: int = 1 << 30
		for v: Vector2i in floors:
			if get_cell(v).type != Type.EMPTY or not empties.has(v) or md.call(v, start) < 3 or md.call(v, door) < 2:
				continue
			if objects.any(func(o: Vector2i) -> bool: return md.call(o, v) < 2):
				continue
			var score: int = md.call(v, start) + md.call(v, door)
			if score < best_score:
				best_score = score
				best = v
		if best != null:
			var at: Vector2i = best
			var key: Cell = Cell.new(Type.KEY)
			key.extra_info = MapInfo.lateral_lock(def.coord, start_side)
			add_object_at(at)
			set_cell(at, key)
			for target: Vector2i in [door, at]:
				var steps: Array[Vector2i] = Reach.way(start_reach, target)
				for i: int in range(1, steps.size()):
					for c: Vector2i in Reach.arc_cells(steps[i - 1], steps[i]):
						keep_clear[c] = true
		start_reach = {}

	## Doors (or the start lantern) on the exit cells, a lantern beside the way back, then the shrine.
	## Lanterns are scarce: the other exits have none.
	func _finish_exits (spots: Array[Vector2i], chosen: Array[Vector2i], depth: int) -> void:
		for which: int in [Exit.BACK, Exit.DEEPER, Exit.LEFT, Exit.RIGHT]:
			var at: Vector2i = exits[which]
			add_object_at(at)
			if which == Exit.BACK and depth == 0:
				set_cell(at, Cell.new(Type.CHECKPOINT))
				exit_lanterns[which] = at
				continue
			var door: Cell = Cell.new(Type.EXIT)
			door.extra_info = which
			set_cell(at, door)
			if which != Exit.BACK:
				continue
			var lantern: Variant = _nearest_free(spots, at, chosen)
			if lantern != null:
				chosen.append(lantern)
				add_object_at(lantern)
				set_cell(lantern, Cell.new(Type.CHECKPOINT))
				exit_lanterns[which] = lantern
		_place_shrine(spots, chosen, exits[Exit.DEEPER])

	## Debug runs: deeper, left and right on the floor spots nearest the way back (the spawn), two
	## cells apart.
	func _place_exits_near (spots: Array[Vector2i], chosen: Array[Vector2i], back: Vector2i, depth: int) -> void:
		var near: Array[Vector2i] = spots.duplicate()
		var md: Callable = func(a: Vector2i, b: Vector2i) -> int: return absi(a.x - b.x) + absi(a.y - b.y)
		near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return md.call(a, back) < md.call(b, back) or (md.call(a, back) == md.call(b, back) and a < b))
		var picks: Array[Vector2i] = []
		for v: Vector2i in near:
			if picks.size() == 3:
				break
			var clear: bool = true
			for q: Vector2i in picks + [back]:
				if md.call(v, q) < 2:
					clear = false
			if clear:
				picks.append(v)
		while picks.size() < 3:
			picks.append(_pick_spot(spots, chosen + picks, func(_v: Vector2i) -> bool: return true))
		chosen.append_array(picks)
		exits = {Exit.BACK: back, Exit.DEEPER: picks[0], Exit.LEFT: picks[1], Exit.RIGHT: picks[2]}
		_finish_exits(spots, chosen, depth)

	## Pockets of open space smaller than this are filled with rock rather than tunnelled to.
	const POCKET: int = 6

	## Join every open space into one cave. Tiny pockets fill with rock; every other open region
	## is joined to the largest by carving the shortest tunnel through the rock between them,
	## nearest region first, until one region remains. Deterministic: fixed scan and BFS orders.
	func connect_caves () -> void:
		var groups: Array = _open_regions()
		for g: Array in groups:
			if g.size() < POCKET:
				for v: Vector2i in g:
					_to_rock(v)
		groups = _open_regions()
		if groups.size() <= 1:
			return
		var main: Dictionary = {}
		var biggest: Array = groups[0]
		for g: Array in groups:
			if g.size() > biggest.size():
				biggest = g
		for v: Vector2i in biggest:
			main[v] = true
		var guard: int = 0
		while main.size() < _open_count() and guard < 200:
			guard += 1
			# Breadth-first out of the main region, through rock, to the nearest other open cell.
			var parent: Dictionary = {}
			var queue: Array[Vector2i] = []
			var starts: Array = main.keys()
			starts.sort()
			for v: Vector2i in starts:
				parent[v] = v
				queue.append(v)
			var found: Variant = null
			var head: int = 0
			while head < queue.size() and found == null:
				var v: Vector2i = queue[head]
				head += 1
				for d: Vector2i in neighbor_offsets:
					var n: Vector2i = v + d
					if not is_valid(n) or parent.has(n):
						continue
					parent[n] = v
					if _open(n) and not main.has(n):
						found = n
						break
					queue.append(n)
			if found == null:
				break
			# Carve the rock along the way back, then take in the region just reached.
			var at: Vector2i = parent[found]
			while not main.has(at):
				if is_ground(at):
					_to_open(at)
				main[at] = true
				at = parent[at]
			_flood(found, main)

	func _open_count () -> int:
		var n: int = 0
		for x: int in range(size.x):
			for y: int in range(size.y):
				if _open(Vector2i(x, y)):
					n += 1
		return n

	## Every connected open region (4-neighbour), in scan order.
	func _open_regions () -> Array:
		var seen: Dictionary = {}
		var out: Array = []
		for x: int in range(size.x):
			for y: int in range(size.y):
				var v: Vector2i = Vector2i(x, y)
				if _open(v) and not seen.has(v):
					var region: Dictionary = {}
					_flood(v, region)
					for c: Vector2i in region:
						seen[c] = true
					var cells_in: Array = region.keys()
					cells_in.sort()
					out.append(cells_in)
		return out

	## Add the open region containing `from` to `into`.
	func _flood (from: Vector2i, into: Dictionary) -> void:
		var stack: Array[Vector2i] = [from]
		into[from] = true
		while not stack.is_empty():
			var v: Vector2i = stack.pop_back()
			for d: Vector2i in neighbor_offsets:
				var n: Vector2i = v + d
				if is_valid(n) and not into.has(n) and _open(n):
					into[n] = true
					stack.append(n)

	func _to_rock (v: Vector2i) -> void:
		cells[v.x][v.y] = Cell.new(Type.GROUND)
		empties.erase(v)
		objects.erase(v)
		grounds.append(v)

	## Cells across and up each kind of thing takes, from its own cell (the bottom left), where that is
	## more than one cell: once a place is laid out, rock in the rest of that box is carved out
	## (make_room), so a tall doorway or portal never prints into the rock over it. Anything new and
	## big only needs its size here.
	const SIZES: Dictionary = {
		Type.EXIT: Vector2i(1, 2),
		Type.PORTAL: Vector2i(1, 2),
		Type.SHRINE: Vector2i(2, 2),
		Type.INKWELL: Vector2i(1, 2),
		Type.CHECKPOINT: Vector2i(1, 2),
		Type.RELIC: Vector2i(1, 2),
	}
	## The cells make_room carved out.
	var carved: Array[Vector2i] = []

	## Carve out the rock (and thorns) in every thing's box (see SIZES). Never a secret room's rock or
	## the rock sealing it (either would give the room away), the rock framing a door or switch gate
	## above or below it, or the rock a laser is set in.
	func make_room () -> void:
		for v: Vector2i in objects.duplicate():
			var size: Vector2i = SIZES.get(get_cell(v).type, Vector2i.ONE)
			if size == Vector2i.ONE:
				continue
			for dx: int in range(size.x):
				for dy: int in range(size.y):
					var c: Vector2i = v + Vector2i(dx, -dy)
					if c == v or not is_valid(c) or not get_cell(c).type in [Type.GROUND, Type.SPIKES]:
						continue
					if _holds_up(c):
						continue
					_to_open(c)
					carved.append(c)

	## Whether rock at `c` frames a door or gate (above or below it), seals a secret room, or has a
	## laser set in it.
	func _holds_up (c: Vector2i) -> bool:
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
			if is_valid(c + d) and get_cell(c + d).type in [Type.DOOR, Type.SWITCH_GATE]:
				return true
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not is_valid(c + d):
				continue
			var n: Cell = get_cell(c + d)
			# A laser's mount, or the rock sealing a secret room (its floor, walls and roof).
			if n.type == Type.LASER or (n.type == Type.CRACKED and n.extra_info != null):
				return true
		return false

	func _to_open (v: Vector2i) -> void:
		cells[v.x][v.y] = Cell.new(Type.EMPTY)
		grounds.erase(v)
		objects.erase(v)
		if not empties.has(v):
			empties.append(v)

	## The shrine stands on two neighbouring floor cells a short walk from the deeper exit: two
	## niches offering abilities, and a bowl for mending, side by side across both.
	func _place_shrine (spots: Array[Vector2i], chosen: Array[Vector2i], near: Vector2i) -> void:
		var standing: Dictionary = {}
		for v: Vector2i in spots:
			if not chosen.has(v) and empties.has(v):
				standing[v] = true
		var pool: Array[Vector2i] = []
		var fallback: Array[Vector2i] = []
		for v: Vector2i in standing:
			if not standing.has(v + Vector2i.RIGHT):
				continue
			var d: int = absi(v.x - near.x) + absi(v.y - near.y)
			if d >= 3 and d <= 14:
				pool.append(v)
			else:
				fallback.append(v)
		if pool.is_empty():
			if fallback.is_empty():
				return
			fallback.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return absi(a.x - near.x) + absi(a.y - near.y) < absi(b.x - near.x) + absi(b.y - near.y))
			pool = [fallback[0]]
		pool.sort()
		var at: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		shrine = at
		chosen.append(at)
		chosen.append(at + Vector2i.RIGHT)
		add_object_at(at)
		empties.erase(at + Vector2i.RIGHT)
		set_cell(at, Cell.new(Type.SHRINE))

	## A random spot passing `test` and not yet chosen; the first free spot if none pass.
	func _pick_spot (spots: Array[Vector2i], chosen: Array[Vector2i], test: Callable, strict: bool = false) -> Variant:
		var pool: Array[Vector2i] = []
		for v: Vector2i in spots:
			if not chosen.has(v) and test.call(v):
				pool.append(v)
		if pool.is_empty():
			if strict:
				return null
			for v: Vector2i in spots:
				if not chosen.has(v):
					return v
			return spots[0]
		return pool[rng.randi_range(0, pool.size() - 1)]

	## The closest standing spot to `at` (within 4 cells) that is still free.
	func _nearest_free (spots: Array[Vector2i], at: Vector2i, chosen: Array[Vector2i]) -> Variant:
		var best: Variant = null
		var best_d: int = 5
		for v: Vector2i in spots:
			var d: int = absi(v.x - at.x) + absi(v.y - at.y)
			if d > 0 and d < best_d and not chosen.has(v) and empties.has(v):
				best = v
				best_d = d
		return best

	## Turns a platform run into one moving platform (stored on its leftmost cell), if the track
	## it would sweep, 2-4 cells right or down, is open. The track is kept clear of other objects.
	func make_moving (run_cells: Array[Vector2i]) -> void:
		run_cells.sort()
		var left: Vector2i = run_cells[0]
		var axis: Vector2i = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
		var travel: int = rng.randi_range(2, 4)
		var track: Array[Vector2i] = []
		for k: int in range(1, travel + 1):
			if axis.x != 0:
				track.append(run_cells[-1] + Vector2i(k, 0))
			else:
				for c: Vector2i in run_cells:
					track.append(c + Vector2i(0, k))
		for p: Vector2i in track:
			if not is_valid(p) or get_cell(p).type != Type.EMPTY or not empties.has(p):
				return
		for p: Vector2i in track:
			empties.erase(p)
		for c: Vector2i in run_cells.slice(1):
			cells[c.x][c.y] = Cell.new(Type.EMPTY)
			objects.erase(c)
		var mover: Cell = Cell.new(Type.MOVING_PLATFORM)
		mover.extra_info = [run_cells.size(), axis, travel]
		set_cell(left, mover)

	func pop_if_random_empty (f: Callable=func(_v: Vector2i) -> bool: return true, force: bool=false) -> Variant:
		while (true):
			var i: int = rng.randi_range(0, len(empties) - 1)
			var v: Vector2i = empties[i]
			if f.bind(v).call():
				add_object_at(v)
				return v
			if not force:
				break

		return null

	func add_cell_to_container (v: Vector2i, cell: Cell) -> void:
		if cell.type == Type.EMPTY:
			empties.append(v)
		elif cell.type == Type.GROUND:
			grounds.append(v)
		else:
			objects.append(v)

	func _init (_cells: Array, def: NextWorldDef) -> void:
		rng = RandomNumberGenerator.new()
		rng.seed = def.gen_seed
		size = Vector2i(len(_cells), len(_cells[0]))
		cells = []

		for i: int in len(_cells):
			var row: Array[Cell] = []
			for j: int in len(_cells[i]):
				var cell: Cell = new_cell_by_color(_cells[i][j])
				row.append(cell)
				add_cell_to_container(Vector2i(i, j), cell)
			cells.append(row)

		def.populate(self)
		# Whatever kind of place it is, big things get room (see SIZES).
		make_room()

	## Dress an ordinary level (see NextWorldDef.populate).
	func populate_level (def: NextWorldDef) -> void:
		# One cave: every open space joined up, so everything placed below is connected to
		# everything else through open air (gates and abilities aside).
		connect_caves()
		if def.cemetery():
			carve_chasms()

		# Exits and their lanterns first, so they get the pick of the level.
		place_exits(def.depth, def.debug)
		place_side_doors(def)
		place_start_key(def)
		place_bells()
		if def.arrival_from != null:
			place_return()

		# One ink well per level stands on a floor.
		set_cell(pop_if_random_empty(ground_below, true), Cell.new(Type.INKWELL))

		if CLOSE_ONE_KEY:
			var v: Vector2i = Vector2i(6,0)
			set_cell(v, Cell.new(Type.KEY))
			add_object_at(v)
		else:
			# Keys: every colour at least once (keys are dealt colours in turn), more in bigger levels.
			for i: int in range(maxi(MapInfo.KEY_COLOR_COUNT, per_area(KEYS_PER_K))):
				set_cell(pop_if_random_empty(), Cell.new(Type.KEY))

		place_doors(per_area(DOORS_PER_K))
		place_switch_gates(maxi(1, per_area(SWITCH_GATES_PER_K)))

#		for i in range(len(empties)*0.1):
#			set_cell(pop_if_random_empty(ground_adjacent), Cell.new(Type.SPIKES))
		for i: int in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(), Cell.new(Type.COIN))


		# Platforms are laid in horizontal runs of 2-5 cells so they read as continuous ledges.
		var platform_budget: int = int(len(empties)*0.2)
		while platform_budget > 0 and len(empties) > 0:
			var start: Variant = pop_if_random_empty()
			set_cell(start, Cell.new(Type.PLATFORM))
			platform_budget -= 1
			var step: Vector2i = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(-1, 0)
			var run: Vector2i = start
			var run_cells: Array[Vector2i] = [start]
			for _j: int in range(rng.randi_range(1, 4)):
				run += step
				if platform_budget <= 0 or not is_valid(run) or get_cell(run).type != Type.EMPTY or not empties.has(run):
					break
				set_cell(run, Cell.new(Type.PLATFORM))
				add_object_at(run)
				run_cells.append(run)
				platform_budget -= 1
			if run_cells.size() <= 3 and rng.randf() < MOVING_PLATFORM_CHANCE:
				make_moving(run_cells)

		# Moons (dash resets) once the ledges are down: open air with nothing to stand on below.
		place_moons(per_area(MOONS_PER_K))

		for i: int in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.ENEMY))

		for i: int in range(len(empties)*0.1):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.SHOOTER))

		for i: int in range(per_area(LANTERNS_PER_K)):
			set_cell(pop_if_random_empty(ground_below, true), Cell.new(Type.CHECKPOINT))

		#place pairs of portals in the stage and connect them to each other
		#by telling each portal the coords of its partner in the extra_info
		for i: int in range(per_area(PORTAL_PAIRS_PER_K)):
			var pos1: Variant = pop_if_random_empty(ground_below, true)
			var pos2: Variant = pop_if_random_empty(ground_below, true)
			var portal1: Cell = Cell.new(Type.PORTAL)
			var portal2: Cell = Cell.new(Type.PORTAL)
			portal1.extra_info = pos2
			portal2.extra_info = pos1
			set_cell(pos1, portal1)
			set_cell(pos2, portal2)

		place_cracks(per_area(CRACKS_PER_K))

		# Placed last, so everything above lands where it always has.
		if def.depth >= 1:
			for i: int in range(per_area(HOPPERS_PER_K)):
				set_cell(pop_if_random_empty(ground_below, true), Cell.new(Type.HOPPER))
		if def.cemetery():
			populate_cemetery(def)
		place_cluster(def)
		place_secrets(def)

	## A cemetery's gates. Chasms are cut across long stretches of floor (CHASM_WIDTH cells across,
	## CHASM_DEPTH deep, with thorns at the bottom and rock under them): too wide to jump without a
	## move found later. Across the top of each lie the planks of a bridge (Type.BRIDGE, holding the
	## chasm's number), not there until the chasm's bell is rung (see place_bells). Each is
	## {"planks": cells, "row": the floor row, "left": the last floor cell before it, "right": the
	## first after}. Cut right after the caves are joined, so everything else lands round them.
	var chasms: Array = []
	const CHASM_WIDTH: Vector2i = Vector2i(5, 7)
	const CHASM_DEPTH: int = 2
	## Floor kept whole either side of a chasm: as much as can be, else less.
	const CHASM_SHORES: Array[int] = [4, 3, 2]
	## Open air over a chasm kept clear of ledges, lifts, moons and everything else, so nothing but
	## the bridge (or a move found later) gets you over.
	const CHASM_CLEAR: int = 4

	func carve_chasms () -> void:
		var want: int = per_area(MapInfo.CHASMS_PER_K)
		# Runs of floor: open cells with rock under them, side by side on one row.
		var runs: Array = []
		for y: int in range(1, size.y - CHASM_DEPTH - 3):
			var x: int = 0
			while x < size.x:
				if get_cell(Vector2i(x, y)).type == Type.EMPTY and is_ground(Vector2i(x, y + 1)):
					var from: int = x
					while x < size.x and get_cell(Vector2i(x, y)).type == Type.EMPTY and is_ground(Vector2i(x, y + 1)):
						x += 1
					runs.append([y, from, x - 1])
				else:
					x += 1
		var spots: Array = []
		for shore: int in CHASM_SHORES:
			for run: Array in runs:
				var y: int = run[0]
				for w: int in range(CHASM_WIDTH.x, CHASM_WIDTH.y + 1):
					for a: int in range(int(run[1]) + shore, int(run[2]) - shore - w + 2):
						# Solid rock under the whole cut, so the pit is a pit.
						var ok: bool = true
						for x: int in range(a, a + w):
							for d: int in range(1, CHASM_DEPTH + 2):
								if not is_valid(Vector2i(x, y + d)) or get_cell(Vector2i(x, y + d)).type == Type.SPIKES:
									ok = false
						if ok:
							spots.append([y, a, w])
			if not spots.is_empty():
				break
		while chasms.size() < want and not spots.is_empty():
			var pick: Array = spots[rng.randi_range(0, spots.size() - 1)]
			var y: int = pick[0]
			var a: int = pick[1]
			var w: int = pick[2]
			# Keep clear of chasms already cut.
			spots = spots.filter(func(sp: Array) -> bool: return absi(int(sp[0]) - y) > CHASM_DEPTH + 2 or int(sp[1]) + int(sp[2]) + CHASM_SHORES[0] < a or a + w + CHASM_SHORES[0] < int(sp[1]))
			var id: int = chasms.size()
			var planks: Array[Vector2i] = []
			for x: int in range(a, a + w):
				for d: int in range(1, CHASM_DEPTH + 1):
					_to_open(Vector2i(x, y + d))
				var bottom: Vector2i = Vector2i(x, y + CHASM_DEPTH + 1)
				grounds.erase(bottom)
				empties.erase(bottom)
				objects.append(bottom)
				cells[bottom.x][bottom.y] = Cell.new(Type.SPIKES)
				var under: Vector2i = bottom + Vector2i.DOWN
				if is_valid(under) and get_cell(under).type != Type.GROUND:
					_to_rock(under)
				# The pit and the air over it are kept clear (out of `empties`, so nothing is placed).
				for d: int in range(-CHASM_CLEAR, CHASM_DEPTH + 1):
					empties.erase(Vector2i(x, y + d))
				var plank: Vector2i = Vector2i(x, y + 1)
				add_object_at(plank)
				var cell: Cell = Cell.new(Type.BRIDGE)
				cell.extra_info = id
				set_cell(plank, cell)
				planks.append(plank)
			chasms.append({"planks": planks, "row": y, "left": Vector2i(a - 1, y), "right": Vector2i(a + w, y)})

	## Each chasm's bell, on the floor of the side nearer the way in, a few cells from the edge.
	func place_bells () -> void:
		var start: Vector2i = exits.get(Exit.BACK, Vector2i(-1, -1))
		var md: Callable = func(a: Vector2i, b: Vector2i) -> int: return absi(a.x - b.x) + absi(a.y - b.y)
		for id: int in range(chasms.size()):
			var chasm: Dictionary = chasms[id]
			var near_left: bool = md.call(chasm["left"], start) <= md.call(chasm["right"], start)
			var edge: Vector2i = chasm["left"] if near_left else chasm["right"]
			var away: int = -1 if near_left else 1
			var at: Variant = null
			for d: int in [2, 3, 1, 4]:
				var v: Vector2i = edge + Vector2i(away * (d - 1), 0)
				if is_valid(v) and get_cell(v).type == Type.EMPTY and empties.has(v) and ground_below(v):
					at = v
					break
			if at == null:
				continue
			add_object_at(at)
			var bell: Cell = Cell.new(Type.BELL)
			bell.extra_info = id
			set_cell(at, bell)

	## What lives in a cemetery, on top of an ordinary level's dressing (placed after the hoppers,
	## so the rest of the level lands as it would): a swarm of moths a few cells from each lantern
	## (they are drawn to a lit one, see MothSwarm) and more in the open air; banks of sleep fog
	## over floors (SleepFog); and wraiths, which drift through rock at the wizard (Wraith), never
	## near the way in.
	func populate_cemetery (def: NextWorldDef) -> void:
		var start: Vector2i = exits.get(Exit.BACK, Vector2i(-1, -1))
		var md: Callable = func(a: Vector2i, b: Vector2i) -> int: return absi(a.x - b.x) + absi(a.y - b.y)
		var air: Array[Vector2i] = []
		for v: Vector2i in empties:
			if get_cell(v).type == Type.EMPTY and _wide_open(v):
				air.append(v)
		air.sort()
		var lanterns: Array[Vector2i] = []
		for v: Vector2i in objects:
			if get_cell(v).type == Type.CHECKPOINT:
				lanterns.append(v)
		lanterns.sort()
		var swarms: Array[Vector2i] = []
		for lantern: Vector2i in lanterns:
			var near: Array[Vector2i] = air.filter(func(v: Vector2i) -> bool: return md.call(v, lantern) >= 3 and md.call(v, lantern) <= 8 and not swarms.has(v))
			if not near.is_empty():
				swarms.append(near[rng.randi_range(0, near.size() - 1)])
		for i: int in range(per_area(MOTHS_PER_K)):
			var pool: Array[Vector2i] = air.filter(func(v: Vector2i) -> bool: return swarms.all(func(q: Vector2i) -> bool: return md.call(q, v) >= 6))
			if pool.is_empty():
				break
			swarms.append(pool[rng.randi_range(0, pool.size() - 1)])
		for v: Vector2i in swarms:
			add_object_at(v)
			set_cell(v, Cell.new(Type.MOTHS))
		# Fog lies over floors with room above it, apart from one another.
		var floors: Array[Vector2i] = []
		for v: Vector2i in empties:
			if get_cell(v).type == Type.EMPTY and ground_below(v) and _open(v + Vector2i.UP) and md.call(v, start) >= 5:
				floors.append(v)
		floors.sort()
		var fogs: Array[Vector2i] = []
		for i: int in range(per_area(FOG_PER_K)):
			var pool: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return fogs.all(func(q: Vector2i) -> bool: return md.call(q, v) >= 8))
			if pool.is_empty():
				break
			var at: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
			fogs.append(at)
			add_object_at(at)
			set_cell(at, Cell.new(Type.FOG))
		# Wraiths wait in the open air, away from the way in.
		for i: int in range(per_area(WRAITHS_PER_K)):
			var pool: Array[Vector2i] = []
			for v: Vector2i in empties:
				if get_cell(v).type == Type.EMPTY and md.call(v, start) >= 10:
					pool.append(v)
			if pool.is_empty():
				break
			pool.sort()
			var at: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
			add_object_at(at)
			set_cell(at, Cell.new(Type.WRAITH))

	## The level's star cluster (worth MapInfo.cluster_value): hung in open air (as a moon is) at
	## least half the exit distance from the way in, three times as likely over thorns; failing
	## that, on the floor furthest from the way in.
	func place_cluster (def: NextWorldDef) -> void:
		var start: Vector2i = exits.get(Exit.BACK, Vector2i(-1, -1))
		@warning_ignore("integer_division")
		var far: int = MapInfo.exit_distance(def.depth) / 2
		var md: Callable = func(v: Vector2i) -> int: return absi(v.x - start.x) + absi(v.y - start.y)
		var spots: Array[Vector2i] = []
		for v: Vector2i in empties:
			if get_cell(v).type != Type.EMPTY or not _wide_open(v) or md.call(v) < far:
				continue
			spots.append(v)
			if _thorns_below(v):
				spots.append(v)
				spots.append(v)
		spots.sort()
		var at: Variant = null
		if not spots.is_empty():
			at = spots[rng.randi_range(0, spots.size() - 1)]
		else:
			var best: int = -1
			var floors: Array[Vector2i] = []
			for v: Vector2i in empties:
				if ground_below(v) and get_cell(v).type == Type.EMPTY:
					floors.append(v)
			floors.sort()
			for v: Vector2i in floors:
				if md.call(v) > best:
					best = md.call(v)
					at = v
		if at == null:
			return
		add_object_at(at)
		set_cell(at, Cell.new(Type.CLUSTER))

	## Secret rooms: pockets of rock behind a false wall (the entrance) at floor height beside a
	## floor. The room's cells and its entrance are cracked cells holding the secret's number; all
	## of them look and map as plain rock (see MapInfo.open_secret), but the entrance can be walked
	## and shot straight through. Stepping into it, a hex bolt striking the rock behind it, drifting
	## in as an astral projection or warping in opens the whole room for good, and its rewards
	## appear: the level's relic (see Relics) if it has one, and stars. Each is {"room": cells,
	## "entrance": cells, "rewards": [[cell, type, extra], ...]}; placed last of all, so the rest
	## of the level lands where it always has.
	var secrets: Array = []
	const SECRETS_PER_K: float = 0.6
	## Room sizes (cells across and up) tried in turn, biggest first.
	const SECRET_SIZES: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2)]
	const SECRET_STARS: int = 3

	func place_secrets (def: NextWorldDef) -> void:
		var want: int = per_area(SECRETS_PER_K)
		# Rooms wholly in rock first; then rooms that only need rock under them (a hidden room's
		# rock is real rock, so another side may face open air).
		for enclosed: bool in [true, false]:
			for room: Vector2i in SECRET_SIZES:
				while secrets.size() < want:
					var spots: Array = _secret_spots(room, enclosed)
					if spots.is_empty():
						break
					var pick: Array = spots[rng.randi_range(0, spots.size() - 1)]
					_carve_secret(pick[0], pick[1], def.relic if secrets.is_empty() else &"")
		# A relic with no room for a secret stands on a floor in the open instead.
		if def.relic != &"" and secrets.is_empty():
			var at: Variant = pop_if_random_empty(ground_below, true)
			var relic: Cell = Cell.new(Type.RELIC)
			relic.extra_info = def.relic
			set_cell(at, relic)
		# A skeleton key takes the place of one of the last room's stars (the one nearest its door).
		if def.skeleton:
			var placed: bool = false
			if not secrets.is_empty():
				var rewards: Array = secrets[secrets.size() - 1]["rewards"]
				for i: int in range(rewards.size() - 1, -1, -1):
					if rewards[i][1] == Type.COIN:
						rewards[i] = [rewards[i][0], Type.KEY, KeyRing.SKELETON]
						placed = true
						break
			if not placed:
				var at: Variant = pop_if_random_empty(ground_below, true)
				var key: Cell = Cell.new(Type.KEY)
				key.extra_info = KeyRing.SKELETON
				set_cell(at, key)

	## Every place a `room` (cells across and up) fits: [its rect, its entrance]. The room's floor is
	## level with a floor spot beside it, through one cell of rock (the entrance, with rock over it),
	## and the room is solid rock with rock under it (the level's edge counts as rock); when
	## `enclosed`, with a cell of rock all round it too.
	func _secret_spots (room: Vector2i, enclosed: bool) -> Array:
		var floors: Array[Vector2i] = []
		for v: Vector2i in empties:
			if ground_below(v) and get_cell(v).type == Type.EMPTY:
				floors.append(v)
		floors.sort()
		var rock: Callable = func(v: Vector2i) -> bool: return not is_valid(v) or is_ground(v)
		var out: Array = []
		for o: Vector2i in floors:
			for side: int in [-1, 1]:
				var door: Vector2i = o + Vector2i(side, 0)
				var x0: int = door.x + 1 if side > 0 else door.x - room.x
				var r: Rect2i = Rect2i(x0, o.y - room.y + 1, room.x, room.y)
				if r.position.x < 0 or r.position.y < 0 or r.end.x > size.x or r.end.y > size.y:
					continue
				var solid: bool = rock.call(door) and rock.call(door + Vector2i.UP)
				var around: Rect2i = r.grow(1) if enclosed else Rect2i(r.position, r.size + Vector2i(0, 1))
				for x: int in range(around.position.x, around.end.x):
					for y: int in range(around.position.y, around.end.y):
						if not rock.call(Vector2i(x, y)):
							solid = false
				if solid:
					out.append([r, door])
		return out

	func _carve_secret (r: Rect2i, door: Vector2i, relic: StringName) -> void:
		var id: int = secrets.size()
		var room: Array[Vector2i] = []
		for x: int in range(r.position.x, r.end.x):
			for y: int in range(r.position.y, r.end.y):
				room.append(Vector2i(x, y))
		var floor_cells: Array[Vector2i] = []
		for x: int in range(r.position.x, r.end.x):
			floor_cells.append(Vector2i(x, r.end.y - 1))
		# The far end of the floor first: the reward waits at the back of the room.
		if door.x < r.position.x:
			floor_cells.reverse()
		var rewards: Array = []
		if relic != &"":
			rewards.append([floor_cells[0], Type.RELIC, relic])
		for c: Vector2i in floor_cells:
			if rewards.size() >= SECRET_STARS + (1 if relic != &"" else 0):
				break
			if rewards.all(func(rw: Array) -> bool: return rw[0] != c):
				rewards.append([c, Type.COIN, null])
		secrets.append({"room": room, "entrance": [door], "rewards": rewards})
		for c: Vector2i in room + [door]:
			grounds.erase(c)
			objects.append(c)
			var cell: Cell = Cell.new(Type.CRACKED)
			cell.extra_info = id
			cells[c.x][c.y] = cell

	## Cracked walls: thin rock (one or two cells, open on both sides) that a hex bolt breaks.
	## Half are picked near something worth reaching (a key, lantern, exit, shrine or ink well).
	## Placed last, so they can block anything the level holds.
	func place_cracks (count: int) -> void:
		var valuable: Array[Vector2i] = []
		for v: Vector2i in objects:
			if get_cell(v).type in [Type.KEY, Type.CHECKPOINT, Type.EXIT, Type.SHRINE, Type.INKWELL]:
				valuable.append(v)
		var walls: Array[Array] = []
		var near: Array[Array] = []
		for v: Vector2i in grounds:
			if v.x < 1 or v.y < 1 or v.x >= size.x - 1 or v.y >= size.y - 1:
				continue
			for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var wall: Array = []
				if _open(v - axis) and _open(v + axis):
					wall = [v]
				elif _open(v - axis) and is_ground(v + axis) and _open(v + axis * 2):
					wall = [v, v + axis]
				if wall.is_empty():
					continue
				walls.append(wall)
				for o: Vector2i in valuable:
					if absi(o.x - v.x) + absi(o.y - v.y) <= 3:
						near.append(wall)
						break
		var placed: int = 0
		while placed < count and not walls.is_empty():
			var pool: Array[Array] = near if placed * 2 < count and not near.is_empty() else walls
			var wall: Array = pool[rng.randi_range(0, pool.size() - 1)]
			near.erase(wall)
			walls.erase(wall)
			var ok: bool = true
			for c: Vector2i in wall:
				ok = ok and is_ground(c)
			if not ok:
				continue
			for c: Vector2i in wall:
				grounds.erase(c)
				cells[c.x][c.y] = Cell.new(Type.CRACKED)
				objects.append(c)
			placed += 1

	## How many of something for this level: `per_k` per 1000 cells, at least one.
	func per_area (per_k: float) -> int:
		return maxi(1, roundi(per_k * float(size.x * size.y) / 1000.0))

	## Gates: portcullis doors across one-cell-tall corridors (rock above and below, open to both
	## sides), which the cave-joining tunnels often make. Spread out, and never right beside
	## another door.
	func place_doors (count: int) -> void:
		var spots: Array[Vector2i] = []
		for v: Vector2i in empties:
			if not keep_clear.has(v) and is_ground(v + Vector2i.UP) and is_ground(v + Vector2i.DOWN) and _open(v + Vector2i.LEFT) and _open(v + Vector2i.RIGHT) \
					and get_cell(v + Vector2i.LEFT).type == Type.EMPTY and get_cell(v + Vector2i.RIGHT).type == Type.EMPTY:
				spots.append(v)
		spots.sort()
		var placed: Array[Vector2i] = []
		while placed.size() < count and not spots.is_empty():
			var v: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
			if placed.any(func(q: Vector2i) -> bool: return absi(q.x - v.x) + absi(q.y - v.y) < 4):
				continue
			placed.append(v)
			add_object_at(v)
			set_cell(v, Cell.new(Type.DOOR))

	## Switch gates: a gate across a corridor (rock above and below, open either side, like a door)
	## and its switch on a floor reachable from the way in without passing that gate, at least
	## SWITCH_REACH cells from it, so the switch is found first and the gate opens a way (often a
	## shortcut) for good. Each records the other's cell in extra_info.
	const SWITCH_REACH: int = 8

	func place_switch_gates (count: int) -> void:
		var start: Vector2i = exits.get(Exit.BACK, Vector2i(-1, -1))
		if not is_valid(start):
			return
		var spots: Array[Vector2i] = []
		for v: Vector2i in empties:
			if not keep_clear.has(v) and is_ground(v + Vector2i.UP) and is_ground(v + Vector2i.DOWN) and _open(v + Vector2i.LEFT) and _open(v + Vector2i.RIGHT) \
					and get_cell(v + Vector2i.LEFT).type == Type.EMPTY and get_cell(v + Vector2i.RIGHT).type == Type.EMPTY:
				spots.append(v)
		spots.sort()
		var placed: Array[Vector2i] = []
		while placed.size() < count and not spots.is_empty():
			var gate: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
			if placed.any(func(q: Vector2i) -> bool: return absi(q.x - gate.x) + absi(q.y - gate.y) < 6):
				continue
			# Floors reachable from the way in with this gate shut.
			var reach: Dictionary = {start: true}
			var queue: Array[Vector2i] = [start]
			while not queue.is_empty():
				var c: Vector2i = queue.pop_back()
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = c + d
					if n != gate and _open(n) and not reach.has(n):
						reach[n] = true
						queue.append(n)
			var choices: Array[Vector2i] = []
			for v: Vector2i in reach:
				if empties.has(v) and ground_below(v) and absi(v.x - gate.x) + absi(v.y - gate.y) >= SWITCH_REACH:
					choices.append(v)
			if choices.is_empty():
				continue
			choices.sort()
			var lever: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
			placed.append(gate)
			add_object_at(gate)
			add_object_at(lever)
			var g: Cell = Cell.new(Type.SWITCH_GATE)
			g.extra_info = lever
			set_cell(gate, g)
			var s: Cell = Cell.new(Type.SWITCH)
			s.extra_info = gate
			set_cell(lever, s)

	## A level a side world leads into gets an ordinary way up as well, on a floor a few cells from
	## the way back (which leads into that world).
	func place_return () -> void:
		var start: Vector2i = exits.get(Exit.BACK, Vector2i(-1, -1))
		if not is_valid(start):
			return
		var best: Variant = null
		var best_d: int = 1 << 30
		var floors: Array[Vector2i] = []
		for v: Vector2i in empties:
			if ground_below(v):
				floors.append(v)
		floors.sort()
		for v: Vector2i in floors:
			var d: int = absi(v.x - start.x) + absi(v.y - start.y)
			if d < 4 or exits.values().any(func(e: Vector2i) -> bool: return absi(e.x - v.x) + absi(e.y - v.y) < 3):
				continue
			if d < best_d:
				best_d = d
				best = v
		if best == null:
			return
		exits[Exit.RETURN] = best
		add_object_at(best)
		var door: Cell = Cell.new(Type.EXIT)
		door.extra_info = Exit.RETURN
		set_cell(best, door)

	## A door into each side world the level deals (NextWorldDef.doors): a floor far from the way
	## in, not crowding another exit. In a debug run it is on the floor nearest the way in instead,
	## like the other exits. It is kept in `exits`, under its door number (Worlds.door).
	func place_side_doors (def: NextWorldDef) -> void:
		var start: Vector2i = exits.get(Exit.BACK, Vector2i(-1, -1))
		var floors: Array[Vector2i] = []
		for v: Vector2i in empties:
			if ground_below(v):
				floors.append(v)
		floors.sort()
		for kind: int in def.doors:
			var best: Variant = null
			var best_d: int = 1 << 30 if def.debug else -1
			for v: Vector2i in floors:
				var d: int = absi(v.x - start.x) + absi(v.y - start.y)
				if get_cell(v).type != Type.EMPTY or exits.values().any(func(e: Vector2i) -> bool: return absi(e.x - v.x) + absi(e.y - v.y) < 3):
					continue
				if (def.debug and d < best_d) or (not def.debug and d > best_d):
					best_d = d
					best = v
			if best == null:
				continue
			var at: Vector2i = best
			exits[Worlds.door(kind)] = at
			add_object_at(at)
			var door: Cell = Cell.new(Type.EXIT)
			door.extra_info = Worlds.door(kind)
			set_cell(at, door)

	## Moons only where the air is open: every cell within MOON_CLEARANCE is open, and the cell
	## below that too, with no ledge or lift in the fall below (nothing to stand on), and
	## at least MOON_SPACING apart. Air over thorns is favoured: such spots are three times as
	## likely, since a dash reset is most welcome there.
	func place_moons (count: int) -> void:
		var supports: Dictionary = _platform_footprint()
		var spots: Array[Vector2i] = []
		for v: Vector2i in empties:
			if not _wide_open(v) or _ledge_below(v, supports):
				continue
			spots.append(v)
			if _thorns_below(v):
				spots.append(v)
				spots.append(v)
		spots.sort()
		var placed: Array[Vector2i] = []
		while placed.size() < count and not spots.is_empty():
			var v: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
			if placed.any(func(q: Vector2i) -> bool: return absi(q.x - v.x) + absi(q.y - v.y) < MOON_SPACING):
				continue
			if not empties.has(v):
				continue
			placed.append(v)
			add_object_at(v)
			set_cell(v, Cell.new(Type.MOON))

	## Include every cell a lift can occupy, including its width and its whole track.
	func _platform_footprint () -> Dictionary:
		var supports: Dictionary = {}
		for v: Vector2i in objects:
			var cell: Cell = get_cell(v)
			if cell.type == Type.PLATFORM:
				supports[v] = true
			elif cell.type == Type.MOVING_PLATFORM:
				var motion: Array = cell.extra_info
				for step: int in range(int(motion[2]) + 1):
					for dx: int in range(int(motion[0])):
						supports[v + Vector2i(dx, 0) + (motion[1] as Vector2i) * step] = true
		return supports

	func _ledge_below (v: Vector2i, supports: Dictionary = {}) -> bool:
		if supports.is_empty():
			supports = _platform_footprint()
		for dx: int in range(-1, 2):
			for dy: int in range(1, size.y - v.y):
				var n: Vector2i = v + Vector2i(dx, dy)
				if not is_valid(n) or get_cell(n).type in [Type.GROUND, Type.CRACKED, Type.SPIKES]:
					break
				if supports.has(n):
					return true
		return false

	func _thorns_below (v: Vector2i) -> bool:
		for dy: int in range(1, 6):
			var n: Vector2i = v + Vector2i(0, dy)
			if not is_valid(n) or get_cell(n).type in [Type.GROUND, Type.CRACKED, Type.PLATFORM, Type.MOVING_PLATFORM]:
				return false
			if get_cell(n).type == Type.SPIKES:
				return true
		return false

	func _wide_open (v: Vector2i) -> bool:
		for dx: int in range(-MOON_CLEARANCE, MOON_CLEARANCE + 1):
			for dy: int in range(-MOON_CLEARANCE, MOON_CLEARANCE + 1):
				var n: Vector2i = v + Vector2i(dx, dy)
				if not is_valid(n) or get_cell(n).type == Type.GROUND:
					return false
		# Hanging in the air, not sitting just above a floor.
		for dy: int in range(MOON_CLEARANCE + 1, MOON_CLEARANCE + 2):
			var below: Vector2i = v + Vector2i(0, dy)
			if not is_valid(below) or get_cell(below).type == Type.GROUND:
				return false
		return true

	func _open (v: Vector2i) -> bool:
		return is_valid(v) and get_cell(v).type != Type.GROUND and get_cell(v).type != Type.CRACKED

var goal_shift: int = 0
@onready var wfc: WaveFunctionCollapse = $"../../WaveFunctionCollapse"
@onready var player: Player
# const?


const CHUNK_SIZE: int = 16

@onready var tile_map: TileMap = $"../../TileMap"

# constants for "box" to contain the generated map
## Solid rock around the level, flush against its edges (cells thick).
const BORDER: int = 3
## Open space beyond the level's own cells (none: the border rock starts at the edge).
const X_MARGIN: int = 0
const TOP_MARGIN: int = 0

@onready var wfc_thread: Thread = Thread.new()

# ------------------------------------------------------------------ Deeper: levels by (seed, depth)

static var instance: MapInfo

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null
	if wfc_thread.is_started():
		wfc_thread.wait_to_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_run()

## The place being played: for a level x is the seed and y the depth (see Worlds for the rest).
var coord: Vector2i = Vector2i.ZERO
## Its definition (set as it loads): where its exits lead, what they cost, how it prints.
var here: NextWorldDef = NextWorldDef.new().setup(Vector2i.ZERO)
## The exit the player arrives at; -1 starts a run, -2 respawns at a lantern.
var arrival: int = -1
## Where to arrive when `arrival` is -3 (a tier III rift from another level).
var arrival_pos: Vector2 = Vector2.ZERO
## The run's cross-world rift link (Rift tier III): up to two ends, each [coord, position].
var rift_link: Array = []
## What changed in each visited level (coord -> record). Levels regenerate identically, then
## their record is applied: pickups taken, doors opened, the deeper exit paid for.
var records: Dictionary = {}
var travelling: bool = false
## The last lantern lit, which may be in another level.
var respawn_coord: Vector2i = Vector2i.ZERO
var respawn_cell: Vector2i = Vector2i.ZERO
var respawn_marker: Node2D

## The seed this run started on (coord.x drifts as the player moves sideways) and the deepest
## depth reached.
var run_seed: int = 0
var deepest: int = 0
## Vulnerable means no lit lantern remains to absorb the next death. A lantern burns out
## after protecting one death; only lighting an unspent lantern restores protection.
var vulnerable: bool = false
var has_ghost: bool = false
var ghost_coord: Vector2i = Vector2i.ZERO
var ghost_pos: Vector2 = Vector2.ZERO
var ghost_stars: int = 0
var ghost_node: Node2D
## Seconds left on the end-of-run card (0 while playing).
var run_ending: float = 0.0
const RUN_END_SECONDS: float = 3.0
var ghost_prefab: Resource = preload("res://prefabs/corpse.tscn")

## Deterministic per-level seed from the run seed and depth (independent of engine hashing).
static func level_seed (run_seed: int, depth: int) -> int:
	var h: int = (run_seed * 73856093) ^ (depth * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 15)) * 0x2c1b3c6d
	h = (h ^ (h >> 12)) * 0x297a2d39
	h = h ^ (h >> 15)
	return h & 0x7fffffff

## Stars to open a level's deeper exit.
static func deeper_price (depth: int) -> int:
	return roundi(8.0 * pow(1.4, depth))

## Stars a level's star cluster is worth: about 10 at the surface, more deeper (stars per level
## grow too).
static func cluster_value (depth: int) -> int:
	return roundi(10.0 * pow(1.25, maxi(depth, 0)))

## Whether a secret room in the level at `at` holds a skeleton key: SKELETON_CHANCE % of levels
## from depth 1, dealt by the level seed.
static func skeleton_at (at: Vector2i) -> bool:
	if at.y < 1:
		return false
	return level_seed(level_seed(at.x, at.y), 4711) % 100 < SKELETON_CHANCE

## Minimum distance in cells between a level's way back and its deeper exit.
static func exit_distance (depth: int) -> int:
	return clampi(24 + 4 * depth, 24, 96)

## The key colour that locks a level's left or right exit, dealt by the level seed.
static func lateral_lock (at: Vector2i, which: int) -> int:
	return level_seed(level_seed(at.x, at.y), 500 + which) % KEY_COLOR_COUNT

## Cells across and down for a level: small near the surface, growing with depth.
static func level_size (depth: int) -> Vector2i:
	# Half the old growth (6 and 5 cells a depth, capped at 80 x 72): big levels were slow and long.
	return Vector2i(clampi(36 + 3 * depth, 36, 60), clampi(30 + (5 * depth) / 2, 30, 48))

## Stars to ink a level's whole map at its ink well.
static func map_price (depth: int) -> int:
	return roundi(4.0 * pow(1.3, depth))

## How a level is named on screen and when sharing it.
static func where (at: Vector2i) -> String:
	return def_for(at).title()

## The WFC sample for a garden level `depth` deep: its garden bands (see NextWorldDef.archetype_at)
## alternate between tunnels and islands. (A cemetery has its own, NextWorldDef.GRAVEYARD.)
static func region_for (depth: int) -> String:
	@warning_ignore("integer_division")
	var garden_band: int = (maxi(depth, 0) / NextWorldDef.BAND) / NextWorldDef.ARCHETYPES.size()
	return "res://wfc_images/levelSample3-spikes.png" if garden_band % 2 == 0 else "res://wfc_images/floating_islands.png"

func record (at: Vector2i = coord) -> Dictionary:
	if not records.has(at):
		records[at] = {"taken": {}, "opened": {}, "deeper_paid": false, "dropped": {}, "next_drop": 0, "shrine_used": false, "lateral_open": {}, "slain": {}, "broken": {}, "mapped": false}
	return records[at]

func mark_taken (node: Node) -> void:
	if node.has_meta(&"cell"):
		record()["taken"][node.get_meta(&"cell")] = true

## A key was grabbed. A generated key is recorded as taken; a dropped one leaves the record.
## The key the player was carrying (`had`, -1 for none) is left where the new one was.
func key_taken (key: Node2D, had: int) -> void:
	var rec: Dictionary = record()
	if key.has_meta(&"dropped_id"):
		(rec["dropped"] as Dictionary).erase(int(key.get_meta(&"dropped_id")))
	else:
		mark_taken(key)
	if had < 0:
		return
	var id: int = int(rec["next_drop"])
	rec["next_drop"] = id + 1
	rec["dropped"][id] = [key.position, had]
	_spawn_dropped_key.call_deferred(id, key.position, had)
	save_run()

func _spawn_dropped_key (id: int, pos: Vector2, color: int) -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	var key: Node2D = key_prefab.instantiate()
	key.set_meta(&"key_color", color)
	key.set_meta(&"dropped_id", id)
	key.position = pos
	map_elements.add_child(key)

## The keys the record keeps in this level.
func dropped_keys () -> Dictionary:
	return record()["dropped"]

## An enemy the hex bolt destroyed: gone until the player dies.
func mark_slain (node: Node) -> void:
	if node.has_meta(&"cell"):
		record()["slain"][node.get_meta(&"cell")] = true

## The bell of chasm `id` was rung: its bridge stays up for good.
func ring_bell (id: int) -> void:
	var rec: Dictionary = record()
	if not rec.has("bridges"):
		rec["bridges"] = {}
	if (rec["bridges"] as Dictionary).has(id):
		return
	rec["bridges"][id] = true
	if map_elements != null and is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			if node.has_method("raise") and int(node.get("chasm")) == id:
				node.call("raise")
	save_run()

func bridge_up (id: int) -> bool:
	return (record().get("bridges", {}) as Dictionary).has(id)

## A cracked wall broken: gone for good.
func mark_broken (node: Node) -> void:
	if node.has_meta(&"cell"):
		record()["broken"][node.get_meta(&"cell")] = true
		save_run()

# ------------------------------------------------------------------ secret rooms and relics

## The secret room (its number in World.secrets) whose unopened rock is at cell `v`, or -1.
func secret_at (v: Vector2i) -> int:
	if world == null or not world.is_valid(v):
		return -1
	var cell: Cell = world.get_cell(v)
	if cell.type != Type.CRACKED or cell.extra_info == null:
		return -1
	var id: int = int(cell.extra_info)
	return -1 if (record().get("secrets", {}) as Dictionary).has(id) else id

## Open secret room `id` for good: its rock (and entrance) crumbles, kept broken in the record,
## and its rewards appear.
func open_secret (id: int) -> void:
	if world == null or id < 0 or id >= world.secrets.size():
		return
	var rec: Dictionary = record()
	if not rec.has("secrets"):
		rec["secrets"] = {}
	if (rec["secrets"] as Dictionary).has(id):
		return
	rec["secrets"][id] = true
	var secret: Dictionary = world.secrets[id]
	var middle: Vector2 = Vector2.ZERO
	for c: Vector2i in secret["room"] + secret["entrance"]:
		rec["broken"][c] = true
		middle += cell_position(c) / float(secret["room"].size() + secret["entrance"].size())
	if map_elements != null and is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			if int(node.get_meta(&"secret", -1)) == id:
				node.queue_free()
	_spawn_secret_rewards(id)
	RisoFx.burst(&"gain", middle, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	RisoFx.burst(&"hit", middle, Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
	Wound.shake(14.0, 0.3)
	# Reprint the rock without the room.
	if RisoPrint.instance != null:
		RisoPrint.instance.world_built(self, coord.y)
	seen_version += 1
	save_run()

func _spawn_secret_rewards (id: int) -> void:
	if world == null or id < 0 or id >= world.secrets.size():
		return
	for reward: Array in world.secrets[id]["rewards"]:
		var cell: Cell = Cell.new(reward[1])
		cell.extra_info = reward[2]
		place_cell(reward[0], cell)

## Run state: the levels whose relic has been taken, and the levels an ink well has pointed to
## (coord -> the move the relic holds), shown on the worlds map.
var relics_found: Dictionary = {}
var relic_hints: Dictionary = {}

## A relic was taken in this level.
func relic_taken () -> void:
	relics_found[coord] = true
	relic_hints.erase(coord)
	save_run()

## The relic a shrine would point to: the nearest one neither found nor already marked, or null.
func next_relic () -> Variant:
	return Relics.nearest(coord, relics_found.merged(relic_hints))

## A shrine's hint: mark that relic on the worlds map. Returns its level, or null.
func hint_relic () -> Variant:
	var at: Variant = next_relic()
	if at != null:
		relic_hints[at] = Relics.at(at)
		save_run()
	return at

func mark_opened (node: Node) -> void:
	if node.has_meta(&"cell"):
		record()["opened"][node.get_meta(&"cell")] = true

## Begin a run at depth 0 of `run_seed`; its start lantern is lit.
func start_run (seed_value: int) -> void:
	run_seed = seed_value
	deepest = 0
	coord = Vector2i(seed_value, 0)
	arrival = -1
	records.clear()
	rift_link.clear()
	relics_found.clear()
	relic_hints.clear()
	if player == null:
		player = main.get_node_or_null("Player") as Player
	if player != null:
		Abilities.reset(player)
		if debug:
			player.collect(DEBUG_STARS - player.coins.coins)
	vulnerable = false
	_clear_ghost()
	_load_level()

## Leave through `exit` and arrive where the place's definition says it leads (NextWorldDef.lead).
## The exits taken are kept in the record ("ways_taken"), so the worlds map can join the places.
func travel (exit: int) -> void:
	if travelling:
		return
	var lead: Dictionary = here.lead(exit)
	if lead.is_empty():
		return
	var rec: Dictionary = record()
	if not rec.has("ways_taken"):
		rec["ways_taken"] = {}
	rec["ways_taken"][exit] = true
	var next: Vector2i = lead["to"]
	await _pass(lead["way"], next)
	coord = next
	deepest = maxi(deepest, coord.y)
	arrival = lead["arrive"]
	_load_level()

## Freeze the wizard and sweep the printed transition over the view before a level changes.
func _pass (way: Vector2, next: Vector2i) -> void:
	travelling = true
	if player == null:
		player = main.get_node_or_null("Player") as Player
	if player != null:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	if RisoTransition.instance != null:
		await RisoTransition.instance.cover(way, MapInfo.where(next))

func light_lantern (lantern: Node) -> bool:
	if travelling or run_ending > 0.0 or not lantern.has_meta(&"cell") or is_lantern_spent(lantern):
		return false
	var was_vulnerable: bool = vulnerable
	_set_respawn(coord, lantern.get_meta(&"cell"))
	vulnerable = false
	_refresh_lanterns()
	if player != null and player.has_node("Hex"):
		(player.get_node("Hex") as Hex).refill()
	if was_vulnerable:
		RisoFx.burst(&"gain", (lantern as Node2D).global_position, Vector2.ZERO, [RisoPrint.EYE, RisoPrint.GLOW])
	save_run()
	return true

## Whether the lit lantern `lantern` can be burned into the mend spell (see burn_lantern).
func can_burn (lantern: Node) -> bool:
	if travelling or run_ending > 0.0 or player == null or not is_respawn_lantern(lantern):
		return false
	var mend: Mend = player.get_node_or_null("Mend") as Mend
	return mend != null and mend.draughts() < mend.draughts_max()

## Burn the lit lantern into the mend spell: its draughts fill up, but the lantern is spent and no
## longer protects the wizard (light another to be protected again).
func burn_lantern (lantern: Node) -> bool:
	if not can_burn(lantern):
		return false
	var spent: Dictionary = record().get("spent_lanterns", {})
	spent[lantern.get_meta(&"cell")] = true
	record()["spent_lanterns"] = spent
	vulnerable = true
	(player.get_node("Mend") as Mend).refill()
	_refresh_lanterns()
	RisoFx.burst(&"gain", (lantern as Node2D).global_position, Vector2.ZERO, [RisoPrint.EYE, RisoPrint.PINK])
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"mend")
	save_run()
	return true

## Give up (the pause menu), when stuck: only while a lantern protects the wizard. It is a death
## like any other: the stars drop into a ghost and the lantern burns out, bringing them back to it.
func can_give_up () -> bool:
	return player != null and world != null and not vulnerable and not travelling and run_ending <= 0.0

func give_up () -> bool:
	if not can_give_up():
		return false
	player.health.health = player.health.max_health
	player.health.display_health()
	player.die()
	return true

func is_lantern_spent (lantern: Node) -> bool:
	return lantern.has_meta(&"cell") and (record().get("spent_lanterns", {}) as Dictionary).has(lantern.get_meta(&"cell"))

func _refresh_lanterns () -> void:
	if is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			if node is Checkpoint:
				(node as Checkpoint).refresh()

func is_respawn_lantern (lantern: Node) -> bool:
	return not vulnerable and coord == respawn_coord and lantern.has_meta(&"cell") and lantern.get_meta(&"cell") == respawn_cell and not is_lantern_spent(lantern)

## True when the last lit lantern is in another level (the player must travel to respawn).
func respawn_elsewhere () -> bool:
	return world != null and respawn_coord != coord

## Step through a tier III rift into level `to`, coming out at `at` (its end of the link).
func rift_travel (to: Vector2i, at: Vector2) -> void:
	if travelling or run_ending > 0.0:
		return
	var d: Vector2i = to - coord
	var way: Vector2 = Vector2(signf(d.x), signf(d.y)) if d != Vector2i.ZERO else Vector2.DOWN
	if absi(d.x) > 0 and absi(d.y) > 0:
		way = Vector2(0, signf(d.y))
	await _pass(way, to)
	coord = to
	deepest = maxi(deepest, coord.y)
	arrival = -3
	arrival_pos = at
	_load_level()

## Debug runs (the F7 panel's Travel rows): go straight to place `to`, a level or a side world,
## arriving at its way back. Nothing is paid or opened on the way.
func debug_travel (to: Vector2i) -> void:
	if not debug or travelling or run_ending > 0.0 or not Worlds.valid(to):
		return
	await _pass(Vector2.DOWN, to)
	coord = to
	deepest = maxi(deepest, coord.y)
	arrival = Exit.BACK
	_load_level()

func respawn_in_other_level () -> void:
	await _pass(Vector2.UP, respawn_coord)
	coord = respawn_coord
	arrival = -2
	_load_level()

func _set_respawn (at: Vector2i, cell: Vector2i) -> void:
	respawn_coord = at
	respawn_cell = cell
	if respawn_marker == null:
		respawn_marker = Node2D.new()
		respawn_marker.name = "RespawnMarker"
		main.add_child(respawn_marker)
	respawn_marker.global_position = cell_position(cell)
	if player != null:
		player.respawn = respawn_marker

# ------------------------------------------------------------------ death, the ghost, the end

## A lit lantern absorbs one death, burns out, and brings the wizard back to its location.
## Without another lit lantern, the next death ends the run. Stars still drop into a ghost.
func player_died (pos: Vector2) -> void:
	if run_ending > 0.0 or travelling:
		return
	if vulnerable:
		end_run()
		return
	_clear_ghost()
	has_ghost = true
	ghost_coord = coord
	ghost_pos = pos
	ghost_stars = player.coins.coins
	player.collect(-ghost_stars)
	var respawn_record: Dictionary = record(respawn_coord)
	var spent: Dictionary = respawn_record.get("spent_lanterns", {})
	spent[respawn_cell] = true
	respawn_record["spent_lanterns"] = spent
	vulnerable = true
	_refresh_lanterns()
	_respawn_everything()
	save_run()
	# The respawn level reloads, so its enemies are back (and the ghost appears if it is there).
	respawn_in_other_level()

## Death brings every slain enemy back.
func _respawn_everything () -> void:
	for c: Vector2i in records:
		(records[c] as Dictionary)["slain"] = {}

## Touching the ghost returns its stars. It cannot restore lantern protection.
func recover_ghost () -> void:
	if not has_ghost:
		return
	var stars: int = ghost_stars
	var at: Vector2 = ghost_pos
	_clear_ghost()
	player.collect(stars)
	RisoFx.burst(&"gain", at, Vector2.ZERO, [RisoPrint.GLOW, RisoPrint.ACCENT])
	save_run()

## The run is over: show the card, then start again at depth 0 of the run's seed with a fresh
## character and no records (the levels themselves are unchanged).
func end_run () -> void:
	if run_ending > 0.0:
		return
	delete_save()
	run_ending = RUN_END_SECONDS
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.visible = false
	while run_ending > 0.0:
		await get_tree().process_frame
		run_ending = maxf(0.0, run_ending - get_process_delta_time())
	player.collect(-player.coins.coins)
	KeyRing.clear(player)
	player.visible = true
	start_run(run_seed)

func _spawn_ghost () -> void:
	if not has_ghost or ghost_coord != coord or map_elements == null or not is_instance_valid(map_elements):
		return
	if ghost_node != null and is_instance_valid(ghost_node):
		ghost_node.queue_free()
	ghost_node = ghost_prefab.instantiate()
	ghost_node.position = ghost_pos
	ghost_node.set("stars", ghost_stars)
	map_elements.add_child(ghost_node)
	if player != null:
		player.corpse_created.emit(ghost_node)

func _clear_ghost () -> void:
	has_ghost = false
	ghost_stars = 0
	if ghost_node != null and is_instance_valid(ghost_node):
		ghost_node.queue_free()
	ghost_node = null

func cell_position (v: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(v))

# ------------------------------------------------------------------ saving

## Debug runs (from the start menu): every exit is generated right by the spawn, and the run
## starts with DEBUG_STARS. Saved with the run and shown in the HUD.
static var debug: bool = false
const DEBUG_STARS: int = 9999

## Where the run is saved. Tests point this elsewhere so they never touch a player's save.
static var save_path: String = "user://deeper_run.save"
const SAVE_VERSION: int = 2

## Autosaved on arriving in a level, lighting a lantern, dying, recovering the ghost, taking a
## key, using a shrine, pausing and quitting. Stars picked up since the last save can be lost.
func save_run () -> void:
	if player == null or world == null or run_ending > 0.0:
		return
	var tiers: Dictionary = {}
	for a: StringName in player.tiers:
		tiers[String(a)] = int(player.tiers[a])
	var data: Dictionary = {
		"version": SAVE_VERSION, "run_seed": run_seed, "deepest": deepest, "coord": coord, "records": records,
		"respawn_coord": respawn_coord, "respawn_cell": respawn_cell,
		"vulnerable": vulnerable,
		"has_ghost": has_ghost, "ghost_coord": ghost_coord, "ghost_pos": ghost_pos, "ghost_stars": ghost_stars,
		"stars": player.coins.coins, "key": int(player.get_meta(&"carried_key", -1)),
		"keys": KeyRing.all(player), "skeleton_keys": KeyRing.skeletons(player), "mend_draughts": Mend.stored(player),
		"tiers": tiers, "health": player.health.health, "debug": debug, "rift_link": rift_link,
		"relics_found": relics_found, "relic_hints": relic_hints,
	}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_var(data)

## The saved run, or {} when there is none (or it is from an older version).
static func read_save () -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if not (data is Dictionary) or int((data as Dictionary).get("version", 0)) != SAVE_VERSION:
		return {}
	return data

static func delete_save () -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

## Resume the saved run at its last lit lantern. False when there is nothing to continue.
func continue_run () -> bool:
	var data: Dictionary = read_save()
	if data.is_empty():
		return false
	if player == null:
		player = main.get_node_or_null("Player") as Player
	_clear_ghost()
	debug = bool(data.get("debug", false))
	run_seed = int(data["run_seed"])
	deepest = int(data["deepest"])
	records = data["records"]
	rift_link = data.get("rift_link", [])
	relics_found = data.get("relics_found", {})
	relic_hints = data.get("relic_hints", {})
	respawn_coord = data["respawn_coord"]
	respawn_cell = data["respawn_cell"]
	vulnerable = bool(data["vulnerable"])
	# Version-1 saves from the old recovery system remain usable: an unprotected save's
	# last lantern is spent, so resuming cannot turn it into another free life.
	if vulnerable:
		var respawn_record: Dictionary = record(respawn_coord)
		var spent: Dictionary = respawn_record.get("spent_lanterns", {})
		spent[respawn_cell] = true
		respawn_record["spent_lanterns"] = spent
	has_ghost = bool(data["has_ghost"])
	ghost_coord = data["ghost_coord"]
	ghost_pos = data["ghost_pos"]
	ghost_stars = int(data["ghost_stars"])
	player.tiers = Abilities.start_tiers()
	var tiers: Dictionary = data["tiers"]
	for a: String in tiers:
		player.tiers[StringName(a)] = int(tiers[a])
	Abilities.apply(player)
	player.health.health = clampi(int(data["health"]), 1, player.health.max_health)
	player.health.display_health()
	player.collect(int(data["stars"]) - player.coins.coins)
	# Saves from before the keyring hold one key.
	KeyRing.set_all(player, data.get("keys", [int(data["key"])]))
	KeyRing.set_skeletons(player, int(data.get("skeleton_keys", 0)))
	Mend.restore(player, int(data.get("mend_draughts", -1)))
	coord = respawn_coord
	arrival = -2
	_load_level()
	return true

# ------------------------------------------------------------------ loading and pre-generation
# One worker thread runs the WFC, one level at a time (the collapse is not shared safely).
# The level being travelled to always goes first; otherwise the worker pre-generates the
# current level's neighbours, so most transitions find their terrain already in the cache.

const CACHE_SIZE: int = 12
var cache: Dictionary = {}
var cache_order: Array[Vector2i] = []
var prefetch: Array[Vector2i] = []
## The level waiting to be shown, or null.
var wanted: Variant = null
var gen_busy: bool = false

## The definition of the place at `at`: a level, or a side world (see Worlds).
static func def_for (at: Vector2i) -> NextWorldDef:
	return Worlds.def_for(at)

func _load_level () -> void:
	travelling = true
	here = def_for(coord)
	if player == null:
		player = main.get_node_or_null("Player") as Player
	if player != null:
		player.set_physics_process(false)
		player.set_collision(false)
	wanted = coord
	var built: World = _built(coord)
	if built != null:
		wanted = null
		_level_ready.call_deferred(built)
	else:
		_pump()

## Start the worker on the wanted level, else on the next neighbour not yet cached.
func _pump () -> void:
	if gen_busy or not is_inside_tree():
		return
	var next: Variant = wanted
	while next == null and not prefetch.is_empty():
		var c: Vector2i = prefetch.pop_front()
		if _built(c) == null:
			next = c
	if next == null:
		return
	gen_busy = true
	if wfc_thread.is_started():
		wfc_thread.wait_to_finish()
	# Cells already generated are handed over, so the worker only lays the level out.
	wfc_thread.start(_generate_threaded.bind(next as Vector2i, cache.get(next, [])))

## On the worker: the level's cells (unless given) and its layout, so neither stalls a frame.
func _generate_threaded (at: Vector2i, cells: Array) -> void:
	if cells.is_empty():
		cells = wfc.generate_level(def_for(at))
	var built: World = World.new(cells, def_for(at))
	_generated.call_deferred(at, cells, built)

func _generated (at: Vector2i, cells: Array, built: World) -> void:
	if wfc_thread.is_started():
		wfc_thread.wait_to_finish()
	gen_busy = false
	# Left the scene (back to the start menu, or a test tearing down): the result is not wanted,
	# and no further work may start, or a thread would outlive this object.
	if not is_inside_tree():
		return
	_cache_put(at, cells, built)
	if wanted != null and wanted == at:
		wanted = null
		_level_ready(built)
	_pump()

## Another level's layout, for the map: the level being played, or one rebuilt from its seed
## (levels are deterministic). Null while the generator thread is busy (try again next frame).
func world_at (at: Vector2i) -> World:
	if at == coord and world != null:
		return world
	var w: World = _built(at)
	if w != null:
		return w
	var cells: Variant = cache.get(at)
	if cells == null:
		if gen_busy:
			return null
		cells = wfc.generate_level(def_for(at))
	w = World.new(cells, def_for(at))
	_cache_put(at, cells, w)
	return w

## Keep a level's cells, and its laid-out World when there is one (layouts are read-only once
## built, and depend on the debug flag, so they are kept per flag).
func _cache_put (at: Vector2i, cells: Array, built: World = null) -> void:
	cache[at] = cells
	if built != null:
		worlds[_world_key(at)] = built
	cache_order.erase(at)
	cache_order.append(at)
	while cache_order.size() > CACHE_SIZE:
		var old: Vector2i = cache_order.pop_front()
		cache.erase(old)
		worlds.erase(_world_key(old))

## Laid-out levels, by _world_key.
var worlds: Dictionary = {}

func _world_key (at: Vector2i) -> String:
	return "%s:%s" % [at, debug]

## The cached layout of level `at`, or null.
func _built (at: Vector2i) -> World:
	return worlds.get(_world_key(at))

## Queue the places the current one leads to for the worker (NextWorldDef.neighbours).
func _prefetch_neighbours () -> void:
	prefetch.clear()
	for c: Vector2i in here.neighbours():
		if not cache.has(c):
			prefetch.append(c)
	# Keep the current level from being evicted by its own neighbours.
	if cache.has(coord):
		cache_order.erase(coord)
		cache_order.append(coord)
	_pump()

func _level_ready (built: World) -> void:
	clear_terrain()
	world = built
	map = world
	if player == null:
		player = main.get_node_or_null("Player") as Player
	map_elements = map_elements_prefab.instantiate()
	main.add_child(map_elements)
	_keys_dealt = 0
	_doors_dealt = 0
	for v: Vector2i in world.objects:
		place_cell(v, world.get_cell(v))
	# Secret rooms already opened: their rewards (the rest of the room stays broken, see
	# open_secret). After everything else, so the rest of the level lands where it always has.
	for id: int in (record().get("secrets", {}) as Dictionary):
		_spawn_secret_rewards(id)
	var dropped: Dictionary = record()["dropped"]
	for id: int in dropped:
		_spawn_dropped_key(id, dropped[id][0], dropped[id][1])
	Rift.restore(self)
	_spawn_ghost()
	next_world()

# ------------------------------------------------------------------ what the map has seen
# Each level's record keeps a byte per cell: 1 once seen. The player sees a few cells around
# them as they move; a moon shard shows a whole chunk. The printed map (RisoMap) draws from it.

const SEE_RADIUS: int = 5
## Bumped whenever something new is seen, so the map knows to redraw.
var seen_version: int = 0
var _last_seen_cell: Vector2i = Vector2i(-9999, -9999)

func seen () -> PackedByteArray:
	var rec: Dictionary = record()
	var n: int = world.size.x * world.size.y if world != null else 0
	if not rec.has("seen") or (rec["seen"] as PackedByteArray).size() != n:
		var fresh: PackedByteArray = PackedByteArray()
		fresh.resize(n)
		rec["seen"] = fresh
	return rec["seen"]

func is_seen (v: Vector2i) -> bool:
	if world == null or not world.is_valid(v):
		return false
	return seen()[v.x * world.size.y + v.y] != 0

func seen_count () -> int:
	var n: int = 0
	for b: int in seen():
		n += b
	return n

## Mark every cell within `radius` of `at` as seen.
func reveal (at: Vector2i, radius: int = SEE_RADIUS) -> void:
	if world == null:
		return
	var bytes: PackedByteArray = seen()
	var changed: bool = false
	for x: int in range(at.x - radius, at.x + radius + 1):
		for y: int in range(at.y - radius, at.y + radius + 1):
			var v: Vector2i = Vector2i(x, y)
			if world.is_valid(v) and (v - at).length_squared() <= radius * radius:
				var i: int = x * world.size.y + y
				if bytes[i] == 0:
					bytes[i] = 1
					changed = true
	if changed:
		record()["seen"] = bytes
		seen_version += 1

## The ink well: the whole level inked onto the map at once.
func ink_whole_map () -> void:
	if world == null:
		return
	var bytes: PackedByteArray = seen()
	bytes.fill(1)
	record()["seen"] = bytes
	record()["mapped"] = true
	seen_version += 1
	save_run()

## The level's area in world pixels (its cells, not the rock border round them).
func level_rect () -> Rect2:
	var cell: Vector2 = Vector2(tile_map.tile_set.tile_size) * tile_map.global_scale
	var top_left: Vector2 = cell_position(Vector2i.ZERO) - cell * 0.5
	return Rect2(top_left, Vector2(world.size) * cell if world != null else cell)

## Whether world position `pos` is inside something solid: rock (or outside the level), cracked
## rock not yet broken (a secret's false wall aside), or a shut door or gate.
func solid_at (pos: Vector2) -> bool:
	if world == null:
		return false
	var v: Vector2i = cell_at(pos)
	if not world.is_valid(v):
		return true
	var cell: Cell = world.get_cell(v)
	var rec: Dictionary = record()
	match cell.type:
		Type.GROUND:
			return true
		Type.CRACKED:
			if (rec["broken"] as Dictionary).has(v):
				return false
			return cell.extra_info == null or not (world.secrets[int(cell.extra_info)]["entrance"] as Array).has(v)
		Type.DOOR, Type.SWITCH_GATE:
			return not (rec["opened"] as Dictionary).has(v)
	return false

## The level cell a world position falls in.
func cell_at (pos: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(pos))

func _physics_process (_delta: float) -> void:
	if world == null or travelling or player == null or not is_instance_valid(player):
		return
	var c: Vector2i = cell_at(player.global_position)
	if c != _last_seen_cell:
		_last_seen_cell = c
		reveal(c)
		# Stepping into a secret room's false wall (or drifting or warping into its rock) opens it.
		open_secret(secret_at(c))
	_sleep_far_chunks()


# ------------------------------------------------------------------ chunks
# The level is cut into CHUNK x CHUNK cell chunks. A few times a second, every chunk is woken or
# put to sleep by its distance from the camera: everything in a sleeping chunk stops (no
# processing, its physics bodies out of the world) and is hidden, so a big level costs about what
# its neighbourhood of the camera does (only things placed with the level; bolts, ghosts and
# rifts always run). Chunks wake with a margin past the view (wider than a
# watcher's sight) and only sleep a little further out, so nothing flickers at the edge.

const CHUNK: int = 8
## Chunks within this many pixels of the view's edge (in world pixels) are awake.
const CHUNK_WAKE: float = 640.0
const CHUNK_SLEEP: float = 896.0
const CHUNK_EVERY: int = 6
var _chunk_tick: int = 0
## Chunk -> whether it is awake.
var _chunk_awake: Dictionary = {}


func chunk_of (pos: Vector2) -> Vector2i:
	var c: Vector2i = cell_at(pos)
	return Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))


## Whether `node`'s chunk is awake (things outside every chunk's reach are asleep).
func is_awake (node: Node2D) -> bool:
	return bool(_chunk_awake.get(chunk_of(node.global_position), true))


func _sleep_far_chunks (force: bool = false, around: Vector2 = Vector2.INF) -> void:
	_chunk_tick += 1
	if not force and _chunk_tick % CHUNK_EVERY != 0:
		return
	if map_elements == null or not is_instance_valid(map_elements):
		return
	var cam: Camera2D = main.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var half: Vector2 = Vector2(get_window().content_scale_size) / cam.zoom * 0.5
	var center: Vector2 = cam.get_screen_center_position() if around == Vector2.INF else around
	var cell_px: Vector2 = Vector2(tile_map.tile_set.tile_size) * tile_map.global_scale
	var chunk_px: Vector2 = cell_px * float(CHUNK)
	var origin: Vector2 = tile_map.to_global(tile_map.map_to_local(Vector2i.ZERO)) - cell_px * 0.5
	var has_wizard: bool = player != null and is_instance_valid(player)
	var wizard: Vector2 = player.global_position if has_wizard else Vector2.ZERO
	# Wake or sleep each chunk by the gap between its rectangle and the view.
	var states: Dictionary = {}
	var size: Vector2i = world.size + Vector2i(BORDER, BORDER) * 2
	for cx: int in range(floori(-float(BORDER) / CHUNK) - 1, ceili(float(size.x) / CHUNK) + 1):
		for cy: int in range(floori(-float(BORDER) / CHUNK) - 1, ceili(float(size.y) / CHUNK) + 1):
			var key: Vector2i = Vector2i(cx, cy)
			var lo: Vector2 = origin + Vector2(key) * chunk_px
			var gap: Vector2 = (((lo + chunk_px * 0.5) - center).abs() - (chunk_px * 0.5 + half)).max(Vector2.ZERO)
			var d: float = maxf(gap.x, gap.y)
			if has_wizard:
				# Also around the wizard: the camera lags a jump (a rift, a respawn) for a moment.
				var gap_w: Vector2 = (((lo + chunk_px * 0.5) - wizard).abs() - (chunk_px * 0.5 + half)).max(Vector2.ZERO)
				d = minf(d, maxf(gap_w.x, gap_w.y))
			var was: bool = bool(_chunk_awake.get(key, false))
			states[key] = d < (CHUNK_SLEEP if was else CHUNK_WAKE)
	_chunk_awake = states
	for node: Node in map_elements.get_children():
		var n2: Node2D = node as Node2D
		# Only the level's own placed things sleep; bolts, ghosts and rifts always run.
		if n2 == null or node.is_queued_for_deletion() or not node.has_meta(&"cell"):
			continue
		var awake: bool = bool(states.get(chunk_of(n2.global_position), false))
		var mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
		if node.process_mode != mode:
			node.process_mode = mode
			n2.visible = awake

var moon_prefab: Resource = preload("res://prefabs/moon.tscn")
var inkwell_prefab: Resource = preload("res://prefabs/inkwell.tscn")
var spikes: Resource = preload("res://prefabs/spikes.tscn")
var enemy_prefab: Resource = preload("res://prefabs/mover_enemy.tscn")
var shooter_prefab: Resource = preload("res://prefabs/shooter_enemy.tscn")
var coin_prefab: Resource = preload("res://prefabs/coin.tscn")
var key_prefab: Resource = preload("res://prefabs/key.tscn")
var door_prefab: Resource = preload("res://prefabs/door.tscn")
var checkpoint_prefab: Resource = preload("res://prefabs/checkpoint.tscn")
var portal_prefab: Resource = preload("res://prefabs/portal.tscn")
var platform_prefab: Resource = preload("res://prefabs/platform.tscn")
var moving_platform_prefab: Resource = preload("res://prefabs/moving_platform.tscn")
var level_exit_prefab: Resource = preload("res://prefabs/level_exit.tscn")
var shrine_prefab: Resource = preload("res://prefabs/shrine.tscn")
var cracked_prefab: Resource = preload("res://prefabs/cracked_wall.tscn")
var switch_gate_prefab: Resource = preload("res://prefabs/switch_gate.tscn")
var switch_prefab: Resource = preload("res://prefabs/switch.tscn")
var hopper_prefab: Resource = preload("res://prefabs/hopper_enemy.tscn")
var laser_prefab: Resource = preload("res://prefabs/laser.tscn")
var relic_prefab: Resource = preload("res://prefabs/relic.tscn")
var cluster_prefab: Resource = preload("res://prefabs/star_cluster.tscn")
var moths_prefab: Resource = preload("res://prefabs/moths.tscn")
var fog_prefab: Resource = preload("res://prefabs/sleep_fog.tscn")
var wraith_prefab: Resource = preload("res://prefabs/wraith_enemy.tscn")
var bridge_prefab: Resource = preload("res://prefabs/bridge.tscn")
var bell_prefab: Resource = preload("res://prefabs/bell.tscn")

var map_elements_prefab: Resource = preload("res://prefabs/map_elements.tscn")

var basic_sprite_prefab: Resource = preload("res://prefabs/sprite_2d.tscn")
@onready var main: Node = $"/root/Main"

var world: World
var map: World

func clear_terrain() -> void:
	if world == null:
		return
	tile_map.clear()
	if map_elements != null and is_instance_valid(map_elements):
		map_elements.queue_free()

func next_world () -> void:
	construct_world()
	_last_seen_cell = Vector2i(-9999, -9999)
	if debug:
		# Debug runs see every level's whole map from the start (its ink well still works).
		var bytes: PackedByteArray = seen()
		bytes.fill(1)
		record()["seen"] = bytes
	seen_version += 1
	# Arrive at the matching exit; a new run starts at its lit start lantern, a respawn at the lantern.
	var at: Vector2i = world.exits.get(Exit.BACK, Vector2i.ZERO)
	if arrival >= 0 and world.exits.has(arrival):
		at = world.exits[arrival]
		# The side door just come through stays open behind the player: the way back is free.
		if arrival == Exit.LEFT or arrival == Exit.RIGHT:
			record()["lateral_open"][arrival] = true
	if arrival == -1:
		_set_respawn(coord, world.exit_lanterns.get(Exit.BACK, at))
	elif arrival == -2:
		at = respawn_cell
		_set_respawn(coord, respawn_cell)
	if player != null:
		player.position = arrival_pos if arrival == -3 else cell_position(at)
		player.velocity = Vector2.ZERO
		player.reset_fourier_motion()
		player.set_collision(true)
		player.set_physics_process(true)
	travelling = false
	_refresh_lanterns()
	if RisoPrint.instance != null:
		RisoPrint.instance.world_built(self, coord.y)
	if RisoTransition.instance != null:
		RisoTransition.instance.reveal()
	save_run()
	# The new level wakes around the wizard (the camera catches up next frame).
	_chunk_awake.clear()
	_sleep_far_chunks(true, player.global_position if player != null else Vector2.INF)
	_prefetch_neighbours()

var map_elements: Node
var _keys_dealt: int = 0
var _doors_dealt: int = 0

var cell_to_prefab: Dictionary = {
	Type.MOON: moon_prefab,
	Type.INKWELL: inkwell_prefab,
	Type.SPIKES: spikes,
	Type.ENEMY: enemy_prefab,
	Type.SHOOTER: shooter_prefab,
	Type.COIN: coin_prefab,
	Type.KEY: key_prefab,
	Type.DOOR: door_prefab,
	Type.SWITCH_GATE: switch_gate_prefab,
	Type.SWITCH: switch_prefab,
	Type.CHECKPOINT: checkpoint_prefab,
	Type.PORTAL: portal_prefab,
	Type.PLATFORM: platform_prefab,
	Type.MOVING_PLATFORM: moving_platform_prefab,
	Type.EXIT: level_exit_prefab,
	Type.SHRINE: shrine_prefab,
	Type.CRACKED: cracked_prefab,
	Type.HOPPER: hopper_prefab,
	Type.LASER: laser_prefab,
	Type.RELIC: relic_prefab,
	Type.CLUSTER: cluster_prefab,
	Type.MOTHS: moths_prefab,
	Type.FOG: fog_prefab,
	Type.WRAITH: wraith_prefab,
	Type.BRIDGE: bridge_prefab,
	Type.BELL: bell_prefab,
}

func place_cell(v: Vector2i, _cell: Cell) -> void:
	# Everything that draws from the level's RNG or counters happens before the record can skip
	# the object, so the rest of the level lands in the same place on every visit.
	var jitter: Vector2 = Vector2.ZERO
	if _cell.type in [Type.COIN, Type.KEY, Type.MOON]:
		# Floating pickups sit anywhere inside their cell rather than on the grid.
		var cell_size: Vector2 = Vector2(tile_map.tile_set.tile_size) * tile_map.global_scale
		jitter = Vector2(world.rng.randf_range(-0.3, 0.3), world.rng.randf_range(-0.3, 0.3)) * cell_size
	var color: int = -1
	if _cell.type == Type.KEY:
		# A key laid for a particular lock (the start's side door) keeps its colour; the rest are
		# dealt colours in turn.
		if _cell.extra_info != null:
			color = int(_cell.extra_info)
		else:
			color = _keys_dealt % KEY_COLOR_COUNT
			_keys_dealt += 1
	elif _cell.type == Type.DOOR:
		color = _doors_dealt % KEY_COLOR_COUNT
		_doors_dealt += 1
	var rec: Dictionary = record()
	for gone: String in ["taken", "opened", "slain", "broken"]:
		# Broken only ever means cracked rock: a secret room's rewards stand on its broken cells.
		if (gone != "broken" or _cell.type == Type.CRACKED) and (rec.get(gone, {}) as Dictionary).has(v):
			return
	var cell: Node = cell_to_prefab[_cell.type].instantiate()
	cell.set_meta(&"cell", v)
	if _cell.type == Type.CRACKED and _cell.extra_info != null:
		# Part of a secret room: hidden rock, or its entrance, a false wall that looks like rock but
		# is walked (and shot) straight through.
		cell.set_meta(&"secret", int(_cell.extra_info))
		cell.set_meta(&"hidden", not (world.secrets[int(_cell.extra_info)]["entrance"] as Array).has(v))
		if not bool(cell.get_meta(&"hidden")):
			(cell as CollisionObject2D).collision_layer = 0
	if color >= 0:
		cell.set_meta(&"key_color", color)
	if _cell.type == Type.CLUSTER:
		cell.set("value", cluster_value(here.depth))
	if _cell.type in [Type.ENEMY, Type.SHOOTER, Type.HOPPER, Type.WRAITH]:
		var wound: Wound = Wound.new()
		wound.name = "Wound"
		wound.hp = Wound.hp_for(here.depth)
		cell.add_child(wound)
		cell.add_to_group(&"hex_target")
	map_elements.add_child(cell)
	cell.set_owner(map_elements)
	cell.position = tile_map.to_global(tile_map.map_to_local(v)) + jitter

	if cell.has_method("setup"):
		# A key's extra info is its colour, already given as key_color; a cracked cell's is its secret.
		if _cell.extra_info != null and _cell.type != Type.KEY and _cell.type != Type.CRACKED:
			cell.setup(self, v, _cell.extra_info)
		else:
			cell.setup(self, v)

func construct_world() -> void:
	_lay_rock(world.grounds)

	enclose_map(world.size.x, world.size.y)

	if not RisoPrint.is_on():
		draw_background(world.size.x, world.size.y)

## The rock in `cells`. With the print on, its art is printed over the TileMap, so each cell gets
## the plain centre tile (every rock tile has the same full-square collision): autotiling the rock
## was the slowest part of loading a big level. With the print off, the autotiled sprites show.
const PLAIN_ROCK: Vector2i = Vector2i(1, 1)

func _lay_rock (cells: Array[Vector2i]) -> void:
	if RisoPrint.is_on():
		for v: Vector2i in cells:
			tile_map.set_cell(0, v, 0, PLAIN_ROCK)
	else:
		tile_map.set_cells_terrain_connect(0, cells, 0, 0)

## The print was switched off: autotile the rock that was laid plain, and draw the background.
func retile_for_sprites () -> void:
	if world == null:
		return
	var rock: Array[Vector2i] = []
	for v: Vector2i in tile_map.get_used_cells(0):
		rock.append(v)
	tile_map.set_cells_terrain_connect(0, rock, 0, 0)
	draw_background(world.size.x, world.size.y)

func get_max_bounds () -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(Vector2i(world.size.x - 1, world.size.y - 1)))

func get_min_bounds () -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(Vector2i(0, 0)))

func in_bounds (v: Vector2) -> bool:
	#	world.size.x, world.size.y
	var max_bounds: Vector2 = get_max_bounds()
	var min_bounds: Vector2 = get_min_bounds()

	if v.x > max_bounds.x or v.y > max_bounds.y:
		return false
	if v.x < min_bounds.x or v.y < min_bounds.y:
		return false

	return true

func clamp_bounds (v: Vector2) -> Vector2:
	var max_bounds: Vector2 = get_max_bounds()
	var min_bounds: Vector2 = get_min_bounds()

	return Vector2(clamp(v.x, min_bounds.x, max_bounds.x), clamp(v.y, min_bounds.y, max_bounds.y))

# Draw on the layer behind the foreground tiles
# We assume negative y values are sky and positive are dirt
func draw_background(dim_x: int, dim_y: int) -> void:
	for i: int in range(-X_MARGIN, dim_x + X_MARGIN):
		for j: int in range(-TOP_MARGIN, dim_y):
			# arg1: layer, layer 1 is the Background layer
			# arg2: location
			# arg3: source_id, the tileset source_id for which ID:1 is the background tiles on this tilemap
			# arg4: atlas coords, the tile by grid location in the atlas, (0,0) is dirt, (1,0) is sky
			tile_map.set_cell(1, Vector2i(i, j), 1, Vector2i(1 if j < 0 else 0, 0))

# Enclose the level in solid rock, BORDER cells thick and flush against its edges, so it reads as
# a cave cut into rock rather than a box drawn round it. The camera stops at the rock.
func enclose_map(dim_x: int, dim_y: int) -> void:
	var rock: Array[Vector2i] = []
	for i: int in range(-BORDER, dim_x + BORDER):
		for j: int in range(-BORDER, dim_y + BORDER):
			if i < 0 or j < 0 or i >= dim_x or j >= dim_y:
				rock.append(Vector2i(i, j))
	_lay_rock(rock)
	_fit_camera(dim_x, dim_y)

## Keep the camera inside the level plus one cell of its border rock.
func _fit_camera(dim_x: int, dim_y: int) -> void:
	var cam: Camera2D = main.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var cell: Vector2 = Vector2(tile_map.tile_set.tile_size) * tile_map.global_scale
	var top_left: Vector2 = tile_map.to_global(tile_map.map_to_local(Vector2i(-1, -1))) - cell * 0.5
	var bottom_right: Vector2 = tile_map.to_global(tile_map.map_to_local(Vector2i(dim_x, dim_y))) + cell * 0.5
	cam.limit_left = int(top_left.x)
	cam.limit_top = int(top_left.y)
	cam.limit_right = int(bottom_right.x)
	cam.limit_bottom = int(bottom_right.y)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Debug-Back"):
		travel(Exit.BACK)
