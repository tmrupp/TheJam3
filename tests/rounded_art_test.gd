extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var original_size: Vector2i = root.content_scale_size
	var room: Node = load("res://prefabs/scenes/rounded_art_room.tscn").instantiate()
	root.add_child(room)
	var world: Node = room.get_node("FourierWorld")
	var visual: Node = room.player.get_node("FourierVisual")
	room.player.set_physics_process(false)
	visual.set_physics_process(false)
	visual.world_velocity = Vector2.ZERO
	visual.effect_pulse = 0.0
	await process_frame
	await process_frame
	assert(root.content_scale_size == Vector2i(960, 540))
	assert(not root.snap_2d_transforms_to_pixel and not root.snap_2d_vertices_to_pixel)
	assert(world.passes[0].material.get_shader_parameter("solid_shapes"))
	assert(room.player.get_node("Sprite2D").visibility_layer == 0)
	assert(room.portals[0].get_node("AnimatedSprite2D").visibility_layer == 0)
	assert(visual.presentation_visible(), "Masking legacy art must not hide the new form")
	assert(visual.outline == 1 and room.portals[0].get_node("FourierVisual").outline == 4)
	visual.pulse(0.8)
	await process_frame
	await process_frame
	var effects: PackedFloat32Array = world.passes[0].material.get_shader_parameter("unresolved")
	assert(effects[0] > 0.0, "A stationary event must trigger contours")
	world.reduced_motion = true
	await process_frame
	await process_frame
	effects = world.passes[0].material.get_shader_parameter("unresolved")
	assert(effects[0] == 0.0)
	room.queue_free()
	await process_frame
	assert(root.content_scale_size == original_size, "Art-study resolution must not leak into other scenes")
	print("PASS: rounded forms, masked pixels, smooth viewport, event pulse, reduced motion and restoration")
	quit()
