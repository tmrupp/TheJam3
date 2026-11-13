class_name SkyArchetype
extends Archetype
## The sky: clusters of floating islands of cloud over an open drop, bigger than a cave level of its
## depth (SCALE) and open all round. The clusters are its sample's own (wfc_images/sky_islands.png,
## kept in tests/make_sky_sample.gd): each cluster painted on the sample is a sample of its own,
## every cluster of a level is collapsed afresh from one of them, in bands across the level
## (WaveFunctionCollapse.collapse_clusters), and
## the layout reads the clusters back from what was laid (read_clusters) and joins them in pairs,
## keeping between each pair the little islands the collapse laid in the open sky there
## (connect_isles); it clears, stamps and grows nothing of its own, and builds nothing between
## clusters: the wind carries the wizard from one to the next. Its gates are gaps between islands crossed on the wind a vane
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

## The walls a rebounding shot bounces off before it bursts (a shield's hits are Rules.SHIELD_HP).
const BOUNCES: int = 2

## A patch of cluster with less rock than this is no cluster (read_clusters): cleared to open sky.
const ISLE_LEAST: int = 8
## How far past the open sky between two linked clusters' boxes their lane reaches (cells), and how
## many cells of rock make an island too big to be one of the little ones between them
## (connect_isles).
const LANE_GROW: int = 3
const LANE_ISLAND: int = 24

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
## How far back from its gap (cells, from and to) one of each gap's two vanes stands, so the two do
## not face each other over it as a pair (Chasms.place_bells): the wind is the whole level's.
const VANE_BACK: Vector2i = Vector2i(7, 18)
## Its balloon (Balloon): on a free floor with BALLOON_AIR rows of open air over it, at least
## BALLOON_CLEAR cells from every exit, picked by hashing the level seed (BALLOON_DEAL, no draw).
const BALLOON_AIR: int = 5
const BALLOON_CLEAR: int = 4
const BALLOON_DEAL: int = Salts.SKY_ARCHETYPE_BALLOON * Salts.STRIDE
## Its temple (build_temples), in TEMPLE_SHARE of sky levels (TEMPLE_DEAL, no draw): a building of
## built stone TEMPLE_WIDE cells across, standing on an island as a crag's tower does. From the
## bottom: a stone floor (its stylobate) let down onto the island's rock, with a footing of built
## stone under it where the rock falls away (at most TEMPLE_FOOTING rows to the rock, under every
## column of it); a hall TEMPLE_HALL rows high over it, open between its columns (which the art draws)
## with a back wall of stone behind its middle (interiors), the altar (Temple) standing in its
## middle; and a roof a row thick, walkable. TEMPLE_AIR rows of open air are kept over the roof, where
## the art draws its pediment; nothing is built into it or placed in its hall or over its roof.
const TEMPLE_SHARE: float = 0.4
const TEMPLE_DEAL: int = Salts.SKY_ARCHETYPE_TEMPLE * Salts.STRIDE
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
	clustered = true
	scale = SCALE
	chasmed = true
	crossing = LevelGen.Type.VANE
	switch_reach = SKY_SWITCH_REACH
	crossing_back = VANE_BACK
	open = true


## Read the clusters of islands the collapse gave, and join them in pairs (cluster_islands).
func shape(w: LevelGen) -> void:
	cluster_islands(w)


## The islands are too small and scattered for long floors to cut into: take the gaps between them
## that are already wide enough (_span_gaps), then build the rest (_build_gaps).
func cut_gates(w: LevelGen) -> void:
	var want: int = Chasms.wanted(w)
	_span_gaps(w, want)
	_build_gaps(w, want)
	build_temples(w)
	# Shores laid and air cleared can shut off a pocket of air: join (or fill) it again.
	w.connect_caves()
	# Joining pockets can tunnel through a shore's footing (the hulls' chambers are pockets):
	# every gap's two shores get rock under them and air on and over them again.
	for chasm: Chasm in w.chasms:
		for shore: Vector2i in [chasm.left, chasm.right]:
			if not w.is_ground(shore + Vector2i.DOWN):
				w._to_rock(shore + Vector2i.DOWN)
			for d: Vector2i in [Vector2i.ZERO, Vector2i.UP]:
				if w.is_ground(shore + d):
					w._to_open(shore + d)


## Stars only in and near the clusters of islands, ledges only in and about them, so the gaps
## between stay open.
func room(w: LevelGen, v: Vector2i, grow: int) -> bool:
	return w.in_isle(v, grow)

## Sky levels: read the clusters of islands the collapse gave (read_clusters), then link them
## (link_isles). Nothing is built here: the islands, in the clusters and between them, are the
## collapse's own.
static func cluster_islands(w: LevelGen) -> void:
	read_clusters(w)
	link_isles(w)


## The clusters of islands, read from the collapse: the sky's sample paints the air of a cluster
## white and the open sky round it another colour (LevelGen.SKY), and the collapse keeps them apart,
## so each patch of cells that is not open sky (LevelGen.open_sky), taken with its neighbours left,
## right, up and down, is a cluster. A patch with less than ISLE_LEAST cells of rock is no cluster:
## it is cleared to open sky. Each cluster is noted in LevelGen.isles as the box round it, and its
## cells in LevelGen.isle_of. No draw: the patches are found in a fixed order.
static func read_clusters(w: LevelGen) -> void:
	var cells: int = w.size.x * w.size.y
	w.isle_of.resize(cells)
	w.isle_of.fill(-1)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(cells)
	seen.fill(0)
	var cleared: Array[Vector2i] = []
	for start: int in range(cells):
		if seen[start] == 1 or (not w.open_sky.is_empty() and w.open_sky[start] == 1):
			continue
		var patch: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var rock: int = 0
		var lo: Vector2i = w.size
		var hi: Vector2i = Vector2i.ZERO
		var head: int = 0
		while head < patch.size():
			var i: int = patch[head]
			head += 1
			@warning_ignore("integer_division")
			var v: Vector2i = Vector2i(i / w.size.y, i % w.size.y)
			if w.types[i] == LevelGen.Type.GROUND:
				rock += 1
			lo = Vector2i(mini(lo.x, v.x), mini(lo.y, v.y))
			hi = Vector2i(maxi(hi.x, v.x), maxi(hi.y, v.y))
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = v + d
				if not w.is_valid(n):
					continue
				var k: int = n.x * w.size.y + n.y
				if seen[k] == 0 and (w.open_sky.is_empty() or w.open_sky[k] == 0):
					seen[k] = 1
					patch.append(k)
		if rock < ISLE_LEAST:
			for i: int in patch:
				if w.types[i] != LevelGen.Type.EMPTY:
					@warning_ignore("integer_division")
					cleared.append(Vector2i(i / w.size.y, i % w.size.y))
			continue
		for i: int in patch:
			w.isle_of[i] = w.isles.size()
		@warning_ignore("integer_division")
		w.isles.append([(lo + hi) / 2, Vector2i(maxi(1, (hi.x - lo.x + 1) / 2), maxi(1, (hi.y - lo.y + 1) / 2))])
	w._to_open_all(cleared)
	w.map_isles()


## Join the clusters in pairs, each to the nearest already joined (a tree of the shortest links
## between them, stacked clusters counting as further apart), and keep between each pair the
## little islands the collapse laid in the open sky there (connect_isles). Nothing is built
## between clusters: the way from one to the next is the wind (the gaps a vane's gust carries the
## wizard over, cut_gates, and the level's own wind in the open air), with those little islands to
## land on. No draw.
static func link_isles(w: LevelGen) -> void:
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
		left.erase(int(best[2]))
		linked.append(int(best[2]))
		connect_isles(w, int(best[1]), int(best[2]))
		w.links += 1


## The little islands between linked clusters `i` and `j`: those the collapse laid in the level's
## open sky (LevelGen.patches, collapsed from the islands painted on the sample's open sky,
## WaveFunctionCollapse.collapse_clusters) that lie whole in the lane between the two, the open
## sky between their boxes and LANE_GROW cells past it at their rounded edges, clear of both
## clusters. Each is laid as the collapse has it, rock and
## the thorns that touch it; one of LANE_ISLAND cells or more is left out, as is one the lane's
## edge would cut. Nothing is drawn: what is laid is the collapse's.
static func connect_isles(w: LevelGen, i: int, j: int) -> void:
	if w.patches.is_empty() or not w.patches[0] is Array or (w.patches[0] as Array).size() < w.size.x:
		return
	var sky: Array = w.patches[0]
	var lo: Vector2i = Vector2i.ZERO
	var hi: Vector2i = Vector2i.ZERO
	for axis: int in range(2):
		var a0: int = (w.isles[i][0] as Vector2i)[axis] - (w.isles[i][1] as Vector2i)[axis]
		var a1: int = (w.isles[i][0] as Vector2i)[axis] + (w.isles[i][1] as Vector2i)[axis]
		var b0: int = (w.isles[j][0] as Vector2i)[axis] - (w.isles[j][1] as Vector2i)[axis]
		var b1: int = (w.isles[j][0] as Vector2i)[axis] + (w.isles[j][1] as Vector2i)[axis]
		if a1 < b0 or b1 < a0:
			# Apart this way: the sky between them, and a little past it.
			lo[axis] = mini(a1, b1) + 1 - LANE_GROW
			hi[axis] = maxi(a0, b0) - 1 + LANE_GROW
		else:
			# Side by side this way: where they overlap.
			lo[axis] = maxi(a0, b0)
			hi[axis] = mini(a1, b1)
	var lane: Rect2i = Rect2i(lo, hi - lo + Vector2i.ONE).intersection(Rect2i(Vector2i.ZERO, w.size))
	var rock: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and Color(sky[v.x][v.y]) == Color.BLACK
	var free: Callable = func(v: Vector2i) -> bool:
		return lane.has_point(v) and w.isle_of[v.x * w.size.y + v.y] < 0 and w.type_at(v) == LevelGen.Type.EMPTY and not w.in_isle(v, 1)
	var seen: Dictionary = {}
	for x: int in range(lane.position.x, lane.end.x):
		for y: int in range(lane.position.y, lane.end.y):
			var start: Vector2i = Vector2i(x, y)
			if seen.has(start) or not rock.call(start):
				continue
			var body: Array[Vector2i] = [start]
			seen[start] = true
			var head: int = 0
			while head < body.size() and body.size() < LANE_ISLAND:
				var v: Vector2i = body[head]
				head += 1
				for dx: int in range(-1, 2):
					for dy: int in range(-1, 2):
						var n: Vector2i = v + Vector2i(dx, dy)
						if not seen.has(n) and rock.call(n):
							seen[n] = true
							body.append(n)
			if body.size() >= LANE_ISLAND or not body.all(free):
				continue
			for v: Vector2i in body:
				w._to_rock(v)
			for v: Vector2i in body:
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = v + d
					if w.is_valid(n) and Color(sky[n.x][n.y]) == Color.RED and free.call(n):
						w.put(n, LevelGen.Type.SPIKES)


## Sky levels: gaps between islands already about as wide as a chasm (GAP_MIN to CHASM_WIDTH and
## a cell or two more), from the end of one floor (GAP_SHORE cells of it) to the start of the next
## on the same row or the one below, with nothing but open air across the gap from the row over
## the floor to the row under it: a drop. Taken as chasms (crossed on a vane's wind) before any
## is cut, up to `want`. Each is laid out as a cut chasm is, its first cell the row under the
## floor.
static func _span_gaps(w: LevelGen, want: int) -> void:
	var floor_at: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and w.type_at(v) == LevelGen.Type.EMPTY and w.is_ground(v + Vector2i.DOWN) and w._open(v + Vector2i.UP)
	var air: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and w.type_at(v) == LevelGen.Type.EMPTY
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
	# Costed only in the first tier with any spot left. A gap's cost is how many cells building it
	# changes: across it, two rows over and under its floor row opened; on each shore, two rows over
	# and the floor row opened and the row under it made rock. Counted in boxes with running sums.
	var filled: PackedByteArray = PackedByteArray()
	filled.resize(w.types.size())
	filled.fill(0)
	for i: int in range(w.types.size()):
		if w.types[i] != LevelGen.Type.EMPTY:
			filled[i] = 1
	var full: CellSums = CellSums.new(w.size, filled)
	var spots: Array = []
	for tier: Array in tiers:
		for sp: Array in tier:
			var y: int = sp[0]
			var a: int = sp[1]
			var span: int = sp[2]
			var across: Rect2i = Rect2i(a, y - 2, span, 5)
			var shores: Array[Rect2i] = [Rect2i(a - BUILT_SHORE, y - 2, BUILT_SHORE, 3), Rect2i(a + span, y - 2, BUILT_SHORE, 3)]
			var footings: Array[Rect2i] = [Rect2i(a - BUILT_SHORE, y + 1, BUILT_SHORE, 1), Rect2i(a + span, y + 1, BUILT_SHORE, 1)]
			var cost: int = full.count(across) + full.count(shores[0]) + full.count(shores[1]) \
					+ 2 * BUILT_SHORE - full.count(footings[0]) - full.count(footings[1])
			spots.append([cost, y, a, span])
		if not spots.is_empty():
			break
	spots.sort()
	for chasm: Chasm in w.chasms:
		spots = Chasms.apart(spots, chasm.row, chasm.left.x + 1, chasm.planks.size())
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
					if w.type_at(c) != LevelGen.Type.GROUND:
						w._to_rock(c)
				elif w.type_at(c) != LevelGen.Type.EMPTY:
					w._to_open(c)
		# The air over the gap is kept clear, as over a cut chasm, and a wind spans it.
		Chasms.add_gap(w, y, a, span)


## Last of all (so nothing else in the level moves for it): its balloon (place_balloon).
func finish(w: LevelGen, _def: NextWorldDef) -> void:
	place_balloon(w)


## A temple in TEMPLE_SHARE of sky levels (see TEMPLE_SHARE), built where it fits (_temple_site):
## of those, the one needing the least footing, ties by a hash of the level seed. Its altar's extra
## info is its lock's sequence of winds (Rules.TEMPLE_LENGTH steps, each +1 right or -1 left, repeats and
## all), dealt by the level seed. Kept in LevelGen.temples.
static func build_temples(w: LevelGen) -> void:
	if not temple_dealt(w.seed_for_colors):
		return
	# What a site asks of each cell, worked out once for the whole search (_temple_site).
	var near: PackedByteArray = Chasms.near_mask(w)
	var bad: PackedByteArray = PackedByteArray()
	bad.resize(w.size.x * w.size.y)
	bad.fill(0)
	var down: PackedInt32Array = PackedInt32Array()
	down.resize(w.size.x * w.size.y)
	for x: int in range(w.size.x):
		var below: int = NO_FOOTING
		for y: int in range(w.size.y - 1, -1, -1):
			var i: int = x * w.size.y + y
			var v: Vector2i = Vector2i(x, y)
			var t: int = w.types[i]
			var foot_bad: bool = t != LevelGen.Type.EMPTY or near[i] == 1 or w.keep_clear.has(v)
			if foot_bad or w.structures.has(v):
				bad[i] = 1
			if t == LevelGen.Type.GROUND:
				below = 0
			elif foot_bad or below == NO_FOOTING:
				below = NO_FOOTING
			else:
				below += 1
			down[i] = below
	var air: CellSums = CellSums.new(w.size, bad)
	var best: Variant = null
	var best_score: int = 0
	for y: int in range(TEMPLE_AIR + TEMPLE_HALL + 3, w.size.y - 2):
		for x: int in range(2, w.size.x - TEMPLE_WIDE - 1):
			var box: Rect2i = Rect2i(x, y - TEMPLE_HALL - 1, TEMPLE_WIDE, TEMPLE_HALL + 2)
			var footing: int = _temple_site(w, box, air, down)
			if footing < 0:
				continue
			var score: int = footing * 100000 + posmod(Rules.level_seed(w.seed_for_colors, TEMPLE_DEAL + x * 977 + y * 31), 100000)
			if best == null or score < best_score:
				best = box
				best_score = score
	if best != null:
		_temple(w, best as Rect2i)


## Whether the sky level with seed `level_seed` (NextWorldDef.gen_seed) is dealt a temple
## (TEMPLE_SHARE of them, no draw): it is built only where it fits (build_temples).
static func temple_dealt(level_seed: int) -> bool:
	return posmod(Rules.level_seed(level_seed, TEMPLE_DEAL), 1000) < roundi(TEMPLE_SHARE * 1000.0)


## In build_temples' table of how far down each cell's column the rock is: no rock is reached
## through open air (thorns, a chasm's kept air, what is kept clear or anything else is met first,
## or the level's bottom).
const NO_FOOTING: int = 1 << 20

## How many cells of footing a temple in `box` (its roof's row to its stylobate's) would need, or -1
## where it cannot stand: it and TEMPLE_AIR rows over it all open air inside the level, clear of the
## gaps and of every other structure (none of them counted in `air`); under its stylobate, every
## column reaching the island's rock within TEMPLE_FOOTING rows (through open air clear of the gaps
## and of what is kept clear: `down`, per cell, how far below it that rock is), at least half of
## them on it at once, and one of its ends, so its hall is a hop up from the island's floor there.
static func _temple_site(w: LevelGen, box: Rect2i, air: CellSums, down: PackedInt32Array) -> int:
	var over: Rect2i = Rect2i(box.position.x, box.position.y - TEMPLE_AIR, box.size.x, box.size.y + TEMPLE_AIR)
	if not Rect2i(Vector2i.ZERO, w.size).encloses(over) or air.count(over) > 0:
		return -1
	var footing: int = 0
	var on_rock: int = 0
	var ends_on_rock: bool = false
	for x: int in range(box.position.x, box.end.x):
		var depth: int = down[x * w.size.y + box.end.y]
		if depth > TEMPLE_FOOTING:
			return -1
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
		# The island's rock it stands on is kept whole, so no tunnel joining the island's pockets
		# (connect_caves) is cut from under a column of it.
		w.claim(under, Claims.KEPT)
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
				w.claim(v, Claims.STRUCTURE, &"temple")
				w.claim(v, Claims.KEPT)
	for v: Vector2i in built:
		w.claim(v, Claims.STRUCTURE, &"temple")
		w.claim(v, Claims.KEPT)
	@warning_ignore("integer_division")
	var altar: Vector2i = Vector2i(x0 + box.size.x / 2, base - 1)
	var winds: Array = []
	var length: int = Rules.TEMPLE_LENGTH.x + posmod(Rules.level_seed(w.seed_for_colors, TEMPLE_DEAL + 100), Rules.TEMPLE_LENGTH.y - Rules.TEMPLE_LENGTH.x + 1)
	for i: int in range(length):
		winds.append(1 if posmod(Rules.level_seed(w.seed_for_colors, TEMPLE_DEAL + 1 + i), 2) == 0 else -1)
	w.put(altar, LevelGen.Type.TEMPLE, winds)
	var hoard: Array[Vector2i] = []
	for k: int in range(TEMPLE_HOARD):
		var at: Vector2i = altar + Vector2i(2 if k % 2 == 0 else -2, 0)
		if hall.has_point(at):
			w.put(at, LevelGen.Type.CLUSTER)
			hoard.append(at)
	w.temples.append(TempleSite.make(box, hall, altar, hoard))


## The balloon moored in every sky level (see BALLOON_AIR), and kept in LevelGen.balloon, the air
## over it kept clear; none where no floor has the room.
static func place_balloon(w: LevelGen) -> void:
	var spots: Array[Vector2i] = w.free_floors().filter(func(v: Vector2i) -> bool:
		if w.keep_clear.has(v) or w.exits.values().any(func(e: Vector2i) -> bool: return LevelGen.dist(e, v) < BALLOON_CLEAR):
			return false
		for k: int in range(1, BALLOON_AIR + 1):
			var up: Vector2i = v - Vector2i(0, k)
			if not w.is_valid(up) or w.is_ground(up) or w.keep_clear.has(up) or w.type_at(up) != LevelGen.Type.EMPTY:
				return false
		return true)
	var spot: Variant = LevelGen.best_of(spots, func(v: Vector2i) -> int: return posmod(Rules.level_seed(w.seed_for_colors, BALLOON_DEAL + v.x * 977 + v.y * 31), 100000))
	if spot != null:
		w.put(spot, LevelGen.Type.BALLOON)
		w.balloon = spot
		# The air its envelope fills is kept clear of what comes after (climbing ledges).
		for k: int in range(1, BALLOON_AIR + 1):
			w.claim((spot as Vector2i) - Vector2i(0, k), Claims.START_WAY)


## What lives in the sky, on top of an ordinary level's dressing:
## - a share of the ledge runs (PUFF_SHARE) are clouds that give way once stood on (Puff);
## - jump pads (Pad) on floors with a ledge or rock shelf within a pad's reach above;
## - updrafts (Wind, {"up": cells}) up open shafts, each rising from a floor to just over a
##   floor beside the shaft, so it lifts you onto a ledge;
## - shields on a share of the wisps and hoppers, and rebounding shots for a share of watchers.
func populate(w: LevelGen, _def: NextWorldDef) -> void:
	var start: Vector2i = w.exits.get(Ways.Exit.BACK, Vector2i(-1, -1))
	# Clouds that give way: whole runs of ledge at a time.
	var ledges: Array[Vector2i] = w.objects_of(LevelGen.Type.PLATFORM)
	var seen: Dictionary = {}
	for v: Vector2i in ledges:
		if seen.has(v):
			continue
		var run: Array[Vector2i] = []
		var c: Vector2i = v
		while w.is_valid(c) and w.type_at(c) == LevelGen.Type.PLATFORM:
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
	var floors: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.type_at(v) == LevelGen.Type.EMPTY and w.ground_below(v) and LevelGen.dist(v, start) >= 3 and shelf.call(v))
	var pads: Array[Vector2i] = w.pick_apart(floors, w.per_area(PADS_PER_K), 6)
	w.put_each(pads, LevelGen.Type.PAD)
	# At least one in every level: failing a floor under a shelf, any floor with headroom.
	if pads.is_empty():
		var open_floors: Array[Vector2i] = w.empties_where(func(v: Vector2i) -> bool: return w.type_at(v) == LevelGen.Type.EMPTY and w.ground_below(v) and w._open(v + Vector2i.UP) and w._open(v + Vector2i(0, -2)) and LevelGen.dist(v, start) >= 3)
		if not open_floors.is_empty():
			var at: Vector2i = w.pick(open_floors)
			pads.append(at)
			w.put(at, LevelGen.Type.PAD)
	# Updrafts: a shaft of open air over a floor, rising to just over a floor beside it.
	var shafts: Array = []
	for v: Vector2i in w.empties:
		if w.type_at(v) != LevelGen.Type.EMPTY or not w.ground_below(v) or LevelGen.dist(v, start) < 3:
			continue
		for h: int in range(UPDRAFT_MIN, UPDRAFT_MAX + 1):
			var top: Vector2i = v + Vector2i(0, -h)
			var clear: bool = true
			for d: int in range(0, h + 2):
				var c: Vector2i = v + Vector2i(0, -d)
				if not w.is_valid(c) or w.type_at(c) != LevelGen.Type.EMPTY:
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
			while x < w.size.x and w.type_at(Vector2i(x, y)) == LevelGen.Type.EMPTY and not w.in_isle(Vector2i(x, y), 1):
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
			cell.mods["shield"] = Rules.SHIELD_HP
		elif cell.type == LevelGen.Type.SHOOTER and w.rng.randf() < BOUNCE_SHARE:
			cell.mods["bounces"] = BOUNCES