extends Control

enum Type {
	EMPTY,
	GROUND,
	SHARD,
	GOAL,
	SPIKES,
}

class Cell:
	var type = Type.GROUND
	var discovered = false
	
	func _init(_type=Type.GROUND):
		type = _type

class World:
	var cells
	var size = Vector2i.ZERO
	var rng
	var next_seed
	var empties = []
	
	func is_valid (v):
		return not (v.x >= size.x or v.x < 0 or v.y >= size.y or v.y < 0)
	
	var neighbor_offsets = [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(0,-1)]
	func get_neighbors (v):
		var vs = []
		for offset in neighbor_offsets:
			var n = v + offset
			if is_valid(n):
				vs.append(n)
		return vs
		
	func is_ground (v):
		return get_cell(v).type == Type.GROUND

	func get_cell (v):
		return cells[v.x][v.y]

	func set_cell (v, cell):
		cells[v.x][v.y] = cell

	func discover (v):
		get_cell(v).discovered = true

	func get_random_cell ():
		return Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		
	func pop_random_empty ():
		var i = rng.randi_range(0, len(empties) - 1)
		var v = empties[i]
		empties.remove_at(i)
		return v

	func _init (_cells, _seed):
		rng = RandomNumberGenerator.new()
		rng.seed = _seed
		size = Vector2i(len(_cells), len(_cells[0]))
		cells = []
		for i in len(_cells):
			var row = []
			for j in len(_cells[i]):
				row.append(Cell.new(_cells[i][j]))
				if _cells[i][j] == Type.EMPTY:
					empties.append(Vector2i(i,j))
			cells.append(row)
	
		var chunks = (size.x*size.y)/(CHUNK_SIZE*CHUNK_SIZE)
		for i in range(chunks):
			set_cell(pop_random_empty(), Cell.new(Type.SHARD))
			
		# find a place for the goal
		set_cell(pop_random_empty(), Cell.new(Type.GOAL))
		
#		for i in range(rng.randi_range(8,32)):
		for i in range(100):
			set_cell(pop_random_empty(), Cell.new(Type.SPIKES))

		next_seed = rng.randi()
		
var goal_shift = 0
var world
var map
@onready var wfc = $"../../WaveFunctionCollapse"
@onready var player
@onready var map_sprite = $MapSprite
# const?
const SPACING = 6.0

var wfc_world_thread = Thread.new()
var wfc_map_thread = Thread.new()

var map_local_size = Vector2(100,100)
var top_left = Vector2i(100, 100)

const START_REVEALED = false
const CHUNK_SIZE = 8

var undiscovered_chunks = []
@onready var tile_map = $"../../TileMap"

var elements = []

# constants for "box" to contain the generated map
const X_MARGIN = 2
const TOP_MARGIN = 5

@onready var wfc_thread = Thread.new()

var generating = false
func generate():
	player.reset_position()
	player.set_physics_process(false)
	wfc_thread.start(wfc.generate_all.bind(world.next_seed, map.next_seed, wfc_thread))

func setup_chunks():
	undiscovered_chunks = []
	for i in range(0,map.size.x/CHUNK_SIZE):
		for j in range(0,map.size.y/CHUNK_SIZE):
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

func discover_all():
	for i in range(map.size.x):
		for j in range(map.size.y):
			map.discover(Vector2i(i,j))

func discover_chunk(v):
	for i in range(v.x*CHUNK_SIZE, v.x*CHUNK_SIZE+CHUNK_SIZE):
		for j in range(v.y*CHUNK_SIZE, v.y*CHUNK_SIZE+CHUNK_SIZE):
			map.discover(Vector2i(i,j))
			
var map_shard = preload("res://prefabs/map_shard.tscn")
var spikes = preload("res://prefabs/spikes.tscn")
var goal = preload("res://prefabs/goal.tscn")
@onready var main = $"../.."
# Called when the node enters the scene tree for the first time.
func _ready():
#	generate_all(9999, 9999)
	pass # more like ass

func remove_element(elem):
	elements.erase(elem)

func clear_terrain():
	if world == null:
		return
		
	for i in range(world.size.x):
		for j in range(world.size.y):
			tile_map.clear()
			
	for elem in elements:
		if elem != null:
			elem.queue_free()
	elements.clear()

var player_prefab = preload("res://prefabs/player.tscn")

func load_all(world_cells, world_seed, map_cells, map_seed):
	clear_terrain()
	print("loading")
	
	map = World.new(map_cells, map_seed)
	world = World.new(world_cells, world_seed)
	goal_shift+=1
	map_local_size = map.size*SPACING
	# print("_world_cells=", len(_world_cells), "x", len(_world_cells[0]), " world_cells=", len(world_cells), "x", len(world_cells[0]))
	
	construct_world()

	if (START_REVEALED):
		discover_all()

	map_image = Image.create(map.size.x, map.size.y, true, Image.FORMAT_RGBA8)
	map_texture = ImageTexture.new()
	# main.add_child(player)
	
	if player == null:
		player = player_prefab.instantiate()

	if player.get_parent() == null:
		main.add_child(player)
	
	player.set_physics_process(true)

var cell_to_prefab = {
	Type.SHARD: map_shard,
	Type.GOAL: goal,
	Type.SPIKES: spikes,
}

func place_cell(v, type):
	var cell = cell_to_prefab[type].instantiate()
	main.add_child.call_deferred(cell)
	cell.position = tile_map.to_global(tile_map.map_to_local(v))
	cell.setup(self, v)
	elements.append(cell)

func construct_world():
	setup_chunks()
	
	for i in range(world.size.x):
		for j in range(world.size.y):
			var v = Vector2i(i,j)
			var cell : Cell = world.get_cell(v)
#			print("Setting a tile @=", Vector2i(i,j), " cell.type=", cell.type)
			if cell.type == Type.GROUND:
				tile_map.set_cells_terrain_connect(0, [v], 0, 0)
			elif cell.type != Type.EMPTY:
				place_cell(v, cell.type)
	
	enclose_map(world.size.x, world.size.y)
	
	queue_redraw()

# Enclose the map in a "box" so the player can't fall into nothingness
func enclose_map(dim_x, dim_y):
	for i in range(-X_MARGIN, dim_x + X_MARGIN):
		var to_add = [
			Vector2i(i, dim_y), #bottom of map
			Vector2i(i, -TOP_MARGIN), #top of map
			]
		tile_map.set_cells_terrain_connect(0, to_add, 0, 0)
		# print("to_add=", to_add, " dim_x=", dim_x)
	
	for j in range(-TOP_MARGIN + 1, dim_y):
		var to_add = [
			Vector2i(-X_MARGIN, j), #left of map
			Vector2i(dim_x + X_MARGIN - 1, j), #right of map
		]
		tile_map.set_cells_terrain_connect(0, to_add, 0, 0)
		# print("to_add=", to_add, " dim_y=", dim_y)

var enabled = false
func _input(event):
	if event.is_action_pressed("ShowMap"):
		enabled = !enabled
		queue_redraw()
		
	if event.is_action_pressed("Discover"):
		discover_random_chunk()
			
var cell_colors = {
	Type.GROUND: 	Color.DARK_OLIVE_GREEN,
	Type.EMPTY: 	Color.LIGHT_BLUE,
	Type.SHARD: 	Color.RED,
	Type.GOAL: 		Color.GREEN,
	Type.SPIKES: 	Color.DARK_OLIVE_GREEN,
}

@onready var map_contents = $MapContents
var map_image : Image
var map_texture : ImageTexture

func compose_texture():
	for i in map.size.x:
		for j in map.size.y:
			draw_cell(i, j, map.get_cell(Vector2i(i, j)))

func draw_cell(x, y, cell):
#	print("cell.type=", cell.type)
	var color = Color.BLACK if not cell.discovered else cell_colors[cell.type]
	color.a = .5
	map_image.set_pixel(x, y, color)

func inverse(v):
	return Vector2(1/float(v.x), 1/float(v.y))

func _draw():
	top_left = get_viewport_rect().size/2-map_local_size/2
	map_sprite.visible = enabled
	map_sprite.position = get_viewport_rect().size/2 - Vector2.RIGHT*8

	map_contents.visible = enabled
	map_contents.position = get_viewport_rect().size/2
	if (enabled):
		for i in map.size.x:
			for j in map.size.y:
				# print("i=", i, " j=", j, " cell=", cells[i][j].type)
				draw_cell(i, j, map.get_cell(Vector2i(i, j)))
		map_texture.image = map_image
		map_contents.texture = map_texture
		map_contents.scale =  inverse(map_contents.texture.get_image().get_size()) * 19 * 32
