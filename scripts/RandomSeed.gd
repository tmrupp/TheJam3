extends Button

@onready var map_seed = $"../MapSeed"
@onready var world_seed = $"../WorldSeed"

func randomize_seed():
	randomize()
	var new_seed = randi()
	map_seed.text = str(new_seed)
	world_seed.text = str(new_seed)

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("button_up", randomize_seed)
