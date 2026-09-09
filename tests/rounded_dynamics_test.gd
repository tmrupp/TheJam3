extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room: Node = load("res://prefabs/scenes/rounded_art_room.tscn").instantiate()
	root.add_child(room)
	room.player.set_physics_process(false)
	var visual: Node = room.player.get_node("FourierVisual")
	var gait: Node = room.locomotion
	visual.set_physics_process(false)
	gait.set_process(false)
	var results: Array[Vector2] = []
	for fps: int in [30, 120]:
		gait.reset_dynamics()
		visual.world_velocity = Vector2(400, 0)
		for step: int in range(fps):
			gait._update_dynamics(1.0 / fps, true, 0.0)
		results.append(gait.body_spring)
	assert(results[0].distance_to(results[1]) < 0.01, "Spring should agree across frame rates")
	assert(gait.body_spring.x > 1.02 and gait.body_spring.y > 0.0, "Motion must stretch and lean")
	assert(absf(visual.transform.determinant() - 1.0) < 0.001, "Preserve body area")
	assert((visual.transform * Vector2(0, 8)).distance_to(Vector2(0, 3)) < 0.001, "Anchor deformation at hips")
	var geometry: Array = gait.envelope_geometry()
	assert(geometry.size() == 3 and geometry[0].points.size() == 129)
	assert(geometry[0].points[0] == geometry[0].points[-1], "Contours must close")
	var center: Vector2 = visual.get_global_transform_with_canvas().origin
	for index: int in range(128):
		var inner: Vector2 = geometry[0].points[index] - center
		var middle: Vector2 = geometry[1].points[index] - center
		var outer: Vector2 = geometry[2].points[index] - center
		assert(absf(inner.normalized().cross(outer.normalized())) < 0.001, "All rings share radial center")
		assert(absf(middle.length() - inner.length() - 3.0) < 0.001, "Concentric spacing")
		assert(absf(outer.length() - middle.length() - 3.0) < 0.001, "No displaced ring centers")
	var strength: float = gait.envelope_strength
	visual.world_velocity = Vector2(-400, 0)
	gait._update_dynamics(1.0 / 60.0, true, 0.0)
	assert(gait.envelope_strength < strength and gait.reversing, "Reversal must shorten before turning")
	for step: int in range(60):
		gait._update_dynamics(1.0 / 60.0, true, 0.0)
	assert(gait.envelope_direction.x < -0.9)
	visual.reset_motion()
	assert(gait.body_spring == Vector2(1, 0) and gait.envelope_strength == 0.0, "Teleport clears dynamics")
	gait.was_grounded = false
	gait.previous_velocity = Vector2(0, 500)
	visual.world_velocity = Vector2.ZERO
	gait._update_dynamics(1.0 / 30.0, true, 0.0)
	assert(gait.body_spring.x > 1.0, "Landing must squash")
	for step: int in range(120):
		gait._update_dynamics(1.0 / 60.0, true, 0.0)
	assert(gait.body_spring.distance_to(Vector2(1, 0)) < 0.001, "Body must settle at rest")
	room.get_node("FourierWorld").reduced_motion = true
	visual.world_velocity = Vector2(600, -600)
	gait._update_dynamics(0.1, false, 0.3)
	assert(gait.body_spring == Vector2(1, 0) and gait.envelope_strength == 0.0)
	room.queue_free()
	await process_frame
	print("PASS: spring stability, hip anchor, deformation, three envelopes, reversal, teleport, landing, reduced motion")
	quit()
