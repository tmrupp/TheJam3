extends CanvasLayer

@onready var start : Button = $VBoxContainer/Start
@onready var exit : Button = $VBoxContainer/Exit
@onready var wfc : WaveFunctionCollapse = $"../WaveFunctionCollapse"

@onready var randomize_button : Button = $"VBoxContainer/World Seed/Randomize"
@onready var copy : Button = $"VBoxContainer/World Seed/Copy"
@onready var paste : Button = $"VBoxContainer/Map Seed/Paste"

@onready var world_seed = $"VBoxContainer/World Seed/LineEdit"
@onready var map_seed = $"VBoxContainer/Map Seed/LineEdit"

@onready var main = $".."
@onready var wfc_thread = Thread.new()

func start_game():
	wfc_thread.start(wfc.generate_all.bind(get_seed(world_seed), get_seed(map_seed), wfc_thread))
	visible = false
	
func exit_game():
	get_tree().quit()

func get_seed(input):
	return int(input.text)

func _input(event):
	if event.is_action_pressed("Menu"):
		if main.has_node("Player"): #!= null:
			visible = !visible

func randomize_seed ():
	world_seed.text = str(randi())

func copy_seed ():
	DisplayServer.clipboard_set(world_seed.text)

func paste_seed ():
	map_seed.text = DisplayServer.clipboard_get()

# Called when the node enters the scene tree for the first time.
func _ready():
	start.pressed.connect(start_game)
	exit.pressed.connect(exit_game)
	randomize_button.pressed.connect(randomize_seed)
	copy.pressed.connect(copy_seed)
	paste.pressed.connect(paste_seed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
