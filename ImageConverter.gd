extends Node

var icon_path = "res://icon.svg"

func to_array(path):
	var image = Image.load_from_file(path)
	var values = []
	var uniques = {}
	
	for j in image.get_size().x:
		var row = []
		for i in image.get_size().y:
			var pixel = image.get_pixel(i, j)
			if pixel not in uniques:
				uniques[pixel] = len(uniques.keys())
			print("pixel @ (", i, ", ", j, ") = ", pixel, " value=", uniques[pixel])
			row.append(uniques[pixel])
		values.append(row)
		
	return values
	

# Called when the node enters the scene tree for the first time.
func _ready():
#	to_array(icon_path)
	pass # Replace with function body.
