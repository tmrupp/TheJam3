extends Control

class_name MapInfo

const CLOSE_ONE_KEY: bool = false
const DEBUG_DISCOVERABLE: bool = false
const CODE_LENGTH: int = 4 # 8 is more reasonable
## Keys and doors are dealt these colours in turn; a key opens doors of its own colour.
const KEY_COLOR_COUNT: int = 4
## Share of platform runs (up to 3 cells long) that glide along a track instead of staying put.
const MOVING_PLATFORM_CHANCE: float = 0.35

enum Type {
	EMPTY,
	GROUND,
	SHARD,
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
}

## A level's four ways out. Deeper and back move along the seed's column; left and right step
## to the neighbouring seed at the same depth, as if a run had started there.
enum Exit { DEEPER, BACK, LEFT, RIGHT }
const OPPOSITE: Dictionary = {Exit.DEEPER: Exit.BACK, Exit.BACK: Exit.DEEPER, Exit.LEFT: Exit.RIGHT, Exit.RIGHT: Exit.LEFT}

class NextWorldDef:
	var gen_seed : int = 0
	var region : String
	var depth : int = 0
	var debug : bool = false

	func _init(s: int, r: String, d: int = 0, dbg: bool = false) -> void:
		gen_seed = s
		region = r
		depth = d
		debug = dbg

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
	## exit_distance(depth) cells from back, left and right at the sides. A lantern goes beside each.
	## At depth 0 there is no way back: that spot holds the run's start lantern instead.
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
		var left: Vector2i = _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.x <= lo.x + band_x)
		chosen.append(left)
		var right: Vector2i = _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.x >= hi.x - band_x)
		chosen.append(right)
		exits = {Exit.BACK: back, Exit.DEEPER: deeper, Exit.LEFT: left, Exit.RIGHT: right}
		_finish_exits(spots, chosen, depth)

	## Doors (or the start lantern) on the exit cells, a lantern beside each, then the shrine.
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
			var lantern: Variant = _nearest_free(spots, at, chosen)
			if lantern != null:
				chosen.append(lantern)
				add_object_at(lantern)
				set_cell(lantern, Cell.new(Type.CHECKPOINT))
				exit_lanterns[which] = lantern
		_place_shrine(spots, chosen, exits[Exit.DEEPER])

	## Debug runs: deeper, left and right on the floor spots nearest the way back (the spawn), two
	## cells apart so each still gets its lantern.
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

	## The shrine stands on two neighbouring floor cells a short walk from the deeper exit.
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

		# Exits and their lanterns first, so they get the pick of the level.
		place_exits(def.depth, def.debug)

		@warning_ignore("integer_division")
		var chunks: int = (size.x*size.y)/(CHUNK_SIZE*CHUNK_SIZE)
		for i: int in range(2*chunks):
			set_cell(pop_if_random_empty(), Cell.new(Type.SHARD))

		if CLOSE_ONE_KEY:
			var v: Vector2i = Vector2i(6,0)
			set_cell(v, Cell.new(Type.KEY))
			add_object_at(v)
		else:
			for i: int in range(len(empties)*0.05):
				set_cell(pop_if_random_empty(), Cell.new(Type.KEY))

		for i: int in range(len(empties)*0.1):
			set_cell(pop_if_random_empty(ground_flanking), Cell.new(Type.DOOR))

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

		for i: int in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.ENEMY))

		for i: int in range(len(empties)*0.1):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.SHOOTER))

		for i: int in range(len(empties)*0.25):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.CHECKPOINT))

		#place pairs of portals in the stage and connect them to each other
		#by telling each portal the coords of its partner in the extra_info
		for i: int in range(4):
			var pos1: Variant = pop_if_random_empty(ground_below, true)
			var pos2: Variant = pop_if_random_empty(ground_below, true)
			var portal1: Cell = Cell.new(Type.PORTAL)
			var portal2: Cell = Cell.new(Type.PORTAL)
			portal1.extra_info = pos2
			portal2.extra_info = pos1
			set_cell(pos1, portal1)
			set_cell(pos2, portal2)

		for i: int in range(len(empties)*0.05):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.ASTRAL_PROJECTION_POINT))

var goal_shift: int = 0
@onready var wfc: WaveFunctionCollapse = $"../../WaveFunctionCollapse"
@onready var player: Player
# const?


const CHUNK_SIZE: int = 16

@onready var tile_map: TileMap = $"../../TileMap"

# constants for "box" to contain the generated map
const X_MARGIN: int = 2
const TOP_MARGIN: int = 5

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

## The level being played: x is the seed, y is the depth.
var coord: Vector2i = Vector2i.ZERO
## The exit the player arrives at; -1 starts a run, -2 respawns at a lantern.
var arrival: int = -1
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
## Dying drops every star into a ghost and leaves the player vulnerable. Recovering the ghost,
## or collecting recover_need fresh stars, ends that; dying again while vulnerable ends the run.
var vulnerable: bool = false
var fresh_stars: int = 0
var recover_need: int = 0
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

## Minimum distance in cells between a level's way back and its deeper exit.
## Fresh stars that end the vulnerable state without the ghost: half the deeper price.
static func recover_price (depth: int) -> int:
	return maxi(1, ceili(deeper_price(depth) / 2.0))

static func exit_distance (depth: int) -> int:
	return clampi(24 + 4 * depth, 24, 96)

## The key colour that locks a level's left or right exit, dealt by the level seed.
static func lateral_lock (at: Vector2i, which: int) -> int:
	return level_seed(level_seed(at.x, at.y), 500 + which) % KEY_COLOR_COUNT

## How a level is named on screen and when sharing it.
static func where (at: Vector2i) -> String:
	return "world %d · depth %d" % [at.x, at.y]

## The WFC sample for a depth: bands of three levels alternate between tunnels and islands.
static func region_for (depth: int) -> String:
	@warning_ignore("integer_division")
	var band: int = depth / 3
	return "res://wfc_images/levelSample3-spikes.png" if band < 2 or band % 2 == 0 else "res://wfc_images/floating_islands.png"

func record (at: Vector2i = coord) -> Dictionary:
	if not records.has(at):
		records[at] = {"taken": {}, "opened": {}, "deeper_paid": false, "dropped": {}, "next_drop": 0, "shrine_used": false, "lateral_open": {}}
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
	if player == null:
		player = main.get_node_or_null("Player") as Player
	if player != null:
		Abilities.reset(player)
		if debug:
			player.collect(DEBUG_STARS - player.coins.coins)
	vulnerable = false
	fresh_stars = 0
	_clear_ghost()
	_load_level()

## Leave through `exit` and arrive at the opposite exit of the next level.
func travel (exit: int) -> void:
	if travelling:
		return
	match exit:
		Exit.DEEPER:
			coord.y += 1
			deepest = maxi(deepest, coord.y)
		Exit.BACK: coord.y = maxi(0, coord.y - 1)
		Exit.LEFT: coord.x -= 1
		Exit.RIGHT: coord.x += 1
	arrival = OPPOSITE[exit]
	_load_level()

func light_lantern (lantern: Node) -> void:
	if lantern.has_meta(&"cell"):
		_set_respawn(coord, lantern.get_meta(&"cell"))
		save_run()

func is_respawn_lantern (lantern: Node) -> bool:
	return coord == respawn_coord and lantern.has_meta(&"cell") and lantern.get_meta(&"cell") == respawn_cell

## True when the last lit lantern is in another level (the player must travel to respawn).
func respawn_elsewhere () -> bool:
	return world != null and respawn_coord != coord

func respawn_in_other_level () -> void:
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

## Called by the player on death. Not vulnerable: every star goes into a ghost where they fell
## (replacing any earlier ghost), and they respawn vulnerable. Vulnerable: the run ends.
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
	vulnerable = true
	fresh_stars = 0
	recover_need = recover_price(coord.y)
	_spawn_ghost()
	save_run()
	player.reset_position()

## Touching the ghost returns its stars and ends the vulnerable state.
func recover_ghost () -> void:
	if not has_ghost:
		return
	var stars: int = ghost_stars
	var at: Vector2 = ghost_pos
	_clear_ghost()
	vulnerable = false
	player.collect(stars)
	RisoFx.burst(&"gain", at, Vector2.ZERO, [RisoPrint.GLOW, RisoPrint.ACCENT])
	save_run()

## Fresh stars count toward leaving the vulnerable state; the ghost stays where it is.
func star_found (count: int) -> void:
	if not vulnerable:
		return
	fresh_stars += count
	if fresh_stars >= recover_need:
		vulnerable = false
		if player != null:
			RisoFx.burst(&"gain", player.global_position, Vector2.ZERO, [RisoPrint.GLOW, RisoPrint.EYE])

## The run is over: show the card, then start again at depth 0 of the run's seed with a fresh
## character and no records (the levels themselves are unchanged).
func end_run () -> void:
	if run_ending > 0.0:
		return
	run_ending = RUN_END_SECONDS
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.visible = false
	while run_ending > 0.0:
		await get_tree().process_frame
		run_ending = maxf(0.0, run_ending - get_process_delta_time())
	player.collect(-player.coins.coins)
	if player.has_meta(&"carried_key"):
		player.remove_meta(&"carried_key")
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
const SAVE_VERSION: int = 1

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
		"vulnerable": vulnerable, "fresh_stars": fresh_stars, "recover_need": recover_need,
		"has_ghost": has_ghost, "ghost_coord": ghost_coord, "ghost_pos": ghost_pos, "ghost_stars": ghost_stars,
		"stars": player.coins.coins, "key": int(player.get_meta(&"carried_key", -1)),
		"tiers": tiers, "health": player.health.health, "debug": debug,
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
	respawn_coord = data["respawn_coord"]
	respawn_cell = data["respawn_cell"]
	vulnerable = bool(data["vulnerable"])
	fresh_stars = int(data["fresh_stars"])
	recover_need = int(data["recover_need"])
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
	if int(data["key"]) >= 0:
		player.set_meta(&"carried_key", int(data["key"]))
	elif player.has_meta(&"carried_key"):
		player.remove_meta(&"carried_key")
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

static func def_for (at: Vector2i) -> NextWorldDef:
	return NextWorldDef.new(level_seed(at.x, at.y), region_for(at.y), at.y, debug)

func _load_level () -> void:
	travelling = true
	if player == null:
		player = main.get_node_or_null("Player") as Player
	if player != null:
		player.set_physics_process(false)
		player.set_collision(false)
	wanted = coord
	if cache.has(coord):
		wanted = null
		_level_ready.call_deferred(cache[coord], def_for(coord))
	else:
		_pump()

## Start the worker on the wanted level, else on the next neighbour not yet cached.
func _pump () -> void:
	if gen_busy:
		return
	var next: Variant = wanted
	while next == null and not prefetch.is_empty():
		var c: Vector2i = prefetch.pop_front()
		if not cache.has(c):
			next = c
	if next == null:
		return
	gen_busy = true
	if wfc_thread.is_started():
		wfc_thread.wait_to_finish()
	wfc_thread.start(_generate_threaded.bind(next as Vector2i))

func _generate_threaded (at: Vector2i) -> void:
	var cells: Array = wfc.generate_level(def_for(at))
	_generated.call_deferred(at, cells)

func _generated (at: Vector2i, cells: Array) -> void:
	wfc_thread.wait_to_finish()
	gen_busy = false
	_cache_put(at, cells)
	if wanted != null and wanted == at:
		wanted = null
		_level_ready(cells, def_for(at))
	_pump()

func _cache_put (at: Vector2i, cells: Array) -> void:
	cache[at] = cells
	cache_order.erase(at)
	cache_order.append(at)
	while cache_order.size() > CACHE_SIZE:
		cache.erase(cache_order.pop_front())

## Queue the four neighbours of the current level for the worker.
func _prefetch_neighbours () -> void:
	prefetch.clear()
	for c: Vector2i in [coord + Vector2i(0, 1), coord + Vector2i(1, 0), coord + Vector2i(-1, 0), coord + Vector2i(0, -1)]:
		if c.y >= 0 and not cache.has(c):
			prefetch.append(c)
	# Keep the current level from being evicted by its own neighbours.
	if cache.has(coord):
		cache_order.erase(coord)
		cache_order.append(coord)
	_pump()

func _level_ready (cells: Array, def: NextWorldDef) -> void:
	clear_terrain()
	world = World.new(cells, def)
	map = world
	if player == null:
		player = main.get_node_or_null("Player") as Player
	map_elements = map_elements_prefab.instantiate()
	main.add_child(map_elements)
	_keys_dealt = 0
	_doors_dealt = 0
	for v: Vector2i in world.objects:
		place_cell(v, world.get_cell(v))
	var dropped: Dictionary = record()["dropped"]
	for id: int in dropped:
		_spawn_dropped_key(id, dropped[id][0], dropped[id][1])
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

## A moon shard: show the chunk nearest the wizard that is still mostly unseen (or, when every
## chunk is mostly seen, the one with the most left).
func discover_random_chunk () -> void:
	if world == null:
		return
	var bytes: PackedByteArray = seen()
	var near: Vector2i = cell_at(player.global_position) / CHUNK_SIZE if player != null else Vector2i.ZERO
	var best: Vector2i = Vector2i.ZERO
	var best_score: float = -INF
	@warning_ignore("integer_division")
	var chunks: Vector2i = Vector2i((world.size.x + CHUNK_SIZE - 1) / CHUNK_SIZE, (world.size.y + CHUNK_SIZE - 1) / CHUNK_SIZE)
	for cx: int in range(chunks.x):
		for cy: int in range(chunks.y):
			var unseen: int = 0
			for x: int in range(cx * CHUNK_SIZE, mini((cx + 1) * CHUNK_SIZE, world.size.x)):
				for y: int in range(cy * CHUNK_SIZE, mini((cy + 1) * CHUNK_SIZE, world.size.y)):
					if bytes[x * world.size.y + y] == 0:
						unseen += 1
			var score: float = float(unseen)
			if unseen * 2 >= CHUNK_SIZE * CHUNK_SIZE:
				score = 100000.0 - float((Vector2i(cx, cy) - near).length_squared())
			if unseen > 0 and score > best_score:
				best_score = score
				best = Vector2i(cx, cy)
	for x: int in range(best.x * CHUNK_SIZE, mini((best.x + 1) * CHUNK_SIZE, world.size.x)):
		for y: int in range(best.y * CHUNK_SIZE, mini((best.y + 1) * CHUNK_SIZE, world.size.y)):
			bytes[x * world.size.y + y] = 1
	record()["seen"] = bytes
	seen_version += 1

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

var map_shard: Resource = preload("res://prefabs/map_shard.tscn")
var spikes: Resource = preload("res://prefabs/spikes.tscn")
var enemy_prefab: Resource = preload("res://prefabs/mover_enemy.tscn")
var shooter_prefab: Resource = preload("res://prefabs/shooter_enemy.tscn")
var coin_prefab: Resource = preload("res://prefabs/coin.tscn")
var key_prefab: Resource = preload("res://prefabs/key.tscn")
var door_prefab: Resource = preload("res://prefabs/door.tscn")
var checkpoint_prefab: Resource = preload("res://prefabs/checkpoint.tscn")
var portal_prefab: Resource = preload("res://prefabs/portal.tscn")
var astral_projection_point_prefab: Resource = preload("res://prefabs/astral_projection_point.tscn")
var platform_prefab: Resource = preload("res://prefabs/platform.tscn")
var moving_platform_prefab: Resource = preload("res://prefabs/moving_platform.tscn")
var level_exit_prefab: Resource = preload("res://prefabs/level_exit.tscn")
var shrine_prefab: Resource = preload("res://prefabs/shrine.tscn")

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
		player.position = cell_position(at)
		player.velocity = Vector2.ZERO
		player.reset_fourier_motion()
		player.set_collision(true)
		player.set_physics_process(true)
	travelling = false
	if RisoPrint.instance != null:
		RisoPrint.instance.world_built(self, coord.y)
	save_run()
	_prefetch_neighbours()

var map_elements: Node
var _keys_dealt: int = 0
var _doors_dealt: int = 0

var cell_to_prefab: Dictionary = {
	Type.SHARD: map_shard,
	Type.SPIKES: spikes,
	Type.ENEMY: enemy_prefab,
	Type.SHOOTER: shooter_prefab,
	Type.COIN: coin_prefab,
	Type.KEY: key_prefab,
	Type.DOOR: door_prefab,
	Type.CHECKPOINT: checkpoint_prefab,
	Type.PORTAL: portal_prefab,
	Type.ASTRAL_PROJECTION_POINT: astral_projection_point_prefab,
	Type.PLATFORM: platform_prefab,
	Type.MOVING_PLATFORM: moving_platform_prefab,
	Type.EXIT: level_exit_prefab,
	Type.SHRINE: shrine_prefab,
}

func place_cell(v: Vector2i, _cell: Cell) -> void:
	# Everything that draws from the level's RNG or counters happens before the record can skip
	# the object, so the rest of the level lands in the same place on every visit.
	var jitter: Vector2 = Vector2.ZERO
	if _cell.type in [Type.COIN, Type.KEY, Type.SHARD]:
		# Floating pickups sit anywhere inside their cell rather than on the grid.
		var cell_size: Vector2 = Vector2(tile_map.tile_set.tile_size) * tile_map.global_scale
		jitter = Vector2(world.rng.randf_range(-0.3, 0.3), world.rng.randf_range(-0.3, 0.3)) * cell_size
	var color: int = -1
	if _cell.type == Type.KEY:
		color = _keys_dealt % KEY_COLOR_COUNT
		_keys_dealt += 1
	elif _cell.type == Type.DOOR:
		color = _doors_dealt % KEY_COLOR_COUNT
		_doors_dealt += 1
	var rec: Dictionary = record()
	if (rec["taken"] as Dictionary).has(v) or (rec["opened"] as Dictionary).has(v):
		return
	var cell: Node = cell_to_prefab[_cell.type].instantiate()
	cell.set_meta(&"cell", v)
	if color >= 0:
		cell.set_meta(&"key_color", color)
	map_elements.add_child(cell)
	cell.set_owner(map_elements)
	cell.position = tile_map.to_global(tile_map.map_to_local(v)) + jitter

	if cell.has_method("setup"):
		if _cell.extra_info != null:
			cell.setup(self, v, _cell.extra_info)
		else:
			cell.setup(self, v)

func construct_world() -> void:
	tile_map.set_cells_terrain_connect(0, world.grounds, 0, 0)

	enclose_map(world.size.x, world.size.y)

	draw_background(world.size.x, world.size.y)

func get_max_bounds () -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(Vector2i(world.size.x + X_MARGIN - 1, world.size.y)))

func get_min_bounds () -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(Vector2i(-X_MARGIN, -TOP_MARGIN)))

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

# Enclose the map in a "box" so the player can't fall into nothingness
func enclose_map(dim_x: int, dim_y: int) -> void:
	for i: int in range(-X_MARGIN, dim_x + X_MARGIN):
		var to_add: Array[Vector2i] = [
			Vector2i(i, dim_y), #bottom of map
			Vector2i(i, -TOP_MARGIN), #top of map
			]
		tile_map.set_cells_terrain_connect(0, to_add, 0, 0)
		# print("to_add=", to_add, " dim_x=", dim_x)

	for j: int in range(-TOP_MARGIN + 1, dim_y):
		var to_add: Array[Vector2i] = [
			Vector2i(-X_MARGIN, j), #left of map
			Vector2i(dim_x + X_MARGIN - 1, j), #right of map
		]
		tile_map.set_cells_terrain_connect(0, to_add, 0, 0)
		# print("to_add=", to_add, " dim_y=", dim_y)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Discover"):
		if DEBUG_DISCOVERABLE:
			discover_random_chunk()

	if event.is_action_pressed("Debug-Back"):
		travel(Exit.BACK)
