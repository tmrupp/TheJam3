extends Node

@onready var player = $"/root/Main/Player"
@onready var collider = $"../CollisionShape2D"
@onready var top = $".."

var knock_back_factor = 400
func touch(other):
	if other == player:
		touching_player = true
		
func stop_touch(other):
	if other == player:
		touching_player = false
	pass

var touching_player = false

func _ready() -> void:
	top.connect("body_entered", touch)
	top.connect("body_exited", stop_touch)
	
func _physics_process(delta):
	if touching_player:
		if player in top.get_overlapping_bodies():
			var d = (player.position - collider.get_global_position()).normalized()
			player.hurt(-1, d * knock_back_factor)
		else:
			touching_player = false
		
