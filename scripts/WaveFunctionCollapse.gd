extends WaveFunctionCollapse

func to_uniques(data):
	var uniques = {255:0} # 255 is always 0
	
	var values = []
	for i in range(len(data)):
		var row = []
		for j in range(len(data[i])):
			var pixel = data[i][j]
			if pixel not in uniques:
				uniques[pixel] = len(uniques.keys())
#			print("pixel @ (", i, ", ", j, ") = ", pixel, " value=", uniques[pixel])
			row.append(uniques[pixel])
		print("len(row)=", len(row))
		values.append(row)
		
	return values

func generate(seed: int):
	set_seed(seed)
	seed(seed)
	var map = to_uniques(collapse())
	while len(map) == 0:
		seed = randi()
		map = to_uniques(collapse())
	return map

	
func generate_all(world_seed: int, map_seed: int):
	var mapInfo = get_tree().get_root().get_child(0).find_child("CanvasLayer").find_child("MapInfo")
	mapInfo.load_all(generate(world_seed), generate(map_seed))

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
