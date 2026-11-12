extends SceneTree
## The WFC sample for sky levels (wfc_images/sky_islands.png): a sheet of clusters of islands of
## cloud with open sky between them. A cluster is a box of air (white) holding its islands, and
## round the boxes is open sky (blue, LevelGen.SKY), open air too but another colour. The sheet is
## painted by hand in the generation lab and kept here as text (SHEET, see SampleSheet): run this
## with "fold" after painting, to write the picture into SHEET; with nothing, to draw the picture
## from SHEET; with "redraw", to draw a sheet afresh by the rules below, as the first was drawn,
## over whatever was painted.
##
## A sky level is not collapsed from the sheet as one picture: with two colours of emptiness
## outweighing the rock, the collapse gave boxes of air of every size and hardly an island in
## them. Each cluster on the sheet is a sample of its own instead, and every cluster of a level is
## collapsed afresh from one of them, three cells at a time
## (WaveFunctionCollapse.collapse_clusters): its islands are new each time, made of that painted
## cluster's pieces, then cut to a cluster's outline (a small island the outline would slice is
## taken away whole). So paint a cluster for each kind of cluster wanted:
## - what is painted inside one box is collapsed together, and nothing in one box mixes with
##   another's: a box of small islands gives small islands, a box holding a mass of rock gives
##   masses of rock;
## - a cluster comes out as high as its box (or as its band, if that is lower) and from its box's
##   width to that and half again;
## - a body of rock of 80 cells or more is a great island (WaveFunctionCollapse.GREAT_ISLAND): a
##   level's first cluster is collapsed from a box that holds one, and one more besides, so paint at
##   least one.
##
## The sheet now, as painted: two clusters of small islands, thorns set into the middle of their
## tops, one of them with a hollow hull; a third of small islands thinly spread; and the great
## island, a mass of rock 28 cells across, tunnelled through, with thorn pits in its floors.
##
## As first drawn (_redraw: three rows of five clusters): a cluster is two halves with a seam of
## bare air between them (SEAM columns). In a half, the islands are packed close, two or three
## cells apart, three rows clear over every top and under every island: small ones, a flat top
## four to nine cells wide to stand on, tapering underneath from the first row (the row under the
## top a cell narrower each side; an island five or six wide has a third row, one or two cells),
## now and then a column of cloud rising from one (COLUMNS); and hulls (HULLS, drawn below cell by
## cell), larger and hollow: a top and a lip over chambers between walls two cells thick, on a
## floor two rows thick, some with a keel, with holes through a top or a floor, a window through a
## wall at a chamber's floor, and doorways under lintels. Their thorns: a tuft at one end of a
## long top (TUFTS of the tops seven cells or wider, one or two cells, never the whole top), one
## hanging under an island's belly (HANGING), and beds on a hull's chamber floors and under its
## keel.
## Every thorn touches rock. Blue is open sky, white the air in a cluster, black rock, red thorns.
## godot --headless --path . --script res://tests/make_sky_sample.gd [-- fold | -- redraw]

## The picture it draws.
const PATH: String = "res://wfc_images/sky_islands.png"
## The sheet, a row a line: ~ open sky, . the air in a cluster, # rock, ^ thorns (SampleSheet.INKS).
const SHEET: PackedStringArray = [
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~......................~~~~~~..........................~~~",
	"~~~......................~~~~~~..........................~~~",
	"~~~.........#####........~~~~~~......######..##^^##......~~~",
	"~~~..####....###...####..~~~~~~.......####....####.......~~~",
	"~~~...##......#.....##...~~~~~~........##......##........~~~",
	"~~~......................~~~~~~..........................~~~",
	"~~~......................~~~~~~..........................~~~",
	"~~~......................~~~~~~............#.............~~~",
	"~~~......####..########..~~~~~~............#.............~~~",
	"~~~.......###..#######...~~~~~~.........####^^###..####..~~~",
	"~~~.......##........##...~~~~~~..##^#....#######....##...~~~",
	"~~~.......##.............~~~~~~...##.....................~~~",
	"~~~.......##^^...........~~~~~~..........................~~~",
	"~~~.......############...~~~~~~..........................~~~",
	"~~~.........########.....~~~~~~..........................~~~",
	"~~~............##........~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~......................~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~......................~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~............................~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~............................~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.....................#####..~~~",
	"~~~....................~~~~~~......................###...~~~",
	"~~~....................~~~~~~...################....#....~~~",
	"~~~.......####^^##.....~~~~~~....#################....##.~~~",
	"~~~........######......~~~~~~....##...###########......##~~~",
	"~~~....................~~~~~~................##.........#~~~",
	"~~~....................~~~~~~....##^^^##.....##.##^^^##.#~~~",
	"~~~....................~~~~~~..#..########..###..#####..#~~~",
	"~~~....................~~~~~~..##..#######..###...##...##~~~",
	"~~~....................~~~~~~...##..#####....####....####~~~",
	"~~~....................~~~~~~...########......#####..####~~~",
	"~~~..#####.............~~~~~~....#######.##########..##.#~~~",
	"~~~...###...##^^####...~~~~~~...###......#.#######......#~~~",
	"~~~....#.....######....~~~~~~...###.........####........#~~~",
	"~~~....................~~~~~~....##.###^^##.###..##^^##.#~~~",
	"~~~....................~~~~~~....##..#####..##....####..#~~~",
	"~~~....................~~~~~~.....#####.....##.#...##..##~~~",
	"~~~....................~~~~~~......##.....###..##......##~~~",
	"~~~...........###^^^#..~~~~~~..........##.......#####.###~~~",
	"~~~............#####...~~~~~~..###########^^^.....#...##.~~~",
	"~~~....................~~~~~~...######..#########.#^^##..~~~",
	"~~~..####..............~~~~~~..............####.#######..~~~",
	"~~~...##...............~~~~~~...............##.....##....~~~",
	"~~~....................~~~~~~............................~~~",
	"~~~....................~~~~~~............................~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]

const SKY: int = 0
const AIR: int = 1
const ROCK: int = 2
const THORN: int = 3
## How many rows each drawn band is, top down, the rows of open
## sky over and under its clusters, and how many clusters it holds.
const BANDS: Array[int] = [20, 16, 18]
const BAND_SKY: int = 2
const CLUSTERS: int = 5
## The columns of open sky at each end of a band and between its clusters, and of bare air between
## a cluster's two halves.
const GAP: int = 8
const SEAM: int = 3
## How wide a half with no hull is (from, to), and how many columns of islands a hull's half may
## have beside its hull, at most.
const HALF_WIDE: Vector2i = Vector2i(10, 14)
const BESIDE: int = 6
## The share of halves that hold a hull.
const HULL_SHARE: float = 0.25
## How wide an island with a third row is: five or six cells, its third row one or two.
const DEEP: Array[int] = [5, 6]
## The share of islands five cells wide or more that a column of cloud rises from.
const COLUMNS: float = 0.2
## The share of tops seven cells or wider with a tuft of thorns at one end, and of islands with a
## thorn hanging under their belly.
const TUFTS: float = 0.3
const HANGING: float = 0.2
## The hulls, cell by cell: # rock, ^ thorns, . air.
const HULLS: Array = [
	# Two chambers under one top: a hole down into the left one, a doorway under a lintel between
	# them, a bed of thorns and a window in the right one, and a keel.
	[
		"####..##########",
		".###..#########.",
		".##....##....##.",
		".##.............",
		".##......^^.....",
		".##############.",
		"...##########...",
		".......##.......",
		".......^^.......",
	],
	# One long chamber: a window at its left end, a bed of thorns, and a hole through its floor.
	[
		"##############",
		".############.",
		".##........##.",
		"...........##.",
		"......^^...##.",
		".#######..###.",
		"...#####..#...",
	],
	# Two storeys: a hole through the floor between them, a window and a bed of thorns below.
	[
		"############",
		".##########.",
		".##......##.",
		".##......##.",
		".####..####.",
		".........##.",
		"...^^....##.",
		".##########.",
		"...######...",
	],
]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _initialize() -> void:
	match SampleSheet.asked():
		&"fold":
			SampleSheet.fold(PATH, get_script() as Script)
		&"redraw":
			SampleSheet.save(_redraw(), PATH)
		_:
			SampleSheet.draw(SHEET, PATH)
	quit()


## A sheet drawn afresh by the rules (see the class description).
func _redraw() -> Image:
	rng.seed = 2626
	# Each band as its columns, left to right; then the sheet as wide as the widest.
	var bands: Array = []
	var wide: int = 0
	for high: int in BANDS:
		var columns: Array = []
		for k: int in range(GAP):
			columns.append(_column(high, SKY))
		for c: int in range(CLUSTERS):
			for side: int in range(2):
				var hull: int = rng.randi_range(0, HULLS.size() - 1) if rng.randf() < HULL_SHARE else -1
				var half: Array = _half(high - 2 * BAND_SKY, hull)
				for column: Array in half:
					columns.append(_boxed(column, high))
				if side == 0:
					for k: int in range(SEAM):
						columns.append(_boxed(_column(high - 2 * BAND_SKY, AIR), high))
			for k: int in range(GAP):
				columns.append(_column(high, SKY))
		bands.append(columns)
		wide = maxi(wide, columns.size())
	var total: int = 0
	for high: int in BANDS:
		total += high
	var img: Image = Image.create(wide, total, false, Image.FORMAT_RGBA8)
	var top: int = 0
	for b: int in range(BANDS.size()):
		for y: int in range(BANDS[b]):
			for x: int in range(wide):
				var c: int = bands[b][x][y] if x < (bands[b] as Array).size() else SKY
				img.set_pixel(x, top + y, [LevelGen.SKY, Color.WHITE, Color.BLACK, Color.RED][c])
		top += BANDS[b]
	return img


## A column `high` cells of `fill`.
func _column(high: int, fill: int) -> Array:
	var column: Array = []
	column.resize(high)
	column.fill(fill)
	return column


## A cluster's column set in its band `high` rows: BAND_SKY rows of open sky over and under it.
func _boxed(column: Array, high: int) -> Array:
	var out: Array = _column(high, SKY)
	for y: int in range(column.size()):
		out[BAND_SKY + y] = column[y]
	return out


## Half a cluster `high` rows, as its columns: islands packed in, and hull `hull` of HULLS among them
## (-1 for none). Drawn again until it has no two bare columns side by side, then cut to what it
## holds, so it begins and ends on a column with something in it (see the class description).
func _half(high: int, hull: int) -> Array:
	for attempt: int in range(400):
		var wide: int = rng.randi_range(HALF_WIDE.x, HALF_WIDE.y)
		var boxes: Array[Rect2i] = []
		var grid: Array = []
		if hull >= 0:
			var art: Array = HULLS[hull]
			var hull_wide: int = (art[0] as String).length()
			wide = hull_wide + rng.randi_range(0, BESIDE)
			# As low as it fits, so a row of islands may stand over it; at either end of the half.
			var at: Vector2i = Vector2i(0 if rng.randf() < 0.5 else wide - hull_wide, high - art.size() - rng.randi_range(0, 1))
			for x: int in range(wide):
				grid.append(_column(high, AIR))
			for y: int in range(art.size()):
				for x: int in range(hull_wide):
					grid[at.x + x][at.y + y] = ".#^".find((art[y] as String)[x]) + AIR
			boxes.append(Rect2i(at, Vector2i(hull_wide, art.size())))
		else:
			for x: int in range(wide):
				grid.append(_column(high, AIR))
		_islands(grid, boxes, high)
		var bare: Array[bool] = []
		for column: Array in grid:
			bare.append(column.all(func(c: int) -> bool: return c == AIR))
		while not bare.is_empty() and bare[0]:
			bare.pop_front()
			grid.pop_front()
		while not bare.is_empty() and bare[-1]:
			bare.pop_back()
			grid.pop_back()
		var paired: bool = false
		for x: int in range(1, bare.size()):
			paired = paired or (bare[x] and bare[x - 1])
		if not paired and grid.size() >= HALF_WIDE.x - 2:
			return grid
	push_error("no half of a cluster could be drawn")
	return [_column(high, ROCK)]


## Islands laid in `grid` (a half `high` rows) as many as fit round what is there (`boxes`): each
## with two cells of air either side and three rows clear over and under it. Then their columns of
## cloud and their thorns.
func _islands(grid: Array, boxes: Array[Rect2i], high: int) -> void:
	var wide: int = grid.size()
	var laid: Array[Rect2i] = []
	for attempt: int in range(600):
		var w: int = rng.randi_range(4, 9)
		# A third row only where it is one or two cells wide (see the class description).
		var h: int = 3 if w in DEEP else 2
		if w > wide or high - h - 1 < 3:
			continue
		var at: Vector2i = Vector2i(rng.randi_range(0, wide - w), rng.randi_range(3, high - h - 1))
		var island: Rect2i = Rect2i(at, Vector2i(w, h))
		var keep: Rect2i = Rect2i(island.position - Vector2i(2, 3), island.size + Vector2i(4, 6))
		if boxes.any(func(b: Rect2i) -> bool: return keep.intersects(b)) or laid.any(func(b: Rect2i) -> bool: return keep.intersects(b)):
			continue
		laid.append(island)
		for d: int in range(h):
			for x: int in range(at.x + d, at.x + w - d):
				grid[x][at.y + d] = ROCK
	for island: Rect2i in laid:
		var at: Vector2i = island.position
		var w: int = island.size.x
		# A column of cloud two cells high, away from the ends.
		if w >= 5 and rng.randf() < COLUMNS:
			var cx: int = at.x + rng.randi_range(2, w - 3)
			grid[cx][at.y - 1] = ROCK
			grid[cx][at.y - 2] = ROCK
		# A tuft of thorns at one end of a long top.
		elif w >= 7 and rng.randf() < TUFTS:
			var left: bool = rng.randf() < 0.5
			for k: int in range(1 if w == 7 else 2):
				grid[at.x + k if left else at.x + w - 1 - k][at.y - 1] = THORN
		# A thorn hanging under its belly.
		if rng.randf() < HANGING:
			@warning_ignore("integer_division")
			grid[at.x + w / 2][at.y + island.size.y] = THORN
