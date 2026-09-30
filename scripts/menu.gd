extends CanvasLayer
## The start menu, then the pause menu.
## Start: continue the saved run (at its last lit lantern), begin at the world typed in (a random
## one when blank), or begin at a random world. Worlds are shareable: the same number gives the
## same levels for everyone. Paused: resume, copy where you are, or save and exit.

@onready var title: Label = $VBoxContainer/Title
@onready var where: Label = $VBoxContainer/Where
@onready var continue_button: Button = $VBoxContainer/Continue
@onready var start: Button = $VBoxContainer/Start
@onready var random_world: Button = $VBoxContainer/Random
@onready var copy: Button = $VBoxContainer/Copy
@onready var exit: Button = $VBoxContainer/Exit

@onready var randomize_button: Button = $"VBoxContainer/World Seed/Randomize"
@onready var paste: Button = $"VBoxContainer/World Seed/Paste"
@onready var world_seed: LineEdit = $"VBoxContainer/World Seed/LineEdit"
@onready var world_seed_container: Node = $"VBoxContainer/World Seed"

@onready var main: Node = $".."

var player_prefab: Resource = preload("res://prefabs/player.tscn")
var old_focus: Control = null
var started: bool = false


func map_info() -> MapInfo:
	return $"../CanvasLayer/MapInfo" as MapInfo


## Begin a new run at the world typed in (random when blank).
func start_game() -> void:
	_enter_play()
	map_info().start_run(get_seed(world_seed))


func start_random() -> void:
	randomize_seed()
	start_game()


func continue_game() -> void:
	if MapInfo.read_save().is_empty():
		return
	_enter_play()
	map_info().continue_run()


## Leave the start menu: the menu becomes the pause menu and the wizard is created.
func _enter_play() -> void:
	visible = false
	started = true
	for node: Control in [continue_button, world_seed_container, random_world]:
		node.visible = false
	copy.visible = true
	start.text = "Resume"
	start.pressed.disconnect(start_game)
	start.pressed.connect(pause_resume_game)
	exit.text = "Save and exit"
	var player: Player = player_prefab.instantiate()
	main.add_child(player)


func exit_game() -> void:
	if started:
		map_info().save_run()
	get_tree().quit()


## The typed world number; blank or unreadable picks a random world.
func get_seed(input: LineEdit) -> int:
	var text: String = input.text.strip_edges()
	if text.is_valid_int():
		return int(text)
	var n: int = randi_range(1, 99999)
	input.text = str(n)
	return n


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Menu"):
		pause_resume_game()


func pause_resume_game() -> void:
	# Only once a run has started: before that this is the start menu.
	if not started or not main.has_node("Player"):
		return
	if not visible:
		old_focus = get_viewport().gui_get_focus_owner()
		map_info().save_run()
		where.text = MapInfo.where(map_info().coord)
		start.grab_focus()
	elif old_focus != null and is_instance_valid(old_focus):
		old_focus.grab_focus()
	visible = !visible
	get_tree().paused = visible


func randomize_seed() -> void:
	world_seed.text = str(randi_range(1, 99999))


## Copies "world 28 · depth 3", so a place can be shared.
func copy_location() -> void:
	DisplayServer.clipboard_set(MapInfo.where(map_info().coord))


## Accepts a bare number or a copied location ("world 28 · depth 3" gives 28).
func paste_seed() -> void:
	var text: String = DisplayServer.clipboard_get()
	var found: RegEx = RegEx.create_from_string("-?\\d+")
	var m: RegExMatch = found.search(text)
	if m != null:
		world_seed.text = m.get_string()


func _ready() -> void:
	start.pressed.connect(start_game)
	continue_button.pressed.connect(continue_game)
	random_world.pressed.connect(start_random)
	exit.pressed.connect(exit_game)
	randomize_button.pressed.connect(randomize_seed)
	copy.pressed.connect(copy_location)
	paste.pressed.connect(paste_seed)
	var saved: Dictionary = MapInfo.read_save()
	continue_button.visible = not saved.is_empty()
	if saved.is_empty():
		where.text = "go deeper"
		start.grab_focus()
	else:
		var at: Vector2i = saved["respawn_coord"]
		where.text = "saved: %s  ·  deepest %d" % [MapInfo.where(at), int(saved["deepest"])]
		continue_button.grab_focus()
