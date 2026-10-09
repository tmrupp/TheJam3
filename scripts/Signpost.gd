extends Node2D
class_name Signpost
## A signpost: walking up to it is enough to read it. A card opens over it with the place (its
## marks and numbers) and the abilities known, and closes as the wizard walks on. Nothing places
## one in the levels for now; it is kept for later uses (prefabs/signpost.tscn, art in SignArt).

## How close the wizard must stand to read it, across and up or down (world pixels).
const READ_REACH: Vector2 = Vector2(110, 120)

## Whether the wizard is near enough to read it now.
var reading: bool = false


func _process(_delta: float) -> void:
	var player: Player = Stage.player()
	if player == null:
		reading = false
		return
	var d: Vector2 = (player.global_position - global_position).abs()
	reading = d.x < READ_REACH.x and d.y < READ_REACH.y
