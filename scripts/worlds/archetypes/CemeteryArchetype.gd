class_name CemeteryArchetype
extends Archetype
## The cemetery: a hillside graveyard of terraces (wfc_images/graveyard.png, drawn by
## tests/make_graveyard_sample.gd, collapsed unturned), printed in its own realm with its own decor.
## Its gates are chasms cut across the terraces, bridged once a grave bell is rung (Chasms). Moths,
## sleep fog and wraiths live there (populate).

const SAMPLE: String = "res://wfc_images/graveyard.png"
## Moth swarms (one by each lantern, and these more), banks of sleep fog and wraiths, per 1000
## cells.
const MOTHS_PER_K: float = 0.6
const FOG_PER_K: float = 2.0
const WRAITHS_PER_K: float = 0.9


func _init() -> void:
	name = &"cemetery"
	decor = &"cemetery"
	sample = SAMPLE
	symmetry = 1
	chasmed = true


func cut_gates(w: LevelGen) -> void:
	Chasms.carve(w)


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
