extends Control

class_name MapInfo

const CLOSE_ONE_KEY: bool = false
const CODE_LENGTH: int = 4 # 8 is more reasonable
## Keys and doors come in this many colours; a key opens doors of its own colour.
const KEY_COLOR_COUNT: int = 4
## How common each key colour is, in order of rarity: sun (about 62 %), ember (24 %), moss (10 %),
## then plum (about one in 30). Keys, corridor doors, side-door locks and padlocks are all dealt by these
## weights (see rarity_color), so a common key opens a lot and a rare one seldom; vaults (see
## World.place_vaults) are the exception, and pay out by their lock's rarity.
const KEY_RARITY: Array[int] = [18, 7, 3, 1]
## Counts per 1000 cells of level, so a level's contents scale with its size (see per_area).
## Keys are scarce: KEYS_PER_K, at least KEYS_MIN (World.key_count). Spots are still drawn for
## KEY_SPOTS_PER_K (at least one per colour), as they always were, so the rest of the level lands
## where it did; once it is laid out only the first key_count of them keep their key (deal_colors).
const KEYS_PER_K: float = 1.0
const KEYS_MIN: int = 2
const KEY_SPOTS_PER_K: float = 2.0
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
const FOG_PER_K: float = 2.0
const WRAITHS_PER_K: float = 0.9
## A cemetery's gates: chasms cut across its floors, bridged by planks that only appear once their
## bell is rung (see World.carve_chasms, Bell, Bridge), per 1000 cells (at least CHASMS_MIN, as
## many as fit).
const CHASMS_PER_K: float = 1.2
const CHASMS_MIN: int = 2
## Sky levels (NextWorldDef.archetype) have chasms too, crossed on the wind a vane sets blowing
## (Vane, Wind). On top of that: jump pads on floors (Pad) and updrafts up open shafts (Wind), per
## 1000 cells; the share of ledge runs that are clouds giving way under you (Puff); and the shares
## of wisps and hoppers carrying a shield (Shield) and of watchers whose shots rebound (bullet.gd).
const PADS_PER_K: float = 1.5
const UPDRAFTS_PER_K: float = 0.8
const PUFF_SHARE: float = 0.5
const SHIELD_SHARE: float = 0.4
## Every watcher in the sky fires rebounding shots, and there are this many more of them.
const BOUNCE_SHARE: float = 1.0
const SKY_WATCHERS_PER_K: float = 1.2
## Swooping birds (Bird) patrolling stretches of open sky.
const BIRDS_PER_K: float = 0.9
## Hits a shield takes before it breaks (a parried shot breaks it at once), and the walls a
## rebounding shot bounces off before it bursts.
const SHIELD_HP: int = 3
const BOUNCES: int = 2

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
	PAD,
	PUFF,
	VANE,
	WIND,
	BIRD,
}

## A level's ways out. Deeper and back move along the seed's column; left and right step to the
## neighbouring seed at the same depth, as if a run had started there; a level a side world leads
## into has an ordinary way up as well (RETURN). Where each leads is up to the place's definition
## (NextWorldDef.lead); doors into side worlds are numbered from Worlds.DOOR_BASE.
enum Exit { DEEPER, BACK, LEFT, RIGHT, RETURN }

class Cell:
	var type: Type = Type.GROUND
	var extra_info: Variant = null
	## How an enemy here differs from the usual: {"shield": hits} (Shield), {"bounces": walls}
	## (a watcher's rebounding shots).
	var mods: Dictionary = {}

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
	## The start key's cell (see place_start_key), or (-1, -1).
	var start_key: Vector2i = Vector2i(-1, -1)
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
			start_key = at
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
	## the rock sealing it (either would give the room away), a vault's walls, the rock framing a door
	## or switch gate above or below it, or the rock a laser is set in.
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

	## Whether rock at `c` walls a vault, frames a door or gate (above or below it), seals a secret
	## room, has a laser set in it, is the footing of a gap's shore, or holds up something stood at.
	func _holds_up (c: Vector2i) -> bool:
		if vault_walls.has(c):
			return true
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
			if is_valid(c + d) and get_cell(c + d).type in [Type.DOOR, Type.SWITCH_GATE]:
				return true
		if is_valid(c + Vector2i.UP) and get_cell(c + Vector2i.UP).type in MapInfo.STANDERS:
			return true
		for chasm: Dictionary in chasms:
			if c == (chasm["left"] as Vector2i) + Vector2i.DOWN or c == (chasm["right"] as Vector2i) + Vector2i.DOWN:
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

	## How far apart (cells, across plus down) the two ends of a pair of teleporters are at least: a
	## quarter of the level's width and height together, at least PORTAL_APART.
	const PORTAL_APART: int = 12

	func portal_apart () -> int:
		@warning_ignore("integer_division")
		return maxi(PORTAL_APART, (size.x + size.y) / 4)

	## A random empty cell passing `f`, taken out of `empties` (into `objects`), or null. Unforced, it
	## draws once; forced, it keeps drawing, and after FORCE_DRAWS misses takes the first match in
	## order, or gives up (null) if no cell passes (a sparse sky level can run out of floors).
	const FORCE_DRAWS: int = 200

	func pop_if_random_empty (f: Callable=func(_v: Vector2i) -> bool: return true, force: bool=false) -> Variant:
		if empties.is_empty():
			return null
		for draw: int in range(FORCE_DRAWS if force else 1):
			var i: int = rng.randi_range(0, len(empties) - 1)
			var v: Vector2i = empties[i]
			if f.bind(v).call():
				add_object_at(v)
				return v
		if force:
			for v: Vector2i in empties:
				if f.bind(v).call():
					add_object_at(v)
					return v
		return null

	func add_cell_to_container (v: Vector2i, cell: Cell) -> void:
		if cell.type == Type.EMPTY:
			empties.append(v)
		elif cell.type == Type.GROUND:
			grounds.append(v)
		else:
			objects.append(v)

	## The level's seed, which deals its key and door colours (deal_colors).
	var seed_for_colors: int = 0

	func _init (_cells: Array, def: NextWorldDef) -> void:
		rng = RandomNumberGenerator.new()
		rng.seed = def.gen_seed
		seed_for_colors = def.gen_seed
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
		deal_colors()

	## Salts for the level seed when dealing key and door colours (deal_colors).
	const KEY_DEAL: int = 7000
	const DOOR_DEAL: int = 8000

	## How many keys a level keeps (besides the start key and skeleton keys): MapInfo.KEYS_PER_K,
	## at least MapInfo.KEYS_MIN.
	func key_count () -> int:
		return maxi(MapInfo.KEYS_MIN, per_area(MapInfo.KEYS_PER_K))

	## Every key and corridor door not laid for a particular lock is dealt its colour by rarity
	## (MapInfo.rarity_color), from the level's seed and its place in the order things were laid,
	## never from the world RNG. The level's first key is always the commonest colour, so every level
	## holds a key to its commonest doors. The colour is kept as the cell's extra_info. Only the first
	## key_count keys are kept; the spots of the rest are left open air. Done last, so it changes no
	## placement.
	func deal_colors () -> void:
		var keys: int = 0
		var doors: int = 0
		var spare: Array[Vector2i] = []
		for v: Vector2i in objects:
			var cell: Cell = get_cell(v)
			if cell.extra_info != null:
				continue
			if cell.type == Type.KEY:
				if keys >= key_count():
					spare.append(v)
					continue
				cell.extra_info = 0 if keys == 0 else MapInfo.rarity_color(MapInfo.level_seed(seed_for_colors, KEY_DEAL + keys))
				keys += 1
			elif cell.type == Type.DOOR:
				cell.extra_info = MapInfo.rarity_color(MapInfo.level_seed(seed_for_colors, DOOR_DEAL + doors))
				doors += 1
		for v: Vector2i in spare:
			_to_open(v)

	## Dress an ordinary level (see NextWorldDef.populate).
	func populate_level (def: NextWorldDef) -> void:
		sky = def.sky()
		if sky:
			cluster_islands()
			map_isles()
		# One cave: every open space joined up, so everything placed below is connected to
		# everything else through open air (gates and abilities aside).
		connect_caves()
		if def.chasmed():
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
			# Spots for keys: more than are kept (see MapInfo.KEYS_PER_K and deal_colors).
			for i: int in range(maxi(MapInfo.KEY_COLOR_COUNT, per_area(MapInfo.KEY_SPOTS_PER_K))):
				set_cell(pop_if_random_empty(), Cell.new(Type.KEY))

		place_doors(per_area(DOORS_PER_K))
		place_switch_gates(maxi(1, per_area(SWITCH_GATES_PER_K)))

#		for i in range(len(empties)*0.1):
#			set_cell(pop_if_random_empty(ground_adjacent), Cell.new(Type.SPIKES))
		# Stars: in the sky, only in and near the clusters of islands.
		for i: int in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(func(v: Vector2i) -> bool: return not sky or in_isle(v, 3)), Cell.new(Type.COIN))


		# Platforms are laid in horizontal runs of 2-5 cells so they read as continuous ledges.
		# In the sky, only in and about the clusters of islands, so the gaps between stay open.
		var ledge_room: Callable = func(v: Vector2i) -> bool: return not sky or in_isle(v, 1)
		var platform_budget: int = int(float(empties.filter(ledge_room).size()) * 0.2)
		while platform_budget > 0 and len(empties) > 0:
			var start: Variant = pop_if_random_empty(ledge_room)
			platform_budget -= 1
			if start == null:
				continue
			set_cell(start, Cell.new(Type.PLATFORM))
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
		# The two ends of a pair at least portal_apart() cells apart (no pair where no floor is that far).
		var apart: int = portal_apart()
		for i: int in range(per_area(PORTAL_PAIRS_PER_K)):
			var pos1: Variant = pop_if_random_empty(ground_below, true)
			var pos2: Variant = null
			if pos1 != null:
				var first: Vector2i = pos1
				pos2 = pop_if_random_empty(func(v: Vector2i) -> bool: return ground_below(v) and absi(v.x - first.x) + absi(v.y - first.y) >= apart, true)
			# Out of floors for a pair (a sparse sky level): no more portals.
			if pos1 == null or pos2 == null:
				if pos1 != null:
					_to_open(pos1)
				break
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
		if def.sky():
			populate_sky(def)
		place_cluster(def)
		place_secrets(def)
		place_vaults()

	## A cemetery's gates. Chasms are cut across long stretches of floor (CHASM_WIDTH cells across,
	## CHASM_DEPTH deep, with thorns at the bottom and rock under them): too wide to jump without a
	## move found later. Across the top of each lie the planks of a bridge (Type.BRIDGE, holding the
	## chasm's number), not there until the chasm's bell is rung (see place_bells). Each is
	## {"planks": cells, "row": the floor row, "left": the last floor cell before it, "right": the
	## first after}. Cut right after the caves are joined, so everything else lands round them.
	var chasms: Array = []
	## A sky level: its chasms are crossed on a vane's wind (one current over each, Type.WIND), not a
	## bridge, and its vanes stand where a cemetery's bells would.
	var sky: bool = false
	const CHASM_WIDTH: Vector2i = Vector2i(8, 10)
	const CHASM_DEPTH: int = 2
	## Floor kept whole either side of a chasm: as much as can be, else less.
	const CHASM_SHORES: Array[int] = [4, 3, 2]
	## Open air over a chasm kept clear of ledges, lifts, moons and everything else, so nothing but
	## the bridge (or a move found later) gets you over.
	const CHASM_CLEAR: int = 4

	func carve_chasms () -> void:
		var want: int = maxi(MapInfo.CHASMS_MIN, per_area(MapInfo.CHASMS_PER_K))
		# The sky's islands are too small and scattered for long floors to cut into: it takes the
		# gaps between them that are already wide enough, then builds the rest (_build_gaps).
		if sky:
			_span_gaps(want)
			_build_gaps(want)
			# Shores laid and air cleared can shut off a pocket of air: join (or fill) it again.
			connect_caves()
			# Joining pockets can tunnel through a shore's footing (the islands' keels leave many
			# pockets): every gap's two shores get rock under them and air on and over them again.
			for chasm: Dictionary in chasms:
				for shore: Vector2i in [chasm["left"], chasm["right"]]:
					if not is_ground(shore + Vector2i.DOWN):
						_to_rock(shore + Vector2i.DOWN)
					for d: Vector2i in [Vector2i.ZERO, Vector2i.UP]:
						if is_ground(shore + d):
							_to_open(shore + d)
			return
		# Which cells are floors (open, with rock under), looked up many times below.
		_floors = PackedByteArray()
		_floors.resize(size.x * size.y)
		for v: Vector2i in empties:
			if get_cell(v).type == Type.EMPTY and is_ground(v + Vector2i.DOWN):
				_floors[v.x * size.y + v.y] = 1
		# Spots for each width of shore, widest first: a chasm takes the widest shores left. A spot
		# is a stretch of floor (shore, chasm, shore) whose every column has its floor within a cell
		# of one row: cutting it levels the floor to that row (see _level_floor), so the graveyard's
		# stepping terraces still have room for wide chasms.
		var by_shore: Array = []
		for shore: int in CHASM_SHORES:
			var spots: Array = []
			for y: int in range(2, size.y - CHASM_DEPTH - 3):
				for w: int in range(CHASM_WIDTH.x, CHASM_WIDTH.y + 1):
					for a: int in range(shore, size.x - shore - w + 1):
						var ok: bool = true
						for x: int in range(a - shore, a + w + shore):
							if _floor_near(x, y) == -1:
								ok = false
								break
						if not ok:
							continue
						# Under the cut, nothing but rock or air (no thorns), down to the pit's floor.
						for x: int in range(a, a + w):
							for d: int in range(1, CHASM_DEPTH + 2):
								if not is_valid(Vector2i(x, y + d)) or get_cell(Vector2i(x, y + d)).type == Type.SPIKES:
									ok = false
						if ok:
							spots.append([y, a, w, shore])
			by_shore.append(spots)
		while chasms.size() < want:
			var spots: Array = []
			for list: Array in by_shore:
				if not list.is_empty():
					spots = list
					break
			if spots.is_empty():
				break
			var pick: Array = spots[rng.randi_range(0, spots.size() - 1)]
			var y: int = pick[0]
			var a: int = pick[1]
			var w: int = pick[2]
			var shore: int = pick[3]
			for x: int in range(a - shore, a + w + shore):
				_level_floor(x, y)
			# Keep clear of chasms already cut.
			for i: int in range(by_shore.size()):
				by_shore[i] = (by_shore[i] as Array).filter(func(sp: Array) -> bool: return absi(int(sp[0]) - y) > CHASM_DEPTH + 2 or int(sp[1]) + int(sp[2]) + CHASM_SHORES[0] < a or a + w + CHASM_SHORES[0] < int(sp[1]))
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
				if sky:
					planks.append(plank)
					# One current spans the chasm, held in its first cell: {chasm, width}.
					if x == a:
						add_object_at(plank)
						var gust: Cell = Cell.new(Type.WIND)
						gust.extra_info = {"chasm": id, "width": w}
						set_cell(plank, gust)
					continue
				add_object_at(plank)
				var cell: Cell = Cell.new(Type.BRIDGE)
				cell.extra_info = id
				set_cell(plank, cell)
				planks.append(plank)
			chasms.append({"planks": planks, "row": y, "left": Vector2i(a - 1, y), "right": Vector2i(a + w, y)})

	## Shore kept whole either side of an island gap taken as a chasm, and the narrowest gap taken
	## (a run, a jump and a dash cover under 6 cells).
	const GAP_SHORE: int = 2
	const GAP_MIN: int = 7

	## Sky levels: gaps between islands already about as wide as a chasm (GAP_MIN to CHASM_WIDTH and
	## a cell or two more), from the end of one floor (GAP_SHORE cells of it) to the start of the next
	## on the same row or the one below, with nothing but open air across the gap from the row over
	## the floor to the row under it: a drop. Taken as chasms (crossed on a vane's wind) before any
	## is cut, up to `want`. Each is laid out as a cut chasm is, its first cell the row under the
	## floor.
	func _span_gaps (want: int) -> void:
		var floor_at: Callable = func(v: Vector2i) -> bool: return is_valid(v) and get_cell(v).type == Type.EMPTY and is_ground(v + Vector2i.DOWN) and _open(v + Vector2i.UP)
		var air: Callable = func(v: Vector2i) -> bool: return is_valid(v) and get_cell(v).type == Type.EMPTY
		var found: Array = []
		for y: int in range(3, size.y - 3):
			for l: int in range(GAP_SHORE, size.x - 1):
				var left: Vector2i = Vector2i(l, y)
				var ok: bool = true
				for k: int in range(GAP_SHORE):
					ok = ok and floor_at.call(left - Vector2i(k, 0))
				if not ok or floor_at.call(left + Vector2i.RIGHT):
					continue
				# Across: open air in every column until the next floor on this row or the next.
				var x: int = l + 1
				var land: int = -1
				while x < size.x:
					if floor_at.call(Vector2i(x, y)):
						land = y
						break
					if floor_at.call(Vector2i(x, y + 1)):
						land = y + 1
						break
					var clear: bool = true
					for d: int in range(-1, 2):
						clear = clear and air.call(Vector2i(x, y + d))
					if not clear:
						break
					x += 1
				var w: int = x - l - 1
				if land < 0 or w < GAP_MIN or w > CHASM_WIDTH.y + 2:
					continue
				for k: int in range(GAP_SHORE):
					ok = ok and floor_at.call(Vector2i(x + k, land))
				if ok:
					found.append([y, l + 1, w])
		found.sort()
		while chasms.size() < want and not found.is_empty():
			var pick: Array = found[rng.randi_range(0, found.size() - 1)]
			var y: int = pick[0]
			var a: int = pick[1]
			var w: int = pick[2]
			found = _apart(found, y, a, w)
			# A gust holds its passenger level. Bring the landing shore up to that row, so a
			# lower shelf with rock behind it cannot trap them against its wall in midair.
			for x: int in range(a + w, a + w + GAP_SHORE):
				_to_open(Vector2i(x, y - 1))
				_to_open(Vector2i(x, y))
				_to_rock(Vector2i(x, y + 1))
			var id: int = chasms.size()
			var planks: Array[Vector2i] = []
			for x: int in range(a, a + w):
				planks.append(Vector2i(x, y + 1))
				# The air over the gap is kept clear, as over a cut chasm.
				for d: int in range(-CHASM_CLEAR, CHASM_DEPTH + 1):
					empties.erase(Vector2i(x, y + d))
			add_object_at(planks[0])
			var gust: Cell = Cell.new(Type.WIND)
			gust.extra_info = {"chasm": id, "width": w}
			set_cell(planks[0], gust)
			chasms.append({"planks": planks, "row": y, "left": Vector2i(a - 1, y), "right": Vector2i(a + w, y)})

	## The sky's islands come in clusters with wide gaps of open air between (cluster_islands): each
	## [centre, radii] of an ellipse of the collapsed islands kept, the rest of the rock cleared.
	var isles: Array = []
	const ISLE_RX: Vector2i = Vector2i(6, 9)
	const ISLE_RY: Vector2i = Vector2i(4, 6)
	## The cells a causeway or its updraft uses (stones, the air over them, the shaft): kept as they are
	## by everything built after (the gaps, _build_gaps).
	var lanes: Dictionary = {}
	## Causeways laid (link_isles): one fewer than the clusters when every cluster is reached.
	var links: int = 0
	## Open air at least this wide between clusters side by side, or this tall between stacked ones.
	const ISLE_GAP: Vector2i = Vector2i(4, 3)
	## A cluster with less rock than this share of its area gets more islands (_stamp_islands).
	const ISLE_ROCK: float = 0.42

	## Per cell, the least growth (0..ISLE_REACH) of some cluster's ellipse that takes it in, 255 if
	## none does (map_isles): in_isle looks it up once the clusters are settled.
	var _isle_map: PackedByteArray = PackedByteArray()
	const ISLE_REACH: int = 5

	func map_isles () -> void:
		_isle_map = PackedByteArray()
		_isle_map.resize(size.x * size.y)
		_isle_map.fill(255)
		for isle: Array in isles:
			var c: Vector2i = isle[0]
			var r: Vector2i = isle[1]
			for x: int in range(maxi(0, c.x - r.x - ISLE_REACH), mini(size.x, c.x + r.x + ISLE_REACH + 1)):
				for y: int in range(maxi(0, c.y - r.y - ISLE_REACH), mini(size.y, c.y + r.y + ISLE_REACH + 1)):
					var i: int = x * size.y + y
					for g: int in range(0, mini(ISLE_REACH, _isle_map[i]) + 1):
						var d: Vector2 = Vector2(float(x - c.x) / float(r.x + g), float(y - c.y) / float(r.y + g))
						if d.length_squared() <= 1.0:
							_isle_map[i] = g
							break

	## Whether `v` lies in a cluster of islands (its ellipse grown by `grow` cells).
	func in_isle (v: Vector2i, grow: int = 0) -> bool:
		if not _isle_map.is_empty() and grow <= ISLE_REACH:
			return is_valid(v) and _isle_map[v.x * size.y + v.y] <= grow
		for isle: Array in isles:
			var c: Vector2i = isle[0]
			var r: Vector2i = isle[1] + Vector2i(grow, grow)
			var d: Vector2 = Vector2(float(v.x - c.x) / float(r.x), float(v.y - c.y) / float(r.y))
			if d.length_squared() <= 1.0:
				return true
		return false

	## Sky levels: keep the collapsed islands only in clusters (ellipses ISLE_RX by ISLE_RY cells,
	## thrown at random and kept ISLE_GAP apart), clearing the rest to open air; fill out a thin
	## cluster with more islands (_stamp_islands); then link the clusters (link_isles).
	func cluster_islands () -> void:
		for attempt: int in range(maxi(600, size.x * size.y / 4)):
			var r: Vector2i = Vector2i(rng.randi_range(ISLE_RX.x, ISLE_RX.y), rng.randi_range(ISLE_RY.x, ISLE_RY.y))
			if size.x - 2 * r.x - 4 <= 0 or size.y - 2 * r.y - 6 <= 0:
				continue
			var c: Vector2i = Vector2i(rng.randi_range(r.x + 2, size.x - r.x - 3), rng.randi_range(r.y + 2, size.y - r.y - 4))
			var apart: bool = true
			for isle: Array in isles:
				var o: Vector2i = isle[0]
				var q: Vector2i = isle[1]
				var gx: int = absi(c.x - o.x) - r.x - q.x
				var gy: int = absi(c.y - o.y) - r.y - q.y
				if gx < ISLE_GAP.x and gy < ISLE_GAP.y:
					apart = false
					break
			if apart:
				isles.append([c, r])
		for x: int in range(size.x):
			for y: int in range(size.y):
				var v: Vector2i = Vector2i(x, y)
				if get_cell(v).type != Type.EMPTY and not in_isle(v):
					_to_open(v)
		for isle: Array in isles:
			var c: Vector2i = isle[0]
			var r: Vector2i = isle[1]
			var rock: int = 0
			var area: int = 0
			for x: int in range(c.x - r.x, c.x + r.x + 1):
				for y: int in range(c.y - r.y, c.y + r.y + 1):
					if in_isle(Vector2i(x, y)):
						area += 1
						if is_ground(Vector2i(x, y)):
							rock += 1
			if float(rock) < float(area) * ISLE_ROCK:
				_stamp_islands(c, r, int(float(area) * ISLE_ROCK) - rock)
		taper_islands()
		link_isles()

	## Rows of air kept clear under a keel (over whatever rock is below it).
	const KEEL_CLEAR: int = 2

	## Floating islands taper underneath: under every run of rock with open air below it (each
	## stretch of an island's underside, as the islands lie before any keel), rows of rock narrowing
	## toward a point, a cell off each side a row (now and then a side holds), as deep as the run
	## allows. A keel stops before it strays past its cluster, meets anything, or comes within
	## KEEL_CLEAR rows of rock below (room to stand on what is beneath). Laid before the clusters
	## are linked, so the causeways go round them.
	func taper_islands () -> void:
		var runs: Array = []
		for y: int in range(size.y - 1):
			var x: int = 0
			while x < size.x:
				var under: Callable = func(cx: int) -> bool: return is_ground(Vector2i(cx, y)) and get_cell(Vector2i(cx, y + 1)).type == Type.EMPTY
				if not under.call(x):
					x += 1
					continue
				var from: int = x
				while x < size.x and under.call(x):
					x += 1
				runs.append([from, x - 1, y + 1])
		for run: Array in runs:
			_keel(int(run[0]), int(run[1]), int(run[2]))

	## A keel under the run of rock from `a` to `b` on the row over `y`.
	func _keel (a: int, b: int, y: int) -> void:
		while true:
			a += 1 if rng.randf() < 0.8 else 0
			b -= 1 if rng.randf() < 0.8 else 0
			if a > b:
				return
			for x: int in range(a, b + 1):
				var v: Vector2i = Vector2i(x, y)
				if not is_valid(v) or get_cell(v).type != Type.EMPTY or not in_isle(v, 4):
					return
				for d: int in range(1, KEEL_CLEAR + 1):
					if is_valid(v + Vector2i(0, d)) and get_cell(v + Vector2i(0, d)).type != Type.EMPTY:
						return
			for x: int in range(a, b + 1):
				_to_rock(Vector2i(x, y))
			y += 1

	## Islands laid in the cluster at `c` (radii `r`) until about `want` more cells of rock: each as
	## the sample draws them (tests/make_sky_sample.gd), a flat top 3 to 6 cells wide over a body that
	## tapers a cell each side per row below the first (2 or 3 rows). One cell beside and below,
	## and two rows above stay open, leaving headroom and hops between the denser shelves.
	func _stamp_islands (c: Vector2i, r: Vector2i, want: int) -> void:
		for attempt: int in range(350):
			if want <= 0:
				return
			var w: int = rng.randi_range(3, 6)
			var h: int = rng.randi_range(2, 3)
			var at: Vector2i = Vector2i(rng.randi_range(c.x - r.x, c.x + r.x - w), rng.randi_range(c.y - r.y + 2, c.y + r.y - h))
			var fits: bool = true
			for x: int in range(at.x - 1, at.x + w + 1):
				for y: int in range(at.y - 2, at.y + h + 1):
					var v: Vector2i = Vector2i(x, y)
					if not is_valid(v) or get_cell(v).type != Type.EMPTY:
						fits = false
			for x: int in [at.x, at.x + w - 1]:
				fits = fits and in_isle(Vector2i(x, at.y))
			if not fits:
				continue
			for d: int in range(h):
				for x: int in range(at.x + maxi(0, d - 1), at.x + w - maxi(0, d - 1)):
					_to_rock(Vector2i(x, at.y + d))
					want -= 1

	## The floors (open, rock under) of cluster `i`.
	func _isle_floors (i: int) -> Array[Vector2i]:
		var c: Vector2i = isles[i][0]
		var r: Vector2i = isles[i][1]
		var out: Array[Vector2i] = []
		for x: int in range(c.x - r.x, c.x + r.x + 1):
			for y: int in range(c.y - r.y - 1, c.y + r.y + 1):
				var v: Vector2i = Vector2i(x, y)
				if is_valid(v) and get_cell(v).type == Type.EMPTY and is_ground(v + Vector2i.DOWN) and is_valid(v + Vector2i.UP) and get_cell(v + Vector2i.UP).type == Type.EMPTY:
					out.append(v)
		return out

	## Link the clusters so every one can be reached: along the shortest links between them (a
	## spanning tree, stacked clusters counting as further apart), a causeway of cloud stepping
	## stones (Puff, two cells wide, a hop apart) from a floor of one to a floor of the other, and
	## an updraft (Wind) where the far floor is too high above to hop up to. A cluster no causeway
	## can reach is cleared away.
	func link_isles () -> void:
		var dropped: Array[int] = []
		var linked: Array[int] = [0]
		var left: Array[int] = []
		for i: int in range(1, isles.size()):
			left.append(i)
		var gap: Callable = func(i: int, j: int) -> int:
			var a: Vector2i = isles[i][0]
			var b: Vector2i = isles[j][0]
			return absi(a.x - b.x) + 2 * absi(a.y - b.y)
		while not left.is_empty() and not isles.is_empty():
			var best: Array = []
			for i: int in linked:
				for j: int in left:
					if best.is_empty() or gap.call(i, j) < int(best[0]):
						best = [gap.call(i, j), i, j]
			var j: int = best[2]
			left.erase(j)
			# From the nearest cluster already linked, else the next nearest, until one can be laid.
			var from: Array[int] = linked.duplicate()
			from.sort_custom(func(p: int, q: int) -> bool: return gap.call(p, j) < gap.call(q, j))
			var laid: bool = false
			for i: int in from:
				if _causeway(i, j):
					laid = true
					break
			if laid:
				links += 1
				linked.append(j)
			else:
				dropped.append(j)
		# A cluster no causeway reaches is cleared away, so nothing is placed out of reach.
		dropped.sort()
		dropped.reverse()
		for j: int in dropped:
			var c: Vector2i = isles[j][0]
			var r: Vector2i = isles[j][1]
			isles.remove_at(j)
			for x: int in range(c.x - r.x, c.x + r.x + 1):
				for y: int in range(c.y - r.y, c.y + r.y + 1):
					var v: Vector2i = Vector2i(x, y)
					if is_valid(v) and is_ground(v) and not in_isle(v):
						var d: Vector2 = Vector2(float(v.x - c.x) / float(r.x), float(v.y - c.y) / float(r.y))
						if d.length_squared() <= 1.0:
							_to_open(v)

	## A causeway between clusters `i` and `j`: from a floor of one up or across to a floor of the
	## other (the lower of the two to the higher). Tries the nearest pairs of floors; false if none
	## can be laid.
	func _causeway (i: int, j: int) -> bool:
		var lo: int = i if (isles[i][0] as Vector2i).y >= (isles[j][0] as Vector2i).y else j
		var hi: int = j if lo == i else i
		var from: Array[Vector2i] = _isle_floors(lo)
		var to: Array[Vector2i] = _isle_floors(hi)
		var pairs: Array = []
		for a: Vector2i in from:
			for b: Vector2i in to:
				# Always built upward, from the lower floor: every hop can be taken either way.
				if a.y >= b.y:
					pairs.append([absi(a.x - b.x) + absi(a.y - b.y), a, b])
				else:
					pairs.append([absi(a.x - b.x) + absi(a.y - b.y), b, a])
		pairs.sort()
		for k: int in range(pairs.size()):
			if _stones(pairs[k][1], pairs[k][2]):
				return true
		return false

	## Stepping stones from standing at `a` up or across to standing at `b` (no lower): hops of three
	## cells across, or two across and one up, each as easily taken back down; where `b` is two or
	## more above with little room across left, an updraft beside it lifts the wizard up to it.
	## Every stone, the cell over it and the one over that must be open air; false (nothing laid)
	## if they are not.
	func _stones (a: Vector2i, b: Vector2i) -> bool:
		var dir: int = 1 if b.x >= a.x else -1
		var stands: Array[Vector2i] = []
		var shaft: Vector2i = Vector2i(-1, -1)
		var shaft_up: int = 0
		var cur: Vector2i = a
		for guard: int in range(40):
			var dx: int = b.x - cur.x
			var dy: int = b.y - cur.y
			# Within a last hop.
			if absi(dx) <= 2 and dy >= -1 or absi(dx) <= 3 and dy >= 0:
				break
			if dy <= -2 and absi(dx) <= 3:
				# Too high to hop up to: over to the column beside it, then an updraft.
				if absi(dx) > 1:
					cur = Vector2i(b.x - dir, cur.y)
					stands.append(cur)
				shaft = cur
				shaft_up = cur.y - b.y + 2
				break
			var step: Vector2i = Vector2i(2 * dir, -1) if dy < 0 else Vector2i(mini(3, absi(dx)) * dir, 0)
			cur += step
			stands.append(cur)
		if stands.is_empty() and shaft.x < 0:
			return false
		var open: Callable = func(v: Vector2i) -> bool: return is_valid(v) and get_cell(v).type == Type.EMPTY
		var stones: Array[Vector2i] = []
		for st: Vector2i in stands:
			for c: Vector2i in [st, st + Vector2i.UP, st + Vector2i.DOWN, st + Vector2i(dir, 1)]:
				if not open.call(c):
					return false
			stones.append(st + Vector2i.DOWN)
			stones.append(st + Vector2i(dir, 1))
		if shaft.x >= 0:
			for d: int in range(0, shaft_up + 1):
				if not open.call(shaft + Vector2i(0, -d)):
					return false
		for st: Vector2i in stands:
			lanes[st] = true
			lanes[st + Vector2i.UP] = true
		for c: Vector2i in stones:
			lanes[c] = true
			add_object_at(c)
			set_cell(c, Cell.new(Type.PUFF))
		if shaft.x >= 0:
			add_object_at(shaft)
			var draft: Cell = Cell.new(Type.WIND)
			draft.extra_info = {"up": shaft_up}
			set_cell(shaft, draft)
			for d: int in range(0, shaft_up + 2):
				lanes[shaft + Vector2i(0, -d)] = true
				empties.erase(shaft + Vector2i(0, -d))
		return true

	## Floor laid either side of a gap the sky builds.
	const BUILT_SHORE: int = 3

	## Sky levels, when the islands' own gaps are too few: build them. A gap is CHASM_WIDTH cells of
	## open air (from two rows over the floor's row to two under it) between two shores of
	## BUILT_SHORE cells of floor, rock laid under each and air cleared over it. Spots are taken
	## from those needing the fewest cells changed, so a gap mostly follows the islands already
	## there, and kept apart as cut chasms are.
	func _build_gaps (want: int) -> void:
		if chasms.size() >= want:
			return
		# Where a gap could go, in tiers: between two clusters of islands (shores at their edges, the
		# gap in the air between: a shortcut from one to the next), else by a cluster, else anywhere.
		var tiers: Array = [[], [], []]
		for y: int in range(CHASM_CLEAR + 1, size.y - 4):
			for w: int in [CHASM_WIDTH.x, CHASM_WIDTH.y]:
				for a: int in range(BUILT_SHORE + 1, size.x - BUILT_SHORE - w - 1):
					@warning_ignore("integer_division")
					var tier: int = 0 if in_isle(Vector2i(a - 1, y), 2) and in_isle(Vector2i(a + w, y), 2) and not in_isle(Vector2i(a + w / 2, y)) else (1 if in_isle(Vector2i(a - 1, y), 4) and in_isle(Vector2i(a + w, y), 4) else 2)
					tiers[tier].append([y, a, w])
		# Costed only in the first tier with any spot left.
		var spots: Array = []
		for tier: Array in tiers:
			for sp: Array in tier:
				var y: int = sp[0]
				var a: int = sp[1]
				var w: int = sp[2]
				var cost: int = 0
				for x: int in range(a - BUILT_SHORE, a + w + BUILT_SHORE):
					var shore: bool = x < a or x >= a + w
					for d: int in range(-2, 3 if not shore else 2):
						var c: Vector2i = Vector2i(x, y + d)
						# Never across a causeway or its updraft.
						if lanes.has(c):
							cost = -1
							break
						if (get_cell(c).type != Type.EMPTY) != (shore and d == 1):
							cost += 1
					if cost < 0:
						break
				if cost >= 0:
					spots.append([cost, y, a, w])
			if not spots.is_empty():
				break
		spots.sort()
		for chasm: Dictionary in chasms:
			spots = _apart(spots, chasm["row"], (chasm["left"] as Vector2i).x + 1, (chasm["planks"] as Array).size())
		while chasms.size() < want and not spots.is_empty():
			# Among the cheapest few, by the level's draw.
			var pick: Array = spots[rng.randi_range(0, mini(spots.size(), 8) - 1)]
			var y: int = pick[1]
			var a: int = pick[2]
			var w: int = pick[3]
			spots = _apart(spots, y, a, w)
			for x: int in range(a - BUILT_SHORE, a + w + BUILT_SHORE):
				var shore: bool = x < a or x >= a + w
				for d: int in range(-2, 3 if not shore else 2):
					var c: Vector2i = Vector2i(x, y + d)
					if shore and d == 1:
						if get_cell(c).type != Type.GROUND:
							_to_rock(c)
					elif get_cell(c).type != Type.EMPTY:
						_to_open(c)
			var id: int = chasms.size()
			var planks: Array[Vector2i] = []
			for x: int in range(a, a + w):
				planks.append(Vector2i(x, y + 1))
				for d: int in range(-CHASM_CLEAR, CHASM_DEPTH + 1):
					empties.erase(Vector2i(x, y + d))
			add_object_at(planks[0])
			var gust: Cell = Cell.new(Type.WIND)
			gust.extra_info = {"chasm": id, "width": w}
			set_cell(planks[0], gust)
			chasms.append({"planks": planks, "row": y, "left": Vector2i(a - 1, y), "right": Vector2i(a + w, y)})

	## `spots` ([.., row, first cell, width] at the end of each) less those too near a chasm on row
	## `y` from `a`, `w` cells wide.
	func _apart (spots: Array, y: int, a: int, w: int) -> Array:
		return spots.filter(func(sp: Array) -> bool:
			var n: int = sp.size()
			return absi(int(sp[n - 3]) - y) > CHASM_DEPTH + 3 or int(sp[n - 2]) + int(sp[n - 1]) + CHASM_SHORES[0] < a or a + w + CHASM_SHORES[0] < int(sp[n - 2]))

	## Which cells are floors, one byte per cell (see carve_chasms).
	var _floors: PackedByteArray = PackedByteArray()

	## The row of the floor (an open cell with rock under it) in column `x` at `y`, a cell above or a
	## cell below; -1 if there is none.
	func _floor_near (x: int, y: int) -> int:
		if x < 0 or x >= size.x:
			return -1
		for r: int in [y, y - 1, y + 1]:
			if r < 0 or r >= size.y:
				continue
			if _floors[x * size.y + r] == 1:
				# Room to stand over the levelled floor.
				if r == y + 1 and get_cell(Vector2i(x, y)).type != Type.EMPTY:
					continue
				return r
		return -1

	## Level column `x`'s floor to row `y`: a step up is cut away, a step down filled in.
	func _level_floor (x: int, y: int) -> void:
		var r: int = _floor_near(x, y)
		if r == y - 1:
			_to_open(Vector2i(x, y))
		elif r == y + 1:
			_to_rock(Vector2i(x, y + 1))

	## Each chasm's bells: one on the floor of each side, a few cells from the edge, so it can be
	## bridged from either side. Each is chained up on its own: by a padlock in a key colour (any key
	## of it, or a skeleton key, frees it), or, about half the time, to a switch on a floor on its own
	## side (reachable from the bell without crossing any chasm), at least BELL_SWITCH cells off
	## (throwing it frees that bell). A bell's cell holds [chasm, lock]: lock is the key colour, or -1
	## for a switch.
	const BELL_SWITCH: int = 6
	## How far from its vane a sky level looks for a vane's switch.
	const SKY_SWITCH_REACH: int = 24

	func place_bells () -> void:
		for id: int in range(chasms.size()):
			var chasm: Dictionary = chasms[id]
			for side: int in [-1, 1]:
				var edge: Vector2i = chasm["left"] if side < 0 else chasm["right"]
				var at: Variant = null
				for d: int in [2, 3, 1, 4]:
					var v: Vector2i = edge + Vector2i(side * (d - 1), 0)
					if is_valid(v) and get_cell(v).type == Type.EMPTY and empties.has(v) and ground_below(v):
						at = v
						break
				if at == null:
					continue
				add_object_at(at)
				# One draw, as randi_range was, so the rest of the level lands where it did.
				var lock: int = MapInfo.rarity_color(int(rng.randi()))
				if rng.randf() < 0.5:
					var lever: Variant = _bell_switch(at)
					if lever != null:
						lock = -1
						add_object_at(lever)
						var s: Cell = Cell.new(Type.SWITCH)
						s.extra_info = at
						set_cell(lever, s)
				var bell: Cell = Cell.new(Type.VANE if sky else Type.BELL)
				bell.extra_info = [id, lock]
				set_cell(at, bell)

	## A floor for the switch that frees the bell at `bell`: on its side, reachable from it through
	## open air without crossing any chasm, at least BELL_SWITCH cells off; null if there is none.
	func _bell_switch (bell: Vector2i) -> Variant:
		var start: Vector2i = bell
		var blocked: Dictionary = {}
		for chasm: Dictionary in chasms:
			var row: int = chasm["row"]
			for plank: Vector2i in chasm["planks"]:
				for d: int in range(-CHASM_CLEAR - 1, CHASM_DEPTH + 2):
					blocked[Vector2i(plank.x, row + d)] = true
		var reach: Dictionary = {start: true}
		var queue: Array[Vector2i] = [start]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if _open(n) and not blocked.has(n) and not reach.has(n):
					# The sky is one wide open space: a switch near its vane will do.
					if sky and absi(n.x - bell.x) + absi(n.y - bell.y) > SKY_SWITCH_REACH:
						continue
					reach[n] = true
					queue.append(n)
		var free: Dictionary = {}
		for v: Vector2i in empties:
			free[v] = true
		var choices: Array[Vector2i] = []
		for v: Vector2i in reach:
			if free.has(v) and get_cell(v).type == Type.EMPTY and ground_below(v) and absi(v.x - bell.x) + absi(v.y - bell.y) >= BELL_SWITCH:
				choices.append(v)
		if choices.is_empty():
			return null
		choices.sort()
		return choices[rng.randi_range(0, choices.size() - 1)]

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
			var pool: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return fogs.all(func(q: Vector2i) -> bool: return md.call(q, v) >= 5))
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

	## What lives in the sky, on top of an ordinary level's dressing (placed after the hoppers, so
	## the rest of the level lands as it would):
	## - a share of the ledge runs (PUFF_SHARE) are clouds that give way once stood on (Puff);
	## - jump pads (Pad) on floors with a ledge or rock shelf within a pad's reach above;
	## - updrafts (Wind, {"up": cells}) up open shafts, each rising from a floor to just over a
	##   floor beside the shaft, so it lifts you onto a ledge;
	## - shields on a share of the wisps and hoppers, and rebounding shots for a share of watchers.
	const UPDRAFT_MIN: int = 4
	const UPDRAFT_MAX: int = 9
	## How high a pad throws the wizard, in cells (see Pad.LAUNCH).
	const PAD_REACH: int = 4
	## The shortest stretch of open sky a bird patrols.
	const BIRD_SPAN: int = 10

	func populate_sky (def: NextWorldDef) -> void:
		var start: Vector2i = exits.get(Exit.BACK, Vector2i(-1, -1))
		var md: Callable = func(a: Vector2i, b: Vector2i) -> int: return absi(a.x - b.x) + absi(a.y - b.y)
		# Clouds that give way: whole runs of ledge at a time.
		var ledges: Array[Vector2i] = []
		for v: Vector2i in objects:
			if get_cell(v).type == Type.PLATFORM:
				ledges.append(v)
		ledges.sort()
		var seen: Dictionary = {}
		for v: Vector2i in ledges:
			if seen.has(v):
				continue
			var run: Array[Vector2i] = []
			var c: Vector2i = v
			while is_valid(c) and get_cell(c).type == Type.PLATFORM:
				run.append(c)
				seen[c] = true
				c += Vector2i.RIGHT
			if rng.randf() < MapInfo.PUFF_SHARE:
				for r: Vector2i in run:
					set_cell(r, Cell.new(Type.PUFF))
		# Pads: on a floor with headroom, a shelf to land on within reach above.
		var pads: Array[Vector2i] = []
		var shelf: Callable = func(v: Vector2i) -> bool:
			for d: int in range(1, 3):
				if not _open(v + Vector2i(0, -d)):
					return false
			for dy: int in range(2, PAD_REACH + 1):
				for dx: int in [-2, -1, 1, 2]:
					var top: Vector2i = v + Vector2i(dx, -dy)
					if _open(top) and not _open(top + Vector2i.DOWN):
						return true
			return false
		var floors: Array[Vector2i] = []
		for v: Vector2i in empties:
			if get_cell(v).type == Type.EMPTY and ground_below(v) and md.call(v, start) >= 3 and shelf.call(v):
				floors.append(v)
		floors.sort()
		for i: int in range(per_area(MapInfo.PADS_PER_K)):
			var pool: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return pads.all(func(q: Vector2i) -> bool: return md.call(q, v) >= 6))
			if pool.is_empty():
				break
			var at: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
			pads.append(at)
			add_object_at(at)
			set_cell(at, Cell.new(Type.PAD))
		# At least one in every level: failing a floor under a shelf, any floor with headroom.
		if pads.is_empty():
			var open_floors: Array[Vector2i] = []
			for v: Vector2i in empties:
				if get_cell(v).type == Type.EMPTY and ground_below(v) and _open(v + Vector2i.UP) and _open(v + Vector2i(0, -2)) and md.call(v, start) >= 3:
					open_floors.append(v)
			open_floors.sort()
			if not open_floors.is_empty():
				var at: Vector2i = open_floors[rng.randi_range(0, open_floors.size() - 1)]
				pads.append(at)
				add_object_at(at)
				set_cell(at, Cell.new(Type.PAD))
		# Updrafts: a shaft of open air over a floor, rising to just over a floor beside it.
		var shafts: Array = []
		for v: Vector2i in empties:
			if get_cell(v).type != Type.EMPTY or not ground_below(v) or md.call(v, start) < 3:
				continue
			for h: int in range(UPDRAFT_MIN, UPDRAFT_MAX + 1):
				var top: Vector2i = v + Vector2i(0, -h)
				var clear: bool = true
				for d: int in range(0, h + 2):
					var c: Vector2i = v + Vector2i(0, -d)
					if not is_valid(c) or get_cell(c).type != Type.EMPTY:
						clear = false
						break
				if not clear:
					break
				if [Vector2i.LEFT, Vector2i.RIGHT].any(func(sd: Vector2i) -> bool: return _open(top + sd) and not _open(top + sd + Vector2i.DOWN)):
					shafts.append([v, h])
					break
		shafts.sort()
		var drafts: Array[Vector2i] = []
		for i: int in range(per_area(MapInfo.UPDRAFTS_PER_K)):
			var pool: Array = shafts.filter(func(sh: Array) -> bool: return not drafts.has(sh[0]) and drafts.all(func(q: Vector2i) -> bool: return absi(q.x - (sh[0] as Vector2i).x) >= 4 or absi(q.y - (sh[0] as Vector2i).y) > int(sh[1]) + 2))
			if pool.is_empty():
				break
			var pick: Array = pool[rng.randi_range(0, pool.size() - 1)]
			var at: Vector2i = pick[0]
			if not empties.has(at):
				continue
			drafts.append(at)
			add_object_at(at)
			var draft: Cell = Cell.new(Type.WIND)
			draft.extra_info = {"up": int(pick[1]) + 1}
			set_cell(at, draft)
			# Nothing is placed in the shaft afterwards.
			for d: int in range(1, int(pick[1]) + 2):
				empties.erase(at + Vector2i(0, -d))
		# More watchers, on floors in the clusters (their shots rebound, below).
		for i: int in range(per_area(MapInfo.SKY_WATCHERS_PER_K)):
			var at: Variant = pop_if_random_empty(func(v: Vector2i) -> bool: return ground_below(v) and md.call(v, start) >= 6, true)
			if at == null:
				break
			set_cell(at, Cell.new(Type.SHOOTER))
		# Swooping birds: each on a stretch of open sky (a row of open air, out of the clusters, at
		# least BIRD_SPAN cells long), away from the way in and from one another.
		var runs: Array = []
		for y: int in range(2, size.y - 4):
			var x: int = 0
			while x < size.x:
				var from: int = x
				while x < size.x and get_cell(Vector2i(x, y)).type == Type.EMPTY and not in_isle(Vector2i(x, y), 1):
					x += 1
				if x - from >= BIRD_SPAN:
					runs.append([y, from + 1, x - 2])
				x += 1
		runs.sort()
		var birds: Array[Vector2i] = []
		for i: int in range(per_area(MapInfo.BIRDS_PER_K)):
			var pool: Array = runs.filter(func(r: Array) -> bool:
				@warning_ignore("integer_division")
				var mid: Vector2i = Vector2i((int(r[1]) + int(r[2])) / 2, int(r[0]))
				return md.call(mid, start) >= 10 and birds.all(func(q: Vector2i) -> bool: return absi(q.y - mid.y) >= 5 or absi(q.x - mid.x) >= 12))
			if pool.is_empty():
				break
			var run: Array = pool[rng.randi_range(0, pool.size() - 1)]
			@warning_ignore("integer_division")
			var at: Vector2i = Vector2i((int(run[1]) + int(run[2])) / 2, int(run[0]))
			if not empties.has(at):
				continue
			birds.append(at)
			add_object_at(at)
			var bird: Cell = Cell.new(Type.BIRD)
			bird.extra_info = [int(run[1]), int(run[2])]
			set_cell(at, bird)
		# Shields and rebounding shots.
		var foes: Array[Vector2i] = objects.duplicate()
		foes.sort()
		for v: Vector2i in foes:
			var cell: Cell = get_cell(v)
			if cell.type in [Type.ENEMY, Type.HOPPER] and rng.randf() < MapInfo.SHIELD_SHARE:
				cell.mods["shield"] = MapInfo.SHIELD_HP
			elif cell.type == Type.SHOOTER and rng.randf() < MapInfo.BOUNCE_SHARE:
				cell.mods["bounces"] = MapInfo.BOUNCES

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

	## Vaults: small rooms sealed in the rock behind a locked corridor door, at floor height beside a
	## floor (found as secret rooms are, see _secret_spots), their loot in plain sight through the
	## bars. A vault's lock is dealt evenly among the key colours, unlike every other lock (see
	## MapInfo.KEY_RARITY), and the rarer its colour the better what it holds (VAULT_LOOT): a rare key
	## seldom opens anything, but what it opens is worth having. VAULTS_PER_K per 1000 cells, as many
	## as fit; placed last of all, so the rest of the level lands where it always has. Each is
	## {"room": cells, "door": cell, "color": key colour}.
	var vaults: Array = []
	const VAULTS_PER_K: float = 0.5
	## Room sizes (cells across and up) tried in turn, biggest first.
	## Low rooms (one cell high, like the corridors doors stand in) fit where tall ones don't.
	const VAULT_SIZES: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(3, 1), Vector2i(2, 1)]
	## What a vault holds, by its lock's colour in order of rarity, each thing as [type, extra info]:
	## a half-sized star cluster (sun), a star cluster (ember), a cluster and a half (moss), a star
	## cluster and a skeleton key (plum). A cluster's extra info is its share of a full cluster's
	## worth (see MapInfo.place_cell). Laid from the back of the room's floor, then along its upper
	## row; two things at most, so it fits the smallest room.
	const VAULT_LOOT: Array = [
		[[Type.CLUSTER, 0.5]],
		[[Type.CLUSTER, 1.0]],
		[[Type.CLUSTER, 1.5]],
		[[Type.CLUSTER, 1.0], [Type.KEY, KeyRing.SKELETON]],
	]
	## An ember vault also holds a moss key (the next colour up) this share (%) of the time, dealt by
	## the level seed and the vault's door, never the world RNG.
	const VAULT_KEY_CHANCE: int = 40
	const VAULT_KEY_DEAL: int = 9000

	## Everything the vault behind `door`, locked in `color`, holds (see VAULT_LOOT).
	func vault_loot (color: int, door: Vector2i) -> Array:
		var loot: Array = (VAULT_LOOT[color] as Array).duplicate()
		if color == 1 and MapInfo.level_seed(seed_for_colors, VAULT_KEY_DEAL + door.x * 1000 + door.y) % 100 < VAULT_KEY_CHANCE:
			loot.append([Type.KEY, 2])
		return loot
	## The rock round every vault, which make_room leaves whole (it would let you in past the door).
	var vault_walls: Dictionary = {}

	func place_vaults () -> void:
		var want: int = per_area(VAULTS_PER_K)
		for room: Vector2i in VAULT_SIZES:
			while vaults.size() < want:
				# Walled in the level's own rock, never its edge.
				var spots: Array = _secret_spots(room, true).filter(func(spot: Array) -> bool: return Rect2i(Vector2i.ZERO, size).encloses((spot[0] as Rect2i).grow(1)))
				if spots.is_empty():
					break
				var pick: Array = spots[rng.randi_range(0, spots.size() - 1)]
				_carve_vault(pick[0], pick[1], rng.randi_range(0, MapInfo.KEY_COLOR_COUNT - 1))
		# No rock thick enough to carve one into (a sky level's islands are thin): build one, a
		# strongbox of rock on a floor.
		if vaults.is_empty():
			var spots: Array = _strongbox_spots()
			if not spots.is_empty():
				var pick: Array = spots[rng.randi_range(0, spots.size() - 1)]
				for c: Vector2i in pick[2]:
					_to_rock(c)
				_carve_vault(pick[0], pick[1], rng.randi_range(0, MapInfo.KEY_COLOR_COUNT - 1))

	## A strongbox: a vault built out of open air, STRONGBOX (cells across and up) inside, its door
	## beside a floor spot, walled, roofed and floored in rock (its floor may be rock already, or it
	## hangs off the floor's edge, as a ledge does). Only where every cell it takes is free,
	## STRONGBOX_HEADROOM rows of open air lie over it and a row under any floor it builds (so it
	## never shuts a way, it is only gone round), and no chasm or gap is near. Each is [its room, its
	## door, the cells to turn to rock].
	const STRONGBOX: Vector2i = Vector2i(2, 1)
	const STRONGBOX_HEADROOM: int = 2

	func _strongbox_spots () -> Array:
		var free: Dictionary = {}
		for v: Vector2i in empties:
			free[v] = true
		var near_chasm: Callable = func(c: Vector2i) -> bool:
			for chasm: Dictionary in chasms:
				for plank: Vector2i in chasm["planks"]:
					if absi(plank.x - c.x) <= 2 and c.y >= int(chasm["row"]) - CHASM_CLEAR - 1 and c.y <= int(chasm["row"]) + CHASM_DEPTH + 1:
						return true
			return false
		var floors: Array[Vector2i] = []
		for v: Vector2i in empties:
			if ground_below(v) and get_cell(v).type == Type.EMPTY:
				floors.append(v)
		floors.sort()
		var out: Array = []
		for o: Vector2i in floors:
			for side: int in [-1, 1]:
				var door: Vector2i = o + Vector2i(side, 0)
				var x0: int = door.x + 1 if side > 0 else door.x - STRONGBOX.x
				var r: Rect2i = Rect2i(x0, o.y - STRONGBOX.y + 1, STRONGBOX.x, STRONGBOX.y)
				var box: Rect2i = Rect2i(mini(door.x, x0 - 1) if side < 0 else door.x, r.position.y - 1, STRONGBOX.x + 2, STRONGBOX.y + 1)
				if not Rect2i(Vector2i(1, 1), size - Vector2i(2, 2)).encloses(box.grow_individual(0, STRONGBOX_HEADROOM, 0, 2)):
					continue
				var ok: bool = true
				var walls: Array[Vector2i] = []
				for x: int in range(box.position.x, box.end.x):
					# Rock to stand on under all of it (built where there is none, with air under it);
					# open air over it.
					var under: Vector2i = Vector2i(x, box.end.y)
					if not is_ground(under):
						ok = ok and free.has(under) and get_cell(under).type == Type.EMPTY and not keep_clear.has(under) and not near_chasm.call(under) 								and _open(under + Vector2i.DOWN) and not keep_clear.has(under + Vector2i.DOWN)
						walls.append(under)
					for h: int in range(1, STRONGBOX_HEADROOM + 1):
						ok = ok and _open(Vector2i(x, box.position.y - h)) and not keep_clear.has(Vector2i(x, box.position.y - h))
					for y: int in range(box.position.y, box.end.y):
						var c: Vector2i = Vector2i(x, y)
						ok = ok and free.has(c) and get_cell(c).type == Type.EMPTY and not keep_clear.has(c) and not near_chasm.call(c)
						if c != door and not r.has_point(c):
							walls.append(c)
					if not ok:
						break
				if ok:
					out.append([r, door, walls])
		return out

	func _carve_vault (r: Rect2i, door: Vector2i, color: int) -> void:
		for x: int in range(r.position.x - 1, r.end.x + 1):
			for y: int in range(r.position.y - 1, r.end.y + 1):
				if is_ground(Vector2i(x, y)):
					vault_walls[Vector2i(x, y)] = true
		vault_walls.erase(door)
		var room: Array[Vector2i] = []
		for x: int in range(r.position.x, r.end.x):
			for y: int in range(r.position.y, r.end.y):
				room.append(Vector2i(x, y))
				_to_open(Vector2i(x, y))
		add_object_at(door)
		var lock: Cell = Cell.new(Type.DOOR)
		lock.extra_info = color
		set_cell(door, lock)
		# The back of the floor first, then the row over it: the loot waits at the back of the room.
		var slots: Array[Vector2i] = []
		for y: int in range(r.end.y - 1, r.position.y - 1, -1):
			var row: Array[Vector2i] = []
			for x: int in range(r.position.x, r.end.x):
				row.append(Vector2i(x, y))
			if door.x < r.position.x:
				row.reverse()
			slots.append_array(row)
		var loot: Array = vault_loot(color, door)
		for i: int in range(mini(loot.size(), slots.size())):
			var at: Vector2i = slots[i]
			add_object_at(at)
			var item: Cell = Cell.new(loot[i][0])
			item.extra_info = loot[i][1]
			set_cell(at, item)
		vaults.append({"room": room, "door": door, "color": color})

	## Cracked walls: thin rock (one or two cells, open on both sides, holding up no thorns) that a
	## hex bolt breaks.
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
				# Never rock that thorns hang from (a chasm's floor, say): they would be left in the air.
				if wall.is_empty() or wall.any(func(c: Vector2i) -> bool: return neighbor_offsets.any(func(d: Vector2i) -> bool: return is_valid(c + d) and get_cell(c + d).type == Type.SPIKES)):
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
	return rarity_color(level_seed(level_seed(at.x, at.y), 500 + which))

## The key colour a draw of `roll` (any int) deals, by KEY_RARITY: common colours come up often,
## rare ones seldom.
static func rarity_color (roll: int) -> int:
	var total: int = 0
	for w: int in KEY_RARITY:
		total += w
	var r: int = posmod(roll, total)
	for c: int in range(KEY_RARITY.size()):
		r -= KEY_RARITY[c]
		if r < 0:
			return c
	return 0

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

## The WFC sample for a garden level `depth` deep: the tunnels. (The cemetery and the sky have their
## own, NextWorldDef.GRAVEYARD and ISLANDS.)
static func region_for (_depth: int) -> String:
	return "res://wfc_images/levelSample3-spikes.png"

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

## A bell of chasm `id` was rung (at cell `from`): its bridge lays itself from that side, and stays
## up for good.
func ring_bell (id: int, from: Vector2i = Vector2i(-1, -1)) -> void:
	var rec: Dictionary = record()
	if not rec.has("bridges"):
		rec["bridges"] = {}
	if (rec["bridges"] as Dictionary).has(id):
		return
	rec["bridges"][id] = true
	if map_elements != null and is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			if node.has_method("raise") and int(node.get("chasm")) == id:
				node.call("raise", from)
	save_run()

func bridge_up (id: int) -> bool:
	return (record().get("bridges", {}) as Dictionary).has(id)

## A vane of chasm `id` was turned (at cell `from`): the wind over the chasm blows from that side
## to the other, and keeps blowing (turning the vane on the far side sends it back).
func turn_vane (id: int, from: Vector2i) -> void:
	var rec: Dictionary = record()
	if not rec.has("bridges"):
		rec["bridges"] = {}
	if not rec.has("winds"):
		rec["winds"] = {}
	rec["bridges"][id] = true
	rec["winds"][id] = from
	save_run()

## The cell of the vane chasm `id`'s wind blows from, or null while it is still.
func wind_from (id: int) -> Variant:
	return (record().get("winds", {}) as Dictionary).get(id)

## The chain on the bell at `cell` is off (by its key or its switch): for good.
func free_bell (cell: Vector2i) -> void:
	var rec: Dictionary = record()
	if not rec.has("bells_free"):
		rec["bells_free"] = {}
	rec["bells_free"][cell] = true
	save_run()

func bell_free (cell: Vector2i) -> bool:
	return (record().get("bells_free", {}) as Dictionary).has(cell)

## A cracked wall broken: gone for good. If something you stand at stood on it, a ledge takes
## its place (prop_up).
func mark_broken (node: Node) -> void:
	if node.has_meta(&"cell"):
		record()["broken"][node.get_meta(&"cell")] = true
		prop_up([node.get_meta(&"cell")])
		save_run()

## Things you stand at to use them: an exit, the shrine (both its cells), a lantern, the ink well,
## a relic, a bell, a switch or a teleporter. They always keep something under them: where rock
## under one is broken (a cracked wall, a secret room's rock), a ledge (a platform) appears in its
## place, at once, or as the level loads for rock broken before.
const STANDERS: Array[Type] = [Type.EXIT, Type.SHRINE, Type.CHECKPOINT, Type.INKWELL, Type.RELIC, Type.BELL, Type.SWITCH, Type.PORTAL, Type.VANE, Type.PAD]
## Cells given a ledge in the level as loaded now.
var _props: Dictionary = {}

## Whether broken cell `c` held up something you stand at.
func holds_up_stander (c: Vector2i) -> bool:
	if world == null:
		return false
	var above: Vector2i = c + Vector2i.UP
	if not world.is_valid(above):
		return false
	if world.get_cell(above).type in STANDERS:
		return true
	# The shrine stands across two cells: its own and the one to its right.
	var left: Vector2i = above + Vector2i.LEFT
	return world.is_valid(left) and world.get_cell(left).type == Type.SHRINE

## A ledge in each of `cells` (broken rock) that held up something you stand at.
func prop_up (cells: Array) -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	for c: Vector2i in cells:
		if _props.has(c) or not holds_up_stander(c):
			continue
		_props[c] = true
		var ledge: Node2D = platform_prefab.instantiate()
		ledge.set_meta(&"cell", c)
		ledge.set_meta(&"prop", true)
		map_elements.add_child(ledge)
		ledge.position = cell_position(c)

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
	prop_up(secret["room"] + secret["entrance"])
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
	player.health.health = 1
	player.health.display_health()
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

## Touching the ghost returns its stars and restores full health, but not lantern protection.
func recover_ghost () -> void:
	if not has_ghost:
		return
	var stars: int = ghost_stars
	var at: Vector2 = ghost_pos
	_clear_ghost()
	player.collect(stars)
	player.health.health = player.health.max_health
	player.health.display_health()
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
	# Rock broken before, under things you stand at: their ledges.
	_props.clear()
	prop_up((record()["broken"] as Dictionary).keys())
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
		# Something spread over several chunks (a wind, Wind.extent) is awake if any of them is.
		if not awake and node.has_method("extent"):
			var r: Rect2 = node.call("extent")
			var x: float = r.position.x
			while not awake and x <= r.end.x + chunk_px.x:
				var y: float = r.position.y
				while not awake and y <= r.end.y + chunk_px.y:
					awake = bool(states.get(chunk_of(Vector2(minf(x, r.end.x), minf(y, r.end.y))), false))
					y += chunk_px.y
				x += chunk_px.x
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
var pad_prefab: Resource = preload("res://prefabs/pad.tscn")
var puff_prefab: Resource = preload("res://prefabs/puff.tscn")
var vane_prefab: Resource = preload("res://prefabs/vane.tscn")
var wind_prefab: Resource = preload("res://prefabs/wind.tscn")
var bird_prefab: Resource = preload("res://prefabs/bird_enemy.tscn")

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
		player.grace()
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
	Type.PAD: pad_prefab,
	Type.PUFF: puff_prefab,
	Type.VANE: vane_prefab,
	Type.WIND: wind_prefab,
	Type.BIRD: bird_prefab,
}

func place_cell(v: Vector2i, _cell: Cell) -> void:
	# Everything that draws from the level's RNG or counters happens before the record can skip
	# the object, so the rest of the level lands in the same place on every visit.
	var jitter: Vector2 = Vector2.ZERO
	if _cell.type in [Type.COIN, Type.KEY, Type.MOON]:
		# Floating pickups sit anywhere inside their cell rather than on the grid.
		var cell_size: Vector2 = Vector2(tile_map.tile_set.tile_size) * tile_map.global_scale
		jitter = Vector2(world.rng.randf_range(-0.3, 0.3), world.rng.randf_range(-0.3, 0.3)) * cell_size
	# A key's or door's colour was dealt with the level (World.deal_colors).
	var color: int = -1
	if _cell.type in [Type.KEY, Type.DOOR]:
		color = int(_cell.extra_info) if _cell.extra_info != null else 0
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
		# A vault's lesser cluster is worth a share of a full one (World.VAULT_LOOT).
		var share: float = float(_cell.extra_info) if _cell.extra_info != null else 1.0
		cell.set("value", maxi(2, roundi(cluster_value(here.depth) * share)))
	if _cell.type in [Type.ENEMY, Type.SHOOTER, Type.HOPPER, Type.WRAITH, Type.BIRD]:
		var wound: Wound = Wound.new()
		wound.name = "Wound"
		wound.hp = Wound.hp_for(here.depth)
		cell.add_child(wound)
		cell.add_to_group(&"hex_target")
	if _cell.mods.has("shield"):
		var shield: Shield = Shield.new()
		shield.name = "Shield"
		shield.hp = int(_cell.mods["shield"])
		cell.add_child(shield)
	if _cell.mods.has("bounces"):
		cell.set_meta(&"bounces", int(_cell.mods["bounces"]))
	map_elements.add_child(cell)
	cell.set_owner(map_elements)
	cell.position = tile_map.to_global(tile_map.map_to_local(v)) + jitter

	if cell.has_method("setup"):
		# A key's or door's extra info is its colour, already given as key_color; a cracked cell's is
		# its secret.
		if _cell.extra_info != null and not _cell.type in [Type.KEY, Type.DOOR, Type.CRACKED]:
			cell.setup(self, v, _cell.extra_info)
		else:
			cell.setup(self, v)

func construct_world() -> void:
	_lay_rock(world.grounds)

	enclose_map(world.size.x, world.size.y, here != null and here.sky())

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
# a cave cut into rock rather than a box drawn round it. The camera stops at the rock. A sky level
# (`open`) has none at all: open sky all round, and a drop below (see Player.fall_back); its camera
# goes SKY_MARGIN cells past the edges, so the sky beyond shows.
const SKY_MARGIN: int = 6

func enclose_map(dim_x: int, dim_y: int, open: bool = false) -> void:
	if open:
		_fit_camera(dim_x, dim_y, SKY_MARGIN)
		return
	var rock: Array[Vector2i] = []
	for i: int in range(-BORDER, dim_x + BORDER):
		for j: int in range(-BORDER, dim_y + BORDER):
			if i < 0 or j < 0 or i >= dim_x or j >= dim_y:
				rock.append(Vector2i(i, j))
	_lay_rock(rock)
	_fit_camera(dim_x, dim_y)

## Keep the camera inside the level plus one cell of its border rock (or `margin` cells of sky).
func _fit_camera(dim_x: int, dim_y: int, margin: int = 1) -> void:
	var cam: Camera2D = main.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var cell: Vector2 = Vector2(tile_map.tile_set.tile_size) * tile_map.global_scale
	var top_left: Vector2 = tile_map.to_global(tile_map.map_to_local(Vector2i(-margin, -margin))) - cell * 0.5
	var bottom_right: Vector2 = tile_map.to_global(tile_map.map_to_local(Vector2i(dim_x + margin - 1, dim_y + margin - 1))) + cell * 0.5
	cam.limit_left = int(top_left.x)
	cam.limit_top = int(top_left.y)
	cam.limit_right = int(bottom_right.x)
	cam.limit_bottom = int(bottom_right.y)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Debug-Back"):
		travel(Exit.BACK)
