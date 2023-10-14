extends Area2D

@onready var player = $/root/Main/Player
@onready var code_menu = $"/root/Main/CodeMenu"
@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"
@onready var door = $".."

func crack (key):
	map_info.remove_valid_key(key)
	door.queue_free()

func interacted ():
	code_menu.enable("", map_info.valid_keys, crack)

func _ready():
	$Interactable.connect("interacted", interacted)
