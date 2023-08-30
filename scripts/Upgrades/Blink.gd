extends Node

@onready var map_info = $"/root/Main/CanvasLayer/MapInfo"
@onready var player = $".."
#@onready var player = $".."
@onready var area = $Area2D
const DISTANCE = 300
const STEPS = 10

# note: potential 'optimization', instantiate all areas along path simultaneously
# only takes one 'tick' but could potentially spawn a lot of colliders
func blink (direction):
	var max_destination = map_info.clamp_bounds(player.position + direction.normalized()*DISTANCE)
	var destination = max_destination
	
	player.get_node("DashTrail").make_trail()
	for s in range(1, STEPS):
		area.global_position = destination
		await get_tree().physics_frame
		if not (area.has_overlapping_areas() or area.has_overlapping_bodies()):
			player.position = destination
			return
		destination = max_destination.lerp(player.position, float(s)/float(STEPS))

# Called when the node enters the scene tree for the first time.
func _ready():
	player.dash_ability = blink
	area.scale = player.scale
	area.add_child(player.get_node("CollisionShape2D").duplicate())
	pass
