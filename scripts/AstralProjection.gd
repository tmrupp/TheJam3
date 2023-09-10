extends Node

@onready var player = $"../"
@onready var main = $"/root/Main"
@onready var visual = $"../Sprite2D" # someday, this reference will break

var projection_timer = ActionTimer.new(5.0, end_projection)

# holds a reference to the projection we create, if one exists currently
var false_player_origin

var held_color

func _ready():
	player.astral_projection_signal.connect(project)
	player.elapse_ability_time_signal.connect(elapse)
	false_player_origin = null
	
func elapse(delta):
	projection_timer.elapse(delta)

func project():
	print("projection started")
	projection_timer.enable()
	
	# clone the visual
	false_player_origin = visual.duplicate()
	main.add_child(false_player_origin)
	false_player_origin.position = player.position
	
	# turn off own collision
	# TODO
	
	# alter our own visual to look all projection-y
	held_color = visual.modulate
	visual.modulate = Color.CYAN

func end_projection(_timer):
	print("projection ended")
	projection_timer.refresh()
	
	# reset our position to the visual clone's
	player.position = false_player_origin.position
	
	# reset our color
	visual.modulate = held_color
	
	# destroy the visual clone
	false_player_origin.queue_free()
