extends WaveFunctionCollapse

func generate(def: MapInfo.NextWorldDef) -> Array:
	set_seed(def.gen_seed)
	seed(def.gen_seed)
	texture = load(def.region)
	var map: Array = collapse()
	while len(map) == 0:
		seed = randi()
		map = collapse()
	return map

func finish_generation(world: Array, world_seed: MapInfo.NextWorldDef, map: Array, map_seed: MapInfo.NextWorldDef, thread: Thread) -> void:
	if thread != null:
		thread.wait_to_finish()
	var mapInfo: MapInfo = get_tree().get_root().get_child(0).find_child("CanvasLayer").find_child("MapInfo")
	mapInfo.load_all(world, world_seed, map, map_seed)

func generate_all(world_seed: MapInfo.NextWorldDef, map_seed: MapInfo.NextWorldDef, thread: Thread=null) -> void:
	var world: Array = generate(world_seed)
	var map: Array = generate(map_seed)
	self.call_deferred("finish_generation", world, world_seed, map, map_seed, thread)
	return
