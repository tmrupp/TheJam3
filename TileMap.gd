extends TileMap
var coordLabel = preload("res://coord_label.tscn")
@onready var main = $"../.."

# Called when the node enters the scene tree for the first time.
func _ready():
	print("AHHHHH")
	for x in range(100):
		for y in range(100):
			var label = coordLabel.instantiate()
			main.add_child.call_deferred(label)
			label.position = map_to_local(Vector2i(x, y))
			label.text = str(Vector2i(x, y))
			
