extends Node2D
## Presentation-only provider. Never reparents or hides its gameplay owner.
@export_enum("Diamond", "Square", "Orbital", "Humanoid", "Circle") var outline: int = 3
@export var contour_size: Vector2 = Vector2(32, 32)
@export var inner_color: Color = Color(1.0, 0.39, 0.08)
@export var outer_color: Color = Color(1.0, 0.16, 0.64)
@export var merge_group: StringName = &"friendly"
@export var source_visual: NodePath = NodePath("../Sprite2D")
@export_range(0.0, 1.0) var convergence: float = 1.0
var world_velocity: Vector2 = Vector2.ZERO
var previous_position: Vector2 = Vector2.ZERO
var reset_pending: bool = true
var effect_pulse: float = 0.0

func pulse(strength: float = 1.0) -> void:
	effect_pulse = maxf(effect_pulse, clampf(strength, 0.0, 1.0))

func _enter_tree() -> void:
	add_to_group("fourier_visuals")
	reset_motion()

func _ready() -> void:
	process_priority = 100

func reset_motion() -> void:
	reset_pending = true
	world_velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	effect_pulse = maxf(0.0, effect_pulse - delta * 1.8)
	if reset_pending:
		reset_pending = false
		world_velocity = Vector2.ZERO
	else:
		var measured: Vector2 = (global_position - previous_position) / max(delta, 0.00001)
		world_velocity = world_velocity.lerp(measured, 1.0 - exp(-14.0 * delta))
	previous_position = global_position

func presentation_visible() -> bool:
	var source: CanvasItem = get_node_or_null(source_visual) as CanvasItem
	return is_visible_in_tree() and (source == null or source.is_visible_in_tree())

func presentation_tint() -> Color:
	var source: CanvasItem = get_node_or_null(source_visual) as CanvasItem
	return modulate * (source.modulate * source.self_modulate if source != null else Color.WHITE)
