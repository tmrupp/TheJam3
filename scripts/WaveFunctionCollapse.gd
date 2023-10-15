extends WaveFunctionCollapse

func generate(def: MapInfo.NextWorldDef):
	set_seed(def.gen_seed)
	seed(def.gen_seed)
	texture = load(def.region)
	var map = collapse()
	while len(map) == 0:
		print("trying again")
		seed = randi()
		map = collapse()
	return map

func finish_generation(world, world_seed, map, map_seed, thread):
	if thread != null:
		thread.wait_to_finish()
	var mapInfo = get_tree().get_root().get_child(0).find_child("CanvasLayer").find_child("MapInfo")
	mapInfo.load_all(world, world_seed, map, map_seed)

func generate_all(world_seed, map_seed, thread=null):
	var world = generate(world_seed)
	var map = generate(map_seed)
	self.call_deferred("finish_generation", world, world_seed, map, map_seed, thread)
	return

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
