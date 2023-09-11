extends Area2D

@onready var player = $/root/Main/Player
@onready var code_menu = $"/root/Main/CodeMenu"
@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"
@onready var door = $".."

func crack (key):
	map_info.remove_valid_key(key)
	door.queue_free()

var touching = false
func untouch(other):
	if (other == player and other.get_parent() != null):
		touching = false
	
func touch(other):
	if (other == player and other.get_parent() != null):
		touching = true
		
func _input(event):
	if touching:
#		print("event=", event.as_text(), " event.is_action_pressed(\"Discover\")=", event.is_action_pressed("Discover"), " touching=", touching)
		if event.is_action_pressed("Discover"):
			code_menu.enable("", map_info.valid_keys, crack)
		

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("body_entered", touch)
	connect("body_exited", untouch)
