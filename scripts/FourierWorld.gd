extends CanvasLayer
## Opt-in world adapter. Original sprite cores remain the identity/capacity fallback.
const CONTOUR = preload("res://scripts/FourierContours.gd")
const FIELD_SHADER: Shader = preload("res://shaders/fourier_field.gdshader")
@export var enabled: bool = false
@export var solid_shapes: bool = false
@export var reduced_motion: bool = false
@export_range(2, 4) var line_count: int = 4
@export var spacing_pixels: float = 1.25
@export var merge_radius_pixels: float = 4.0
@export var max_distortion_pixels: float = 2.0
@export var speed_for_max_distortion: float = 600.0
@export_range(1, 32) var max_passes: int = 16
var passes: Array[ColorRect] = []
var cache: Dictionary = {}
var sampler: ColorRect
var elapsed: float = 0.0
var visible_count: int = 0
var fallback_count: int = 0

func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 200
	enabled = enabled or "--fourier" in OS.get_cmdline_user_args()
	sampler = ColorRect.new()
	sampler.set_script(CONTOUR)
	sampler.animate = false
	add_child(sampler)
	sampler.hide()
	sampler.set_process(false)

func contour_for(outline: int, convergence: float) -> PackedVector2Array:
	# Quantization bounds cache growth if gameplay later animates convergence.
	var step: int = clampi(roundi(convergence * 32.0), 0, 32)
	var key: Vector2i = Vector2i(outline, step)
	if not cache.has(key):
		sampler.outline = outline
		sampler.convergence = float(step) / 32.0
		sampler._update_uniforms()
		cache[key] = sampler.get_field_contour()
	return cache[key]

func _process(delta: float) -> void:
	for pass_rect: Variant in passes:
		pass_rect.hide()
	visible_count = 0
	fallback_count = 0
	if not enabled or get_tree().paused:
		return
	for menu_name: String in ["Menu", "UpgradeMenu", "CodeMenu"]:
		var menu: CanvasLayer = get_parent().get_node_or_null(menu_name) as CanvasLayer
		if menu != null and menu.visible:
			return
	if not reduced_motion:
		elapsed += delta
	var screen: Rect2 = get_viewport().get_visible_rect()
	var groups: Dictionary = {}
	for visual: Variant in get_tree().get_nodes_in_group("fourier_visuals"):
		if visual.get_viewport() != get_viewport() or not visual.presentation_visible():
			continue
		var transform: Transform2D = visual.get_global_transform_with_canvas()
		var points: PackedVector2Array = PackedVector2Array()
		var bounds: Rect2 = Rect2(transform.origin, Vector2.ZERO)
		for point: Variant in contour_for(visual.outline, visual.convergence):
			var projected: Vector2 = transform * (point * visual.contour_size)
			points.append(projected)
			bounds = bounds.expand(projected)
		bounds = bounds.grow(merge_radius_pixels + line_count * spacing_pixels + max_distortion_pixels * 2.0 + 3.0)
		if not bounds.intersects(screen):
			continue
		var tint: Color = visual.presentation_tint()
		if tint.a <= 0.001:
			continue
		var velocity: Vector2 = visual.world_velocity
		# Transform direction only: camera translation/zoom cannot create speed.
		var canvas: Transform2D = visual.get_canvas_transform()
		var direction: Vector2 = (canvas * velocity - canvas.origin).normalized()
		var motion: Vector2 = direction * clampf(velocity.length() / max(speed_for_max_distortion, 1.0), 0.0, 1.0)
		if reduced_motion:
			motion = Vector2.ZERO
		var entry: Dictionary = {"points": points, "bounds": bounds, "center": transform.origin,
			"hole": minf(transform.x.length() * visual.contour_size.x, transform.y.length() * visual.contour_size.y) * 0.23 * visual.opening_ratio,
			"motion": motion, "inner": visual.inner_color * tint, "outer": visual.outer_color * tint,
			"unresolved": 0.0 if reduced_motion else maxf(1.0 - visual.convergence, visual.effect_pulse)}
		var group: StringName = visual.merge_group
		if not groups.has(group):
			groups[group] = []
		groups[group].append(entry)
		visible_count += 1
	var pass_index: int = 0
	for group: Variant in groups:
		var entries: Array = groups[group]
		# Conservative capacity fallback: never split a union across shader batches.
		# More than four in a group degrades the WHOLE group to independent contours.
		if entries.size() <= 4 and group != &"":
			pass_index = _draw_entries(entries, pass_index, screen)
		else:
			for entry: Variant in entries:
				pass_index = _draw_entries([entry], pass_index, screen)

func _draw_entries(entries: Array, index: int, screen: Rect2) -> int:
	if index >= max_passes:
		fallback_count += entries.size() # Original sprites were never hidden.
		return index
	if index == passes.size():
		var rect: ColorRect = ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = ShaderMaterial.new()
		rect.material.shader = FIELD_SHADER
		add_child(rect)
		passes.append(rect)
	var rect: ColorRect = passes[index]
	var bounds: Rect2 = entries[0].bounds
	for entry: Variant in entries:
		bounds = bounds.merge(entry.bounds)
	bounds = bounds.intersection(screen)
	var points: PackedVector2Array = PackedVector2Array()
	var centers: PackedVector2Array = PackedVector2Array()
	var motion: PackedVector2Array = PackedVector2Array()
	var inner: PackedColorArray = PackedColorArray()
	var outer: PackedColorArray = PackedColorArray()
	var unresolved: PackedFloat32Array = PackedFloat32Array()
	var holes: PackedFloat32Array = PackedFloat32Array()
	points.resize(512)
	centers.resize(4)
	motion.resize(4)
	inner.resize(4)
	outer.resize(4)
	unresolved.resize(4)
	holes.resize(4)
	for object: Variant in range(entries.size()):
		var entry: Dictionary = entries[object]
		for point: Variant in range(128):
			points[object * 128 + point] = entry.points[point] - bounds.position
		centers[object] = entry.center - bounds.position
		motion[object] = entry.motion
		inner[object] = entry.inner
		outer[object] = entry.outer
		unresolved[object] = entry.unresolved
		holes[object] = entry.hole
	rect.position = bounds.position
	rect.size = bounds.size
	var ink: ShaderMaterial = rect.material
	ink.set_shader_parameter("points", points)
	ink.set_shader_parameter("centers", centers)
	ink.set_shader_parameter("motion", motion)
	ink.set_shader_parameter("inner_colors", inner)
	ink.set_shader_parameter("outer_colors", outer)
	ink.set_shader_parameter("unresolved", unresolved)
	ink.set_shader_parameter("hole_radius", holes)
	ink.set_shader_parameter("object_count", entries.size())
	ink.set_shader_parameter("rect_size", rect.size)
	ink.set_shader_parameter("line_count", line_count)
	ink.set_shader_parameter("spacing", spacing_pixels)
	ink.set_shader_parameter("line_width", 0.55)
	ink.set_shader_parameter("merge_radius", max(merge_radius_pixels, 0.001))
	ink.set_shader_parameter("max_distortion", 0.0 if reduced_motion else max_distortion_pixels)
	ink.set_shader_parameter("phase", elapsed)
	ink.set_shader_parameter("solid_shapes", solid_shapes)
	rect.show()
	return index + 1
