extends SceneTree
## Draws the WFC sample for cemetery levels (wfc_images/graveyard.png): a hillside graveyard of
## stacked terraces. Each terrace is a band of rock whose top rolls up and down a cell at a time,
## dotted with grave mounds (single cells) and small mausoleums (blocks two or three wide), broken
## by drops down to the terrace below, some of them open graves with thorns at the bottom. Plenty
## of headroom between terraces, and only a little rock hanging from above. Collapsed with no
## symmetry (NextWorldDef.symmetry), so up stays up. White is open, black rock, red thorns.
## godot --headless --path . --script res://tests/make_graveyard_sample.gd

const N: int = 32
const OPEN: int = 0
const ROCK: int = 1
const THORN: int = 2
## Where each terrace's surface starts (its top open row is the one above).
const TERRACES: Array[int] = [10, 19, 28]

var grid: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 1313
	for x: int in range(N):
		var col: Array = []
		col.resize(N)
		col.fill(OPEN)
		grid.append(col)
	# A rock ceiling with a few hanging lumps, and solid ground under the last terrace.
	for x: int in range(N):
		grid[x][0] = ROCK
		grid[x][1] = ROCK
		if rng.randf() < 0.25:
			grid[x][2] = ROCK
	for i: int in range(TERRACES.size()):
		_terrace(TERRACES[i], i == TERRACES.size() - 1)
	var img: Image = Image.create(N, N, false, Image.FORMAT_RGBA8)
	var counts: Array[int] = [0, 0, 0]
	for y: int in range(N):
		var line: String = ""
		for x: int in range(N):
			var c: int = grid[x][y]
			img.set_pixel(x, y, [Color.WHITE, Color.BLACK, Color.RED][c])
			line += ".#^"[c]
			counts[c] += 1
		print(line)
	print("open %d, rock %d, thorns %d" % counts)
	img.save_png(ProjectSettings.globalize_path("res://wfc_images/graveyard.png"))
	quit()


func _at(x: int, y: int) -> int:
	return grid[x][y] if x >= 0 and y >= 0 and x < N and y < N else ROCK


## One terrace: a hillside that runs the whole width, its surface stepping up or down a cell
## (now and then two) every few cells. On it, grave mounds (single cells) and mausoleums (blocks two
## or three wide, two high); dug into it, open graves (a pit two wide, thorns at the bottom); and
## one drop through it, two cells wide, down to the terrace below (none in the last).
func _terrace(top: int, last: bool) -> void:
	var y: int = top
	var drop_at: int = -1 if last else rng.randi_range(6, N - 8)
	var x: int = 0
	var since: int = 0
	while x < N:
		if x == drop_at:
			x += 2
			since = 0
			continue
		var depth: int = 3 if not last else N - y
		for d: int in range(depth):
			if y + d < N:
				grid[x][y + d] = ROCK
		since += 1
		var r: float = rng.randf()
		if since > 2 and x < N - 4 and x + 3 != drop_at and x + 2 != drop_at and x + 1 != drop_at:
			if r < 0.12:
				# An open grave: a pit two wide and two deep, thorns at its bottom.
				for gx: int in range(x + 1, x + 3):
					for d: int in range(depth):
						if y + d < N:
							grid[gx][y + d] = ROCK
					grid[gx][y] = OPEN
					grid[gx][y + 1] = THORN
				x += 3
				since = 0
				continue
			elif r < 0.22:
				# A mausoleum, two or three wide and two high.
				var w: int = rng.randi_range(2, 3)
				for mx: int in range(x, mini(N, x + w)):
					for d: int in range(depth):
						if y + d < N:
							grid[mx][y + d] = ROCK
					grid[mx][y - 1] = ROCK
					grid[mx][y - 2] = ROCK
				x += w
				since = 0
				continue
			elif r < 0.45:
				# A grave mound.
				grid[x][y - 1] = ROCK
		x += 1
		if rng.randf() < 0.3:
			var step: int = 2 if rng.randf() < 0.2 else 1
			y = clampi(y + (step if rng.randf() < 0.5 else -step), top - 2, top + 2)
