extends Control

enum Type {
	EMPTY,
	GROUND,
}

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
		
			
	queue_redraw()

var enabled = false
func _input(event):
	if event.is_action_pressed("ShowMap"):
		enabled = !enabled
		queue_redraw()
			
			
func draw_cell(x, y, cell):
	var color = (Color.DARK_OLIVE_GREEN if cell.type == Type.GROUND else Color.BLACK)
	color.a = .5
	draw_rect(Rect2(x*SPACING+top_left.x, y*SPACING+top_left.y, SPACING, SPACING), color)

func _draw():
	if (enabled):
		for i in len(cells):
			for j in len(cells[i]):
				# print("i=", i, " j=", j, " cell=", cells[i][j].type)
				draw_cell(i, j, cells[i][j])
