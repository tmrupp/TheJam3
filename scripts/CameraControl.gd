extends Node

# lerp method
# always lerp the camera to the player
const LERP_SMOOTHNESS = 0.04

# bounding radius lerp method
# only lerp to the player if the camera gets a certain distance away
# once it does, lerp until we're within epsilon of the player
const BOUNDING_RADIUS = 500
const BR_LERP_SMOOTHNESS = 0.0001
const BR_LOWER_THRESHOLD = 20
var currently_lerping = false

# hard camera boundaries
var level_bounds_low = Vector2()
var level_bounds_high = Vector2()
var boundary_buffer = Vector2i(800, 450)

@onready var camera = $"../../Camera2D"
@onready var player = $"../"

func _ready():
	var level_size = $"../../WaveFunctionCollapse".output_size * $"../../TileMap".cell_quadrant_size
	level_bounds_low.x = -1 * $"../../CanvasLayer/MapInfo".X_MARGIN * $"../../TileMap".cell_quadrant_size
	level_bounds_high.x = level_size.x + $"../../CanvasLayer/MapInfo".X_MARGIN * $"../../TileMap".cell_quadrant_size
	level_bounds_low.y = -1 * $"../../CanvasLayer/MapInfo".TOP_MARGIN * $"../../TileMap".cell_quadrant_size
	level_bounds_high.y = level_size.y
	
	
	
	print(level_size)

# Set the position of the camera to lerp the player's position over time
func _process(delta):
	smooth_lerp(delta, LERP_SMOOTHNESS)
	# bounding_radius_lerping(delta)
	
	# enforce camera position boundaries so the area past the level isn't shown
#	if camera.position.x < level_bounds_low.x + boundary_buffer.x:
#		camera.position.x = level_bounds_low.x + boundary_buffer.x
#	elif camera.position.x > level_bounds_high.x - boundary_buffer.x:
#		camera.position.x = level_bounds_high.x - boundary_buffer.x
#
#	if camera.position.y < level_bounds_low.y + boundary_buffer.y:
#		camera.position.y = level_bounds_low.y + boundary_buffer.y
#	elif camera.position.y > level_bounds_high.y - boundary_buffer.y:
#		camera.position.y = level_bounds_high.y - boundary_buffer.y

# Move the camera towards the position of the player
func smooth_lerp(delta, smoothness):
	camera.position = lerp(camera.position, player.position, 1 - pow(smoothness, delta))

# Check if the player/camera distance is above a threshold, lerp if so until we rest on the character again
func bounding_radius_lerping(delta):
	var diff = camera.position - player.position
	print(diff.length())
	if currently_lerping || diff.length() > BOUNDING_RADIUS:
		smooth_lerp(delta, BR_LERP_SMOOTHNESS)
		currently_lerping = true
		
		if diff.length() < BR_LOWER_THRESHOLD:
			currently_lerping = false
