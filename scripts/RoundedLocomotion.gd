extends Node2D
## Procedural legs + a current-velocity ring cone. No position history is stored.
var player: CharacterBody2D
var world: CanvasLayer
var visual: Node2D
var gait_phase: float = 0.0
var stride_blend: float = 0.0
var facing: float = 1.0
var grounded_override: int = -1 # Art capture/tests only; gameplay reads is_on_floor().
var rings: Node2D

func setup(actor: CharacterBody2D, renderer: CanvasLayer) -> void:
	player = actor
	world = renderer
	visual = player.get_node("FourierVisual")
	var tail_layer: CanvasLayer = CanvasLayer.new()
	tail_layer.layer = 0 # The solid body occludes the front of the contour tail.
	add_child(tail_layer)
	rings = Node2D.new()
	tail_layer.add_child(rings)
	rings.draw.connect(_draw_rings)

func _process(delta: float) -> void:
	var speed: float = absf(visual.world_velocity.x)
	var grounded: bool = player.is_on_floor() if grounded_override < 0 else grounded_override == 1
	if speed > 5.0:
		facing = signf(visual.world_velocity.x)
	var target: float = clampf(speed / 100.0, 0.0, 1.0) if grounded else 0.0
	stride_blend = lerpf(stride_blend, target, 1.0 - exp(-delta * 18.0))
	if grounded and speed > 5.0:
		gait_phase = fmod(gait_phase + speed * delta / 80.0, 1.0)
	var bob: float = absf(sin(gait_phase * TAU * 2.0)) * stride_blend * 0.35
	visual.position.y = -5.0 - (0.0 if world.reduced_motion else bob)
	queue_redraw()
	rings.queue_redraw()

func foot_position(leg: int) -> Vector2:
	var grounded: bool = player.is_on_floor() if grounded_override < 0 else grounded_override == 1
	var side: float = -1.0 if leg == 0 else 1.0
	if not grounded:
		return Vector2(side * 3.0 - facing * 1.5, 5.8)
	var cycle: float = fmod(gait_phase + float(leg) * 0.5, 1.0)
	var x: float
	var lift: float = 0.0
	if cycle < 0.5:
		x = lerpf(5.0, -5.0, cycle * 2.0) # Stance: moves backward relative to body.
	else:
		var swing: float = (cycle - 0.5) * 2.0
		x = lerpf(-5.0, 5.0, smoothstep(0.0, 1.0, swing))
		lift = sin(swing * PI) * 3.0
	return Vector2(side * 2.3 + x * facing * stride_blend, 6.8 - lift * stride_blend)

func _draw() -> void:
	if not is_instance_valid(player):
		return
	var transform: Transform2D = player.get_global_transform_with_canvas()
	var tint: Color = visual.presentation_tint()
	for leg: int in range(2):
		var side: float = -1.0 if leg == 0 else 1.0
		var hip: Vector2 = Vector2(side * 2.3, 2.7)
		var foot: Vector2 = foot_position(leg)
		var knee: Vector2 = hip.lerp(foot, 0.55) + Vector2(facing * 1.0, 0.0)
		var color: Color = Color(0.78, 0.37, 0.3) if leg == 0 else Color(1.0, 0.64, 0.43)
		color *= tint
		var width: float = transform.x.length() * 1.7
		draw_line(transform * hip, transform * knee, color, width, true)
		draw_line(transform * knee, transform * foot, color, width, true)
		draw_circle(transform * knee, width * 0.5, color)
		draw_line(transform * foot, transform * (foot + Vector2(facing * 1.5, 0.0)), color, width, true)
		draw_circle(transform * foot, width * 0.5, color)

func _draw_rings() -> void:
	if not is_instance_valid(player) or world.reduced_motion:
		return
	var velocity: Vector2 = visual.world_velocity
	var strength: float = clampf(velocity.length() / 600.0, 0.0, 1.0)
	if strength < 0.025:
		return
	var canvas: Transform2D = player.get_canvas_transform()
	var direction: Vector2 = (canvas * velocity - canvas.origin).normalized()
	var transform: Transform2D = visual.get_global_transform_with_canvas()
	var center: Vector2 = transform.origin
	var tint: Color = visual.presentation_tint()
	var contour: PackedVector2Array = world.contour_for(visual.outline, visual.convergence)
	for ring: int in range(4):
		var taper: float = 1.0 - float(ring) * 0.19
		var ring_center: Vector2 = center - direction * ((10.0 + ring * 12.0) * (0.4 + strength))
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in contour:
			var relative: Vector2 = transform * (point * visual.contour_size) - center
			points.append(ring_center + relative * taper)
		points.append(points[0])
		var color: Color = visual.inner_color.lerp(visual.outer_color, float(ring) / 3.0)
		color.a = (0.25 + 0.6 * strength) * taper * tint.a
		rings.draw_polyline(points, color, 0.6 + 1.5 * taper, true)
