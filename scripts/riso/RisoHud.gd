extends Node2D
## The HUD, printed: a paper label in the top-left corner carrying the coin mote and count,
## health as ember beads, and collected keys with their codes. It lives on the ink plates
## (it follows the camera in the world canvas), so it goes through the same riso print as the
## art. Laid out in the 320 x 180 UI space; the legacy HUD is hidden while the print is on.
## Top right, the world and depth being played. Below the main label, while there is a ghost:
## its stars, an arrow toward it and its world when that is elsewhere, and while vulnerable the
## fresh stars still needed. When a run ends, a card in the middle of the sheet.

const TEXT_PX: int = 64
var ink: InkCanvas
var coin_label: Label
var key_labels: Array[Label] = []
var ghost_label: Label
var need_label: Label
var where_label: Label
var ghost_where: Label
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
	where_label = _make_label(9.0)
	ghost_where = _make_label(7.0)
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
		for label: Label in [coin_label, ghost_label, need_label, where_label, ghost_where, end_title, end_sub]:
			label.visible = false
		for label: Label in key_labels:
			label.visible = false
		ink.finish()
		return
	var hp: int = player.health.health
	var hp_max: int = player.health.max_health
	var carried: bool = player.has_meta(&"carried_key")
	var hex: Hex = player.get_node_or_null("Hex") as Hex
	var charge_w: float = 9.0 * float(hex.charges_max) + 3.0 if hex != null else 0.0
	var width: float = 58.0 + 11.0 * float(hp_max) + charge_w + (16.0 if carried else 0.0)
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
	# Hex charges: glow sparks, faint while recharging.
	if hex != null:
		for i: int in range(hex.charges_max):
			var c: Vector2 = Vector2(56.0 + 11.0 * float(hp_max) + 1.0 + 9.0 * float(i), 15.0)
			var ready: bool = i < hex.charges
			var spark: PackedVector2Array = Transform2D(t * 1.5 if ready else 0.0, c) * RisoShapes.sparkle(Vector2.ZERO, 4.2)
			ink.ink(RisoPrint.GLOW, 1.0 if ready else 0.3, [spark], false)
	if carried:
		var at: Vector2 = Vector2(56.0 + 11.0 * float(hp_max) + charge_w + 4.0, 15.0)
		for plate: int in RisoPrint.key_inks(int(player.get_meta(&"carried_key"))):
			ink.ink(plate, 1.0, RisoProp.key_shape(at, 0.33), false)
	_run_state(player)
	ink.finish()


## Width of `text` in UI units at a label's scale.
func _text_width(label: Label, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x * label.scale.x


func _paper(rect: PackedVector2Array, tint: int, cover: float) -> void:
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [rect])
	ink.ink(tint, cover, [rect], false)


func _run_state(player: Player) -> void:
	var info: MapInfo = MapInfo.instance
	where_label.visible = info != null and info.world != null
	ghost_label.visible = info != null and info.has_ghost
	need_label.visible = info != null and info.has_ghost and info.vulnerable
	ghost_where.visible = info != null and info.has_ghost and info.ghost_coord != info.coord
	end_title.visible = info != null and info.run_ending > 0.0
	end_sub.visible = end_title.visible
	if info == null:
		return
	if where_label.visible:
		# The level being played, top right: shareable, since levels are the same for everyone.
		where_label.text = MapInfo.where(info.coord) + ("  ·  debug" if MapInfo.debug else "")
		var w: float = _text_width(where_label, where_label.text)
		_paper(RisoShapes.rrect(316.0 - w - 14.0, 4, w + 14.0, 20, 7), RisoPrint.BLUE, 0.12)
		where_label.position = Vector2(316.0 - w - 7.0, 6.5)
		_abilities(player)
	if info.has_ghost:
		ghost_label.text = str(info.ghost_stars)
		ghost_label.position = Vector2(23, 32)
		var x: float = 23.0 + _text_width(ghost_label, ghost_label.text) + 4.0
		var arrow_at: Vector2 = Vector2(x + 6.0, 40)
		x += 14.0
		if ghost_where.visible:
			ghost_where.text = MapInfo.where(info.ghost_coord)
			ghost_where.position = Vector2(x, 34.5)
			x += _text_width(ghost_where, ghost_where.text) + 6.0
		var star_at: Vector2 = Vector2(x + 6.0, 40)
		if info.vulnerable:
			need_label.text = "%d/%d" % [info.fresh_stars, info.recover_need]
			need_label.position = Vector2(x + 14.0, 32)
			x += 14.0 + _text_width(need_label, need_label.text) + 4.0
		_paper(RisoShapes.rrect(4, 30, x + 2.0, 20, 7), RisoPrint.PINK if info.vulnerable else RisoPrint.BLUE, 0.2 if info.vulnerable else 0.12)
		var bob: float = sin(t * 2.0) * 0.8
		ink.ink(RisoPrint.GLOW, 1.0, RisoProp.ghost_shape(Transform2D(0.0, Vector2(0.42, 0.42), 0.0, Vector2(14, 48.5 + bob))), false)
		var dir: Vector2 = _ghost_dir(info, player)
		if dir != Vector2.ZERO:
			var at: Vector2 = arrow_at + dir * sin(t * 4.0) * 0.8
			var side: Vector2 = Vector2(-dir.y, dir.x)
			var head: PackedVector2Array = PackedVector2Array([at + dir * 5.5, at + side * 4.2 - dir * 0.5, at - side * 4.2 - dir * 0.5])
			var shaft: PackedVector2Array = PackedVector2Array([at + side * 1.3, at + side * 1.3 - dir * 5.5, at - side * 1.3 - dir * 5.5, at - side * 1.3])
			ink.ink(RisoPrint.NIGHT, 1.0, [head, shaft], false)
		if info.vulnerable:
			# A cracked star: the fresh stars still needed to shake off the vulnerable state.
			ink.ink(RisoPrint.PINK, 1.0, [RisoShapes.sparkle(star_at, 6.0)], false)
			ink.knock([RisoPrint.PINK], [Transform2D(0.9, star_at) * RisoShapes.rrect(-7, -0.5, 14, 1.0, 0.5)])
	if info.run_ending > 0.0:
		_paper(RisoShapes.rrect(85, 58, 150, 58, 10), RisoPrint.PINK, 0.18)
		ink.ink(RisoPrint.GLOW, 1.0, RisoProp.ghost_shape(Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(160, 75))), false)
		end_title.text = "the run ends"
		end_title.position = Vector2(85, 76)
		end_sub.text = "world %d  ·  deepest %d" % [info.run_seed, info.deepest]
		end_sub.position = Vector2(85, 99)


## Under the world tag: each ability known, as its shrine mark with a pip per tier.
func _abilities(player: Player) -> void:
	var owned: Array[StringName] = []
	for a: StringName in Abilities.ORDER:
		if Abilities.tier(player, a) > 0:
			owned.append(a)
	if owned.is_empty():
		return
	var slot: float = 17.0
	var x0: float = 316.0 - slot * float(owned.size()) - 6.0
	_paper(RisoShapes.rrect(x0, 28, slot * float(owned.size()) + 6.0, 24, 7), RisoPrint.BLUE, 0.12)
	for i: int in range(owned.size()):
		var a: StringName = owned[i]
		var c: Vector2 = Vector2(x0 + 3.0 + slot * (float(i) + 0.5), 37.0)
		var mark: Array[PackedVector2Array] = []
		for poly: PackedVector2Array in RisoProp.glyph(a, Vector2.ZERO, t):
			mark.append(Transform2D(0.0, Vector2(0.24, 0.24), 0.0, c) * poly)
		ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
		var n: int = Abilities.tier(player, a)
		var pips: Array[PackedVector2Array] = []
		for k: int in range(n):
			pips.append(RisoShapes.circle(Vector2(c.x + (float(k) - float(n - 1) * 0.5) * 3.2, 47.0), 1.1, 8))
		ink.ink(RisoPrint.ACCENT, 1.0, pips, false)


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
