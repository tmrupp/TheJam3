extends Area2D
## The ghost left where the player died, holding every star they carried. Touching it gives
## them back and restores full health. Lantern protection is restored by lighting another lantern.
## MapInfo owns the ghost and respawns it with its level.
## It arms only once the wizard has been clear of it (more than ARM_DISTANCE away), so dying on
## the lantern does not hand it straight back. Distance, not overlap: the wizard's collision is
## off while a level reloads, so an overlap test would arm it too early.

@onready var player: Player = $"/root/Main/Player"

var stars: int = 0
var armed: bool = false
const ARM_DISTANCE: float = 110.0

func touch (other: Node) -> void:
	if armed and other == player and MapInfo.instance != null:
		MapInfo.instance.recover_ghost()

func _physics_process(_delta: float) -> void:
	if not armed and player != null and player.global_position.distance_to(global_position) > ARM_DISTANCE:
		armed = true
		# Already inside the area when arming (e.g. a fast pass): take it now.
		if overlaps_body(player):
			touch(player)

func _ready() -> void:
	connect("body_entered", touch)
