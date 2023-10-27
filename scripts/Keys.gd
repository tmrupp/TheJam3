extends VBoxContainer

@onready var entry: Node = $KeyEntry

func add_key (code: String) -> void:
	var new_entry: Node = entry.duplicate()
	new_entry.get_node("Label").text = code
	add_child(new_entry)
