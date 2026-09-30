extends Node2D
## The HUD, printed: a paper label in the top-left corner carrying the coin mote and count,
## health as ember beads, and collected keys with their codes. It lives on the ink plates
## (it follows the camera in the world canvas), so it goes through the same riso print as the
## art. Laid out in the 320 x 180 UI space; the legacy HUD is hidden while the print is on.

const TEXT_PX: int = 64
var ink: InkCanvas
var coin_label: Label
var key_labels: Array[Label] = []
var font: SystemFont
var t: float = 0.0


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)
	font = RisoTheme.serif()
	coin_label = _make_label()


func _make_label() -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", TEXT_PX)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.scale = Vector2.ONE * (10.0 / float(TEXT_PX))
	label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
	add_child(label)
	return label


func _process(delta: float) -> void:
	t += delta
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var base: Vector2 = Vector2(get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var view: Vector2 = base / cam.zoom
	global_position = cam.get_screen_center_position() - view * 0.5
	scale = Vector2.ONE / cam.zoom
	var player: Player = get_node_or_null("/root/Main/Player") as Player
	ink.begin()
	if player == null:
		coin_label.visible = false
		for label: Label in key_labels:
			label.visible = false
		ink.finish()
		return
	var hp: int = player.health.health
	var hp_max: int = player.health.max_health
	var carried: bool = player.has_meta(&"carried_key")
	var width: float = 58.0 + 11.0 * float(hp_max) + (16.0 if carried else 0.0)
	var height: float = 22.0
	# Bare-paper label: every plate cleared so the HUD prints as ink on paper.
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [RisoShapes.rrect(4, 4, width, height, 7)])
	ink.ink(RisoPrint.BLUE, 0.12, [RisoShapes.rrect(4, 4, width, height, 7)], false)
	var spin: float = maxf(0.3, absf(cos(t * 2.0)))
	ink.ink(RisoPrint.ACCENT, 1.0, [Transform2D(0.0, Vector2(spin, 1.0), 0.0, Vector2(14, 15)) * RisoShapes.sparkle(Vector2.ZERO, 6.0)], false)
	coin_label.visible = true
	coin_label.text = str(player.coins.coins)
	coin_label.position = Vector2(23, 8)
	var beads: Array[PackedVector2Array] = []
	var spent: Array[PackedVector2Array] = []
	var cores: Array[PackedVector2Array] = []
	for i: int in range(hp_max):
		var c: Vector2 = Vector2(56.0 + 11.0 * float(i), 15.0)
		if i < hp:
			beads.append(RisoShapes.circle(c, 3.8, 16))
			cores.append(RisoShapes.circle(c + Vector2(-0.8, -0.8), 1.3, 8))
		else:
			spent.append(RisoShapes.circle(c, 3.8, 16))
	ink.ink(RisoPrint.EYE, 1.0, beads, false)
	ink.ink(RisoPrint.PINK, 0.35, beads, false)
	ink.knock([RisoPrint.EYE, RisoPrint.PINK], cores)
	ink.ink(RisoPrint.NIGHT, 0.25, spent, false)
	if carried:
		var at: Vector2 = Vector2(56.0 + 11.0 * float(hp_max) + 4.0, 15.0)
		for plate: int in RisoPrint.key_inks(int(player.get_meta(&"carried_key"))):
			ink.ink(plate, 1.0, RisoProp.key_shape(at, 0.33), false)
	ink.finish()


func _key_codes() -> Array[String]:
	var codes: Array[String] = []
	var keys: Node = get_node_or_null("/root/Main/CanvasLayer/HUD/Keys")
	if keys == null:
		return codes
	for i: int in range(1, keys.get_child_count()):
		var label: Label = keys.get_child(i).get_node_or_null("Label") as Label
		if label != null and label.text != "":
			codes.append(label.text)
	return codes
