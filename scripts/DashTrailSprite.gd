extends Node2D

# lerp sprite's color modulate over the sprite's lifetime
const START_COLOR = Color.BLUE
const END_COLOR = Color(1, 1, 1, 0)

# time in seconds until destroy self
const LIFETIME = 0.5

@onready var sprite = $"Sprite2D"

var timer

func _ready():
	timer = get_tree().create_timer(LIFETIME)
	change_color()
	self_destruct()

func change_color():
	sprite.modulate = START_COLOR
	while true:
		await get_tree().process_frame
		sprite.modulate = START_COLOR.lerp(END_COLOR, 1 - timer.time_left / LIFETIME)

func self_destruct():
	await timer.timeout
	queue_free()
