extends Node2D

@onready var player = $"/root/Main/Player"
var active:bool = false

func astral_project():
	if not active:
		print("used the astral projection point named " + name)
		player.astral_projection_signal.emit()
		active = true

func setup(map_info, coord):
	print("hello, I am an astral projection point at: " + str(coord))

func _ready():
	$Area2D/Interactable.interacted.connect(astral_project)
