class_name Sigils
## The sigils that tie a level's linked things together: each pair of teleporters shares one, and
## each switch shares one with what it works (its gate, the bell or vane it frees, the lift it
## starts), so the player can tell which goes with which. Every link in a level gets its own shape
## of the RisoMarks.SIGILS while there are shapes left (teleporters first, then switches); a level
## with more links than that (a big sky level) reuses the shape whose other links lie furthest
## away. Dealt once a level is laid out, by hashing its seed (no world RNG draws), so it is the
## same on every visit and on the map.

## Salt for the level seed when dealing sigils.
const DEAL: int = 9300
## Steps through the shapes, each prime to their number, so neighbouring links get unlike shapes.
const STEPS: Array[int] = [1, 5, 7, 11]


## The sigil (0 to RisoMarks.SIGILS - 1) of every linked cell in level `w`, by cell: both ends of
## each pair of teleporters, each switch and the cell of the thing it works.
static func deal(w: LevelGen) -> Dictionary:
	var portals: Array = []
	var switches: Array = []
	var sorted: Array[Vector2i] = w.objects.duplicate()
	sorted.sort()
	for v: Vector2i in sorted:
		var cell: LevelGen.Cell = w.get_cell(v)
		if not cell.extra_info is Vector2i:
			continue
		var other: Vector2i = cell.extra_info
		if cell.type == LevelGen.Type.PORTAL and v < other:
			portals.append([v, other])
		elif cell.type == LevelGen.Type.SWITCH:
			switches.append([v, other])
	var out: Dictionary = {}
	_deal_links(w, portals + switches, DEAL, out)
	return out


## Deals `links` (pairs of cells, in order) their sigils into `out`, starting the shapes at a place
## and stepping through them by a stride, both hashed from the level seed and `salt`.
static func _deal_links(w: LevelGen, links: Array, salt: int, out: Dictionary) -> void:
	var n: int = RisoMarks.SIGILS
	var roll: int = posmod(Rules.level_seed(w.seed_for_colors, salt), n * STEPS.size())
	var start: int = roll % n
	var step: int = STEPS[roll / n]
	var order: Array[int] = []
	for i: int in range(n):
		order.append((start + i * step) % n)
	# The links each shape has gone to so far.
	var used: Dictionary = {}
	for link: Array in links:
		var best: int = -1
		var best_far: int = -1
		for s: int in order:
			if not used.has(s):
				best = s
				break
			var far: int = _nearest(link, used[s])
			if far > best_far:
				best_far = far
				best = s
		if not used.has(best):
			used[best] = []
		(used[best] as Array).append(link)
		out[link[0]] = best
		out[link[1]] = best


## How near (cells) link `link` comes to the nearest of `others`.
static func _nearest(link: Array, others: Array) -> int:
	var near: int = 1 << 30
	for other: Array in others:
		for a: Vector2i in link:
			for b: Vector2i in other:
				near = mini(near, LevelGen.dist(a, b))
	return near


## The sigil of the thing `node` in the level being played (by its cell), or -1 if it has none.
static func of(node: Node) -> int:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null or node == null or not node.has_meta(&"cell"):
		return -1
	return info.world.sigil_at(node.get_meta(&"cell"))
