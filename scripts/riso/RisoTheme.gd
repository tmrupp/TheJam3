class_name RisoTheme
## Restyles the shared menu theme (res://themes/main_menu_theme.tres) in the riso palette while
## the print is on, and restores it exactly when the print is switched off. Every menu uses that
## theme, so this is the one place the UI changes. Flat ink colours, no borders: buttons are
## blue ink that turns to the accent on hover or focus, fields are paper, panels are night.

const MENU_THEME: String = "res://themes/main_menu_theme.tres"

static var _saved: Dictionary = {}
static var _serif: SystemFont


static func serif() -> SystemFont:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "serif"])
		_serif.multichannel_signed_distance_field = true
		_serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _serif


static func _box(color: Color, radius: int, pad_x: float, pad_y: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(0)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	box.anti_aliasing = true
	return box


static func apply(realm: StringName) -> void:
	var theme: Theme = load(MENU_THEME) as Theme
	if theme == null:
		return
	if _saved.is_empty():
		_saved = {"font": theme.default_font, "size": theme.default_font_size}
	var info: Dictionary = RisoPrint.REALMS[realm]
	var inks: Array = info["inks"]
	var paper: Color = info["paper"]
	var night: Color = inks[RisoPrint.NIGHT]
	var blue: Color = inks[RisoPrint.BLUE]
	var accent: Color = inks[RisoPrint.ACCENT]
	theme.default_font = serif()
	theme.default_font_size = 11
	theme.set_stylebox("normal", "Button", _box(blue, 6, 7, 2))
	theme.set_stylebox("hover", "Button", _box(accent, 6, 7, 2))
	theme.set_stylebox("pressed", "Button", _box(night, 6, 7, 2))
	# Focus draws over the normal box, so it must be opaque: focused looks exactly like hovered.
	theme.set_stylebox("focus", "Button", _box(accent, 6, 7, 2))
	theme.set_stylebox("disabled", "Button", _box(Color(blue, 0.4), 6, 7, 2))
	theme.set_color("font_color", "Button", paper)
	theme.set_color("font_hover_color", "Button", night)
	theme.set_color("font_focus_color", "Button", night)
	theme.set_color("font_pressed_color", "Button", paper)
	theme.set_color("font_hover_pressed_color", "Button", night)
	theme.set_stylebox("normal", "LineEdit", _box(paper, 6, 6, 2))
	theme.set_stylebox("focus", "LineEdit", _box(Color(accent, 0.5), 6, 6, 2))
	theme.set_color("font_color", "LineEdit", night)
	theme.set_color("caret_color", "LineEdit", night)
	theme.set_color("selection_color", "LineEdit", Color(accent, 0.6))
	theme.set_color("font_color", "Label", paper)
	theme.set_stylebox("panel", "Panel", _box(Color(night, 0.92), 8, 6, 4))
	theme.set_stylebox("panel", "PanelContainer", _box(Color(night, 0.92), 8, 6, 4))


static func restore() -> void:
	var theme: Theme = load(MENU_THEME) as Theme
	if theme == null or _saved.is_empty():
		return
	theme.default_font = _saved["font"]
	theme.default_font_size = int(_saved["size"])
	for pair: Array in [["normal", "Button"], ["hover", "Button"], ["pressed", "Button"], ["focus", "Button"], ["disabled", "Button"],
			["normal", "LineEdit"], ["focus", "LineEdit"], ["panel", "Panel"], ["panel", "PanelContainer"]]:
		theme.clear_stylebox(pair[0], pair[1])
	for pair: Array in [["font_color", "Button"], ["font_hover_color", "Button"], ["font_focus_color", "Button"], ["font_pressed_color", "Button"],
			["font_hover_pressed_color", "Button"], ["font_color", "LineEdit"], ["caret_color", "LineEdit"], ["selection_color", "LineEdit"], ["font_color", "Label"]]:
		theme.clear_color(pair[0], pair[1])
