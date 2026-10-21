extends SceneTree
## Draws the WFC samples the trials in the cemetery's crypts are collapsed from (Crypts.TRIALS),
## each a strip whose rows (or, for the well, columns) the collapse keeps in order, so every trial
## it gives plays by the sample's rules however it is laid out. White is open, black rock, red
## thorns.
## - wfc_images/crypt_pit.png, the ossuary pit: a floor of thorns under a ceiling, crossed on
##   pillars of rock rising out of it, their tops one to three rows over the thorns (the tallest
##   right under the ceiling, so it is left by a dash, not a jump), now and then a stone standing on
##   nothing; never more than two thorns side by side (so no gap the collapse gives is wider), and
##   over some gaps between low pillars a tooth of rock hanging from the ceiling with thorns under
##   it, so that gap is crossed low, by a dash, not over the top.
## - wfc_images/crypt_crawl.png, the thorn crawl: a passage two rows high, thorns hanging from its
##   ceiling in runs and dug into its floor a cell or two wide, now and then a step a row up; never
##   a step under hanging thorns, so it is crossed by running, hopping low and dashing.
## - wfc_images/crypt_well.png, the bone well: a shaft four cells across between walls of rock,
##   climbed by ledges on alternate sides, each two rows over the last, with thorns on the walls
##   between them, on the side away from the ledge under them.
## godot --headless --path . --script res://tests/make_crypt_trials.gd

const OPEN: int = 0
const ROCK: int = 1
const THORN: int = 2
const COLORS: Array[Color] = [Color.WHITE, Color.BLACK, Color.RED]
## How long the pit's and the crawl's strips are, and how tall the well's.
const STRIP: int = 64
const WELL_HIGH: int = 48

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 6600
	_save(_pit(), "res://wfc_images/crypt_pit.png")
	_save(_crawl(), "res://wfc_images/crypt_crawl.png")
	_save(_well(), "res://wfc_images/crypt_well.png")
	quit()


## A grid `wide` by `high` of `fill`.
func _grid(wide: int, high: int, fill: int) -> Array:
	var out: Array = []
	for x: int in range(wide):
		var col: Array = []
		col.resize(high)
		col.fill(fill)
		out.append(col)
	return out


## The pit, seven rows: rock, two rows of air, the rows the pillars' tops stand in (2 to 4), the
## thorns (5) and rock. A pillar is one or two across (a tall one, its top on row 2, under the
## ceiling, always one), its top on row 2, 3 or 4; a gap between is one or two thorns, with a stone on
## row 3 over one of a gap of two now and then; and a gap between two low pillars (tops on row 4) may
## have a tooth of rock hanging over it from the ceiling, thorns under it on row 2, so it is crossed
## low, dashing from pillar to pillar.
func _pit() -> Array:
	var g: Array = _grid(STRIP, 7, OPEN)
	for x: int in range(STRIP):
		g[x][0] = ROCK
		g[x][6] = ROCK
		g[x][5] = THORN
	var x: int = 0
	var low_before: bool = false
	while x < STRIP:
		var roll: float = rng.randf()
		var top: int = 2 if roll < 0.2 else (3 if roll < 0.55 else 4)
		var wide: int = 1 if top == 2 or rng.randf() < 0.65 else 2
		# A tooth over the gap just crossed, when both pillars beside it are low.
		if low_before and top == 4 and rng.randf() < 0.8:
			var k: int = x - 1
			while k >= 0 and g[k][4] != ROCK:
				g[k][1] = ROCK
				g[k][2] = THORN
				k -= 1
		for k: int in range(wide):
			if x + k < STRIP:
				for y: int in range(top, 6):
					g[x + k][y] = ROCK
		x += wide
		var gap: int = 1 if rng.randf() < 0.35 else 2
		if gap == 2 and rng.randf() < 0.25 and x + 1 < STRIP:
			# A stone standing on nothing over one cell of the gap.
			g[x + (1 if rng.randf() < 0.5 else 0)][3] = ROCK
		low_before = top == 4
		x += gap
	return g


## The crawl, five rows: rock, the row thorns hang in (1), the passage (2), its floor (3: rock, a
## thorn or a step's air) and rock.
func _crawl() -> Array:
	var g: Array = _grid(STRIP, 5, OPEN)
	for x: int in range(STRIP):
		g[x][0] = ROCK
		g[x][3] = ROCK
		g[x][4] = ROCK
	# Thorns hanging in runs of one to three, apart.
	var x: int = rng.randi_range(1, 3)
	while x < STRIP:
		var run: int = rng.randi_range(1, 3)
		for k: int in range(run):
			if x + k < STRIP:
				g[x + k][1] = THORN
		x += run + rng.randi_range(1, 3)
	# Thorns dug into the floor, one or two wide, and steps a row up where nothing hangs over them.
	x = rng.randi_range(1, 3)
	while x < STRIP - 2:
		var wide: int = 1 if rng.randf() < 0.5 else 2
		if rng.randf() < 0.3 and g[x][1] == OPEN and g[x + wide - 1][1] == OPEN:
			# A step: rock on the passage's row, a cell or two.
			for k: int in range(wide):
				g[x + k][2] = ROCK
		else:
			for k: int in range(wide):
				g[x + k][3] = THORN
		x += wide + rng.randi_range(2, 4)
	return g


## The well, six cells across: rock walls at 0 and 5, ledges on alternate sides every two rows (one
## or two cells out from the wall), thorns on the wall a row over a ledge, on the other side.
func _well() -> Array:
	var g: Array = _grid(6, WELL_HIGH, OPEN)
	for y: int in range(WELL_HIGH):
		g[0][y] = ROCK
		g[5][y] = ROCK
	var left: bool = true
	for y: int in range(WELL_HIGH - 1, -1, -2):
		var wide: int = 1 if rng.randf() < 0.4 else 2
		for k: int in range(wide):
			g[1 + k if left else 4 - k][y] = ROCK
		# Thorns on the far wall in the row over it, now and then.
		if y - 1 >= 0 and rng.randf() < 0.45:
			g[4 if left else 1][y - 1] = THORN
		left = not left
	return g


func _save(g: Array, path: String) -> void:
	var wide: int = g.size()
	var high: int = (g[0] as Array).size()
	var img: Image = Image.create(wide, high, false, Image.FORMAT_RGBA8)
	for y: int in range(high):
		var line: String = ""
		for x: int in range(wide):
			var c: int = g[x][y]
			img.set_pixel(x, y, COLORS[c])
			line += ".#^"[c]
		print(line)
	print(path)
	img.save_png(ProjectSettings.globalize_path(path))
