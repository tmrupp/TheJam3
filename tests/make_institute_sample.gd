extends SceneTree
## Draws the WFC sample for institute levels (wfc_images/institute.png): a sunken institute of
## rooms and corridors dug into the earth. Storeys of rooms three rows high run across the sheet,
## with floors of rock two rows thick between them; walls a cell or two thick part the rooms, most
## with a doorway two rows high at the floor, some solid. Here and there a room rises through two
## storeys (a tall hall), a floor has a stair hole two cells wide with a step under it, and a
## stair of steps a row high climbs from one storey to the next. One corner is bare earth, tunnelled
## by a winding passage, so the levels are not all building. Collapsed with no symmetry
## (NextWorldDef.symmetry), so up stays up and floors stay flat. White is open, black rock.
## godot --headless --path . --script res://tests/make_institute_sample.gd

const W: int = 40
const H: int = 32
const OPEN: int = 0
const ROCK: int = 1
## The open rows of each storey (top, bottom): three rows, two rows of floor between.
const STOREYS: Array[Vector2i] = [Vector2i(1, 3), Vector2i(6, 8), Vector2i(11, 13), Vector2i(16, 18), Vector2i(21, 23), Vector2i(26, 28)]

var grid: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 5151
	for x: int in range(W):
		var col: Array = []
		col.resize(H)
		col.fill(ROCK)
		grid.append(col)
	for i: int in range(STOREYS.size()):
		_storey(i)
	# Tall halls: a room open through two storeys, the floor between gone.
	_tall(4, 11, 1)
	_tall(24, 31, 3)
	# Stair holes, each with a step a row under it on one side.
	_hole(17, 3, true)
	_hole(30, 8, false)
	_hole(9, 18, false)
	_hole(33, 23, true)
	_hole(14, 13, true)
	# Stairs a row high up from one storey into the next.
	_stair(20, 1, 1)
	_stair(6, 3, -1)
	_earth(Rect2i(0, 19, 12, 13))
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
	img.save_png(ProjectSettings.globalize_path("res://wfc_images/institute.png"))
	quit()


func _at(x: int, y: int) -> int:
	return grid[x][y] if x >= 0 and y >= 0 and x < W and y < H else ROCK


func _put(x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		grid[x][y] = c


## Storey `i`: its rows opened across the sheet, then parted into rooms by walls a cell or two thick
## every five to nine cells, most with a doorway two rows high at the floor.
func _storey(i: int) -> void:
	var rows: Vector2i = STOREYS[i]
	for x: int in range(1, W - 1):
		for y: int in range(rows.x, rows.y + 1):
			_put(x, y, OPEN)
	var x: int = rng.randi_range(3, 7)
	while x < W - 3:
		var thick: int = 1 if rng.randf() < 0.6 else 2
		var door: bool = rng.randf() < 0.75
		for k: int in range(thick):
			for y: int in range(rows.x, rows.y + 1):
				if door and y >= rows.y - 1:
					continue
				_put(x + k, y, ROCK)
		x += thick + rng.randi_range(5, 9)


## A tall hall: columns `a` to `b` open through storey `top` and the one under it.
func _tall(a: int, b: int, top: int) -> void:
	for x: int in range(a, b + 1):
		for y: int in range(STOREYS[top].x, STOREYS[top + 1].y + 1):
			_put(x, y, OPEN)


## A stair hole two cells wide at column `x` through the floor under the storey whose bottom row is
## `bottom`, with a step a cell long under it in the top row of the storey below (to the left of it
## if `left`, else to the right), so it is climbed in two hops.
func _hole(x: int, bottom: int, left: bool) -> void:
	for y: int in [bottom + 1, bottom + 2]:
		_put(x, y, OPEN)
		_put(x + 1, y, OPEN)
	var below: int = bottom + 3
	_put(x - 1 if left else x + 2, below, ROCK)


## A stair of steps a row high, each two cells deep, from the floor of storey `from` (at column `x`)
## up through its floor into the storey over it, rising the way `dir` points.
func _stair(x: int, from: int, dir: int) -> void:
	var floor_y: int = STOREYS[from].y
	var top: int = STOREYS[from - 1].y
	var y: int = floor_y
	var cx: int = x
	while y > top:
		for k: int in range(2):
			_put(cx + k * dir, y, ROCK)
			for up: int in range(1, 3):
				_put(cx + k * dir, y - up, OPEN)
		y -= 1
		cx += 2 * dir


## Bare earth over `r`: rock, with a winding passage two rows high tunnelled through it.
func _earth(r: Rect2i) -> void:
	for x: int in range(r.position.x, r.end.x):
		for y: int in range(r.position.y, r.end.y):
			_put(x, y, ROCK)
	var y: int = r.position.y + 3
	for x: int in range(r.position.x + 1, r.end.x + 1):
		if rng.randf() < 0.3:
			y = clampi(y + (1 if rng.randf() < 0.5 else -1), r.position.y + 2, r.end.y - 3)
		_put(x, y, OPEN)
		_put(x, y - 1, OPEN)
	# A cave opening off it.
	for x: int in range(r.position.x + 2, r.position.x + 7):
		for yy: int in range(r.end.y - 6, r.end.y - 3):
			_put(x, yy, OPEN)
	for yy: int in range(y, r.end.y - 3):
		_put(r.position.x + 4, yy, OPEN)
		_put(r.position.x + 5, yy, OPEN)
