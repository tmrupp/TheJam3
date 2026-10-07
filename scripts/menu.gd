extends CanvasLayer
## The start menu, then the pause menu.
## Start: continue the saved run (at its last lit lantern), begin at the world typed in (a random
## one when blank), or begin at a random world. Worlds are shareable: the same number gives the
## same levels for everyone. Paused: resume, copy where you are, give up (while a lantern protects
## you: a death, back to the lantern, for when you are stuck), save and go back to the start menu,
## or save and exit. Works by controller: D-pad or left stick to move, A to choose, Start to pause,
## B to back out of the pause menu.

@onready var title: Label = $VBoxContainer/Title
@onready var where: Label = $VBoxContainer/Where
@onready var continue_button: Button = $VBoxContainer/Continue
@onready var start: Button = $VBoxContainer/Start
@onready var random_world: Button = $VBoxContainer/Random
@onready var copy: Button = $VBoxContainer/Copy
@onready var give_up_button: Button = $VBoxContainer/GiveUp
@onready var main_menu: Button = $VBoxContainer/MainMenu
@onready var debug_button: Button = $VBoxContainer/Debug
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
	if RunState.read_save().is_empty():
		return
	_enter_play()
	map_info().continue_run()


## Leave the start menu: the menu becomes the pause menu and the wizard is created.
func _enter_play() -> void:
	visible = false
	started = true
	for node: Control in [continue_button, world_seed_container, random_world, debug_button]:
		node.visible = false
	copy.visible = true
	main_menu.visible = true
	start.text = "Resume"
	start.pressed.disconnect(start_game)
	start.pressed.connect(pause_resume_game)
	exit.text = "Save and exit"
	var player: Player = player_prefab.instantiate()
	main.add_child(player)


## Save the run and go back to the start menu: the whole main scene is rebuilt fresh (as at launch),
## so nothing of the run in progress lingers, and Continue picks it up again.
func return_to_menu() -> void:
	if started:
		map_info().save_run()
	var tree: SceneTree = get_tree()
	tree.paused = false
	var old: Node = main
	var parent: Node = old.get_parent()
	var path: String = old.scene_file_path
	(func() -> void:
		# Out of the way first, so the new scene takes the name "Main" its nodes look each other up by.
		old.name = "MainLeaving"
		parent.remove_child(old)
		old.queue_free()
		var fresh: Node = (load(path) as PackedScene).instantiate()
		parent.add_child(fresh)
		tree.current_scene = fresh
	).call_deferred()


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
		get_viewport().set_input_as_handled()
	elif visible and started and event.is_action_pressed("ui_cancel"):
		# B (or another cancel) backs out of the pause menu.
		pause_resume_game()
		get_viewport().set_input_as_handled()


## Menus by controller: the project binds the UI actions to the D-pad only, so add the left stick
## (and make sure B cancels). The D-pad and A already work.
static func ensure_controller_ui() -> void:
	for pair: Array in [[&"ui_up", JOY_AXIS_LEFT_Y, -1.0], [&"ui_down", JOY_AXIS_LEFT_Y, 1.0], [&"ui_left", JOY_AXIS_LEFT_X, -1.0], [&"ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var has: bool = false
		for e: InputEvent in InputMap.action_get_events(pair[0]):
			if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == pair[1]:
				has = true
		if not has:
			var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
			stick.axis = pair[1]
			stick.axis_value = pair[2]
			InputMap.action_add_event(pair[0], stick)
	var has_b: bool = false
	for e: InputEvent in InputMap.action_get_events(&"ui_cancel"):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			has_b = true
	if not has_b:
		var b: InputEventJoypadButton = InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_B
		InputMap.action_add_event(&"ui_cancel", b)


func pause_resume_game() -> void:
	# Only once a run has started: before that this is the start menu.
	if not started or not main.has_node("Player"):
		return
	if not visible:
		old_focus = get_viewport().gui_get_focus_owner()
		map_info().save_run()
		where.text = Rules.where(map_info().coord)
		give_up_button.visible = map_info().can_give_up()
		start.grab_focus()
	elif old_focus != null and is_instance_valid(old_focus):
		old_focus.grab_focus()
	visible = !visible
	get_tree().paused = visible


## Debug runs start rich, with every exit next to the spawn (see MapInfo.debug).
func set_debug(on: bool) -> void:
	MapInfo.debug = on
	debug_button.text = "debug: on" if on else "debug: off"


func randomize_seed() -> void:
	world_seed.text = str(randi_range(1, 99999))


## Stuck (say, down a pit): die on purpose and come back at the lit lantern. Only offered while a
## lantern protects the wizard (see MapInfo.give_up).
func give_up() -> void:
	if not map_info().can_give_up():
		return
	pause_resume_game()
	map_info().give_up()


## Copies "world 28 · depth 3", so a place can be shared.
func copy_location() -> void:
	DisplayServer.clipboard_set(Rules.where(map_info().coord))


## Accepts a bare number or a copied location ("world 28 · depth 3" gives 28).
func paste_seed() -> void:
	var text: String = DisplayServer.clipboard_get()
	var found: RegEx = RegEx.create_from_string("-?\\d+")
	var m: RegExMatch = found.search(text)
	if m != null:
		world_seed.text = m.get_string()


func _ready() -> void:
	ensure_controller_ui()
	start.pressed.connect(start_game)
	continue_button.pressed.connect(continue_game)
	random_world.pressed.connect(start_random)
	exit.pressed.connect(exit_game)
	randomize_button.pressed.connect(randomize_seed)
	copy.pressed.connect(copy_location)
	give_up_button.pressed.connect(give_up)
	main_menu.pressed.connect(return_to_menu)
	paste.pressed.connect(paste_seed)
	debug_button.toggled.connect(set_debug)
	set_debug(false)
	var saved: Dictionary = RunState.read_save()
	continue_button.visible = not saved.is_empty()
	if saved.is_empty():
		where.text = "go deeper"
		start.grab_focus()
	else:
		var at: Vector2i = saved["respawn_coord"]
		where.text = "saved: %s  ·  deepest %d" % [Rules.where(at), int(saved["deepest"])]
		continue_button.grab_focus()
