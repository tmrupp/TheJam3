extends Node

class_name Health

@onready var player: Player = $".."
@onready var hurt_sfx: AudioStreamPlayer = $AudioStreamPlayer
@onready var camera: Camera2D = Stage.camera()

var max_health: int = 3
var health: int = 3
## Debug runs (the debug panel's Invincible): the wizard loses no hearts, from a blow, a fall or
## anything else, though they are still knocked back. Outside debug runs it does nothing.
static var invincible: bool = false

## Whether the wizard loses no hearts just now (invincible, in a debug run).
static func is_invincible() -> bool:
	return invincible and MapInfo.debug

func modify_health (delta: int) -> void:
	if delta < 0 and is_invincible():
		return
	health += delta
	
	if delta < 0:
		hurt_sfx.play()
		camera.shake(15, 0.5)
	
	if health <= 0:
		player.die()

