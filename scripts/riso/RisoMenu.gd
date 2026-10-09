extends Node2D
## The menus (menu.gd), printed. While the print is on, every visible button, field and label of
## the menu is printed in the UI's riso (RisoPrint.ui_canvas), as finely as the HUD, and the Godot
## controls only lay it out and take focus and input (they draw nothing themselves). Like the
## HUD's plaques, the text is night ink on paper: a button is a paper plaque tinted and rimmed in
## blue, solid accent while focused or hovered, solid blue while pressed; a field is paper with a
## caret while focused, its placeholder in faint night; labels print as paper over the scene.

## Labels are laid at this size and scaled down, so the text stays sharp on the plates.
const TEXT_PX: int = 48
## Every plate a plaque clears to paper.
const ALL: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE]

var canvas: Node2D
var ink: InkCanvas
var labels: Array[Label] = []
var labels_used: int = 0
var font: Font
var t: float = 0.0
## The controls drawn invisibly while printed, to show again when the print is off.
var _muted: Dictionary = {}


func _ready() -> void:
	z_index = 80
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = RisoTheme.serif()
	canvas = RisoPrint.ui_canvas(self)
	canvas.z_index = 80
	canvas.z_as_relative = false
	ink = InkCanvas.new()
	ink.ui = true
	canvas.add_child(ink)


func _process(delta: float) -> void:
	t += delta
	var menu: CanvasLayer = Stage.menu()
	var printing: bool = RisoPrint.is_on()
	var cam: Camera2D = get_viewport().get_camera_2d()
	var showing: bool = printing and menu != null and menu.visible and cam != null
	canvas.visible = showing
	if menu == null:
		return
	var controls: Array[Control] = []
	_collect(menu, controls)
	# The controls draw nothing while printed; they come back when the print is switched off.
	for c: Control in controls:
		if printing and not _muted.has(c):
			_muted[c] = true
			c.self_modulate.a = 0.0
		elif not printing and _muted.has(c):
			c.self_modulate.a = 1.0
	if not printing:
		_muted.clear()
	if not showing:
		return
	var base: Vector2 = Vector2(get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	global_position = cam.get_screen_center_position() - base / cam.zoom * 0.5
	scale = Vector2.ONE / cam.zoom
	canvas.global_position = global_position
	canvas.scale = scale
	labels_used = 0
	ink.begin()
	for c: Control in controls:
		if not c.is_visible_in_tree():
			continue
		if c is Button:
			_button(c as Button)
		elif c is LineEdit:
			_field(c as LineEdit)
		elif c is Label:
			_label(c as Label)
	ink.finish()
	for i: int in range(labels_used, labels.size()):
		labels[i].visible = false


## Every button, field and label under `node` (not the pixel-art backdrop).
func _collect(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Button or child is LineEdit or child is Label:
			out.append(child as Control)
		if not (child is Button or child is LineEdit):
			_collect(child, out)


func _plaque(r: Rect2) -> PackedVector2Array:
	return RisoShapes.rrect(r.position.x, r.position.y, r.size.x, r.size.y, minf(6.0, r.size.y * 0.35))


func _button(b: Button) -> void:
	var r: Rect2 = b.get_global_rect()
	var box: PackedVector2Array = _plaque(r)
	var lit: bool = b.has_focus() or b.is_hovered()
	var pressed: bool = b.get_draw_mode() == BaseButton.DRAW_PRESSED or b.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED
	ink.knock(ALL, [box])
	if pressed:
		ink.ink(RisoPrint.BLUE, 1.0, [box], false)
	elif lit:
		ink.ink(RisoPrint.ACCENT, 1.0, [box], false)
	else:
		# Paper tinted blue inside a blue rim.
		var rim: float = 1.2
		ink.ink(RisoPrint.BLUE, 1.0, [box], false)
		ink.knock(ALL, [RisoShapes.rrect(r.position.x + rim, r.position.y + rim, r.size.x - rim * 2.0, r.size.y - rim * 2.0, maxf(1.0, minf(6.0, r.size.y * 0.35) - rim))])
		ink.ink(RisoPrint.BLUE, 0.22, [box], false)
	var size: float = float(b.get_theme_font_size(&"font_size"))
	_text(b.text, r, size, HORIZONTAL_ALIGNMENT_CENTER, RisoPrint.plate_mask(RisoPrint.NIGHT), 0.45 if b.disabled else 1.0)


func _field(e: LineEdit) -> void:
	var r: Rect2 = e.get_global_rect()
	var box: PackedVector2Array = _plaque(r)
	ink.knock(ALL, [box])
	ink.ink(RisoPrint.BLUE, 0.1, [box], false)
	var size: float = float(e.get_theme_font_size(&"font_size"))
	var pad: float = 5.0
	var inner: Rect2 = Rect2(r.position + Vector2(pad, 0), r.size - Vector2(pad * 2.0, 0))
	if e.text.is_empty():
		_text(e.placeholder_text, inner, size, HORIZONTAL_ALIGNMENT_LEFT, RisoPrint.plate_mask(RisoPrint.NIGHT), 0.35)
	else:
		_text(e.text, inner, size, HORIZONTAL_ALIGNMENT_LEFT, RisoPrint.plate_mask(RisoPrint.NIGHT), 1.0)
	if e.has_focus() and fmod(t, 1.0) < 0.6:
		var x: float = inner.position.x + (font.get_string_size(e.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x if not e.text.is_empty() else 0.0) + 1.0
		ink.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.rrect(x, r.position.y + r.size.y * 0.22, 1.0, r.size.y * 0.56, 0.5)], false)


func _label(l: Label) -> void:
	var size: float = float(l.get_theme_font_size(&"font_size"))
	_text(l.text, l.get_global_rect(), size, l.horizontal_alignment, RisoPrint.paper_mask(), 1.0)


## `text` at `size` (base pixels) in `r`, aligned across and centred down, on the plates in
## `mask`, at `cover`.
func _text(text: String, r: Rect2, size: float, align: HorizontalAlignment, mask: int, cover: float) -> void:
	if text.is_empty():
		return
	if labels_used >= labels.size():
		var made: Label = Label.new()
		made.add_theme_font_override("font", font)
		made.add_theme_font_size_override("font_size", TEXT_PX)
		canvas.add_child(made)
		RisoPrint.share_layers(made)
		labels.append(made)
	var label: Label = labels[labels_used]
	labels_used += 1
	var k: float = size / float(TEXT_PX)
	label.scale = Vector2(k, k)
	label.text = text
	label.visibility_layer = mask
	label.add_theme_color_override("font_color", Color(1, 1, 1, cover))
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x * k
	var h: float = font.get_height(TEXT_PX) * k
	var x: float = r.position.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x = r.position.x + (r.size.x - w) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = r.end.x - w
	label.position = Vector2(x, r.position.y + (r.size.y - h) * 0.5)
	label.visible = true
