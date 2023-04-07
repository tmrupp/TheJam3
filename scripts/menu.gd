extends CanvasLayer

@onready var start : Button = $VBoxContainer/Start
@onready var exit : Button = $VBoxContainer/Exit
@onready var wfc : WaveFunctionCollapse = $"../WaveFunctionCollapse"

@onready var world_seed = $"VBoxContainer/World Seed/LineEdit"
@onready var map_seed = $"VBoxContainer/Map Seed/LineEdit"

var player = preload("res://prefabs/player.tscn")
var player_instance

@onready var main = $".."

func start_game():
	wfc.set_seed(get_seed(world_seed))
	wfc.generate()
	
	visible = false
	if player_instance == null:
		player_instance = player.instantiate()
		main.add_child(player_instance)
	pass
	
func exit_game():
	get_tree().quit()
	pass

func get_seed(input):
	return int(input.text)

func _input(event):
	if event.is_action_pressed("Menu"):
		if player_instance != null:
			visible = !visible

# Called when the node enters the scene tree for the first time.
func _ready():
	start.pressed.connect(start_game)
	exit.pressed.connect(exit_game)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
