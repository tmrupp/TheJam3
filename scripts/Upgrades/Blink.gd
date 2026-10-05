extends Node
## Blink, the move that replaces the dash: the wizard jumps up to `distance` along the held
## direction, to the furthest spot there with room for them. Everything on the way is struck as a
## dash would strike it (DashStrike: the jump happens while the dash runs), and every full moon on
## the way is spent and gives the dash back.

@onready var map_info: MapInfo = $"/root/Main/CanvasLayer/MapInfo"
@onready var player: Player = $".."
#@onready var player = $".."
@onready var area: Area2D = $Area2D
## Set by the blink tier (Abilities.apply).
var distance: int = 300
const STEPS: int = 10

# note: potential 'optimization', instantiate all areas along path simultaneously
# only takes one 'tick' but could potentially spawn a lot of colliders
func blink (direction: Vector2) -> void:
	var max_destination: Vector2 = map_info.clamp_bounds(player.position + direction.normalized()*distance)
	var destination: Vector2 = max_destination
	
	for s: int in range(1, STEPS):
		area.global_position = destination
		await get_tree().physics_frame
		if not (area.has_overlapping_areas() or area.has_overlapping_bodies()):
			var from: Vector2 = player.global_position
			player.position = destination
			_moons(from, player.global_position)
			return
		destination = max_destination.lerp(player.position, float(s)/float(STEPS))

## How near the way a moon has to be to be gathered.
const MOON_REACH: float = 56.0

## Spend every full moon near the way from `from` to `to`.
func _moons(from: Vector2, to: Vector2) -> void:
	for moon: Node in map_info.map_elements.get_children() if map_info.map_elements != null else []:
		if moon.has_method("pass_through"):
			var at: Vector2 = (moon as Node2D).global_position
			if Geometry2D.get_closest_point_to_segment(at, from, to).distance_to(at) <= MOON_REACH:
				moon.call("pass_through")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.dash_ability = blink
	area.scale = player.scale
	area.add_child(player.get_node("CollisionShape2D").duplicate())
