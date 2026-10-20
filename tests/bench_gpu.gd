extends TestKit
## Whether the CPU or the GPU holds a frame back, and where the GPU's share goes. At a few places a
## steady frame is timed: the CPU's passes by probe nodes (physics, every step of it with the
## physics server, then process, then the redraws), each viewport's GPU time by the renderer (the
## window, the sheet viewport light graphics prints into, the eight scene plates and the nine UI
## plates), and the wall clock. Then again with one part of the print changed at a time, to price it: the UI's print pass off, the scene's print
## shader swapped for a plain one (the plates multiplied, no screen, grain or wobble), the plates
## without antialiasing, the plates not rendering (the print shader still runs, on stale plates),
## the legacy art under the print culled from the window, and nothing left for the GPU to draw (the
## CPU's frame alone, and how fast it runs with the GPU idle: a laptop shares its power between
## them). Physics steps as in play (up to 8 a frame to catch up), not the kit's one a frame.
## Light graphics (RisoPrint.graphics, chosen on integrated GPUs) prints into the smaller sheet
## viewport, timed as "print"; --graphics=full or --graphics=light sets it.
## godot --path . --windowed --script res://tests/bench_gpu.gd -- --size=1280x720 --rows=0,8,-8
## (--size=max maximizes the window, as the game starts; --base-only times the whole print alone,
## to compare renderers: add --rendering-method gl_compatibility or --rendering-driver d3d12.)

## Frames averaged for each measurement, after a few to settle.
const FRAMES: int = 150
const WARM: int = 30
## A visibility bit no game layer uses, to cull everything but the print from the window.
const SPARE_BIT: int = 1 << 24
## The engine's own catch-up limit, which the kit lowers to one.
const PLAY_PHYSICS_STEPS: int = 8
## The scene's print with nothing but the plates multiplied over paper.
const PLAIN: String = """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D plate0 : filter_linear, repeat_disable;
uniform sampler2D plate1 : filter_linear, repeat_disable;
uniform sampler2D plate2 : filter_linear, repeat_disable;
uniform sampler2D plate3 : filter_linear, repeat_disable;
uniform sampler2D plate4 : filter_linear, repeat_disable;
uniform sampler2D plate5 : filter_linear, repeat_disable;
uniform sampler2D plate6 : filter_linear, repeat_disable;
uniform sampler2D plate7 : filter_linear, repeat_disable;
uniform vec3 paper;
uniform vec3 ink0; uniform vec3 ink1; uniform vec3 ink2; uniform vec3 ink3;
uniform vec3 ink4; uniform vec3 ink5; uniform vec3 ink6; uniform vec3 ink7;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = paper;
	col *= mix(vec3(1.0), ink0, texture(plate0, uv).a);
	col *= mix(vec3(1.0), ink1, texture(plate1, uv).a);
	col *= mix(vec3(1.0), ink2, texture(plate2, uv).a);
	col *= mix(vec3(1.0), ink3, texture(plate3, uv).a);
	col *= mix(vec3(1.0), ink4, texture(plate4, uv).a);
	col *= mix(vec3(1.0), ink5, texture(plate5, uv).a);
	col *= mix(vec3(1.0), ink6, texture(plate6, uv).a);
	col *= mix(vec3(1.0), ink7, texture(plate7, uv).a);
	COLOR = vec4(col, 1.0);
}
"""


## A node that stamps the time when each pass reaches it. The first one also notes when the
## frame's first physics step began and how many steps ran.
class Probe extends Node:
	## When the process pass reached it, and when the deferred calls queued in it were done.
	var stamp: int = 0
	var flushed: int = 0
	## When this frame's first physics step reached it, whether one has, and how many have.
	var physics_start: int = 0
	var stepped: bool = false
	var steps: int = 0
	## Set when the process pass begins: the physics steps of this frame, with the server's, and
	## how many there were.
	var physics_us: int = 0
	var frame_steps: int = 0
	## Whether this is the first probe, which keeps the physics count.
	var leads: bool = false
	func _process(_d: float) -> void:
		stamp = Time.get_ticks_usec()
		if leads:
			physics_us = stamp - physics_start if stepped else 0
			frame_steps = steps
			stepped = false
			steps = 0
		_flush.call_deferred()
	func _flush() -> void:
		flushed = Time.get_ticks_usec()
	func _physics_process(_d: float) -> void:
		if leads:
			if not stepped:
				physics_start = Time.get_ticks_usec()
				stepped = true
			steps += 1


## The probes that run first and last in each pass.
var first: Probe
var last: Probe
var riso: RisoPrint
## The renderer's ids of the window, the sheet viewport (light graphics) and the scene's and the
## UI's plate viewports.
var root_rid: RID
var sheet_rid: RID
var plate_rids: Array[RID] = []
var ui_rids: Array[RID] = []
## The plate viewports, scene then UI, as their ids above (a viewport not rendering keeps its last
## measurement, so it is left out).
var plate_views: Array[SubViewport] = []
## The window's cull mask, while a change hides things from it.
var saved_mask: int = 0
## Each plate's antialiasing, while a change turns it off.
var saved_msaa: Array[Viewport.MSAA] = []


func run() -> void:
	var size: Vector2i = Vector2i(1280, 720)
	var rows: Array[int] = [0, 8, -8]
	var base_only: bool = false
	var graphics: StringName = &""
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--base-only":
			base_only = true
		elif arg.begins_with("--graphics="):
			graphics = StringName(arg.trim_prefix("--graphics="))
		elif arg == "--size=max":
			size = Vector2i.ZERO
		elif arg.begins_with("--size="):
			var wh: PackedStringArray = arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif arg.begins_with("--rows="):
			rows.clear()
			for r: String in arg.trim_prefix("--rows=").split(","):
				rows.append(int(r))
	if size == Vector2i.ZERO:
		root.mode = Window.MODE_MAXIMIZED
	else:
		window(size)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await boot(28)
	Engine.max_physics_steps_per_frame = PLAY_PHYSICS_STEPS
	# Standing about among enemies: the wizard is healed every frame so they never die mid-
	# measurement.
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	riso = RisoPrint.instance
	if graphics != &"":
		riso.set_graphics(graphics)
	print("BENCH device %s, %s, window %s, %s graphics" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(), root.size, riso.graphics])
	first = Probe.new()
	first.leads = true
	first.process_priority = -1000000
	first.process_physics_priority = -1000000
	last = Probe.new()
	last.process_priority = 1000000
	last.process_physics_priority = 1000000
	root.add_child(first)
	root.add_child(last)
	root_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(root_rid, true)
	sheet_rid = riso.sheet_viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(sheet_rid, true)
	for sv: SubViewport in riso.plates:
		plate_rids.append(sv.get_viewport_rid())
		plate_views.append(sv)
	for sv: SubViewport in riso.ui_plates:
		ui_rids.append(sv.get_viewport_rid())
		plate_views.append(sv)
	for r: RID in plate_rids + ui_rids:
		RenderingServer.viewport_set_measure_render_time(r, true)
	for row: int in rows:
		var at: Vector2i = Vector2i(28, row)
		if info.coord != at:
			MapInfo.debug = true
			info.debug_travel(at)
			MapInfo.debug = false
			await until(func() -> bool: return info.coord == at and not info.travelling)
		await _neighbours(row)
		print("BENCH row %d %s, %d nodes" % [row, info.world.size, get_node_count()])
		var base: float = await measure("all on", true)
		if base_only:
			continue
		await price("UI print pass off", base, _ui_print_off)
		await price("plain scene shader", base, _plain_shader)
		await price("plates without MSAA", base, _no_msaa)
		await price("plates not rendering", base, _plates_frozen)
		await price("legacy art culled", base, _legacy_culled)
		await price("GPU given nothing", base, _gpu_idle)
	finish()


## Wait for the generator's worker to lay out the neighbouring places (it starts on arrival and
## would share the CPU with the measurements), and print how long that took and the frames meanwhile.
func _neighbours(row: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var count: int = 0
	var worst: float = 0.0
	var t_prev: int = t0
	while info.loader.gen_busy or not info.loader.prefetch.is_empty():
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, float(now - t_prev) / 1000.0)
		t_prev = now
		count += 1
		if now - t0 > 60000000:
			break
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("BENCH row %d: neighbours laid out %.2f s after arriving, frames meanwhile %.2f ms (worst %.1f ms)" % [row, ms / 1000.0, ms / maxf(1.0, float(count)), worst])


## Time a steady frame and print where it went; returns the wall-clock frame in ms.
func measure(label: String, per_plate: bool = false) -> float:
	for i: int in range(WARM):
		await process_frame
	var physics: float = 0.0
	var steps: int = 0
	var process: float = 0.0
	var redraws: float = 0.0
	var root_gpu: float = 0.0
	var plates_gpu: float = 0.0
	var ui_gpu: float = 0.0
	var sheet_gpu: float = 0.0
	var render_cpu: float = 0.0
	var each_plate: Array[float] = []
	each_plate.resize(plate_rids.size() + ui_rids.size())
	each_plate.fill(0.0)
	var times: Array[float] = []
	var t0: int = Time.get_ticks_usec()
	var t_prev: int = t0
	for i: int in range(FRAMES):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - t_prev) / 1000.0)
		t_prev = now
		physics += float(first.physics_us) / 1000.0
		steps += first.frame_steps
		process += float(last.stamp - first.stamp) / 1000.0
		redraws += float(last.flushed - last.stamp) / 1000.0
		root_gpu += RenderingServer.viewport_get_measured_render_time_gpu(root_rid)
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root_rid) + RenderingServer.get_frame_setup_time_cpu()
		if riso.sheet_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			sheet_gpu += RenderingServer.viewport_get_measured_render_time_gpu(sheet_rid)
			render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(sheet_rid)
		var k: int = 0
		for r: RID in plate_rids:
			if plate_views[k].render_target_update_mode == SubViewport.UPDATE_DISABLED:
				k += 1
				continue
			var g: float = RenderingServer.viewport_get_measured_render_time_gpu(r)
			plates_gpu += g
			each_plate[k] += g
			render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(r)
			k += 1
		for r: RID in ui_rids:
			if plate_views[k].render_target_update_mode == SubViewport.UPDATE_DISABLED:
				k += 1
				continue
			var g: float = RenderingServer.viewport_get_measured_render_time_gpu(r)
			ui_gpu += g
			each_plate[k] += g
			render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(r)
			k += 1
	var n: float = float(FRAMES)
	var frame: float = float(Time.get_ticks_usec() - t0) / 1000.0 / n
	var cpu: float = (physics + process + redraws) / n
	var gpu: float = (root_gpu + sheet_gpu + plates_gpu + ui_gpu) / n
	times.sort()
	print("BENCH   %s %-22s frame %6.2f ms (median %6.2f, p90 %6.2f)  CPU %6.2f = physics %5.2f (%.1f steps) + process %5.2f + redraws %5.2f; render cpu %5.2f  |  GPU %6.2f = window %5.2f + print %5.2f + plates %5.2f + UI plates %5.2f" % [
		Time.get_time_string_from_system(), label, frame, times[FRAMES / 2], times[FRAMES * 9 / 10], cpu, physics / n, float(steps) / n, process / n, redraws / n, render_cpu / n,
		gpu, root_gpu / n, sheet_gpu / n, plates_gpu / n, ui_gpu / n])
	if per_plate:
		var parts: PackedStringArray = []
		for i: int in range(each_plate.size()):
			parts.append("%s%d %.2f" % ["p" if i < plate_rids.size() else "u", i % RisoPrint.PLATE_COUNT if i < plate_rids.size() else i - plate_rids.size(), each_plate[i] / n])
		print("BENCH     GPU by plate (ms): %s" % ", ".join(parts))
	return frame


## Measure with `change` made (called with true, then false to undo it), and print what it saves.
func price(label: String, base: float, change: Callable) -> void:
	change.call(true)
	var ms: float = await measure(label)
	change.call(false)
	print("BENCH     -> saves %.2f ms a frame" % (base - ms))


## The UI's print pass off: its rect hidden and its plates not rendering.
func _ui_print_off(on: bool) -> void:
	riso.ui_rect.visible = not on
	for vp: SubViewport in riso.ui_plates:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_ALWAYS


## The scene printed by PLAIN instead of the riso shader.
func _plain_shader(on: bool) -> void:
	if not on:
		riso.print_rect.material = riso.print_material
		return
	var shader: Shader = Shader.new()
	shader.code = PLAIN
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader
	for i: int in range(RisoPrint.PLATE_COUNT):
		m.set_shader_parameter("plate%d" % i, riso.print_material.get_shader_parameter("plate%d" % i))
		m.set_shader_parameter("ink%d" % i, riso.print_material.get_shader_parameter("ink%d" % i))
	m.set_shader_parameter("paper", riso.print_material.get_shader_parameter("paper"))
	riso.print_rect.material = m


## Every plate without antialiasing (then as it was).
func _no_msaa(on: bool) -> void:
	var all: Array[SubViewport] = riso.plates + riso.ui_plates
	if on:
		saved_msaa.clear()
		for vp: SubViewport in all:
			saved_msaa.append(vp.msaa_2d)
			vp.msaa_2d = Viewport.MSAA_DISABLED
	else:
		for i: int in range(all.size()):
			all[i].msaa_2d = saved_msaa[i]


## No plate rendering: the print shaders read what the plates last held.
func _plates_frozen(on: bool) -> void:
	for vp: SubViewport in riso.plates + riso.ui_plates:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_ALWAYS


## The window drawing only the print (its two rects, or at light graphics the sheet showing them),
## not the legacy art under it.
func _legacy_culled(on: bool) -> void:
	var shown: Array[CanvasItem] = [riso.print_rect, riso.ui_rect, riso.sheet_rect]
	if on:
		saved_mask = root.canvas_cull_mask
		for item: CanvasItem in shown:
			item.visibility_layer = SPARE_BIT | 1
		root.canvas_cull_mask = SPARE_BIT
	else:
		root.canvas_cull_mask = saved_mask
		for item: CanvasItem in shown:
			item.visibility_layer = 1


## Nothing for the GPU: no plates, no print, nothing in the window.
func _gpu_idle(on: bool) -> void:
	_plates_frozen(on)
	if riso.graphics == &"light":
		riso.sheet_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_ALWAYS
	riso.print_layer.visible = not on
	if on:
		saved_mask = root.canvas_cull_mask
		root.canvas_cull_mask = 0
	else:
		root.canvas_cull_mask = saved_mask
