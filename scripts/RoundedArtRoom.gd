extends "res://scripts/FourierRoom.gd"
## Art-direction study: no raster sprites or pixel-grid presentation.
var identities: Node2D
var feedback: Node2D
var locomotion: Node2D
var old_scale: Vector2i
var old_snap_transforms: bool
var old_snap_vertices: bool
var old_msaa: int

func _ready() -> void:
	old_scale = get_window().content_scale_size
	old_snap_transforms = get_viewport().snap_2d_transforms_to_pixel
	old_snap_vertices = get_viewport().snap_2d_vertices_to_pixel
	old_msaa = get_viewport().msaa_2d
	get_window().content_scale_size = Vector2i(960, 540)
	get_viewport().snap_2d_transforms_to_pixel = false
	get_viewport().snap_2d_vertices_to_pixel = false
	get_viewport().msaa_2d = Viewport.MSAA_4X
	super._ready()
	$Camera2D.zoom = Vector2(0.75, 0.75)
	$CanvasLayer.hide()
	$FourierWorld.solid_shapes = true
	$FourierWorld.spacing_pixels = 3.0
	$FourierWorld.merge_radius_pixels = 13.0
	$FourierWorld.max_distortion_pixels = 6.0
	var visual: Node2D = player.get_node("FourierVisual")
	visual.outline = 1
	visual.contour_size = Vector2(38, 40)
	visual.position.y = -5.0
	visual.inner_color = Color(1.0, 0.66, 0.44)
	visual.outer_color = Color(1.0, 0.35, 0.62)
	# Visibility masks hide pixels without overriding gameplay visibility/modulation.
	player.get_node("Sprite2D").visibility_layer = 0
	player.get_node("ParticleController").visibility_layer = 0
	player.get_node("Parry").visibility_layer = 0
	for portal: Node2D in portals:
		portal.get_node("AnimatedSprite2D").visibility_layer = 0
		portal.get_node("Area2D/Interactable/Sprite2D").visibility_layer = 0
		var portal_visual: Node2D = portal.get_node("FourierVisual")
		portal_visual.outline = 4
		portal_visual.contour_size = Vector2(52, 52)
		portal_visual.opening_ratio = 0.76
		portal_visual.inner_color = Color(0.47, 0.9, 0.8)
		portal_visual.outer_color = Color(0.43, 0.6, 1.0)
	var violet: Node = portals[1].get_node("FourierVisual")
	violet.inner_color = Color(0.76, 0.66, 1.0)
	violet.outer_color = Color(1.0, 0.42, 0.7)
	# Crisp code-drawn identity marks remain separate from the merging field.
	identities = Node2D.new()
	var identity_layer: CanvasLayer = CanvasLayer.new()
	identity_layer.layer = 2
	add_child(identity_layer)
	identity_layer.add_child(identities)
	locomotion = Node2D.new()
	locomotion.set_script(preload("res://scripts/RoundedLocomotion.gd"))
	identity_layer.add_child(locomotion)
	locomotion.setup(player, $FourierWorld)
	feedback = Node2D.new()
	feedback.set_script(preload("res://scripts/RoundedFeedback.gd"))
	identity_layer.add_child(feedback)
	feedback.setup(player, $FourierWorld)
	identities.draw.connect(_draw_identities)
	var heading: Label = Label.new()
	heading.position = Vector2(40, 36)
	heading.add_theme_font_size_override("font_size", 24)
	heading.text = "SOFT FORMS / SIGNAL IN MOTION"
	heading.modulate = Color(0.88, 0.88, 0.94)
	identity_layer.add_child(heading)
	var note: Label = Label.new()
	note.position = Vector2(40, 75)
	note.add_theme_font_size_override("font_size", 15)
	note.text = "Move / jump / dash    E: portal    P: project/return    H: hit    K: death    F2: reduced motion"
	note.modulate = Color(0.5, 0.53, 0.63)
	identity_layer.add_child(note)

func _process(_delta: float) -> void:
	identities.queue_redraw()

func _draw_identities() -> void:
	var transform: Transform2D = player.get_node("FourierVisual").get_global_transform_with_canvas()
	var color: Color = Color(0.13, 0.12, 0.2, player.get_node("Sprite2D").modulate.a)
	identities.draw_circle(transform * Vector2(-2.3, -1.3), 2.4, color)
	identities.draw_circle(transform * Vector2(2.3, -1.3), 2.4, color)

func _unhandled_key_input(event: InputEvent) -> void:
	# Keep the new art visible: F1 changes contour intensity, not the base art style.
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		$FourierWorld.reduced_motion = not $FourierWorld.reduced_motion
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		var projection: Node = player.get_node("AstralProjection")
		if is_instance_valid(projection.false_player_origin):
			projection.end_projection(projection.projection_timer)
		else:
			projection.project()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		player.hurt(-1, Vector2.ZERO, null)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		player.die()
	else:
		super._unhandled_key_input(event)

func _exit_tree() -> void:
	get_window().content_scale_size = old_scale
	get_viewport().snap_2d_transforms_to_pixel = old_snap_transforms
	get_viewport().snap_2d_vertices_to_pixel = old_snap_vertices
	get_viewport().msaa_2d = old_msaa
