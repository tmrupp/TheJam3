class_name GardenArchetype
extends Archetype
## The garden: the caves a run starts in, tunnels collapsed from the levels' own sample, gated by
## doors and switch gates in their corridors. Last of all it grows its own: seed pods in its walls
## (SeedPod), a plot to plant their seeds in (Plot) and small worms in its rock (Wormlet), and in
## the levels near a gate the spares that are its boss's signs (place_spares), see finish.

## Its WFC sample: the tunnels (side worlds with no sample of their own use it too).
const SAMPLE: String = "res://wfc_images/levelSample3-spikes.png"

## Seed pods per 1000 cells (times the difficulty's foes, LevelGen.foes_per_area), from depth
## PODS_FROM, up to PODS_TOWARD more on the rows above the start toward the bramble's gate (in
## proportion to the way there, as the small worms rise toward the worm's); each in an empty cell
## against a wall (rock on its left or right) with POD_ROOM cells of open air out from it, at least
## POD_CLEAR cells from the way in and POD_APART from one another.
const PODS_PER_K: float = 1.0
const PODS_TOWARD: float = 1.0
const PODS_FROM: int = 1
const POD_ROOM: int = 2
const POD_CLEAR: int = 8
const POD_APART: int = 6
## One plot a level: on a free floor with air over it, at least PLOT_CLEAR cells from the way in.
const PLOT_CLEAR: int = 6
## Small worms per 1000 cells (times the difficulty's foes), from depth PODS_FROM, up to twice as many
## on the rows toward the worm's gate (WORMS_TOWARD more at the gate, in proportion to the way there),
## each on a free floor at least WORM_CLEAR cells from the way in and WORM_APART from one another.
const WORMS_PER_K: float = 0.8
const WORMS_TOWARD: float = 1.0
const WORM_CLEAR: int = 8
const WORM_APART: int = 5


func _init() -> void:
	name = &"garden"
	title = "The Garden"
	sample = SAMPLE


## Spares, the garden bosses' signs (docs/REVIEW_PLAN.md §2.3, 2.4): laid in every garden level
## within Bosses.SIGN_REACH rows of a garden boss's gate on its side of the start (not the gate
## level itself), so many a 1000 cells (times the difficulty's foes): small worms near the worm,
## seed pods and thorn vines (GardenVine) near the bramble. Each is marked a spare of its boss with
## its order (the cell's mods), and the loader keeps as many as the run's nearness to the boss calls
## for (Bosses.near, spare_kept): a layout cannot know which column the run's boss is in. A vine wants
## VINE_ROOM cells of open air out of its wall (it lashes BrambleVine.REACH).
const SPARE_WORMS_PER_K: float = 0.8
const SPARE_PODS_PER_K: float = 0.6
const SPARE_VINES_PER_K: float = 0.8
const VINE_ROOM: int = 3
const VINE_APART: int = 5


## Last, so nothing else in the level moves for them: its seed pods (place_pods), its plot
## (place_plot) and its small worms (place_worms); and after them all its bosses' signs
## (place_spares).
func finish(w: LevelGen, def: NextWorldDef) -> void:
	if def.depth >= PODS_FROM:
		place_pods(w, def.coord.y)
	place_plot(w)
	if def.depth >= PODS_FROM:
		place_worms(w, def.coord.y)
	if def.depth >= PODS_FROM:
		place_spares(w, def.coord.y)


## The cells inside the level's vaults, where nothing of the garden's grows.
static func _vaulted(w: LevelGen) -> Dictionary:
	var out: Dictionary = {}
	for vault: Dictionary in w.vaults:
		for c: Vector2i in vault["room"]:
			out[c] = true
	return out


## Seed pods (PODS_PER_K, more toward the bramble's gate on row `row`), each grown out of a wall
## (see the consts).
static func place_pods(w: LevelGen, row: int) -> void:
	var gate: int = Bosses.row_of(&"bramble")
	var toward: float = clampf(float(row) / float(gate), 0.0, 1.0) if gate != 0 else 0.0
	w.put_each(w.pick_apart(_wall_spots(w, POD_ROOM), w.foes_per_area(PODS_PER_K * (1.0 + PODS_TOWARD * toward)), POD_APART), LevelGen.Type.POD)


## The empty cells against a wall (rock left or right) with `room` cells of open air out from it, at
## least POD_CLEAR from the way in and outside the vaults.
static func _wall_spots(w: LevelGen, room: int) -> Array[Vector2i]:
	var start: Vector2i = w.exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	var vaulted: Dictionary = _vaulted(w)
	return w.empties_where(func(v: Vector2i) -> bool:
		if w.type_at(v) != LevelGen.Type.EMPTY or vaulted.has(v) or LevelGen.dist(v, start) < POD_CLEAR:
			return false
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			if not w.is_ground(v + side):
				continue
			var open: bool = true
			for k: int in range(1, room + 1):
				var out: Vector2i = v - side * k
				open = open and w.is_valid(out) and not w.is_ground(out)
			if open:
				return true
		return false)


## The level's plot, on a free floor with air over it (see the consts).
static func place_plot(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	var vaulted: Dictionary = _vaulted(w)
	var spots: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool:
		return not vaulted.has(v) and LevelGen.dist(v, start) >= PLOT_CLEAR and w.is_valid(v + Vector2i.UP) and not w.is_ground(v + Vector2i.UP))
	if not spots.is_empty():
		w.put(w.pick(spots), LevelGen.Type.PLOT)


## Small worms (WORMS_PER_K, more toward the worm's gate on row `row`), each on a free floor (see
## the consts).
static func place_worms(w: LevelGen, row: int) -> void:
	var gate: int = Bosses.row_of(&"worm")
	var toward: float = clampf(float(row) / float(gate), 0.0, 1.0) if gate != 0 else 0.0
	var start: Vector2i = w.exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	var vaulted: Dictionary = _vaulted(w)
	var spots: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool:
		return not vaulted.has(v) and LevelGen.dist(v, start) >= WORM_CLEAR)
	w.put_each(w.pick_apart(spots, w.foes_per_area(WORMS_PER_K * (1.0 + WORMS_TOWARD * toward)), WORM_APART), LevelGen.Type.WORMLET)


## The spares, the bosses' signs, in a level on row `row` (see SPARE_WORMS_PER_K): near the worm's
## gate small worms on free floors, near the bramble's seed pods and thorn vines out of its walls,
## each kept as far from the level's own of its kind as they are from one another.
static func place_spares(w: LevelGen, row: int) -> void:
	if Bosses.gate_at(row) != &"":
		return
	var worm: int = Bosses.row_of(&"worm")
	if worm != 0 and signi(row) == signi(worm) and absi(row - worm) < Bosses.SIGN_REACH:
		var start: Vector2i = w.exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
		var vaulted: Dictionary = _vaulted(w)
		var floors: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool:
			return not vaulted.has(v) and LevelGen.dist(v, start) >= WORM_CLEAR)
		_spares(w, w.pick_apart(floors, w.foes_per_area(SPARE_WORMS_PER_K), WORM_APART, w.objects_of(LevelGen.Type.WORMLET)), LevelGen.Type.WORMLET, &"worm")
	var bramble: int = Bosses.row_of(&"bramble")
	if bramble != 0 and signi(row) == signi(bramble) and absi(row - bramble) < Bosses.SIGN_REACH:
		_spares(w, w.pick_apart(_wall_spots(w, POD_ROOM), w.foes_per_area(SPARE_PODS_PER_K), POD_APART, w.objects_of(LevelGen.Type.POD)), LevelGen.Type.POD, &"bramble")
		_spares(w, w.pick_apart(_wall_spots(w, VINE_ROOM), w.foes_per_area(SPARE_VINES_PER_K), VINE_APART), LevelGen.Type.VINE, &"bramble")


## Lay `type` at `spots`, each marked a spare of `boss` with its order and how many there are.
static func _spares(w: LevelGen, spots: Array[Vector2i], type: LevelGen.Type, boss: StringName) -> void:
	w.put_each(spots, type)
	for i: int in range(spots.size()):
		var cell: LevelGen.Cell = w.get_cell(spots[i])
		cell.mods["spare"] = i
		cell.mods["spares"] = spots.size()
		cell.mods["spare_of"] = boss
