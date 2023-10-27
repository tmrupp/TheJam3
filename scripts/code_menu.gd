extends CanvasLayer
@onready var input_label: Label = $ColorRect/VBoxContainer/MarginContainer/HBoxContainer/Input
@onready var code_label: Label = $ColorRect/VBoxContainer/MarginContainer2/HBoxContainer/Code
var current_code: String = ""
var secrets: Array = []
var crack: Callable

func enable (display_code: String, possible_secrets: Array, on_crack: Callable) -> void:
	code_label.text = display_code
	current_code = ""
	input_label.text = current_code
	secrets = possible_secrets
	crack = on_crack
	visible = true
	get_tree().paused = true
	
var input_map: Dictionary = {
	"Left": '<',
	"Right": '>',
	"Up": '^',
	"Down": 'v',
}

var input_released: Dictionary = {
	"Left": true,
	"Right": true,
	"Up": true,
	"Down": true,
}

func check_code () -> void:
#	for secret in secrets:
#		print("secret:", secret, " len(secret)=", len(secrets), " current_code=", current_code, " ==:", current_code == secret)
	if secrets.find(current_code) != -1:
		crack.bind(current_code).call_deferred()
		exit()

func exit () -> void:
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	for input: String in input_map:
		if event.is_action_pressed(input) and input_released[input]:
			current_code += input_map[input]
			input_label.text = current_code
			input_released[input] = false
			
		if event.is_action_released(input):
			input_released[input] = true
	
	if event.is_action_pressed("Discover"):
		check_code()
	
	#TODO: should be 'back' or something
	if event.is_action_pressed("Back"):
		if len(current_code) == 0:
			exit()
		else:
			current_code = current_code.left(-1)
			input_label.text = current_code
	
				
