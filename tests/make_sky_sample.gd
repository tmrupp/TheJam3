extends SceneTree
## Draws the WFC sample for sky levels (wfc_images/sky_islands.png): islands of cloud packed close,
## two or three cells apart, so a collapse gives dense clusters of them (the level then keeps only
## clusters, with wide gaps of open air between, MapInfo.World.cluster_islands). Each island has a
## flat top four to nine cells wide to stand on and tapers underneath (two or three rows), a cell
## narrower each side per row below the first; now and then a column of cloud rises from it. Three
## rows of headroom over every top, two clear under every island.
## Collapsed with no symmetry (NextWorldDef.symmetry), so up stays up. White is open, black rock.
## godot --headless --path . --script res://tests/make_sky_sample.gd

const N: int = 32
const OPEN: int = 0
const ROCK: int = 1

var grid: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 2626
	for x: int in range(N):
		var col: Array = []
		col.resize(N)
		col.fill(OPEN)
		grid.append(col)
	var boxes: Array[Rect2i] = []
	for attempt: int in range(4000):
		var w: int = rng.randi_range(4, 9)
		var h: int = rng.randi_range(2, 3)
		var at: Vector2i = Vector2i(rng.randi_range(1, N - w - 1), rng.randi_range(3, N - h - 1))
		var box: Rect2i = Rect2i(at, Vector2i(w, h))
		# Two cells of air either side, headroom of three rows and two clear under it.
		var keep: Rect2i = Rect2i(box.position - Vector2i(2, 3), box.size + Vector2i(4, 5))
		if boxes.any(func(b: Rect2i) -> bool: return keep.intersects(b)):
			continue
		boxes.append(box)
		for d: int in range(h):
			for x: int in range(at.x + maxi(0, d - 1), at.x + w - maxi(0, d - 1)):
				grid[x][at.y + d] = ROCK
		# A column of cloud rising from it now and then.
		if w >= 5 and rng.randf() < 0.2:
			var cx: int = at.x + rng.randi_range(1, w - 2)
			for d: int in range(1, 3):
				if at.y - d >= 1:
					grid[cx][at.y - d] = ROCK
	var img: Image = Image.create(N, N, false, Image.FORMAT_RGBA8)
	var rock: int = 0
	for y: int in range(N):
		var line: String = ""
		for x: int in range(N):
			img.set_pixel(x, y, Color.BLACK if grid[x][y] == ROCK else Color.WHITE)
			line += "#" if grid[x][y] == ROCK else "."
			rock += 1 if grid[x][y] == ROCK else 0
		print(line)
	print("islands %d, rock %d of %d" % [boxes.size(), rock, N * N])
	img.save_png(ProjectSettings.globalize_path("res://wfc_images/sky_islands.png"))
	quit()
