extends Area2D

@onready var visuals: Sprite2D = $Sprite2D

@onready var player: Player = $"/root/Main/Player"

@onready var collect_sfx: AudioStreamPlayer = $AudioStreamPlayer

@export var code : String
func setup(_map_info: MapInfo, _v: Vector2) -> void:
	code = _map_info.get_next_key()

## The key's colour (set by MapInfo when it is placed); doors of the same colour open with it.
func key_color() -> int:
	return int(get_meta(&"key_color", 0))

func touch(other: Node) -> void:
	if (other == player and other.get_parent() != null and visuals.visible):
		# one key at a time: a new key replaces the one being carried
		player.set_meta(&"carried_key", key_color())
		RisoFx.burst(&"gain", global_position, Vector2.ZERO, RisoPrint.key_inks(key_color()))

		# make invisible bc we aren't destroying self immediately
		visuals.visible = false

		# make uncollidable bc we aren't destroying self immediately
		set_collision_layer_value(5, false)
		set_collision_mask_value(7, false)

		# wait to destroy self until after sfx finish playing
		destroy_on_finish_sfx()

func destroy_on_finish_sfx() -> void:
	collect_sfx.play()
	await collect_sfx.finished
	queue_free()

func _ready() -> void:
	connect("body_entered", touch)

