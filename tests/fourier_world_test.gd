extends SceneTree
var failures: int = 0

func _initialize() -> void:
	create_timer(20.0, true).timeout.connect(_timeout)
	call_deferred("run")

func _timeout() -> void:
	push_error("Fourier integration tests timed out")
	quit(1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int = 3) -> void:
	for index: Variant in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	var scene: PackedScene = load("res://prefabs/scenes/fourier_room.tscn")
	if scene == null:
		quit(1)
		return
	var room: Variant = scene.instantiate()
	root.add_child(room)
	await frames(15)
	var world: Variant = room.get_node("FourierWorld")
	var visual: Variant = room.player.get_node("FourierVisual")
	check(world.visible_count == 3, "Expected player and two portals")
	check(world.passes.size() == 1, "Three friendly shapes should share a union")
	check(world.passes[0].material.get_shader_parameter("object_count") == 3, "Field upload count")
	var cache_size: int = world.cache.size()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://fourier-room.png")
	# Exercise actual physics input, not just manually moved scene nodes.
	var start_x: float = room.player.position.x
	Input.action_press("Right")
	await frames(12)
	Input.action_release("Right")
	check(room.player.position.x > start_x, "Real player movement")
	Input.action_press("Jump")
	await frames(2)
	Input.action_release("Jump")
	check(room.player.velocity.y < 0.0, "Real player jump")
	room.player.reset_position()
	await frames(15)
	room.player.set_physics_process(false)
	visual.reset_motion()
	await frames()
	room.get_node("Camera2D").offset = Vector2(10, 5)
	await frames()
	check(visual.world_velocity.length() < 0.01, "Camera must not induce velocity")
	room.player.position.x += 5.0
	await frames(1)
	check(visual.world_velocity.length() > 0.0, "Actor movement must induce velocity")
	check(world.cache.size() == cache_size, "Movement must not rebuild shape cache")
	room.portals[0].use_portal()
	await frames()
	check(visual.world_velocity.length() < 0.01, "Portal must reset motion")
	room.player.reset_position()
	await frames()
	check(visual.world_velocity.length() < 0.01, "Respawn must reset motion")
	room.portals[0].hide()
	await frames()
	check(world.visible_count == 2, "Hidden actors must not leak contours")
	room.portals[0].show()
	var sprite: Sprite2D = room.player.get_node("Sprite2D")
	sprite.modulate = Color(0.25, 0.5, 1.0, 0.4)
	check(visual.presentation_tint() == sprite.modulate, "Hurt/projection tint passthrough")
	sprite.modulate = Color.WHITE
	var phase: float = world.elapsed
	paused = true
	await create_timer(0.05, true).timeout
	check(world.elapsed == phase, "Pause freezes visual animation")
	paused = false
	world.reduced_motion = true
	room.player.position.x += 10.0
	await frames()
	var motion: PackedVector2Array = world.passes[0].material.get_shader_parameter("motion")
	check(motion[0] == Vector2.ZERO, "Reduced motion must disable deformation")
	world.enabled = false
	await frames()
	check(not world.passes[0].visible, "Feature off hides rendering")
	check(room.player.get_node("Sprite2D").visible, "Original player sprite must survive")
	world.enabled = true
	for index: Variant in range(3):
		var actor: Node2D = Node2D.new()
		actor.position = Vector2(600 + index * 30, 540)
		room.add_child(actor)
		var provider: Node2D = Node2D.new()
		provider.set_script(load("res://scripts/FourierVisual.gd"))
		actor.add_child(provider)
	await frames()
	check(world.visible_count == 6, "Capacity must not drop registered objects")
	check(world.passes.size() == 6, "Oversized group must fall back to independent draws")
	world.max_passes = 2
	await frames()
	check(world.fallback_count == 4, "Budget fallback must be explicit")
	check(sprite.visible, "Budget fallback retains sprite identity")
	world.max_passes = 16
	room.portals[1].queue_free()
	await frames()
	check(world.visible_count == 5, "Freed actors must leave registry")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://fourier-room-test.png")
	room.queue_free()
	await frames()
	check(get_nodes_in_group("fourier_visuals").is_empty(), "Room cleanup must release registry")
	print("FOURIER TESTS: ", failures, " failures")
	quit(0 if failures == 0 else 1)
