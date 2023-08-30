extends Node

@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"
@onready var player = $".."
#@onready var player = $".."
@onready var area = $Area2D
const DISTANCE = 300
const GRANULARITY = 0.1

# note: potential 'optimization', instantiate all areas along path simultaneously
# only takes one 'tick' but could potentially spawn a lot of colliders
func blink (direction):
	var max_destination = player.position + direction.normalized()*DISTANCE
	var destination = max_destination
	var x = 0.0
	
	player.get_node("DashTrail").make_trail()
	while x < 1:
		if map_info.in_bounds(destination):
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
