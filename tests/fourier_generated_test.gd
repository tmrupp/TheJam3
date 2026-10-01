extends SceneTree
var results: Array[int] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for active: bool in [false, true]:
		var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
		root.add_child(main)
		MapInfo.save_path = "user://test_run.save"
		var menu: Node = main.get_node("Menu")
		main.get_node("FourierWorld").enabled = active
		menu.world_seed.text = "28"
		menu.start_game()
		await process_frame
		await process_frame
		var info: Node = main.get_node("CanvasLayer/MapInfo")
		var deadline: int = Time.get_ticks_msec() + 20000
		while info.world == null and Time.get_ticks_msec() < deadline:
			await process_frame
		if info.world == null:
			push_error("Generated-world test timed out")
			quit(1)
			return
		for index: int in range(10):
			await physics_frame
			await process_frame
		var types: PackedInt32Array = PackedInt32Array()
		for column: Array in info.world.cells:
			for cell: Variant in column:
				types.append(cell.type)
		results.append(hash([types, info.world.exits, info.world.exit_lanterns]))
		print("GENERATED seed 28 effect=", active, " fingerprint=", results[-1], " registered=", get_nodes_in_group("fourier_visuals").size())
		# Validate existing projection return and death against the integrated provider.
		var player: Node = main.get_node("Player")
		player.set_physics_process(false)
		var projection: Node = player.get_node("AstralProjection")
		Abilities.grant(player, &"astral")
		var origin: Vector2 = player.position
		projection.project()
		player.position += Vector2(100, 0)
		projection.end_projection(projection.projection_timer)
		if player.position != origin or not player.get_node("FourierVisual").reset_pending:
			push_error("Projection return failed to reset Fourier motion")
			quit(1)
			return
		player.die()
		if not player.get_node("FourierVisual").reset_pending:
			push_error("Death failed to reset Fourier motion")
			quit(1)
			return
		main.queue_free()
		await process_frame
		await process_frame
	if results[0] != results[1]:
		push_error("Renderer changed generated world data")
		quit(1)
	else:
		print("PASS: generated world data unchanged by Fourier rendering")
		quit()
