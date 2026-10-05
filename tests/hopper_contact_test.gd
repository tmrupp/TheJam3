extends SceneTree
## Fast hopper motion cannot carry/push an invulnerable wizard; the separate hitbox still hurts.

var failed: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, what: String) -> void:
	print("  ok   " if ok else "FAIL  ", what)
	failed = failed or not ok

func run() -> void:
	MapInfo.save_path = "user://hopper_contact_test.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	while MapInfo.instance.world == null or MapInfo.instance.travelling:
		await process_frame
	var player: Player = main.get_node("Player")
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var home: Vector2 = Vector2(-10000, -10000)
	player.global_position = home
	player.velocity = Vector2.ZERO
	player.invulnerable.enable()
	var hopper: RigidBody2D = load("res://prefabs/hopper_enemy.tscn").instantiate()
	main.add_child(hopper)
	hopper.scale = Vector2.ONE * 4.0
	hopper.get_node("Hopper").set_physics_process(false)
	# Confirm this overlap sweep exercises the old shove, then restore the production exceptions.
	hopper.remove_collision_exception_with(player)
	player.remove_collision_exception_with(hopper)
	var old_shove: float = 0.0
	for i: int in range(31):
		hopper.global_position = home + Vector2(-180.0 + float(i) * 12.0, 0)
		await physics_frame
		player.velocity = Vector2.ZERO
		player.move_and_slide()
		old_shove = maxf(old_shove, player.global_position.distance_to(home))
	check(old_shove > 40.0, "the contact scenario reproduces the old solid-body shove (%.1f px)" % old_shove)
	hopper.add_collision_exception_with(player)
	player.add_collision_exception_with(hopper)
	# Sweep across the wizard from every direction, as a fast leap/landing would, while they
	# repeatedly resolve body overlaps. Check displacement rather than just collision flags.
	var moved: float = 0.0
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		player.global_position = home
		for i: int in range(31):
			hopper.global_position = home + direction * (-180.0 + float(i) * 12.0)
			await physics_frame
			player.velocity = Vector2.ZERO
			player.move_and_slide()
			moved = maxf(moved, player.global_position.distance_to(home))
	check(moved < 1.0, "fast hopper contact does not shove or carry the wizard (%.1f px)" % moved)
	player.end_invulnerable()
	player.invulnerable.refresh()
	player.health.health = player.health.max_health
	var before: int = player.health.health
	hopper.global_position = player.global_position + Vector2(40, 0)
	for i: int in range(4):
		await physics_frame
	check(player.health.health == before - 1 and player.knock.length() > 0.0, "the hopper's contact hitbox still deals damage and normal recoil")
	# Terrain is still solid to it.
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.collision_layer = 4
	floor_body.position = home + Vector2(0, 200)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(600, 40)
	shape.shape = box
	floor_body.add_child(shape)
	main.add_child(floor_body)
	hopper.global_position = home
	await physics_frame
	var hit: KinematicCollision2D = hopper.move_and_collide(Vector2(0, 300))
	check(hit != null and hit.get_collider() == floor_body, "hopper still lands on solid terrain")
	MapInfo.delete_save()
	print("FAILED" if failed else "PASS: hopper contact")
	quit(1 if failed else 0)
