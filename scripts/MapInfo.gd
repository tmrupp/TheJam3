extends Control

const START_REVEALED = false
const CLOSE_GOAL = false
const CLOSE_ONE_KEY = false

enum Type {
	EMPTY,
	GROUND,
	SHARD,
	GOAL,
	SPIKES,
	ENEMY,
	SHOOTER,
	COIN,
	KEY,
	DOOR,
}
	
class Cell:
	var type = Type.GROUND
	var discovered = false
	
	func _init(_type: Type):
		type = _type

class World:
	var cells
	var size = Vector2i.ZERO
	var rng
	var next_seed
	var empties = []
	var grounds = []
	var objects = []
	var code = ""
	var keys = []
	
	# acts like a static method
	var code_digits = ['<', '>', '^', 'v']
	func generate_code (length=8):
		var new_code = ""
		for i in range(length):
			new_code += code_digits[rng.randi_range(0, len(code_digits)-1)]
		return new_code
	
	var color_to_type = {
		Color.WHITE: 	Type.EMPTY,
		Color.BLACK: 	Type.GROUND,
		Color.RED: 		Type.SPIKES,
	}
	
	func new_cell_by_color (c: Color):
		return Cell.new(color_to_type[Color(c)])
	
	func is_valid (v):
		return not (v.x >= size.x or v.x < 0 or v.y >= size.y or v.y < 0)
	
	var neighbor_offsets = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
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
		if v != null:
			cells[v.x][v.y] = cell

	func discover (v):
		get_cell(v).discovered = true

	func get_random_cell ():
		return Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		
	func ground_adjacent (v):
		return get_neighbors(v).any(is_ground)
		
	func ground_below (v):
		var n = v+Vector2i(0,1)
		return is_valid(n) and is_ground(n)
		
	func add_object_at (v):
		empties.erase(v)
		grounds.erase(v)
		objects.append(v)
		
	func pop_if_random_empty (f=func(_v): return true):
		var i = rng.randi_range(0, len(empties) - 1)
		var v = empties[i]
		if f.bind(v).call():
			add_object_at(v)
			return v
		else:
			return null
			
	func add_cell_to_container (v, cell):
		if cell.type == Type.EMPTY:
			empties.append(v)
		elif cell.type == Type.GROUND:
			grounds.append(v)
		else:
			objects.append(v)

	func _init (_cells, _seed):
		rng = RandomNumberGenerator.new()
		rng.seed = _seed
		size = Vector2i(len(_cells), len(_cells[0]))
		cells = []
		for i in len(_cells):
			var row = []
			for j in len(_cells[i]):
				var cell = new_cell_by_color(_cells[i][j])
				row.append(cell)
				add_cell_to_container(Vector2i(i, j), cell)
			cells.append(row)
	
		var chunks = (size.x*size.y)/(CHUNK_SIZE*CHUNK_SIZE)
		for i in range(chunks):
			set_cell(pop_if_random_empty(), Cell.new(Type.SHARD))
		
		if CLOSE_ONE_KEY:
			var v = Vector2i(6,0)
			set_cell(v, Cell.new(Type.KEY))
			keys.append(generate_code())
			add_object_at(v)
		else:
			for i in range(len(empties)*0.05):
				set_cell(pop_if_random_empty(), Cell.new(Type.KEY))
				keys.append(generate_code())
#			print("keys=", keys)
			
		for i in range(len(empties)*0.05):
			set_cell(pop_if_random_empty(), Cell.new(Type.DOOR))
			
		# find a place for the goal
		if CLOSE_GOAL:
			var v = Vector2i(4,0)
			set_cell(v, Cell.new(Type.GOAL))
			add_object_at(v)
		else:
			set_cell(pop_if_random_empty(), Cell.new(Type.GOAL))
		
#		for i in range(len(empties)*0.1):
#			set_cell(pop_if_random_empty(ground_adjacent), Cell.new(Type.SPIKES))
		for i in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(), Cell.new(Type.COIN))

		for i in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.ENEMY))
			
		for i in range(len(empties)*0.1):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.SHOOTER))
			
		
		code = generate_code()

		next_seed = rng.randi()
		
var goal_shift = 0
var world
var map
@onready var wfc = $"../../WaveFunctionCollapse"
@onready var player
@onready var map_sprite = $MapSprite
@onready var keys = $"../HUD/Keys"
# const?
const SPACING = 6.0

var wfc_world_thread = Thread.new()
var wfc_map_thread = Thread.new()

var map_local_size = Vector2(100,100)
var top_left = Vector2i(100, 100)

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
var enemy_prefab = preload("res://prefabs/mover_enemy.tscn")
var shooter_prefab = preload("res://prefabs/shooter_enemy.tscn")
var coin_prefab = preload("res://prefabs/coin.tscn")
var key_prefab = preload("res://prefabs/key.tscn")
var door_prefab = preload("res://prefabs/door.tscn")
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
var valid_keys = []

func remove_valid_key (key):
	valid_keys.erase(key)

func load_all(world_cells, world_seed, map_cells, map_seed):
	clear_terrain()
	
	map = World.new(map_cells, map_seed)
	world = World.new(world_cells, world_seed)
	
	valid_keys.append_array(map.keys)
	# print("valid keys=", valid_keys)
	
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
	Type.ENEMY: enemy_prefab,
	Type.SHOOTER: shooter_prefab,
	Type.COIN: coin_prefab,
	Type.KEY: key_prefab,
	Type.DOOR: door_prefab,
}

func place_cell(v, type):
	var cell = cell_to_prefab[type].instantiate()
	# print("making, ", type, " at ", v)
	main.add_child.call_deferred(cell)
	cell.position = tile_map.to_global(tile_map.map_to_local(v))
	cell.setup(self, v)
	elements.append(cell)

func construct_world():
	setup_chunks()
	
	tile_map.set_cells_terrain_connect(0, world.grounds, 0, 0)
	
	for v in world.objects:
		var cell : Cell = world.get_cell(v)
		place_cell(v, cell.type)
	
	enclose_map(world.size.x, world.size.y)
	
	draw_background(world.size.x, world.size.y)
	
	queue_redraw()

func in_bounds (v):
	#	world.size.x, world.size.y
	var max_bounds = tile_map.to_global(tile_map.map_to_local(Vector2i(world.size.x + X_MARGIN, world.size.y + TOP_MARGIN)))
	var min_bounds = tile_map.to_global(tile_map.map_to_local(Vector2i(-X_MARGIN, -TOP_MARGIN)))
	
	if v.x > max_bounds.x or v.y > max_bounds.y:
		return false
	if v.x < min_bounds.x or v.y < min_bounds.y:
		return false
		
	return true

func clamp_bounds (v):
	var max_bounds = tile_map.to_global(tile_map.map_to_local(Vector2i(world.size.x + X_MARGIN, world.size.y + TOP_MARGIN)))
	var min_bounds = tile_map.to_global(tile_map.map_to_local(Vector2i(-X_MARGIN, -TOP_MARGIN)))

	return Vector2(clamp(v.x, min_bounds.x, max_bounds.x), clamp(v.y, min_bounds.y, max_bounds.y))

func get_next_key ():
	if len(world.keys) > 0:
		return world.keys.pop_back()
	return null

# Draw on the layer behind the foreground tiles
# We assume negative y values are sky and positive are dirt
func draw_background(dim_x, dim_y):
	for i in range(-X_MARGIN, dim_x + X_MARGIN):
		for j in range(-TOP_MARGIN, dim_y):
			# arg1: layer, layer 1 is the Background layer
			# arg2: location
			# arg3: source_id, the tileset source_id for which ID:1 is the background tiles on this tilemap
			# arg4: atlas coords, the tile by grid location in the atlas, (0,0) is dirt, (1,0) is sky
			tile_map.set_cell(1, Vector2i(i, j), 1, Vector2i(1 if j < 0 else 0, 0))

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
	Type.SHARD: 	Color.RED,
	Type.GOAL: 		Color.GREEN,
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
	var color = Color.BLACK if not cell.discovered else (Color.LIGHT_BLUE if cell.type not in cell_colors else cell_colors[cell.type])
	color.a = .5
	map_image.set_pixel(x, y, color)

func inverse(v):
	return Vector2(1/float(v.x), 1/float(v.y))

func _draw():
	top_left = get_viewport_rect().size/2-map_local_size/2
	map_sprite.visible = enabled
	map_sprite.position = get_viewport_rect().size/2 - Vector2.RIGHT*8
	
	keys.visible = enabled

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
