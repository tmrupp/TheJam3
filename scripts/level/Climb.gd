class_name Climb
extends RefCounted
## Climbing a level, as the layout reckons it: how high a hop goes (`hop_up`) and where the wizard
## can stand with its gates open (`footholds`), for Reach. Nothing here lays anything: the climbing
## aid that once laid ledges toward an up level's way on is gone (AGENTS.md, "Traversability":
## nothing makes sure a level can be crossed).

## Rows a hop climbs beyond the garden: about a double jump.
const RELIC_UP: int = 4
## The furthest a hop falls while Reach looks (a climb has little use for long falls).
const FALL: int = 6


## The rows a hop of `def`'s level is laid for: the wizard's own in the garden, a relic's beyond it.
static func hop_up(def: NextWorldDef) -> int:
	return Reach.UP if def.depth <= Bands.garden_rows() else RELIC_UP


## Where the wizard can stand in `w` with its gates open: Reach's footholds, the planks over each
## chasm, the air a wind carries the wizard through (an updraft), and the first cell of each sky gap
## a gust carries them over (all but those left to relics).
static func footholds(w: LevelGen) -> Dictionary:
	var nodes: Dictionary = Reach.footholds(w)
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		if cell.type == LevelGen.Type.BRIDGE and Reach.clear(w, v + Vector2i.UP):
			nodes[v + Vector2i.UP] = false
		elif cell.type == LevelGen.Type.WIND:
			nodes[v] = false
	for id: int in range(w.chasms.size()):
		var first: Vector2i = (w.chasms[id]["planks"] as Array)[0]
		if w.get_cell(first).type != LevelGen.Type.BRIDGE and not w.relic_chasms.has(id):
			nodes[first] = false
	return nodes
