extends Control

enum Type {
	EMPTY,
	GROUND,
	SHARD,
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

var undiscovered_chunks = []
@onready var tile_map = $"../../TileMap"

func setup_chunks():
	for i in range(0,map_size.x/CHUNK_SIZE):
		for j in range(0,map_size.y/CHUNK_SIZE):
			undiscovered_chunks.append(Vector2i(i, j))

func get_random_chunk():
	if (undiscovered_chunks.is_empty()):
		return Vector2i.ZERO

	var i = randi_range(0, len(undiscovered_chunks)-1)
	var chunk = undiscovered_chunks[i]
	undiscovered_chunks.remove_at(i)
	return chunk

func discover_random_chunk():
	discover_chunk(get_random_chunk())
	queue_redraw()
	
func discover_chunk(v):
	for i in range(v.x*CHUNK_SIZE, v.x*CHUNK_SIZE+CHUNK_SIZE):
		for j in range(v.y*CHUNK_SIZE, v.y*CHUNK_SIZE+CHUNK_SIZE):
			cells[i][j].discovered = true
			
var map_shard = preload("res://map_shard.tscn")
@onready var main = $"../.."
# Called when the node enters the scene tree for the first time.
func _ready():
	seed(9999)
	setup_chunks()
	for i in range(map_size.x):
		var row = []
		for j in range(map_size.y):
			var r = randi_range(0,3)
			# print(r)
			row.append(Cell.new(r))
			if row[j].type == Type.GROUND:
				tile_map.set_cells_terrain_connect(0, [Vector2i(i,j)], 0, 0)
			elif row[j].type == Type.SHARD:
				var ms = map_shard.instantiate()
				main.add_child.call_deferred(ms)
				ms.position = tile_map.map_to_local(Vector2i(i,j))
				ms.setup(self)
				
		cells.append(row)
			
	queue_redraw()

var enabled = false
func _input(event):
	if event.is_action_pressed("ShowMap"):
		enabled = !enabled
		queue_redraw()
		
	if event.is_action_pressed("Discover"):
		discover_random_chunk()
			
			
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
