extends SceneTree
## Draws the WFC sample the insides of the cemetery's crypts are collapsed from
## (wfc_images/crypt.png, Crypts): four levels of ossuary rooms five rows high, joined by burial
## passages two rows high (their floors a row up for a few cells now and then) or squeezes a row
## high with burial niches (slots a row high, two deep) over their mouths, a hop up from the room's
## floor, and niches at the floor at each level's ends; and stairs a row a step joining the levels,
## two or three between each level and the next. A wide room has ledges of rock to climb, a hop
## (Reach.UP, two rows) over its floor and another over that, and now and then a room is a hall two
## levels high, open through to the level over it, climbed by ledges a hop apart, with a perch near
## its top. So little inside is more than a hop above what it is reached from. Collapsed with no
## symmetry (NextWorldDef.symmetry), so up stays up. White is open, black rock.
## godot --headless --path . --script res://tests/make_crypt_sample.gd

const W: int = 46
const H: int = 25
const OPEN: int = 0
const ROCK: int = 1
## The floor rows of the levels, top first: a slab of rock a row or two thick between one level's
## rooms and the next's.
const FLOORS: Array[int] = [6, 12, 18, 24]
## How wide an ossuary room is (from, to) and how many rows of air it has; how long a passage
## between two rooms is (from, to).
const ROOM_WIDE: Vector2i = Vector2i(4, 9)
const ROOM_HIGH: int = 5
const PASSAGE_LONG: Vector2i = Vector2i(2, 5)
## A room at least LEDGE_ROOM wide has a ledge a hop over its floor, and one at least HIGH_ROOM wide
## another a hop over that; a ledge is LEDGE_WIDE cells (from, to).
const LEDGE_ROOM: int = 6
const HIGH_ROOM: int = 8
const LEDGE_WIDE: Vector2i = Vector2i(2, 3)
## The chance a room under another level is a hall open through to it (at least LEDGE_ROOM wide).
const HALL_SHARE: float = 0.4

var grid: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 4040
	for x: int in range(W):
		var col: Array = []
		col.resize(H)
		col.fill(ROCK)
		grid.append(col)
	for base: int in FLOORS:
		_level(base)
	# Stairs down from each level to the next, two or three, going either way.
	for i: int in range(FLOORS.size() - 1):
		var x: int = rng.randi_range(3, 9)
		while x < W - 8:
			var dir: int = 1 if rng.randf() < 0.5 else -1
			_stairs(x if dir > 0 else x + 5, FLOORS[i], FLOORS[i + 1], dir)
			x += rng.randi_range(11, 16)
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var counts: Array[int] = [0, 0]
	for y: int in range(H):
		var line: String = ""
		for x: int in range(W):
			var c: int = grid[x][y]
			img.set_pixel(x, y, [Color.WHITE, Color.BLACK][c])
			line += ".#"[c]
			counts[c] += 1
		print(line)
	print("open %d, rock %d" % counts)
	img.save_png(ProjectSettings.globalize_path("res://wfc_images/crypt.png"))
	quit()


func _open(x: int, y: int) -> void:
	if x >= 1 and y >= 1 and x < W - 1 and y < H - 1:
		grid[x][y] = OPEN


## One level of the crypt over floor row `base`: ossuary rooms (ROOM_WIDE across, ROOM_HIGH rows of
## air) joined by passages (PASSAGE_LONG cells, two rows high, or a squeeze a row high with a niche
## over each of its mouths, a hop up from the room's floor), the floor of a passage now and then a
## row up for a few cells; and a niche at the floor in the far wall of the first room and the last.
func _level(base: int) -> void:
	var x: int = 1 + rng.randi_range(0, 2)
	var first: bool = true
	while true:
		var wide: int = rng.randi_range(ROOM_WIDE.x, ROOM_WIDE.y)
		if x + wide >= W - 2:
			break
		for k: int in range(wide):
			for d: int in range(1, ROOM_HIGH + 1):
				_open(x + k, base - d)
		if wide >= LEDGE_ROOM and base != FLOORS[0] and rng.randf() < HALL_SHARE:
			_hall(x, wide, base)
		elif wide >= LEDGE_ROOM:
			_ledges(x, wide, base)
		if first:
			_niche(x - 1, base - 1, -1)
			first = false
		x += wide
		var long: int = rng.randi_range(PASSAGE_LONG.x, PASSAGE_LONG.y)
		if x + long + ROOM_WIDE.x >= W - 2:
			_niche(x, base - 1, 1)
			break
		var squeeze: bool = rng.randf() < 0.4
		var lift: int = 1 if not squeeze and rng.randf() < 0.35 else 0
		for k: int in range(long):
			var up: int = lift if k > 0 and k < long - 1 else 0
			for d: int in range(1, (1 if squeeze else 2) + 1):
				_open(x + k, base - d - up)
		if squeeze:
			_niche(x - 1, base - 3, -1)
			_niche(x + long, base - 3, 1)
		x += long


## Ledges in the room `wide` cells across from column `x` over floor row `base`: one a hop over the
## floor at one end, and in a wide room another a hop over that, toward the other end.
func _ledges(x: int, wide: int, base: int) -> void:
	var left: bool = rng.randf() < 0.5
	var long: int = rng.randi_range(LEDGE_WIDE.x, LEDGE_WIDE.y)
	var at: int = x + 1 if left else x + wide - 1 - long
	_slab(at, long, base - 2)
	if wide >= HIGH_ROOM:
		var high: int = rng.randi_range(LEDGE_WIDE.x, LEDGE_WIDE.y)
		_slab(x + wide - 1 - high if left else x + 1, high, base - 4)


## A hall: the room `wide` cells across from column `x` over floor row `base`, open through the
## slab over it to the level above (all but a cell at each side), climbed by a ledge a hop over the
## floor at one side, another a hop over that at the other, from where the floor above is a hop up,
## and a perch in the middle a hop over that.
func _hall(x: int, wide: int, base: int) -> void:
	for k: int in range(1, wide - 1):
		for d: int in range(ROOM_HIGH + 1, 2 * ROOM_HIGH + 2):
			_open(x + k, base - d)
	var left: bool = rng.randf() < 0.5
	var a: int = rng.randi_range(LEDGE_WIDE.x, LEDGE_WIDE.y)
	var b: int = rng.randi_range(LEDGE_WIDE.x, LEDGE_WIDE.y)
	_slab(x + 1 if left else x + wide - 1 - a, a, base - 2)
	_slab(x + wide - 1 - b if left else x + 1, b, base - 4)
	_slab(x + int(float(wide) * 0.5) - 1, 2, base - 8)


## A slab of rock a row thick, `long` cells from column `x`, on row `y`.
func _slab(x: int, long: int, y: int) -> void:
	for k: int in range(long):
		if x + k >= 1 and x + k < W - 1 and y >= 1 and y < H - 1:
			grid[x + k][y] = ROCK


## A niche: a slot a row high and two deep in a wall, on row `y`, cut from column `x` the way `dir`.
func _niche(x: int, y: int, dir: int) -> void:
	for k: int in range(2):
		_open(x + dir * k, y)


## Stairs from the level on floor row `from` down to the one on `to`: a step a row down for each
## cell across, starting at column `x` and going the way `dir`, with three rows of air over each.
func _stairs(x: int, from: int, to: int, dir: int) -> void:
	var at: int = x
	for y: int in range(from, to):
		for d: int in range(0, 3):
			_open(at, y - d)
		at += dir
