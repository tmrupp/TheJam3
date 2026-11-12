extends Node

const JUMP_PARTICLES: String = "res://prefabs/jump_particles.tscn"

func Jump() -> void:
	var jp: GPUParticles2D = Prefabs.make(JUMP_PARTICLES) as GPUParticles2D
	add_child(jp)
	jp.emitting = true
