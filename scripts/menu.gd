extends CanvasLayer

@onready var start : Button = $VBoxContainer/Start
@onready var exit : Button = $VBoxContainer/Exit
@onready var wfc : WaveFunctionCollapse = $"../WaveFunctionCollapse"

@onready var randomize_button : Button = $"VBoxContainer/World Seed/Randomize"
@onready var copy : Button = $"VBoxContainer/World Seed/Copy"
@onready var paste : Button = $"VBoxContainer/Map Seed/Paste"

@onready var world_seed: LineEdit = $"VBoxContainer/World Seed/LineEdit"
@onready var map_seed: LineEdit = $"VBoxContainer/Map Seed/LineEdit"

@onready var world_seed_container: Node = $"VBoxContainer/World Seed"
@onready var map_seed_container: Node = $"VBoxContainer/Map Seed"

@onready var main: Node = $".."
@onready var wfc_thread: Thread = Thread.new()

func start_game() -> void:
	wfc_thread.start(wfc.generate_all.bind(
		MapInfo.default_def(get_seed(world_seed)), 
		MapInfo.default_def(get_seed(map_seed)), 
		wfc_thread))
	visible = false
	
	# We're repurposing the menu now from a 'main menu' to a 'pause menu'
	start.text = "Resume"
	start.pressed.disconnect(start_game)
	start.pressed.connect(pause_resume_game)
	start.focus_neighbor_bottom = exit.get_path()
	exit.focus_neighbor_top = start.get_path()
	world_seed_container.visible = false
	map_seed_container.visible = false
	
func exit_game() -> void:
	get_tree().quit()

func get_seed(input: LineEdit) -> int:
	return int(input.text)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Menu"):
		pause_resume_game()

func pause_resume_game() -> void:
	# this check prevents the user from deactivating the menu when the game hasn't started
	# by checking if the scene has a 'player' in it
	if main.has_node("Player"): #!= null:
		visible = !visible
		get_tree().paused = visible
		start.grab_focus()

func randomize_seed () -> void:
	world_seed.text = str(randi())

func copy_seed () -> void:
	DisplayServer.clipboard_set(world_seed.text)

func paste_seed () -> void:
	map_seed.text = DisplayServer.clipboard_get()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start.pressed.connect(start_game)
	exit.pressed.connect(exit_game)
	randomize_button.pressed.connect(randomize_seed)
	copy.pressed.connect(copy_seed)
	paste.pressed.connect(paste_seed)
	start.grab_focus()
