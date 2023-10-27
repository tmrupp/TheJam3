extends Node

@onready var player: Player = $"../"
@onready var main: Node = $"/root/Main"
@onready var visual: Sprite2D = $"../Sprite2D" # someday, this reference will break

var projection_timer: ActionTimer = ActionTimer.new(5.0, end_projection)

# holds a reference to the projection we create, if one exists currently
var false_player_origin: Sprite2D

var held_color: Color

func _ready() -> void:
	player.astral_projection_signal.connect(project)
	player.elapse_ability_time_signal.connect(elapse)
	false_player_origin = null
	
func elapse(delta: float) -> void:
	projection_timer.elapse(delta)

func project() -> void:
	projection_timer.enable()
	
	# clone the visual
	false_player_origin = visual.duplicate()
	main.add_child(false_player_origin)
	false_player_origin.position = player.position
	false_player_origin.scale = player.scale
	
	# turn off own collision
	# TODO
	
	# alter our own visual to look all projection-y
	held_color = visual.modulate
	visual.modulate = Color(0, 1, 1, 0.5)

func end_projection(_timer: ActionTimer) -> void:
	projection_timer.refresh()
	
	# reset our position to the visual clone's
	player.position = false_player_origin.position
	
	# reset our color
	visual.modulate = held_color
	
	# destroy the visual clone
	false_player_origin.queue_free()
