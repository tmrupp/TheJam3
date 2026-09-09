extends SceneTree
## Deterministic art reel: walk, run, reverse, jump; rings use only current velocity.
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
	room.locomotion.set_process(false)
	var caption: Label = Label.new()
	caption.position = Vector2(40, 112)
	caption.add_theme_font_size_override("font_size", 18)
	caption.modulate = Color(1.0, 0.7, 0.55)
	room.identities.get_parent().add_child(caption)
	var output: String = ProjectSettings.globalize_path("res://../art-captures/walk-frames")
	DirAccess.make_dir_recursive_absolute(output)
	var previous: Vector2 = Vector2(300, 569)
	for frame: int in range(240):
		var time: float = float(frame) / 30.0
		var at: Vector2 = Vector2(300, 569)
		caption.text = "REST / planted feet, quiet silhouette"
		room.locomotion.grounded_override = 1
		if time >= 1.0 and time < 3.0:
			at.x = 300.0 + 90.0 * (time - 1.0)
			caption.text = "WALK / alternating stance and swing"
		elif time >= 3.0 and time < 4.0:
			at.x = 480.0 + 300.0 * (time - 3.0)
			caption.text = "RUN / spring lean + surrounding velocity envelope"
		elif time >= 4.0 and time < 5.0:
			at.x = 780.0 - 300.0 * (time - 4.0)
			caption.text = "REVERSE / compress, redirect, recover"
		elif time >= 5.0 and time < 6.5:
			var t: float = (time - 5.0) / 1.5
			at.x = lerpf(480.0, 300.0, t)
			at.y -= sin(t * PI) * 150.0
			room.locomotion.grounded_override = 0
			caption.text = "AIR / stretch, round out, squash on landing"
		room.player.position = at
		visual.world_velocity = (at - previous) * 30.0
		visual.effect_pulse = 0.0
		previous = at
		room.locomotion._process(1.0 / 30.0)
		world._process(1.0 / 30.0)
		room.identities.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frame_%03d.png" % frame))
	print("CAPTURED rounded walk: ", output)
	room.queue_free()
	await process_frame
	quit()
