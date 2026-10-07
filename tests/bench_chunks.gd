extends SceneTree
## What chunking could save on the largest level: the frame time with everything running against
## only what is near the camera running (the rest asleep), and the stall when a level loads.
## godot --path . --windowed --resolution 1280x720 --script res://tests/bench_chunks.gd

const DEPTH: int = 8
const FRAMES: int = 120


func _initialize() -> void:
	call_deferred("run")


func measure(label: String) -> float:
	for i: int in range(20):
		await process_frame
	var t0: int = Time.get_ticks_usec()
	for i: int in range(FRAMES):
		await process_frame
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(FRAMES)
	print("BENCH %-34s frame %6.2f ms" % [label, ms])
	return ms


func run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://bench.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	while info.coord.y < DEPTH:
		info.travel(MapInfo.Exit.DEEPER)
		await process_frame
		while info.world == null or info.travelling:
			await process_frame
	# Level loads: travel sideways and back, timing the longest frame while it loads.
	for k: int in range(2):
		var worst: float = 0.0
		var t_start: int = Time.get_ticks_usec()
		info.travel(MapInfo.Exit.RIGHT if k == 0 else MapInfo.Exit.LEFT)
		var last: int = Time.get_ticks_usec()
		await process_frame
		while info.world == null or info.travelling:
			await process_frame
			var now: int = Time.get_ticks_usec()
			worst = maxf(worst, float(now - last) / 1000.0)
			last = now
		for i: int in range(3):
			await process_frame
			var now2: int = Time.get_ticks_usec()
			worst = maxf(worst, float(now2 - last) / 1000.0)
			last = now2
		print("BENCH load %d: %.0f ms in all, longest frame %.1f ms, %d objects" % [k, float(Time.get_ticks_usec() - t_start) / 1000.0, worst, info.map_elements.get_child_count()])
	var all_on: float = await measure("depth %d %s all running" % [DEPTH, info.world.size])
	var cam: Camera2D = main.get_node("Camera2D") as Camera2D
	var reach: Vector2 = Vector2(root.get_window().content_scale_size) / cam.zoom * 0.75 + Vector2(256, 256)
	var center: Vector2 = cam.get_screen_center_position()
	var asleep: int = 0
	for n: Node in info.map_elements.get_children():
		if n is Node2D and ((n as Node2D).global_position - center).abs().x > reach.x or ((n as Node2D).global_position - center).abs().y > reach.y:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			if n is CanvasItem:
				(n as CanvasItem).visible = false
			asleep += 1
	var near: float = await measure("only near camera (%d of %d asleep)" % [asleep, info.map_elements.get_child_count()])
	print("BENCH   sleeping far objects saves %.2f ms" % (all_on - near))
	quit()
