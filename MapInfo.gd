extends Control

enum Type {
	EMPTY,
	GROUND,
}

class Cell:
	var type = Type.GROUND
	var discovered = false
	
	func _init(_type=Type.GROUND):
		type = _type

var cells = []
# const?
var map_size = Vector2i(100, 100)
const SPACING = 10.0
var top_left = Vector2i(0, 0)

const CHUNK_SIZE = 10

var discovered_chunks = {}

func get_random_chunk():
	return Vector2i(randi_range(0,map_size.x/CHUNK_SIZE-1), randi_range(0,map_size.y/CHUNK_SIZE-1))

func discover_chunk(v):
	for i in range(v.x*CHUNK_SIZE, v.x*CHUNK_SIZE+CHUNK_SIZE):
		for j in range(v.y*CHUNK_SIZE, v.y*CHUNK_SIZE+CHUNK_SIZE):
			cells[i][j].discovered = true

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(map_size.x):
		var row = []
		for j in range(map_size.y):
			var r = randi_range(0,1)
			# print(r)
			row.append(Cell.new(r))
		cells.append(row)
		
			
	queue_redraw()

var enabled = false
func _input(event):
	if event.is_action_pressed("ShowMap"):
		enabled = !enabled
		queue_redraw()
		
	if event.is_action_pressed("Discover"):
		var v = get_random_chunk()
		
		while (v in discovered_chunks):
			v = get_random_chunk()
		discovered_chunks[v] = true
		
		discover_chunk(v)
		queue_redraw()
			
			
func draw_cell(x, y, cell):
	var color = Color.BLACK if not cell.discovered else (Color.DARK_OLIVE_GREEN if cell.type == Type.GROUND else Color.LIGHT_BLUE)
	color.a = .5
	draw_rect(Rect2(x*SPACING+top_left.x, y*SPACING+top_left.y, SPACING, SPACING), color)

func _draw():
	if (enabled):
		for i in len(cells):
			for j in len(cells[i]):
				# print("i=", i, " j=", j, " cell=", cells[i][j].type)
				draw_cell(i, j, cells[i][j])
