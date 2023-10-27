extends Node

var jump_particles: Resource = preload("res://prefabs/jump_particles.tscn")

func Jump() -> void:
	#print("In ParticleController.Jump")
	var jp: GPUParticles2D = jump_particles.instantiate()
	add_child(jp)
	jp.emitting = true
