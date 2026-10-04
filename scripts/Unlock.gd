extends Area2D

@onready var player: Player = $"/root/Main/Player"
@onready var door: Node = $".."

## The door's colour (set by MapInfo when it is placed); only a key of the same colour opens it.
func door_color() -> int:
	return int(door.get_meta(&"key_color", 0))

## Open with a carried key of the door's colour; when `skeleton`, failing that, with a skeleton key
## (used up). Touching the door never spends a skeleton key; interacting with it does.
func try_open(skeleton: bool = false) -> void:
	if not KeyRing.has(player, door_color()) and not (skeleton and KeyRing.spend_skeleton(player)):
		return
	RisoPrint.door_opened(door as Node2D)
	if MapInfo.instance != null:
		MapInfo.instance.mark_opened(door)
		MapInfo.instance.save_run()
	door.queue_free()

func interacted () -> void:
	try_open(true)

func touch (other: Node) -> void:
	if other == player:
		try_open()

func _ready() -> void:
	$Interactable.connect("interacted", interacted)
	connect("body_entered", touch)
