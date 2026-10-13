class_name Crypts
extends RefCounted
## The cemetery's crypts (docs/REGIONS_PLAN.md §7): one or two a level, buildings of masonry dug
## into the hillside, as the crags' towers stand on the cliff but bigger, their insides collapsed by
## WFC from a sample of their own (wfc_images/crypt.png, drawn by tests/make_crypt_sample.gd):
## ossuary rooms, burial passages and squeezes, niches, stairs. The insides are collapsed with the
## level's terrain (Archetype.patches, CemeteryArchetype) and handed to the layout as
## LevelGen.patches; build sets them into the level right after its chasms are cut, and furnish
## fills them once everything else is laid. Inside it is completely dark (RisoLight, DARK): nothing
## shows but what a light lights. Nothing here draws from the world RNG: where a crypt goes and what
## it holds are hashed from the level seed.
##
## A crypt is its inside framed by a wall of masonry a cell thick all round, entered by a doorway a
## cell high through a side wall, at a floor inside, with a passage two rows high carved out from it
## through the rock until it meets open air (at most DOOR_REACH cells): one doorway on the side with
## the shorter passage, and one on the other side too where it fits. What the collapse cut off from
## the doorways is filled with rock, and so is any pit inside the wizard could drop into but not hop
## out of (Reach), until there are none. Its stone, inside and passages are kept whole
## (LevelGen.kept_whole) and kept out of the free cells, so nothing else is placed in it. Each is
## noted in LevelGen.crypts as {"box": the crypt with its walls (Rect2i), "inside": its open cells,
## "doors": its doorways' cells, "steps": the cell outside each doorway where its passage meets open
## air, "floors": the cells inside the wizard can stand in and get back out from, nearest a doorway
## first, "deep": the furthest of them from a doorway}.
##
## What it holds: a snuffing font (Snuffer) on a floor outside each doorway, laid as it is built;
## then, once the level is laid (furnish), the level's star cluster brought in to the first one's
## deepest floor (keeping its place among the level's objects, as a crag tower's key is) or, in a
## second, a hoard of stars (HOARD), and skeletons asleep on its floors (niches first,
## SKELETONS_PER). The
## necromancer's gate level keeps its first crypt for the necromancer and its graves instead
## (LevelGen.place_boss).

## The insides collapsed for each level (Archetype.patches), the first crypt's first: cells across
## and down, not counting the walls.
const INSIDES: Array[Vector2i] = [Vector2i(18, 9), Vector2i(15, 8)]
## A level of at least TWO_AREA cells has two crypts, by a chance of TWO_SHARE dealt by the level
## seed; a smaller one has one.
const TWO_AREA: int = 2400
const TWO_SHARE: float = 0.6
## Cells kept between a crypt and another crypt, a chasm's kept air or anything kept whole.
const APART: int = 3
## The longest passage out from a doorway to open air (cells).
const DOOR_REACH: int = 7
## How much each cell of passage counts against a site, against each cell of open air it walls over.
const PASSAGE_COST: int = 3
## How dark it is inside (RisoLight): night ink over all no light falls on.
const DARK: float = 0.94
## Skeletons asleep in a crypt: one for each SKELETONS_PER of its floors (more on a harder preset,
## Difficulty.foes), at least SKELETONS_MIN, each at least SKELETON_APART cells from another and
## SKELETON_CLEAR from a doorway.
const SKELETONS_PER: int = 9
const SKELETONS_MIN: int = 2
const SKELETON_APART: int = 3
const SKELETON_CLEAR: int = 4
## The stars of the hoard in a crypt the level's cluster has not gone to.
const HOARD: int = 4
## How far from a doorway's step (cells) its snuffing font may stand.
const FONT_REACH: int = 5
## Salts for the level seed: how many crypts, where each goes (ties), and which floors its
## skeletons sleep on.
const COUNT_DEAL: int = 6100
const SITE_DEAL: int = 6110
const SLEEP_DEAL: int = 6120
## The sample its insides are collapsed from.
const SAMPLE: String = "res://wfc_images/crypt.png"


## The insides to collapse for a crypted level (see Archetype.patches).
static func patches() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for size: Vector2i in INSIDES:
		out.append({"sample": SAMPLE, "size": size})
	return out


## How many crypts `w` has (see TWO_AREA).
static func wanted(w: LevelGen) -> int:
	if w.size.x * w.size.y < TWO_AREA:
		return 1
	var roll: float = float(posmod(Rules.level_seed(w.seed_for_colors, COUNT_DEAL), 1000)) / 1000.0
	return 2 if roll < TWO_SHARE else 1


## Set the collapsed insides into `w` as crypts (see the class description), then join the caves
## again round their walls.
static func build(w: LevelGen) -> void:
	var n: int = mini(wanted(w), w.patches.size())
	for i: int in range(n):
		var inside: Array = w.patches[i]
		if inside.is_empty():
			continue
		var site: Dictionary = _site(w, inside)
		if not site.is_empty():
			_raise(w, inside, site)
	if not w.crypts.is_empty():
		w.connect_caves()


## Whether a crypt's inside (as collapsed) is open at cell (`x`, `y`) of it.
static func _open_in(inside: Array, x: int, y: int) -> bool:
	return Color(inside[x][y]) != Color.BLACK


## Where the crypt with `inside` goes: {"box", "doors": [[the doorway, the passage's cells, the step
## out]...]}, the site walling over the least open air and needing the shortest passages, ties dealt
## by the seed; {} if none fits.
static func _site(w: LevelGen, inside: Array) -> Dictionary:
	var size: Vector2i = Vector2i(inside.size(), (inside[0] as Array).size()) + Vector2i(2, 2)
	var blocked: Dictionary = _blocked(w)
	var open_sum: PackedInt32Array = _sums(w, func(v: Vector2i) -> bool: return not w.is_ground(v))
	var blocked_sum: PackedInt32Array = _sums(w, func(v: Vector2i) -> bool: return blocked.has(v))
	var best: Dictionary = {}
	var best_score: int = 1 << 30
	var best_tie: int = 0
	for x: int in range(1, w.size.x - size.x):
		for y: int in range(1, w.size.y - size.y):
			var box: Rect2i = Rect2i(Vector2i(x, y), size)
			if _count(w, blocked_sum, box.grow(APART)) > 0:
				continue
			var score: int = _count(w, open_sum, box)
			if score > best_score:
				continue
			var doors: Array = _doors(w, inside, box, blocked)
			if doors.is_empty():
				continue
			for door: Array in doors:
				score += (door[1] as Array).size() * PASSAGE_COST
			var tie: int = Rules.level_seed(w.seed_for_colors, SITE_DEAL + x * 131 + y)
			if score < best_score or (score == best_score and tie < best_tie):
				best_score = score
				best_tie = tie
				best = {"box": box, "doors": doors}
	return best


## Running sums over `w` of the cells passing `test`, for counting them in any box at once (_count).
static func _sums(w: LevelGen, test: Callable) -> PackedInt32Array:
	var h: int = w.size.y + 1
	var sums: PackedInt32Array = PackedInt32Array()
	sums.resize((w.size.x + 1) * h)
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var here: int = 1 if test.call(Vector2i(x, y)) else 0
			sums[(x + 1) * h + y + 1] = here + sums[x * h + y + 1] + sums[(x + 1) * h + y] - sums[x * h + y]
	return sums


## How many cells in `box` (clipped to the level) `sums` counts.
static func _count(w: LevelGen, sums: PackedInt32Array, box: Rect2i) -> int:
	var r: Rect2i = box.intersection(Rect2i(Vector2i.ZERO, w.size))
	if not r.has_area():
		return 0
	var h: int = w.size.y + 1
	return sums[r.end.x * h + r.end.y] - sums[r.position.x * h + r.end.y] - sums[r.end.x * h + r.position.y] + sums[r.position.x * h + r.position.y]


## The cells a crypt keeps away from: every chasm's kept air (Chasms.near), what is kept whole or
## clear, the other crypts.
static func _blocked(w: LevelGen) -> Dictionary:
	var out: Dictionary = {}
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var v: Vector2i = Vector2i(x, y)
			if Chasms.near(w, v) or w.kept(v) or w.keep_clear.has(v) or w.structures.has(v):
				out[v] = true
	return out


## The doorways a crypt with `inside` in `box` would have: on each side, at the lowest floor inside
## beside the wall whose passage out reaches open air soonest; the side with the shorter passage
## first, and the other side's too if it has one. Each [the doorway, the passage's cells (both
## rows), the step out (the open cell it meets)].
static func _doors(w: LevelGen, inside: Array, box: Rect2i, blocked: Dictionary) -> Array:
	var out: Array = []
	for side: int in [-1, 1]:
		var wall: int = box.position.x if side < 0 else box.end.x - 1
		var col: int = 0 if side < 0 else inside.size() - 1
		var best: Array = []
		for row: int in range((inside[0] as Array).size() - 1, -1, -1):
			if not _open_in(inside, col, row):
				continue
			if row + 1 < (inside[0] as Array).size() and _open_in(inside, col, row + 1):
				continue
			var y: int = box.position.y + 1 + row
			var cut: Array[Vector2i] = []
			var step: Variant = null
			for k: int in range(1, DOOR_REACH + 1):
				var c: Vector2i = Vector2i(wall + side * k, y)
				if c.x < 1 or c.x >= w.size.x - 1 or blocked.has(c) or blocked.has(c + Vector2i.UP):
					break
				var cell: LevelGen.Type = w.get_cell(c).type
				if cell == LevelGen.Type.EMPTY:
					step = c
					break
				if cell != LevelGen.Type.GROUND:
					break
				cut.append(c)
				if y - 1 >= 1:
					cut.append(c + Vector2i.UP)
			if step == null:
				continue
			if best.is_empty() or cut.size() < (best[1] as Array).size():
				best = [Vector2i(wall, y), cut, step]
		if not best.is_empty():
			out.append(best)
	if out.size() == 2 and (out[1][1] as Array).size() < (out[0][1] as Array).size():
		out.reverse()
	return out


## Build the crypt with `inside` at `site` (from _site) into `w` and note it in LevelGen.crypts.
static func _raise(w: LevelGen, inside: Array, site: Dictionary) -> void:
	var box: Rect2i = site["box"]
	var room: Rect2i = box.grow(-1)
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			var v: Vector2i = Vector2i(x, y)
			if room.has_point(v) and _open_in(inside, x - room.position.x, y - room.position.y):
				_open_at(w, v)
			else:
				_rock_at(w, v)
				w.masonry[v] = true
	var doors: Array[Vector2i] = []
	var steps: Array[Vector2i] = []
	var passages: Array[Vector2i] = []
	for door: Array in site["doors"]:
		_open_at(w, door[0])
		w.masonry.erase(door[0])
		for c: Vector2i in door[1]:
			_open_at(w, c)
			passages.append(c)
		doors.append(door[0])
		steps.append(door[2])
	# What the collapse cut off from the doorways is filled with rock.
	var inner: Array[Vector2i] = []
	for v: Vector2i in doors:
		inner.append(v + Vector2i.RIGHT * (1 if v.x == box.position.x else -1))
	var open: Dictionary = _flood(w, room, inner)
	for x: int in range(room.position.x, room.end.x):
		for y: int in range(room.position.y, room.end.y):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_ground(v) and not open.has(v):
				_rock_at(w, v)
				w.masonry[v] = true
	var floors: Array[Vector2i] = _fill_pits(w, room, doors)
	var cells: Array[Vector2i] = []
	for x: int in range(room.position.x, room.end.x):
		for y: int in range(room.position.y, room.end.y):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_ground(v):
				cells.append(v)
				w.interiors[v] = true
	for x: int in range(box.position.x, box.end.x):
		for y: int in range(box.position.y, box.end.y):
			w.kept_whole[Vector2i(x, y)] = true
			w.structures[Vector2i(x, y)] = &"crypt"
			w.empties.erase(Vector2i(x, y))
	for c: Vector2i in passages:
		w.kept_whole[c] = true
		w.empties.erase(c)
		w.kept_whole[c + Vector2i.DOWN] = true
	for v: Vector2i in steps:
		w.kept_whole[v] = true
		w.kept_whole[v + Vector2i.DOWN] = true
	var crypt: Dictionary = {"box": box, "inside": cells, "doors": doors, "steps": steps, "floors": floors, "deep": floors.back() if not floors.is_empty() else Vector2i(-1, -1)}
	w.crypts.append(crypt)
	_fonts(w, crypt)


## The open cells inside `room` joined through open air to `from`.
static func _flood(w: LevelGen, room: Rect2i, from: Array[Vector2i]) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	for v: Vector2i in from:
		if room.has_point(v) and not w.is_ground(v):
			seen[v] = true
			queue.append(v)
	var head: int = 0
	while head < queue.size():
		var v: Vector2i = queue[head]
		head += 1
		for d: Vector2i in w.neighbor_offsets:
			var n: Vector2i = v + d
			if room.has_point(n) and not seen.has(n) and not w.is_ground(n):
				seen[n] = true
				queue.append(n)
	return seen


## The floors inside `room` (open cells with rock under them) the wizard can hop to from a doorway
## and back out from, nearest a doorway first (in hops). A floor they could drop to but not get back
## out from is a pit: it is filled with rock (its floor raised a row) and the floors worked out
## again, until there are none.
static func _fill_pits(w: LevelGen, room: Rect2i, doors: Array[Vector2i]) -> Array[Vector2i]:
	for pass_: int in range(room.size.x * room.size.y):
		var stand: Array[Vector2i] = doors.duplicate()
		for x: int in range(room.position.x, room.end.x):
			for y: int in range(room.position.y, room.end.y):
				var v: Vector2i = Vector2i(x, y)
				if not w.is_ground(v) and Reach.underfoot(w, v):
					stand.append(v)
		var there: Array[Vector2i] = _hops(w, stand, doors, false)
		var back: Dictionary = {}
		for v: Vector2i in _hops(w, stand, doors, true):
			back[v] = true
		var pits: Array[Vector2i] = there.filter(func(v: Vector2i) -> bool: return not back.has(v) and room.has_point(v))
		if pits.is_empty():
			return there.filter(func(v: Vector2i) -> bool: return room.has_point(v))
		for v: Vector2i in pits:
			_rock_at(w, v)
			w.masonry[v] = true
	return []


## The cells of `stand` reached hop by hop from `from` (back: those `from` is reached from), in the
## order reached.
static func _hops(w: LevelGen, stand: Array[Vector2i], from: Array[Vector2i], back: bool) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var order: Array[Vector2i] = []
	for v: Vector2i in from:
		seen[v] = true
		order.append(v)
	var head: int = 0
	while head < order.size():
		var a: Vector2i = order[head]
		head += 1
		for b: Vector2i in stand:
			if seen.has(b) or absi(b.x - a.x) > Reach.ACROSS + 4:
				continue
			if (Reach.hop(w, b, a, false) if back else Reach.hop(w, a, b, false)):
				seen[b] = true
				order.append(b)
	return order


## Fill the crypts of `w` once everything else is laid (see the class description). `def` is the
## level's, for the necromancer's gate level.
static func furnish(w: LevelGen, def: NextWorldDef) -> void:
	for i: int in range(w.crypts.size()):
		var crypt: Dictionary = w.crypts[i]
		var floors: Array[Vector2i] = crypt["floors"]
		if floors.is_empty():
			continue
		if i == 0 and def.gate == &"necromancer" and not Worlds.is_side(def.coord):
			continue
		var deep: Vector2i = crypt["deep"]
		var cluster: Variant = _cluster(w)
		if cluster != null:
			w.move_object(cluster, deep)
		else:
			_hoard(w, crypt)
		_sleepers(w, crypt, deep)


## The level's star cluster (LevelGen.place_cluster), out in the level: not in a vault, nor in a
## crypt already; or null.
static func _cluster(w: LevelGen) -> Variant:
	for v: Vector2i in w.objects:
		var in_vault: bool = w.vaults.any(func(vault: Dictionary) -> bool: return (vault["room"] as Array).has(v))
		if w.get_cell(v).type == LevelGen.Type.CLUSTER and w.structures.get(v, &"") != &"crypt" and not in_vault:
			return v
	return null


## A hoard of HOARD stars on `crypt`'s deepest free floors.
static func _hoard(w: LevelGen, crypt: Dictionary) -> void:
	var floors: Array[Vector2i] = crypt["floors"]
	var n: int = 0
	for i: int in range(floors.size() - 1, -1, -1):
		if n >= HOARD:
			break
		if w.get_cell(floors[i]).type == LevelGen.Type.EMPTY:
			w.put(floors[i], LevelGen.Type.COIN)
			n += 1


## The skeletons asleep in `crypt` (see the consts), on free floors: niches (rock over them and on
## one side) first, then the rest, then those nearer a doorway than SKELETON_CLEAR, each in an
## order dealt by the seed.
static func _sleepers(w: LevelGen, crypt: Dictionary, deep: Vector2i) -> void:
	var floors: Array[Vector2i] = crypt["floors"]
	var doors: Array[Vector2i] = crypt["doors"]
	var want: int = maxi(SKELETONS_MIN, roundi(float(floors.size()) / float(SKELETONS_PER) * Difficulty.foes()))
	var spots: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return v != deep and w.get_cell(v).type == LevelGen.Type.EMPTY)
	var key: Callable = func(v: Vector2i) -> int:
		var niche: bool = w.is_ground(v + Vector2i.UP) and (w.is_ground(v + Vector2i.LEFT) or w.is_ground(v + Vector2i.RIGHT))
		var near: bool = doors.any(func(d: Vector2i) -> bool: return LevelGen.dist(d, v) < SKELETON_CLEAR)
		return (2 << 20 if near else 0) + (0 if niche else 1 << 20) + posmod(Rules.level_seed(w.seed_for_colors, SLEEP_DEAL + v.x * 977 + v.y), 1 << 20)
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return key.call(a) < key.call(b))
	var chosen: Array[Vector2i] = []
	for v: Vector2i in spots:
		if chosen.size() >= want:
			break
		if chosen.all(func(q: Vector2i) -> bool: return LevelGen.dist(q, v) >= SKELETON_APART):
			chosen.append(v)
			w.put(v, LevelGen.Type.SKELETON)


## A snuffing font on the free floor nearest each of `crypt`'s steps out, within FONT_REACH, outside
## the crypt: laid as the crypt is built, before anything else takes the floors by its doorways,
## and kept whole (with the rock under it).
static func _fonts(w: LevelGen, crypt: Dictionary) -> void:
	var box: Rect2i = crypt["box"]
	for step: Vector2i in crypt["steps"]:
		var spot: Variant = w.best_of(w.free_floors(), func(v: Vector2i) -> int: return LevelGen.dist(v, step),
				func(v: Vector2i) -> bool: return LevelGen.dist(v, step) <= FONT_REACH and not box.grow(1).has_point(v) and not w._crowds_exit(v))
		if spot != null:
			w.put(spot, LevelGen.Type.SNUFFER)
			w.kept_whole[spot] = true
			w.kept_whole[(spot as Vector2i) + Vector2i.DOWN] = true


## Rock at `v`, inside the level's edge.
static func _rock_at(w: LevelGen, v: Vector2i) -> void:
	if w.is_valid(v) and not w.is_ground(v):
		w._to_rock(v)


## Open air at `v`, inside the level's edge.
static func _open_at(w: LevelGen, v: Vector2i) -> void:
	if w.is_valid(v) and w.get_cell(v).type != LevelGen.Type.EMPTY:
		w._to_open(v)
