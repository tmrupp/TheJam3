extends Area2D
## The ghost left where the player died, holding every star they carried. Touching it gives
## them back and ends the vulnerable state. MapInfo owns it and respawns it with its level.
## It arms only once the player is clear of it, so dying on the lantern does not hand it back.

@onready var player: Player = $"/root/Main/Player"

var stars: int = 0
var armed: bool = false

func touch (other: Node) -> void:
	if armed and other == player and MapInfo.instance != null:
		MapInfo.instance.recover_ghost()

func left (other: Node) -> void:
	if other == player:
		armed = true

func _ready() -> void:
	connect("body_entered", touch)
	connect("body_exited", left)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree() and not overlaps_body(player):
		armed = true
