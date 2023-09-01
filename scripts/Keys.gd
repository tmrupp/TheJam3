extends VBoxContainer

@onready var entry = $KeyEntry

func add_key (code):
	var new_entry = entry.duplicate()
	new_entry.get_node("Label").text = code
	add_child(new_entry)
