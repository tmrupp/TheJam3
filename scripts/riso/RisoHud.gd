extends Node2D
## The HUD, printed: a paper label in the top-left corner carrying the coin mote and count,
## health as ember beads, and collected keys with their codes. It lives on the ink plates
## (it follows the camera in the world canvas), so it goes through the same riso print as the
## art. Laid out in the 320 x 180 UI space; the legacy HUD is hidden while the print is on.
## Below it, while there is a ghost: its stars and an arrow toward it, and while vulnerable the
## fresh stars still needed. When a run ends, a card in the middle of the sheet.

const TEXT_PX: int = 64
var ink: InkCanvas
var coin_label: Label
var key_labels: Array[Label] = []
var ghost_label: Label
var need_label: Label
var end_title: Label
var end_sub: Label
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
	ghost_label = _make_label()
	need_label = _make_label()
	end_title = _make_label(15.0)
	end_sub = _make_label(8.0)
	for label: Label in [end_title, end_sub]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(150.0 / label.scale.x, float(TEXT_PX) * 1.4)


func _make_label(px: float = 10.0) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", TEXT_PX)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.scale = Vector2.ONE * (px / float(TEXT_PX))
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
		for label: Label in [coin_label, ghost_label, need_label, end_title, end_sub]:
			label.visible = false
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
	_run_state(player)
	ink.finish()


func _run_state(player: Player) -> void:
	var info: MapInfo = MapInfo.instance
	ghost_label.visible = info != null and info.has_ghost
	need_label.visible = info != null and info.has_ghost and info.vulnerable
	end_title.visible = info != null and info.run_ending > 0.0
	end_sub.visible = end_title.visible
	if info == null:
		return
	if info.has_ghost:
		var width: float = 100.0 if info.vulnerable else 56.0
		var chip: PackedVector2Array = RisoShapes.rrect(4, 30, width, 20, 7)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [chip])
		ink.ink(RisoPrint.PINK if info.vulnerable else RisoPrint.BLUE, 0.2 if info.vulnerable else 0.12, [chip], false)
		var bob: float = sin(t * 2.0) * 0.8
		ink.ink(RisoPrint.GLOW, 1.0, RisoProp.ghost_shape(Transform2D(0.0, Vector2(0.42, 0.42), 0.0, Vector2(14, 48.5 + bob))), false)
		ghost_label.text = str(info.ghost_stars)
		ghost_label.position = Vector2(23, 32)
		var dir: Vector2 = _ghost_dir(info, player)
		if dir != Vector2.ZERO:
			var at: Vector2 = Vector2(48, 40) + dir * sin(t * 4.0) * 0.8
			var side: Vector2 = Vector2(-dir.y, dir.x)
			var head: PackedVector2Array = PackedVector2Array([at + dir * 5.5, at + side * 4.2 - dir * 0.5, at - side * 4.2 - dir * 0.5])
			var shaft: PackedVector2Array = PackedVector2Array([at + side * 1.3, at + side * 1.3 - dir * 5.5, at - side * 1.3 - dir * 5.5, at - side * 1.3])
			ink.ink(RisoPrint.NIGHT, 1.0, [head, shaft], false)
		if info.vulnerable:
			# A cracked star: the fresh stars still needed to shake off the vulnerable state.
			var star: PackedVector2Array = RisoShapes.sparkle(Vector2(66, 40), 6.0)
			ink.ink(RisoPrint.PINK, 1.0, [star], false)
			ink.knock([RisoPrint.PINK], [Transform2D(0.9, Vector2(66, 40)) * RisoShapes.rrect(-7, -0.5, 14, 1.0, 0.5)])
			need_label.text = "%d/%d" % [info.fresh_stars, info.recover_need]
			need_label.position = Vector2(74, 32)
	if info.run_ending > 0.0:
		var card: PackedVector2Array = RisoShapes.rrect(85, 58, 150, 58, 10)
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [card])
		ink.ink(RisoPrint.PINK, 0.18, [card], false)
		ink.ink(RisoPrint.GLOW, 1.0, RisoProp.ghost_shape(Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(160, 75))), false)
		end_title.text = "the run ends"
		end_title.position = Vector2(85, 76)
		end_sub.text = "seed %d  ·  deepest %d" % [info.run_seed, info.deepest]
		end_sub.position = Vector2(85, 99)


## Toward the ghost: by level (deeper is down, the next seed is right) when it is elsewhere,
## otherwise straight at it. Zero when the player is standing on it.
func _ghost_dir(info: MapInfo, player: Player) -> Vector2:
	if info.ghost_coord != info.coord:
		return Vector2(signf(info.ghost_coord.x - info.coord.x), signf(info.ghost_coord.y - info.coord.y)).normalized()
	var v: Vector2 = info.ghost_pos - player.global_position
	return v.normalized() if v.length() > 48.0 else Vector2.ZERO


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
