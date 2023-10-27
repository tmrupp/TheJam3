extends Node

@onready var map_info: MapInfo = $"/root/Main/CanvasLayer/MapInfo"
@onready var player: Player = $".."
#@onready var player = $".."
@onready var area: Area2D = $Area2D
const DISTANCE: int = 300
const STEPS: int = 10

# note: potential 'optimization', instantiate all areas along path simultaneously
# only takes one 'tick' but could potentially spawn a lot of colliders
func blink (direction: Vector2) -> void:
	var max_destination: Vector2 = map_info.clamp_bounds(player.position + direction.normalized()*DISTANCE)
	var destination: Vector2 = max_destination
	
	player.get_node("DashTrail").make_trail()
	for s: int in range(1, STEPS):
		area.global_position = destination
		await get_tree().physics_frame
		if not (area.has_overlapping_areas() or area.has_overlapping_bodies()):
			player.position = destination
			return
		destination = max_destination.lerp(player.position, float(s)/float(STEPS))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.dash_ability = blink
	area.scale = player.scale
	area.add_child(player.get_node("CollisionShape2D").duplicate())
