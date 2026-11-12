extends SceneTree
## The WFC sample for crag levels (wfc_images/crags.png): tall cliffs, bare of anything built (the
## keeps and towers are the structure pass's, CragsArchetype.shape; drawn in the sample, the
## collapse only scattered their walls and floors about as stray lines of rock). The sheet is
## painted by hand in the generation lab and kept here as text (SHEET, see SampleSheet): run this
## with "fold" after painting, to write the picture into SHEET; with nothing, to draw the picture
## from SHEET; with "redraw", to draw it afresh by the rules below, as it was first drawn, over
## whatever was painted.
##
## As first drawn (_redraw): pillars of rock run up the sheet, their faces long and straight,
## stepping in or out a cell now and then, with shafts of open air between them five to seven cells
## wide. Narrow ledges jut from the faces into the shafts, from one side and then the other a few
## rows apart, so a shaft is climbed in a zigzag; a pillar now and then breaks off for a few rows,
## or bulges out over the shaft below (an overhang). A chimney (a shaft two wide) runs most of the
## way up inside the widest pillar, its walls two cells thick or so (a wide pillar left solid
## collapses into great masses of rock), and passages one cell high run through the pillars from
## shaft to shaft (where doors and switch gates fit). Thorns grow all over it: at the tips of
## ledges (LEDGE_THORNS of them), under their roots (ROOT_THORNS), up the face across the shaft
## from a ledge in runs of two or three (FACE_THORNS), as in the cemetery's bone well, and in beds
## on the ground at the foot of each shaft. Every thorn touches rock.
## As painted since: thorns up the chimney's walls, longer beds along the ground, the top of the
## widest pillar opened, and an opening through it lower down.
## Taller than wide, as its levels are, and collapsed with no symmetry (NextWorldDef.symmetry), so
## up stays up. White is open, black rock, red thorns.
## godot --headless --path . --script res://tests/make_crags_sample.gd [-- fold | -- redraw]

## The picture it draws.
const PATH: String = "res://wfc_images/crags.png"
## The sheet, a row a line: . open, # rock, ^ thorns (SampleSheet.INKS).
const SHEET: PackedStringArray = [
	"##.....########......##.......##",
	"##.....#####.##......##^......##",
	"##.....####..##..^...##^......##",
	"##...######.######...##^...#####",
	"##....^###..###^.....##.......##",
	"##....^###..###^.....##.......##",
	"##....^###..###^.....##..^...^##",
	"####..^###..###^..########...^##",
	"##.....###..###.....^##.......##",
	"##.....####.###.....###.......##",
	"........##..##^.....###.......##",
	"........##..##^..#########....##",
	"............##......###^......##",
	"##.....^######......###.......##",
	"##...............^..###..^.....#",
	"#####..^###.##^..#########....##",
	"##^....###..###....^###.......##",
	"##.....###..^##.....##........##",
	"##^..^.###..^##.^...##^....^...#",
	"##^..#####..^####...##^....#####",
	"##.....###..###.....##........##",
	"##.....####.###^....##.......^##",
	"##....^###..###^....##.......^##",
	"####..^###..###^..#######....^##",
	"##.....###..###....^##........##",
	"##.....###..###^....###.......##",
	"##.....###..###^..^...........##",
	".......###.####^..########....##",
	".......###..###....^##.^......##",
	".......###..###.....##........##",
	"##^^...###^.###..^..##..^....^##",
	"#####..^##^.##^..########....^##",
	"##......##^.##......##........##",
	"##......##..##......###^......##",
	"##^..^..##..........###^......##",
	"##^..############...###^...#####",
	"##......######^.....###.......##",
	"##......######^^^^^^###.^^^^^^##",
	"####^^^#########################",
	"################################",
]

const W: int = 32
const H: int = 40
const OPEN: int = 0
const ROCK: int = 1
const THORN: int = 2
## Each pillar: its left and right columns at the top of the sheet.
const PILLARS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(8, 13), Vector2i(21, 22), Vector2i(30, 31)]
## Which of them the chimney runs up inside: its faces never step, so the chimney's walls are two
## cells thick all the way (a wall a cell thick reads as built, not as cliff, and thicker ones
## collapse into masses of rock).
const HOLLOW: int = 1
## The share of ledges with a thorn at their tip, with one hanging under their root, and with a run
## of thorns up the face across the shaft from them.
const LEDGE_THORNS: float = 0.45
const ROOT_THORNS: float = 0.25
const FACE_THORNS: float = 0.65
## How long a bed of thorns on the ground at the foot of a shaft is (from, to).
const BED: Vector2i = Vector2i(2, 3)

var grid: Array = []
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


## The sheet drawn afresh by the rules (see the class description).
func _redraw() -> Image:
	rng.seed = 4141
	for x: int in range(W):
		var col: Array = []
		col.resize(H)
		col.fill(OPEN)
		grid.append(col)
	for p: Vector2i in PILLARS:
		_pillar(p.x, p.y, p == PILLARS[HOLLOW])
	_chimney(10, 4, 34)
	_passage(14, 8, 13)
	_passage(26, 20, 22)
	_ledges()
	# Solid ground along the bottom, stepping up and down.
	var top: int = H - 2
	for x: int in range(W):
		if rng.randf() < 0.25:
			top = clampi(top + (1 if rng.randf() < 0.5 else -1), H - 2, H - 1)
		for y: int in range(top, H):
			grid[x][y] = ROCK
	_beds()
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y: int in range(H):
		for x: int in range(W):
			img.set_pixel(x, y, [Color.WHITE, Color.BLACK, Color.RED][grid[x][y]])
	return img


func _at(x: int, y: int) -> int:
	return grid[x][y] if x >= 0 and y >= 0 and x < W and y < H else ROCK


func _put(x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		grid[x][y] = c


## A pillar from `left` to `right` (columns) down the whole sheet, its faces running straight for six
## to ten rows at a time and then stepping in or out a cell (never narrower than two; a `hollow`
## one keeps its width and is never broken), now and then broken off for three rows, or bulging a
## cell out over the shaft below for a few rows (an overhang).
func _pillar(left: int, right: int, hollow: bool) -> void:
	var a: int = left
	var b: int = right
	var y: int = 0
	while y < H:
		var run: int = rng.randi_range(6, 10)
		var r: float = rng.randf()
		if r < 0.12 and y > 4 and y < H - 8 and not hollow:
			# Broken off: a gap of open air across it.
			y += 3
			continue
		var bulge: int = 1 if r > 0.85 else 0
		for d: int in range(run):
			for x: int in range(a - bulge, b + bulge + 1):
				_put(x, y + d, ROCK)
		y += run
		if hollow:
			continue
		if left > 0:
			a = clampi(a + rng.randi_range(-1, 1), left - 1, left + 1 if right < W - 1 else left)
		if right < W - 1:
			b = clampi(b + rng.randi_range(-1, 1), right - 1, right + 1)
		if b - a < 1:
			b = a + 1


## A chimney: a shaft two cells wide inside a pillar, from row `from` to `to`, with a ledge across
## half of it every CHIMNEY_LEDGE rows, from one side and then the other.
const CHIMNEY_LEDGE: int = 6

func _chimney(x: int, from: int, to: int) -> void:
	for y: int in range(from, to + 1):
		_put(x, y, OPEN)
		_put(x + 1, y, OPEN)
	var side: int = 0
	for y: int in range(from + CHIMNEY_LEDGE - 1, to - 1, CHIMNEY_LEDGE):
		_put(x + side, y, ROCK)
		side = 1 - side


## A passage one cell high through a pillar at row `y`, from column `a` to `b` (the pillar's own
## columns), with rock kept above and below it.
func _passage(y: int, a: int, b: int) -> void:
	for x: int in range(a, b + 1):
		_put(x, y - 1, ROCK)
		_put(x, y + 1, ROCK)
		_put(x, y, OPEN)


## Ledges into every shaft: every LEDGE_EVERY rows, from one face and then the other (so a shaft is
## climbed in a zigzag), two or three cells long, a cell thick, with open air over and under them.
## Then each ledge's thorns: at its tip, hanging under its root, and up the face across the shaft
## from it (a run of two or three, from the ledge's own row up), each by its share.
const LEDGE_EVERY: int = 4

func _ledges() -> void:
	for y: int in range(3, H - 4, LEDGE_EVERY):
		var x: int = 0
		var n: int = 0
		while x < W:
			if _at(x, y) != OPEN:
				x += 1
				continue
			var from: int = x
			while x < W and _at(x, y) == OPEN:
				x += 1
			var wide: int = x - from
			if wide < 4 or from == 0 or x >= W:
				continue
			n += 1
			var long: int = 2 if wide < 6 else 3
			@warning_ignore("integer_division")
			var left: bool = (y / LEDGE_EVERY + n) % 2 == 0
			var laid: int = 0
			for k: int in range(long):
				var lx: int = from + k if left else x - 1 - k
				if _at(lx, y - 1) == OPEN and _at(lx, y + 1) == OPEN:
					_put(lx, y, ROCK)
					laid += 1
			if laid < long:
				continue
			var tip: int = from + long - 1 if left else x - long
			var root: int = from if left else x - 1
			if rng.randf() < LEDGE_THORNS:
				_put(tip, y - 1, THORN)
			if rng.randf() < ROOT_THORNS:
				_put(root, y + 1, THORN)
			if rng.randf() < FACE_THORNS:
				var fx: int = x - 1 if left else from
				var wall: int = x if left else from - 1
				for d: int in range(rng.randi_range(2, 3)):
					if _at(fx, y - d) == OPEN and _at(wall, y - d) == ROCK:
						_put(fx, y - d, THORN)


## A bed of thorns on the ground at the foot of every shaft: BED cells of them side by side on the
## ground's top, clear of the faces either side.
func _beds() -> void:
	var x: int = 0
	while x < W:
		var y: int = H - 1
		while y > 0 and _at(x, y) == ROCK:
			y -= 1
		if y < H - 6:
			# A pillar's column: no ground to bed.
			x += 1
			continue
		var from: int = x
		while x < W and _at(x, y) == OPEN and _at(x, y + 1) == ROCK:
			x += 1
		if x - from >= BED.y + 2:
			var long: int = rng.randi_range(BED.x, BED.y)
			var at: int = from + rng.randi_range(1, x - from - long - 1)
			for k: int in range(long):
				if _at(at + k, y) == OPEN and _at(at + k, y + 1) == ROCK:
					_put(at + k, y, THORN)
		x = maxi(x, from + 1)
