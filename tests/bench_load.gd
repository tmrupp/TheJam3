extends TestKit
## What arriving at a level costs on the main thread, step by step, as MapInfo._level_ready takes
## them: clearing the last level, building this one (a node per thing, place_cell, and each one's
## art), laying its rock, and the print rebuilding for it (world_built: its terrain, decor and light,
## each timed again after on its own). The last level's freeing and the TileMap's update, which
## otherwise come in the next frame, are done and timed in their own steps. Then the first frames
## after: the process pass, the redraws, the renderer, and the rest (the big first draws of the
## terrain and decor, queued before the frame, among it). Places are laid out first (world_at), so the worker's share is not
## counted (see bench_gen.gd).
## godot --path . --windowed --resolution 1280x720 --script res://tests/bench_load.gd

## The rows timed.
const ROWS: Array[int] = [0, 4, 8, 12, -4, -8, -10]
## Frames timed after each arrival.
const AFTER: int = 3


## A node that stamps the time when the process pass reaches it, and when the deferred calls
## queued in it (the redraws among them) are done.
class Probe extends Node:
	var stamp: int = 0
	var flushed: int = 0
	var physics_stamp: int = 0
	func _process(_d: float) -> void:
		stamp = Time.get_ticks_usec()
		_flush.call_deferred()
	func _physics_process(_d: float) -> void:
		physics_stamp = Time.get_ticks_usec()
	func _flush() -> void:
		flushed = Time.get_ticks_usec()


## When the renderer started and finished drawing the last frame.
var pre_draw: int = 0
var post_draw: int = 0


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
	var riso: RisoPrint = RisoPrint.instance
	var first: Probe = Probe.new()
	first.process_priority = -1000000
	var last: Probe = Probe.new()
	last.process_priority = 1000000
	first.process_physics_priority = -1000000
	last.process_physics_priority = 1000000
	root.add_child(first)
	root.add_child(last)
	RenderingServer.frame_pre_draw.connect(func() -> void: pre_draw = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: post_draw = Time.get_ticks_usec())
	for row: int in ROWS:
		var at: Vector2i = Vector2i(28, row)
		var w: LevelGen = null
		while w == null:
			w = info.loader.world_at(at)
			if w == null:
				await process_frame
		info.coord = at
		info.here = Rules.def_for(at)
		var old: Node = info.loader.map_elements
		var t: int = Time.get_ticks_usec()
		info.loader.clear()
		var t_clear: float = ms_since(t)
		# The last level is freed at the end of the frame; here, now, to time it.
		t = Time.get_ticks_usec()
		if is_instance_valid(old):
			old.free()
		var t_free: float = ms_since(t)
		info.world = w
		t = Time.get_ticks_usec()
		info.loader.build(w)
		var t_build: float = ms_since(t)
		t = Time.get_ticks_usec()
		info.loader.lay_terrain(w, info.here.open())
		var t_rock: float = ms_since(t)
		# The TileMap brings its tiles (and their collision) up to date at the next frame; here, now.
		t = Time.get_ticks_usec()
		info.tile_map.update_internals()
		var t_tiles: float = ms_since(t)
		t = Time.get_ticks_usec()
		riso.world_built(info, row)
		var t_print: float = ms_since(t)
		player.position = info.cell_position(w.exits.get(MapInfo.Exit.BACK, Vector2i.ZERO))
		info.loader.wake_around(player.global_position)
		var frames: Array[String] = []
		var t_last: int = Time.get_ticks_usec()
		for i: int in range(AFTER):
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			var whole: float = float(now - t_last) / 1000.0
			var process: float = float(last.stamp - first.stamp) / 1000.0
			var redraws: float = float(last.flushed - last.stamp) / 1000.0
			var render: float = float(post_draw - pre_draw) / 1000.0
			# The physics pass, if one ran this frame (its probes stamped after the last frame).
			var physics: float = float(last.physics_stamp - first.physics_stamp) / 1000.0 if first.physics_stamp > t_last else 0.0
			var before: float = float(first.physics_stamp - t_last) / 1000.0 if first.physics_stamp > t_last else float(first.stamp - t_last) / 1000.0
			frames.append("%.0f (before %.0f, physics %.0f, process %.0f, redraws %.0f, render %.0f, the rest %.0f)" % [whole, before, physics, process, redraws, render, whole - before - physics - process - redraws - render])
			t_last = now
		# The print's three rebuilds, each again on its own.
		t = Time.get_ticks_usec()
		riso.terrain.rebuild(info.tile_map, [] as Array[Vector2], [] as Array[Vector2])
		var t_terrain: float = ms_since(t)
		t = Time.get_ticks_usec()
		riso.decor.rebuild(info, [] as Array[Vector2])
		var t_decor: float = ms_since(t)
		t = Time.get_ticks_usec()
		riso.light.rebuild(info)
		var t_light: float = ms_since(t)
		print("BENCH row %3d %-9s objects %4d  clear %5.1f (freeing %5.1f)  build %6.1f  rock %5.1f (tiles %5.1f)  world_built %6.1f (terrain %5.1f, decor %5.1f, light %4.1f)" % [
			row, w.size, w.objects.size(), t_clear, t_free, t_build, t_rock, t_tiles, t_print, t_terrain, t_decor, t_light])
		print("BENCH     first frames: %s" % ", ".join(frames))
		# Steady frames, here, with chunks sleeping as in play.
		for i: int in range(30):
			await process_frame
		t = Time.get_ticks_usec()
		for i: int in range(60):
			await process_frame
		print("BENCH     then steady frames of %.2f ms" % (ms_since(t) / 60.0))
	finish()
