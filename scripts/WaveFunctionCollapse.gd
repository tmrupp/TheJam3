extends WaveFunctionCollapse

## Collapses the terrain for one level. A failed collapse retries on a seed derived from the
## level seed and the attempt, so the same (seed, depth) always gives the same level. A place whose
## archetype builds round small insides of their own (Archetype.patches: the cemetery's crypts)
## has each collapsed too, after the terrain, on seeds of their own, and handed over after the
## terrain's columns as {"patches": [each inside, or [] if it never settled]} (LevelGen reads it).

## Salt for the level seed when collapsing each inside (and each retry).
const PATCH_DEAL: int = 6200
const PATCH_TRIES: int = 16
func generate_level(def: NextWorldDef) -> Array:
	texture = load(def.region)
	output_size = def.size
	symmetry = def.symmetry
	var map: Array = []
	for attempt: int in range(32):
		set_seed(def.gen_seed if attempt == 0 else Rules.level_seed(def.gen_seed, 1000 + attempt))
		map = collapse()
		if len(map) > 0:
			break
	if map.is_empty():
		# The collapse never settled: whatever the place falls back to ([] for a level).
		return def.fallback()
	var specs: Array[Dictionary] = def.patches()
	if specs.is_empty():
		return map
	var patches: Array = []
	for i: int in range(specs.size()):
		texture = load(String(specs[i]["sample"]))
		output_size = specs[i]["size"]
		symmetry = 1
		var inside: Array = []
		for attempt: int in range(PATCH_TRIES):
			set_seed(Rules.level_seed(def.gen_seed, PATCH_DEAL + i * 100 + attempt))
			inside = collapse()
			if len(inside) > 0:
				break
		patches.append(inside)
	map.append({"patches": patches})
	return map
