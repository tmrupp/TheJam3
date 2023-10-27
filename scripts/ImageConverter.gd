extends Node

var icon_path: String = "res://icon.svg"

func to_array(path: String) -> Array[Variant]:
	var image: Image = Image.load_from_file(path)
	var values: Array[Variant] = []
	var uniques: Dictionary = {}
	
	for j: int in image.get_size().x:
		var row: Array[Color] = []
		for i: int in image.get_size().y:
			var pixel: Color = image.get_pixel(i, j)
			if pixel not in uniques:
				uniques[pixel] = len(uniques.keys())
			print("pixel @ (", i, ", ", j, ") = ", pixel, " value=", uniques[pixel])
			row.append(uniques[pixel])
		values.append(row)
		
	return values
