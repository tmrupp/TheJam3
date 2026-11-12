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
	TRAPDOOR,
	NEST,
	DRAUGHT,
	WELL,
	CROSSBOW,
	BALLOON,
	TEMPLE,
	SNUFFER,
	SKELETON,
	LIGHT_GATE,
	STUDENT,
	MASTER,
	PROCTOR,
	LIBRARIAN,
	ABOMINATION,
	BREACH,
	EXAM_DOOR,
	DEPARTMENT,
	STATION_GATE,
	TOWER_SWITCH,
	SCHOOL_BELL,
	LECTERN,
	## No longer laid (the institute's glyph seals were taken out); kept so the types after it keep
	## their numbers.
	GLYPH_SEAL,
	## The library's reading desk (StudyDesk) and its timetable board (TimetableBoard).
	STUDY_DESK,
	TIMETABLE_BOARD,
	## The institute's rolling bookcase ladders, laid where other bands lay lifts (RollingLadder).
	ROLLING_LADDER,
	## The cemetery's sun and shade blocks (PhaseBlock), and its crypts' ossuary doors (OssuaryDoor).
	PHASE_BLOCK,
	OSSUARY_DOOR,
	## The crags: a watchtower's iron spire on its roof (Spire), and a lodestone (Lodestone).
	SPIRE,
	LODESTONE,
	## The whale's belly (Belly): its pool of acid, flooding and draining (Acid), and the wreckage it
	## has swallowed, floating on it (Wreck).
	ACID,
	WRECK,
	## The practice range's tally (PracticeRange, PracticeTally).
	TALLY,
	## A card of the control a stretch of the tutorial asks for (Tutorial, ControlHint).
	HINT,
	## A boss's trophy stand, in the room by the tutorial's way out (Tutorial, TrophyStand).
	TROPHY_STAND,
	## The garden's seed pods, set in its walls (SeedPod), and its plots, where a seed is planted
	## (Plot; GardenArchetype.finish).
	POD,
	PLOT,
	## The garden's small worms, in its rock (Wormlet).
	WORMLET,
	VINE,
	BARRIER_MARK,
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

## Hoppers (enemies that leap at the wizard) from depth 1, per 1000 cells, unless the archetype
## says otherwise (Archetype.hoppers_per_k).
const HOPPERS_PER_K: float = 2.0

class Cell:
	var type: Type = Type.GROUND
	var extra_info: Variant = null
	## How an enemy here differs from the usual: {"shield": hits} (Shield), {"bounces": walls}
	## (a watcher's rebounding shots), {"hovers": true} (a watcher hovering, its shots straight),
	## {"parried_only": true} (wounded only by a parried shot, Wound.parried_only); the last two the
	## tutorial's watcher (Tutorial).
	var mods: Dictionary = {}

	func _init(_type: Type) -> void:
		type = _type

var cells: Array
## Every cell's type (Type), cell (x, y) at x * size.y + y: what `cells` says, kept in step by
## set_cell (every change of a cell goes through it), for the passes that ask what a cell is
## millions of times (type_at, is_ground, _open).
var types: PackedByteArray = PackedByteArray()
var size: Vector2i = Vector2i.ZERO
var rng: RandomNumberGenerator
var empties: Array[Vector2i] = []
var grounds: Array[Vector2i] = []
var objects: Array[Vector2i] = []

## Exit -> cell, and the lantern cell placed beside each exit (the start lantern at depth 0).
var exits: Dictionary = {}
var exit_lanterns: Dictionary = {}
## At depth 0, the side door placed near the start (Ways.Exit.LEFT or RIGHT; -1 for none), the
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
## The small insides collapsed with the terrain (Archetype.patches), each columns of the
## generator's colours, [] where one never settled.
var patches: Array = []
## The crypts a cemetery level built (Crypts), each a Dictionary (see Crypts).
var crypts: Array[Dictionary] = []
## The halls an institute level built (Institute), each a Dictionary (see Institute).
var halls: Array[Dictionary] = []
## The open box inside an institute level's bell room (Institute.BELFRY_INSIDE), where its first
## great bell hangs; empty where it has none.
var belfry: Rect2i = Rect2i()
## The towers an archetype built (CragsArchetype.build_towers), each a Dictionary (see
## CragsArchetype._tower).
var towers: Array[Dictionary] = []
## The temples a sky level built (SkyArchetype.build_temples), each {"box": its cells, Rect2i;
## "hall": the open hall's rows, Rect2i; "altar": the altar's cell; "hoard": its star clusters'
## cells, there once it is opened}.
var temples: Array[Dictionary] = []

## Whether cell `v` holds a temple's hoard (there only once it is opened, Temple).
func in_temple_hoard (v: Vector2i) -> bool:
	return temples.any(func(t: Dictionary) -> bool: return (t["hoard"] as Array).has(v))
## The gondola's circuit an archetype laid (CragsArchetype.lay_circuit), or {} for none.
var circuit: Dictionary = {}
## The lines between a crags level's tiers, bottom up (CragsArchetype.cut_tiers): each {"rows": the
## row under the upper station's landing and the one under that}. Empty for none.
var tiers: Array[Dictionary] = []
## A crags level's lodestone (CragsArchetype.place_lodestone), or (-1, -1) for none.
var lodestone: Vector2i = Vector2i(-1, -1)
## The shrine's cell (its boon side; mending is the cell to the right), or (-1, -1).
var shrine: Vector2i = Vector2i(-1, -1)

## The colour a sample paints open sky in: open air, as white is, but outside every cluster of
## islands (the sky's sample, tests/make_sky_sample.gd). A level's clusters are laid with it round
## them (WaveFunctionCollapse.collapse_clusters), and the cells laid this colour are kept in
## `open_sky`, so the level can tell a cluster's own air from the sky between.
const SKY: Color = Color(0.0, 0.0, 1.0)

var color_to_type: Dictionary = {
	Color.WHITE: 	Type.EMPTY,
	Color.BLACK: 	Type.GROUND,
	Color.RED: 		Type.SPIKES,
	SKY: 			Type.EMPTY,
}

## Per cell, 1 where the collapse gave open sky (SKY), 0 elsewhere; empty for a level whose sample
## paints none.
var open_sky: PackedByteArray = PackedByteArray()

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
	return v.x >= 0 and v.y >= 0 and v.x < size.x and v.y < size.y and types[v.x * size.y + v.y] == Type.GROUND

func get_cell (v: Vector2i) -> Cell:
	return cells[v.x][v.y]

## The type of cell `v` (inside the level), as get_cell(v).type, read from `types`.
func type_at (v: Vector2i) -> Type:
	return types[v.x * size.y + v.y] as Type

## Make cell `v` (if not null) `cell`. Every change of a cell goes through here, so `types` stays
## in step with `cells`.
func set_cell (v: Variant, cell: Cell) -> void:
	if v != null:
		cells[v.x][v.y] = cell
		types[v.x * size.y + v.y] = cell.type

func ground_below (v: Vector2i) -> bool:
	return v.x >= 0 and v.y >= -1 and v.x < size.x and v.y < size.y - 1 and types[v.x * size.y + v.y + 1] == Type.GROUND

func add_object_at (v: Vector2i) -> void:
	empties.erase(v)
	grounds.erase(v)
	objects.append(v)

## Move what is in cell `from` to free cell `to`, keeping its place among the level's objects (a
## crag tower's key or switch, CragsArchetype; a crypt's cluster, Crypts).
func move_object (from: Vector2i, to: Vector2i) -> void:
	var cell: Cell = get_cell(from)
	objects[objects.find(from)] = to
	empties.erase(to)
	set_cell(to, cell)
	set_cell(from, Cell.new(Type.EMPTY))
	empties.append(from)

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
	for exit: int in exits:
		if dist(exits[exit], v) < 3:
			return true
	return false

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
	var out: Array[Vector2i] = []
	for v: Vector2i in empties:
		# Open air (not a thing) with rock straight under it.
		if v.y + 1 < size.y and types[v.x * size.y + v.y] == Type.EMPTY and types[v.x * size.y + v.y + 1] == Type.GROUND:
			out.append(v)
	out.sort()
	return out

## The free floors of the level proper (free_floors), sorted, leaving out the vaults' rooms and the
## barriers' pockets: where something dealt once the level is laid out (a sold skeleton key, a soul
## of the beast and its guards, exam papers, the way back from a department) may lie, never shut
## behind a vault's door or a barrier made for a move the wizard may lack.
func floors_proper () -> Array[Vector2i]:
	var shut_away: Dictionary = {}
	for vault: Dictionary in vaults:
		for c: Vector2i in vault["room"]:
			shut_away[c] = true
	for barrier: Dictionary in barriers:
		for c: Vector2i in barrier["open"]:
			shut_away[c] = true
	return free_floors().filter(func(v: Vector2i) -> bool: return not shut_away.has(v))

## What every cell of the level is spoken for, as it stands now (Claims): the one place a pass that
## comes late asks before it changes a cell. Worked out afresh each time it is asked for, so ask
## once and keep it while nothing changes.
func claims () -> Claims:
	return Claims.new(self)

## The cells a lift's body and track sweep, and those a rolling ladder rolls and hangs through
## (make_moving, _make_ladder), a set: open air to look at, and off the free list, but spoken for.
var tracks: Dictionary = {}

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
		if type_at(v) == type:
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
	# The bramble's gate level: the way on stands at the head of its shaft (BrambleShaft); the
	# golem's, on its hall's top gallery (LodeHall).
	var fixed_on: Variant = shaft.get("on", keep.get("on"))
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
	# The institute's way on stands in a classroom (Institute.way_on), the spot drawn above passed over.
	var classroom: Variant = Institute.way_on(self, back)
	if classroom != null:
		deeper = classroom
	if not chosen.has(deeper):
		chosen.append(deeper)
	# At depth 0, one side door stands near the start, on floors the wizard can hop to from it,
	# so every run can get out of its first level (its key: place_start_key).
	var near: Variant = _start_door(spots, chosen, back) if depth == 0 else null
	if near != null:
		chosen.append(near)
		start_side = Ways.Exit.LEFT if (near as Vector2i).x < back.x else Ways.Exit.RIGHT
	var left: Vector2i = near if start_side == Ways.Exit.LEFT else _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.x <= lo.x + band_x)
	if start_side != Ways.Exit.LEFT:
		chosen.append(left)
	var right: Vector2i = near if start_side == Ways.Exit.RIGHT else _pick_spot(spots, chosen, func(v: Vector2i) -> bool: return v.x >= hi.x - band_x)
	if start_side != Ways.Exit.RIGHT:
		chosen.append(right)
	exits = {Ways.Exit.BACK: back, Ways.Exit.DEEPER: deeper, Ways.Exit.LEFT: left, Ways.Exit.RIGHT: right}
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
	var start: Vector2i = exits[Ways.Exit.BACK]
	var door: Vector2i = exits[start_side]
	var floors: Array[Vector2i] = []
	for v: Vector2i in start_reach:
		floors.append(v)
	floors.sort()
	var best: Variant = best_of(floors, func(v: Vector2i) -> int: return dist(v, start) + dist(v, door),
			func(v: Vector2i) -> bool: return type_at(v) == Type.EMPTY and empties.has(v) and dist(v, start) >= 3 and dist(v, door) >= 2 \
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

## Doors on the exit cells (at the start too, whose way back leads up) but those the labyrinth
## leaves out (shut), a lantern beside the way back (the start lantern, at the start; there even
## where its door is not), then the shrine. Lanterns are scarce: the other exits
## have none.
func _finish_exits (spots: Array[Vector2i], chosen: Array[Vector2i], _depth: int) -> void:
	for which: int in [Ways.Exit.BACK, Ways.Exit.DEEPER, Ways.Exit.LEFT, Ways.Exit.RIGHT]:
		var at: Vector2i = exits[which]
		if not shut.has(which):
			put(at, Type.EXIT, which)
		if which != Ways.Exit.BACK:
			continue
		var lantern: Variant = _nearest_free(spots, at, chosen)
		if lantern != null:
			chosen.append(lantern)
			put(lantern, Type.CHECKPOINT)
			exit_lanterns[which] = lantern
	_place_shrine(spots, chosen, exits[Ways.Exit.DEEPER])

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
	exits = {Ways.Exit.BACK: back, Ways.Exit.DEEPER: picks[0], Ways.Exit.LEFT: picks[1], Ways.Exit.RIGHT: picks[2]}
	_finish_exits(spots, chosen, depth)

## Pockets of open space smaller than this are filled with rock rather than tunnelled to.
const POCKET: int = 6

## Join every open space into one cave. Tiny pockets fill with rock; every other open region
## is joined to the largest by carving the shortest tunnel through the rock between them,
## nearest region first, until one region remains. Deterministic: fixed scan and BFS orders.
## No tunnel goes through the cells in `walled` (the bramble's shaft, BrambleShaft) or through
## rock kept whole (kept_whole), though a tunnel may end at open air kept whole.
func connect_caves (walled: Dictionary = {}) -> void:
	var groups: Array = _open_regions()
	for g: Array in groups:
		if g.size() < POCKET:
			for v: Vector2i in g:
				if not kept(v):
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
	# The open cells in the level, counted once and kept as the tunnels are carved.
	var open_cells: int = _open_count()
	var guard: int = 0
	while main.size() < open_cells and guard < 200:
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
				# Rock kept whole is never tunnelled through, but open air kept whole (a tower's
				# rooms, the air at its doorway) is still reached: else a pocket of it alone stays
				# shut off.
				if kept_whole.has(n) and not (_open(n) and not main.has(n)):
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
				open_cells += 1
			main[at] = true
			at = parent[at]
		_flood(found, main)

## How many cells of the level are open (_open).
func _open_count () -> int:
	return types.size() - types.count(Type.GROUND) - types.count(Type.CRACKED)

## Every connected open region (4-neighbour), in scan order.
func _open_regions () -> Array:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(types.size())
	seen.fill(0)
	var out: Array = []
	for x: int in range(size.x):
		for y: int in range(size.y):
			var i: int = x * size.y + y
			if seen[i] == 0 and types[i] != Type.GROUND and types[i] != Type.CRACKED:
				var region: Dictionary = {}
				_flood(Vector2i(x, y), region)
				for c: Vector2i in region:
					seen[c.x * size.y + c.y] = 1
				var cells_in: Array = region.keys()
				cells_in.sort()
				out.append(cells_in)
	return out

## Add the open region containing `from` to `into`.
func _flood (from: Vector2i, into: Dictionary) -> void:
	reach_from(from, Callable(), into)

## Every cell reached from `start` through open air (4-neighbour), where `passable(cell)` also
## holds (every open cell, without it); a set (cell -> true), `start` among them. Given `into`,
## the cells already in it are not walked through again and those found are added to it. The
## order cells are found in is not kept: sort before drawing.
func reach_from (start: Vector2i, passable: Callable = Callable(), into: Dictionary = {}) -> Dictionary:
	var any: bool = passable.is_null()
	# Begun afresh, the cells found are marked in a packed array, quicker to ask than `into`.
	var fresh: bool = into.is_empty()
	var marks: PackedByteArray = PackedByteArray()
	if fresh:
		marks.resize(types.size())
		marks.fill(0)
		if is_valid(start):
			marks[start.x * size.y + start.y] = 1
	var stack: Array[Vector2i] = [start]
	into[start] = true
	while not stack.is_empty():
		var v: Vector2i = stack.pop_back()
		for d: Vector2i in neighbor_offsets:
			var n: Vector2i = v + d
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
				continue
			var i: int = n.x * size.y + n.y
			if (marks[i] == 1) if fresh else into.has(n):
				continue
			var t: int = types[i]
			if t != Type.GROUND and t != Type.CRACKED and (any or passable.call(n)):
				into[n] = true
				if fresh:
					marks[i] = 1
				stack.append(n)
	return into

func _to_rock (v: Vector2i) -> void:
	set_cell(v, Cell.new(Type.GROUND))
	empties.erase(v)
	objects.erase(v)
	grounds.append(v)

## The cells make_room carved out.
var carved: Array[Vector2i] = []

## Carve out the rock (and thorns) in every thing's box: the cells across and up it takes from its
## own cell (the bottom left), where that is more than one (Placeables.size), so a tall doorway or
## portal never prints into the rock over it. Never a secret room's rock or the rock sealing it
## (either would give the room away), a vault's walls, the rock framing a door or switch gate above
## or below it, the rock a laser is set in, or the rock on and under the start's way to its side
## door and key (keep_clear), which every run must be able to hop.
func make_room () -> void:
	for v: Vector2i in objects.duplicate():
		var size: Vector2i = Placeables.size(type_at(v))
		if size == Vector2i.ONE:
			continue
		for dx: int in range(size.x):
			for dy: int in range(size.y):
				var c: Vector2i = v + Vector2i(dx, -dy)
				if c == v or not is_valid(c) or not type_at(c) in [Type.GROUND, Type.SPIKES]:
					continue
				if _holds_up(c):
					continue
				_to_open(c)
				carved.append(c)

## The cells above and below a cell, and what rock framing it above or below holds (_holds_up).
const UP_DOWN: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN]
const FRAMED: Array[Type] = [Type.DOOR, Type.SWITCH_GATE, Type.EXAM_DOOR]

## Whether rock at `c` walls a vault, frames a door or gate (above or below it), is kept whole
## (kept), seals a secret room or holds up the floor its way in is taken from (secret_steps), has a
## laser set in it, is the footing of a gap's shore, holds up something stood at, or lies on or
## under the start's way (keep_clear).
func _holds_up (c: Vector2i) -> bool:
	if vault_walls.has(c) or kept(c) or secret_steps.has(c) or keep_clear.has(c) or keep_clear.has(c + Vector2i.UP):
		return true
	for d: Vector2i in UP_DOWN:
		if is_valid(c + d) and type_at(c + d) in FRAMED:
			return true
	if is_valid(c + Vector2i.UP) and Placeables.has_flag(type_at(c + Vector2i.UP), &"stander"):
		return true
	for chasm: Dictionary in chasms:
		if c == (chasm["left"] as Vector2i) + Vector2i.DOWN or c == (chasm["right"] as Vector2i) + Vector2i.DOWN:
			return true
	for d: Vector2i in neighbor_offsets:
		if not is_valid(c + d):
			continue
		var n: Cell = get_cell(c + d)
		# A laser's mount, or the rock sealing a secret room (its floor, walls and roof).
		if n.type == Type.LASER or (n.type == Type.CRACKED and n.extra_info != null):
			return true
	return false

func _to_open (v: Vector2i) -> void:
	set_cell(v, Cell.new(Type.EMPTY))
	grounds.erase(v)
	objects.erase(v)
	masonry.erase(v)
	if not empties.has(v):
		empties.append(v)

## As _to_open on each of `at` in turn (each once), done in one pass over the lists rather than a
## search of them for every cell: the same cells, and every list left in the same order (each
## cell's first listing taken out, as erase does; those not yet free added to `empties` in order).
func _to_open_all (at: Array[Vector2i]) -> void:
	var pending: Dictionary = {}
	for v: Vector2i in at:
		pending[v] = true
		set_cell(v, Cell.new(Type.EMPTY))
		masonry.erase(v)
	grounds = _without_first(grounds, pending)
	objects = _without_first(objects, pending)
	var free: Dictionary = empty_set()
	for v: Vector2i in at:
		if not free.has(v):
			empties.append(v)

## `list` less the first listing of each cell in `cells` (a set), the rest in order.
static func _without_first (list: Array[Vector2i], cells: Dictionary) -> Array[Vector2i]:
	var left: Dictionary = cells.duplicate()
	var out: Array[Vector2i] = []
	for v: Vector2i in list:
		if left.has(v):
			left.erase(v)
			continue
		out.append(v)
	return out

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
## With `ladders` (Archetype.ladders) it is a rolling ladder instead (RollingLadder), whose track
## always runs right (the same draws are made, so the rest of the level is dealt as before): a
## step one cell wide at the run's left end, rolling over the run and on along the track, laid only
## where its foot stands on solid ground all along the track (Ladders.stands; elsewhere the
## run stays a ledge), the air it hangs through kept clear of anything laid after it.
func make_moving (run_cells: Array[Vector2i], ladders: bool = false) -> void:
	run_cells.sort()
	var left: Vector2i = run_cells[0]
	var axis: Vector2i = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
	var travel: int = rng.randi_range(2, 4)
	if ladders:
		axis = Vector2i(1, 0)
		_make_ladder(run_cells, travel)
		return
	var track: Array[Vector2i] = []
	for k: int in range(1, travel + 1):
		if axis.x != 0:
			track.append(run_cells[-1] + Vector2i(k, 0))
		else:
			for c: Vector2i in run_cells:
				track.append(c + Vector2i(0, k))
	for p: Vector2i in track:
		if not is_valid(p) or type_at(p) != Type.EMPTY or not empties.has(p):
			return
	for p: Vector2i in track:
		empties.erase(p)
		tracks[p] = true
	for c: Vector2i in run_cells.slice(1):
		set_cell(c, Cell.new(Type.EMPTY))
		objects.erase(c)
		tracks[c] = true
	set_kind(left, Type.MOVING_PLATFORM, [run_cells.size(), axis, travel])

## A rolling ladder made of platform run `run_cells` (sorted) with `travel` cells of track past it
## (see make_moving).
func _make_ladder (run_cells: Array[Vector2i], travel: int) -> void:
	var left: Vector2i = run_cells[0]
	var track: Array[Vector2i] = []
	for k: int in range(1, travel + 1):
		track.append(run_cells[-1] + Vector2i(k, 0))
	for p: Vector2i in track:
		if not is_valid(p) or type_at(p) != Type.EMPTY or not empties.has(p):
			return
	var reach: int = run_cells.size() - 1 + travel
	var rungs: int = Ladders.stands(self, left, reach)
	if rungs <= 0:
		return
	for p: Vector2i in track:
		empties.erase(p)
		tracks[p] = true
	for c: Vector2i in run_cells.slice(1):
		set_cell(c, Cell.new(Type.EMPTY))
		objects.erase(c)
		tracks[c] = true
	for x: int in range(left.x, left.x + reach + 1):
		for y: int in range(left.y + 1, left.y + rungs):
			empties.erase(Vector2i(x, y))
			tracks[Vector2i(x, y)] = true
		# The floor its foot rolls along stays whole: no cracked wall is made of it.
		kept_whole[Vector2i(x, left.y + rungs)] = true
	set_kind(left, Type.ROLLING_LADDER, [1, Vector2i(1, 0), reach])

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
		if f.call(v):
			add_object_at(v)
			return v
	if force:
		for v: Vector2i in empties:
			if f.call(v):
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
## The ways out the labyrinth leaves out of this level (NextWorldDef.shut), a set: their spots
## are still picked (the level's start stays by its way back's), but no door stands on them.
var shut: Dictionary = {}
## The boss whose gate this level is (Bosses; &"" for none, and in every side world), for the
## passes that build what a boss needs into its gate level (the beast's chamber, Institute).
var gate: StringName = &""

## For the benches (bench_gen -- passes): called with each pass's name as laying a level out
## finishes it (the passes of populate_level, then those _init does after it). Empty in the game.
static var on_pass: Callable = Callable()

## Pass `pass_name` is done: on_pass is told (if set), and the passes after it draw from a stream of
## their own, seeded from the level's seed and the name of the pass just done (docs/CODE_REVIEW.md
## 2.4). So a draw added to, dropped from or moved within one pass changes what that pass lays and
## what is built on it, but not what the passes after it draw: retuning one band's dressing does
## not re-deal everything laid later. The name is mixed in by its letters, not by the engine's
## hashing, which may change.
func _mark (pass_name: StringName) -> void:
	if not on_pass.is_null():
		on_pass.call(pass_name)
	var named: int = Salts.LEVEL_GEN_PASS * Salts.STRIDE
	for code: int in String(pass_name).to_utf8_buffer():
		named = (named * 31 + code) & 0x7fffffff
	rng.seed = Rules.level_seed(seed_for_colors, named)

func _init (_cells: Array, def: NextWorldDef) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = def.gen_seed
	seed_for_colors = def.gen_seed
	depth = def.depth
	gate = &"" if Worlds.is_side(def.coord) else def.gate
	for exit: int in def.shut:
		shut[exit] = true
	# The small insides collapsed with the terrain come after its columns (WaveFunctionCollapse).
	if not _cells.is_empty() and _cells.back() is Dictionary:
		patches = (_cells.back() as Dictionary).get("patches", [])
		_cells = _cells.slice(0, _cells.size() - 1)
	size = Vector2i(len(_cells), len(_cells[0]))
	cells = []
	types.resize(size.x * size.y)

	for i: int in len(_cells):
		var row: Array[Cell] = []
		for j: int in len(_cells[i]):
			var cell: Cell = new_cell_by_color(_cells[i][j])
			if Color(_cells[i][j]) == SKY:
				if open_sky.is_empty():
					open_sky.resize(size.x * size.y)
					open_sky.fill(0)
				open_sky[i * size.y + j] = 1
			row.append(cell)
			types[i * size.y + j] = cell.type
			add_cell_to_container(Vector2i(i, j), cell)
		cells.append(row)
	_mark(&"cells")

	def.populate(self)
	# Whatever kind of place it is, big things get room (see make_room).
	make_room()
	_mark(&"make_room")
	# Then thorns that come and go, on the runs room was made round (a switch never names a thorn
	# that is gone); the last draws of the level's own laying out, as before.
	if _thorns_due != null:
		place_thorn_modes(_thorns_due)
		_thorns_due = null
	_mark(&"thorn_modes")
	deal_colors()
	_mark(&"deal_colors")
	if not Worlds.is_side(def.coord):
		place_lift_switches()
	_mark(&"lift_switches")
	# A barrier made for a relic move, carved into solid rock off the level (Barriers): after all
	# else of the level's own, so nothing laid before it moves.
	Barriers.lay(self, def)
	_mark(&"barriers")
	# A gate level: its boss (Bosses), placed last, with no RNG draws.
	if not Worlds.is_side(def.coord) and def.gate != &"":
		place_boss(def.gate)
	# Doors laid once all else is (the tutorial's), with no RNG draws, so they move nothing.
	place_side_doors(def, true)
	_mark(&"boss")

## A gate level's boss: on the free floor nearest the way on it guards, at least BOSS_APART cells
## from it; the bramble in the knot at the head of its shaft (BrambleShaft), its cell the knot's
## bottom corner beside the landing; the golem in its lair on its hall's ground floor, and the hall's
## crossbows with it (LodeHall.arm); the necromancer at the deepest floor of the level's first
## crypt (Crypts), which holds nothing else; the beast in the middle of its chamber's floor
## (Institute), which holds nothing else either. The boss is placed in every visit's layout;
## the loader leaves it out once it is slain (RunState.bosses).
const BOSS_APART: int = 4

func place_boss (boss: StringName) -> void:
	# The whale is in no gate level of its own: it roams its row (WhaleHunt, Whale).
	if not exits.has(Ways.Exit.DEEPER) or boss == &"whale":
		return
	if not keep.is_empty():
		put(keep["lair"], Type.BOSS, boss)
		LodeHall.arm(self)
		return
	if boss == &"necromancer" and not crypts.is_empty() and not (crypts[0]["floors"] as Array).is_empty():
		put(crypts[0]["deep"], Type.BOSS, boss)
		return
	var chamber: Dictionary = Institute.chamber(self) if boss == &"beast" else {}
	if not chamber.is_empty():
		var inside: Rect2i = chamber["inside"]
		@warning_ignore("integer_division")
		put(Vector2i(inside.position.x + inside.size.x / 2, inside.end.y - 1), Type.BOSS, boss)
		return
	if not shaft.is_empty():
		var knot: Rect2i = shaft["knot"]
		var beside: int = knot.position.x if knot.position.x > (shaft["inside"] as Rect2i).position.x else knot.end.x - 1
		put(Vector2i(beside, knot.end.y - 1), Type.BOSS, boss)
		return
	var on: Vector2i = exits[Ways.Exit.DEEPER]
	var spot: Variant = best_of(free_floors(), func(v: Vector2i) -> int: return dist(v, on),
			func(v: Vector2i) -> bool: return dist(v, on) >= BOSS_APART and not _crowds_exit(v))
	if spot != null:
		put(spot, Type.BOSS, boss)

## Some of an ordinary level's lifts wait for a switch: parked at the start of their track until
## it is thrown, then running for good (the record keeps it). LIFT_SWITCH_SHARE of them, picked by
## hashing the level seed and the lift's cell, with the switch on the free floor nearest the lift
## within LIFT_SWITCH_NEAR cells, reachable from the way in, outside the vaults. Ordinary levels
## never need a lift to get through, so a parked one blocks nothing; side worlds' lifts
## (hyperspace's crossings) always run. The lift's extra info gains the switch's cell, and the
## switch holds the lift's. Done last and with no world RNG draws, so nothing else in the level
## moves.
const LIFT_SWITCH_SHARE: float = 0.5
const LIFT_SWITCH_NEAR: int = 6
const LIFT_SWITCH_DEAL: int = Salts.LEVEL_GEN_LIFT_SWITCH * Salts.STRIDE
func place_lift_switches () -> void:
	var start: Vector2i = exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	if not is_valid(start):
		return
	var reach: Dictionary = reach_from(start)
	# Never in a vault, as switch_floor keeps out of them.
	var locked: Dictionary = {}
	for vault: Dictionary in vaults:
		for c: Vector2i in vault["room"]:
			locked[c] = true
	# The free floors, kept as each switch takes one (nothing else here changes them).
	var floors: Array[Vector2i] = free_floors()
	for lift: Vector2i in objects_of(Type.MOVING_PLATFORM):
		var info: Array = get_cell(lift).extra_info
		if info.size() > 3:
			continue
		var roll: int = posmod(Rules.level_seed(seed_for_colors, LIFT_SWITCH_DEAL + lift.x * 977 + lift.y), 1000)
		if float(roll) / 1000.0 >= LIFT_SWITCH_SHARE:
			continue
		var spot: Variant = best_of(floors, func(v: Vector2i) -> int: return dist(v, lift),
				func(v: Vector2i) -> bool: return reach.has(v) and dist(v, lift) <= LIFT_SWITCH_NEAR and not _crowds_exit(v) and not locked.has(v))
		if spot == null:
			continue
		info.append(spot)
		put(spot, Type.SWITCH, lift)
		floors.erase(spot)

## Salts for the level seed when dealing key and door colours (deal_colors).
const KEY_DEAL: int = Salts.LEVEL_GEN_KEY * Salts.STRIDE
const DOOR_DEAL: int = Salts.LEVEL_GEN_DOOR * Salts.STRIDE
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
				cell.extra_info = Keys.SKELETON
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
	_mark(&"shape")
	# One cave: every open space joined up, so everything placed below is connected to
	# everything else through open air (gates and abilities aside).
	connect_caves()
	_mark(&"connect_caves")
	# The crags' way up: the golem's hall, cut before the gondola and the towers so they are laid
	# round it (only in its gate levels).
	if LodeHall.wanted(def):
		LodeHall.cut(self)
	arch.cut_gates(self)
	_mark(&"cut_gates")
	# The garden's way up: the bramble's shaft, cut before anything is placed so the rest lands
	# round it (only in its gate levels).
	if BrambleShaft.wanted(def):
		BrambleShaft.cut(self)
	_mark(&"bramble_shaft")

	# Exits and their lanterns first, so they get the pick of the level.
	place_exits(def.depth, def.debug, def.coord.y < 0)
	place_side_doors(def)
	place_start_key(def)
	_mark(&"exits")
	Chasms.place_bells(self, arch.crossing, arch.switch_reach)
	_mark(&"bells")
	if def.arrival_from != null:
		place_return()

	# One ink well per level (the map), on the floor nearest the level's middle.
	place_inkwell()
	_mark(&"return_and_inkwell")

	# Spots for keys: more than are kept (see KEYS_PER_K and deal_colors).
	for i: int in range(maxi(Rules.KEY_COLOR_COUNT, per_area(KEY_SPOTS_PER_K))):
		put_random(Type.KEY)
	_mark(&"keys")

	place_doors(per_area(DOORS_PER_K))
	_mark(&"doors")
	place_switch_gates(maxi(1, per_area(SWITCH_GATES_PER_K)))
	_mark(&"switch_gates")

	# Stars, where the archetype has room for them (in the sky, only in and near the clusters).
	for i: int in range(len(empties) * arch.star_share):
		put_random(Type.COIN, func(v: Vector2i) -> bool: return arch.room(self, v, 3))
	_mark(&"stars")

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
			if platform_budget <= 0 or not is_valid(run) or type_at(run) != Type.EMPTY or not empties.has(run):
				break
			put(run, Type.PLATFORM)
			run_cells.append(run)
			platform_budget -= 1
		if run_cells.size() <= 3 and rng.randf() < MOVING_PLATFORM_CHANCE:
			make_moving(run_cells, arch.ladders)
	_mark(&"ledges")

	# Moons (dash resets) once the ledges are down: open air with nothing to stand on below.
	place_moons(per_area(MOONS_PER_K))
	_mark(&"moons")

	for i: int in range(int(len(empties) * arch.wisp_share * Difficulty.foes())):
		put_random(Type.ENEMY, ground_below)

	for i: int in range(int(len(empties) * arch.watcher_share * Difficulty.foes())):
		put_random(Type.SHOOTER, ground_below)

	for i: int in range(per_area(LANTERNS_PER_K)):
		put_random(Type.CHECKPOINT, ground_below, true)
	_mark(&"foes_and_lanterns")

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

	_mark(&"portals")
	place_cracks(per_area(CRACKS_PER_K))
	_mark(&"cracks")

	# Placed last, so everything above lands where it always has.
	if def.depth >= 1:
		for i: int in range(foes_per_area(arch.hoppers_per_k)):
			put_random(Type.HOPPER, ground_below, true)
	_mark(&"hoppers")
	arch.populate(self, def)
	_mark(&"populate")
	place_cluster(def)
	_mark(&"cluster")
	Secrets.place(self, def)
	_mark(&"secrets")
	Vaults.place(self, def)
	_mark(&"vaults")
	Chasms.relax_crossings(self, def)
	arch.finish(self, def)
	_mark(&"finish")
	# Its thorns are dealt once room is made for big things (see _init), which may clear some.
	_thorns_due = def

## The level whose thorns are still to be dealt (place_thorn_modes), set at the end of
## populate_level and dealt once room is made for big things; null when none are due.
var _thorns_due: NextWorldDef = null

## Thorns that come and go (Spikes): past the start, some runs of thorns are put on a timer and
## some on a switch, once the level is laid out and room made for big things (make_room). A run is a group of thorn cells side by side. Each
## run is dealt by hashing the level seed and its first cell (no draw): THORN_TIMED_SHARE of runs go
## on a timer, their phase hashed too, so neighbouring runs are not in step; THORN_SWITCH_SHARE go
## on a switch (at most THORN_SWITCHES_MOST a level), on a floor reached from the way in some way
## off (switch_floor: one draw each). The switch drops them while it is on. A chasm's thorns and
## the cells kept for a big thing (the bramble's shaft, the golem's hall) are never dealt, so a
## chasm still bars the way. A thorn cell's extra_info says how it goes:
## {"timed": phase in seconds} or {"switch": the switch's cell}; the switch's extra_info is the
## run's first cell.
const THORN_TIMED_SHARE: float = 0.3
const THORN_SWITCH_SHARE: float = 0.25
const THORN_SWITCHES_MOST: int = 2
## Salt for the level seed when dealing thorn runs.
const THORN_DEAL: int = Salts.LEVEL_GEN_THORN * Salts.STRIDE
func place_thorn_modes (def: NextWorldDef) -> void:
	if def.depth < 1:
		return
	var start: Vector2i = exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	# Reached from the way in without passing a door (a vault's, or any locked one).
	var reach: Dictionary = reach_from(start, func(n: Vector2i) -> bool: return type_at(n) != Type.DOOR) if is_valid(start) else {}
	var switches: int = 0
	for run: Array[Vector2i] in thorn_runs():
		var first: Vector2i = run[0]
		var roll: float = float(posmod(Rules.level_seed(seed_for_colors, THORN_DEAL + first.x * 131 + first.y * 7919), 1000)) / 1000.0
		if roll < THORN_TIMED_SHARE:
			var phase: float = float(posmod(Rules.level_seed(seed_for_colors, THORN_DEAL + 1 + first.x * 53 + first.y * 389), 1000)) / 1000.0 * Rules.THORN_CYCLE
			for c: Vector2i in run:
				get_cell(c).extra_info = {"timed": phase}
		elif roll < THORN_TIMED_SHARE + THORN_SWITCH_SHARE and switches < THORN_SWITCHES_MOST and not reach.is_empty():
			var found: Variant = switch_floor(reach, first)
			if found == null:
				continue
			var lever: Vector2i = found
			put(lever, Type.SWITCH, first)
			for c: Vector2i in run:
				get_cell(c).extra_info = {"switch": lever}
			switches += 1

## The runs of thorns that may come and go (see place_thorn_modes): groups of thorn cells side by
## side, each sorted, in order of their first cell; none at a chasm's foot or in a kept cell.
func thorn_runs () -> Array[Array]:
	var barred: Dictionary = {}
	for chasm: Dictionary in chasms:
		for plank: Vector2i in chasm["planks"]:
			for d: int in range(1, Chasms.CHASM_DEPTH + 3):
				barred[plank + Vector2i(0, d)] = true
	var seen: Dictionary = {}
	var runs: Array[Array] = []
	for x: int in range(size.x):
		for y: int in range(size.y):
			var v: Vector2i = Vector2i(x, y)
			if seen.has(v) or type_at(v) != Type.SPIKES:
				continue
			var run: Array[Vector2i] = []
			var ok: bool = true
			var stack: Array[Vector2i] = [v]
			seen[v] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				run.append(c)
				ok = ok and not barred.has(c) and not kept(c)
				for d: Vector2i in neighbor_offsets:
					var n: Vector2i = c + d
					if is_valid(n) and not seen.has(n) and type_at(n) == Type.SPIKES:
						seen[n] = true
						stack.append(n)
			if ok:
				run.sort()
				runs.append(run)
	runs.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2i) < (b[0] as Vector2i))
	return runs

## Chasms (and sky gaps) with no bell or vane, which only a relic move gets over (see
## Chasms.relax_crossings); and in hyperspace, the stretches left unbridged (Hyperspace._relic_gap).
var relic_chasms: Array[int] = []
var relic_gaps: Array[Rect2i] = []

## The bramble's shaft, in its gate levels (BrambleShaft.cut, which says what it holds); empty in
## every other level.
var shaft: Dictionary = {}

## The golem's lode hall at the top of the crags' gate levels (LodeHall.cut, which says what it
## holds); empty in every other place.
var keep: Dictionary = {}

## The cell of a sky level's balloon (SkyArchetype.place_balloon), else (-1, -1).
var balloon: Vector2i = Vector2i(-1, -1)

## Where a run that begins in this place starts, and the lantern lit for it there, when not at its
## way back and the lantern beside it (the tutorial's, Tutorial); else (-1, -1).
var start: Vector2i = Vector2i(-1, -1)
var start_lantern: Vector2i = Vector2i(-1, -1)

## Whether cell `v` is part of the golem's hall (keep): inside it, or its walls, roof or ground.
## Nothing else is built into it (secret rooms, vaults, cracked walls, climbing ledges).
func in_keep (v: Vector2i) -> bool:
	return not keep.is_empty() and (keep["box"] as Rect2i).has_point(v)

## Whether cell `v` is part of the bramble's shaft: inside it, or its walls, roof or floor. Nothing
## else is built into it (secret rooms, vaults, cracked walls, climbing ledges).
func in_shaft (v: Vector2i) -> bool:
	return not shaft.is_empty() and (shaft["inside"] as Rect2i).grow(1).has_point(v)

## Cells a built structure keeps as they are (a crag tower's stone, rooms, doorsteps, footing and
## the air over its roof, CragsArchetype; the floor a rolling ladder stands on all along its track,
## _make_ladder): nothing else cracks, carves, fills or tunnels through
## them, or builds a secret room or vault into them.
var kept_whole: Dictionary = {}

## Whether cell `v` is kept as it is: the bramble's shaft (in_shaft), the golem's hall (in_keep) or
## kept_whole.
func kept (v: Vector2i) -> bool:
	return kept_whole.has(v) or in_shaft(v) or in_keep(v)

## The level's chasms and gaps, its gates where the archetype has them (see Chasms): each
## {"planks": cells, "row": the floor row, "left": the last floor cell before it, "right": the
## first after}, numbered by their place here.
var chasms: Array = []

## The sky's islands come in clusters with open sky between them, as its sample paints them and the
## collapse lays them (SkyArchetype.read_clusters): each [centre, radii] of the box round a
## cluster's cells (isle_of).
var isles: Array = []
## Per cell, which cluster it lies in (its place in `isles`), -1 in open sky. Empty for a level
## with no clusters.
var isle_of: PackedInt32Array = PackedInt32Array()
## How many pairs of clusters the layout joined (SkyArchetype.link_isles): one fewer than the
## clusters.
var links: int = 0

## Per cell, how many cells it is from the nearest cluster (0 in one, a cell diagonally counting as
## one), up to ISLE_REACH, 255 further off (map_isles): in_isle looks it up once the clusters are
## settled.
var _isle_map: PackedByteArray = PackedByteArray()
const ISLE_REACH: int = 5

## Work out how far each cell is from the clusters (isle_of), out to ISLE_REACH cells.
func map_isles () -> void:
	_isle_map = PackedByteArray()
	_isle_map.resize(size.x * size.y)
	_isle_map.fill(255)
	var queue: PackedInt32Array = PackedInt32Array()
	for i: int in range(isle_of.size()):
		if isle_of[i] >= 0:
			_isle_map[i] = 0
			queue.append(i)
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var g: int = _isle_map[i]
		if g >= ISLE_REACH:
			continue
		@warning_ignore("integer_division")
		var x: int = i / size.y
		var y: int = i % size.y
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				var nx: int = x + dx
				var ny: int = y + dy
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
					continue
				var n: int = nx * size.y + ny
				if _isle_map[n] == 255:
					_isle_map[n] = g + 1
					queue.append(n)

## Whether `v` lies in a cluster of islands, or within `grow` cells of one (ISLE_REACH at most).
func in_isle (v: Vector2i, grow: int = 0) -> bool:
	return not _isle_map.is_empty() and is_valid(v) and _isle_map[v.x * size.y + v.y] <= mini(grow, ISLE_REACH)

## The level's star cluster (worth Rules.cluster_value): hung in open air (as a moon is) at
## least half the exit distance from the way in, three times as likely over thorns; failing
## that, on the floor furthest from the way in.
func place_cluster (def: NextWorldDef) -> void:
	var start: Vector2i = exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	@warning_ignore("integer_division")
	var far: int = Rules.exit_distance(def.depth) / 2
	var spots: Array[Vector2i] = _air_spots(func(v: Vector2i) -> bool: return type_at(v) == Type.EMPTY and _wide_open(v) and dist(v, start) >= far)
	var at: Variant = null
	if not spots.is_empty():
		at = pick(spots)
	else:
		at = best_of(free_floors(), func(v: Vector2i) -> int: return -dist(v, start))
	if at == null:
		return
	put(at, Type.CLUSTER)

## The level's secret rooms, laid by Secrets (see there), each {"room": cells, "entrance": cells,
## "rewards": [[cell, type, extra], ...]}.
var secrets: Array = []
## The master carrying the level's relic (Institute.populate: in the institute, a master out in the
## level carries it rather than a secret room or a bone vault), or (-1, -1) for none.
var relic_carrier: Vector2i = Vector2i(-1, -1)
## The level's relic waits behind a bone gate rather than in a secret room
## (Rules.RELIC_GATE_CHANCE; see Vaults.place_bone).
var relic_gated: bool = false
## Where the wizard stands to walk into each secret room (an open floor beside its way in), and the
## rock under it. What is placed after the rooms leaves them as they are (a vault or strongbox is
## not built on them, make_room does not carve them), or a room could not be walked into.
var secret_steps: Dictionary = {}
## The level's vaults, laid by Vaults (see there), each {"room": cells, "door": cell, "color": key
## colour}.
var vaults: Array = []
## The level's barrier, if it took one (Barriers): each {"kind", "move", "mouth", "side", "open",
## "thorns", "reward"}.
var barriers: Array = []
## The rock round every vault, which make_room leaves whole (it would let you in past the door).
var vault_walls: Dictionary = {}
## The relic a bone vault holds instead of its hoard (relic_gated, Vaults.place_bone), or &"".
var bone_relic: StringName = &""

## Per cell (x * size.y + y), 1 where it is kept as it is (kept): what is kept whole, the bramble's
## shaft and the golem's hall.
func kept_mask () -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(size.x * size.y)
	out.fill(0)
	for v: Vector2i in kept_whole:
		if is_valid(v):
			out[v.x * size.y + v.y] = 1
	var boxes: Array[Rect2i] = []
	if not shaft.is_empty():
		boxes.append((shaft["inside"] as Rect2i).grow(1))
	if not keep.is_empty():
		boxes.append(keep["box"] as Rect2i)
	for box: Rect2i in boxes:
		var r: Rect2i = box.intersection(Rect2i(Vector2i.ZERO, size))
		for x: int in range(r.position.x, r.end.x):
			for y: int in range(r.position.y, r.end.y):
				out[x * size.y + y] = 1
	return out

## Cracked walls: thin rock (one or two cells, open on both sides, holding up no thorns) that only
## an empowered spell breaks (Empower, CrackedWall).
## Half are picked near something worth reaching (a key, lantern, exit, shrine or ink well).
## Placed last, so they can block anything the level holds but a door: none stands within
## CRACK_DOOR_CLEAR cells of an exit (a side door among them) or a corridor door, so a run that has
## tempered no spell yet is never shut in by one (a key may well be behind one).
const CRACK_DOOR_CLEAR: int = 3

func place_cracks (count: int) -> void:
	var valuable: Array[Vector2i] = []
	var doors: Array[Vector2i] = []
	for v: Vector2i in objects:
		if type_at(v) in [Type.KEY, Type.CHECKPOINT, Type.EXIT, Type.SHRINE, Type.INKWELL]:
			valuable.append(v)
		if type_at(v) in [Type.EXIT, Type.DOOR]:
			doors.append(v)
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
			if wall.is_empty() or wall.any(func(c: Vector2i) -> bool: return kept(c) or neighbor_offsets.any(func(d: Vector2i) -> bool: return is_valid(c + d) and type_at(c + d) == Type.SPIKES)):
				continue
			if wall.any(func(c: Vector2i) -> bool: return doors.any(func(d: Vector2i) -> bool: return dist(c, d) <= CRACK_DOOR_CLEAR)):
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
			set_cell(c, Cell.new(Type.CRACKED))
			objects.append(c)
		placed += 1

## How many of something for this level: `per_k` per 1000 cells, at least one.
func per_area (per_k: float) -> int:
	return maxi(1, roundi(per_k * float(size.x * size.y) / 1000.0))

## How many of a kind of foe (an enemy or a hazard) for this level: `per_k` per 1000 cells at
## Normal, more at a harder preset (Difficulty.foes), at least one.
func foes_per_area (per_k: float) -> int:
	return per_area(per_k * Difficulty.foes())

## Gates: portcullis doors across one-cell-tall corridors (rock above and below, open to both
## sides), which the cave-joining tunnels often make. Spread out, and never right beside
## another door.
func place_doors (count: int) -> void:
	put_each(spread_out(_corridors(), count, 4), Type.DOOR)

## Free cells in a corridor one cell high (rock above and below, open air either side), off the
## ways kept clear, sorted: where a door or a switch gate fits.
func _corridors () -> Array[Vector2i]:
	return empties_where(func(v: Vector2i) -> bool: return not keep_clear.has(v) and is_ground(v + Vector2i.UP) and is_ground(v + Vector2i.DOWN) \
			and _open(v + Vector2i.LEFT) and _open(v + Vector2i.RIGHT) and type_at(v + Vector2i.LEFT) == Type.EMPTY and type_at(v + Vector2i.RIGHT) == Type.EMPTY)

## Switch gates: a gate across a corridor (rock above and below, open either side, like a door)
## and its switch on a floor some way off (switch_floor) reachable from the way in without passing that
## gate, so the switch is found on the way to it. Each records the other's cell in extra_info.

func place_switch_gates (count: int) -> void:
	var start: Vector2i = exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	if not is_valid(start):
		return
	var spots: Array[Vector2i] = _corridors()
	var placed: Array[Vector2i] = []
	while placed.size() < count and not spots.is_empty():
		var gate: Vector2i = pop_pick(spots)
		if placed.any(func(q: Vector2i) -> bool: return dist(q, gate) < 6):
			continue
		# A floor reachable from the way in with this gate shut (the gate taken as walked already,
		# so the way is never walked through it).
		var reach: Dictionary = {}
		if gate == start:
			reach = reach_from(start, func(n: Vector2i) -> bool: return n != gate)
		else:
			reach = reach_from(start, Callable(), {gate: true})
			reach.erase(gate)
		var found: Variant = switch_floor(reach, gate)
		if found == null:
			continue
		var lever: Vector2i = found
		placed.append(gate)
		put(gate, Type.SWITCH_GATE, lever)
		put(lever, Type.SWITCH, gate)

## Where a switch goes: well away from what it works, so finding one is a trip of its own. A free
## floor (open, nothing in it, rock under it) in `reach`, drawn (one draw) from those SWITCH_MIN to
## SWITCH_MAX cells from `target`; with none in that band, the nearest further off (no draw); with
## none even SWITCH_MIN away (a small side of a chasm, say), the furthest there is (no draw), never
## right beside it, and never in a vault; null, with no draw, if there is none.
const SWITCH_MAX: int = 16
const SWITCH_MIN: int = 8

func switch_floor (reach: Dictionary, target: Vector2i) -> Variant:
	var free: Dictionary = empty_set()
	var locked: Dictionary = {}
	for vault: Dictionary in vaults:
		for c: Vector2i in vault["room"]:
			locked[c] = true
	var band: Array[Vector2i] = []
	var far: Array[Vector2i] = []
	var close: Array[Vector2i] = []
	for v: Vector2i in reach:
		if not free.has(v) or type_at(v) != Type.EMPTY or not ground_below(v) or dist(v, target) < 2 or locked.has(v):
			continue
		var d: int = dist(v, target)
		(band if d >= SWITCH_MIN and d <= SWITCH_MAX else (far if d > SWITCH_MAX else close)).append(v)
	if not band.is_empty():
		band.sort()
		return pick(band)
	if not far.is_empty():
		far.sort()
		return best_of(far, func(v: Vector2i) -> int: return dist(v, target))
	close.sort()
	return best_of(close, func(v: Vector2i) -> int: return -dist(v, target))

## The ink well (the level's map) on the free floor nearest the middle of the level, among those
## reached from the way in (any free floor if none is, a random one if there is none at all). No
## draw, unless it falls back to a random floor.
func place_inkwell () -> void:
	var start: Vector2i = exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	var reach: Dictionary = reach_from(start) if is_valid(start) else {}
	var middle: Vector2i = size / 2
	var floors: Array[Vector2i] = empties_where(ground_below)
	var near: Callable = func(v: Vector2i) -> int: return dist(v, middle)
	var best: Variant = best_of(floors, near, func(v: Vector2i) -> bool: return reach.has(v) and not _crowds_exit(v))
	if best == null:
		best = best_of(floors, near)
	if best == null:
		put_random(Type.INKWELL, ground_below, true)
		return
	put(best, Type.INKWELL)

## A level a side world leads into gets an ordinary way up as well, on a floor a few cells from
## the way back (which leads into that world).
func place_return () -> void:
	var start: Vector2i = exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	if not is_valid(start):
		return
	var best: Variant = best_of(empties_where(ground_below), func(v: Vector2i) -> int: return dist(v, start),
			func(v: Vector2i) -> bool: return dist(v, start) >= 4 and not _crowds_exit(v))
	if best == null:
		return
	exits[Ways.Exit.RETURN] = best
	# Its spot is kept, as the other ways', even where the labyrinth leaves it out (shut).
	if not shut.has(Ways.Exit.RETURN):
		put(best, Type.EXIT, Ways.Exit.RETURN)

## A door into each side world the level deals (NextWorldDef.doors): a floor far from the way
## in, not crowding another exit. In a debug run it is on the floor nearest the way in instead,
## like the other exits. It is kept in `exits`, under its door number (Worlds.door).
## A kind whose door is laid last (SideWorld.laid_last) is left out, and laid alone when `last`,
## once the level is otherwise laid out: on the floor nearest the way in, with open air over it.
func place_side_doors (def: NextWorldDef, last: bool = false) -> void:
	var from: Vector2i = exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	var floors: Array[Vector2i] = empties_where(ground_below)
	var nearest: Callable = func(v: Vector2i) -> int: return dist(v, from)
	var furthest: Callable = func(v: Vector2i) -> int: return -dist(v, from)
	var free: Callable = func(v: Vector2i) -> bool: return type_at(v) == Type.EMPTY and not _crowds_exit(v)
	var free_and_open: Callable = func(v: Vector2i) -> bool:
		return bool(free.call(v)) and is_valid(v + Vector2i.UP) and type_at(v + Vector2i.UP) == Type.EMPTY
	for kind: int in def.doors:
		if Worlds.proto(kind).laid_last != last:
			continue
		var best: Variant = best_of(floors, nearest if def.debug or last else furthest, free if not last else free_and_open)
		if best == null:
			continue
		var at: Vector2i = best
		exits[Worlds.door(kind)] = at
		put(at, Type.EXIT, Worlds.door(kind))

## Moons only where the air is open: every cell within MOON_CLEARANCE is open, and the cell
## below that too, with no ledge or lift in the fall below (nothing to stand on), and
## at least MOON_SPACING apart (with no such air, any open air with nothing to stand on below).
## Air over thorns is favoured: such spots are three times as likely, since a dash reset is most
## welcome there.
func place_moons (count: int) -> void:
	var held: PackedByteArray = _held_up(_platform_footprint())
	var spots: Array[Vector2i] = _air_spots(func(v: Vector2i) -> bool: return _wide_open(v) and not _ledge_below(v, held))
	# With no wide open air left clear of ledges (a small level its ledges crowd), any open air clear
	# of them, so every level has its moons.
	if spots.is_empty():
		spots = _air_spots(func(v: Vector2i) -> bool: return not _ledge_below(v, held))
	var free: Dictionary = empty_set()
	put_each(spread_out(spots, count, MOON_SPACING, func(v: Vector2i) -> bool: return free.has(v)), Type.MOON)

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
		elif cell.type in [Type.MOVING_PLATFORM, Type.ROLLING_LADDER]:
			var motion: Array = cell.extra_info
			for step: int in range(int(motion[2]) + 1):
				for dx: int in range(int(motion[0])):
					supports[v + Vector2i(dx, 0) + (motion[1] as Vector2i) * step] = true
	return supports

## What stops a fall before it reaches a ledge (_held_up), and what a fall reaches before thorns
## (_thorns_below).
const FALL_STOPS: Array[Type] = [Type.GROUND, Type.CRACKED, Type.SPIKES]
const THORN_COVER: Array[Type] = [Type.GROUND, Type.CRACKED, Type.PLATFORM, Type.MOVING_PLATFORM, Type.ROLLING_LADDER]

## Whether a fall from `v`, straight down or a column to either side, lands on a ledge or lift
## (see _held_up, which `held` is, worked out here if not given).
func _ledge_below (v: Vector2i, held: PackedByteArray = PackedByteArray()) -> bool:
	if held.is_empty():
		held = _held_up(_platform_footprint())
	for dx: int in range(-1, 2):
		var n: Vector2i = v + Vector2i(dx, 1)
		if is_valid(n) and held[n.x * size.y + n.y] == 1:
			return true
	return false

## Per cell (x * size.y + y), 1 where a ledge or lift (a cell of `supports`) lies in it or straight
## below it before rock, cracked rock or thorns stop the fall: each column worked out once, from
## the bottom up, rather than scanned down from every cell asked about.
func _held_up (supports: Dictionary) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(size.x * size.y)
	out.fill(0)
	for x: int in range(size.x):
		var held: bool = false
		for y: int in range(size.y - 1, -1, -1):
			var v: Vector2i = Vector2i(x, y)
			if types[x * size.y + y] in FALL_STOPS:
				held = false
				continue
			held = held or supports.has(v)
			if held:
				out[x * size.y + y] = 1
	return out

func _thorns_below (v: Vector2i) -> bool:
	if v.x < 0 or v.x >= size.x:
		return false
	for y: int in range(v.y + 1, v.y + 6):
		if y < 0 or y >= size.y:
			return false
		var t: int = types[v.x * size.y + y]
		if t in THORN_COVER:
			return false
		if t == Type.SPIKES:
			return true
	return false

func _wide_open (v: Vector2i) -> bool:
	# No rock within MOON_CLEARANCE cells (all inside the level), nor the cell under that: hanging
	# in the air, not sitting just above a floor.
	var c: int = MOON_CLEARANCE
	if v.x - c < 0 or v.y - c < 0 or v.x + c >= size.x or v.y + c + 1 >= size.y:
		return false
	for x: int in range(v.x - c, v.x + c + 1):
		var column: int = x * size.y
		for y: int in range(v.y - c, v.y + c + 1):
			if types[column + y] == Type.GROUND:
				return false
	return types[v.x * size.y + v.y + c + 1] != Type.GROUND

func _open (v: Vector2i) -> bool:
	if v.x < 0 or v.y < 0 or v.x >= size.x or v.y >= size.y:
		return false
	var t: int = types[v.x * size.y + v.y]
	return t != Type.GROUND and t != Type.CRACKED

## The sigils linking this level's teleporter pairs and switches to what they work (Sigils.deal),
## dealt the first time one is asked for.
var _sigils: Variant = null

## The sigil shared by the linked thing at `v` (a teleporter, a switch, or what a switch works),
## or -1 if it has none.
func sigil_at (v: Vector2i) -> int:
	if _sigils == null:
		_sigils = Sigils.deal(self)
	return int((_sigils as Dictionary).get(v, -1))
