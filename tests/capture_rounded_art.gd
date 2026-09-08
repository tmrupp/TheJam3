extends SceneTree
## Deterministic art-direction reel; scripted movement, not a recorded player input run.

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
	var output: String = ProjectSettings.globalize_path("res://../art-captures/rounded-frames")
	DirAccess.make_dir_recursive_absolute(output)
	var previous: Vector2 = Vector2(300, 560)
	for frame: int in range(240):
		var time: float = float(frame) / 30.0
		var position: Vector2 = Vector2(300, 560)
		if time >= 1.0 and time < 3.0:
			position.x = lerpf(300.0, 650.0, smoothstep(1.0, 3.0, time))
		elif time >= 3.0 and time < 4.0:
			position.x = 650.0
		elif time >= 4.0 and time < 5.3:
			var progress: float = (time - 4.0) / 1.3
			position.x = lerpf(650.0, 300.0, smoothstep(0.0, 1.0, progress))
			position.y -= sin(progress * PI) * 150.0
		visual.world_velocity = (position - previous) * 30.0
		visual.effect_pulse = maxf(0.0, 0.9 - (time - 6.0) * 2.0) if time >= 6.0 else 0.0
		room.player.position = position
		previous = position
		world._process(1.0 / 30.0)
		room.identities.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frame_%03d.png" % frame))
	print("CAPTURED 240 frames: ", output)
	room.queue_free()
	await process_frame
	quit()
