extends Control

class_name MapInfo

const START_REVEALED = false
const CLOSE_GOAL = true
const CLOSE_ONE_KEY = false
const DEBUG_DISCOVERABLE = false
const CODE_LENGTH = 4 # 8 is more reasonable

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
	RESPAWN,
	CHECKPOINT,
	PORTAL,
	ASTRAL_PROJECTION_POINT,
	PLATFORM,
}

class NextWorldDef:
	var gen_seed : int = 0
	var region : String

	func _init(s, r):
		gen_seed = s
		region = r

static func default_def (gen_seed):
	return NextWorldDef.new(gen_seed, "res://wfc_images/levelSample3-spikes.png")
	
class Cell:
	var type = Type.GROUND
	var discovered = false
	var extra_info = null
	
	func _init(_type: Type):
		type = _type

class World:
	var cells
	var size = Vector2i.ZERO
	var rng
	var empties = []
	var grounds = []
	var objects = []
	
	# codes maps code -> NextWorldDef (seed and wfc image)
	var codes = {}
	var keys = []
	
	var prev_world_index = -1
	var next_world_indices = {}

	var regions = {
		"tunnels" : "res://wfc_images/levelSample3-spikes.png",
		"islands" : "res://wfc_images/floating_islands.png",
	}
	
	var code_index = 0
	func next_code ():
		code_index += 1
		return codes.keys()[code_index-1]
	
	# acts like a static method
	var code_digits = ['<', '>', '^', 'v']
	func generate_code (length=CODE_LENGTH):
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
		return is_valid(v) and get_cell(v).type == Type.GROUND

	func get_cell (v):
		return cells[v.x][v.y]
		
	func random_region ():
		return regions.values()[rng.randi_range(0, len(regions.values())-1)]

	func set_cell (v, cell):
		if v != null:
			cells[v.x][v.y] = cell
			
			if cell.type == Type.GOAL:
				codes[generate_code()] = NextWorldDef.new(rng.randi(), random_region())
				

	func discover (v):
		get_cell(v).discovered = true

	func get_random_cell ():
		return Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		
	func ground_adjacent (v):
		return get_neighbors(v).any(is_ground)
		
	func ground_flanking (v):
		for n in range(0, 2, len(neighbor_offsets)):
			var a = v+neighbor_offsets[n]
			var b = v+neighbor_offsets[n+1]
			if is_ground(a) and is_ground(b):
				return true
			
		return false
		
	func ground_below (v):
		var n = v+Vector2i(0,1)
		return is_ground(n)
		
	func add_object_at (v):
		empties.erase(v)
		grounds.erase(v)
		objects.append(v)
		
	func pop_if_random_empty (f=func(_v): return true, force=false):
		while (true):
			var i = rng.randi_range(0, len(empties) - 1)
			var v = empties[i]
			if f.bind(v).call():
				add_object_at(v)
				return v
			if not force:
				break

		return null
			
	func add_cell_to_container (v, cell):
		if cell.type == Type.EMPTY:
			empties.append(v)
		elif cell.type == Type.GROUND:
			grounds.append(v)
		else:
			objects.append(v)

	func _init (_cells, def):
		rng = RandomNumberGenerator.new()
		rng.seed = def.gen_seed
		size = Vector2i(len(_cells), len(_cells[0]))
		cells = []
		
		var goals = 2
		
		if CLOSE_GOAL:
			_cells[0][0] = Color.BLACK

		for i in len(_cells):
			var row = []
			for j in len(_cells[i]):
				var cell = new_cell_by_color(_cells[i][j])
				row.append(cell)
				add_cell_to_container(Vector2i(i, j), cell)
			cells.append(row)
	
		var chunks = (size.x*size.y)/(CHUNK_SIZE*CHUNK_SIZE)
		for i in range(2*chunks):
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
			
		for i in range(len(empties)*0.1):
			set_cell(pop_if_random_empty(ground_flanking), Cell.new(Type.DOOR))
			
		# find a place for the goal
		if CLOSE_GOAL:
			for i in range(goals):
				var v = Vector2i(4+i,0)
				set_cell(v, Cell.new(Type.GOAL))
				add_object_at(v)
			
			var v = Vector2i(0,-1)
			set_cell(v, Cell.new(Type.RESPAWN))
			add_object_at(v)
		else:
			for i in range(goals):
				set_cell(pop_if_random_empty(), Cell.new(Type.GOAL))
				set_cell(pop_if_random_empty(ground_below, true), Cell.new(Type.RESPAWN))
		
#		for i in range(len(empties)*0.1):
#			set_cell(pop_if_random_empty(ground_adjacent), Cell.new(Type.SPIKES))
		for i in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(), Cell.new(Type.COIN))
			
		
		for i in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(), Cell.new(Type.PLATFORM))

		for i in range(len(empties)*0.2):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.ENEMY))
			
		for i in range(len(empties)*0.1):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.SHOOTER))
			
		for i in range(len(empties)*0.25):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.CHECKPOINT))

		#place pairs of portals in the stage and connect them to each other
		#by telling each portal the coords of its partner in the extra_info
		for i in range(1):
			var pos1 = pop_if_random_empty(ground_below, true)
			var pos2 = pop_if_random_empty(ground_below, true)
			var portal1 = Cell.new(Type.PORTAL)
			var portal2 = Cell.new(Type.PORTAL)
			portal1.extra_info = pos2
			portal2.extra_info = pos1
			set_cell(pos1, portal1)
			set_cell(pos2, portal2)

		for i in range(len(empties)*0.05):
			set_cell(pop_if_random_empty(ground_below), Cell.new(Type.ASTRAL_PROJECTION_POINT))
		
var goal_shift = 0
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

const CHUNK_SIZE = 16

var undiscovered_chunks = []
@onready var tile_map = $"../../TileMap"

# constants for "box" to contain the generated map
const X_MARGIN = 2
const TOP_MARGIN = 5

@onready var wfc_thread = Thread.new()

var generating = false
func generate(world_code, map_code):
	player.set_physics_process(false)
	player.set_collision(false)
	
	if world_code in world.next_world_indices:
		# go to the next world, already generated
		load_world(world.next_world_indices[world_code])
	else:
		# have to generate a new world
		world.next_world_indices[world_code] = len(worlds)
		wfc_thread.start(wfc.generate_all.bind(world.codes[world_code], all_map_codes[map_code], wfc_thread))
		all_map_codes.erase(map_code)

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
var respawn_prefab = preload("res://prefabs/respawn.tscn")
var checkpoint_prefab = preload("res://prefabs/checkpoint.tscn")
var portal_prefab = preload("res://prefabs/portal.tscn")
var astral_projection_point_prefab = preload("res://prefabs/astral_projection_point.tscn")
var platform_prefab = preload("res://prefabs/platform.tscn")

var map_elements_prefab = preload("res://prefabs/map_elements.tscn")

var basic_sprite_prefab = preload("res://prefabs/sprite_2d.tscn")
@onready var main = $"/root/Main"
	
var world_index = -1

var worlds = []
var maps = []
var world_scenes = []
var world
var map

var all_map_codes = {}

func can_backtrack ():
	return world.prev_world_index >= 0
	
func backtrack ():
	load_world(world.prev_world_index)
	
func clear_terrain():
	if world == null:
		return
		
	for i in range(world.size.x):
		for j in range(world.size.y):
			tile_map.clear()
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(map_elements)
	if world_index < len(world_scenes):
		world_scenes[world_index] = packed_scene
	else:
		world_scenes.append(packed_scene)
		
	map_elements.queue_free()

var player_prefab = preload("res://prefabs/player.tscn")
var valid_keys = []

func remove_valid_key (key):
	valid_keys.erase(key)

func next_world ():
	map_local_size = map.size*SPACING
	construct_world()

	if (START_REVEALED):
		discover_all()

	map_image = Image.create(map.size.x, map.size.y, true, Image.FORMAT_RGBA8)
	map_texture = ImageTexture.new()
	# main.add_child(player)
	
	player.reset_position()
	player.set_collision(true)
	player.set_physics_process(true)

var map_elements
# result of generating a new world
func load_all(world_cells, world_seed, map_cells, map_seed):
	clear_terrain()
	
	# log old world index
	var prev_world_index = world_index
	# set current world index to the end of the list
	world_index = len(worlds)
	maps.append(World.new(map_cells, map_seed))
	worlds.append(World.new(world_cells, world_seed))
	
	map = maps[world_index]
	world = worlds[world_index]
	world.prev_world_index = prev_world_index

	for code in map.codes.keys():
		if code in all_map_codes:
			printerr("yo we already made this")
		all_map_codes[code] = map.codes[code]
	
	valid_keys.append_array(map.keys)
	
	if player == null:
		player = player_prefab.instantiate()
		
	if player.get_parent() == null:
		main.add_child(player)

	map_elements = map_elements_prefab.instantiate()
	main.add_child(map_elements)

	for v in world.objects:
		var cell : Cell = world.get_cell(v)
		place_cell(v, cell)

	next_world()
	
func load_world (i):
	clear_terrain()
	
	world_index = i
	print("loading, i=", i)
	world = worlds[i]
	map = worlds[i]

	map_elements = world_scenes[i].instantiate()
	main.add_child(map_elements)
	
	next_world()

var cell_to_prefab = {
	Type.SHARD: map_shard,
	Type.GOAL: goal,
	Type.SPIKES: spikes,
	Type.ENEMY: enemy_prefab,
	Type.SHOOTER: shooter_prefab,
	Type.COIN: coin_prefab,
	Type.KEY: key_prefab,
	Type.DOOR: door_prefab,
	Type.RESPAWN: respawn_prefab,
	Type.CHECKPOINT: checkpoint_prefab,
	Type.PORTAL: portal_prefab,
	Type.ASTRAL_PROJECTION_POINT: astral_projection_point_prefab,
	Type.PLATFORM: platform_prefab,
}

func place_cell(v, _cell):
	var cell = cell_to_prefab[_cell.type].instantiate()
	map_elements.add_child(cell)
	cell.set_owner(map_elements)
	cell.position = tile_map.to_global(tile_map.map_to_local(v))
	
	if _cell.extra_info != null:
		cell.setup(self, v, _cell.extra_info)
	else:
		cell.setup(self, v)

func construct_world():
	setup_chunks()
	
	tile_map.set_cells_terrain_connect(0, world.grounds, 0, 0)
	
	enclose_map(world.size.x, world.size.y)
	
	draw_background(world.size.x, world.size.y)
	
	queue_redraw()

func get_max_bounds ():
	return tile_map.to_global(tile_map.map_to_local(Vector2i(world.size.x + X_MARGIN - 1, world.size.y)))
	
func get_min_bounds ():
	return tile_map.to_global(tile_map.map_to_local(Vector2i(-X_MARGIN, -TOP_MARGIN)))

func in_bounds (v):
	#	world.size.x, world.size.y
	var max_bounds = get_max_bounds()
	var min_bounds = get_min_bounds()
	
	if v.x > max_bounds.x or v.y > max_bounds.y:
		return false
	if v.x < min_bounds.x or v.y < min_bounds.y:
		return false
		
	return true

func clamp_bounds (v):
	var max_bounds = get_max_bounds()
	var min_bounds = get_min_bounds()

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
		if DEBUG_DISCOVERABLE:
			discover_random_chunk()
	
	if event.is_action_pressed("Debug-Back"):
		load_world(world_index-1)
			
var cell_colors = {
	Type.GROUND: 	Color.DARK_OLIVE_GREEN,
	Type.SHARD: 	Color.RED,
	Type.GOAL: 		Color.GREEN,
}

@onready var map_contents = $MapContents
var map_image : Image
var map_texture : ImageTexture

func draw_cell(x, y, cell):
#	print("cell.type=", cell.type)
	var color = Color.BLACK if not cell.discovered else (Color.LIGHT_BLUE if cell.type not in cell_colors else cell_colors[cell.type])
	color.a = .5
	map_image.set_pixel(x, y, color)

func inverse(v):
	return Vector2(1/float(v.x), 1/float(v.y))

func _draw():
	map_sprite.visible = enabled
	
	keys.visible = enabled

	map_contents.visible = enabled
	if (enabled):
		for i in map.size.x:
			for j in map.size.y:
				# print("i=", i, " j=", j, " cell=", cells[i][j].type)
				draw_cell(i, j, map.get_cell(Vector2i(i, j)))
		map_texture.image = map_image
		map_contents.texture = map_texture
		# map_contents.scale =  inverse(map_contents.texture.get_image().get_size())
