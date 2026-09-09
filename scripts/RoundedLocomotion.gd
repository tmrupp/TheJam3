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
var body_spring: Vector2 = Vector2(1.0, 0.0) # Width stretch, lean shear.
var body_rate: Vector2 = Vector2.ZERO
var previous_velocity: Vector2 = Vector2.ZERO
var was_grounded: bool = true
var envelope_direction: Vector2 = Vector2.RIGHT
var envelope_strength: float = 0.0
var reversing: bool = false

func setup(actor: CharacterBody2D, renderer: CanvasLayer) -> void:
	player = actor
	world = renderer
	visual = player.get_node("FourierVisual")
	visual.motion_reset.connect(reset_dynamics)
	var tail_layer: CanvasLayer = CanvasLayer.new()
	tail_layer.layer = 0 # The solid body occludes the front of the contour tail.
	add_child(tail_layer)
	rings = Node2D.new()
	tail_layer.add_child(rings)
	rings.draw.connect(_draw_rings)
	reset_dynamics()

func reset_dynamics() -> void:
	body_spring = Vector2(1.0, 0.0)
	body_rate = Vector2.ZERO
	previous_velocity = Vector2.ZERO
	was_grounded = player.is_on_floor()
	envelope_strength = 0.0
	reversing = false
	visual.transform = Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2(0, -5))

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
	_update_dynamics(delta, grounded, bob)
	queue_redraw()
	rings.queue_redraw()

func _update_dynamics(delta: float, grounded: bool, bob: float) -> void:
	var velocity: Vector2 = visual.world_velocity
	var acceleration: Vector2 = (velocity - previous_velocity) / maxf(delta, 0.001)
	var horizontal: float = clampf(absf(velocity.x) / 600.0, 0.0, 1.0)
	var vertical: float = clampf(absf(velocity.y) / 600.0, 0.0, 1.0)
	var target: Vector2 = Vector2(1.0 + 0.12 * horizontal - (0.14 * vertical if not grounded else 0.0),
		clampf(velocity.x / 600.0 * 0.2 + acceleration.x / 6000.0 * 0.1, -0.28, 0.28))
	if grounded and not was_grounded and previous_velocity.y > 80.0:
		body_rate.x += minf(previous_velocity.y / 300.0, 2.0) * 2.0
	previous_velocity = velocity
	was_grounded = grounded
	if world.reduced_motion:
		body_spring = Vector2(1.0, 0.0)
		body_rate = Vector2.ZERO
		envelope_strength = 0.0
	else:
		# Bounded substeps keep the spring stable across render rates and stalls.
		var duration: float = minf(delta, 0.2)
		var steps: int = maxi(1, ceili(duration * 120.0))
		var dt: float = duration / steps
		for step: int in range(steps):
			body_rate += ((target - body_spring) * 324.0 - body_rate * 27.0) * dt
			body_spring += body_rate * dt
		body_spring.x = clampf(body_spring.x, 0.84, 1.18)
		body_spring.y = clampf(body_spring.y, -0.3, 0.3)
		_update_envelope(delta, velocity)
	# Area-preserving stretch + hip-pivoted shear: top lags, feet remain independent.
	var basis_x: Vector2 = Vector2(body_spring.x, 0.0)
	var basis_y: Vector2 = Vector2(-body_spring.y, 1.0 / body_spring.x)
	var hip: Vector2 = Vector2(0, 3.0 - (0.0 if world.reduced_motion else bob))
	visual.transform = Transform2D(basis_x, basis_y, hip - basis_y * 8.0)

func _update_envelope(delta: float, velocity: Vector2) -> void:
	var target_strength: float = clampf(velocity.length() / 600.0, 0.0, 1.0)
	if velocity.length() > 5.0:
		var desired: Vector2 = velocity.normalized()
		if envelope_direction.dot(desired) < -0.25 and envelope_strength > 0.06:
			reversing = true
		if reversing:
			envelope_strength = lerpf(envelope_strength, 0.0, 1.0 - exp(-30.0 * delta))
			if envelope_strength <= 0.06:
				envelope_direction = desired
				reversing = false
			return
		if envelope_strength < 0.025:
			envelope_direction = desired
		else:
			envelope_direction = envelope_direction.rotated(envelope_direction.angle_to(desired) * (1.0 - exp(-16.0 * delta)))
	envelope_strength = lerpf(envelope_strength, target_strength, 1.0 - exp(-14.0 * delta))

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

func envelope_geometry() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var canvas: Transform2D = player.get_canvas_transform()
	var direction: Vector2 = (canvas * envelope_direction - canvas.origin).normalized()
	var transform: Transform2D = visual.get_global_transform_with_canvas()
	var center: Vector2 = transform.origin
	var contour: PackedVector2Array = world.contour_for(visual.outline, visual.convergence)
	for ring: int in range(3):
		var points: PackedVector2Array = PackedVector2Array()
		var weights: PackedFloat32Array = PackedFloat32Array()
		for point: Vector2 in contour:
			var relative: Vector2 = transform * (point * visual.contour_size) - center
			var normal: Vector2 = relative.normalized()
			var rear: float = smoothstep(-0.5, 0.8, -normal.dot(direction))
			var gap: float = 2.0 + ring * 2.7
			var tail: float = envelope_strength * (4.0 + ring * ring * 9.0)
			points.append(center + relative + normal * gap - direction * rear * tail)
			weights.append(lerpf(0.2, 1.0, rear))
		points.append(points[0])
		weights.append(weights[0])
		result.append({"points": points, "weights": weights})
	return result

func _draw_rings() -> void:
	if not is_instance_valid(player) or world.reduced_motion or envelope_strength < 0.025:
		return
	var tint: Color = visual.presentation_tint()
	var geometry: Array[Dictionary] = envelope_geometry()
	for ring: int in range(geometry.size()):
		var points: PackedVector2Array = geometry[ring].points
		var weights: PackedFloat32Array = geometry[ring].weights
		var colors: PackedColorArray = PackedColorArray()
		for index: int in range(points.size()):
			var weight: float = weights[index]
			var color: Color = visual.inner_color.lerp(visual.outer_color, float(ring) / 2.0)
			color.a = (0.2 + 0.65 * envelope_strength) * weight * (1.0 - ring * 0.18) * tint.a
			colors.append(color)
		rings.draw_polyline_colors(points, colors, 1.6 - ring * 0.18, true)
