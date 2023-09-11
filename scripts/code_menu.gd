extends CanvasLayer
@onready var input_label = $ColorRect/VBoxContainer/MarginContainer/HBoxContainer/Input
@onready var code_label = $ColorRect/VBoxContainer/MarginContainer2/HBoxContainer/Code
var current_code = ""
var secrets = []
var crack

func enable (display_code, possible_secrets, on_crack):
	code_label.text = display_code
	current_code = ""
	input_label.text = current_code
	secrets = possible_secrets
	crack = on_crack
	visible = true
	get_tree().paused = true
	
var input_map = {
	"Left": '<',
	"Right": '>',
	"Up": '^',
	"Down": 'v',
}

func check_code ():
#	for secret in secrets:
#		print("secret:", secret, " len(secret)=", len(secrets), " current_code=", current_code, " ==:", current_code == secret)
	if secrets.find(current_code) != -1:
		crack.bind(current_code).call_deferred()
		exit()

func exit ():
	visible = false
	get_tree().paused = false

func _input(event):
	for input in input_map:
		if event.is_action_pressed(input):
			current_code += input_map[input]
			input_label.text = current_code
			check_code()
	
	#TODO: should be 'back' or something
	if event.is_action_pressed("Back"):
		if len(current_code) == 0:
			exit()
		else:
			current_code = current_code.left(-1)
			input_label.text = current_code
	
				
