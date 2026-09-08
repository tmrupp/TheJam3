@tool
extends ColorRect
## Fourier reconstruction of radial or closed silhouettes. No texture or native extension needed.
## Place as a child of a portal, pickup, UI panel, or a Node2D.

enum Outline { ROUNDED_DIAMOND, ROUNDED_SQUARE, ORBITAL, HUMANOID }

@export var outline: Outline = Outline.ROUNDED_DIAMOND:
	set(value):
		outline = value
		if is_node_ready():
			_update_coefficients()
@export var animate: bool = true
@export_range(0.0, 1.0) var convergence: float = 0.7
@export_range(2.0, 20.0) var cycle_seconds: float = 8.0
@export_range(2, 16) var line_count: int = 4
@export_range(0.003, 0.025) var spacing: float = 0.007
@export_range(0.5, 4.0) var line_width: float = 1.2
@export_range(0.0, 0.1) var turbulence: float = 0.045
@export_range(0.0, 1.0) var glow: float = 0.22
@export var inner_color: Color = Color(1.0, 0.39, 0.08)
@export var outer_color: Color = Color(1.0, 0.16, 0.64)

const SHADER: Shader = preload("res://shaders/fourier_contours.gdshader")
const SAMPLE_COUNT: int = 512
const HARMONICS: int = 32
# A spread-limb silhouette, clockwise from the crown. Coordinates use screen Y.
const HUMANOID_POINTS: Array[Vector2] = [
	Vector2(0.0, -0.32), Vector2(0.045, -0.305), Vector2(0.065, -0.27),
	Vector2(0.055, -0.23), Vector2(0.032, -0.21), Vector2(0.04, -0.175),
	Vector2(0.095, -0.155), Vector2(0.24, -0.205), Vector2(0.265, -0.18),
	Vector2(0.25, -0.15), Vector2(0.105, -0.065), Vector2(0.075, 0.03),
	Vector2(0.15, 0.27), Vector2(0.12, 0.30), Vector2(0.085, 0.29),
	Vector2(0.0, 0.105), Vector2(-0.085, 0.29), Vector2(-0.12, 0.30),
	Vector2(-0.15, 0.27), Vector2(-0.075, 0.03), Vector2(-0.105, -0.065),
	Vector2(-0.25, -0.15), Vector2(-0.265, -0.18), Vector2(-0.24, -0.205),
	Vector2(-0.095, -0.155), Vector2(-0.04, -0.175), Vector2(-0.032, -0.21),
	Vector2(-0.055, -0.23), Vector2(-0.065, -0.27), Vector2(-0.045, -0.305),
]
var elapsed: float = 0.0
var contour_mean := Vector2.ZERO
var contour_cos: Array[Vector2] = []
var contour_sin: Array[Vector2] = []
var cached_resolution: float = -1.0

func get_field_contour() -> PackedVector2Array:
	if outline == Outline.HUMANOID:
		return material.get_shader_parameter("contour_points")
	var points := PackedVector2Array()
	var coefficients: PackedVector2Array = material.get_shader_parameter("coefficients")
	var resolved: float = material.get_shader_parameter("convergence")
	var mean: float = material.get_shader_parameter("mean_radius")
	for index in range(128):
		var angle: float = TAU * float(index) / 128.0
		var radius: float = mean
		for harmonic in range(12):
			var n: float = harmonic + 1.0
			radius += smoothstep(n - 1.0, n, resolved * 13.0) * coefficients[harmonic].dot(Vector2(cos(n * angle), sin(n * angle)))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _ready() -> void:
	# Separate uniforms for every instance, including editor duplicates.
	var ink: ShaderMaterial = ShaderMaterial.new()
	ink.shader = SHADER
	material = ink
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_coefficients()
	_update_uniforms()

func _target_radius(angle: float) -> float:
	if outline == Outline.ORBITAL:
		return 0.225 + 0.035 * cos(3.0 * angle + 0.4) + 0.018 * sin(5.0 * angle)
	var rotated: float = angle + (PI / 4.0 if outline == Outline.ROUNDED_DIAMOND else 0.0)
	# Superellipse: rounded corners, with a genuine Fourier partial-sum reconstruction.
	var exponent: float = 4.0
	return 0.205 / pow(pow(abs(cos(rotated)), exponent) + pow(abs(sin(rotated)), exponent), 1.0 / exponent)

func _update_coefficients() -> void:
	material.set_shader_parameter("closed_contour", outline == Outline.HUMANOID)
	if outline == Outline.HUMANOID:
		_build_closed_contour()
		return
	var coefficients: PackedVector2Array = PackedVector2Array()
	coefficients.resize(HARMONICS)
	var mean: float = 0.0
	for sample_index: int in range(SAMPLE_COUNT):
		var angle: float = TAU * float(sample_index) / float(SAMPLE_COUNT)
		var radius: float = _target_radius(angle)
		mean += radius / float(SAMPLE_COUNT)
		for harmonic: int in range(HARMONICS):
			var frequency: float = float(harmonic + 1) * angle
			coefficients[harmonic] += 2.0 * radius / float(SAMPLE_COUNT) * Vector2(cos(frequency), sin(frequency))
	material.set_shader_parameter("mean_radius", mean)
	material.set_shader_parameter("coefficients", coefficients)
	material.set_shader_parameter("harmonic_count", 12)

func _build_closed_contour() -> void:
	# Arc-length sampling retains neck/underarm concavities that a radial graph cannot.
	var lengths: Array[float] = [0.0]
	for index in range(HUMANOID_POINTS.size()):
		lengths.append(lengths[-1] + HUMANOID_POINTS[index].distance_to(HUMANOID_POINTS[(index + 1) % HUMANOID_POINTS.size()]))
	contour_mean = Vector2.ZERO
	contour_cos.clear()
	contour_sin.clear()
	for harmonic in range(HARMONICS):
		contour_cos.append(Vector2.ZERO)
		contour_sin.append(Vector2.ZERO)
	var edge: int = 0
	for sample_index in range(SAMPLE_COUNT):
		var distance: float = lengths[-1] * float(sample_index) / SAMPLE_COUNT
		while edge < HUMANOID_POINTS.size() - 1 and lengths[edge + 1] < distance:
			edge += 1
		var point: Vector2 = HUMANOID_POINTS[edge].lerp(HUMANOID_POINTS[(edge + 1) % HUMANOID_POINTS.size()], (distance - lengths[edge]) / (lengths[edge + 1] - lengths[edge]))
		contour_mean += point / SAMPLE_COUNT
		for harmonic in range(HARMONICS):
			var angle: float = TAU * float(sample_index) / SAMPLE_COUNT * (harmonic + 1)
			contour_cos[harmonic] += point * (2.0 * cos(angle) / SAMPLE_COUNT)
			contour_sin[harmonic] += point * (2.0 * sin(angle) / SAMPLE_COUNT)
	cached_resolution = -1.0

func _update_closed_contour(resolved: float) -> void:
	if is_equal_approx(cached_resolution, resolved):
		return
	cached_resolution = resolved
	var points := PackedVector2Array()
	for index in range(128):
		var angle: float = TAU * float(index) / 128.0
		var point: Vector2 = contour_mean
		for harmonic in range(HARMONICS):
			var n: float = float(harmonic + 1)
			var weight: float = smoothstep(n - 1.0, n, 1.0 + resolved * HARMONICS)
			point += weight * (contour_cos[harmonic] * cos(n * angle) + contour_sin[harmonic] * sin(n * angle))
		points.append(point)
	material.set_shader_parameter("contour_points", points)

func _process(delta: float) -> void:
	if animate:
		elapsed += delta
	_update_uniforms()

func _update_uniforms() -> void:
	var resolved: float = convergence
	if animate:
		# Approach, briefly settle, and dissolve; the turn-around is continuous.
		var wave: float = 0.5 - 0.5 * cos(TAU * elapsed / max(cycle_seconds, 0.1))
		resolved = smoothstep(0.08, 0.88, wave)
	if outline == Outline.HUMANOID:
		_update_closed_contour(resolved)
	material.set_shader_parameter("rect_size", size)
	material.set_shader_parameter("phase", elapsed)
	material.set_shader_parameter("convergence", resolved)
	material.set_shader_parameter("line_count", line_count)
	material.set_shader_parameter("spacing", spacing)
	material.set_shader_parameter("line_width", line_width)
	material.set_shader_parameter("turbulence", turbulence)
	material.set_shader_parameter("glow", glow)
	material.set_shader_parameter("inner_color", inner_color)
	material.set_shader_parameter("outer_color", outer_color)
