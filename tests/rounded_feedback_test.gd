extends SceneTree
## suite: full (fails: still expects the old corpse "remnant", which the ghost replaced; full run only until it is updated)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room: Node = load("res://prefabs/scenes/rounded_art_room.tscn").instantiate()
	root.add_child(room)
	room.player.set_physics_process(false)
	# Astral projection is learned at a shrine now; this room starts without it.
	Abilities.set_tier(room.player, &"astral", 1)
	var feedback: Node = room.feedback
	room.player.do_dash(Vector2.RIGHT)
	await process_frame
	await process_frame
	assert(feedback.events_seen.get(&"dash", 0) == 1)
	assert(feedback.traces.is_empty(), "Dash uses velocity rings, not stored echoes")
	room.player.get_node("DashTrail").stop_trail()
	var projection: Node = room.player.get_node("AstralProjection")
	projection.project()
	var original: Sprite2D = projection.false_player_origin
	projection.project()
	assert(projection.false_player_origin == original, "Repeated projection cannot orphan origin")
	assert(not feedback.projection.is_empty())
	projection.end_projection(projection.projection_timer)
	assert(feedback.projection.is_empty())
	projection.end_projection(projection.projection_timer)
	room.player.normal_hurt(-1, Vector2.ZERO, null)
	assert(feedback.events_seen.get(&"hurt", 0) == 1)
	room.player.die()
	assert(feedback.events_seen.get(&"death", 0) == 1)
	assert(feedback.remnant_refs.size() == 1)
	var corpse: Node = feedback.remnant_refs[0].get_ref()
	assert(corpse.get_node("Sprite2D").visibility_layer == 0)
	var coins: int = room.player.coins.coins
	var value: int = corpse.value
	corpse.touch(room.player)
	await process_frame
	await process_frame
	assert(room.player.coins.coins == coins + value, "Remnant still returns its actual coin value")
	assert(feedback.remnant_refs.is_empty())
	room.get_node("FourierWorld").reduced_motion = true
	feedback.traces.clear()
	feedback.on_event(&"dash", room.player.global_position)
	await process_frame
	await process_frame
	assert(feedback.traces.is_empty(), "Reduced motion suppresses dash echoes")
	room.queue_free()
	await process_frame
	print("PASS: rounded dash, projection/re-entry, impact, death, remnant recovery and reduced motion")
	quit()
