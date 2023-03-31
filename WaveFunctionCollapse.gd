extends WaveFunctionCollapse


func _input(event):
#	print("got an event")
	if event.is_action_pressed("Dash"):
		set_size(Vector2i(10, 10))
	if event.is_action_pressed("Jump"):
		print("collapsing")
		var map = collapse()
		print(len(map))
		

# Called when the node enters the scene tree for the first time.
func _ready():
	print("alive!")
	pass # Replace with function body.
