extends Area2D

@onready var player: Player = $"/root/Main/Player"
@onready var door: Node = $".."

## The door's colour (set by MapInfo when it is placed); only a key of the same colour opens it.
func door_color() -> int:
	return int(door.get_meta(&"key_color", 0))

func try_open() -> void:
	if player.has_meta(&"carried_key") and int(player.get_meta(&"carried_key")) == door_color():
		RisoPrint.door_opened(door as Node2D)
		if MapInfo.instance != null:
			MapInfo.instance.mark_opened(door)
		door.queue_free()

func interacted () -> void:
	try_open()

func touch (other: Node) -> void:
	if other == player:
		try_open()

func _ready() -> void:
	$Interactable.connect("interacted", interacted)
	connect("body_entered", touch)
