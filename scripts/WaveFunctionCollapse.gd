extends WaveFunctionCollapse

## Collapses the terrain for one level. A failed collapse retries on a seed derived from the
## level seed and the attempt, so the same (seed, depth) always gives the same level.
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
	return map
