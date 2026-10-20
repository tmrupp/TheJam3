extends TestKit
## Where the GPU's frame goes in the print, at a few places: each pass timed on the GPU (the main
## view with the print and UI shaders, the scene's eight plates, the UI's nine), then again with
## one suspect switched off at a time (antialiasing on the plates, the UI's plates and print, the
## print shader's work), to find what a weak GPU (integrated graphics) pays for most.
## godot --path . --windowed --script res://tests/bench_print.gd -- 1920x1080

## The rows timed (the garden, the cemetery, the institute).
const ROWS: Array[int] = [0, 8, 11]
## Frames averaged for each measurement, after a few to settle.
const FRAMES: int = 120
const SETTLE: int = 20
## The print shaders as they were before they skipped the plates with no ink near (kept to compare
## against).
const REF_PRINT: String = "res://tests/proto/riso_print_ref.gdshader"
const REF_UI: String = "res://tests/proto/riso_ui_ref.gdshader"

## A print shader that only samples each plate once and multiplies its ink in: what the print
## would cost with none of its screen, wobble or grain.
const PLAIN: String = """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D plate0 : filter_linear; uniform sampler2D plate1 : filter_linear;
uniform sampler2D plate2 : filter_linear; uniform sampler2D plate3 : filter_linear;
uniform sampler2D plate4 : filter_linear; uniform sampler2D plate5 : filter_linear;
uniform sampler2D plate6 : filter_linear; uniform sampler2D plate7 : filter_linear;
uniform vec3 paper; uniform vec3 ink0; uniform vec3 ink1; uniform vec3 ink2; uniform vec3 ink3;
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

var riso: RisoPrint
var vp: RID


func run() -> void:
	var size: Vector2i = Vector2i(1280, 720)
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("x")
		if parts.size() == 2:
			size = Vector2i(int(parts[0]), int(parts[1]))
	window(size)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await boot(28)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	riso = RisoPrint.instance
	vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for sv: SubViewport in riso.plates + riso.ui_plates + [riso.sheet_viewport]:
		RenderingServer.viewport_set_measure_render_time(sv.get_viewport_rid(), true)
	for i: int in range(10):
		await process_frame
	print("BENCH window %s, plates %s, %s" % [root.size, riso.plates[0].size, RenderingServer.get_video_adapter_name()])
	var print_shader: Shader = riso.print_material.shader
	var ui_shader: Shader = riso.ui_material.shader
	var plain: Shader = Shader.new()
	plain.code = PLAIN
	var fast_print: Shader = load(REF_PRINT) as Shader
	var fast_ui: Shader = load(REF_UI) as Shader
	for row: int in ROWS:
		var at: Vector2i = Vector2i(28, row)
		if info.coord != at:
			MapInfo.debug = true
			info.debug_travel(at)
			MapInfo.debug = false
			await until(func() -> bool: return info.coord == at and not info.travelling)
		for i: int in range(60):
			await process_frame
		print("BENCH row %d %s" % [row, info.world.size])
		var base: Dictionary = await _measure("as it is")
		var each: Array = base["each"]
		var line: String = "BENCH     each scene plate's gpu:"
		for i: int in range(each.size()):
			line += " %.3f" % float(each[i])
		print(line)
		_msaa(Viewport.MSAA_2X)
		await _measure("2x antialiasing on plates")
		_msaa(Viewport.MSAA_DISABLED)
		await _measure("no antialiasing on plates")
		_msaa(Viewport.MSAA_4X)
		_ui(false)
		await _measure("no UI plates or UI print")
		_ui(true)
		riso.ui_rect.visible = false
		await _measure("UI plates but no UI print")
		riso.print_material.shader = plain
		await _measure("plain print, no UI print")
		riso.print_material.shader = print_shader
		riso.ui_rect.visible = true
		riso.print_material.shader = fast_print
		riso.ui_material.shader = fast_ui
		await _measure("print as it was (every plate)")
		riso.print_material.shader = print_shader
		riso.ui_material.shader = ui_shader
		riso.set_graphics(&"light")
		await _measure("light graphics")
		riso.set_graphics(&"full")
		if row == ROWS[0]:
			await _compare(fast_print, fast_ui, print_shader, ui_shader)
	finish()


func _msaa(mode: Viewport.MSAA) -> void:
	for sv: SubViewport in riso.plates + riso.ui_plates:
		sv.msaa_2d = mode


func _ui(on: bool) -> void:
	for sv: SubViewport in riso.ui_plates:
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	riso.ui_rect.visible = on


## The same still printed by the print shaders and by the prototype: how far apart they are.
func _compare(fast_print: Shader, fast_ui: Shader, print_shader: Shader, ui_shader: Shader) -> void:
	paused = true
	for i: int in range(10):
		await process_frame
	var a: Image = root.get_texture().get_image()
	riso.print_material.shader = fast_print
	riso.ui_material.shader = fast_ui
	for i: int in range(10):
		await process_frame
	var b: Image = root.get_texture().get_image()
	riso.print_material.shader = print_shader
	riso.ui_material.shader = ui_shader
	paused = false
	var differ: int = 0
	var most: float = 0.0
	var sum: float = 0.0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var d: float = maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			sum += d
			most = maxf(most, d)
			if d > 4.0 / 255.0:
				differ += 1
	var n: int = a.get_width() * a.get_height()
	print("BENCH     the print against how it was: %d of %d pixels differ by more than 4/255 (%.3f%%), most %.0f/255, mean %.3f/255" % [differ, n, 100.0 * differ / n, most * 255.0, sum / n * 255.0])
	a.save_png(ProjectSettings.globalize_path(STILLS).path_join("bench_print_a.png"))
	b.save_png(ProjectSettings.globalize_path(STILLS).path_join("bench_print_b.png"))


## Times FRAMES frames: the whole frame (wall clock), the main view (with the light graphics' sheet
## the print shaders draw into), the scene's plates and the UI's on the GPU, and each scene plate
## alone.
func _measure(label: String) -> Dictionary:
	for i: int in range(SETTLE):
		await process_frame
	var main_gpu: float = 0.0
	var plates_gpu: float = 0.0
	var ui_gpu: float = 0.0
	var each: Array[float] = []
	each.resize(riso.plates.size())
	each.fill(0.0)
	var t0: int = Time.get_ticks_usec()
	for i: int in range(FRAMES):
		await process_frame
		main_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		if riso.graphics == &"light":
			main_gpu += RenderingServer.viewport_get_measured_render_time_gpu(riso.sheet_viewport.get_viewport_rid())
		for k: int in range(riso.plates.size()):
			var g: float = RenderingServer.viewport_get_measured_render_time_gpu(riso.plates[k].get_viewport_rid())
			each[k] += g / FRAMES
			plates_gpu += g
		for sv: SubViewport in riso.ui_plates:
			ui_gpu += RenderingServer.viewport_get_measured_render_time_gpu(sv.get_viewport_rid())
	var frame: float = float(Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
	var total: float = (main_gpu + plates_gpu + ui_gpu) / FRAMES
	print("BENCH   %-30s gpu %6.3f ms = main view %6.3f + scene plates %6.3f + UI plates %6.3f   (frame %6.2f ms)" % [label, total, main_gpu / FRAMES, plates_gpu / FRAMES, ui_gpu / FRAMES, frame])
	return {"total": total, "each": each}
