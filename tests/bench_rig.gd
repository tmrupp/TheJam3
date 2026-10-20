extends TestKit
## What a rig saves: every rigged kind of art in a few places printed again and again with its rig
## on the GPU and in script (InkCanvas.rig_on_gpu), its print's time and the ops it redraws.
## godot --path . --windowed --script res://tests/bench_rig.gd

## The rows timed (the garden, the cemetery, the crags, the sky, the institute), and prints each.
const ROWS: Array[int] = [0, 8, -8, -10, 11]
const N: int = 40


func run() -> void:
	window()
	await boot(28)
	var spent: Dictionary = {}
	var redrawn: Dictionary = {}
	var count: Dictionary = {}
	for row: int in ROWS:
		var at: Vector2i = Vector2i(28, row)
		if info.coord != at:
			MapInfo.debug = true
			info.debug_travel(at)
			MapInfo.debug = false
			await until(func() -> bool: return info.coord == at and not info.travelling)
		for i: int in range(60):
			await process_frame
		var props: Array[RisoProp] = []
		var stack: Array[Node] = [main]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var prop: RisoProp = n as RisoProp
			if prop != null and prop.ink != null and prop.ink.rigged and prop.host != null and prop.host.is_visible_in_tree():
				props.append(prop)
		for gpu: bool in [false, true]:
			InkCanvas.rig_on_gpu = gpu
			for prop: RisoProp in props:
				var key: String = (prop.get_script() as Script).resource_path.get_file() + (" GPU" if gpu else " script")
				prop._redraw()
				await process_frame
				var took: int = 0
				var ops: int = 0
				for i: int in range(N):
					prop.t += 1.0 / 30.0
					var t0: int = Time.get_ticks_usec()
					prop._redraw()
					took += Time.get_ticks_usec() - t0
					for op: Node in prop.ink.get_children():
						var o: RisoInkOp = op as RisoInkOp
						if o != null and o.shown and o._px < 0.0:
							ops += 1
				spent[key] = float(spent.get(key, 0.0)) + float(took) / 1000.0 / N
				redrawn[key] = float(redrawn.get(key, 0.0)) + float(ops) / N
				count[key] = int(count.get(key, 0)) + 1
		InkCanvas.rig_on_gpu = true
	var keys: Array = spent.keys()
	keys.sort()
	for key: String in keys:
		print("BENCH %-22s %3d of them: a print %.3f ms, %.1f ops redrawn a print" % [key, count[key], float(spent[key]) / int(count[key]), float(redrawn[key]) / int(count[key])])
	finish()
