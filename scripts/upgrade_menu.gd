extends CanvasLayer

var container_prefab = preload("res://prefabs/upgrade_container.tscn")
@onready var done_button = $ColorRect/VBoxContainer/Done
func done ():
	visible = false
	get_tree().paused = false

func present ():
	done_button.grab_focus()
	visible = true
	for option in $ColorRect/VBoxContainer/HBoxContainer.get_children():
		option.setup()
	await get_tree().process_frame
	get_tree().paused = true
		
func _ready():
	done_button.grab_focus()
	done_button.connect("button_down", done)
