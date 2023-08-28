extends CanvasLayer

var container_prefab = preload("res://prefabs/upgrade_container.tscn")

func done ():
	visible = false
	get_tree().paused = false

func present ():
	visible = true
	for option in $ColorRect/VBoxContainer/HBoxContainer.get_children():
		option.setup()
	await get_tree().process_frame
	get_tree().paused = true
		
func _ready():
	$ColorRect/VBoxContainer/Done.connect("button_down", done)
