extends CanvasLayer

var container_prefab: Resource = preload("res://prefabs/upgrade_container.tscn")

@onready var done_button: Button = $ColorRect/VBoxContainer/Done
func done () -> void:
	visible = false
	get_tree().paused = false

func present () -> void:
	done_button.grab_focus()
	visible = true
	for option: Node in $ColorRect/VBoxContainer/HBoxContainer.get_children():
		option.setup()
	await get_tree().process_frame
	get_tree().paused = true
		
func _ready() -> void:
	done_button.grab_focus()
	done_button.connect("button_down", done)
