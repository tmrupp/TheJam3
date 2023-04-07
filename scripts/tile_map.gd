extends TileMap
var coordLabel = preload("res://coord_label.tscn")
@onready var main = $"../.."

func display(cells, patterns):
	for x in range(len(cells)):
		for y in range(len(cells[x])):
			var label = coordLabel.instantiate()
			main.add_child.call_deferred(label)
			label.position = map_to_local(Vector2i(x, y))
			label.text = str(Vector2i(x, y)) + ", " + str(cells[x][y][0])
			

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
#	print("AHHHHH")
#	for x in range(100):
#		for y in range(100):
#			var label = coordLabel.instantiate()
#			main.add_child.call_deferred(label)
#			label.position = map_to_local(Vector2i(x, y))
#			label.text = str(Vector2i(x, y))
			
