extends SceneTree
## Draws the WFC sample for crag levels (wfc_images/crags.png): tall cliffs with castle ruins on
## them. Pillars of rock run up the sheet, their faces long and straight, stepping in or out a cell
## now and then, with shafts of open air between them four to six cells wide. Narrow ledges jut from the faces into
## the shafts, from one side and then the other a few rows apart, so a shaft is climbed in a zigzag;
## a pillar now and then breaks off for a few rows, or bulges out over the shaft below (an
## overhang). Chimneys (shafts two wide) run up inside the widest pillars, and passages one cell
## high run through the pillars from shaft to shaft (where doors and switch gates fit). Some of it
## is built: a keep, a block of masonry with flat walls and a flat roof, holding two halls one over
## the other (a stair gap between them) with doorways through its walls, and a squat tower on a
## pillar's top. A few thorns sit on ledges. Taller than wide, as its levels are, and collapsed
## with no symmetry (NextWorldDef.symmetry), so up stays up. White is open, black rock, red thorns.
## godot --headless --path . --script res://tests/make_crags_sample.gd

const W: int = 32
const H: int = 40
const OPEN: int = 0
const ROCK: int = 1
const THORN: int = 2
## Each pillar: its left and right columns at the top of the sheet.
const PILLARS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(9, 12), Vector2i(20, 22), Vector2i(30, 31)]
## The keep's walls (outer box) and the squat tower's.
const KEEP: Rect2i = Rect2i(16, 25, 12, 8)
const TOWER: Rect2i = Rect2i(10, 3, 5, 4)

var grid: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 4141
	for x: int in range(W):
		var col: Array = []
		col.resize(H)
		col.fill(OPEN)
		grid.append(col)
	for p: Vector2i in PILLARS:
		_pillar(p.x, p.y)
	_chimney(10, 9, 19)
	_passage(14, 8, 14)
	_passage(8, 20, 24)
	_ledges()
	_keep(KEEP)
	_tower(TOWER)
	# Solid ground along the bottom, stepping up and down.
	var top: int = H - 2
	for x: int in range(W):
		if rng.randf() < 0.25:
			top = clampi(top + (1 if rng.randf() < 0.5 else -1), H - 3, H - 1)
		for y: int in range(top, H):
			grid[x][y] = ROCK
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var counts: Array[int] = [0, 0, 0]
	for y: int in range(H):
		var line: String = ""
		for x: int in range(W):
			var c: int = grid[x][y]
			img.set_pixel(x, y, [Color.WHITE, Color.BLACK, Color.RED][c])
			line += ".#^"[c]
			counts[c] += 1
		print(line)
	print("open %d, rock %d, thorns %d" % counts)
	img.save_png(ProjectSettings.globalize_path("res://wfc_images/crags.png"))
	quit()


func _at(x: int, y: int) -> int:
	return grid[x][y] if x >= 0 and y >= 0 and x < W and y < H else ROCK


func _put(x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		grid[x][y] = c


## A pillar from `left` to `right` (columns) down the whole sheet, its faces running straight for six
## to ten rows at a time and then stepping in or out a cell (never narrower than two), now and then broken off for three rows, or
## bulging a cell out over the shaft below for a few rows (an overhang).
func _pillar(left: int, right: int) -> void:
	var a: int = left
	var b: int = right
	var y: int = 0
	while y < H:
		var run: int = rng.randi_range(6, 10)
		var r: float = rng.randf()
		if r < 0.12 and y > 4 and y < H - 8 and b - a < 6:
			# Broken off: a gap of open air across it.
			y += 3
			continue
		var bulge: int = 1 if r > 0.85 else 0
		for d: int in range(run):
			for x: int in range(a - bulge, b + bulge + 1):
				_put(x, y + d, ROCK)
		y += run
		if left > 0:
			a = clampi(a + rng.randi_range(-1, 1), left - 1, left + 1)
		if right < W - 1:
			b = clampi(b + rng.randi_range(-1, 1), right - 1, right + 1)
		if b - a < 2:
			b = a + 2


## A chimney: a shaft two cells wide inside a pillar, from row `from` to `to`, with a ledge across
## half of it midway.
func _chimney(x: int, from: int, to: int) -> void:
	for y: int in range(from, to + 1):
		_put(x, y, OPEN)
		_put(x + 1, y, OPEN)
	_put(x, (from + to) / 2, ROCK)


## A passage one cell high through a pillar at row `y`, from column `a` to `b` (the shafts either
## side), with rock kept above and below it where the pillar is.
func _passage(y: int, a: int, b: int) -> void:
	for x: int in range(a, b + 1):
		_put(x, y - 1, ROCK)
		_put(x, y + 1, ROCK)
		_put(x, y, OPEN)


## Ledges into every shaft: every LEDGE_EVERY rows, from one face and then the other (so a shaft is
## climbed in a zigzag), two or three cells long, a cell thick, with open air over and under them;
## a few carry a thorn at their tip.
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
			var left: bool = (y / LEDGE_EVERY + n) % 2 == 0
			for k: int in range(long):
				var lx: int = from + k if left else x - 1 - k
				if _at(lx, y - 1) == OPEN and _at(lx, y + 1) == OPEN:
					_put(lx, y, ROCK)
			if rng.randf() < 0.25:
				var tip: int = from + long - 1 if left else x - long
				if _at(tip, y) == ROCK:
					_put(tip, y - 1, THORN)


## The keep: a block of masonry, its walls a cell thick, two halls one over the other (two rows
## high each, a floor between with a stair gap at one end), doorways one cell high through both
## walls into each hall, and a flat roof.
func _keep(r: Rect2i) -> void:
	for x: int in range(r.position.x, r.end.x):
		for y: int in range(r.position.y, r.end.y):
			_put(x, y, ROCK)
	var hall: Array[int] = [r.position.y + 1, r.position.y + 4]
	for top: int in hall:
		for x: int in range(r.position.x + 1, r.end.x - 1):
			_put(x, top, OPEN)
			_put(x, top + 1, OPEN)
		# Doorways through each wall, at the hall's floor.
		_put(r.position.x, top + 1, OPEN)
		_put(r.end.x - 1, top + 1, OPEN)
	# The stair gap in the floor between the halls.
	for x: int in range(r.end.x - 4, r.end.x - 2):
		_put(x, hall[0] + 2, OPEN)
	# Open air round it, so its walls stand clear.
	for y: int in range(r.position.y - 2, r.end.y):
		_put(r.position.x - 1, y, OPEN if y < r.end.y - 2 else _at(r.position.x - 1, y))
		_put(r.end.x, y, OPEN if y < r.end.y - 2 else _at(r.end.x, y))
	for x: int in range(r.position.x - 1, r.end.x + 1):
		_put(x, r.position.y - 1, OPEN)
		_put(x, r.position.y - 2, OPEN)


## A squat tower on a pillar's top: a block of masonry with a room in it and a doorway out.
func _tower(r: Rect2i) -> void:
	for x: int in range(r.position.x, r.end.x):
		for y: int in range(r.position.y, r.end.y):
			_put(x, y, ROCK)
		_put(x, r.position.y - 1, OPEN)
		_put(x, r.position.y - 2, OPEN)
	for x: int in range(r.position.x + 1, r.end.x - 1):
		_put(x, r.position.y + 1, OPEN)
		_put(x, r.position.y + 2, OPEN)
	_put(r.position.x, r.position.y + 2, OPEN)
