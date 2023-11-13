extends Button

@onready var world_seed: LineEdit = $"../World Seed/LineEdit"
@onready var map_seed: LineEdit = $"../World Seed/LineEdit"
var player_instance: Node

@onready var menu: CanvasItem = $"../.."

@onready var main: Node = get_tree().get_root().get_child(0)
var wfc: WaveFunctionCollapse

func _ready() -> void:
	wfc = main.find_child("WaveFunctionCollapse")

func get_seed(input: LineEdit) -> int:
	return int(input.text)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Menu"):
		if player_instance != null:
			menu.visible = !menu.visible
			

func _pressed() -> void:
	print("world seed=", get_seed(world_seed))
	print(main)
	print(wfc)
	wfc.set_seed(get_seed(world_seed))
	wfc.generate()
	
	menu.visible = false
