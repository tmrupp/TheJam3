extends TextureRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var button: Button = Button.new()
	button.text = "Click me"
	button.pressed.connect(self._button_pressed)
	add_child(button)


func _button_pressed() -> void:
	get_tree().change_scene("res://path/to/main.tscn")
