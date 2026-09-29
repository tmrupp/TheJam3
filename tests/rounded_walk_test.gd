extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room: Node = load("res://prefabs/scenes/rounded_art_room.tscn").instantiate()
	root.add_child(room)
	room.player.set_physics_process(false)
	var gait: Node = room.locomotion
	var visual: Node = room.player.get_node("FourierVisual")
	visual.set_physics_process(false)
	gait.set_process(false)
	gait.grounded_override = 1
	visual.world_velocity = Vector2.ZERO
	gait._process(0.1)
	var idle_phase: float = gait.gait_phase
	gait._process(0.1)
	assert(gait.gait_phase == idle_phase, "Idle must not walk in place")
	visual.world_velocity = Vector2(150, 0)
	gait._process(0.1)
	assert(gait.gait_phase != idle_phase)
	assert(gait.facing == 1.0)
	var foot_a: Vector2 = gait.foot_position(0)
	var foot_b: Vector2 = gait.foot_position(1)
	assert(absf(foot_a.y - foot_b.y) > 0.1, "Feet must alternate stance and swing")
	var planted: Vector2 = room.player.to_global(gait.foot_position(0))
	room.player.position.x += 3.0
	gait._process(0.02)
	assert(room.player.to_global(gait.foot_position(0)).distance_to(planted) < 0.001, "Supporting foot must not slide in world space")
	visual.world_velocity = Vector2(-150, 0)
	gait._process(0.1)
	assert(gait.facing == -1.0)
	gait.grounded_override = 0
	gait._process(0.1)
	assert(gait.foot_position(0).y < 6.8, "Air pose must tuck feet")
	room.player.visual_event.emit(&"dash", room.player.global_position)
	assert(room.feedback.traces.is_empty(), "No dash echoes")
	await process_frame
	await process_frame
	var holes: PackedFloat32Array = room.get_node("FourierWorld").passes[0].material.get_shader_parameter("hole_radius")
	assert(holes[0] == 0.0 and holes[1] > 20.0 and holes[2] > 20.0, "Only portals have open centers")
	room.queue_free()
	await process_frame
	print("PASS: distance-driven gait, stance/swing, reverse, airborne pose, no echoes, hollow portals")
	quit()
