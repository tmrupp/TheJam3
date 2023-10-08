extends Node

@onready var dash_trail_sprite = preload("res://prefabs/DashTrailSprite.tscn")
@onready var sprite2d_to_use = $"../Sprite2D"
@onready var player = $"../"
@onready var root = $"../../"

const TIME_BETWEEN_ELEMENTS = 0.05

var continue_making_trail = false
	
func make_trail():
	continue_making_trail = true
	make_trail_element()
	while continue_making_trail:
		await get_tree().create_timer(TIME_BETWEEN_ELEMENTS).timeout
		make_trail_element()

func stop_trail():
	continue_making_trail = false
	
func make_trail_element():
	var trail = dash_trail_sprite.instantiate()
	var sprite_copy = sprite2d_to_use.duplicate()
	trail.position = player.position
	trail.scale = player.scale
	trail.add_child(sprite_copy)
	root.add_child(trail)
