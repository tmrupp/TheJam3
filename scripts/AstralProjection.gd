extends Node

@onready var player = $"../"

var projection_timer = ActionTimer.new(5.0, end_projection)

func _ready():
	player.astral_projection_signal.connect(project)
	player.elapse_ability_time_signal.connect(elapse)
	
func elapse(delta):
	projection_timer.elapse(delta)

func project():
	print("projection started")
	projection_timer.enable()
	
	#copy the player in the hierarchy and hold a reference to it
	#disable the original player's controls/movement/physics
	#link the camera in the scene to the new player copy
	
	pass

func end_projection(_timer):
	print("projection ended")
	
	#link the camera back to the original player
	#destroy the newly made copy
	
	pass
