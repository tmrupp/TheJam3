extends WaveFunctionCollapse

# func to_uniques(data):
# 	var uniques = {255:0} # 255 is always 0
	
# 	var values = []
# 	for i in range(len(data)):
# 		var row = []
# 		for j in range(len(data[i])):
# 			var pixel = data[i][j]
# 			if pixel not in uniques:
# 				uniques[pixel] = len(uniques.keys())
# #			print("pixel @ (", i, ", ", j, ") = ", pixel, " value=", uniques[pixel])
# 			row.append(uniques[pixel])
# 		values.append(row)
		
# 	return values

func generate(in_seed: int):
	set_seed(in_seed)
	seed(in_seed)
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

func generate_all(world_seed: int, map_seed: int, thread=null):
	var world = generate(world_seed)
	var map = generate(map_seed)
	self.call_deferred("finish_generation", world, world_seed, map, map_seed, thread)
	return

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
