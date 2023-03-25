extends Control

enum Type {
	EMPTY,
	GROUND,
}

@onready var cam = $"../Camera2D"

class Cell:
	var type = Type.GROUND
	
	func _init(_type=Type.GROUND):
		type = _type

var cells = []
# const?
var map_size = Vector2i(100, 100)
const SPACING = 10.0
var top_left = Vector2i(0, 0)

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(map_size.x):
		var row = []
		for j in range(map_size.y):
			var r = randi_range(0,1)
			# print(r)
			row.append(Cell.new(r))
		cells.append(row)
		
	#top_left = get_viewport_rect().size
	print("top_left", top_left)
			
	queue_redraw()
			
			
func draw_cell(x, y, cell):
	var color = Color.DARK_OLIVE_GREEN if cell.type == Type.GROUND else Color.BLACK
	draw_rect(Rect2(x*SPACING+top_left.x, y*SPACING+top_left.y, SPACING, SPACING), color)

func _draw():
#	print("drawing, len(cells)=", len(cells))
	for i in len(cells):
		for j in len(cells[i]):
			# print("i=", i, " j=", j, " cell=", cells[i][j].type)
			draw_cell(i, j, cells[i][j])
			
#	draw_rect(Rect2(1.0, 1.0, 3.0, 3.0), Color.GREEN)
#	draw_rect(Rect2(5.5, 1.5, 2.0, 2.0), Color.GREEN, false, 1.0)
#	draw_rect(Rect2(9.0, 1.0, 5.0, 5.0), Color.GREEN)
#	draw_rect(Rect2(16.0, 2.0, 3.0, 3.0), Color.GREEN, false, 2.0)
