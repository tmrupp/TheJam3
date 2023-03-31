extends WaveFunctionCollapse


func to_uniques(data):
	var uniques = {}
	
	var values = []
	for j in range(len(data)):
		var row = []
		for i in range(len(data[j])):
			var pixel = data[i][j]
			if pixel not in uniques:
				uniques[pixel] = len(uniques.keys())
			print("pixel @ (", i, ", ", j, ") = ", pixel, " value=", uniques[pixel])
			row.append(uniques[pixel])
		values.append(row)
		
	return values

# Called when the node enters the scene tree for the first time.
func _ready():
	var mapInfo = get_tree().get_root().get_child(0).find_child("CanvasLayer").find_child("MapInfo")
	var map = to_uniques(collapse())
	mapInfo.load_all(map, map)
	pass
