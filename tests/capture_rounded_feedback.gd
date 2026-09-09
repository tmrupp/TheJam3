extends SceneTree
## Scripted motion with real dash/projection/hurt/death events for art review.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var room: Node = load("res://prefabs/scenes/rounded_art_room.tscn").instantiate()
	root.add_child(room)
	room.player.set_physics_process(false)
	var visual: Node = room.player.get_node("FourierVisual")
	visual.set_physics_process(false)
	var world: Node = room.get_node("FourierWorld")
	world.set_process(false)
	var caption: Label = Label.new()
	caption.position = Vector2(40, 112)
	caption.add_theme_font_size_override("font_size", 18)
	caption.modulate = Color(1.0, 0.7, 0.55)
	room.identities.get_parent().add_child(caption)
	var projection: Node = room.player.get_node("AstralProjection")
	var output: String = ProjectSettings.globalize_path("res://../art-captures/feedback-frames")
	DirAccess.make_dir_recursive_absolute(output)
	var previous: Vector2 = Vector2(300, 560)
	for frame: int in range(240):
		var time: float = float(frame) / 30.0
		var position: Vector2 = Vector2(300, 560)
		caption.text = "REST / clean, quiet forms"
		if time >= 1.0 and time < 1.25:
			position.x = 300.0 + (time - 1.0) * 600.0
		elif time >= 1.25 and time < 2.0:
			position.x = 450.0
		elif time >= 2.0 and time < 3.2:
			position.x = lerpf(450.0, 720.0, smoothstep(2.0, 3.2, time))
		elif time >= 3.2 and time < 5.0:
			position.x = 450.0
		elif time >= 5.0 and time < 6.0:
			position.x = lerpf(450.0, 720.0, smoothstep(5.0, 6.0, time))
		elif time >= 6.0:
			position.x = 420.0
		room.player.position = position
		if frame == 30:
			room.player.dash.enable(true)
			room.player.do_dash(Vector2.RIGHT)
		if frame == 60:
			projection.project()
		if frame == 96:
			projection.end_projection(projection.projection_timer)
		if frame == 126:
			room.player.normal_hurt(-1, Vector2.ZERO, null)
		if frame == 180:
			room.player.position = Vector2(720, 560)
			room.player.die()
			# Keep the remnant in this scripted shot; coin recovery is tested separately.
			if not room.feedback.remnant_refs.is_empty():
				room.feedback.remnant_refs[-1].get_ref().set_deferred("monitoring", false)
		if time >= 1.0 and time < 2.0:
			caption.text = "DASH / fading contour echoes"
		elif time >= 2.0 and time < 3.2:
			caption.text = "PROJECT / a visible return anchor"
		elif time >= 3.2 and time < 4.2:
			caption.text = "RETURN / settle back into form"
		elif time >= 4.2 and time < 5.3:
			caption.text = "IMPACT / brief flash and contour pulse"
		elif time >= 6.0:
			caption.text = "DEATH / dispersal + recoverable remnant"
		visual.world_velocity = (room.player.position - previous) * 30.0
		if visual.reset_pending:
			visual.world_velocity = Vector2.ZERO
			visual.reset_pending = false
		visual.effect_pulse = maxf(0.0, visual.effect_pulse - 1.8 / 30.0)
		previous = room.player.position
		for timer: ActionTimer in room.player.timers:
			timer.elapse(1.0 / 30.0)
		room.player.elapse_ability_time_signal.emit(1.0 / 30.0)
		world._process(1.0 / 30.0)
		room.identities.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frame_%03d.png" % frame))
	print("CAPTURED rounded feedback: ", output)
	room.queue_free()
	await process_frame
	quit()
