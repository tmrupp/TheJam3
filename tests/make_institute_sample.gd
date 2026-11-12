extends SceneTree
## The WFC sample for institute levels (wfc_images/institute.png): the earth the institute is dug
## into, between its halls (the halls of marble are the structure pass's, Institute.build). The
## sheet is painted by hand in the generation lab and kept here as text (SHEET, see SampleSheet):
## run this with "fold" after painting, to write the picture into SHEET; with nothing, to draw the
## picture from SHEET; with "redraw", to draw it afresh by the rules below, as it was first drawn,
## over whatever was painted.
##
## The collapse sees three cells at a time, so it keeps no storey's height and no room's size, only
## what shows in a patch that small; the sheet is drawn for that, tight and square, to read as cut
## by hand and nothing like the cemetery's open terraces. As first drawn (_redraw): storeys run
## across the sheet, by turns of rooms three rows high and of corridors two rows high, with floors
## of rock two or three rows thick between them. Walls two or three cells thick part the rooms
## every few cells, most with a doorway two rows high at the floor (a lintel over it), some solid,
## and here and there a room is left undug; a corridor runs on for a dozen cells and ends in rock.
## Stair holes two cells wide go down through the floors, each with a step under it. Nothing in it
## is taller than a room, so open air seldom piles up into a void.
## As painted since: beds of thorns along the floor of the lowest rooms, doorways and stair holes
## widened, some stair holes stepped down a cell a row, and a few walls opened, so the collapse
## seals fewer rooms off.
## Collapsed with no symmetry (NextWorldDef.symmetry), so up stays up and floors stay flat. White
## is open, black rock, red thorns.
## godot --headless --path . --script res://tests/make_institute_sample.gd [-- fold | -- redraw]

## The picture it draws.
const PATH: String = "res://wfc_images/institute.png"
## The sheet, a row a line: . open, # rock, ^ thorns (SampleSheet.INKS).
const SHEET: PackedStringArray = [
	"########################################",
	"#.....##......###.......##....###....###",
	"#.............###....................###",
	"#.............###....................###",
	"######....#################...##########",
	"#######...#################..###########",
	"##....##.......###..........########...#",
	"##..............................###....#",
	"###############################..#..####",
	"################################....####",
	"#################################...####",
	"#.......##.......##.....##.............#",
	"#................................###...#",
	"#................................###...#",
	"##################..###########..#######",
	"##################..###########..#######",
	"####................###.......#...###..#",
	"####...............####................#",
	"######......############################",
	"######.....#############################",
	"######....##############################",
	"#....#...##......##....##....###.....###",
	"#......................##..............#",
	"#......................##..............#",
	"###########....############....#########",
	"###########...##############...#########",
	"#........##..###...###....###..#.....###",
	"#......................................#",
	"#########^^^^##^^^^###^^^^###^^^^###^^^#",
	"########################################",
	"########################################",
	"########################################",
]

const W: int = 40
const H: int = 32
const OPEN: int = 0
const ROCK: int = 1
## The open rows of each storey (top, bottom): rooms three rows high and corridors two, by turns,
## the floors between two or three rows thick.
const STOREYS: Array[Vector2i] = [Vector2i(1, 3), Vector2i(6, 7), Vector2i(11, 13), Vector2i(16, 17), Vector2i(21, 23), Vector2i(26, 28)]
## How high a room is: a storey this high is parted into rooms, a lower one is a corridor.
const ROOM_HIGH: int = 3
## How wide a room is, and how thick the wall after it (from, to); the share of walls with a
## doorway, and of rooms left undug.
const ROOM_WIDE: Vector2i = Vector2i(4, 8)
const WALL_THICK: Vector2i = Vector2i(2, 3)
const DOORS: float = 0.6
const UNDUG: float = 0.12
## How long a stretch of corridor is, and how much rock ends it (from, to).
const CORRIDOR_LONG: Vector2i = Vector2i(9, 15)
const CORRIDOR_END: Vector2i = Vector2i(3, 5)

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
	rng.seed = 5151
	for x: int in range(W):
		var col: Array = []
		col.resize(H)
		col.fill(ROCK)
		grid.append(col)
	for i: int in range(STOREYS.size()):
		if STOREYS[i].y - STOREYS[i].x + 1 >= ROOM_HIGH:
			_rooms(i)
		else:
			_corridor(i)
	# Stair holes through the floors, each with a step a row under it on one side: two through
	# each floor two rows thick, one through each thicker one (a hole joins the air over it to the
	# air under it, and many of them let the collapse stack rooms into voids).
	_hole(8, 0, true)
	_hole(27, 0, false)
	_hole(34, 1, true)
	_hole(18, 2, false)
	_hole(31, 2, true)
	_hole(6, 3, true)
	_hole(11, 4, true)
	_hole(29, 4, false)
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y: int in range(H):
		for x: int in range(W):
			img.set_pixel(x, y, [Color.WHITE, Color.BLACK][grid[x][y]])
	return img


func _put(x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		grid[x][y] = c


## Storey `i` as rooms: each ROOM_WIDE cells of open air its whole height (or left undug, UNDUG of
## them), then a wall WALL_THICK cells thick, most (DOORS) with a doorway two rows high at the floor.
func _rooms(i: int) -> void:
	var rows: Vector2i = STOREYS[i]
	var x: int = 1
	while x < W - 1:
		var wide: int = mini(rng.randi_range(ROOM_WIDE.x, ROOM_WIDE.y), W - 1 - x)
		if rng.randf() >= UNDUG:
			for k: int in range(wide):
				for y: int in range(rows.x, rows.y + 1):
					_put(x + k, y, OPEN)
		x += wide
		var thick: int = rng.randi_range(WALL_THICK.x, WALL_THICK.y)
		if rng.randf() < DOORS:
			for k: int in range(thick):
				if x + k < W - 1:
					_put(x + k, rows.y, OPEN)
					_put(x + k, rows.y - 1, OPEN)
		x += thick


## Storey `i` as a corridor: stretches CORRIDOR_LONG cells long, each ending in CORRIDOR_END cells
## of rock.
func _corridor(i: int) -> void:
	var rows: Vector2i = STOREYS[i]
	var x: int = rng.randi_range(1, 4)
	while x < W - 1:
		var long: int = mini(rng.randi_range(CORRIDOR_LONG.x, CORRIDOR_LONG.y), W - 1 - x)
		for k: int in range(long):
			for y: int in range(rows.x, rows.y + 1):
				_put(x + k, y, OPEN)
		x += long + rng.randi_range(CORRIDOR_END.x, CORRIDOR_END.y)


## A stair hole two cells wide at column `x` through the floor under storey `i`, with a step a cell
## long under it in the top row of the storey below (to the left of it if `left`, else to the
## right), so it is climbed in two hops.
func _hole(x: int, i: int, left: bool) -> void:
	for y: int in range(STOREYS[i].y + 1, STOREYS[i + 1].x + 1):
		_put(x, y, OPEN)
		_put(x + 1, y, OPEN)
	_put(x - 1 if left else x + 2, STOREYS[i + 1].x, ROCK)
