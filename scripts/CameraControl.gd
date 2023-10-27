extends Node

# lerp method
# always lerp the camera to the player
const LERP_SMOOTHNESS: float = 0.04

# bounding radius lerp method
# only lerp to the player if the camera gets a certain distance away
# once it does, lerp until we're within epsilon of the player
const BOUNDING_RADIUS: int = 500
const BR_LERP_SMOOTHNESS: float = 0.0001
const BR_LOWER_THRESHOLD: int = 20
var currently_lerping: bool = false

@onready var camera: Camera2D = $"../../Camera2D"
@onready var player: Player = $"../"

# position we track to with the camera
var target_location: Vector2
const HORIZONTAL_OFFSET: int = 200
const VERTICAL_OFFSET: int = 100

func _ready() -> void:
	var tilemap_scale: Vector2i = Vector2i($"../../TileMap".scale)
	var level_size: Vector2i = $"../../WaveFunctionCollapse".output_size * $"../../TileMap".tile_set.tile_size * tilemap_scale
	camera.limit_left = -1 * $"../../CanvasLayer/MapInfo".X_MARGIN * $"../../TileMap".tile_set.tile_size.x * tilemap_scale.x
	camera.limit_right = level_size.x + $"../../CanvasLayer/MapInfo".X_MARGIN * $"../../TileMap".tile_set.tile_size.x * tilemap_scale.x
	camera.limit_top = -1 * $"../../CanvasLayer/MapInfo".TOP_MARGIN * $"../../TileMap".tile_set.tile_size.y * tilemap_scale.y
	camera.limit_bottom = level_size.y + 1 * $"../../TileMap".tile_set.tile_size.y * tilemap_scale.y
	player.direction_signal.connect(update_target)
	target_location = player.position

# Set the position of the camera to lerp the player's position over time
func _process(delta: float) -> void:
	smooth_lerp(delta, LERP_SMOOTHNESS)
	# bounding_radius_lerping(delta)

# Move the camera towards the position of the player
func smooth_lerp(delta: float, smoothness) -> void:
	camera.position = lerp(camera.position, target_location, 1 - pow(smoothness, delta))

# Check if the player/camera distance is above a threshold, lerp if so until we rest on the character again
func bounding_radius_lerping(delta: float) -> void:
	var diff: Vector2 = camera.position - target_location
	if currently_lerping || diff.length() > BOUNDING_RADIUS:
		smooth_lerp(delta, BR_LERP_SMOOTHNESS)
		currently_lerping = true
		
		if diff.length() < BR_LOWER_THRESHOLD:
			currently_lerping = false

# change place camera is looking based on direction player is facing
func update_target(direction):
	var horizontal_multiplier = 0
	if direction.x > 0.1:
		horizontal_multiplier = 1
	elif direction.x < -0.1:
		horizontal_multiplier = -1
		
	var vertical_multiplier = 0
	if direction.y < -0.1:
		vertical_multiplier = -1
	elif direction.y > 0.1:
		vertical_multiplier = 1
		
	target_location = player.position + Vector2(0, VERTICAL_OFFSET * vertical_multiplier)
	
	if horizontal_multiplier != 0:
		target_location += Vector2(HORIZONTAL_OFFSET * horizontal_multiplier, 0)
