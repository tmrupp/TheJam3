extends Area2D

@onready var player: Player = $"/root/Main/Player"

func _ready() -> void:
	connect("body_entered", touch)

func touch(other: Node) -> void:
	if other == player:
		$"/root/Main/CanvasLayer/MapInfo".discover_random_chunk()
		queue_free()
