class_name CemeteryArchetype
extends Archetype
## The cemetery: a hillside graveyard of terraces (wfc_images/graveyard.png, drawn by
## tests/make_graveyard_sample.gd, collapsed unturned), printed in its own realm with its own decor.
## Its gates are chasms cut across the terraces, bridged once a grave bell is rung (Chasms). Moths,
## sleep fog and wraiths live there (populate). One or two crypts are dug into its hillside (Crypts),
## their insides collapsed from a sample of their own (patches) and dark inside, with skeletons
## asleep in them and snuffing fonts by their doorways; more fonts stand about its terraces
## (finish). Some levels have no fonts at all (Rules.fontless_at), and its crypts hold sun and
## shade blocks and, in some, ossuary doors (Crypts.phase).

const SAMPLE: String = "res://wfc_images/graveyard.png"
## Moth swarms (one by each lantern, and these more), banks of sleep fog and wraiths, per 1000
## cells.
const MOTHS_PER_K: float = 0.6
const FOG_PER_K: float = 2.0
const WRAITHS_PER_K: float = 0.9
## How much bigger than Rules.level_size its levels are, across and down: room for its crypts and
## the rock round them.
const SCALE: Vector2 = Vector2(1.12, 1.12)
## Snuffing fonts about the terraces, besides those by the crypts' doorways, per 1000 cells; each
## at least FONT_APART cells from another font and FONT_CLEAR from the way in. Their places are
## hashed from the level seed (FONT_DEAL), not drawn from the world RNG.
const FONTS_PER_K: float = 2.5
const FONT_APART: int = 9
const FONT_CLEAR: int = 4
const FONT_DEAL: int = 6200


func _init() -> void:
	name = &"cemetery"
	title = "The Cemetery"
	decor = &"cemetery"
	sample = SAMPLE
	symmetry = 1
	chasmed = true
	scale = SCALE


func cut_gates(w: LevelGen) -> void:
	Chasms.carve(w)
	Crypts.build(w)


## The crypts' insides (Crypts).
func patches(_def: NextWorldDef) -> Array[Dictionary]:
	return Crypts.patches()


## Last of all: what the crypts hold (Crypts.furnish), the fonts about the terraces (none at all in
## a level the seed leaves without, Rules.fontless_at: dry_up), and the crypts' sun and shade
## blocks and ossuary doors (Crypts.phase).
func finish(w: LevelGen, def: NextWorldDef) -> void:
	Crypts.furnish(w, def)
	if Rules.fontless_at(def.coord):
		dry_up(w)
	else:
		scatter_fonts(w)
	Crypts.phase(w, def)


## Take away every snuffing font in `w` (those the crypts laid by their doorways): its cells are
## free again, as they were before the fonts were laid.
static func dry_up(w: LevelGen) -> void:
	for v: Vector2i in w.objects_of(LevelGen.Type.SNUFFER):
		w.set_kind(v, LevelGen.Type.EMPTY)
		w.objects.erase(v)
		if not w.interiors.has(v):
			w.empties.append(v)


## Snuffing fonts about the terraces (see FONTS_PER_K), on free floors with room over them, in an
## order hashed from the level seed, each kept apart from the other fonts.
static func scatter_fonts(w: LevelGen) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var fonts: Array[Vector2i] = w.objects_of(LevelGen.Type.SNUFFER)
	var spots: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool:
		return w.is_valid(v + Vector2i.UP) and w._open(v + Vector2i.UP) and not w._crowds_exit(v) and LevelGen.dist(v, start) >= FONT_CLEAR)
	var key: Callable = func(v: Vector2i) -> int: return posmod(Rules.level_seed(w.seed_for_colors, FONT_DEAL + v.x * 977 + v.y), 1 << 24)
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return key.call(a) < key.call(b))
	var want: int = w.per_area(FONTS_PER_K)
	var laid: int = 0
	for v: Vector2i in spots:
		if laid >= want:
			break
		if fonts.all(func(f: Vector2i) -> bool: return LevelGen.dist(f, v) >= FONT_APART):
			fonts.append(v)
			w.put(v, LevelGen.Type.SNUFFER)
			laid += 1


## What lives in a cemetery: a swarm of moths a few cells from each lantern (they are drawn to a
## lit one, see MothSwarm) and more in the open air; banks of sleep fog over floors (SleepFog); and
## wraiths, which drift through rock at the wizard (Wraith), never near the way in.
func populate(w: LevelGen, _def: NextWorldDef) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	var air: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.EMPTY and w._wide_open(v))
	var swarms: Array[Vector2i] = []
	for lantern: Vector2i in w.objects_of(LevelGen.Type.CHECKPOINT):
		var near: Array[Vector2i] = air.filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, lantern) >= 3 and LevelGen.dist(v, lantern) <= 8 and not swarms.has(v))
		if not near.is_empty():
			swarms.append(w.pick(near))
	w.pick_apart(air, w.foes_per_area(MOTHS_PER_K), 6, swarms)
	w.put_each(swarms, LevelGen.Type.MOTHS)
	# Fog lies over floors with room above it, apart from one another.
	var floors: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.EMPTY and w.ground_below(v) and w._open(v + Vector2i.UP) and LevelGen.dist(v, start) >= 5)
	w.put_each(w.pick_apart(floors, w.foes_per_area(FOG_PER_K), 5), LevelGen.Type.FOG)
	# Wraiths wait in the open air, away from the way in, each in a cell of its own.
	var open_air: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.EMPTY and LevelGen.dist(v, start) >= 10)
	w.put_each(w.pick_apart(open_air, w.foes_per_area(WRAITHS_PER_K), 1), LevelGen.Type.WRAITH)
