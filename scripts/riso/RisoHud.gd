extends Node2D
## The HUD, printed: paper plaques in the top corners, on the ink plates, so they go through the
## same riso print as the art. Laid out in the 320 x 180 UI space; the legacy HUD is hidden while
## the print is on.
## - Top left: stars, health beads, a lantern mark for protection, hex charges and the carried key.
## - Under it, while there is a ghost: its stars, an arrow toward it and its world when that is
##   elsewhere.
## - Top right: the world and depth being played, and under it the abilities known.
## - When a run ends, a card in the middle of the sheet.
## Everything sits on one grid: plaques are ROW_H tall, MARGIN from the screen edge and GAP apart,
## with contents flowing at measured widths and centred on the row's midline.
## The corner plaques are laid out at full size inside `corner`, which is drawn at CORNER_SCALE
## so they keep clear of the play area; the end card and awareness pointers stay full size.

const TEXT_PX: int = 64
const CORNER_SCALE: float = 0.68
const MARGIN: float = 4.0
const ROW_H: float = 18.0
const GAP: float = 3.0
const PAD: float = 6.0
const RADIUS: float = 6.0
## The right edge of the top-right plaques, in the corner's (unscaled) units.
const RIGHT: float = 320.0 / CORNER_SCALE - MARGIN
const KNOCK_ALL: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW]

## The canvas being drawn into: `corner_ink` for the corner plaques, `sheet_ink` otherwise.
var ink: InkCanvas
var corner: Node2D
var corner_ink: InkCanvas
var sheet_ink: InkCanvas
var coin_label: Label
var ghost_label: Label
## Whether the lantern mark shows protection (false: light another lantern).
var lantern_lit: bool = true
var where_label: Label
var ghost_where: Label
var end_title: Label
var end_sub: Label
var font: SystemFont
var t: float = 0.0
## Set to 1 by RisoPrint on a hit or death; while above 0.5 the whole sheet takes a 15% pink
## screen (as in the prototype), fading out in a third of a second.
var flash: float = 0.0
## World-to-UI mapping for this frame (for pointers at the edge of the view).
var view_origin: Vector2 = Vector2.ZERO
var view_k: float = 1.0


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	corner = Node2D.new()
	corner.scale = Vector2.ONE * CORNER_SCALE
	add_child(corner)
	corner_ink = InkCanvas.new()
	corner.add_child(corner_ink)
	sheet_ink = InkCanvas.new()
	add_child(sheet_ink)
	ink = sheet_ink
	font = RisoTheme.serif()
	coin_label = _make_label(10.0, corner)
	ghost_label = _make_label(10.0, corner)
	where_label = _make_label(9.0, corner)
	ghost_where = _make_label(8.0, corner)
	end_title = _make_label(15.0, self)
	end_sub = _make_label(8.0, self)
	for label: Label in [end_title, end_sub]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.size = Vector2(150.0 / label.scale.x, float(TEXT_PX) * 1.4)


func _make_label(px: float, parent: Node) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", TEXT_PX)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.scale = Vector2.ONE * (px / float(TEXT_PX))
	label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
	label.visible = false
	parent.add_child(label)
	return label


# ------------------------------------------------------------------ layout

func _row_top(row: int) -> float:
	return MARGIN + float(row) * (ROW_H + GAP)


func _mid(row: int) -> float:
	return _row_top(row) + ROW_H * 0.5


## Width of `text` in UI units at a label's scale.
func _text_width(label: Label, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x * label.scale.x


## Show `text` in `label` with its left edge at `x`, centred on `row`; returns its width.
func _place(label: Label, text: String, x: float, row: int) -> float:
	label.visible = true
	label.text = text
	var w: float = _text_width(label, text)
	label.size = Vector2(w / label.scale.x + 4.0, ROW_H / label.scale.y)
	label.position = Vector2(x, _row_top(row))
	return w


func _paper(rect: PackedVector2Array, tint: int, cover: float) -> void:
	ink.knock(KNOCK_ALL, [rect])
	ink.ink(tint, cover, [rect], false)


func _plaque(x: float, w: float, row: int, tint: int = RisoPrint.BLUE, cover: float = 0.12) -> void:
	_paper(RisoShapes.rrect(x, _row_top(row), w, ROW_H, RADIUS), tint, cover)


# ------------------------------------------------------------------ drawing

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
	view_origin = global_position
	view_k = 320.0 / view.x
	scale = Vector2.ONE / cam.zoom
	var player: Player = get_node_or_null("/root/Main/Player") as Player
	corner_ink.begin()
	sheet_ink.begin()
	for label: Label in [coin_label, ghost_label, where_label, ghost_where, end_title, end_sub]:
		label.visible = false
	if player != null:
		ink = corner_ink
		_status(player)
		_run_state(player)
		ink = sheet_ink
		_end_card()
		_awareness(player)
	flash = maxf(0.0, flash - delta * 3.0)
	if flash > 0.5:
		sheet_ink.ink(RisoPrint.PINK, 0.15, [PackedVector2Array([Vector2(-20, -20), Vector2(340, -20), Vector2(340, 200), Vector2(-20, 200)])], false)
	corner_ink.finish()
	sheet_ink.finish()


## Top left: stars, then health, hex charges and the carried key, on one plaque.
func _status(player: Player) -> void:
	var hp: int = player.health.health
	var hp_max: int = player.health.max_health
	var hex: Hex = player.get_node_or_null("Hex") as Hex
	var carried: bool = player.has_meta(&"carried_key")
	var info: MapInfo = MapInfo.instance
	var lantern: bool = info != null and info.world != null
	var y: float = _mid(0)
	var count: String = str(player.coins.coins)
	var count_w: float = _text_width(coin_label, count)
	# The paper goes down first, so size it from the contents.
	var width: float = PAD + 13.0 + count_w + 8.0 + 10.0 * float(hp_max) - 2.0
	if lantern:
		width += 5.0 + 10.0
	if hex != null:
		width += 5.0 + 9.0 * float(hex.charges_max)
	if carried:
		width += 6.0 + 12.0
	width += PAD
	_plaque(MARGIN, width, 0)
	var x: float = MARGIN + PAD
	# Stars: a spinning mote and the count.
	var spin: float = maxf(0.3, absf(cos(t * 2.0)))
	ink.ink(RisoPrint.ACCENT, 1.0, [Transform2D(0.0, Vector2(spin, 1.0), 0.0, Vector2(x + 5.0, y)) * RisoShapes.sparkle(Vector2.ZERO, 5.5)], false)
	x += 13.0
	_place(coin_label, count, x, 0)
	x += count_w + 8.0
	# Health: ember beads; spent ones a faint screen.
	var beads: Array[PackedVector2Array] = []
	var spent: Array[PackedVector2Array] = []
	var cores: Array[PackedVector2Array] = []
	for i: int in range(hp_max):
		var c: Vector2 = Vector2(x + 4.0 + 10.0 * float(i), y)
		if i < hp:
			beads.append(RisoShapes.circle(c, 3.6, 16))
			cores.append(RisoShapes.circle(c + Vector2(-0.8, -0.8), 1.2, 8))
		else:
			spent.append(RisoShapes.circle(c, 3.6, 16))
	ink.ink(RisoPrint.EYE, 1.0, beads, false)
	ink.ink(RisoPrint.PINK, 0.35, beads, false)
	ink.knock([RisoPrint.EYE, RisoPrint.PINK], cores)
	ink.ink(RisoPrint.NIGHT, 0.25, spent, false)
	x += 10.0 * float(hp_max) - 2.0
	if lantern:
		x += 5.0
		_lantern_mark(info, Vector2(x, y))
		x += 10.0
	# Hex charges: night-ink sparks, faint while recharging (never pink: pink is danger).
	if hex != null:
		x += 5.0
		var ready: Array[PackedVector2Array] = []
		var waiting: Array[PackedVector2Array] = []
		for i: int in range(hex.charges_max):
			var c: Vector2 = Vector2(x + 4.0 + 9.0 * float(i), y)
			if i < hex.charges:
				ready.append(Transform2D(t * 1.2, c) * RisoShapes.sparkle(Vector2.ZERO, 4.2))
			else:
				waiting.append(Transform2D(0.0, c) * RisoShapes.sparkle(Vector2.ZERO, 4.2))
		ink.ink(RisoPrint.NIGHT, 1.0, ready, false)
		ink.ink(RisoPrint.NIGHT, 0.4, waiting, false)
		x += 9.0 * float(hex.charges_max)
	if carried:
		x += 6.0
		for plate: int in RisoPrint.key_inks(int(player.get_meta(&"carried_key"))):
			ink.ink(plate, 1.0, RisoProp.key_shape(Vector2(x + 5.0, y), 0.3), false)


func _run_state(player: Player) -> void:
	var info: MapInfo = MapInfo.instance
	if info == null:
		return
	if info.world != null:
		_top_right(info, player)
	if info.has_ghost:
		_ghost_row(info, player)


## When a run ends, a card in the middle of the sheet.
func _end_card() -> void:
	var info: MapInfo = MapInfo.instance
	if info != null and info.run_ending > 0.0:
		_paper(RisoShapes.rrect(85, 58, 150, 58, 10), RisoPrint.PINK, 0.18)
		ink.ink(RisoPrint.GLOW, 1.0, RisoProp.ghost_shape(Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(160, 75))), false)
		end_title.visible = true
		end_title.text = "no lantern left"
		end_title.position = Vector2(85, 76)
		end_sub.visible = true
		end_sub.text = "world %d  ·  deepest %d" % [info.run_seed, info.deepest]
		end_sub.position = Vector2(85, 99)


## Top right: where you are, and under it the abilities you know. Both plaques share one width
## and one right edge.
func _top_right(info: MapInfo, player: Player) -> void:
	var text: String = MapInfo.where(info.coord) + ("  ·  debug" if MapInfo.debug else "")
	var text_w: float = _text_width(where_label, text)
	var owned: Array[StringName] = []
	for a: StringName in Abilities.ORDER:
		if Abilities.tier(player, a) > 0:
			owned.append(a)
	var slot: float = 16.0
	var marks_w: float = slot * float(owned.size())
	var width: float = maxf(text_w, marks_w) + PAD * 2.0
	var x0: float = RIGHT - width
	_plaque(x0, width, 0)
	_place(where_label, text, x0 + (width - text_w) * 0.5, 0)
	if owned.is_empty():
		return
	_plaque(x0, width, 1)
	var y: float = _mid(1)
	var start: float = x0 + (width - marks_w) * 0.5
	var marks: Array[PackedVector2Array] = []
	var pips: Array[PackedVector2Array] = []
	for i: int in range(owned.size()):
		var a: StringName = owned[i]
		var n: int = Abilities.tier(player, a)
		# Tier I shows the mark alone; higher tiers add a pip per tier under it.
		var c: Vector2 = Vector2(start + slot * (float(i) + 0.5), y - (2.0 if n > 1 else 0.0))
		for poly: PackedVector2Array in RisoProp.glyph(a, Vector2.ZERO, t):
			marks.append(Transform2D(0.0, Vector2(0.2, 0.2), 0.0, c) * poly)
		# The spell in the slot (the Spell button) is underlined.
		if a in Abilities.SPELLS:
			pips.append(RisoShapes.rrect(c.x - 5.0, _row_top(1) + 2.0, 10.0, 1.4, 0.7))
		if n > 1:
			for k: int in range(n):
				pips.append(RisoShapes.circle(Vector2(c.x + (float(k) - float(n - 1) * 0.5) * 3.0, _row_top(1) + ROW_H - 3.2), 1.0, 8))
	ink.ink(RisoPrint.NIGHT, 1.0, marks, false)
	ink.ink(RisoPrint.ACCENT, 1.0, pips, false)


## Second row, left: the ghost, its stars, an arrow toward it and its world when elsewhere.
func _ghost_row(info: MapInfo, player: Player) -> void:
	var y: float = _mid(1)
	var stars: String = str(info.ghost_stars)
	var elsewhere: bool = info.ghost_coord != info.coord
	var where: String = MapInfo.where(info.ghost_coord)
	var width: float = PAD + 13.0 + _text_width(ghost_label, stars) + 4.0 + 10.0
	if elsewhere:
		width += 3.0 + _text_width(ghost_where, where)
	width += PAD
	_plaque(MARGIN, width, 1, RisoPrint.PINK if info.vulnerable else RisoPrint.BLUE, 0.2 if info.vulnerable else 0.12)
	var x: float = MARGIN + PAD
	var bob: float = sin(t * 2.0) * 0.6
	# HUD icons are night ink: the glow plate takes the hat's colour, which can be pink (danger).
	ink.ink(RisoPrint.NIGHT, 1.0, RisoProp.ghost_shape(Transform2D(0.0, Vector2(0.34, 0.34), 0.0, Vector2(x + 5.0, y + 6.5 + bob))), false)
	x += 13.0
	x += _place(ghost_label, stars, x, 1) + 4.0
	var dir: Vector2 = _ghost_dir(info, player)
	if dir != Vector2.ZERO:
		var at: Vector2 = Vector2(x + 5.0, y) + dir * sin(t * 4.0) * 0.7
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var head: PackedVector2Array = PackedVector2Array([at + dir * 4.5, at + side * 3.6 - dir * 0.5, at - side * 3.6 - dir * 0.5])
		var shaft: PackedVector2Array = PackedVector2Array([at + side * 1.1, at + side * 1.1 - dir * 4.5, at - side * 1.1 - dir * 4.5, at - side * 1.1])
		ink.ink(RisoPrint.NIGHT, 1.0, [head, shaft], false)
	x += 10.0
	if elsewhere:
		x += 3.0
		x += _place(ghost_where, where, x, 1)


## Protection, as a small hanging lantern beside the health beads (left edge at `at.x`, 10
## wide), drawn like the ones in the world: a hook, a cap, a framed pane and a base. While a
## lantern is ready it hangs in night ink with warm glowing glass, a flickering flame and a soft
## halo; when another must be lit it is an empty, pulsing pink frame with a cold wick. It stays
## after recovering the ghost, since only lighting a lantern restores protection.
func _lantern_mark(info: MapInfo, at: Vector2) -> void:
	lantern_lit = not info.vulnerable
	var tint: int = RisoPrint.NIGHT if lantern_lit else RisoPrint.PINK
	var cover: float = 1.0 if lantern_lit else 0.55 + 0.45 * absf(sin(t * 3.0))
	var cx: float = at.x + 5.0
	var y: float = at.y
	if lantern_lit:
		ink.ink(RisoPrint.EYE, 0.3 * (0.9 + 0.1 * sin(t * 7.0)), [RisoShapes.circle(Vector2(cx, y + 0.5), 7.5, 20)], false)
	var hook: PackedVector2Array = RisoShapes.circle(Vector2(cx, y - 7.2), 1.8, 10)
	var cap: PackedVector2Array = PackedVector2Array([Vector2(cx - 4.0, y - 4.0), Vector2(cx - 2.2, y - 6.0), Vector2(cx + 2.2, y - 6.0), Vector2(cx + 4.0, y - 4.0)])
	var frame: PackedVector2Array = RisoShapes.rrect(cx - 4.0, y - 4.2, 8.0, 9.2, 2.0)
	var base: PackedVector2Array = RisoShapes.rrect(cx - 4.6, y + 4.6, 9.2, 1.8, 0.9)
	ink.ink(tint, cover, [hook, cap, frame, base], false)
	ink.knock([tint], [RisoShapes.circle(Vector2(cx, y - 7.2), 0.8, 8)])
	var pane: PackedVector2Array = RisoShapes.rrect(cx - 2.8, y - 3.0, 5.6, 6.9, 1.4)
	ink.knock([tint, RisoPrint.EYE], [pane])
	if lantern_lit:
		ink.ink(RisoPrint.EYE, 1.0, [pane], false)
		# The flame: a paper-white teardrop in the glowing glass.
		var f: float = 1.0 + 0.12 * sin(t * 9.0)
		var flame: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([Vector2(cx, y - 2.4 * f), Vector2(cx + 1.6, y + 1.4), Vector2(cx, y + 2.8), Vector2(cx - 1.6, y + 1.4)]), 3)
		ink.knock([RisoPrint.EYE], [flame])
	else:
		ink.ink(RisoPrint.NIGHT, cover, [RisoShapes.rrect(cx - 0.6, y + 1.2, 1.2, 2.4, 0.6)], false)


## Awareness: while sensing, a pointer at the edge of the view for each sensed thing that is off
## screen, with its mark beside the arrow.
func _awareness(player: Player) -> void:
	var aware: Awareness = player.get_node_or_null("Awareness") as Awareness
	if aware == null or not aware.active():
		return
	var fade: float = clampf(aware.sensing, 0.0, 1.0)
	# Kept below the corner plaques (two rows at CORNER_SCALE).
	var inner: Rect2 = Rect2(Vector2(14, 38), Vector2(292, 128))
	var centre: Vector2 = inner.get_center()
	var arrows: Array[PackedVector2Array] = []
	var placed: Array[Vector2] = []
	for target: Dictionary in aware.targets():
		var p: Vector2 = ((target["at"] as Vector2) - view_origin) * view_k
		if inner.grow(-6.0).has_point(p):
			continue
		var dir: Vector2 = (p - centre).normalized()
		# Where the line from the centre meets the inner rectangle.
		var tx: float = (inner.size.x * 0.5) / maxf(absf(dir.x), 0.001)
		var ty: float = (inner.size.y * 0.5) / maxf(absf(dir.y), 0.001)
		var at: Vector2 = centre + dir * minf(tx, ty) + dir * sin(t * 4.0) * 0.8
		# Never stack pointers: the first one there wins.
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(at) < 13.0):
			continue
		placed.append(at)
		var side: Vector2 = Vector2(-dir.y, dir.x)
		arrows.append(PackedVector2Array([at + dir * 5.0, at + side * 3.6 - dir * 1.0, at - side * 3.6 - dir * 1.0]))
		var mark: Vector2 = at - dir * 8.0
		_paper(RisoShapes.circle(mark, 5.6, 16), RisoPrint.BLUE, 0.12 * fade)
		match target["kind"]:
			&"exit":
				var which: int = int((target["node"] as Node).get("exit"))
				ink.ink(RisoPrint.PINK if which == MapInfo.Exit.DEEPER else RisoPrint.NIGHT, fade, [RisoShapes.arch(mark.x - 2.6, mark.y - 3.2, 5.2, 6.0, 6)], false)
			&"inkwell":
				ink.ink(RisoPrint.BLUE, fade, [RisoShapes.rrect(mark.x - 2.8, mark.y - 2.2, 5.6, 5.0, 1.8)], false)
				ink.ink(RisoPrint.ACCENT, fade, [RisoShapes.rrect(mark.x - 2.0, mark.y - 3.4, 4.0, 1.4, 0.6)], false)
			&"shrine":
				ink.ink(RisoPrint.ACCENT, fade, [RisoShapes.arch(mark.x - 2.6, mark.y - 3.2, 5.2, 6.0, 6)], false)
			&"key":
				for plate: int in RisoPrint.key_inks(int((target["node"] as Node).get_meta(&"key_color", 0))):
					ink.ink(plate, fade, RisoProp.key_shape(mark, 0.2), false)
	ink.ink(RisoPrint.NIGHT, fade, arrows, false)


## Toward the ghost: by level (deeper is down, the next seed is right) when it is elsewhere,
## otherwise straight at it. Zero when the player is standing on it.
func _ghost_dir(info: MapInfo, player: Player) -> Vector2:
	if info.ghost_coord != info.coord:
		return Vector2(signf(info.ghost_coord.x - info.coord.x), signf(info.ghost_coord.y - info.coord.y)).normalized()
	var v: Vector2 = info.ghost_pos - player.global_position
	return v.normalized() if v.length() > 48.0 else Vector2.ZERO
