extends Node2D

# lerp sprite's color modulate over the sprite's lifetime
const START_COLOR: Color = Color.BLUE
const END_COLOR: Color = Color(1, 1, 1, 0)

# time in seconds until destroy self
const LIFETIME: float = 0.5

@onready var sprite: Sprite2D = $"Sprite2D"

var timer: SceneTreeTimer

func _ready() -> void:
	timer = get_tree().create_timer(LIFETIME)
	change_color()
	self_destruct()

func change_color() -> void:
	sprite.modulate = START_COLOR
	while true:
		await get_tree().process_frame
		sprite.modulate = START_COLOR.lerp(END_COLOR, 1 - timer.time_left / LIFETIME)

func self_destruct() -> void:
	await timer.timeout
	queue_free()
