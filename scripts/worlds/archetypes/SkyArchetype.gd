class_name SkyArchetype
extends Archetype
## The sky: clusters of floating islands of cloud (wfc_images/sky_islands.png, drawn by
## tests/make_sky_sample.gd, collapsed unturned) over an open drop, bigger than a cave level of its
## depth (SCALE) and open all round. Its gates are gaps between islands crossed on the wind a vane
## sets blowing (cut_gates, Chasms.add_gap, Vane, Wind). Pads, clouds that give way, updrafts,
## swooping birds, shielded enemies and rebounding shots live there (populate), and a balloon is
## moored in every one, to ride along the row on the level's wind, and a temple stands in some,
## opened by a sequence of winds along the row (finish, Balloon, Temple).

const SAMPLE: String = "res://wfc_images/sky_islands.png"
## A sky level is this much bigger than a cave level of its depth (Rules.level_size), across and
## down: wide open sky with no walls round it.
const SCALE: Vector2 = Vector2(1.8, 1.6)
## Jump pads on floors (Pad) and updrafts up open shafts (Wind), per 1000 cells; the share of ledge
## runs that are clouds giving way under you (Puff); and the share of wisps and hoppers carrying a
## shield (Shield).
const PADS_PER_K: float = 1.5
const UPDRAFTS_PER_K: float = 0.8
const PUFF_SHARE: float = 0.5
const SHIELD_SHARE: float = 0.4

## Every watcher in the sky fires rebounding shots, and there are this many more of them.
const BOUNCE_SHARE: float = 1.0
const SKY_WATCHERS_PER_K: float = 1.2

## Swooping birds (Bird) patrolling stretches of open sky.
const BIRDS_PER_K: float = 0.9

## The walls a rebounding shot bounces off before it bursts (a shield's hits are Shield.HP).
const BOUNCES: int = 2

## A cluster of islands is an ellipse this many cells across and down from its centre (from, to).
const ISLE_RX: Vector2i = Vector2i(6, 9)
const ISLE_RY: Vector2i = Vector2i(4, 6)
## Open air at least this wide between clusters side by side, or this tall between stacked ones.
const ISLE_GAP: Vector2i = Vector2i(4, 3)
## A cluster with less rock than this share of its area gets more islands (_stamp_islands).
const ISLE_ROCK: float = 0.42

## Rows of air kept clear under a keel (over whatever rock is below it).
const KEEL_CLEAR: int = 2

## Shore kept whole either side of an island gap taken as a chasm, and the narrowest gap taken
## (a run, a jump and a dash cover under 6 cells).
const GAP_SHORE: int = 2
const GAP_MIN: int = 7

## Floor laid either side of a gap the sky builds.
const BUILT_SHORE: int = 3

## An updraft's shaft rises this many cells over its floor (from, to).
const UPDRAFT_MIN: int = 4
const UPDRAFT_MAX: int = 9
## How high a pad throws the wizard, in cells (see Pad.LAUNCH).
const PAD_REACH: int = 4
## The shortest stretch of open sky a bird patrols.
const BIRD_SPAN: int = 10

## How far from its vane a sky level looks for a vane's switch.
const SKY_SWITCH_REACH: int = 24
## Its balloon (Balloon): on a free floor with BALLOON_AIR rows of open air over it, at least
## BALLOON_CLEAR cells from every exit, picked by hashing the level seed (BALLOON_DEAL, no draw).
const BALLOON_AIR: int = 5
const BALLOON_CLEAR: int = 4
const BALLOON_DEAL: int = 9300
## Its temple (build_temples), in TEMPLE_SHARE of sky levels (TEMPLE_DEAL, no draw): a building of
## built stone TEMPLE_WIDE cells across, standing on an island as a crag's tower does. From the
## bottom: a stone floor (its stylobate) let down onto the island's rock, with a footing of built
## stone under it where the rock falls away (at most TEMPLE_FOOTING rows to the rock, under every
## column of it); a hall TEMPLE_HALL rows high over it, open between its columns (which the art draws)
## with a back wall of stone behind its middle (interiors), the altar (Temple) standing in its
## middle; and a roof a row thick, walkable. TEMPLE_AIR rows of open air are kept over the roof, where
## the art draws its pediment; nothing is built into it or placed in its hall or over its roof.
const TEMPLE_SHARE: float = 0.4
const TEMPLE_DEAL: int = 9400
const TEMPLE_WIDE: int = 7
const TEMPLE_HALL: int = 3
const TEMPLE_FOOTING: int = 3
const TEMPLE_AIR: int = 3
## Star clusters in its hall (its hoard), either side of its altar, there once it is opened.
const TEMPLE_HOARD: int = 2


func _init() -> void:
	name = &"sky"
	title = "The Sky"
	decor = &"sky"
	sample = SAMPLE
	symmetry = 1
	scale = SCALE
	chasmed = true
	crossing = LevelGen.Type.VANE
	switch_reach = SKY_SWITCH_REACH
	open = true


## Keep the collapsed islands only in clusters, linked by causeways (cluster_islands).
func shape(w: LevelGen) -> void:
	cluster_islands(w)
	w.map_isles()


## The islands are too small and scattered for long floors to cut into: take the gaps between them
## that are already wide enough (_span_gaps), then build the rest (_build_gaps).
func cut_gates(w: LevelGen) -> void:
	var want: int = Chasms.wanted(w)
	_span_gaps(w, want)
	_build_gaps(w, want)
	build_temples(w)
	# Shores laid and air cleared can shut off a pocket of air: join (or fill) it again.
	w.connect_caves()
	# Joining pockets can tunnel through a shore's footing (the islands' keels leave many
	# pockets): every gap's two shores get rock under them and air on and over them again.
	for chasm: Dictionary in w.chasms:
		for shore: Vector2i in [chasm["left"], chasm["right"]]:
			if not w.is_ground(shore + Vector2i.DOWN):
				w._to_rock(shore + Vector2i.DOWN)
			for d: Vector2i in [Vector2i.ZERO, Vector2i.UP]:
				if w.is_ground(shore + d):
					w._to_open(shore + d)


## Stars only in and near the clusters of islands, ledges only in and about them, so the gaps
## between stay open.
func room(w: LevelGen, v: Vector2i, grow: int) -> bool:
	return w.in_isle(v, grow)

## Sky levels: keep the collapsed islands only in clusters (ellipses ISLE_RX by ISLE_RY cells,
## thrown at random and kept ISLE_GAP apart), clearing the rest to open air; fill out a thin
## cluster with more islands (_stamp_islands); then link the clusters (link_isles).
static func cluster_islands(w: LevelGen) -> void:
	for attempt: int in range(maxi(600, w.size.x * w.size.y / 4)):
		var r: Vector2i = Vector2i(w.rng.randi_range(ISLE_RX.x, ISLE_RX.y), w.rng.randi_range(ISLE_RY.x, ISLE_RY.y))
		if w.size.x - 2 * r.x - 4 <= 0 or w.size.y - 2 * r.y - 6 <= 0:
			continue
		var c: Vector2i = Vector2i(w.rng.randi_range(r.x + 2, w.size.x - r.x - 3), w.rng.randi_range(r.y + 2, w.size.y - r.y - 4))
		var apart: bool = true
		for isle: Array in w.isles:
			var o: Vector2i = isle[0]
			var q: Vector2i = isle[1]
			var gx: int = absi(c.x - o.x) - r.x - q.x
			var gy: int = absi(c.y - o.y) - r.y - q.y
			if gx < ISLE_GAP.x and gy < ISLE_GAP.y:
				apart = false
				break
		if apart:
			w.isles.append([c, r])
	# The clusters are thrown: map them, so telling whether a cell is in one (in_isle, asked tens
	# of thousands of times below) is a lookup rather than a test against every cluster.
	w.map_isles()
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var v: Vector2i = Vector2i(x, y)
			if w.get_cell(v).type != LevelGen.Type.EMPTY and not w.in_isle(v):
				w._to_open(v)
	for isle: Array in w.isles:
		var c: Vector2i = isle[0]
		var r: Vector2i = isle[1]
		var rock: int = 0
		var area: int = 0
		for x: int in range(c.x - r.x, c.x + r.x + 1):
			for y: int in range(c.y - r.y, c.y + r.y + 1):
				if w.in_isle(Vector2i(x, y)):
					area += 1
					if w.is_ground(Vector2i(x, y)):
						rock += 1
		if float(rock) < float(area) * ISLE_ROCK:
			_stamp_islands(w, c, r, int(float(area) * ISLE_ROCK) - rock)
	taper_islands(w)
	link_isles(w)


## Floating islands taper underneath: under every run of rock with open air below it (each
## stretch of an island's underside, as the islands lie before any keel), rows of rock narrowing
## toward a point, a cell off each side a row (now and then a side holds), as deep as the run
## allows. A keel stops before it strays past its cluster, meets anything, or comes within
## KEEL_CLEAR rows of rock below (room to stand on what is beneath). Laid before the clusters
## are linked, so the causeways go round them.
static func taper_islands(w: LevelGen) -> void:
	var runs: Array = []
	for y: int in range(w.size.y - 1):
		var x: int = 0
		while x < w.size.x:
			var under: Callable = func(cx: int) -> bool: return w.is_ground(Vector2i(cx, y)) and w.get_cell(Vector2i(cx, y + 1)).type == LevelGen.Type.EMPTY
			if not under.call(x):
				x += 1
				continue
			var from: int = x
			while x < w.size.x and under.call(x):
				x += 1
			runs.append([from, x - 1, y + 1])
	for run: Array in runs:
		_keel(w, int(run[0]), int(run[1]), int(run[2]))


## A keel under the run of rock from `a` to `b` on the row over `y`.
static func _keel(w: LevelGen, a: int, b: int, y: int) -> void:
	while true:
		a += 1 if w.rng.randf() < 0.8 else 0
		b -= 1 if w.rng.randf() < 0.8 else 0
		if a > b:
			return
		for x: int in range(a, b + 1):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_valid(v) or w.get_cell(v).type != LevelGen.Type.EMPTY or not w.in_isle(v, 4):
				return
			for d: int in range(1, KEEL_CLEAR + 1):
				if w.is_valid(v + Vector2i(0, d)) and w.get_cell(v + Vector2i(0, d)).type != LevelGen.Type.EMPTY:
					return
		for x: int in range(a, b + 1):
			w._to_rock(Vector2i(x, y))
		y += 1


## Islands laid in the cluster at `c` (radii `r`) until about `want` more cells of rock: each as
## the sample draws them (tests/make_sky_sample.gd), a flat top 3 to 6 cells wide over a body that
## tapers a cell each side per row below the first (2 or 3 rows). One cell beside and below,
## and two rows above stay open, leaving headroom and hops between the denser shelves.
static func _stamp_islands(w: LevelGen, c: Vector2i, r: Vector2i, want: int) -> void:
	for attempt: int in range(350):
		if want <= 0:
			return
		var span: int = w.rng.randi_range(3, 6)
		var h: int = w.rng.randi_range(2, 3)
		var at: Vector2i = Vector2i(w.rng.randi_range(c.x - r.x, c.x + r.x - span), w.rng.randi_range(c.y - r.y + 2, c.y + r.y - h))
		var fits: bool = true
		for x: int in range(at.x - 1, at.x + span + 1):
			for y: int in range(at.y - 2, at.y + h + 1):
				var v: Vector2i = Vector2i(x, y)
				if not w.is_valid(v) or w.get_cell(v).type != LevelGen.Type.EMPTY:
					fits = false
					break
			if not fits:
				break
		for x: int in [at.x, at.x + span - 1]:
			fits = fits and w.in_isle(Vector2i(x, at.y))
		if not fits:
			continue
		for d: int in range(h):
			for x: int in range(at.x + maxi(0, d - 1), at.x + span - maxi(0, d - 1)):
				w._to_rock(Vector2i(x, at.y + d))
				want -= 1


## The floors (open, rock under) of cluster `i`.
static func _isle_floors(w: LevelGen, i: int) -> Array[Vector2i]:
	var c: Vector2i = w.isles[i][0]
	var r: Vector2i = w.isles[i][1]
	var out: Array[Vector2i] = []
	for x: int in range(c.x - r.x, c.x + r.x + 1):
		for y: int in range(c.y - r.y - 1, c.y + r.y + 1):
			var v: Vector2i = Vector2i(x, y)
			if w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.EMPTY and w.is_ground(v + Vector2i.DOWN) and w.is_valid(v + Vector2i.UP) and w.get_cell(v + Vector2i.UP).type == LevelGen.Type.EMPTY:
				out.append(v)
	return out


## Link the clusters so every one can be reached: along the shortest links between them (a
## spanning tree, stacked clusters counting as further apart), a causeway of cloud stepping
## stones (Puff, two cells wide, a hop apart) from a floor of one to a floor of the other, and
## an updraft (Wind) where the far floor is too high above to hop up to. A cluster no causeway
## can reach is cleared away.
static func link_isles(w: LevelGen) -> void:
	var dropped: Array[int] = []
	var linked: Array[int] = [0]
	var left: Array[int] = []
	for i: int in range(1, w.isles.size()):
		left.append(i)
	var gap: Callable = func(i: int, j: int) -> int:
		var a: Vector2i = w.isles[i][0]
		var b: Vector2i = w.isles[j][0]
		return absi(a.x - b.x) + 2 * absi(a.y - b.y)
	while not left.is_empty() and not w.isles.is_empty():
		var best: Array = []
		for i: int in linked:
			for j: int in left:
				if best.is_empty() or gap.call(i, j) < int(best[0]):
					best = [gap.call(i, j), i, j]
		var j: int = best[2]
		left.erase(j)
		# From the nearest cluster already linked, else the next nearest, until one can be laid.
		var from: Array[int] = linked.duplicate()
		from.sort_custom(func(p: int, q: int) -> bool: return gap.call(p, j) < gap.call(q, j))
		var laid: bool = false
		for i: int in from:
			if _causeway(w, i, j):
				laid = true
				break
		if laid:
			w.links += 1
			linked.append(j)
		else:
			dropped.append(j)
	# A cluster no causeway reaches is cleared away, so nothing is placed out of reach.
	dropped.sort()
	dropped.reverse()
	for j: int in dropped:
		var c: Vector2i = w.isles[j][0]
		var r: Vector2i = w.isles[j][1]
		w.isles.remove_at(j)
		w.map_isles()
		for x: int in range(c.x - r.x, c.x + r.x + 1):
			for y: int in range(c.y - r.y, c.y + r.y + 1):
				var v: Vector2i = Vector2i(x, y)
				if w.is_valid(v) and w.is_ground(v) and not w.in_isle(v):
					var d: Vector2 = Vector2(float(v.x - c.x) / float(r.x), float(v.y - c.y) / float(r.y))
					if d.length_squared() <= 1.0:
						w._to_open(v)


## A causeway between clusters `i` and `j`: from a floor of one up or across to a floor of the
## other (the lower of the two to the higher). Tries the nearest pairs of floors; false if none
## can be laid.
static func _causeway(w: LevelGen, i: int, j: int) -> bool:
	var lo: int = i if (w.isles[i][0] as Vector2i).y >= (w.isles[j][0] as Vector2i).y else j
	var hi: int = j if lo == i else i
	var from: Array[Vector2i] = _isle_floors(w, lo)
	var to: Array[Vector2i] = _isle_floors(w, hi)
	var pairs: Array = []
	for a: Vector2i in from:
		for b: Vector2i in to:
			# Always built upward, from the lower floor: every hop can be taken either way.
			if a.y >= b.y:
				pairs.append([LevelGen.dist(a, b), a, b])
			else:
				pairs.append([LevelGen.dist(a, b), b, a])
	pairs.sort()
	for k: int in range(pairs.size()):
		if _stones(w, pairs[k][1], pairs[k][2]):
			return true
	return false


## Stepping stones from standing at `a` up or across to standing at `b` (no lower): hops of three
## cells across, or two across and one up, each as easily taken back down; where `b` is two or
## more above with little room across left, an updraft beside it lifts the wizard up to it.
## Every stone, the cell over it and the one over that must be open air; false (nothing laid)
## if they are not.
static func _stones(w: LevelGen, a: Vector2i, b: Vector2i) -> bool:
	var dir: int = 1 if b.x >= a.x else -1
	var stands: Array[Vector2i] = []
	var shaft: Vector2i = Vector2i(-1, -1)
	var shaft_up: int = 0
	var cur: Vector2i = a
	for guard: int in range(40):
		var dx: int = b.x - cur.x
		var dy: int = b.y - cur.y
		# Within a last hop.
		if absi(dx) <= 2 and dy >= -1 or absi(dx) <= 3 and dy >= 0:
			break
		if dy <= -2 and absi(dx) <= 3:
			# Too high to hop up to: over to the column beside it, then an updraft.
			if absi(dx) > 1:
				cur = Vector2i(b.x - dir, cur.y)
				stands.append(cur)
			shaft = cur
			shaft_up = cur.y - b.y + 2
			break
		var step: Vector2i = Vector2i(2 * dir, -1) if dy < 0 else Vector2i(mini(3, absi(dx)) * dir, 0)
		cur += step
		stands.append(cur)
	if stands.is_empty() and shaft.x < 0:
		return false
	var open: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.EMPTY
	var stones: Array[Vector2i] = []
	for st: Vector2i in stands:
		for c: Vector2i in [st, st + Vector2i.UP, st + Vector2i.DOWN, st + Vector2i(dir, 1)]:
			if not open.call(c):
				return false
		stones.append(st + Vector2i.DOWN)
		stones.append(st + Vector2i(dir, 1))
	if shaft.x >= 0:
		for d: int in range(0, shaft_up + 1):
			if not open.call(shaft + Vector2i(0, -d)):
				return false
	for st: Vector2i in stands:
		w.lanes[st] = true
		w.lanes[st + Vector2i.UP] = true
	for c: Vector2i in stones:
		w.lanes[c] = true
		w.put(c, LevelGen.Type.PUFF)
	if shaft.x >= 0:
		w.put(shaft, LevelGen.Type.WIND, {"up": shaft_up})
		for d: int in range(0, shaft_up + 2):
			w.lanes[shaft + Vector2i(0, -d)] = true
			w.empties.erase(shaft + Vector2i(0, -d))
	return true


## Sky levels: gaps between islands already about as wide as a chasm (GAP_MIN to CHASM_WIDTH and
## a cell or two more), from the end of one floor (GAP_SHORE cells of it) to the start of the next
## on the same row or the one below, with nothing but open air across the gap from the row over
## the floor to the row under it: a drop. Taken as chasms (crossed on a vane's wind) before any
## is cut, up to `want`. Each is laid out as a cut chasm is, its first cell the row under the
## floor.
static func _span_gaps(w: LevelGen, want: int) -> void:
	var floor_at: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.EMPTY and w.is_ground(v + Vector2i.DOWN) and w._open(v + Vector2i.UP)
	var air: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.EMPTY
	var found: Array = []
	for y: int in range(3, w.size.y - 3):
		for l: int in range(GAP_SHORE, w.size.x - 1):
			var left: Vector2i = Vector2i(l, y)
			var ok: bool = true
			for k: int in range(GAP_SHORE):
				ok = ok and floor_at.call(left - Vector2i(k, 0))
			if not ok or floor_at.call(left + Vector2i.RIGHT):
				continue
			# Across: open air in every column until the next floor on this row or the next.
			var x: int = l + 1
			var land: int = -1
			while x < w.size.x:
				if floor_at.call(Vector2i(x, y)):
					land = y
					break
				if floor_at.call(Vector2i(x, y + 1)):
					land = y + 1
					break
				var clear: bool = true
				for d: int in range(-1, 2):
					clear = clear and air.call(Vector2i(x, y + d))
				if not clear:
					break
				x += 1
			var span: int = x - l - 1
			if land < 0 or span < GAP_MIN or span > Chasms.CHASM_WIDTH.y + 2:
				continue
			for k: int in range(GAP_SHORE):
				ok = ok and floor_at.call(Vector2i(x + k, land))
			if ok:
				found.append([y, l + 1, span])
	found.sort()
	while w.chasms.size() < want and not found.is_empty():
		var choice: Array = w.pick(found)
		var y: int = choice[0]
		var a: int = choice[1]
		var span: int = choice[2]
		found = Chasms.apart(found, y, a, span)
		# A gust holds its passenger level. Bring the landing shore up to that row, so a
		# lower shelf with rock behind it cannot trap them against its wall in midair.
		for x: int in range(a + span, a + span + GAP_SHORE):
			w._to_open(Vector2i(x, y - 1))
			w._to_open(Vector2i(x, y))
			w._to_rock(Vector2i(x, y + 1))
		# The air over the gap is kept clear, as over a cut chasm, and a wind spans it.
		Chasms.add_gap(w, y, a, span)


## Sky levels, when the islands' own gaps are too few: build them. A gap is CHASM_WIDTH cells of
## open air (from two rows over the floor's row to two under it) between two shores of
## BUILT_SHORE cells of floor, rock laid under each and air cleared over it. Spots are taken
## from those needing the fewest cells changed, so a gap mostly follows the islands already
## there, and kept apart as cut chasms are.
static func _build_gaps(w: LevelGen, want: int) -> void:
	if w.chasms.size() >= want:
		return
	# Where a gap could go, in tiers: between two clusters of islands (shores at their edges, the
	# gap in the air between: a shortcut from one to the next), else by a cluster, else anywhere.
	var tiers: Array = [[], [], []]
	for y: int in range(Chasms.CHASM_CLEAR + 1, w.size.y - 4):
		for span: int in [Chasms.CHASM_WIDTH.x, Chasms.CHASM_WIDTH.y]:
			for a: int in range(BUILT_SHORE + 1, w.size.x - BUILT_SHORE - span - 1):
				@warning_ignore("integer_division")
				var tier: int = 0 if w.in_isle(Vector2i(a - 1, y), 2) and w.in_isle(Vector2i(a + span, y), 2) and not w.in_isle(Vector2i(a + span / 2, y)) else (1 if w.in_isle(Vector2i(a - 1, y), 4) and w.in_isle(Vector2i(a + span, y), 4) else 2)
				tiers[tier].append([y, a, span])
	# Costed only in the first tier with any spot left.
	var spots: Array = []
	for tier: Array in tiers:
		for sp: Array in tier:
			var y: int = sp[0]
			var a: int = sp[1]
			var span: int = sp[2]
			var cost: int = 0
			for x: int in range(a - BUILT_SHORE, a + span + BUILT_SHORE):
				var shore: bool = x < a or x >= a + span
				for d: int in range(-2, 3 if not shore else 2):
					var c: Vector2i = Vector2i(x, y + d)
					# Never across a causeway or its updraft.
					if w.lanes.has(c):
						cost = -1
						break
					if (w.get_cell(c).type != LevelGen.Type.EMPTY) != (shore and d == 1):
						cost += 1
				if cost < 0:
					break
			if cost >= 0:
				spots.append([cost, y, a, span])
		if not spots.is_empty():
			break
	spots.sort()
	for chasm: Dictionary in w.chasms:
		spots = Chasms.apart(spots, chasm["row"], (chasm["left"] as Vector2i).x + 1, (chasm["planks"] as Array).size())
	while w.chasms.size() < want and not spots.is_empty():
		# Among the cheapest few, by the level's draw.
		var choice: Array = w.pick(spots.slice(0, 8))
		var y: int = choice[1]
		var a: int = choice[2]
		var span: int = choice[3]
		spots = Chasms.apart(spots, y, a, span)
		for x: int in range(a - BUILT_SHORE, a + span + BUILT_SHORE):
			var shore: bool = x < a or x >= a + span
			for d: int in range(-2, 3 if not shore else 2):
				var c: Vector2i = Vector2i(x, y + d)
				if shore and d == 1:
					if w.get_cell(c).type != LevelGen.Type.GROUND:
						w._to_rock(c)
				elif w.get_cell(c).type != LevelGen.Type.EMPTY:
					w._to_open(c)
		# The air over the gap is kept clear, as over a cut chasm, and a wind spans it.
		Chasms.add_gap(w, y, a, span)


## Last of all (so nothing else in the level moves for it): its balloon (place_balloon).
func finish(w: LevelGen, _def: NextWorldDef) -> void:
	place_balloon(w)


## A temple in TEMPLE_SHARE of sky levels (see TEMPLE_SHARE), built where it fits (_temple_site):
## of those, the one needing the least footing, ties by a hash of the level seed. Its altar's extra
## info is its lock's sequence of winds (Temple.LENGTH steps, each +1 right or -1 left, repeats and
## all), dealt by the level seed. Kept in LevelGen.temples.
static func build_temples(w: LevelGen) -> void:
	if posmod(Rules.level_seed(w.seed_for_colors, TEMPLE_DEAL), 1000) >= roundi(TEMPLE_SHARE * 1000.0):
		return
	var best: Variant = null
	var best_score: int = 0
	for y: int in range(TEMPLE_AIR + TEMPLE_HALL + 3, w.size.y - 2):
		for x: int in range(2, w.size.x - TEMPLE_WIDE - 1):
			var box: Rect2i = Rect2i(x, y - TEMPLE_HALL - 1, TEMPLE_WIDE, TEMPLE_HALL + 2)
			var footing: int = _temple_site(w, box)
			if footing < 0:
				continue
			var score: int = footing * 100000 + posmod(Rules.level_seed(w.seed_for_colors, TEMPLE_DEAL + x * 977 + y * 31), 100000)
			if best == null or score < best_score:
				best = box
				best_score = score
	if best != null:
		_temple(w, best as Rect2i)


## How many cells of footing a temple in `box` (its roof's row to its stylobate's) would need, or -1
## where it cannot stand: it and TEMPLE_AIR rows over it all open air inside the level, clear of the
## gaps and of every other structure; under its stylobate, every column reaching the island's rock
## within TEMPLE_FOOTING rows (through open air), at least half of them on it at once, and one of
## its ends, so its hall is a hop up from the island's floor there.
static func _temple_site(w: LevelGen, box: Rect2i) -> int:
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y - TEMPLE_AIR, box.end.y):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_valid(v) or not w._open(v) or w.keep_clear.has(v) or w.structures.has(v) or Chasms.near(w, v) or w.get_cell(v).type != LevelGen.Type.EMPTY:
				return -1
	var footing: int = 0
	var on_rock: int = 0
	var ends_on_rock: bool = false
	for x: int in range(box.position.x, box.end.x):
		var depth: int = 0
		var v: Vector2i = Vector2i(x, box.end.y)
		while not w.is_ground(v):
			if depth >= TEMPLE_FOOTING or not w.is_valid(v) or w.keep_clear.has(v) or Chasms.near(w, v) or w.get_cell(v).type != LevelGen.Type.EMPTY:
				return -1
			depth += 1
			v += Vector2i.DOWN
		footing += depth
		if depth == 0:
			on_rock += 1
			if x == box.position.x or x == box.end.x - 1:
				ends_on_rock = true
	return footing if on_rock * 2 >= box.size.x and ends_on_rock else -1


## Build a temple in `box` (see TEMPLE_SHARE), its altar and its hoard (TEMPLE_HOARD).
static func _temple(w: LevelGen, box: Rect2i) -> void:
	var x0: int = box.position.x
	var x1: int = box.end.x - 1
	var roof: int = box.position.y
	var base: int = box.end.y - 1
	var built: Dictionary = {}
	# The roof, the stylobate, and the footing down to the rock under it.
	for x: int in range(x0, x1 + 1):
		built[Vector2i(x, roof)] = true
		built[Vector2i(x, base)] = true
		var under: Vector2i = Vector2i(x, base + 1)
		while not w.is_ground(under):
			built[under] = true
			under += Vector2i.DOWN
	for v: Vector2i in built:
		w._to_rock(v)
		w.masonry[v] = true
	# The hall: kept open, nothing placed in it; its middle backed by stone.
	var hall: Rect2i = Rect2i(x0, roof + 1, box.size.x, TEMPLE_HALL)
	for x: int in range(hall.position.x, hall.end.x):
		for y: int in range(hall.position.y, hall.end.y):
			w.empties.erase(Vector2i(x, y))
			if x >= x0 + 2 and x <= x1 - 2:
				w.interiors[Vector2i(x, y)] = true
	# Nothing over its roof either (the pediment is drawn there).
	for x: int in range(x0 - 1, x1 + 2):
		for y: int in range(roof - TEMPLE_AIR, roof):
			w.empties.erase(Vector2i(x, y))
	for x: int in range(box.position.x - 1, box.end.x + 1):
		for y: int in range(box.position.y - TEMPLE_AIR, box.end.y):
			var v: Vector2i = Vector2i(x, y)
			if w.is_valid(v):
				w.structures[v] = &"temple"
				w.kept_whole[v] = true
	for v: Vector2i in built:
		w.structures[v] = &"temple"
		w.kept_whole[v] = true
	@warning_ignore("integer_division")
	var altar: Vector2i = Vector2i(x0 + box.size.x / 2, base - 1)
	var winds: Array = []
	var length: int = Temple.LENGTH.x + posmod(Rules.level_seed(w.seed_for_colors, TEMPLE_DEAL + 100), Temple.LENGTH.y - Temple.LENGTH.x + 1)
	for i: int in range(length):
		winds.append(1 if posmod(Rules.level_seed(w.seed_for_colors, TEMPLE_DEAL + 1 + i), 2) == 0 else -1)
	w.put(altar, LevelGen.Type.TEMPLE, winds)
	var hoard: Array[Vector2i] = []
	for k: int in range(TEMPLE_HOARD):
		var at: Vector2i = altar + Vector2i(2 if k % 2 == 0 else -2, 0)
		if hall.has_point(at):
			w.put(at, LevelGen.Type.CLUSTER)
			hoard.append(at)
	w.temples.append({"box": box, "hall": hall, "altar": altar, "hoard": hoard})


## The balloon moored in every sky level (see BALLOON_AIR), and kept in LevelGen.balloon, the air
## over it kept clear; none where no floor has the room.
static func place_balloon(w: LevelGen) -> void:
	var spots: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool:
		if w.keep_clear.has(v) or w.exits.values().any(func(e: Vector2i) -> bool: return LevelGen.dist(e, v) < BALLOON_CLEAR):
			return false
		for k: int in range(1, BALLOON_AIR + 1):
			var up: Vector2i = v - Vector2i(0, k)
			if not w.is_valid(up) or w.is_ground(up) or w.keep_clear.has(up) or w.get_cell(up).type != LevelGen.Type.EMPTY:
				return false
		return true)
	var spot: Variant = LevelGen.best_of(spots, func(v: Vector2i) -> int: return posmod(Rules.level_seed(w.seed_for_colors, BALLOON_DEAL + v.x * 977 + v.y * 31), 100000))
	if spot != null:
		w.put(spot, LevelGen.Type.BALLOON)
		w.balloon = spot
		# The air its envelope fills is kept clear of what comes after (climbing ledges).
		for k: int in range(1, BALLOON_AIR + 1):
			w.keep_clear[(spot as Vector2i) - Vector2i(0, k)] = true


## What lives in the sky, on top of an ordinary level's dressing:
## - a share of the ledge runs (PUFF_SHARE) are clouds that give way once stood on (Puff);
## - jump pads (Pad) on floors with a ledge or rock shelf within a pad's reach above;
## - updrafts (Wind, {"up": cells}) up open shafts, each rising from a floor to just over a
##   floor beside the shaft, so it lifts you onto a ledge;
## - shields on a share of the wisps and hoppers, and rebounding shots for a share of watchers.
func populate(w: LevelGen, _def: NextWorldDef) -> void:
	var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
	# Clouds that give way: whole runs of ledge at a time.
	var ledges: Array[Vector2i] = w.objects_of(LevelGen.Type.PLATFORM)
	var seen: Dictionary = {}
	for v: Vector2i in ledges:
		if seen.has(v):
			continue
		var run: Array[Vector2i] = []
		var c: Vector2i = v
		while w.is_valid(c) and w.get_cell(c).type == LevelGen.Type.PLATFORM:
			run.append(c)
			seen[c] = true
			c += Vector2i.RIGHT
		if w.rng.randf() < PUFF_SHARE:
			for r: Vector2i in run:
				w.set_kind(r, LevelGen.Type.PUFF)
	# Pads: on a floor with headroom, a shelf to land on within reach above.
	var shelf: Callable = func(v: Vector2i) -> bool:
		for d: int in range(1, 3):
			if not w._open(v + Vector2i(0, -d)):
				return false
		for dy: int in range(2, PAD_REACH + 1):
			for dx: int in [-2, -1, 1, 2]:
				var top: Vector2i = v + Vector2i(dx, -dy)
				if w._open(top) and not w._open(top + Vector2i.DOWN):
					return true
		return false
	var floors: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.EMPTY and w.ground_below(v) and LevelGen.dist(v, start) >= 3 and shelf.call(v))
	var pads: Array[Vector2i] = w.pick_apart(floors, w.per_area(PADS_PER_K), 6)
	w.put_each(pads, LevelGen.Type.PAD)
	# At least one in every level: failing a floor under a shelf, any floor with headroom.
	if pads.is_empty():
		var open_floors: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.EMPTY and w.ground_below(v) and w._open(v + Vector2i.UP) and w._open(v + Vector2i(0, -2)) and LevelGen.dist(v, start) >= 3)
		if not open_floors.is_empty():
			var at: Vector2i = w.pick(open_floors)
			pads.append(at)
			w.put(at, LevelGen.Type.PAD)
	# Updrafts: a shaft of open air over a floor, rising to just over a floor beside it.
	var shafts: Array = []
	for v: Vector2i in w.empties:
		if w.get_cell(v).type != LevelGen.Type.EMPTY or not w.ground_below(v) or LevelGen.dist(v, start) < 3:
			continue
		for h: int in range(UPDRAFT_MIN, UPDRAFT_MAX + 1):
			var top: Vector2i = v + Vector2i(0, -h)
			var clear: bool = true
			for d: int in range(0, h + 2):
				var c: Vector2i = v + Vector2i(0, -d)
				if not w.is_valid(c) or w.get_cell(c).type != LevelGen.Type.EMPTY:
					clear = false
					break
			if not clear:
				break
			if [Vector2i.LEFT, Vector2i.RIGHT].any(func(sd: Vector2i) -> bool: return w._open(top + sd) and not w._open(top + sd + Vector2i.DOWN)):
				shafts.append([v, h])
				break
	shafts.sort()
	var drafts: Array[Vector2i] = []
	for i: int in range(w.per_area(UPDRAFTS_PER_K)):
		var pool: Array = shafts.filter(func(sh: Array) -> bool: return not drafts.has(sh[0]) and drafts.all(func(q: Vector2i) -> bool: return absi(q.x - (sh[0] as Vector2i).x) >= 4 or absi(q.y - (sh[0] as Vector2i).y) > int(sh[1]) + 2))
		if pool.is_empty():
			break
		var choice: Array = w.pick(pool)
		var at: Vector2i = choice[0]
		if not w.empties.has(at):
			continue
		drafts.append(at)
		w.put(at, LevelGen.Type.WIND, {"up": int(choice[1]) + 1})
		# Nothing is placed in the shaft afterwards.
		for d: int in range(1, int(choice[1]) + 2):
			w.empties.erase(at + Vector2i(0, -d))
	# More watchers, on floors in the clusters (their shots rebound, below).
	for i: int in range(w.foes_per_area(SKY_WATCHERS_PER_K)):
		if w.put_random(LevelGen.Type.SHOOTER, func(v: Vector2i) -> bool: return w.ground_below(v) and LevelGen.dist(v, start) >= 6, true) == null:
			break
	# Swooping birds: each on a stretch of open sky (a row of open air, out of the clusters, at
	# least BIRD_SPAN cells long), away from the way in and from one another.
	var runs: Array = []
	for y: int in range(2, w.size.y - 4):
		var x: int = 0
		while x < w.size.x:
			var from: int = x
			while x < w.size.x and w.get_cell(Vector2i(x, y)).type == LevelGen.Type.EMPTY and not w.in_isle(Vector2i(x, y), 1):
				x += 1
			if x - from >= BIRD_SPAN:
				runs.append([y, from + 1, x - 2])
			x += 1
	runs.sort()
	var birds: Array[Vector2i] = []
	for i: int in range(w.foes_per_area(BIRDS_PER_K)):
		var pool: Array = runs.filter(func(r: Array) -> bool:
			@warning_ignore("integer_division")
			var mid: Vector2i = Vector2i((int(r[1]) + int(r[2])) / 2, int(r[0]))
			return LevelGen.dist(mid, start) >= 10 and birds.all(func(q: Vector2i) -> bool: return absi(q.y - mid.y) >= 5 or absi(q.x - mid.x) >= 12))
		if pool.is_empty():
			break
		var run: Array = w.pick(pool)
		@warning_ignore("integer_division")
		var at: Vector2i = Vector2i((int(run[1]) + int(run[2])) / 2, int(run[0]))
		if not w.empties.has(at):
			continue
		birds.append(at)
		w.put(at, LevelGen.Type.BIRD, [int(run[1]), int(run[2])])
	# Shields and rebounding shots.
	var foes: Array[Vector2i] = w.objects.duplicate()
	foes.sort()
	for v: Vector2i in foes:
		var cell: LevelGen.Cell = w.get_cell(v)
		if cell.type in [LevelGen.Type.ENEMY, LevelGen.Type.HOPPER] and w.rng.randf() < SHIELD_SHARE:
			cell.mods["shield"] = Shield.HP
		elif cell.type == LevelGen.Type.SHOOTER and w.rng.randf() < BOUNCE_SHARE:
			cell.mods["bounces"] = BOUNCES