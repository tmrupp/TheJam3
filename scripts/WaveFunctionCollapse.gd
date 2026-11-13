class_name WaveFunctionCollapse
extends RefCounted

## Collapses the terrain for one level. A failed collapse retries on a seed derived from the
## level seed and the attempt, so the same (seed, depth) always gives the same level. A place whose
## archetype builds round small insides of their own (Archetype.patches: the cemetery's crypts)
## has each collapsed too, after the terrain, on seeds of their own, and handed over after the
## terrain's columns as {"patches": [each inside, or [] if it never settled]} (LevelGen reads it).
## An inside may be collapsed by slices ("slices": &"columns" or &"rows", the crypts' trials): each
## column (or row) of its sample is one colour of a strip three cells thick, the strip is collapsed,
## and each colour of what settles is that column (or row) again. So a sample whose rows (or columns)
## must stay in their order keeps them, and only the order of its columns (or rows) is collapsed,
## three at a time, which settles where the whole picture seldom would.
## A place whose sample is a sheet of clusters (NextWorldDef.clustered, the sky's) has each cluster
## of its terrain collapsed from one cluster of the sheet (collapse_clusters).

## It is no node (docs/CODE_REVIEW.md 2.3): the collapse itself is a plain function (Collapse.run,
## gdextension/src/collapse.cpp) from a picture, a size and a seed to cells, and this holds what
## it is asked with from one call to the next. Each thread that lays levels out makes its own.

## How many cells across the pieces a sample is cut into are.
const PATTERN: int = 3

## What the next collapse is asked with (collapse): the sample, how many cells to lay, the seed,
## the piece's size, and which of a piece's eight versions are used (the first `symmetry`, or
## those of `symmetry_mask`, a bit each, when it is not 0; see NextWorldDef).
var sample: Image
var output_size: Vector2i = Vector2i(64, 64)
var seed: int = 0
var pattern_size: int = PATTERN
var symmetry: int = 5
var symmetry_mask: int = 0


## Collapse `sample` as set: the cells as columns of colours, [] where it never settled.
func collapse() -> Array:
	return Collapse.run(sample, output_size, seed, pattern_size, symmetry, symmetry_mask)


## The picture kept at `path` (a sample).
static func picture(path: String) -> Image:
	return (load(path) as Texture2D).get_image()


## Salt for the level seed when collapsing each inside (and each retry).
const PATCH_DEAL: int = Salts.WAVE_FUNCTION_COLLAPSE_PATCH * Salts.STRIDE
const PATCH_TRIES: int = 16
func generate_level(def: NextWorldDef) -> Array:
	if def.clustered:
		var laid: Array = collapse_clusters(picture(def.region), def.size, def.gen_seed)
		return laid if not laid.is_empty() else def.fallback()
	sample = picture(def.region)
	output_size = def.size
	symmetry = def.symmetry
	symmetry_mask = def.symmetry_mask
	var map: Array = []
	for attempt: int in range(32):
		seed = def.gen_seed if attempt == 0 else Rules.level_seed(def.gen_seed, Salts.COLLAPSE_RETRY * Salts.STRIDE + attempt)
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
		var inside_sample: Image = picture(String(specs[i]["sample"]))
		var size: Vector2i = specs[i]["size"]
		var slices: StringName = StringName(specs[i].get("slices", &""))
		var kinds: Array = []
		sample = inside_sample
		output_size = size
		if slices != &"":
			var strip: Array = _strip(inside_sample, slices == &"columns")
			sample = strip[0]
			kinds = strip[1]
			output_size = Vector2i(size.x, STRIP) if slices == &"columns" else Vector2i(STRIP, size.y)
		symmetry = 1
		symmetry_mask = 0
		var inside: Array = []
		for attempt: int in range(PATCH_TRIES):
			seed = Rules.level_seed(def.gen_seed, PATCH_DEAL + i * 100 + attempt)
			inside = collapse()
			if len(inside) > 0:
				break
		if slices != &"" and not inside.is_empty():
			inside = _unstrip(inside, kinds, size, slices == &"columns")
		patches.append(inside)
	map.append({"patches": patches})
	return map


## How thick the strip an inside is collapsed by slices from is (cells): the pattern's size.
const STRIP: int = 3

## Salt for the level seed when dealing a place of clusters its bands (which clusters, how wide and
## where) and collapsing each cluster (and each retry).
const BAND_DEAL: int = Salts.WAVE_FUNCTION_COLLAPSE_BAND * Salts.STRIDE
## The fewest rows of open sky between one band of clusters and the next, and the most more dealt.
const BAND_APART: int = 5
const BAND_GAP: int = 2
## The fewest columns of open sky between two clusters in a band, and the most more dealt.
const CLUSTER_APART: int = 8
const CLUSTER_GAP: int = 3
## How wide a cluster is collapsed, in hundredths of its sample's width (from, to).
const CLUSTER_WIDE: Vector2i = Vector2i(90, 140)
## The versions of a sample's pieces a cluster's collapse uses (NextWorldDef.symmetry_mask): as
## painted, and mirrored left to right.
const CLUSTER_TURNS: int = 33
## How many times a cluster is collapsed for one that settles and holds what it should.
const CLUSTER_TRIES: int = 6
## The fewest cells of rock a cluster is kept with.
const CLUSTER_LEAST: int = 8
## A cluster's outline: its full width down to this share of its height, then narrowing to a keel,
## to this share of its width at the bottom; and its top corners rounded by this many cells.
const OUTLINE_FULL: float = 0.45
const OUTLINE_KEEL: float = 0.55
const OUTLINE_CORNER: int = 2
## A body of rock smaller than this (cells) that the outline cuts through is taken away whole, so
## no small island is sliced; a larger one is cut at the outline, and what the cut leaves in
## pieces smaller than SCRAP is cleared.
const WHOLE_ISLAND: int = 40
const SCRAP: int = 5
## How many cells of open sky round the little islands painted on a sheet's open sky are taken with
## them as the open sky's sample.
const BETWEEN_ROUND: int = 3
## A body of rock this many cells or more (its cells touching, corners too) is a great island: a
## cluster sample that holds one is a great cluster, and every level has one collapsed from such a
## sample, kept only if it holds a great island itself.
const GREAT_ISLAND: int = 80


## Terrain `size` cells across and down from `sample`, a sheet of clusters, for the level seed
## `level_seed`. Each cluster painted on the sheet (_clusters: a patch of anything but open sky,
## LevelGen.SKY) is a sample of its own, and every cluster of the level is collapsed afresh from
## one of them (_cluster), three cells at a time as any level's terrain is: so its islands are new
## each time, made of the pieces of that painted cluster, and no painted cluster is ever copied.
## The clusters are dealt in bands across the level: a band is as tall as the sample of the first
## cluster dealt it, and is filled from side to side with clusters from any of the samples, none
## taller than the band (a tall sample's cluster is collapsed as high as the band), each
## CLUSTER_WIDE of its sample's width, CLUSTER_APART columns of open sky between them and up to CLUSTER_GAP more; bands are
## dealt one under another until no more fit, BAND_APART rows of open sky between and up to
## BAND_GAP more, the stack in the middle of the level's height and open sky over and under it.
## The first cluster dealt is a great one (GREAT_ISLAND), and so is the second of the second band
## dealt; each lies anywhere in its band, which lies anywhere in the stack. So a level has two
## great islands or more. Where little islands are painted straight onto the sheet's open sky,
## the level's open sky is collapsed from them too (_between, _sky), and handed on after the
## terrain's columns as {"patches": [it]} (LevelGen.patches), for the layout to keep what lies
## between the clusters it links. [] if the sheet has no clusters or none fits.
func collapse_clusters(sample: Image, size: Vector2i, level_seed: int) -> Array:
	var boxes: Array[Rect2i] = _clusters(sample)
	var crops: Array[Image] = []
	var great: Array[bool] = []
	for box: Rect2i in boxes:
		var crop: Image = sample.get_region(box)
		crop.convert(Image.FORMAT_RGBA8)
		for x: int in range(crop.get_width()):
			for y: int in range(crop.get_height()):
				if crop.get_pixel(x, y).is_equal_approx(LevelGen.SKY):
					crop.set_pixel(x, y, Color.WHITE)
		crops.append(crop)
		great.append(_largest_body(crop) >= GREAT_ISLAND)
	var any_great: bool = great.has(true)
	# The bands: each [the cluster that leads it, the rows of open sky over it].
	var bands: Array[Vector2i] = []
	var total: int = 0
	for n: int in range(size.y):
		var gap: int = BAND_APART + posmod(Rules.level_seed(level_seed, BAND_DEAL + 500 + n), BAND_GAP + 1) if n > 0 else 0
		var fits: Array[int] = []
		for k: int in range(boxes.size()):
			var wanted: bool = great[k] if n == 0 and any_great else true
			if wanted and total + gap + boxes[k].size.y <= size.y and boxes[k].size.x <= size.x:
				fits.append(k)
		if fits.is_empty():
			break
		# No cluster leads two bands while another that fits has led none.
		var fresh: Array[int] = fits.filter(func(k: int) -> bool: return not bands.any(func(b: Vector2i) -> bool: return b.x == k))
		fits = fresh if not fresh.is_empty() else fits
		bands.append(Vector2i(fits[posmod(Rules.level_seed(level_seed, BAND_DEAL + n), fits.size())], gap))
		total += gap + boxes[bands.back().x].size.y
	if bands.is_empty():
		return []
	# The band with the great cluster is dealt first, but lies anywhere in the stack: the stack is
	# turned round by the seed (`first`, where the first dealt lies).
	var first: int = posmod(Rules.level_seed(level_seed, BAND_DEAL + 3000), bands.size())
	var map: Array = []
	for x: int in range(size.x):
		var column: Array = []
		column.resize(size.y)
		column.fill(LevelGen.SKY)
		map.append(column)
	@warning_ignore("integer_division")
	var row: int = (size.y - total) / 2
	var greats: Array[int] = []
	for k: int in range(boxes.size()):
		if great[k]:
			greats.append(k)
	for n: int in range(bands.size()):
		# Which band this is in the order they were dealt.
		var dealt: int = posmod(n - first, bands.size())
		var lead: int = bands[dealt].x
		row += bands[n].y if n > 0 else 0
		var high: int = boxes[lead].size.y
		# The band's clusters, left to right: each Vector2i(which sample, how wide), the lead first.
		var laid: Array[Vector2i] = []
		var across: int = 0
		for slot: int in range(size.x):
			var salt: int = BAND_DEAL + 4000 + n * 100 + slot
			var k: int = lead if slot == 0 else posmod(Rules.level_seed(level_seed, salt), boxes.size())
			# The second band dealt has a great cluster too, after its lead.
			if slot == 1 and dealt == 1 and not greats.is_empty():
				k = greats[posmod(Rules.level_seed(level_seed, salt), greats.size())]
			var share: int = CLUSTER_WIDE.x + posmod(Rules.level_seed(level_seed, salt + 30), CLUSTER_WIDE.y - CLUSTER_WIDE.x + 1)
			@warning_ignore("integer_division")
			var wide: int = boxes[k].size.x * share / 100
			var gap: int = CLUSTER_APART + posmod(Rules.level_seed(level_seed, salt + 60), CLUSTER_GAP + 1) if slot > 0 else 0
			if across + gap + wide > size.x:
				# The last of the band: as wide as is left, if that is as wide as its sample.
				wide = size.x - across - gap
				if wide < boxes[k].size.x:
					break
			laid.append(Vector2i(k, wide))
			across += gap + wide
			laid.append(Vector2i(-1, gap))
		# Turned round by the seed, so the lead lies anywhere in the band; set in its middle.
		var turn: int = posmod(Rules.level_seed(level_seed, BAND_DEAL + 5000 + n), maxi(1, laid.size() / 2))
		@warning_ignore("integer_division")
		var x: int = (size.x - across) / 2
		for slot: int in range(laid.size() / 2):
			var from: int = posmod(slot - turn, laid.size() / 2)
			var k: int = laid[from * 2].x
			var wide: int = laid[from * 2].y
			x += laid[slot * 2 + 1].y if slot > 0 else 0
			var want_great: bool = great[k] and ((dealt == 0 and from == 0) or (dealt == 1 and from == 1))
			# No taller than its band; one lower than its band lies at a height in it dealt by the seed.
			var tall: int = mini(high, boxes[k].size.y)
			var patch: Array = _cluster(crops[k], Vector2i(wide, tall), Rules.level_seed(level_seed, BAND_DEAL + 6000 + n * 100 + slot), want_great)
			var drop: int = posmod(Rules.level_seed(level_seed, BAND_DEAL + 7000 + n * 100 + slot), high - tall + 1)
			for px: int in range(patch.size()):
				for py: int in range((patch[px] as Array).size()):
					map[x + px][row + drop + py] = patch[px][py]
			x += wide
		row += high
	# The open sky's own islands, collapsed for the whole level and handed on after its columns:
	# the layout keeps those that lie between two clusters it links (SkyArchetype.link_isles).
	var between: Image = _between(sample)
	if between != null and between.get_width() >= STRIP and between.get_height() >= STRIP:
		map.append({"patches": [_sky(between, size, Rules.level_seed(level_seed, BAND_DEAL + 8000))]})
	return map


## The clusters painted on a sheet: the box round each patch of cells that are not open sky (taken
## with their neighbours left, right, up and down) and that has air in it, in the order they are
## met reading down the sheet's columns from the left. A patch with no air in it is no cluster:
## rock painted straight onto the open sky is the open sky's own, a little island of it (_between).
static func _clusters(sample: Image) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for patch: Dictionary in _patches(sample):
		if patch["airy"]:
			out.append(patch["box"])
	return out


## Every patch of a sheet that is not open sky: {"cells": its cells, "box": the box round them,
## "airy": whether any of them is air}, in the order they are met reading down the sheet's
## columns from the left.
static func _patches(sample: Image) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for x: int in range(sample.get_width()):
		for y: int in range(sample.get_height()):
			var start: Vector2i = Vector2i(x, y)
			if seen.has(start) or sample.get_pixel(x, y).is_equal_approx(LevelGen.SKY):
				continue
			var patch: Array[Vector2i] = [start]
			seen[start] = true
			var lo: Vector2i = start
			var hi: Vector2i = start
			var airy: bool = false
			var head: int = 0
			while head < patch.size():
				var v: Vector2i = patch[head]
				head += 1
				lo = Vector2i(mini(lo.x, v.x), mini(lo.y, v.y))
				hi = Vector2i(maxi(hi.x, v.x), maxi(hi.y, v.y))
				airy = airy or sample.get_pixel(v.x, v.y).is_equal_approx(Color.WHITE)
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = v + d
					if n.x < 0 or n.y < 0 or n.x >= sample.get_width() or n.y >= sample.get_height() or seen.has(n) or sample.get_pixel(n.x, n.y).is_equal_approx(LevelGen.SKY):
						continue
					seen[n] = true
					patch.append(n)
			out.append({"cells": patch, "box": Rect2i(lo, hi - lo + Vector2i.ONE), "airy": airy})
	return out


## The sample of a sheet's open sky: the stretch of the sheet round the little islands painted
## straight onto its open sky (every patch with no air in it), BETWEEN_ROUND cells of sky round
## them, the clusters in it painted over with open sky. null if none is painted.
static func _between(sample: Image) -> Image:
	var sky: Image = sample.duplicate() as Image
	sky.convert(Image.FORMAT_RGBA8)
	var lo: Vector2i = Vector2i(sample.get_width(), sample.get_height())
	var hi: Vector2i = Vector2i(-1, -1)
	for patch: Dictionary in _patches(sample):
		if patch["airy"]:
			for v: Vector2i in patch["cells"]:
				sky.set_pixel(v.x, v.y, LevelGen.SKY)
		else:
			var box: Rect2i = patch["box"]
			lo = Vector2i(mini(lo.x, box.position.x), mini(lo.y, box.position.y))
			hi = Vector2i(maxi(hi.x, box.end.x - 1), maxi(hi.y, box.end.y - 1))
	if hi.x < 0:
		return null
	var round_it: Rect2i = Rect2i(lo, hi - lo + Vector2i.ONE).grow(BETWEEN_ROUND).intersection(Rect2i(0, 0, sample.get_width(), sample.get_height()))
	return sky.get_region(round_it)


## The open sky of a level `size` cells across and down, collapsed from `between` (_between) on
## `sky_seed`, three cells at a time: open sky with little islands in it, as its columns in the
## sample's colours. Collapsed again, on the next seed, while it does not settle (CLUSTER_TRIES at
## most); [] if it never does.
func _sky(between: Image, size: Vector2i, sky_seed: int) -> Array:
	sample = between
	output_size = size
	symmetry = 2
	symmetry_mask = CLUSTER_TURNS
	for attempt: int in range(CLUSTER_TRIES):
		seed = Rules.level_seed(sky_seed, attempt)
		var cells: Array = collapse()
		if not cells.is_empty():
			return cells
	return []


## A cluster `size` cells across and down, collapsed from `crop` (a painted cluster, its open sky
## made air) on `cluster_seed`, then cut to a cluster's outline (_trim): its columns, in the
## sample's colours, open sky outside the outline. Collapsed again, on the next seed, while it does
## not settle or holds too little (CLUSTER_LEAST cells of rock; a great island, if `want_great`):
## after CLUSTER_TRIES, the one that held the most rock, or all open sky if none settled.
func _cluster(crop: Image, size: Vector2i, cluster_seed: int, want_great: bool) -> Array:
	sample = crop
	output_size = size
	symmetry = 2
	symmetry_mask = CLUSTER_TURNS
	var best: Array = []
	var most: int = -1
	for attempt: int in range(CLUSTER_TRIES):
		seed = Rules.level_seed(cluster_seed, attempt)
		var cells: Array = collapse()
		if cells.is_empty():
			continue
		var cut: Array = _trim(cells, size)
		var rock: int = 0
		for column: Array in cut:
			rock += column.count(Color.BLACK)
		var enough: bool = rock >= CLUSTER_LEAST and (not want_great or _largest_body_of(cut) >= GREAT_ISLAND)
		if rock > most:
			most = rock
			best = cut
		if enough:
			return cut
	if best.is_empty():
		for x: int in range(size.x):
			var column: Array = []
			column.resize(size.y)
			column.fill(LevelGen.SKY)
			best.append(column)
	return best


## Whether cell (`x`, `y`) of a cluster `size` cells across and down lies inside its outline: a cell
## in from its edge all round, its top corners rounded (OUTLINE_CORNER), its full width down to
## OUTLINE_FULL of its height and narrowing from there to a keel (OUTLINE_KEEL of its width at the
## bottom).
static func _inside(x: int, y: int, size: Vector2i) -> bool:
	if x < 1 or y < 1 or x > size.x - 2 or y > size.y - 2:
		return false
	var down: float = float(y) / float(maxi(1, size.y - 1))
	var half: float = float(size.x) * 0.5 - 1.0
	if down > OUTLINE_FULL:
		var t: float = (down - OUTLINE_FULL) / (1.0 - OUTLINE_FULL)
		half *= 1.0 - t * t * (1.0 - OUTLINE_KEEL)
	half -= float(maxi(0, OUTLINE_CORNER - (y - 1)))
	return absf(float(x) + 0.5 - float(size.x) * 0.5) <= half


## The collapsed cluster `cells` (`size` across and down) cut to its outline (_inside): a body of
## rock the outline cuts through is taken away whole if it is small (under WHOLE_ISLAND cells),
## and cut at the outline if not, what is left of it in pieces under SCRAP cells cleared; thorns
## stay where they still touch rock; all else inside the outline is the cluster's air, and outside
## it open sky.
static func _trim(cells: Array, size: Vector2i) -> Array:
	var rock: Dictionary = {}
	for x: int in range(size.x):
		for y: int in range(size.y):
			if Color(cells[x][y]) == Color.BLACK:
				rock[Vector2i(x, y)] = true
	var cut: Dictionary = {}
	for body: Array in _bodies(rock):
		var outside: Array = body.filter(func(v: Vector2i) -> bool: return not _inside(v.x, v.y, size))
		if outside.is_empty():
			continue
		for v: Vector2i in (body if body.size() < WHOLE_ISLAND else outside):
			rock.erase(v)
		if body.size() >= WHOLE_ISLAND:
			for v: Vector2i in body:
				if rock.has(v):
					cut[v] = true
	for piece: Array in _bodies(cut):
		if piece.size() < SCRAP:
			for v: Vector2i in piece:
				rock.erase(v)
	var out: Array = []
	for x: int in range(size.x):
		var column: Array = []
		for y: int in range(size.y):
			var v: Vector2i = Vector2i(x, y)
			var c: Color = LevelGen.SKY
			if _inside(x, y, size):
				c = Color.WHITE
				if rock.has(v):
					c = Color.BLACK
				elif Color(cells[x][y]) == Color.RED and [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(d: Vector2i) -> bool: return rock.has(v + d)):
					c = Color.RED
			column.append(c)
		out.append(column)
	return out


## The bodies of the cells in `set` (a set of cells): each a list of cells that touch one another,
## corners too, in the order they are met reading down the columns from the left.
static func _bodies(cells: Dictionary) -> Array:
	var order: Array = cells.keys()
	order.sort()
	var seen: Dictionary = {}
	var out: Array = []
	for start: Vector2i in order:
		if seen.has(start):
			continue
		var body: Array[Vector2i] = [start]
		seen[start] = true
		var head: int = 0
		while head < body.size():
			var v: Vector2i = body[head]
			head += 1
			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					var n: Vector2i = v + Vector2i(dx, dy)
					if cells.has(n) and not seen.has(n):
						seen[n] = true
						body.append(n)
		out.append(body)
	return out


## The most cells of rock in one body in the picture `img`.
static func _largest_body(img: Image) -> int:
	var rock: Dictionary = {}
	for x: int in range(img.get_width()):
		for y: int in range(img.get_height()):
			if img.get_pixel(x, y).is_equal_approx(Color.BLACK):
				rock[Vector2i(x, y)] = true
	var most: int = 0
	for body: Array in _bodies(rock):
		most = maxi(most, body.size())
	return most


## The most cells of rock in one body in the columns `cells`.
static func _largest_body_of(cells: Array) -> int:
	var rock: Dictionary = {}
	for x: int in range(cells.size()):
		for y: int in range((cells[x] as Array).size()):
			if Color(cells[x][y]) == Color.BLACK:
				rock[Vector2i(x, y)] = true
	var most: int = 0
	for body: Array in _bodies(rock):
		most = maxi(most, body.size())
	return most


## The strip for collapsing `img` by its columns (`columns`) or rows: [the strip, each slice's
## colours in order of the colour that stands for it]. Each different slice gets a colour of its
## own, the n-th Color8(n + 1, 7, 200).
static func _strip(img: Image, columns: bool) -> Array:
	var count: int = img.get_width() if columns else img.get_height()
	var along: int = img.get_height() if columns else img.get_width()
	var ids: Dictionary = {}
	var kinds: Array = []
	var order: Array[int] = []
	for i: int in range(count):
		var slice: Array[Color] = []
		for j: int in range(along):
			slice.append(img.get_pixel(i, j) if columns else img.get_pixel(j, i))
		var key: String = str(slice)
		if not ids.has(key):
			ids[key] = kinds.size()
			kinds.append(slice)
		order.append(int(ids[key]))
	var strip: Image = Image.create(count if columns else STRIP, STRIP if columns else count, false, Image.FORMAT_RGBA8)
	for i: int in range(count):
		for k: int in range(STRIP):
			strip.set_pixel(i if columns else k, k if columns else i, Color8(order[i] + 1, 7, 200))
	return [strip, kinds]


## The inside of `size` a strip collapsed by slices stands for (see _strip): each colour along its
## first row (or column) the slice it stands for.
static func _unstrip(strip: Array, kinds: Array, size: Vector2i, columns: bool) -> Array:
	var out: Array = []
	for x: int in range(size.x):
		var column: Array = []
		for y: int in range(size.y):
			var code: Color = Color(strip[x][0]) if columns else Color(strip[0][y])
			var slice: Array = kinds[clampi(code.r8 - 1, 0, kinds.size() - 1)]
			column.append(slice[y] if columns else slice[x])
		out.append(column)
	return out
