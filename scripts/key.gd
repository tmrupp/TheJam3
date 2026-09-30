extends Area2D
## A key. Keys are never used up: the carried key opens every door of its colour, in any level.
## The player carries one at a time; grabbing another leaves the carried one where the new one
## was (MapInfo records it there). A dropped key arms only once the wizard has been more than
## ARM_DISTANCE from it.

@onready var visuals: Sprite2D = $Sprite2D

@onready var player: Player = $"/root/Main/Player"

@onready var collect_sfx: AudioStreamPlayer = $AudioStreamPlayer

var armed: bool = true
const ARM_DISTANCE: float = 110.0

func setup(_map_info: MapInfo, _v: Vector2) -> void:
	pass

## The key's colour (set by MapInfo when it is placed); doors of the same colour open with it.
func key_color() -> int:
	return int(get_meta(&"key_color", 0))

func touch(other: Node) -> void:
	if armed and other == player and other.get_parent() != null and visuals.visible:
		var had: int = int(player.get_meta(&"carried_key", -1))
		player.set_meta(&"carried_key", key_color())
		RisoFx.burst(&"gain", global_position, Vector2.ZERO, RisoPrint.key_inks(key_color()))
		if MapInfo.instance != null:
			MapInfo.instance.key_taken(self, had)

		# make invisible bc we aren't destroying self immediately
		visuals.visible = false

		# make uncollidable bc we aren't destroying self immediately
		set_collision_layer_value(5, false)
		set_collision_mask_value(7, false)

		# wait to destroy self until after sfx finish playing
		destroy_on_finish_sfx()

func _physics_process(_delta: float) -> void:
	if not armed and player != null and player.global_position.distance_to(global_position) > ARM_DISTANCE:
		armed = true

func destroy_on_finish_sfx() -> void:
	collect_sfx.play()
	await collect_sfx.finished
	queue_free()

func _ready() -> void:
	connect("body_entered", touch)
	armed = not has_meta(&"dropped_id")
