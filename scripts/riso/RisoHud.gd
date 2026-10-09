extends Node2D
class_name RisoHud
## The HUD, printed. It draws in the UI's own canvas (RisoPrint.ui_canvas), which is printed over
## the scene with finer dots, wobble and registration, so small marks and text stay legible. Laid
## out in the 320 x 180 UI space; the legacy HUD is hidden while the print is on.
## There are no standing plaques: what they showed is in the game itself. Health is the traveler's
## necklace, protection their lantern, keys trail behind them, and the place shows when sitting and
## on the level transition. The only writing is numbers: a place is its marks
## (RisoMarks.place_marks) with the world's and depth's numbers. What remains here:
## - Sitting (hold Down), a card over the traveler's head with the stars carried and the place.
## - While there is a ghost, a pointer at the edge of the view toward it.
## - While sensing (Awareness), a pointer at the edge of the view for each sensed thing off screen.
## - When a run ends, a card in the middle of the sheet.

const TEXT_PX: int = 64
const PAD: float = 4.0
const RADIUS: float = 5.0
const GAP: float = 2.0
## The sitting card's row height, and how high over the traveler's feet it hangs (art units).
const CARD_H: float = 10.0
## Half the height of a place's marks on a card's row, and on the end card.
const PLACE_R: float = 3.0
const END_PLACE_R: float = 5.0
const CARD_ABOVE: float = 40.0
## The UI's print is pinned to the screen, so small numbers moving across it shimmer as they are
## screened afresh each frame. Sitting pans the camera down (Down looks down), so the sitting card
## is put where the traveler will be once the view has settled, on whole pixels, and stays there
## until that place strays more than CARD_SLACK (UI units), as on a lift.
const CARD_SLACK: float = 3.0
## Pointers sit on this rectangle, just inside the edge of the view.
const VIEW_INNER: Rect2 = Rect2(Vector2(14, 14), Vector2(292, 152))
const KNOCK_ALL: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE]

## The node in the UI's canvas that holds all the HUD's art, kept on the camera like this one.
var canvas: Node2D
var ink: InkCanvas
var coin_label: Label
## The world's and depth's numbers of the place printed on the sitting card, by the ghost's
## pointer and on the end card.
var world_label: Label
var depth_label: Label
var ghost_label: Label
var ghost_world: Label
var ghost_depth: Label
var end_world: Label
var end_depth: Label
var font: SystemFont
var t: float = 0.0
## Set to 1 by RisoPrint on a hit or death; while above 0.5 the whole sheet takes a 15% pink
## screen (as in the prototype), fading out in a third of a second.
var flash: float = 0.0
## World-to-UI mapping for this frame (for pointers at the edge of the view).
var view_origin: Vector2 = Vector2.ZERO
var view_k: float = 1.0
## Whether the sitting card is up, and where it is held (UI units).
var _card_up: bool = false
var _card_at: Vector2 = Vector2.ZERO
## Half the view this frame, in world pixels.
var _view_half: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	# Everything is drawn in the UI's canvas, printed finer than the scene (RisoPrint.ui_canvas).
	canvas = RisoPrint.ui_canvas(self)
	canvas.z_index = 60
	canvas.z_as_relative = false
	ink = InkCanvas.new()
	ink.ui = true
	canvas.add_child(ink)
	font = RisoTheme.serif()
	coin_label = _make_label(6.5)
	world_label = _make_label(5.5)
	depth_label = _make_label(5.5)
	ghost_label = _make_label(5.5)
	ghost_world = _make_label(5.0)
	ghost_depth = _make_label(5.0)
	end_world = _make_label(9.0)
	end_depth = _make_label(9.0)


func _make_label(px: float) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", TEXT_PX)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.scale = Vector2.ONE * (px / float(TEXT_PX))
	label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
	label.visible = false
	canvas.add_child(label)
	return label


# ------------------------------------------------------------------ layout

## Width of `text` in UI units at a label's scale.
func _text_width(label: Label, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x * label.scale.x


## Show `text` in `label` with its left edge at `x`, centred on `y`; returns its width. Placed on
## whole pixels, like the plaques under it (see _seated_card), so it never shimmers against them.
func _place(label: Label, text: String, x: float, y: float, h: float = CARD_H) -> float:
	label.visible = true
	label.text = text
	var w: float = _text_width(label, text)
	label.size = Vector2(w / label.scale.x + 4.0, h / label.scale.y)
	label.position = Vector2(x, y - h * 0.5).round()
	return w


func _paper(rect: PackedVector2Array, tint: int, cover: float) -> void:
	ink.knock(KNOCK_ALL, [rect])
	ink.ink(tint, cover, [rect], false)


## Where a pointer toward `dir` sits on the edge of the view (on VIEW_INNER), bobbing a little
## unless `still` (for text beside it, which would shimmer moving over the screen-pinned print).
func _edge(dir: Vector2, still: bool = false) -> Vector2:
	var centre: Vector2 = VIEW_INNER.get_center()
	var tx: float = (VIEW_INNER.size.x * 0.5) / maxf(absf(dir.x), 0.001)
	var ty: float = (VIEW_INNER.size.y * 0.5) / maxf(absf(dir.y), 0.001)
	return centre + dir * minf(tx, ty) + (Vector2.ZERO if still else dir * sin(t * 4.0) * 0.8)


## The numbers of place `at`, as text for its two labels.
func _place_texts(at: Vector2i) -> PackedStringArray:
	var n: Vector3i = Rules.place_numbers(at)
	return PackedStringArray([str(n.x), str(absi(n.y))])


## How wide place `at` prints with marks of half height `r`, its numbers in `labels`' size.
func _place_w(at: Vector2i, r: float, labels: Array[Label]) -> float:
	var texts: PackedStringArray = _place_texts(at)
	var widths: Vector2 = Vector2(_text_width(labels[0], texts[0]), _text_width(labels[1], texts[1]))
	return RisoMarks.place_width(r, widths, Worlds.is_side(at))


## Print place `at` from `left` (centred on its y): its marks, and its numbers in `labels`.
func _place_row(at: Vector2i, left: Vector2, r: float, labels: Array[Label], h: float = CARD_H) -> void:
	var texts: PackedStringArray = _place_texts(at)
	var widths: Vector2 = Vector2(_text_width(labels[0], texts[0]), _text_width(labels[1], texts[1]))
	var xs: Vector2 = RisoMarks.place_marks(ink, left, r, widths, Worlds.is_side(at), Rules.place_numbers(at).y < 0)
	_place(labels[0], texts[0], xs.x, left.y, h)
	_place(labels[1], texts[1], xs.y, left.y, h)


## A pointer's arrowhead at `at`, toward `dir`.
func _arrow(at: Vector2, dir: Vector2) -> PackedVector2Array:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	return PackedVector2Array([at + dir * 5.0, at + side * 3.6 - dir * 1.0, at - side * 3.6 - dir * 1.0])


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
	_view_half = view * 0.5
	scale = Vector2.ONE / cam.zoom
	canvas.global_position = global_position
	canvas.scale = scale
	canvas.visible = visible
	var player: Player = Stage.player()
	ink.begin()
	for label: Label in [coin_label, world_label, depth_label, ghost_label, ghost_world, ghost_depth, end_world, end_depth]:
		label.visible = false
	if player != null:
		_end_card()
		var placed: Array[Vector2] = []
		_ghost_pointer(player, placed)
		_awareness(player, placed)
		_seated_card(player, cam)
	flash = maxf(0.0, flash - delta * 3.0)
	if flash > 0.5:
		ink.ink(RisoPrint.PINK, 0.15, [PackedVector2Array([Vector2(-20, -20), Vector2(340, -20), Vector2(340, 200), Vector2(-20, 200)])], false)
	ink.finish()


## When a run ends, a card in the middle of the sheet: the ghost, and under it the world and the
## furthest from the start reached (a depth, or a height above the start).
func _end_card() -> void:
	var info: MapInfo = MapInfo.instance
	if info != null and info.run_ending > 0.0:
		_paper(RisoShapes.rrect(110, 54, 100, 62, 10), RisoPrint.PINK, 0.18)
		ink.ink(RisoPrint.GLOW, 1.0, RisoMarks.ghost_shape(Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(160, 84))), false)
		var at: Vector2i = Vector2i(info.run.run_seed, info.run.furthest_row)
		var labels: Array[Label] = [end_world, end_depth]
		_place_row(at, Vector2(160.0 - _place_w(at, END_PLACE_R, labels) * 0.5, 104.0), END_PLACE_R, labels, 14.0)


## Sitting: a card over the traveler's head, the stars carried on it and the place over that, as
## they settle down (and gone as they get up).
func _seated_card(player: Player, cam: Camera2D) -> void:
	var art: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard
	var info: MapInfo = MapInfo.instance
	if art == null or art.costume == null or info == null or info.world == null or art.costume.seated() < 0.5:
		_card_up = false
		return
	# Where the traveler will be once the view settles (see CARD_SLACK), on whole pixels, so the
	# plaques, marks and numbers hold still together while the camera finishes easing.
	var settled: Vector2 = (art.to_global(Vector2(0, -CARD_ABOVE)) - view_origin) * view_k + _settling(cam, player)
	if not _card_up or settled.distance_to(_card_at) > CARD_SLACK:
		_card_at = settled.round()
	_card_up = true
	var above: Vector2 = _card_at
	var count: String = str(player.coins.coins)
	var labels: Array[Label] = [world_label, depth_label]
	var count_w: float = _text_width(coin_label, count)
	var stars_w: float = PAD + 10.0 + count_w + PAD
	var place_w: float = PAD + _place_w(info.coord, PLACE_R, labels) + PAD
	var stars_x: float = roundf(clampf(above.x - stars_w * 0.5, 2.0, 318.0 - stars_w))
	var place_x: float = roundf(clampf(above.x - place_w * 0.5, 2.0, 318.0 - place_w))
	# Kept on the sheet: near the top of the view, the card hangs lower rather than off the edge.
	var stars_y: float = maxf(above.y - CARD_H * 0.5, 2.0 + CARD_H * 1.5 + GAP)
	var place_y: float = stars_y - CARD_H - GAP
	_paper(RisoShapes.rrect(place_x, place_y - CARD_H * 0.5, place_w, CARD_H, RADIUS), RisoPrint.BLUE, 0.12)
	_place_row(info.coord, Vector2(place_x + PAD, place_y), PLACE_R, labels)
	_paper(RisoShapes.rrect(stars_x, stars_y - CARD_H * 0.5, stars_w, CARD_H, RADIUS), RisoPrint.ACCENT, 0.15)
	ink.ink(RisoPrint.ACCENT, 1.0, [Transform2D(sin(t * 1.7) * 0.45, Vector2(stars_x + PAD + 4.0, stars_y)) * RisoShapes.sparkle(Vector2.ZERO, 3.8)], false)
	_place(coin_label, count, stars_x + PAD + 10.0, stars_y)


## How far (UI units) the view has still to move what is on it: from where the camera is to where
## it is heading (CameraControl's target, kept inside the camera's limits).
func _settling(cam: Camera2D, player: Player) -> Vector2:
	var control: CameraControl = player.get_node_or_null("CameraControl") as CameraControl
	if control == null:
		return Vector2.ZERO
	var goal: Vector2 = control.target_location
	var lo: Vector2 = Vector2(cam.limit_left, cam.limit_top) + _view_half
	var hi: Vector2 = Vector2(cam.limit_right, cam.limit_bottom) - _view_half
	goal.x = clampf(goal.x, lo.x, hi.x) if lo.x <= hi.x else (lo.x + hi.x) * 0.5
	goal.y = clampf(goal.y, lo.y, hi.y) if lo.y <= hi.y else (lo.y + hi.y) * 0.5
	return (cam.get_screen_center_position() - goal) * view_k


## While there is a ghost: a pointer at the edge of the view toward it, unless it is in view, with
## its mark (on pink while unprotected), the stars it holds and, when it is in another place, that
## place. The map marks it too (RisoMap).
func _ghost_pointer(player: Player, placed: Array[Vector2]) -> void:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null or not info.run.has_ghost:
		return
	var elsewhere: bool = info.run.ghost_coord != info.coord
	var dir: Vector2 = _ghost_dir(info, player)
	if not elsewhere:
		var p: Vector2 = (info.run.ghost_pos - view_origin) * view_k
		if VIEW_INNER.grow(-6.0).has_point(p):
			return
		dir = (p - VIEW_INNER.get_center()).normalized()
	if dir == Vector2.ZERO:
		return
	var at: Vector2 = _edge(dir)
	placed.append(at)
	var mark: Vector2 = at - dir * 9.0
	_paper(RisoShapes.circle(mark, 6.2, 18), RisoPrint.PINK if info.run.vulnerable else RisoPrint.BLUE, 0.2 if info.run.vulnerable else 0.12)
	# HUD icons are night ink: the glow plate takes the hat's colour, which can be pink (danger).
	ink.ink(RisoPrint.NIGHT, 1.0, RisoMarks.ghost_shape(Transform2D(0.0, Vector2(0.24, 0.24), 0.0, mark + Vector2(0, 4.6))), false)
	ink.ink(RisoPrint.NIGHT, 1.0, [_arrow(at, dir)], false)
	# Its stars, and its place when elsewhere, on a small plaque on the inner side of the mark, held
	# still on whole pixels while the arrow bobs.
	var rest: Vector2 = (_edge(dir, true) - dir * 9.0).round()
	var inward: float = 1.0 if rest.y < VIEW_INNER.get_center().y else -1.0
	var stars: String = str(info.run.ghost_stars)
	var labels: Array[Label] = [ghost_world, ghost_depth]
	var stars_w: float = 8.0 + _text_width(ghost_label, stars)
	var where_w: float = PLACE_R * RisoMarks.PLACE_SPACE * 2.0 + _place_w(info.run.ghost_coord, PLACE_R, labels) if elsewhere else 0.0
	var w: float = PAD + stars_w + where_w + PAD
	var x: float = roundf(clampf(rest.x - w * 0.5, 2.0, 318.0 - w))
	var y: float = rest.y + inward * (6.0 + GAP + CARD_H * 0.5)
	_paper(RisoShapes.rrect(x, y - CARD_H * 0.5, w, CARD_H, RADIUS), RisoPrint.BLUE, 0.12)
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.sparkle(Vector2(x + PAD + 3.0, y), 3.2)], false)
	_place(ghost_label, stars, x + PAD + 8.0, y)
	if elsewhere:
		_place_row(info.run.ghost_coord, Vector2(x + PAD + stars_w + PLACE_R * RisoMarks.PLACE_SPACE * 2.0, y), PLACE_R, labels)


## Awareness: while sensing, a pointer at the edge of the view for each sensed thing that is off
## screen, with its mark beside the arrow. Never stacked: the first pointer at a spot wins.
func _awareness(player: Player, placed: Array[Vector2]) -> void:
	var aware: Awareness = player.get_node_or_null("Awareness") as Awareness
	if aware == null or not aware.active():
		return
	var fade: float = clampf(aware.sensing, 0.0, 1.0)
	var arrows: Array[PackedVector2Array] = []
	for target: Dictionary in aware.targets():
		var p: Vector2 = ((target["at"] as Vector2) - view_origin) * view_k
		if VIEW_INNER.grow(-6.0).has_point(p):
			continue
		var dir: Vector2 = (p - VIEW_INNER.get_center()).normalized()
		var at: Vector2 = _edge(dir)
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(at) < 13.0):
			continue
		placed.append(at)
		arrows.append(_arrow(at, dir))
		var mark: Vector2 = at - dir * 8.0
		_paper(RisoShapes.circle(mark, 5.6, 16), RisoPrint.BLUE, 0.12 * fade)
		match target["kind"]:
			&"exit":
				var which: int = (target["node"] as LevelExit).exit
				ink.ink(RisoPrint.PINK if which == MapInfo.Exit.DEEPER else RisoPrint.NIGHT, fade, [RisoShapes.arch(mark.x - 2.6, mark.y - 3.2, 5.2, 6.0, 6)], false)
			&"inkwell":
				ink.ink(RisoPrint.BLUE, fade, [RisoShapes.rrect(mark.x - 2.8, mark.y - 2.2, 5.6, 5.0, 1.8)], false)
				ink.ink(RisoPrint.ACCENT, fade, [RisoShapes.rrect(mark.x - 2.0, mark.y - 3.4, 4.0, 1.4, 0.6)], false)
			&"shrine":
				ink.ink(RisoPrint.ACCENT, fade, [RisoShapes.arch(mark.x - 2.6, mark.y - 3.2, 5.2, 6.0, 6)], false)
			&"key":
				var color: int = int((target["node"] as Node).get_meta(&"key_color", 0))
				RisoPrint.ink_key(ink, color, fade, RisoMarks.key_shape(mark, 0.2, color))
	ink.ink(RisoPrint.NIGHT, fade, arrows, false)


## Toward the ghost: by level (deeper is down, the next seed is right) when it is elsewhere,
## otherwise straight at it. Zero when the player is standing on it.
func _ghost_dir(info: MapInfo, player: Player) -> Vector2:
	if info.run.ghost_coord != info.coord:
		return Vector2(signf(info.run.ghost_coord.x - info.coord.x), signf(info.run.ghost_coord.y - info.coord.y)).normalized()
	var v: Vector2 = info.run.ghost_pos - player.global_position
	return v.normalized() if v.length() > 48.0 else Vector2.ZERO
