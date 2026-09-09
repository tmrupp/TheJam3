extends Node2D
## Presentation-only snapshots: never enter the union, physics, or world RNG.
var player: CharacterBody2D
var world: CanvasLayer
var traces: Array[Dictionary] = []
var projection: Dictionary = {}
var remnant_refs: Array[WeakRef] = []
var dash_remaining: float = 0.0
var sample_remaining: float = 0.0
var events_seen: Dictionary = {}
var held_palette: Array[Color] = []

func setup(actor: CharacterBody2D, renderer: CanvasLayer) -> void:
	player = actor
	world = renderer
	player.visual_event.connect(on_event)
	player.corpse_created.connect(_on_remnant)

func snapshot(at: Vector2, color: Color, lifetime: float, kind: StringName) -> Dictionary:
	var visual: Node2D = player.get_node("FourierVisual")
	var transform: Transform2D = visual.global_transform
	transform.origin = at
	var vertices: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in world.contour_for(visual.outline, 1.0):
		vertices.append(transform * (point * visual.contour_size))
	return {"points": vertices, "center": at, "color": color, "age": 0.0, "life": lifetime, "kind": kind}

func on_event(kind: StringName, at: Vector2) -> void:
	events_seen[kind] = int(events_seen.get(kind, 0)) + 1
	match kind:
		&"dash":
			dash_remaining = 0.25
			sample_remaining = 0.0
		&"projection_start":
			projection = snapshot(at, Color(0.52, 0.9, 1.0, 0.75), 1.0, kind)
			var visual: Node = player.get_node("FourierVisual")
			held_palette = [visual.inner_color, visual.outer_color]
			visual.inner_color = Color(0.5, 1.0, 1.0)
			visual.outer_color = Color(0.55, 0.7, 1.0)
		&"projection_end":
			projection.clear()
			if held_palette.size() == 2:
				var visual: Node = player.get_node("FourierVisual")
				visual.inner_color = held_palette[0]
				visual.outer_color = held_palette[1]
				held_palette.clear()
			traces.append(snapshot(at, Color(0.52, 0.9, 1.0), 0.5, &"return"))
		&"death":
			traces.append(snapshot(at, Color(1.0, 0.48, 0.65), 0.85, kind))
		&"hurt":
			traces.append(snapshot(at, Color(1.0, 0.85, 0.67), 0.4, kind))
		&"jump":
			traces.append(snapshot(at, Color(1.0, 0.65, 0.48, 0.5), 0.3, kind))
	while traces.size() > 24:
		traces.pop_front()
	queue_redraw()

func _on_remnant(corpse: Node2D) -> void:
	corpse.get_node("Sprite2D").visibility_layer = 0
	remnant_refs.append(weakref(corpse))

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	for index: int in range(traces.size() - 1, -1, -1):
		traces[index].age += delta
		if traces[index].age >= traces[index].life:
			traces.remove_at(index)
	if dash_remaining > 0.0:
		dash_remaining -= delta
		sample_remaining -= delta
		if sample_remaining <= 0.0 and not world.reduced_motion:
			sample_remaining = 0.04
			traces.append(snapshot(player.global_position, Color(1.0, 0.54, 0.62, 0.55), 0.38, &"ghost"))
	for index: int in range(remnant_refs.size() - 1, -1, -1):
		if remnant_refs[index].get_ref() == null:
			remnant_refs.remove_at(index)
	queue_redraw()

func _draw_trace(trace: Dictionary, persistent: bool = false) -> void:
	var progress: float = 0.0 if persistent else trace.age / trace.life
	var expansion: float = 0.0 if world.reduced_motion else progress * (0.7 if trace.kind == &"death" else 0.25)
	var canvas: Transform2D = player.get_canvas_transform()
	var color: Color = trace.color
	color.a *= 1.0 - progress
	var ring_count: int = 3 if trace.kind == &"death" and not world.reduced_motion else 1
	for ring: int in range(ring_count):
		var points: PackedVector2Array = PackedVector2Array()
		for index: int in range(trace.points.size()):
			var point: Vector2 = trace.points[index]
			var residual: float = 0.0
			if trace.kind == &"death" and not world.reduced_motion:
				residual = sin(float(index) / 128.0 * TAU * 5.0 + progress * 8.0 + ring) * progress * 0.12
			points.append(canvas * (trace.center + (point - trace.center) * (1.0 + expansion + ring * 0.12 + residual)))
		points.append(points[0])
		draw_polyline(points, color, 1.6, true)

func _draw() -> void:
	if not is_instance_valid(player):
		return
	for trace: Dictionary in traces:
		if world.reduced_motion and trace.kind == &"ghost":
			continue
		_draw_trace(trace)
	if not projection.is_empty():
		_draw_trace(projection, true)
		var center: Vector2 = player.get_canvas_transform() * projection.center
		draw_circle(center + Vector2(-7, -4), 2.0, Color(0.52, 0.9, 1.0, 0.7))
		draw_circle(center + Vector2(7, -4), 2.0, Color(0.52, 0.9, 1.0, 0.7))
	for reference: WeakRef in remnant_refs:
		var corpse: Node2D = reference.get_ref() as Node2D
		if corpse != null:
			var center: Vector2 = corpse.get_global_transform_with_canvas().origin
			draw_circle(center, 9.0, Color(1.0, 0.72, 0.4, 0.3))
			draw_arc(center, 9.0, 0.0, TAU, 48, Color(1.0, 0.72, 0.4), 1.5, true)
			draw_circle(center, 2.5, Color(1.0, 0.85, 0.65))
