extends Node

@onready var player = $".."
@onready var area = $Area2D
const DISTANCE = 300
const GRANULARITY = 0.1

func blink (direction):
	var max_destination = player.position + direction.normalized()*DISTANCE
	var destination = max_destination
	var x = 0.0
	while x < 1:
		area.global_position = destination
		await get_tree().physics_frame
		if not (area.has_overlapping_areas() or area.has_overlapping_bodies()):
			player.position = destination
			return
		destination = max_destination.lerp(player.position, x)
		x += GRANULARITY

# Called when the node enters the scene tree for the first time.
func _ready():
	player.dash_ability = blink
	area.scale = player.scale
	area.add_child(player.get_node("CollisionShape2D").duplicate())
	pass
