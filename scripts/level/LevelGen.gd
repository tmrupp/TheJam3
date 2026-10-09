class_name LevelGen
extends RefCounted
## A level as it is laid out: the cell grid collapsed by the WFC, then dressed with exits, keys,
## doors, enemies and hazards (populate_level, and each archetype's own pass, see Archetype). Built
## from the level seed alone (see Rules.level_seed), so it is the same on every visit; MapInfo
## keeps the built layout and loads it into the scene.

enum Type {
	EMPTY,
	GROUND,
	MOON,
	SPIKES,
	ENEMY,
	SHOOTER,
	COIN,
	KEY,
	DOOR,
	CHECKPOINT,
	PORTAL,
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
	BOSS,
	GONDOLA,
	TOLL,
	BUG,
	STALACTITE,
}

## Counts per 1000 cells of level, so a level's contents scale with its size (see per_area).
## Keys are scarce: KEYS_PER_K, at least KEYS_MIN (key_count). Spots are still drawn for
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

class Cell:
	var type: Type = Type.GROUND
	var extra_info: Variant = null
	## How an enemy here differs from the usual: {"shield": hits} (Shield), {"bounces": walls}
	## (a watcher's rebounding shots).
	var mods: Dictionary = {}

	func _init(_type: Type) -> void:
		type = _type

var cells: Array
var size: Vector2i = Vector2i.ZERO
var rng: RandomNumberGenerator
var empties: Array[Vector2i] = []
var grounds: Array[Vector2i] = []
var objects: Array[Vector2i] = []

## Exit -> cell, and the lantern cell placed beside each exit (the start lantern at depth 0).
var exits: Dictionary = {}
var exit_lanterns: Dictionary = {}
## At depth 0, the side door placed near the start (MapInfo.Exit.LEFT or RIGHT; -1 for none), the
## footholds hopped to from the start (see Reach.tree), and the cells on the way from the start
## to that door and its key, which doors and gates keep off (see place_start_key).
var start_side: int = -1
## The start key's cell (see place_start_key), or (-1, -1).
var start_key: Vector2i = Vector2i(-1, -1)
var start_reach: Dictionary = {}
var keep_clear: Dictionary = {}
## The rock an archetype's structure pass laid as masonry (the crags' keeps, CragsArchetype): built
## walls and floors rather than raw cliff, which the decor prints as dressed stone (RisoDecor).
var masonry: Dictionary = {}
## The open air inside an archetype's buildings (the crags' keeps' halls and towers' rooms), which
## RisoTerrain prints with a back wall of stone rather than the sky.
var interiors: Dictionary = {}
## The cells an archetype's structure pass has spoken for, each with what holds it (the crags'
## &"shaft", &"keep" and &"tower" cells), which structures built after keep out of.
var structures: Dictionary = {}
## The towers an archetype built (CragsArchetype.build_towers), each a Dictionary (see
## CragsArchetype._tower).
var towers: Array[Dictionary] = []
## The gondola's circuit an archetype laid (CragsArchetype.lay_circuit), or {} for none.
var circuit: Dictionary = {}
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

func ground_below (v: Vector2i) -> bool:
	var n: Vector2i = v+Vector2i(0,1)
	return is_ground(n)

func add_object_at (v: Vector2i) -> void:
	empties.erase(v)
	grounds.erase(v)
	objects.append(v)

## Put a `type` holding `extra` at `v`: it leaves `empties` (or `grounds`) for `objects`.
func put (v: Vector2i, type: Type, extra: Variant = null) -> Cell:
	add_object_at(v)
	return set_kind(v, type, extra)

## Make cell `v` a `type` holding `extra`, leaving where it is listed (empties, grounds, objects)
## to the caller.
func set_kind (v: Vector2i, type: Type, extra: Variant = null) -> Cell:
	var cell: Cell = Cell.new(type)
	cell.extra_info = extra
	set_cell(v, cell)
	return cell

## A `type` at each of `at` (see put).
func put_each (at: Array[Vector2i], type: Type) -> void:
	for v: Vector2i in at:
		put(v, type)

## How far apart two cells are, across plus down.
static func dist (a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## The first of `spots` (in their order) with the least `score(v)`, among those passing `test`;
## null if none pass. Ties keep the earlier spot. For the furthest of something, negate the score.
static func best_of (spots: Array, score: Callable, test: Callable = func(_v: Variant) -> bool: return true) -> Variant:
	var best: Variant = null
	var best_score: float = INF
	for v: Variant in spots:
		if not test.call(v):
			continue
		var s: float = score.call(v)
		if best == null or s < best_score:
			best = v
			best_score = s
	return best

## Whether `v` is within 3 cells of an exit, too near to hold another.
func _crowds_exit (v: Vector2i) -> bool:
	return exits.values().any(func(e: Vector2i) -> bool: return dist(e, v) < 3)

## One of `items`, drawn from the world RNG (a single draw).
func pick (items: Array) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)]

## One of `items`, drawn from the world RNG and taken out of `items`.
func pop_pick (items: Array) -> Variant:
	return items.pop_at(rng.randi_range(0, items.size() - 1))

## The free cells (`empties`) passing `test`, sorted, so whatever is drawn from them is the same
## every time.
func empties_where (test: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Vector2i in empties:
		if test.call(v):
			out.append(v)
	out.sort()
	return out

## The free floors (open cells with rock under them), sorted.
func free_floors () -> Array[Vector2i]:
	return empties_where(func(v: Vector2i) -> bool: return ground_below(v) and get_cell(v).type == Type.EMPTY)

## The free cells (`empties`) as a set, for looking up many times.
func empty_set () -> Dictionary:
	var out: Dictionary = {}
	for v: Vector2i in empties:
		out[v] = true
	return out

## The cells holding a `type`, sorted.
func objects_of (type: Type) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Vector2i in objects:
		if get_cell(v).type == type:
			out.append(v)
	out.sort()
	return out

## Up to `count` of `spots`, drawn at random one after another, each at least `gap` cells (dist)
## from every cell in `chosen` and every one drawn before it. Those drawn are added to `chosen`
## and returned.
func pick_apart (spots: Array[Vector2i], count: int, gap: int, chosen: Array[Vector2i] = []) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in range(count):
		var pool: Array[Vector2i] = spots.filter(func(v: Vector2i) -> bool: return chosen.all(func(q: Vector2i) -> bool: return dist(q, v) >= gap))
		if pool.is_empty():
			break
		var at: Vector2i = pick(pool)
		chosen.append(at)
		out.append(at)
	return out

## Up to `count` of `spots`, popped at random until they run out: each one popped is kept if it is
## at least `gap` cells (dist) from those kept already and passes `ok`, else passed over.
func spread_out (spots: Array[Vector2i], count: int, gap: int, ok: Callable = func(_v: Vector2i) -> bool: return true) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	while kept.size() < count and not spots.is_empty():
		var v: Vector2i = pop_pick(spots)
		if kept.any(func(q: Vector2i) -> bool: return dist(q, v) < gap) or not ok.call(v):
			continue
		kept.append(v)
	return kept

## Places the four exits by position: the way back near the top and the way on near the bottom, at
## least exit_distance(depth) cells from it, left and right at the sides. Above the start
## (`climbing`) it is the other way about, the way back near the bottom and the way on near the top,
## so the up branch is climbed rather than fallen through. A lantern goes beside the way back, where
## the wizard arrives (at the start, the start lantern, beside its way up).
func place_exits (depth: int, debug: bool = false, climbing: bool = false) -> void:
	var spots: Array[Vector2i] = empties_where(ground_below)
	if spots.size() < 8:
		return
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
	# The bramble's gate level: the way on stands at the head of its shaft (BrambleShaft).
	var fixed_on: Variant = shaft.get("on")
	if fixed_on != null:
		chosen.append(fixed_on)
	var near_top: Callable = func(v: Vector2i) -> bool: return v.y <= lo.y + band_y
	var near_bottom: Callable = func(v: Vector2i) -> bool: return v.y >= hi.y - band_y
	var back_band: Callable = near_bottom if climbing else near_top
	var on_band: Callable = near_top if climbing else near_bottom
	var back: Vector2i = _pick_spot(spots, chosen, back_band)
	chosen.append(back)
	if debug:
		_place_exits_near(spots, chosen, back, depth)
		return
	var reach: int = Rules.exit_distance(depth)
	var deeper: Variant = fixed_on
	if deeper == null:
		deeper = _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return on_band.call(v) and dist(v, back) >= reach, true)
	if deeper == null:
		# No spot in its band and far enough: take the one furthest from the way back.
		var best: Vector2i = spots[0]
		for v: Vector2i in spots:
			if not chosen.has(v) and dist(v, back) > dist(best, back):
				best = v
		deeper = best
	if not chosen.has(deeper):
		chosen.append(deeper)
	# At depth 0, one side door stands near the start, on floors the wizard can hop to from it,
	# so every run can get out of its first level (its key: place_start_key).
	var near: Variant = _start_door(spots, chosen, back) if depth == 0 else null
	if near != null:
		chosen.append(near)
		start_side = MapInfo.Exit.LEFT if (near as Vector2i).x < back.x else MapInfo.Exit.RIGHT
	var left: Vector2i = near if start_side == MapInfo.Exit.LEFT else _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.x <= lo.x + band_x)
	if start_side != MapInfo.Exit.LEFT:
		chosen.append(left)
	var right: Vector2i = near if start_side == MapInfo.Exit.RIGHT else _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.x >= hi.x - band_x)
	if start_side != MapInfo.Exit.RIGHT:
		chosen.append(right)
	exits = {MapInfo.Exit.BACK: back, MapInfo.Exit.DEEPER: deeper, MapInfo.Exit.LEFT: left, MapInfo.Exit.RIGHT: right}
	_finish_exits(spots, chosen, depth)

## The start's side door and key: at least START_DOOR cells from the start, and found with hops
## START_ACROSS wide, a little short of the wizard's reach, so getting to them is easy.
const START_DOOR: int = 5
const START_ACROSS: int = 3

## The floor spot nearest the start (`back`), at least START_DOOR cells from it, that the wizard
## can hop to from it; null if there is none.
func _start_door (spots: Array[Vector2i], chosen: Array[Vector2i], back: Vector2i) -> Variant:
	start_reach = Reach.tree(self, back, START_ACROSS)
	return best_of(spots, func(v: Vector2i) -> int: return dist(v, back),
			func(v: Vector2i) -> bool: return dist(v, back) >= START_DOOR and not chosen.has(v) and start_reach.has(v))

## A key for the start's side door (in that door's lock colour), on a floor the wizard can hop
## to from the start, as near the way to the door as can be; the cells on the way from the start
## to the door and to the key are kept clear of doors and gates.
func place_start_key (def: NextWorldDef) -> void:
	if start_side < 0:
		return
	var start: Vector2i = exits[MapInfo.Exit.BACK]
	var door: Vector2i = exits[start_side]
	var floors: Array[Vector2i] = []
	for v: Vector2i in start_reach:
		floors.append(v)
	floors.sort()
	var best: Variant = best_of(floors, func(v: Vector2i) -> int: return dist(v, start) + dist(v, door),
			func(v: Vector2i) -> bool: return get_cell(v).type == Type.EMPTY and empties.has(v) and dist(v, start) >= 3 and dist(v, door) >= 2 \
				and not objects.any(func(o: Vector2i) -> bool: return dist(o, v) < 2))
	if best != null:
		var at: Vector2i = best
		put(at, Type.KEY, Rules.lateral_lock(def.coord, start_side))
		start_key = at
		for target: Vector2i in [door, at]:
			var steps: Array[Vector2i] = Reach.way(start_reach, target)
			for i: int in range(1, steps.size()):
				for c: Vector2i in Reach.arc_cells(steps[i - 1], steps[i]):
					keep_clear[c] = true
	start_reach = {}

## Doors on the exit cells (at the start too, whose way back leads up), a lantern beside the way
## back (the start lantern, at the start), then the shrine. Lanterns are scarce: the other exits
## have none.
func _finish_exits (spots: Array[Vector2i], chosen: Array[Vector2i], _depth: int) -> void:
	for which: int in [MapInfo.Exit.BACK, MapInfo.Exit.DEEPER, MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT]:
		var at: Vector2i = exits[which]
		put(at, Type.EXIT, which)
		if which != MapInfo.Exit.BACK:
			continue
		var lantern: Variant = _nearest_free(spots, at, chosen)
		if lantern != null:
			chosen.append(lantern)
			put(lantern, Type.CHECKPOINT)
			exit_lanterns[which] = lantern
	_place_shrine(spots, chosen, exits[MapInfo.Exit.DEEPER])

## Debug runs: deeper, left and right on the floor spots nearest the way back (the spawn), two
## cells apart.
func _place_exits_near (spots: Array[Vector2i], chosen: Array[Vector2i], back: Vector2i, depth: int) -> void:
	var near: Array[Vector2i] = spots.duplicate()
	near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return dist(a, back) < dist(b, back) or (dist(a, back) == dist(b, back) and a < b))
	var picks: Array[Vector2i] = []
	for v: Vector2i in near:
		if picks.size() == 3:
			break
		var clear: bool = true
		for q: Vector2i in picks + [back]:
			if dist(v, q) < 2:
				clear = false
		if clear:
			picks.append(v)
	while picks.size() < 3:
		picks.append(_pick_spot(spots, chosen + picks, func(_v: Vector2i) -> bool: return true))
	chosen.append_array(picks)
	exits = {MapInfo.Exit.BACK: back, MapInfo.Exit.DEEPER: picks[0], MapInfo.Exit.LEFT: picks[1], MapInfo.Exit.RIGHT: picks[2]}
	_finish_exits(spots, chosen, depth)

## Pockets of open space smaller than this are filled with rock rather than tunnelled to.
const POCKET: int = 6

## Join every open space into one cave. Tiny pockets fill with rock; every other open region
## is joined to the largest by carving the shortest tunnel through the rock between them,
## nearest region first, until one region remains. Deterministic: fixed scan and BFS orders.
## No tunnel goes through the cells in `walled` (the bramble's shaft, BrambleShaft).
func connect_caves (walled: Dictionary = {}) -> void:
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
				if not is_valid(n) or parent.has(n) or walled.has(n):
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
	reach_from(from, func(_v: Vector2i) -> bool: return true, into)

## Every cell reached from `start` through open air (4-neighbour), where `passable(cell)` also
## holds; a set (cell -> true), `start` among them. Given `into`, the cells already in it are not
## walked through again and those found are added to it. The order cells are found in is not
## kept: sort before drawing.
func reach_from (start: Vector2i, passable: Callable = func(_v: Vector2i) -> bool: return true, into: Dictionary = {}) -> Dictionary:
	var stack: Array[Vector2i] = [start]
	into[start] = true
	while not stack.is_empty():
		var v: Vector2i = stack.pop_back()
		for d: Vector2i in neighbor_offsets:
			var n: Vector2i = v + d
			if not into.has(n) and _open(n) and passable.call(n):
				into[n] = true
				stack.append(n)
	return into

## A free floor (open, nothing in it, rock under it) in `reach`, at least `at_least` cells from
## `from`, drawn from them sorted (one draw); null, with no draw, if there is none.
func _pick_floor_in (reach: Dictionary, from: Vector2i, at_least: int) -> Variant:
	var free: Dictionary = empty_set()
	var choices: Array[Vector2i] = []
	for v: Vector2i in reach:
		if free.has(v) and get_cell(v).type == Type.EMPTY and ground_below(v) and dist(v, from) >= at_least:
			choices.append(v)
	if choices.is_empty():
		return null
	choices.sort()
	return pick(choices)

func _to_rock (v: Vector2i) -> void:
	cells[v.x][v.y] = Cell.new(Type.GROUND)
	empties.erase(v)
	objects.erase(v)
	grounds.append(v)

## The cells make_room carved out.
var carved: Array[Vector2i] = []

## Carve out the rock (and thorns) in every thing's box: the cells across and up it takes from its
## own cell (the bottom left), where that is more than one (Placeables.size), so a tall doorway or
## portal never prints into the rock over it. Never a secret room's rock or the rock sealing it
## (either would give the room away), a vault's walls, the rock framing a door or switch gate above
## or below it, or the rock a laser is set in.
func make_room () -> void:
	for v: Vector2i in objects.duplicate():
		var size: Vector2i = Placeables.size(get_cell(v).type)
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
## room or holds up the floor its way in is taken from (secret_steps), has a laser set in it, is
## the footing of a gap's shore, or holds up something stood at.
func _holds_up (c: Vector2i) -> bool:
	if vault_walls.has(c) or in_shaft(c) or secret_steps.has(c):
		return true
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
		if is_valid(c + d) and get_cell(c + d).type in [Type.DOOR, Type.SWITCH_GATE]:
			return true
	if is_valid(c + Vector2i.UP) and Placeables.has_flag(get_cell(c + Vector2i.UP).type, &"stander"):
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
	masonry.erase(v)
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
		var d: int = dist(v, near)
		if d >= 3 and d <= 14:
			pool.append(v)
		else:
			fallback.append(v)
	if pool.is_empty():
		if fallback.is_empty():
			return
		fallback.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return dist(a, near) < dist(b, near))
		pool = [fallback[0]]
	pool.sort()
	var at: Vector2i = pick(pool)
	shrine = at
	chosen.append(at)
	chosen.append(at + Vector2i.RIGHT)
	put(at, Type.SHRINE)
	empties.erase(at + Vector2i.RIGHT)

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
	return pick(pool)

## The closest standing spot to `at` (within 4 cells) that is still free.
func _nearest_free (spots: Array[Vector2i], at: Vector2i, chosen: Array[Vector2i]) -> Variant:
	return best_of(spots, func(v: Vector2i) -> int: return dist(v, at),
			func(v: Vector2i) -> bool: return dist(v, at) > 0 and dist(v, at) <= 4 and not chosen.has(v) and empties.has(v))

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
	set_kind(left, Type.MOVING_PLATFORM, [run_cells.size(), axis, travel])

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

## A `type` holding `extra` on a random empty cell passing `test` (see pop_if_random_empty).
## Returns the cell, or null when none was found.
func put_random (type: Type, test: Callable = func(_v: Vector2i) -> bool: return true, force: bool = false, extra: Variant = null) -> Variant:
	var at: Variant = pop_if_random_empty(test, force)
	if at != null:
		set_kind(at, type, extra)
	return at

func add_cell_to_container (v: Vector2i, cell: Cell) -> void:
	if cell.type == Type.EMPTY:
		empties.append(v)
	elif cell.type == Type.GROUND:
		grounds.append(v)
	else:
		objects.append(v)

## The level's seed, which deals what is hashed rather than drawn from the world RNG: key and
## door colours (deal_colors), and where a pickup sits in its cell (LevelLoader.place_cell).
var seed_for_colors: int = 0
## The level's depth, for the rules that change with it (bone gates on the way, deal_colors).
var depth: int = 0

func _init (_cells: Array, def: NextWorldDef) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = def.gen_seed
	seed_for_colors = def.gen_seed
	depth = def.depth
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
	# Whatever kind of place it is, big things get room (see make_room).
	make_room()
	deal_colors()
	if not Worlds.is_side(def.coord):
		place_lift_switches()
	# Up levels: ledges where the climb from the way back to the way on needs them (Climb), last
	# and with no RNG draws, so nothing else moves.
	Climb.aid(self, def)
	# A gate level whose boss fights in it: the boss (Bosses), placed last, with no RNG draws.
	if not Worlds.is_side(def.coord) and def.gate != &"" and not Bosses.in_arena(def.gate):
		place_boss(def.gate)

## A gate level's boss (Bosses.IN_LEVEL): on the free floor nearest the way on it guards, at least
## BOSS_APART cells from it; the bramble in the knot at the head of its shaft (BrambleShaft), its
## cell the knot's bottom corner beside the landing. The boss is placed in every visit's layout;
## the loader leaves it out once it is slain (RunState.bosses).
const BOSS_APART: int = 4

func place_boss (boss: StringName) -> void:
	if not exits.has(MapInfo.Exit.DEEPER):
		return
	if not shaft.is_empty():
		var knot: Rect2i = shaft["knot"]
		var beside: int = knot.position.x if knot.position.x > (shaft["inside"] as Rect2i).position.x else knot.end.x - 1
		put(Vector2i(beside, knot.end.y - 1), Type.BOSS, boss)
		return
	var on: Vector2i = exits[MapInfo.Exit.DEEPER]
	var spot: Variant = best_of(free_floors(), func(v: Vector2i) -> int: return dist(v, on),
			func(v: Vector2i) -> bool: return dist(v, on) >= BOSS_APART and not _crowds_exit(v))
	if spot != null:
		put(spot, Type.BOSS, boss)

## Some of an ordinary level's lifts wait for a switch: parked at the start of their track until
## it is thrown, then running for good (the record keeps it). LIFT_SWITCH_SHARE of them, picked by
## hashing the level seed and the lift's cell, with the switch on the free floor nearest the lift
## within LIFT_SWITCH_NEAR cells, reachable from the way in. Ordinary levels never need a lift to
## get through, so a parked one blocks nothing; side worlds' lifts (hyperspace's crossings) always
## run. The lift's extra info gains the switch's cell, and the switch holds the lift's. Done last
## and with no world RNG draws, so nothing else in the level moves.
const LIFT_SWITCH_SHARE: float = 0.5
const LIFT_SWITCH_NEAR: int = 6
const LIFT_SWITCH_DEAL: int = 9100

func place_lift_switches () -> void:
	var start: Vector2i = exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	if not is_valid(start):
		return
	var reach: Dictionary = reach_from(start)
	for lift: Vector2i in objects_of(Type.MOVING_PLATFORM):
		var info: Array = get_cell(lift).extra_info
		if info.size() > 3:
			continue
		var roll: int = posmod(Rules.level_seed(seed_for_colors, LIFT_SWITCH_DEAL + lift.x * 977 + lift.y), 1000)
		if float(roll) / 1000.0 >= LIFT_SWITCH_SHARE:
			continue
		var spot: Variant = best_of(free_floors(), func(v: Vector2i) -> int: return dist(v, lift),
				func(v: Vector2i) -> bool: return reach.has(v) and dist(v, lift) <= LIFT_SWITCH_NEAR and not _crowds_exit(v))
		if spot == null:
			continue
		info.append(spot)
		put(spot, Type.SWITCH, lift)

## Salts for the level seed when dealing key and door colours (deal_colors).
const KEY_DEAL: int = 7000
const DOOR_DEAL: int = 8000

## How many keys a level keeps (besides the start key and skeleton keys): KEYS_PER_K,
## at least KEYS_MIN.
func key_count () -> int:
	return maxi(KEYS_MIN, per_area(KEYS_PER_K))

## Every key and corridor door not laid for a particular lock is dealt its colour by rarity
## (Rules.rarity_color), from the level's seed and its place in the order things were laid,
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
			cell.extra_info = 0 if keys == 0 else Rules.rarity_color(Rules.level_seed(seed_for_colors, KEY_DEAL + keys))
			keys += 1
		elif cell.type == Type.DOOR:
			var roll: int = Rules.level_seed(seed_for_colors, DOOR_DEAL + doors)
			# Deep down, some doors on the way are bone gates.
			if depth >= Rules.SKELETON_DOOR_DEPTH and (roll / 100) % 100 < Rules.SKELETON_DOOR_CHANCE:
				cell.extra_info = KeyRing.SKELETON
			else:
				cell.extra_info = Rules.rarity_color(roll)
			doors += 1
	for v: Vector2i in spare:
		_to_open(v)

## Dress an ordinary level (see NextWorldDef.populate). Its archetype (def.arch) has its say at fixed
## points (see Archetype): before and after the caves are joined, where stars and ledges may go,
## and its own dressing near the end.
func populate_level (def: NextWorldDef) -> void:
	var arch: Archetype = def.arch
	arch.shape(self)
	# One cave: every open space joined up, so everything placed below is connected to
	# everything else through open air (gates and abilities aside).
	connect_caves()
	arch.cut_gates(self)
	# The garden's way up: the bramble's shaft, cut before anything is placed so the rest lands
	# round it (only in its gate levels).
	if BrambleShaft.wanted(def):
		BrambleShaft.cut(self)

	# Exits and their lanterns first, so they get the pick of the level.
	place_exits(def.depth, def.debug, def.coord.y < 0)
	place_side_doors(def)
	place_start_key(def)
	Chasms.place_bells(self, arch.crossing, arch.switch_reach)
	if def.arrival_from != null:
		place_return()

	# One ink well per level stands on a floor.
	put_random(Type.INKWELL, ground_below, true)

	# Spots for keys: more than are kept (see KEYS_PER_K and deal_colors).
	for i: int in range(maxi(Rules.KEY_COLOR_COUNT, per_area(KEY_SPOTS_PER_K))):
		put_random(Type.KEY)

	place_doors(per_area(DOORS_PER_K))
	place_switch_gates(maxi(1, per_area(SWITCH_GATES_PER_K)))

	# Stars, where the archetype has room for them (in the sky, only in and near the clusters).
	for i: int in range(len(empties)*0.2):
		put_random(Type.COIN, func(v: Vector2i) -> bool: return arch.room(self, v, 3))

	# Platforms are laid in horizontal runs of 2-5 cells so they read as continuous ledges.
	# Only where the archetype has room (in the sky, in and about the clusters, so the gaps stay open).
	var ledge_room: Callable = func(v: Vector2i) -> bool: return arch.room(self, v, 1)
	var platform_budget: int = int(float(empties.filter(ledge_room).size()) * 0.2)
	while platform_budget > 0 and len(empties) > 0:
		var start: Variant = pop_if_random_empty(ledge_room)
		platform_budget -= 1
		if start == null:
			continue
		set_kind(start, Type.PLATFORM)
		var step: Vector2i = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(-1, 0)
		var run: Vector2i = start
		var run_cells: Array[Vector2i] = [start]
		for _j: int in range(rng.randi_range(1, 4)):
			run += step
			if platform_budget <= 0 or not is_valid(run) or get_cell(run).type != Type.EMPTY or not empties.has(run):
				break
			put(run, Type.PLATFORM)
			run_cells.append(run)
			platform_budget -= 1
		if run_cells.size() <= 3 and rng.randf() < MOVING_PLATFORM_CHANCE:
			make_moving(run_cells)

	# Moons (dash resets) once the ledges are down: open air with nothing to stand on below.
	place_moons(per_area(MOONS_PER_K))

	for i: int in range(len(empties)*0.2):
		put_random(Type.ENEMY, ground_below)

	for i: int in range(len(empties)*0.1):
		put_random(Type.SHOOTER, ground_below)

	for i: int in range(per_area(LANTERNS_PER_K)):
		put_random(Type.CHECKPOINT, ground_below, true)

	#place pairs of portals in the stage and connect them to each other
	#by telling each portal the coords of its partner in the extra_info
	# The two ends of a pair at least portal_apart() cells apart (no pair where no floor is that far).
	var apart: int = portal_apart()
	for i: int in range(per_area(PORTAL_PAIRS_PER_K)):
		var pos1: Variant = pop_if_random_empty(ground_below, true)
		var pos2: Variant = null
		if pos1 != null:
			var first: Vector2i = pos1
			pos2 = pop_if_random_empty(func(v: Vector2i) -> bool: return ground_below(v) and dist(v, first) >= apart, true)
		# Out of floors for a pair (a sparse sky level): no more portals.
		if pos1 == null or pos2 == null:
			if pos1 != null:
				_to_open(pos1)
			break
		set_kind(pos1, Type.PORTAL, pos2)
		set_kind(pos2, Type.PORTAL, pos1)

	place_cracks(per_area(CRACKS_PER_K))

	# Placed last, so everything above lands where it always has.
	if def.depth >= 1:
		for i: int in range(per_area(HOPPERS_PER_K)):
			put_random(Type.HOPPER, ground_below, true)
	arch.populate(self, def)
	place_cluster(def)
	place_secrets(def)
	place_vaults(def)
	Chasms.relax_crossings(self, def)
	arch.finish(self, def)

## Chasms (and sky gaps) with no bell or vane, which only a relic move gets over (see
## Chasms.relax_crossings); and in hyperspace, the stretches left unbridged (Hyperspace._relic_gap).
var relic_chasms: Array[int] = []
var relic_gaps: Array[Rect2i] = []
## The ledges laid to make an up level climbable (Climb.aid), in the order they were laid.
var climb_ledges: Array[Vector2i] = []

## The bramble's shaft, in its gate levels (BrambleShaft.cut, which says what it holds); empty in
## every other level.
var shaft: Dictionary = {}

## Whether cell `v` is part of the bramble's shaft: inside it, or its walls, roof or floor. Nothing
## else is built into it (secret rooms, vaults, cracked walls, climbing ledges).
func in_shaft (v: Vector2i) -> bool:
	return not shaft.is_empty() and (shaft["inside"] as Rect2i).grow(1).has_point(v)

## The level's chasms and gaps, its gates where the archetype has them (see Chasms): each
## {"planks": cells, "row": the floor row, "left": the last floor cell before it, "right": the
## first after}, numbered by their place here.
var chasms: Array = []

## The sky's islands come in clusters with wide gaps of open air between (SkyArchetype.cluster_islands): each
## [centre, radii] of an ellipse of the collapsed islands kept, the rest of the rock cleared.
var isles: Array = []
## The cells a causeway or its updraft uses (stones, the air over them, the shaft): kept as they are
## by everything built after (the gaps, SkyArchetype._build_gaps).
var lanes: Dictionary = {}
## Causeways laid (SkyArchetype.link_isles): one fewer than the clusters when every cluster is reached.
var links: int = 0

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

## The level's star cluster (worth Rules.cluster_value): hung in open air (as a moon is) at
## least half the exit distance from the way in, three times as likely over thorns; failing
## that, on the floor furthest from the way in.
func place_cluster (def: NextWorldDef) -> void:
	var start: Vector2i = exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	@warning_ignore("integer_division")
	var far: int = Rules.exit_distance(def.depth) / 2
	var spots: Array[Vector2i] = _air_spots(func(v: Vector2i) -> bool: return get_cell(v).type == Type.EMPTY and _wide_open(v) and dist(v, start) >= far)
	var at: Variant = null
	if not spots.is_empty():
		at = pick(spots)
	else:
		at = best_of(free_floors(), func(v: Vector2i) -> int: return -dist(v, start))
	if at == null:
		return
	put(at, Type.CLUSTER)

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
## The level's relic waits behind a bone gate rather than in a secret room
## (Rules.RELIC_GATE_CHANCE; see place_bone_vault).
var relic_gated: bool = false
## Room sizes (cells across and up) tried in turn, biggest first.
const SECRET_SIZES: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2)]
const SECRET_STARS: int = 3

func place_secrets (def: NextWorldDef) -> void:
	relic_gated = def.relic != &"" and Rules.relic_gated_at(def.coord)
	var want: int = per_area(SECRETS_PER_K)
	# Rooms wholly in rock first; then rooms that only need rock under them (a hidden room's
	# rock is real rock, so another side may face open air).
	for enclosed: bool in [true, false]:
		for room: Vector2i in SECRET_SIZES:
			while secrets.size() < want:
				var spots: Array = _secret_spots(room, enclosed)
				if spots.is_empty():
					break
				var choice: Array = pick(spots)
				_carve_secret(choice[0], choice[1], def.relic if secrets.is_empty() and not relic_gated else &"")
	# A relic with no room for a secret stands on a floor in the open instead.
	if def.relic != &"" and secrets.is_empty() and not relic_gated:
		put_random(Type.RELIC, ground_below, true, def.relic)
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
			put_random(Type.KEY, ground_below, true, KeyRing.SKELETON)

## Every place a `room` (cells across and up) fits: [its rect, its entrance]. The room's floor is
## level with a floor spot beside it, through one cell of rock (the entrance, with rock over it),
## and the room is solid rock with rock under it (the level's edge counts as rock); when
## `enclosed`, with a cell of rock all round it too.
func _secret_spots (room: Vector2i, enclosed: bool) -> Array:
	var floors: Array[Vector2i] = free_floors()
	var rock: Callable = func(v: Vector2i) -> bool: return not is_valid(v) or (is_ground(v) and not in_shaft(v))
	var out: Array = []
	for o: Vector2i in floors:
		for side: int in [-1, 1]:
			var fit: Array = _room_beside(o, side, room)
			var r: Rect2i = fit[0]
			var door: Vector2i = fit[1]
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

## A room `inside` (cells across and up) beside floor spot `o`, on its `side` (-1 left, 1 right):
## [its rect, its door]. The door is the cell next to `o`, and the room's floor is level with it,
## running on from the door away from `o`.
func _room_beside (o: Vector2i, side: int, inside: Vector2i) -> Array:
	var door: Vector2i = o + Vector2i(side, 0)
	var x0: int = door.x + 1 if side > 0 else door.x - inside.x
	return [Rect2i(x0, o.y - inside.y + 1, inside.x, inside.y), door]

## Every place a vault `room` (cells across and up) fits, found as secret rooms are (enclosed), but
## walled in the level's own rock, never its edge: [its rect, its door].
func _vault_spots (room: Vector2i) -> Array:
	return _secret_spots(room, true).filter(func(spot: Array) -> bool: return Rect2i(Vector2i.ZERO, size).encloses((spot[0] as Rect2i).grow(1)) \
			and not secret_steps.keys().any(func(c: Vector2i) -> bool: return (spot[0] as Rect2i).grow(1).has_point(c)))

## Build the vault `choice` ([its rect, its door] and, for a strongbox, the cells to turn to rock),
## locked in `color`.
func _build_vault (choice: Array, color: int) -> void:
	if choice.size() > 2:
		for c: Vector2i in choice[2]:
			_to_rock(c)
	_carve_vault(choice[0], choice[1], color)

## Where the wizard stands to walk into each secret room (an open floor beside its way in), and the
## rock under it. What is placed after the rooms leaves them as they are (a vault or strongbox is
## not built on them, make_room does not carve them), or a room could not be walked into.
var secret_steps: Dictionary = {}

func _carve_secret (r: Rect2i, door: Vector2i, relic: StringName) -> void:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
		var o: Vector2i = door + d
		if is_valid(o) and not r.has_point(o) and _open(o) and ground_below(o):
			secret_steps[o] = true
			secret_steps[o + Vector2i.DOWN] = true
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
## Rules.KEY_RARITY), and the rarer its colour the better what it holds (VAULT_LOOT): a rare key
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
## worth (see LevelLoader.place_cell). Laid from the back of the room's floor, then along its upper
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
	if color == KeyRing.SKELETON:
		return [[Type.RELIC, bone_relic]] if bone_relic != &"" else BONE_LOOT.duplicate()
	var loot: Array = (VAULT_LOOT[color] as Array).duplicate()
	if color == 1 and Rules.level_seed(seed_for_colors, VAULT_KEY_DEAL + door.x * 1000 + door.y) % 100 < VAULT_KEY_CHANCE:
		loot.append([Type.KEY, 2])
	return loot
## The rock round every vault, which make_room leaves whole (it would let you in past the door).
var vault_walls: Dictionary = {}
## A bone vault's loot, a step above a plum vault's: a hoard worth three star clusters.
const BONE_LOOT: Array = [[Type.CLUSTER, 3.0]]
## The relic a bone vault holds instead (relic_gated), or &"".
var bone_relic: StringName = &""
## Room sizes for a bone vault: two high, so a relic stands in it.
const BONE_SIZES: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 2)]
## A bone strongbox's inside, where no rock is thick enough (see _strongbox_spots).
const BONE_STRONGBOX: Vector2i = Vector2i(2, 2)

func place_vaults (def: NextWorldDef) -> void:
	var want: int = per_area(VAULTS_PER_K)
	for room: Vector2i in VAULT_SIZES:
		while vaults.size() < want:
			var spots: Array = _vault_spots(room)
			if spots.is_empty():
				break
			# The spot is drawn first, then the lock's colour.
			var choice: Array = pick(spots)
			_build_vault(choice, rng.randi_range(0, Rules.KEY_COLOR_COUNT - 1))
	# No rock thick enough to carve one into (a sky level's islands are thin): build one, a
	# strongbox of rock on a floor.
	if vaults.is_empty():
		var spots: Array = _strongbox_spots(STRONGBOX)
		if not spots.is_empty():
			var choice: Array = pick(spots)
			_build_vault(choice, rng.randi_range(0, Rules.KEY_COLOR_COUNT - 1))
	place_bone_vault(def)

## A bone vault: a vault behind a bone gate, which only a skeleton key opens. In BONE_VAULT_CHANCE
## % of levels from depth 1 it holds BONE_LOOT; in a level whose relic is gated (relic_gated) it
## holds the relic instead. Placed after the other vaults. A gated relic with no room for a bone
## vault goes back to the level's first secret room (in place of a star), or, with no secret room
## either, stands on a floor in the open.
func place_bone_vault (def: NextWorldDef) -> void:
	if not relic_gated and not Rules.bone_vault_at(def.coord):
		return
	bone_relic = def.relic if relic_gated else &""
	for room: Vector2i in BONE_SIZES:
		var spots: Array = _vault_spots(room)
		if not spots.is_empty():
			_build_vault(pick(spots), KeyRing.SKELETON)
			return
	# No rock to carve one into (a cemetery's terraces, the sky's islands): build a strongbox,
	# two high so a relic stands in it.
	var built: Array = _strongbox_spots(BONE_STRONGBOX)
	if not built.is_empty():
		_build_vault(pick(built), KeyRing.SKELETON)
		return
	if not relic_gated:
		return
	if not secrets.is_empty():
		var rewards: Array = secrets[0]["rewards"]
		rewards[0] = [rewards[0][0], Type.RELIC, def.relic]
	else:
		put_random(Type.RELIC, ground_below, true, def.relic)
	relic_gated = false

## A strongbox: a vault built out of open air, `inside` (cells across and up; STRONGBOX for a
## keyed vault) inside, its door
## beside a floor spot, walled, roofed and floored in rock (its floor may be rock already, or it
## hangs off the floor's edge, as a ledge does). Only where every cell it takes is free,
## STRONGBOX_HEADROOM rows of open air lie over it and a row under any floor it builds (so it
## never shuts a way, it is only gone round), and no chasm or gap is near. Each is [its room, its
## door, the cells to turn to rock].
const STRONGBOX: Vector2i = Vector2i(2, 1)
const STRONGBOX_HEADROOM: int = 2

func _strongbox_spots (inside: Vector2i) -> Array:
	var free: Dictionary = empty_set()
	var floors: Array[Vector2i] = free_floors()
	var out: Array = []
	for o: Vector2i in floors:
		for side: int in [-1, 1]:
			var fit: Array = _room_beside(o, side, inside)
			var r: Rect2i = fit[0]
			var door: Vector2i = fit[1]
			# The room with a wall either side (the door is one of them) and a roof.
			var box: Rect2i = r.grow_individual(1, 1, 1, 0)
			if not Rect2i(Vector2i(1, 1), size - Vector2i(2, 2)).encloses(box.grow_individual(0, STRONGBOX_HEADROOM, 0, 2)):
				continue
			var ok: bool = true
			var walls: Array[Vector2i] = []
			for x: int in range(box.position.x, box.end.x):
				# Rock to stand on under all of it (built where there is none, with air under it);
				# open air over it.
				var under: Vector2i = Vector2i(x, box.end.y)
				if not is_ground(under):
					ok = ok and _buildable(under, free) and not keep_clear.has(under) and not Chasms.near(self, under) \
							and _open(under + Vector2i.DOWN) and not keep_clear.has(under + Vector2i.DOWN)
					walls.append(under)
				for h: int in range(1, STRONGBOX_HEADROOM + 1):
					ok = ok and _open(Vector2i(x, box.position.y - h)) and not keep_clear.has(Vector2i(x, box.position.y - h))
				for y: int in range(box.position.y, box.end.y):
					var c: Vector2i = Vector2i(x, y)
					ok = ok and _buildable(c, free) and not keep_clear.has(c) and not Chasms.near(self, c)
					if c != door and not r.has_point(c):
						walls.append(c)
				if not ok:
					break
			if ok:
				out.append([r, door, walls])
	return out

## Whether a strongbox may take cell `c`: open air with nothing in it, or only a star or a piece
## of a ledge that stays put (which it takes the place of). `free` holds the open cells.
func _buildable (c: Vector2i, free: Dictionary) -> bool:
	if in_shaft(c) or secret_steps.has(c):
		return false
	return (free.has(c) and get_cell(c).type == Type.EMPTY) or get_cell(c).type in [Type.COIN, Type.PLATFORM]

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
	# A strongbox's door may stand where a star was: it is listed once.
	objects.erase(door)
	put(door, Type.DOOR, color)
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
		put(at, loot[i][0], loot[i][1])
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
			# Never rock that thorns hang from (a chasm's floor, say): they would be left in the air;
			# nor the bramble's shaft, which is climbed only from its foot.
			if wall.is_empty() or wall.any(func(c: Vector2i) -> bool: return in_shaft(c) or neighbor_offsets.any(func(d: Vector2i) -> bool: return is_valid(c + d) and get_cell(c + d).type == Type.SPIKES)):
				continue
			walls.append(wall)
			for o: Vector2i in valuable:
				if dist(o, v) <= 3:
					near.append(wall)
					break
	var placed: int = 0
	while placed < count and not walls.is_empty():
		var pool: Array[Array] = near if placed * 2 < count and not near.is_empty() else walls
		var wall: Array = pick(pool)
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
	put_each(spread_out(_corridors(), count, 4), Type.DOOR)

## Free cells in a corridor one cell high (rock above and below, open air either side), off the
## ways kept clear, sorted: where a door or a switch gate fits.
func _corridors () -> Array[Vector2i]:
	return empties_where(func(v: Vector2i) -> bool: return not keep_clear.has(v) and is_ground(v + Vector2i.UP) and is_ground(v + Vector2i.DOWN) \
			and _open(v + Vector2i.LEFT) and _open(v + Vector2i.RIGHT) and get_cell(v + Vector2i.LEFT).type == Type.EMPTY and get_cell(v + Vector2i.RIGHT).type == Type.EMPTY)

## Switch gates: a gate across a corridor (rock above and below, open either side, like a door)
## and its switch on a floor near it (switch_floor) reachable from the way in without passing that
## gate, so the switch is found on the way to it. Each records the other's cell in extra_info.

func place_switch_gates (count: int) -> void:
	var start: Vector2i = exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	if not is_valid(start):
		return
	var spots: Array[Vector2i] = _corridors()
	var placed: Array[Vector2i] = []
	while placed.size() < count and not spots.is_empty():
		var gate: Vector2i = pop_pick(spots)
		if placed.any(func(q: Vector2i) -> bool: return dist(q, gate) < 6):
			continue
		# A floor reachable from the way in with this gate shut.
		var found: Variant = switch_floor(reach_from(start, func(n: Vector2i) -> bool: return n != gate), gate)
		if found == null:
			continue
		var lever: Vector2i = found
		placed.append(gate)
		put(gate, Type.SWITCH_GATE, lever)
		put(lever, Type.SWITCH, gate)

## Where a switch goes: near what it works. A free floor (open, nothing in it, rock under it) in
## `reach`, drawn (one draw) from those SWITCH_NEAR_MIN to SWITCH_NEAR cells from `target`; with
## none so near, the nearest further off (no draw); null, with no draw, if there is none.
const SWITCH_NEAR: int = 6
const SWITCH_NEAR_MIN: int = 2

func switch_floor (reach: Dictionary, target: Vector2i) -> Variant:
	var free: Dictionary = empty_set()
	var near: Array[Vector2i] = []
	var far: Array[Vector2i] = []
	for v: Vector2i in reach:
		if not free.has(v) or get_cell(v).type != Type.EMPTY or not ground_below(v) or dist(v, target) < SWITCH_NEAR_MIN:
			continue
		(near if dist(v, target) <= SWITCH_NEAR else far).append(v)
	if not near.is_empty():
		near.sort()
		return pick(near)
	far.sort()
	return best_of(far, func(v: Vector2i) -> int: return dist(v, target))

## A level a side world leads into gets an ordinary way up as well, on a floor a few cells from
## the way back (which leads into that world).
func place_return () -> void:
	var start: Vector2i = exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	if not is_valid(start):
		return
	var best: Variant = best_of(empties_where(ground_below), func(v: Vector2i) -> int: return dist(v, start),
			func(v: Vector2i) -> bool: return dist(v, start) >= 4 and not _crowds_exit(v))
	if best == null:
		return
	exits[MapInfo.Exit.RETURN] = best
	put(best, Type.EXIT, MapInfo.Exit.RETURN)

## A door into each side world the level deals (NextWorldDef.doors): a floor far from the way
## in, not crowding another exit. In a debug run it is on the floor nearest the way in instead,
## like the other exits. It is kept in `exits`, under its door number (Worlds.door).
func place_side_doors (def: NextWorldDef) -> void:
	var start: Vector2i = exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var floors: Array[Vector2i] = empties_where(ground_below)
	var nearest: Callable = func(v: Vector2i) -> int: return dist(v, start)
	var furthest: Callable = func(v: Vector2i) -> int: return -dist(v, start)
	for kind: int in def.doors:
		var best: Variant = best_of(floors, nearest if def.debug else furthest,
				func(v: Vector2i) -> bool: return get_cell(v).type == Type.EMPTY and not _crowds_exit(v))
		if best == null:
			continue
		var at: Vector2i = best
		exits[Worlds.door(kind)] = at
		put(at, Type.EXIT, Worlds.door(kind))

## Moons only where the air is open: every cell within MOON_CLEARANCE is open, and the cell
## below that too, with no ledge or lift in the fall below (nothing to stand on), and
## at least MOON_SPACING apart. Air over thorns is favoured: such spots are three times as
## likely, since a dash reset is most welcome there.
func place_moons (count: int) -> void:
	var supports: Dictionary = _platform_footprint()
	var spots: Array[Vector2i] = _air_spots(func(v: Vector2i) -> bool: return _wide_open(v) and not _ledge_below(v, supports))
	put_each(spread_out(spots, count, MOON_SPACING, func(v: Vector2i) -> bool: return empties.has(v)), Type.MOON)

## The free cells passing `test`, sorted, those over thorns listed three times (so a draw from
## them is three times as likely to land over thorns, where a moon or a reward is most welcome).
func _air_spots (test: Callable) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for v: Vector2i in empties:
		if not test.call(v):
			continue
		spots.append(v)
		if _thorns_below(v):
			spots.append(v)
			spots.append(v)
	spots.sort()
	return spots

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

## The sigils linking this level's teleporter pairs and switches to what they work (Sigils.deal),
## dealt the first time one is asked for.
var _sigils: Variant = null

## The sigil shared by the linked thing at `v` (a teleporter, a switch, or what a switch works),
## or -1 if it has none.
func sigil_at (v: Vector2i) -> int:
	if _sigils == null:
		_sigils = Sigils.deal(self)
	return int((_sigils as Dictionary).get(v, -1))
