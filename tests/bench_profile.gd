extends TestKit
## Which GDScript functions a steady frame spends its time in, at a few places: the engine's own
## script profiler (the command-line debugger's, so Godot must run with -d) is switched on for a
## stretch of frames and then off, which prints every function's total and self time and calls
## since it was switched on. Times include the profiler's own overhead (every call is timed), so
## they rank the functions rather than add up to the frame. Physics steps as in play.
## godot --path . --windowed -d --script res://tests/bench_profile.gd -- --rows=0,8
## (A script error stops at the debugger's prompt: run it under a timeout.)

## Frames profiled at each place, after a few to settle.
const FRAMES: int = 300
const WARM: int = 40


func run() -> void:
	var rows: Array[int] = [0, 8]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rows="):
			rows.clear()
			for r: String in arg.trim_prefix("--rows=").split(","):
				rows.append(int(r))
	window()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await boot(28)
	Engine.max_physics_steps_per_frame = 8
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	if not EngineDebugger.is_active():
		print("BENCH the script profiler needs the debugger: run Godot with -d")
		finish()
		return
	for row: int in rows:
		var at: Vector2i = Vector2i(28, row)
		if info.coord != at:
			MapInfo.debug = true
			info.debug_travel(at)
			MapInfo.debug = false
			await until(func() -> bool: return info.coord == at and not info.travelling)
		# The generator's worker lays the neighbouring places out on arrival; let it finish first.
		await until(func() -> bool: return not info.loader.gen_busy and info.loader.prefetch.is_empty(), 60000)
		for i: int in range(WARM):
			await process_frame
		print("BENCH PROFILE row %d %s, %d nodes, %d frames" % [row, info.world.size, get_node_count(), FRAMES])
		var t0: int = Time.get_ticks_usec()
		EngineDebugger.profiler_enable("scripts", true)
		for i: int in range(FRAMES):
			await process_frame
		EngineDebugger.profiler_enable("scripts", false)
		print("BENCH PROFILE END row %d, %.2f ms a frame while profiled" % [row, float(Time.get_ticks_usec() - t0) / 1000.0 / float(FRAMES)])
	finish()
