extends Node

var jump_particles = preload("res://prefabs/jump_particles.tscn")

func Jump():
	#print("In ParticleController.Jump")
	var jp = jump_particles.instantiate()
	add_child(jp)
	jp.emitting = true
