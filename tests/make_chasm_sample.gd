extends SceneTree
## Draws the WFC sample for hyperspace (wfc_images/chasm_gauntlet.png): two stacked
## caverns joined by shafts, ceilings hung with teeth, floors broken by thorn-bottomed pits and
## capped with runs of thorns, and floating rock islands. White is open, black rock, red thorns,
## like the other samples, and every thorn touches rock.
## godot --headless --path . --script res://tests/make_chasm_sample.gd

const N: int = 32
const OPEN: int = 0
const ROCK: int = 1
const THORN: int = 2
const SHAFTS: Array[int] = [6, 22]

var grid: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 2024
	for x: int in range(N):
		var col: Array = []
		col.resize(N)
		col.fill(ROCK)
		grid.append(col)
	_cavern(1, 14, true)
	_cavern(17, 30, false)
	for s: int in SHAFTS:
		for x: int in range(s, s + 3):
			grid[x][15] = OPEN
			grid[x][16] = OPEN
	_thorns()
	var img: Image = Image.create(N, N, false, Image.FORMAT_RGBA8)
	var counts: Array[int] = [0, 0, 0]
	var stray: int = 0
	for y: int in range(N):
		var line: String = ""
		for x: int in range(N):
			var c: int = grid[x][y]
			img.set_pixel(x, y, [Color.WHITE, Color.BLACK, Color.RED][c])
			line += ".#^"[c]
			counts[c] += 1
			if c == THORN and not _touches_rock(x, y):
				stray += 1
		print(line)
	print("open %d, rock %d, thorns %d, stray thorns %d" % [counts[0], counts[1], counts[2], stray])
	img.save_png(ProjectSettings.globalize_path("res://wfc_images/chasm_gauntlet.png"))
	quit()


func _at(x: int, y: int) -> int:
	return grid[x][y] if x >= 0 and y >= 0 and x < N and y < N else ROCK


func _touches_rock(x: int, y: int) -> bool:
	return _at(x, y - 1) == ROCK or _at(x, y + 1) == ROCK or _at(x - 1, y) == ROCK or _at(x + 1, y) == ROCK


func _in_shaft(x: int) -> bool:
	for s: int in SHAFTS:
		if x >= s and x < s + 3:
			return true
	return false


## Carve a cavern between rows `top` and `bot`: a wandering ceiling hung with teeth, a floor of
## wandering height broken by pits (the upper cavern's pits include the shafts; the lower one's
## ceiling opens at them), and a few floating islands.
func _cavern(top: int, bot: int, upper: bool) -> void:
	var ceil_d: int = 1
	var floor_h: int = 3
	var pits: Dictionary = {}
	var starts: Array[int] = []
	starts.append(rng.randi_range(13, 18))
	if not upper:
		starts.append(rng.randi_range(2, 4))
	for s: int in starts:
		for x: int in range(s, s + rng.randi_range(3, 5)):
			pits[x] = true
	for x: int in range(N):
		if rng.randf() < 0.5:
			ceil_d = clampi(ceil_d + rng.randi_range(-1, 1), 0, 4)
		if rng.randf() < 0.45:
			floor_h = clampi(floor_h + rng.randi_range(-1, 1), 2, 5)
		var c: int = 0 if (not upper and _in_shaft(x)) else ceil_d
		var deep: bool = (upper and (pits.has(x) or _in_shaft(x))) or (not upper and pits.has(x) and not _in_shaft(x))
		for y: int in range(top + c, bot - (0 if deep else floor_h) + 1):
			grid[x][y] = OPEN
	# Teeth hanging from the ceiling, clear of the shafts.
	for i: int in range(6):
		var x: int = rng.randi_range(1, N - 3)
		var length: int = rng.randi_range(2, 4)
		for dx: int in range(rng.randi_range(1, 2)):
			if _in_shaft(x + dx) or _in_shaft(x + dx - 1) or _in_shaft(x + dx + 1):
				continue
			var y: int = top
			while y < bot and grid[x + dx][y] == ROCK:
				y += 1
			for k: int in range(length):
				if y + k < bot - 5:
					grid[x + dx][y + k] = ROCK
	# Floating islands, with room above and below.
	for i: int in range(4):
		var w: int = rng.randi_range(3, 6)
		var x: int = rng.randi_range(1, N - w - 1)
		var y: int = rng.randi_range(top + 5, bot - 6)
		var clear: bool = true
		for xx: int in range(x - 1, x + w + 1):
			for yy: int in range(y - 3, y + 4):
				clear = clear and _at(xx, yy) == OPEN
		if clear:
			for xx: int in range(x, x + w):
				grid[xx][y] = ROCK
				if rng.randf() < 0.5:
					grid[xx][y + 1] = ROCK


## Runs of thorns on floors and island tops (and always on narrow pit bottoms), single ones hung
## from ceilings and island undersides, and an occasional one on a wall.
func _thorns() -> void:
	var marks: Array[Vector2i] = []
	for y: int in range(N):
		var run: int = 0
		var rest: int = 0
		for x: int in range(N):
			var floor_cell: bool = _at(x, y) == OPEN and _at(x, y + 1) == ROCK
			if run > 0:
				run -= 1
				if floor_cell:
					marks.append(Vector2i(x, y))
				continue
			rest -= 1
			if rest <= 0 and floor_cell and rng.randf() < 0.55:
				run = rng.randi_range(2, 5)
				rest = rng.randi_range(1, 3)
				marks.append(Vector2i(x, y))
			# A pit bottom: rock stands higher beside it.
			elif floor_cell and _at(x, y - 1) == OPEN and (_at(x - 1, y - 1) == ROCK or _at(x + 1, y - 1) == ROCK):
				marks.append(Vector2i(x, y))
	for x: int in range(N):
		var rest_c: int = 0
		for y: int in range(1, N):
			rest_c -= 1
			if _at(x, y) == OPEN and _at(x, y - 1) == ROCK and rest_c <= 0 and rng.randf() < 0.4:
				marks.append(Vector2i(x, y))
				rest_c = 2
	for x: int in range(1, N - 1):
		for y: int in range(1, N - 1):
			if _at(x, y) == OPEN and (_at(x - 1, y) == ROCK or _at(x + 1, y) == ROCK) and rng.randf() < 0.12:
				marks.append(Vector2i(x, y))
	for v: Vector2i in marks:
		grid[v.x][v.y] = THORN
