class_name GardenArchetype
extends Archetype
## The garden: the caves a run starts in, tunnels collapsed from the levels' own sample, gated by
## doors and switch gates in their corridors. Last of all it grows its own: seed pods in its walls
## (SeedPod), a plot to plant their seeds in (Plot) and small worms in its rock (Wormlet), see
## finish.

## Its WFC sample: the tunnels (side worlds with no sample of their own use it too).
const SAMPLE: String = "res://wfc_images/levelSample3-spikes.png"

## Seed pods per 1000 cells (times the difficulty's foes, LevelGen.foes_per_area), from depth
## PODS_FROM; each in an empty cell against a wall (rock on its left or right) with POD_ROOM cells of
## open air out from it, at least POD_CLEAR cells from the way in and POD_APART from one another.
const PODS_PER_K: float = 1.0
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


## Last, so nothing else in the level moves for them: its seed pods (place_pods), its plot
## (place_plot) and its small worms (place_worms).
func finish(w: LevelGen, def: NextWorldDef) -> void:
	if def.depth >= PODS_FROM:
		place_pods(w)
	place_plot(w)
	if def.depth >= PODS_FROM:
		place_worms(w, def.coord.y)


## The cells inside the level's vaults, where nothing of the garden's grows.
static func _vaulted(w: LevelGen) -> Dictionary:
	var out: Dictionary = {}
	for vault: Dictionary in w.vaults:
		for c: Vector2i in vault["room"]:
			out[c] = true
	return out


## Seed pods (PODS_PER_K), each grown out of a wall (see the consts).
static func place_pods(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var vaulted: Dictionary = _vaulted(w)
	var spots: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool:
		if w.type_at(v) != LevelGen.Type.EMPTY or vaulted.has(v) or LevelGen.dist(v, start) < POD_CLEAR:
			return false
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			if not w.is_ground(v + side):
				continue
			var open: bool = true
			for k: int in range(1, POD_ROOM + 1):
				var out: Vector2i = v - side * k
				open = open and w.is_valid(out) and not w.is_ground(out)
			if open:
				return true
		return false)
	w.put_each(w.pick_apart(spots, w.foes_per_area(PODS_PER_K), POD_APART), LevelGen.Type.POD)


## The level's plot, on a free floor with air over it (see the consts).
static func place_plot(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
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
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var vaulted: Dictionary = _vaulted(w)
	var spots: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool:
		return not vaulted.has(v) and LevelGen.dist(v, start) >= WORM_CLEAR)
	w.put_each(w.pick_apart(spots, w.foes_per_area(WORMS_PER_K * (1.0 + WORMS_TOWARD * toward)), WORM_APART), LevelGen.Type.WORMLET)
