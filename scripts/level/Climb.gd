class_name Climb
extends RefCounted
## Climbing levels: above the start the way on lies near the top of a level and the way back near
## the bottom (LevelGen.place_exits), so the up branch is climbed rather than fallen through
## (docs/REGIONS_PLAN.md, phase 2). Climbing is harder than falling, so once an up level is laid
## out, `aid` lends a hand: a few ledges (at most MAX_LEDGES), each a hop on from somewhere the
## wizard can already get to, toward the way on. A hop is the wizard's own (Reach.UP rows) in the
## garden and a relic's (RELIC_UP, about a double jump) beyond it.
##
## Nothing is promised, as nothing is in the levels below the start: some climbs want wall jumps, a
## relic or another move, and a few may not go at all. Gates count as open while it looks (a
## chasm's planks, a gap's wind), but no ledge goes in the air a chasm or gap keeps clear, so the
## crossings left to relics stay theirs. Pure: no world RNG draws, and laid last, so nothing else
## in a level moves.

## The most ledges a level gets, and the reached footholds nearest the way on that the next ledge
## is sought from.
const MAX_LEDGES: int = 12
const FRONTIER: int = 32
## Rows a hop climbs beyond the garden: about a double jump.
const RELIC_UP: int = 4
## The furthest a hop falls while it looks (a climb has little use for long falls).
const FALL: int = 6


## Lay a few ledges in up level `w` (laid out as `def`) toward its way on (LevelGen.climb_ledges).
static func aid(w: LevelGen, def: NextWorldDef) -> void:
	if def.coord.y >= 0 or Worlds.is_side(def.coord):
		return
	if not w.exits.has(MapInfo.Exit.BACK) or not w.exits.has(MapInfo.Exit.DEEPER):
		return
	var up: int = hop_up(def)
	var back: Vector2i = w.exits[MapInfo.Exit.BACK]
	var on: Vector2i = w.exits[MapInfo.Exit.DEEPER]
	var nodes: Dictionary = footholds(w)
	var reach: Dictionary = {back: true}
	Reach.grow(w, nodes, reach, [back], {}, {}, Reach.ACROSS, up, FALL)
	var to_on: Dictionary = air_steps(w, on)
	while not reach.has(on) and w.climb_ledges.size() < MAX_LEDGES:
		var ledge: Variant = _next_ledge(w, nodes, reach, to_on, up)
		if ledge == null:
			break
		var q: Vector2i = ledge
		w.put(q, LevelGen.Type.PLATFORM)
		w.climb_ledges.append(q)
		var foot: Vector2i = q + Vector2i.UP
		nodes[foot] = false
		reach[foot] = true
		Reach.grow(w, nodes, reach, [foot], {}, {}, Reach.ACROSS, up, FALL)


## The rows a hop of `def`'s level is laid for: the wizard's own in the garden, a relic's beyond it.
static func hop_up(def: NextWorldDef) -> int:
	return Reach.UP if def.depth <= NextWorldDef.GARDEN_ROWS else RELIC_UP


## Where the wizard can stand in `w` with its gates open: Reach's footholds, the planks over each
## chasm, and the air a wind carries the wizard through (a gap's crosswind, an updraft).
static func footholds(w: LevelGen) -> Dictionary:
	var nodes: Dictionary = Reach.footholds(w)
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		if cell.type == LevelGen.Type.BRIDGE and Reach.clear(w, v + Vector2i.UP):
			nodes[v + Vector2i.UP] = false
		elif cell.type == LevelGen.Type.WIND:
			nodes[v] = false
	return nodes


## Steps through open air (not rock, not thorns; side to side and up and down) from `from` to every
## cell it reaches in `w`: how far the way on is, round the rock.
static func air_steps(w: LevelGen, from: Vector2i) -> Dictionary:
	var steps: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	var i: int = 0
	while i < queue.size():
		var a: Vector2i = queue[i]
		i += 1
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var b: Vector2i = a + d
			if not steps.has(b) and Reach.clear(w, b):
				steps[b] = int(steps[a]) + 1
				queue.append(b)
	return steps


## The next ledge: from the reached footholds nearest the way on through the air (`to_on`, see
## air_steps), the cell under a foothold one hop on (not a foothold yet) that comes nearest it,
## among those nearer than the foothold hopped from; null if there is none.
static func _next_ledge(w: LevelGen, nodes: Dictionary, reach: Dictionary, to_on: Dictionary, up: int) -> Variant:
	var far: int = 1 << 30
	var reached: Array[Vector2i] = []
	for v: Vector2i in reach:
		if to_on.has(v):
			reached.append(v)
	if reached.is_empty():
		return null
	reached.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(to_on[a]) < int(to_on[b]) or (int(to_on[a]) == int(to_on[b]) and a < b))
	var best: Variant = null
	var best_d: int = far
	for i: int in range(mini(FRONTIER, reached.size())):
		var a: Vector2i = reached[i]
		var moon: bool = nodes.get(a, false)
		var from_d: int = int(to_on[a])
		for dy: int in range(-up, 1):
			for dx: int in range(-Reach.ACROSS, Reach.ACROSS + 1):
				var foot: Vector2i = a + Vector2i(dx, dy)
				var d: int = int(to_on.get(foot, far))
				if d >= best_d or d >= from_d or nodes.has(foot) or not _ledge_fits(w, foot + Vector2i.DOWN):
					continue
				if Reach.hop(w, a, foot, moon, Reach.ACROSS, up):
					best = foot + Vector2i.DOWN
					best_d = d
	return best


## Whether a ledge may go at `q`: an empty cell (in open air, or on a floor as a step up), with room
## to stand on it (only air, a star, a moon or another ledge over it, and open air over that),
## clear of the doors' corridors, of every chasm's and gap's kept air, and out of the bramble's
## shaft (which has ledges of its own).
static func _ledge_fits(w: LevelGen, q: Vector2i) -> bool:
	if not w.is_valid(q) or w.get_cell(q).type != LevelGen.Type.EMPTY or w.keep_clear.has(q) or Chasms.near(w, q) or w.in_shaft(q):
		return false
	var over: Vector2i = q + Vector2i.UP
	if not w.is_valid(over) or not w.get_cell(over).type in [LevelGen.Type.EMPTY, LevelGen.Type.COIN, LevelGen.Type.MOON, LevelGen.Type.PLATFORM]:
		return false
	return Reach.clear(w, over + Vector2i.UP)
