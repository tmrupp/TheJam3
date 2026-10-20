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
## Before it is set in, the bits of its inside the collapse left apart from the rest are joined to
## the biggest stretch of it by stairs carved through the rock (_joined), so little of it is lost to
## the filling below. A crypt is its inside framed by a wall of masonry a cell thick all round, entered by a doorway a
## cell high through a side wall, at a floor inside, with a passage two rows high carved out from it
## through the rock until it meets open air (at most DOOR_REACH cells): one doorway on the side with
## the shorter passage, and one on the other side too where it fits: on each side, at the floor
## from which the most of the inside's footholds are got to hop by hop (_reach_in, a rough reach
## over the inside alone), then the shortest passage. What the collapse cut off from the doorways is filled with rock, and so is
## any pit inside the wizard could drop into but not hop out of (Reach), until there are none, and
## then whatever filling the pits cut off. Where footholds inside are still out of reach over a
## floor that is reached (a tall room with nothing to climb), steps are set in to climb to them: a
## cell of rock a hop over the reached floor, toward the foothold (_step, at most STEPS). Its stone, inside and passages are kept whole
## (LevelGen.kept_whole) and kept out of the free cells, so nothing else is placed in it. Each is
## noted in LevelGen.crypts as {"box": the crypt with its walls (Rect2i), "inside": its open cells,
## "doors": its doorways' cells, "steps": the cell outside each doorway where its passage meets open
## air, "floors": the cells inside the wizard can stand in and get back out from, nearest a doorway
## first, "deep": the furthest of them from a doorway}.
##
## Its doorways may be shut by a sun or a shade block (PhaseBlock), dealt by the seed for each, in
## place of the light gates that once stood there: a shade block (SHADE_DOOR_SHARE), passed with the
## flame lit, or a sun block (SUN_DOOR_SHARE), passed with it snuffed, so the crypt is entered lit,
## waking its sleepers, or in the dark; the rest are open. A second crypt's may be ossuary doors
## instead (phase).
##
## What it holds: a snuffing font (Snuffer) on a floor outside each doorway and another on the floor
## inside nearest it, laid as it is built, so a wizard who has lit their flame inside can always
## put it out again;
## then, once the level is laid (furnish), the level's star cluster brought in to the first one's
## deepest floor (keeping its place among the level's objects, as a crag tower's key is) or, in a
## second, a hoard of stars (HOARD), skeletons asleep on its floors (niches first,
## SKELETONS_PER), stars to find on its ledges (STARS_PER), and before those two, alternating
## thorns along its floors (THORN_BLOCK). The
## necromancer's gate level keeps its first crypt for the necromancer and its graves instead
## (LevelGen.place_boss).

## The insides collapsed for each level (Archetype.patches), the first crypt's first: cells across
## and down, not counting the walls.
const INSIDES: Array[Vector2i] = [Vector2i(22, 12), Vector2i(16, 9)]
## A level of at least TWO_AREA cells has two crypts, by a chance of TWO_SHARE dealt by the level
## seed; a smaller one has one.
const TWO_AREA: int = 2400
const TWO_SHARE: float = 0.6
## The smallest bit of a crypt's inside (open cells) joined to the rest rather than filled in, and
## how many rows of air are carved over each step of the stairs that join it.
const JOIN_MIN: int = 4
const STAIR_AIR: int = 3
## The most steps set into a crypt to climb to what is out of reach.
const STEPS: int = 24
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
const HOARD: int = 6
## Stars to find in a crypt: one for each STARS_PER of its floors, on free floors kept STARS_APART
## cells from one another, ledges (a floor on a slab with air under it) first, then the floors
## furthest from a doorway.
const STARS_PER: int = 5
const STARS_APART: int = 3
## The share of doorways shut by a shade block (passed lit), and of those shut by a sun block
## (passed dark), the rest open, dealt by the level seed (DOOR_DEAL) for each: as the sun and shade
## gates once were, a sun gate's doorway taking a shade block and a shade gate's a sun block.
const SHADE_DOOR_SHARE: float = 0.3
const SUN_DOOR_SHARE: float = 0.35
const DOOR_DEAL: int = 6130
## Alternating thorns along a crypt's floors (Spikes, timed): along each stretch of floor at least
## THORN_STRETCH cells long, a cell clear at each end (at its start only, in a stretch of two),
## blocks of THORN_BLOCK cells take turns, each
## out for THORN_UP of the thorns' CYCLE, the next block (in that stretch or the next) half a cycle
## on, so one is down while the other is out; none within THORN_CLEAR cells of a doorway. Their
## phase is hashed from the seed (THORN_DEAL).
const THORN_STRETCH: int = 2
const THORN_BLOCK: int = 1
const THORN_UP: float = 0.45
const THORN_CLEAR: int = 2
const THORN_DEAL: int = 6150
## How far from a doorway's step (cells) its snuffing font may stand, and how far it may stand if
## there is no floor that near (a doorway opening onto a drop).
const FONT_REACH: int = 5
const FONT_FAR: int = 10
## Salts for the level seed: how many crypts, where each goes (ties), which floors its skeletons
## sleep on, and where its stars lie (ties).
const COUNT_DEAL: int = 6100
const SITE_DEAL: int = 6110
const SLEEP_DEAL: int = 6120
const STAR_DEAL: int = 6140
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
		if (w.patches[i] as Array).is_empty():
			continue
		var inside: Array = _joined(w.patches[i])
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
			var opens: int = _reach_in(inside, Vector2i(col, row))
			if best.is_empty() or opens > int(best[3]) or (opens == int(best[3]) and cut.size() < (best[1] as Array).size()):
				best = [Vector2i(wall, y), cut, step, opens]
		if not best.is_empty():
			out.append(best)
	if out.size() == 2 and (out[1][1] as Array).size() < (out[0][1] as Array).size():
		out.reverse()
	return out


## How many footholds of `inside` (open cells with rock under them; its edges are rock) the wizard
## gets to hop by hop from foothold `from`, roughly as Reach has it over a level: up to Reach.UP
## rows up and Reach.ACROSS across (a cell further for every two fallen), over clear air: up from
## where they stand to a row over the higher end, across, and down to where they land (or, down
## a step and close by, along and down without the rise).
static func _reach_in(inside: Array, from: Vector2i) -> int:
	var wide: int = inside.size()
	var high: int = (inside[0] as Array).size()
	var open: Callable = func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < wide and y < high and _open_in(inside, x, y)
	var holds: Array[Vector2i] = []
	for x: int in range(wide):
		for y: int in range(high):
			if open.call(x, y) and not open.call(x, y + 1):
				holds.append(Vector2i(x, y))
	var clear: Callable = func(a: Vector2i, b: Vector2i, top: int) -> bool:
		for y: int in range(top, a.y + 1):
			if not open.call(a.x, y):
				return false
		for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			if not open.call(x, top):
				return false
		for y: int in range(top, b.y + 1):
			if not open.call(b.x, y):
				return false
		return true
	var seen: Dictionary = {from: true}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var a: Vector2i = queue[head]
		head += 1
		for b: Vector2i in holds:
			if seen.has(b):
				continue
			var rise: int = a.y - b.y
			var dx: int = absi(b.x - a.x)
			if rise > Reach.UP or dx > Reach.ACROSS + floori(float(maxi(0, -rise)) * 0.5):
				continue
			var ok: bool = clear.call(a, b, mini(a.y, b.y) - 1)
			if not ok and rise <= 0 and dx <= 1:
				ok = clear.call(a, b, a.y)
			if ok:
				seen[b] = true
				queue.append(b)
	return seen.size()


## `inside` (as collapsed) with each bit of it of at least JOIN_MIN open cells that is apart from
## the biggest joined to it: from the bit's cell nearest the biggest (a pair that climbs more than
## it crosses counting for more), stairs carved toward the biggest's cell, a step up or down for
## each cell across while both are left to go, then straight on, with STAIR_AIR rows of air over
## each step; straight up or down it is carved two wide, so steps fit in to climb it (_step). A
## copy; the collapse is left as it was.
static func _joined(inside: Array) -> Array:
	var out: Array = []
	for column: Array in inside:
		out.append(column.duplicate())
	var wide: int = out.size()
	var high: int = (out[0] as Array).size()
	for pass_: int in range(8):
		var sizes: Dictionary = _stretches(out)
		var biggest: int = 0
		for v: Vector2i in sizes:
			biggest = maxi(biggest, int(sizes[v]))
		var main: Array[Vector2i] = []
		var apart: Array[Vector2i] = []
		var groups: Dictionary = _groups(out)
		var main_id: int = -1
		for v: Vector2i in groups:
			if int(sizes[v]) == biggest and main_id < 0:
				main_id = int(groups[v])
		for v: Vector2i in groups:
			if int(groups[v]) == main_id:
				main.append(v)
			elif int(sizes[v]) >= JOIN_MIN:
				apart.append(v)
		if apart.is_empty() or main.is_empty():
			break
		main.sort()
		apart.sort()
		# The closest pair, the first found on a tie.
		var from: Vector2i = apart[0]
		var to: Vector2i = main[0]
		var best: int = 1 << 30
		for a: Vector2i in apart:
			for b: Vector2i in main:
				var d: int = absi(a.x - b.x) + absi(a.y - b.y) + 2 * maxi(0, absi(a.y - b.y) - absi(a.x - b.x))
				if d < best:
					best = d
					from = a
					to = b
		var at: Vector2i = from
		while at != to:
			var step: Vector2i = Vector2i(signi(to.x - at.x), signi(to.y - at.y))
			at += step
			var widths: Array[int] = [0]
			if step.x == 0:
				widths.append(1 if at.x + 1 < wide else -1)
			for across: int in widths:
				for k: int in range(STAIR_AIR):
					var c: Vector2i = at + Vector2i(across, -k)
					if c.x >= 0 and c.y >= 0 and c.x < wide and c.y < high:
						out[c.x][c.y] = Color.WHITE
	return out


## Each open cell of `inside` -> the number of the bit of it (joined through open air, side by
## side) it is in, the bits numbered in the order first met.
static func _groups(inside: Array) -> Dictionary:
	var out: Dictionary = {}
	var wide: int = inside.size()
	var high: int = (inside[0] as Array).size()
	var id: int = 0
	for x: int in range(wide):
		for y: int in range(high):
			if out.has(Vector2i(x, y)) or not _open_in(inside, x, y):
				continue
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			out[Vector2i(x, y)] = id
			var head: int = 0
			while head < queue.size():
				var v: Vector2i = queue[head]
				head += 1
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = v + d
					if n.x >= 0 and n.y >= 0 and n.x < wide and n.y < high and not out.has(n) and _open_in(inside, n.x, n.y):
						out[n] = id
						queue.append(n)
			id += 1
	return out


## Each open cell of `inside` (as collapsed) -> how many open cells it is joined to through open
## air (side by side), itself included.
static func _stretches(inside: Array) -> Dictionary:
	var out: Dictionary = {}
	var wide: int = inside.size()
	var high: int = (inside[0] as Array).size()
	for x: int in range(wide):
		for y: int in range(high):
			if out.has(Vector2i(x, y)) or not _open_in(inside, x, y):
				continue
			var group: Array[Vector2i] = [Vector2i(x, y)]
			var seen: Dictionary = {Vector2i(x, y): true}
			var head: int = 0
			while head < group.size():
				var v: Vector2i = group[head]
				head += 1
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = v + d
					if n.x >= 0 and n.y >= 0 and n.x < wide and n.y < high and not seen.has(n) and _open_in(inside, n.x, n.y):
						seen[n] = true
						group.append(n)
			for v: Vector2i in group:
				out[v] = group.size()
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
	var stairs: Array[Vector2i] = []
	for k: int in range(STEPS):
		if not _step(w, room, floors, stairs):
			break
		floors = _fill_pits(w, room, doors)
	# Filling the pits may have cut some air off from the doorways: filled too.
	var still: Dictionary = _flood(w, room, inner)
	for x: int in range(room.position.x, room.end.x):
		for y: int in range(room.position.y, room.end.y):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_ground(v) and not still.has(v):
				_rock_at(w, v)
				w.masonry[v] = true
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
	var crypt: Dictionary = {"box": box, "inside": cells, "doors": doors, "steps": steps, "floors": floors, "deep": floors.back() if not floors.is_empty() else Vector2i(-1, -1), "stairs": stairs}
	w.crypts.append(crypt)
	_fonts(w, crypt)
	_door_blocks(w, crypt)


## Set one step into `room` toward a foothold out of reach (see the class description): over the
## reached floor (of `floors`) with an unreached foothold nearest above it (between one and
## Reach.ACROSS cells across, more than Reach.UP rows up), a cell of rock a hop up, a cell toward
## it, with air to stand on it and over that; the nearest such pair first. Whether one was set (it
## is added to `stairs`).
static func _step(w: LevelGen, room: Rect2i, floors: Array[Vector2i], stairs: Array[Vector2i]) -> bool:
	var reached: Dictionary = {}
	for v: Vector2i in floors:
		reached[v] = true
	var out_of_reach: Array[Vector2i] = []
	for x: int in range(room.position.x, room.end.x):
		for y: int in range(room.position.y, room.end.y):
			var v: Vector2i = Vector2i(x, y)
			if not reached.has(v) and not w.is_ground(v) and Reach.underfoot(w, v):
				out_of_reach.append(v)
	var best: int = 1 << 30
	var step: Vector2i = Vector2i(-1, -1)
	for b: Vector2i in out_of_reach:
		for a: Vector2i in floors:
			var rise: int = a.y - b.y
			var dx: int = absi(b.x - a.x)
			if rise <= Reach.UP or dx > Reach.ACROSS:
				continue
			var s: Vector2i = Vector2i(a.x + signi(b.x - a.x), a.y - Reach.UP + 1)
			var score: int = (rise << 8) + dx
			if score >= best or not room.has_point(s) or not room.has_point(s + Vector2i.UP * 2):
				continue
			if w.is_ground(s) or w.is_ground(s + Vector2i.UP) or w.is_ground(s + Vector2i.UP * 2) or w.get_cell(s).type != LevelGen.Type.EMPTY:
				continue
			best = score
			step = s
	if best == 1 << 30:
		return false
	_rock_at(w, step)
	w.masonry[step] = true
	stairs.append(step)
	return true


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
		_thorns(w, crypt)
		_sleepers(w, crypt, deep)
		_stars(w, crypt)


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


## The stars to find in `crypt` (see STARS_PER), on its free floors: ledges first, then the floors
## furthest from a doorway, ties dealt by the seed.
static func _stars(w: LevelGen, crypt: Dictionary) -> void:
	var floors: Array[Vector2i] = crypt["floors"]
	var doors: Array[Vector2i] = crypt["doors"]
	var want: int = maxi(1, floori(float(floors.size()) / float(STARS_PER)))
	var spots: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.EMPTY)
	var key: Callable = func(v: Vector2i) -> int:
		var ledge: bool = w.is_valid(v + Vector2i.DOWN * 2) and not w.is_ground(v + Vector2i.DOWN * 2)
		var near: int = 99
		for d: Vector2i in doors:
			near = mini(near, LevelGen.dist(d, v))
		return (0 if ledge else 1 << 24) + ((99 - mini(near, 99)) << 16) + posmod(Rules.level_seed(w.seed_for_colors, STAR_DEAL + v.x * 977 + v.y), 1 << 16)
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return key.call(a) < key.call(b))
	var chosen: Array[Vector2i] = []
	for v: Vector2i in spots:
		if chosen.size() >= want:
			break
		if chosen.all(func(q: Vector2i) -> bool: return LevelGen.dist(q, v) >= STARS_APART):
			chosen.append(v)
			w.put(v, LevelGen.Type.COIN)


## The alternating thorns along `crypt`'s floors (see THORN_STRETCH): each stretch of free floor
## side by side, a cell clear at each end (or the start), in blocks taking turns.
static func _thorns(w: LevelGen, crypt: Dictionary) -> void:
	var doors: Array[Vector2i] = crypt["doors"]
	var free: Dictionary = {}
	for v: Vector2i in crypt["floors"]:
		if w.get_cell(v).type == LevelGen.Type.EMPTY and doors.all(func(d: Vector2i) -> bool: return LevelGen.dist(d, v) > THORN_CLEAR):
			free[v] = true
	var starts: Array[Vector2i] = []
	for v: Vector2i in free:
		if not free.has(v + Vector2i.LEFT):
			starts.append(v)
	starts.sort()
	var box: Rect2i = crypt["box"]
	var base: float = float(posmod(Rules.level_seed(w.seed_for_colors, THORN_DEAL + box.position.x * 977 + box.position.y), 1000)) / 1000.0 * Spikes.CYCLE
	var block: int = 0
	for start: Vector2i in starts:
		var stretch: Array[Vector2i] = []
		var at: Vector2i = start
		while free.has(at):
			stretch.append(at)
			at += Vector2i.RIGHT
		if stretch.size() < THORN_STRETCH:
			continue
		for k: int in range(1, maxi(2, stretch.size() - 1)):
			if k > 1 and (k - 1) % THORN_BLOCK == 0:
				block += 1
			w.put(stretch[k], LevelGen.Type.SPIKES, {"timed": fposmod(base + float(block % 2) * Spikes.CYCLE * 0.5, Spikes.CYCLE), "up": THORN_UP * Spikes.CYCLE})
		block += 1


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


## A snuffing font on the free floor nearest each of `crypt`'s steps out, within FONT_REACH (or,
## failing that, FONT_FAR), outside the crypt, and another on the floor inside nearest each
## doorway: laid as the crypt is built, before anything else takes the floors by its doorways, and
## kept whole (with the rock under it).
static func _fonts(w: LevelGen, crypt: Dictionary) -> void:
	var box: Rect2i = crypt["box"]
	var doors: Array[Vector2i] = crypt["doors"]
	for door: Vector2i in doors:
		var inner: Variant = w.best_of(crypt["floors"], func(v: Vector2i) -> int: return LevelGen.dist(v, door),
				func(v: Vector2i) -> bool: return v != door and not doors.has(v) and w.get_cell(v).type == LevelGen.Type.EMPTY)
		if inner != null:
			w.put(inner, LevelGen.Type.SNUFFER)
	for step: Vector2i in crypt["steps"]:
		var spot: Variant = w.best_of(w.free_floors(), func(v: Vector2i) -> int: return LevelGen.dist(v, step),
				func(v: Vector2i) -> bool: return LevelGen.dist(v, step) <= FONT_FAR and not box.grow(1).has_point(v) and not w._crowds_exit(v))
		if spot != null:
			w.put(spot, LevelGen.Type.SNUFFER)
			w.kept_whole[spot] = true
			w.kept_whole[(spot as Vector2i) + Vector2i.DOWN] = true


## Each of `crypt`'s doorways a shade block, a sun block or open, dealt by the seed (see
## SHADE_DOOR_SHARE).
static func _door_blocks(w: LevelGen, crypt: Dictionary) -> void:
	for door: Vector2i in crypt["doors"]:
		var roll: float = float(posmod(Rules.level_seed(w.seed_for_colors, DOOR_DEAL + door.x * 977 + door.y), 1000)) / 1000.0
		if roll < SHADE_DOOR_SHARE:
			w.put(door, LevelGen.Type.PHASE_BLOCK, false)
		elif roll < SHADE_DOOR_SHARE + SUN_DOOR_SHARE:
			w.put(door, LevelGen.Type.PHASE_BLOCK, true)


## Rock at `v`, inside the level's edge.
static func _rock_at(w: LevelGen, v: Vector2i) -> void:
	if w.is_valid(v) and not w.is_ground(v):
		w._to_rock(v)


## Open air at `v`, inside the level's edge.
static func _open_at(w: LevelGen, v: Vector2i) -> void:
	if w.is_valid(v) and w.get_cell(v).type != LevelGen.Type.EMPTY:
		w._to_open(v)


# ------------------------------------------------------------------ sun and shade blocks

## Sun and shade blocks (PhaseBlock) in the crypts, and ossuary doors (OssuaryDoor), laid last of
## all in a cemetery level (CemeteryArchetype.finish), hashed from the level seed and the cells,
## with no draw from the world RNG and nothing changed outside the crypts. In each furnished crypt:
## - phase stairs: where the crypt was given steps to climb its tall rooms (_step), at least
##   STAIRS_MIN of them, each becomes a block, the kinds taking turns up the climb, so it is climbed
##   by switching the light from hop to hop (a step with something on it stays rock);
## - shade floors: over a run of its alternating thorns, by a share of SHADE_FLOOR_SHARE, a floor of
##   shade blocks a cell up, walked in the dark over the thorns, or passed under lit, timing them;
## - phase walls: up to PHASE_WALLS of its passages a cell or two high (rock over and under, open to
##   either side) shut by a block, passed in the other light;
## - shut pockets: by a share of POCKET_SHARE, one of its stars walled in sun blocks wherever it is
##   open round it, reached only in the dark.
## And where the seed deals one (Rules.ossuary_at), the doorways of a level's second crypt are
## ossuary doors, which drink Rules.ossuary_fill charges before they open.
const STAIRS_MIN: int = 2
const SHADE_FLOOR_SHARE: float = 0.5
const PHASE_WALLS: int = 1
const POCKET_SHARE: float = 0.5
## Salts for the level seed: which kind each crypt's stairs start with, which runs of thorns get a
## shade floor, which passages are walled and with what, and which star is shut in.
const STAIRS_DEAL: int = 6400
const FLOOR_DEAL: int = 6410
const WALL_DEAL: int = 6420
const POCKET_DEAL: int = 6430


## A number from 0 up to 1 for cell `v` of `w`, hashed from its seed and `salt`.
static func _roll(w: LevelGen, salt: int, v: Vector2i) -> float:
	return float(posmod(Rules.level_seed(w.seed_for_colors, salt + v.x * 977 + v.y * 31), 1000)) / 1000.0


## Lay the blocks and doors (see STAIRS_MIN). `def` is the level's.
static func phase(w: LevelGen, def: NextWorldDef) -> void:
	if Rules.ossuary_at(def.coord) and w.crypts.size() >= 2:
		_ossuary(w, 1, Rules.ossuary_fill(def.coord.y))
	for i: int in range(w.crypts.size()):
		var crypt: Dictionary = w.crypts[i]
		if (crypt["floors"] as Array).is_empty() or (i == 0 and def.gate == &"necromancer" and not Worlds.is_side(def.coord)):
			continue
		_phase_stairs(w, crypt)
		_shade_floors(w, crypt)
		_phase_walls(w, crypt)
		_pocket(w, crypt)


## Whether cell `v` is free for a block: open, holding nothing.
static func _free(w: LevelGen, v: Vector2i) -> bool:
	return w.is_valid(v) and not w.is_ground(v) and w.get_cell(v).type == LevelGen.Type.EMPTY


## A sun block (`sun`) or a shade block at `v`, an open cell inside a crypt.
static func _block(w: LevelGen, v: Vector2i, sun: bool) -> void:
	w.put(v, LevelGen.Type.PHASE_BLOCK, sun)
	w.empties.erase(v)


## Each doorway of crypt `i` an ossuary door drinking `fill` charges.
static func _ossuary(w: LevelGen, i: int, fill: int) -> void:
	var crypt: Dictionary = w.crypts[i]
	if (crypt["floors"] as Array).is_empty():
		return
	for door: Vector2i in crypt["doors"]:
		if w.get_cell(door).type == LevelGen.Type.EMPTY:
			w.put(door, LevelGen.Type.OSSUARY_DOOR, [i, fill])
			w.empties.erase(door)
		else:
			w.set_kind(door, LevelGen.Type.OSSUARY_DOOR, [i, fill])


## The crypt's steps turned to blocks of each kind in turn, from the lowest (see STAIRS_MIN).
static func _phase_stairs(w: LevelGen, crypt: Dictionary) -> void:
	var stairs: Array[Vector2i] = []
	for s: Vector2i in crypt["stairs"]:
		var top: Vector2i = s + Vector2i.UP
		if w.is_ground(s) and w.is_valid(top) and not w.is_ground(top) and w.get_cell(top).type in [LevelGen.Type.EMPTY, LevelGen.Type.COIN]:
			stairs.append(s)
	if stairs.size() < STAIRS_MIN:
		return
	stairs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	var box: Rect2i = crypt["box"]
	var sun: bool = _roll(w, STAIRS_DEAL, box.position) < 0.5
	for s: Vector2i in stairs:
		w._to_open(s)
		w.interiors[s] = true
		(crypt["inside"] as Array[Vector2i]).append(s)
		_block(w, s, sun)
		sun = not sun


## Shade floors over the crypt's runs of thorns (see SHADE_FLOOR_SHARE).
static func _shade_floors(w: LevelGen, crypt: Dictionary) -> void:
	var thorns: Dictionary = {}
	for v: Vector2i in crypt["floors"]:
		if w.get_cell(v).type == LevelGen.Type.SPIKES:
			thorns[v] = true
	var starts: Array[Vector2i] = []
	for v: Vector2i in thorns:
		if not thorns.has(v + Vector2i.LEFT):
			starts.append(v)
	starts.sort()
	for start: Vector2i in starts:
		var run: Array[Vector2i] = []
		var at: Vector2i = start
		while thorns.has(at):
			run.append(at)
			at += Vector2i.RIGHT
		if _roll(w, FLOOR_DEAL, start) >= SHADE_FLOOR_SHARE:
			continue
		if not run.all(func(t: Vector2i) -> bool: return _free(w, t + Vector2i.UP) and w.is_valid(t + Vector2i.UP * 2) and not w.is_ground(t + Vector2i.UP * 2)):
			continue
		for t: Vector2i in run:
			_block(w, t + Vector2i.UP, false)


## Phase walls across the crypt's low passages (see PHASE_WALLS): the cells of each, a run of one or
## two open cells with rock over and under, open to either side at its foot, away from a doorway;
## the lowest passages first, then by the seed.
static func _phase_walls(w: LevelGen, crypt: Dictionary) -> void:
	var doors: Array[Vector2i] = crypt["doors"]
	var walls: Array = []
	for v: Vector2i in crypt["floors"]:
		if not _free(w, v) or v == crypt["deep"] or doors.any(func(d: Vector2i) -> bool: return LevelGen.dist(d, v) <= 2):
			continue
		if w.is_ground(v + Vector2i.LEFT) or w.is_ground(v + Vector2i.RIGHT):
			continue
		var cells: Array[Vector2i] = [v]
		if not w.is_ground(v + Vector2i.UP):
			if not _free(w, v + Vector2i.UP) or not w.is_ground(v + Vector2i.UP * 2):
				continue
			cells.append(v + Vector2i.UP)
		walls.append([cells, (cells.size() << 16) + int(_roll(w, WALL_DEAL, v) * 1000.0)])
	walls.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	var laid: Array[Vector2i] = []
	for wall: Array in walls:
		if laid.size() >= PHASE_WALLS:
			break
		var cells: Array[Vector2i] = wall[0]
		if not cells.all(func(c: Vector2i) -> bool: return _free(w, c)):
			continue
		var sun: bool = _roll(w, WALL_DEAL + 1, cells[0]) < 0.5
		for c: Vector2i in cells:
			_block(w, c, sun)
		laid.append(cells[0])


## A star of the crypt shut in sun blocks (see POCKET_SHARE): one standing on a floor, walled
## wherever it is open beside and over it, with at least two sides to wall; by the seed.
static func _pocket(w: LevelGen, crypt: Dictionary) -> void:
	var box: Rect2i = crypt["box"]
	if _roll(w, POCKET_DEAL, box.position) >= POCKET_SHARE:
		return
	var best: Variant = null
	var best_key: float = INF
	for v: Vector2i in crypt["floors"]:
		if v == crypt["deep"] or w.get_cell(v).type != LevelGen.Type.COIN:
			continue
		var around: Array[Vector2i] = []
		var fits: bool = true
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i(-1, -1), Vector2i(1, -1)]:
			var c: Vector2i = v + d
			if not w.is_valid(c) or w.is_ground(c):
				continue
			if w.get_cell(c).type != LevelGen.Type.EMPTY:
				fits = false
			around.append(c)
		if not fits or around.size() < 2:
			continue
		var key: float = _roll(w, POCKET_DEAL + 1, v)
		if key < best_key:
			best_key = key
			best = around
	if best == null:
		return
	for c: Vector2i in (best as Array[Vector2i]):
		_block(w, c, true)
