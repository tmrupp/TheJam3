extends CanvasLayer

var container_prefab: Resource = preload("res://prefabs/upgrade_container.tscn")

@onready var done_button: Button = $ColorRect/VBoxContainer/Done
func done () -> void:
	visible = false
	get_tree().paused = false

func present (choose_one:bool=false) -> void:
	done_button.grab_focus()
	visible = true
	var i: int = 0
	for option: Node in $ColorRect/VBoxContainer/HBoxContainer.get_children():
		option.setup(choose_one, i)
		i += 1
	await get_tree().process_frame
	get_tree().paused = true
		
func _ready() -> void:
	done_button.grab_focus()
	done_button.connect("button_down", done)
