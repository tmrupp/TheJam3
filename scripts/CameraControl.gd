extends Node
class_name CameraControl
## Steers the camera after the wizard (to `target_location`, ahead of them the way they face). While
## thorns have struck them and they are gone a moment (Player.held), the view holds still.

# lerp method
# always lerp the camera to the player
const LERP_SMOOTHNESS: float = 0.04

@onready var camera: Camera2D = $"../../Camera2D"
@onready var player: Player = $"../"

# position we track to with the camera
var target_location: Vector2
const HORIZONTAL_OFFSET: int = 200
const VERTICAL_OFFSET: int = 100

## Cut the view to `wizard` at once, rather than sweeping across the level (a teleport, a warp).
static func snap(wizard: Player) -> void:
	var control: CameraControl = wizard.get_node_or_null("CameraControl") as CameraControl
	var view: Camera2D = Stage.camera()
	if control != null:
		control.target_location = wizard.position
	if view != null:
		view.position = wizard.position
		view.reset_smoothing()

func _ready() -> void:
	# Camera limits are fitted to each level (LevelLoader.lay_terrain).
	player.direction_signal.connect(update_target)
	target_location = player.position

# Set the position of the camera to lerp the player's position over time
func _process(delta: float) -> void:
	if player.held > 0.0:
		return
	smooth_lerp(delta, LERP_SMOOTHNESS)

# Move the camera towards the position of the player
func smooth_lerp(delta: float, smoothness: float) -> void:
	camera.position = lerp(camera.position, target_location, 1 - pow(smoothness, delta))

# change place camera is looking based on direction player is facing
func update_target(direction: Vector2) -> void:
	var horizontal_multiplier: int = 0
	if direction.x > 0.1:
		horizontal_multiplier = 1
	elif direction.x < -0.1:
		horizontal_multiplier = -1
		
	var vertical_multiplier: int = 0
	if direction.y < -0.1:
		vertical_multiplier = -1
	elif direction.y > 0.1:
		vertical_multiplier = 1
		
	target_location = player.position + Vector2(0, VERTICAL_OFFSET * vertical_multiplier)
	
	if horizontal_multiplier != 0:
		target_location += Vector2(HORIZONTAL_OFFSET * horizontal_multiplier, 0)
