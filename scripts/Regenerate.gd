extends Button

@onready var map_info = $"../../MapInfo"
@onready var world_seed = $"../WorldSeed"
@onready var map_seed = $"../MapSeed"

func get_seed(input):
	return int(input.text)

func regenerate_map():
	map_info.clear_terrain()
	map_info.generate_all(get_seed(world_seed), get_seed(map_seed))

func _ready():
	connect("button_up", regenerate_map)
