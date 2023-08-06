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

var world_cells = []
var map_cells = []
@onready var map_sprite = $MapSprite
# const?
var map_size = Vector2i(100, 100)
const SPACING = 6.0

var map_local_size = map_size*SPACING
var top_left = Vector2i(100, 100)

const CHUNK_SIZE = 10

var undiscovered_chunks = []
@onready var tile_map = $"../../TileMap"

var elements = []

# constants for "box" to contain the generated map
const X_MARGIN = 2
const TOP_MARGIN = 5

func setup_chunks():
	undiscovered_chunks = []
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
			map_cells[i][j].discovered = true
			
var map_shard = preload("res://prefabs/map_shard.tscn")
@onready var main = $"../.."
# Called when the node enters the scene tree for the first time.
func _ready():
#	generate_all(9999, 9999)
	pass # more like ass

func remove_element(elem):
	elements.erase(elem)

func clear_terrain():
	for i in range(map_size.x):
		for j in range(map_size.y):
			tile_map.clear()
			
	for elem in elements:
		elem.queue_free()
	elements.clear()

func generate(new_seed):
	var cells = []
	seed(new_seed)
	for i in range(map_size.x):
		var row = []
		for j in range(map_size.y):
			var r = randi_range(0, Type.size()-1)
			row.append(Cell.new(r))
		cells.append(row)
	return cells

func convert_to_cells(cells):
	var new_cells = []
	for i in len(cells):
		var row = []
		for j in len(cells[i]):
			row.append(Cell.new(cells[i][j]))
		new_cells.append(row)
	return new_cells

func load_map(cells):
	map_cells = convert_to_cells(cells)
	
func load_world(cells):
	world_cells = convert_to_cells(cells)
	
func load_all(_world_cells, _map_cells):
	clear_terrain()
	load_map(_map_cells)
	load_world(_world_cells)
	print("_world_cells=", len(_world_cells), "x", len(_world_cells[0]), " world_cells=", len(world_cells), "x", len(world_cells[0]))
	
	construct_all()
	
func construct_all():
	setup_chunks()
	
	var dimX = len(world_cells)
	var dimY = len(world_cells[0])
	
	for i in range(dimX):
		for j in range(dimY):
			var cell = world_cells[i][j]
#			print("Setting a tile @=", Vector2i(i,j), " cell.type=", cell.type)
			if cell.type == Type.GROUND:
				tile_map.set_cells_terrain_connect(0, [Vector2i(i,j)], 0, 0)
			elif cell.type == Type.SHARD:
				var ms = map_shard.instantiate()
				main.add_child.call_deferred(ms)
				ms.position = tile_map.map_to_local(Vector2i(i,j))
				ms.setup(self)
				elements.append(ms)
	
	enclose_map(dimX, dimY)
	
	queue_redraw()

# Enclose the map in a "box" so the player can't fall into nothingness
func enclose_map(dimX, dimY):
	for i in range(-X_MARGIN, dimX + X_MARGIN):
		var to_add = [
			Vector2i(i, dimY), #bottom of map
			Vector2i(i, -TOP_MARGIN), #top of map
			]
		tile_map.set_cells_terrain_connect(0, to_add, 0, 0)
	
	for j in range(-TOP_MARGIN + 1, dimY):
		var to_add = [
			Vector2i(-X_MARGIN, j), #left of map
			Vector2i(dimX + X_MARGIN - 1, j), #right of map
		]
		tile_map.set_cells_terrain_connect(0, to_add, 0, 0)

func generate_all(world_seed, map_seed):
#	clear_terrain()
	map_cells = generate(map_seed)
	world_cells = generate(world_seed)
	
	construct_all()

var enabled = false
func _input(event):
	if event.is_action_pressed("ShowMap"):
		enabled = !enabled
		queue_redraw()
		
	if event.is_action_pressed("Discover"):
		discover_random_chunk()
			
var cell_colors = {
	Type.GROUND: Color.DARK_OLIVE_GREEN,
	Type.EMPTY: Color.LIGHT_BLUE,
	Type.SHARD: Color.RED,
}
			
func draw_cell(x, y, cell):
#	print("cell.type=", cell.type)
	var color = Color.BLACK if not cell.discovered else cell_colors[cell.type]
	color.a = .5
	draw_rect(Rect2(x*SPACING+top_left.x, y*SPACING+top_left.y, SPACING, SPACING), color)

func _draw():
	top_left = get_viewport_rect().size/2-map_local_size/2
	map_sprite.visible = enabled
	map_sprite.position = get_viewport_rect().size/2 - Vector2.RIGHT*8
	if (enabled):
		for i in len(map_cells):
			for j in len(map_cells[i]):
				# print("i=", i, " j=", j, " cell=", cells[i][j].type)
				draw_cell(i, j, map_cells[i][j])
