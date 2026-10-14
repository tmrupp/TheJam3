extends TestKit
## The CPU of a frame standing still and walking, at a few places: the median frame and its
## passes (the process pass, the redraws queued in it, a physics step, and drawing), timed by probe
## nodes that run first and last in each pass, over FRAMES frames each.
## godot --path . --windowed --script res://tests/bench_walk.gd [-- script]

## The rows timed (the garden, the cemetery, the crags, the sky, the institute).
const ROWS: Array[int] = [0, 8, -8, -10, 11]
const FRAMES: int = 300


## A node that stamps the time when its pass reaches it.
class Probe extends Node:
	var stamp: int = 0
	var physics_stamp: int = 0
	## When the deferred calls queued in the process pass (the redraws among them) are done.
	var flushed: int = 0
	func _process(_d: float) -> void:
		stamp = Time.get_ticks_usec()
		_flush.call_deferred()
	func _flush() -> void:
		flushed = Time.get_ticks_usec()
	func _physics_process(_d: float) -> void:
		physics_stamp = Time.get_ticks_usec()


func run() -> void:
	window()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await boot(28)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	# `-- script`: rigs placed in script, as all art was before rigs (InkCanvas.rig_on_gpu off).
	if OS.get_cmdline_user_args().has("script"):
		InkCanvas.rig_on_gpu = false
	var first: Probe = Probe.new()
	first.process_priority = -1000000
	first.process_physics_priority = -1000000
	var last: Probe = Probe.new()
	last.process_priority = 1000000
	last.process_physics_priority = 1000000
	root.add_child(first)
	root.add_child(last)
	var draw_at: Array[int] = [0, 0]
	RenderingServer.frame_pre_draw.connect(func() -> void: draw_at[0] = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: draw_at[1] = Time.get_ticks_usec())
	var all: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
	for row: int in ROWS:
		var at: Vector2i = Vector2i(28, row)
		if info.coord != at:
			MapInfo.debug = true
			info.debug_travel(at)
			MapInfo.debug = false
			await until(func() -> bool: return info.coord == at and not info.travelling)
		for i: int in range(90):
			await process_frame
		for walking: bool in [false, true]:
			if walking:
				Input.action_press(&"Right")
			var passes: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
			var t_prev: int = Time.get_ticks_usec()
			for i: int in range(FRAMES):
				await process_frame
				var now: int = Time.get_ticks_usec()
				passes[0].append(float(now - t_prev) / 1000.0)
				t_prev = now
				passes[1].append(float(last.stamp - first.stamp) / 1000.0)
				passes[2].append(float(last.flushed - last.stamp) / 1000.0)
				passes[3].append(float(last.physics_stamp - first.physics_stamp) / 1000.0)
				passes[4].append(float(draw_at[1] - draw_at[0]) / 1000.0)
			Input.action_release(&"Right")
			var med: Array[float] = []
			for p: PackedFloat32Array in passes:
				var q: PackedFloat32Array = p.duplicate()
				q.sort()
				med.append(q[q.size() / 2])
			all[1 if walking else 0] += med[0] / ROWS.size()
			print("BENCH row %3d %-8s median frame %6.2f ms = process %5.2f + redraws %5.2f + physics step %5.2f + drawing %5.2f" % [row, "walking" if walking else "standing", med[0], med[1], med[2], med[3], med[4]])
	print("BENCH mean of the medians: standing %.2f ms, walking %.2f ms" % [all[0], all[1]])
	finish()
