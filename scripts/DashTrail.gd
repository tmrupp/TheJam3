extends Node

@onready var dash_trail_sprite: Resource = preload("res://prefabs/DashTrailSprite.tscn")
@onready var sprite2d_to_use: Sprite2D = $"../Sprite2D"
@onready var player: Player = $"../"
@onready var root: Node = $"../../"

const TIME_BETWEEN_ELEMENTS: float = 0.05

var continue_making_trail: bool = false
	
func make_trail() -> void:
	continue_making_trail = true
	make_trail_element()
	while continue_making_trail:
		await get_tree().create_timer(TIME_BETWEEN_ELEMENTS).timeout
		make_trail_element()

func stop_trail() -> void:
	continue_making_trail = false
	
func make_trail_element() -> void:
	var trail: Node = dash_trail_sprite.instantiate()
	var sprite_copy: Node = sprite2d_to_use.duplicate()
	trail.position = player.position
	trail.scale = player.scale
	trail.add_child(sprite_copy)
	root.add_child(trail)
