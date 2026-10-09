extends TestKit
## Where a steady frame goes, at a few places: the process pass (every _process), the physics pass,
## and the rest (drawing and the renderer), timed by probe nodes that run first and last in each
## pass. Then the process pass by script: each processing node's _process timed on its own.
## godot --path . --windowed --resolution 1280x720 --script res://tests/bench_frame.gd

## The rows timed.
const ROWS: Array[int] = [0, 8, -8, -10]
## Frames averaged.
const FRAMES: int = 240


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


func ms_since(t: int) -> float:
	return float(Time.get_ticks_usec() - t) / 1000.0


func run() -> void:
	window()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await boot(28)
	# Standing about among enemies: the wizard is healed every frame so they never die mid-
	# measurement (more health would print more beads, and cost more).
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	var first: Probe = Probe.new()
	first.process_priority = -1000000
	first.process_physics_priority = -1000000
	var last: Probe = Probe.new()
	last.process_priority = 1000000
	last.process_physics_priority = 1000000
	root.add_child(first)
	root.add_child(last)
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var plates: Array[RID] = []
	for sv: SubViewport in RisoPrint.instance.plates + RisoPrint.instance.ui_plates:
		plates.append(sv.get_viewport_rid())
		RenderingServer.viewport_set_measure_render_time(sv.get_viewport_rid(), true)
	for row: int in ROWS:
		var at: Vector2i = Vector2i(28, row)
		if info.coord != at:
			# Debug travel goes straight there (and inks the whole map, which is drawn anyway).
			MapInfo.debug = true
			info.debug_travel(at)
			MapInfo.debug = false
			await until(func() -> bool: return info.coord == at and not info.travelling)
		for i: int in range(40):
			await process_frame
		var proc: float = 0.0
		var phys: float = 0.0
		var cpu: float = 0.0
		var gpu: float = 0.0
		var draw: float = 0.0
		var plate_cpu: float = 0.0
		var plate_gpu: float = 0.0
		var t0: int = Time.get_ticks_usec()
		var times: Array[float] = []
		var t_prev: int = t0
		for i: int in range(FRAMES):
			await process_frame
			times.append(ms_since(t_prev))
			t_prev = Time.get_ticks_usec()
			proc += float(last.stamp - first.stamp) / 1000.0
			phys += float(last.physics_stamp - first.physics_stamp) / 1000.0
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			draw += float(last.flushed - last.stamp) / 1000.0
			for p: RID in plates:
				plate_cpu += RenderingServer.viewport_get_measured_render_time_cpu(p)
				plate_gpu += RenderingServer.viewport_get_measured_render_time_gpu(p)
		var frame: float = ms_since(t0) / FRAMES
		print("BENCH row %3d %-9s frame %6.2f ms  process %6.2f  redraws %6.2f  physics %6.2f  render cpu %6.2f  gpu %6.2f  plates cpu %6.2f  gpu %6.2f  nodes %d" % [
			row, info.world.size, frame, proc / FRAMES, draw / FRAMES, phys / FRAMES, cpu / FRAMES, gpu / FRAMES, plate_cpu / FRAMES, plate_gpu / FRAMES, get_node_count()])
		times.sort()
		print("BENCH     frame times: median %.2f  p90 %.2f  p99 %.2f  max %.2f ms" % [times[FRAMES / 2], times[FRAMES * 9 / 10], times[FRAMES * 99 / 100], times[FRAMES - 1]])
		_by_script()
	finish()


## Each processing node's _process timed alone (a few calls each), summed by script.
func _by_script() -> void:
	var cost: Dictionary = {}
	var count: Dictionary = {}
	var stack: Array[Node] = [root]
	var nodes: Array[Node] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if n.is_processing() and n.can_process() and n.has_method(&"_process") and not (n is Probe):
			nodes.append(n)
	for n: Node in nodes:
		var s: Script = n.get_script() as Script
		var key: String = s.resource_path.get_file() if s != null and s.resource_path != "" else n.get_class()
		var t: int = Time.get_ticks_usec()
		for k: int in range(3):
			n.call(&"_process", 1.0 / 60.0)
		cost[key] = float(cost.get(key, 0.0)) + float(Time.get_ticks_usec() - t) / 3000.0
		count[key] = int(count.get(key, 0)) + 1
	var keys: Array = cost.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(cost[a]) > float(cost[b]))
	for key: String in keys.slice(0, 14):
		print("BENCH     %-28s %4d nodes  %6.2f ms" % [key, count[key], cost[key]])
	var total: float = 0.0
	for key: String in keys:
		total += float(cost[key])
	print("BENCH     all %d processing nodes, %d scripts: %.2f ms" % [nodes.size(), keys.size(), total])
