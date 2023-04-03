extends Button

@onready var world_seed = $"../World Seed/LineEdit"
@onready var map_seed = $"../World Seed/LineEdit"
@onready var game_scene = preload("res://main.tscn")

func get_seed(input):
	return int(input.text)

func _pressed():
	print("world seed=", get_seed(world_seed))
#	game_scene.
	pass
