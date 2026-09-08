extends ColorRect
## Shared visual union of up to four direct FourierContours children.
## Child positions and colors remain independent; this changes no collision shapes.
const CONTOUR = preload("res://scripts/FourierContours.gd")
@export_range(2, 8) var line_count: int = 4
@export var spacing_pixels: float = 2.0
@export var line_width_pixels: float = 0.65
@export var merge_radius_pixels: float = 10.0
@export var speed_for_max_distortion: float = 150.0
@export var max_distortion_pixels: float = 7.0
var previous: Dictionary = {}
var velocities: Dictionary = {}
var elapsed: float = 0.0

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/fourier_field.gdshader")
	process_priority = 10
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset_motion() -> void:
	previous.clear()
	velocities.clear()

func _process(delta: float) -> void:
	elapsed += delta
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(512)
	var centers: PackedVector2Array = PackedVector2Array()
	var motion: PackedVector2Array = PackedVector2Array()
	var inner: PackedColorArray = PackedColorArray()
	var outer: PackedColorArray = PackedColorArray()
	var unresolved: PackedFloat32Array = PackedFloat32Array()
	centers.resize(4)
	motion.resize(4)
	inner.resize(4)
	outer.resize(4)
	unresolved.resize(4)
	var count: int = 0
	for child: Variant in get_children():
		if not child is CONTOUR:
			continue
		child.hide() # Only the shared field draws; children still update their harmonics.
		if count == 4:
			child.show() # Capacity fallback: keep extra objects independently visible.
			continue
		var transform: Transform2D = child.get_transform()
		var center: Vector2 = transform * (child.size * 0.5)
		var id: int = child.get_instance_id()
		var measured: Vector2 = (center - previous.get(id, center)) / max(delta, 0.00001)
		var velocity: Vector2 = velocities.get(id, Vector2.ZERO)
		velocity = velocity.lerp(measured, 1.0 - exp(-delta * 14.0))
		previous[id] = center
		velocities[id] = velocity
		centers[count] = center
		motion[count] = velocity.limit_length(max(speed_for_max_distortion, 1.0)) / max(speed_for_max_distortion, 1.0)
		inner[count] = child.inner_color
		outer[count] = child.outer_color
		unresolved[count] = 1.0 - float(child.material.get_shader_parameter("convergence"))
		var contour: PackedVector2Array = child.get_field_contour()
		for index: Variant in range(128):
			points[count * 128 + index] = transform * (child.size * 0.5 + contour[index] * min(child.size.x, child.size.y))
		count += 1
	material.set_shader_parameter("object_count", count)
	material.set_shader_parameter("points", points)
	material.set_shader_parameter("centers", centers)
	material.set_shader_parameter("motion", motion)
	material.set_shader_parameter("inner_colors", inner)
	material.set_shader_parameter("outer_colors", outer)
	material.set_shader_parameter("unresolved", unresolved)
	material.set_shader_parameter("rect_size", size)
	material.set_shader_parameter("phase", elapsed)
	material.set_shader_parameter("line_count", line_count)
	material.set_shader_parameter("spacing", spacing_pixels)
	material.set_shader_parameter("line_width", line_width_pixels)
	material.set_shader_parameter("merge_radius", max(merge_radius_pixels, 0.001))
	material.set_shader_parameter("max_distortion", max_distortion_pixels)
