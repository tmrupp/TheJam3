extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for count: int in [0, 1, 4, 8, 16]:
		var holder: Node2D = Node2D.new()
		root.add_child(holder)
		var world: CanvasLayer = CanvasLayer.new()
		world.set_script(load("res://scripts/FourierWorld.gd"))
		holder.add_child(world)
		world.set_process(false)
		for index: int in range(count):
			var visual: Node2D = Node2D.new()
			visual.set_script(load("res://scripts/FourierVisual.gd"))
			visual.position = Vector2(130 + (index % 4) * 12, 70 + (index / 4) * 12)
			holder.add_child(visual)
		for active: bool in [false, true]:
			world.enabled = active
			var gpu: float = 0.0
			var cpu: float = 0.0
			for frame: int in range(90):
				var started: int = Time.get_ticks_usec()
				world._process(1.0 / 60.0)
				var update_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
				await process_frame
				await RenderingServer.frame_post_draw
				if frame >= 30:
					gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
					cpu += update_ms
			print("BENCH objects=", count, " enabled=", active, " gpu_ms=", snappedf(gpu / 60.0, 0.001), " update_ms=", snappedf(cpu / 60.0, 0.001))
		holder.queue_free()
		await process_frame
	quit()
