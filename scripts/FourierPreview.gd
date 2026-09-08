extends Control

@onready var effect: ColorRect = $Effect
@onready var animate_button: CheckButton = $Panel/Controls/Animate
@onready var slider: HSlider = $Panel/Controls/Convergence
@onready var shape: OptionButton = $Panel/Controls/Outline
@onready var move_button: CheckButton = $Panel/Controls/Move
var field: ColorRect
var second: ColorRect
var motion_time: float = 0.0
var dragging: ColorRect
var drag_offset := Vector2.ZERO

func _ready() -> void:
	field = ColorRect.new()
	field.set_script(preload("res://scripts/FourierField.gd"))
	add_child(field)
	move_child(field, 1)
	effect.reparent(field)
	second = preload("res://prefabs/fourier_contours.tscn").instantiate()
	second.outline = effect.outline
	second.animate = false
	second.convergence = 1.0
	second.inner_color = Color(0.1, 1.0, 0.7)
	second.outer_color = Color(0.2, 0.45, 1.0)
	field.add_child(second)
	shape.add_item("Rounded diamond")
	shape.add_item("Rounded square")
	shape.add_item("Orbital")
	shape.add_item("Humanoid")
	shape.select(effect.get("outline"))
	shape.item_selected.connect(_select_outline)
	animate_button.toggled.connect(_toggle_animation)
	slider.value_changed.connect(_change_convergence)
	move_button.toggled.connect(_toggle_motion)
	resized.connect(_layout_effect)
	_layout_effect()

func _layout_effect() -> void:
	if not is_instance_valid(field):
		return
	field.size = size
	var side: float = min(size.x * 0.35, size.y * 0.72)
	effect.size = Vector2(side, side)
	second.size = effect.size
	_place_objects()
	field.reset_motion()

func _place_objects() -> void:
	var separation: float = size.x * (0.055 + 0.09 * (0.5 + 0.5 * cos(motion_time * 1.6)))
	var center := Vector2(size.x * 0.69, size.y * 0.54)
	effect.position = center - Vector2(separation, 0.0) - effect.size * 0.5
	second.position = center + Vector2(separation, sin(motion_time * 1.6) * size.y * 0.06) - second.size * 0.5

func _toggle_motion(enabled: bool) -> void:
	if enabled:
		_place_objects()
		field.reset_motion()

func _process(delta: float) -> void:
	if move_button.button_pressed and not is_instance_valid(dragging):
		motion_time += delta
		_place_objects()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			dragging = null
		elif get_local_mouse_position().x > size.x * 0.40:
			var mouse: Vector2 = get_local_mouse_position()
			var a: float = mouse.distance_to(effect.position + effect.size * 0.5)
			var b: float = mouse.distance_to(second.position + second.size * 0.5)
			if min(a, b) < effect.size.x * 0.45:
				dragging = effect if a < b else second
				drag_offset = dragging.position - mouse
				move_button.button_pressed = false
	if event is InputEventMouseMotion and is_instance_valid(dragging):
		dragging.position = get_local_mouse_position() + drag_offset

func _select_outline(index: int) -> void:
	effect.set("outline", index)
	second.set("outline", index)

func _toggle_animation(enabled: bool) -> void:
	effect.set("animate", enabled)
	second.set("animate", enabled)

func _change_convergence(value: float) -> void:
	animate_button.button_pressed = false
	effect.set("convergence", value)
	second.set("convergence", value)
