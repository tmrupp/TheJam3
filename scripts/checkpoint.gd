extends Area2D

class_name Checkpoint
## A lantern. Interact to light it: it becomes where you come back to, and absorbs one death; and,
## lit or already lit, it refills the hex's charges and mend's draughts (MapInfo.light_lantern).

@onready var player: Player = Stage.player()

func enabled (val: bool) -> void:
	var spent: bool = MapInfo.instance != null and MapInfo.instance.is_lantern_spent(self)
	$Sprite2D.self_modulate = Color(0.3, 0.3, 0.35) if spent else (Color.GREEN_YELLOW if val else Color.WHITE)

func refresh () -> void:
	enabled(MapInfo.instance != null and MapInfo.instance.is_respawn_lantern(self))
	($Interactable as Interactable).available = (MapInfo.instance == null or not MapInfo.instance.is_lantern_spent(self))

func interacted () -> void:
	# Spent lanterns cannot be relit during this run.
	if MapInfo.instance != null:
		MapInfo.instance.light_lantern(self)
	refresh()

func _ready() -> void:
	$Interactable.connect("interacted", interacted)
	refresh.call_deferred()
