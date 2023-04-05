extends Button

@onready var world_seed = $"../World Seed/LineEdit"
@onready var map_seed = $"../World Seed/LineEdit"
@onready var game_scene = preload("res://main.tscn")
var player = preload("res://player.tscn")
var player_instance

@onready var menu = $"../.."

@onready var main = get_tree().get_root().get_child(0)
var wfc

func _ready():
	wfc = main.find_child("WaveFunctionCollapse")
	
	pass

func get_seed(input):
	return int(input.text)
	
func _input(event):
	if event.is_action_pressed("Menu"):
		if player_instance != null:
			menu.visible = !menu.visible
			

func _pressed():
	print("world seed=", get_seed(world_seed))
	print(main)
	print(wfc)
	wfc.set_seed(get_seed(world_seed))
	wfc.generate()
	
	menu.visible = false
	if player_instance == null:
		player_instance = player.instantiate()
		main.add_child(player_instance)
#	game_scene.
	pass
