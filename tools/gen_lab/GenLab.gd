extends Control
## The generation lab: a workbench for trying other ways to generate levels and seeing many at once.
## On the left, the WFC sample a band's terrain is collapsed from, painted pixel by pixel (open
## air, rock, thorns), resized, reverted or saved; and what else shapes a level: the pattern size
## and symmetry of the collapse, the level's size, the band row it is dressed as (its archetype's
## passes and tuning, Bands), whether it is dressed at all, and the band tuning knobs
## (Archetype.star_share and the rest). On the right, a grid of levels from consecutive world seeds,
## laid out again a moment after anything changes, on a worker thread so painting stays smooth,
## each with a line of what it holds; a click shows one large, and from there it can be looked at in
## the game itself (the whole level, as it prints) or played, the wizard at its way in. Backspace
## (or F10) comes back to the lab as it was left.
##
## It collapses with the game's own generator (the WaveFunctionCollapse node, set as the game scene
## sets it) and dresses with LevelGen, so what it shows is what the game would make with the same
## sample and settings. Nothing here changes the game until a sample is saved.
## godot --path . res://tools/gen_lab/gen_lab.tscn   (or open the scene in the editor and press F6)

## The sample's colours: open air, rock, thorns (LevelGen.color_to_type).
const INKS: Array[Color] = [Color.WHITE, Color.BLACK, Color.RED]
const INK_NAMES: Array[String] = ["Open", "Rock", "Thorns"]
## How a level is drawn, one pixel a cell: the terrain, then what stands in it.
const SHOW_OPEN: Color = Color(0.93, 0.91, 0.86)
const SHOW_ROCK: Color = Color(0.16, 0.2, 0.18)
const SHOW: Dictionary = {
	LevelGen.Type.SPIKES: Color(0.9, 0.15, 0.3),
	LevelGen.Type.PLATFORM: Color(0.6, 0.45, 0.25),
	LevelGen.Type.MOVING_PLATFORM: Color(0.85, 0.6, 0.2),
	LevelGen.Type.CRACKED: Color(0.4, 0.4, 0.4),
	LevelGen.Type.EXIT: Color(0.1, 0.8, 0.3),
	LevelGen.Type.DOOR: Color(0.3, 0.4, 1.0),
	LevelGen.Type.SWITCH_GATE: Color(0.3, 0.4, 1.0),
	LevelGen.Type.KEY: Color(1.0, 0.85, 0.0),
	LevelGen.Type.CHECKPOINT: Color(1.0, 0.55, 0.0),
	LevelGen.Type.PORTAL: Color(0.7, 0.3, 0.9),
	LevelGen.Type.MOON: Color(0.5, 0.8, 1.0),
	LevelGen.Type.SHRINE: Color(0.0, 0.8, 0.8),
	LevelGen.Type.BOSS: Color(1.0, 0.0, 1.0),
}
## Foes, drawn alike.
const FOES: Array[LevelGen.Type] = [LevelGen.Type.ENEMY, LevelGen.Type.SHOOTER, LevelGen.Type.HOPPER, LevelGen.Type.BIRD,
	LevelGen.Type.WRAITH, LevelGen.Type.SKELETON, LevelGen.Type.BUG]
const SHOW_FOE: Color = Color(0.85, 0.0, 0.0)
## Stars are many (a fifth of the open cells): a faint tint, so the terrain still reads.
const SHOW_STAR: Color = Color(0.96, 0.9, 0.7)
## The key under the grid: each colour a level is drawn in (SHOW_ROCK and the rest), and its name.
const KEY: Array = [
	[SHOW_ROCK, "rock"], [SHOW_OPEN, "open air"], [Color(0.9, 0.15, 0.3), "thorns"],
	[Color(0.6, 0.45, 0.25), "ledge"], [Color(0.85, 0.6, 0.2), "lift"], [Color(0.4, 0.4, 0.4), "cracked rock"],
	[Color(0.1, 0.8, 0.3), "exit"], [Color(0.3, 0.4, 1.0), "door, gate"], [Color(1.0, 0.85, 0.0), "key"],
	[Color(1.0, 0.55, 0.0), "lantern"], [Color(0.7, 0.3, 0.9), "portal"], [Color(0.5, 0.8, 1.0), "moon"],
	[Color(0.0, 0.8, 0.8), "shrine"], [SHOW_FOE, "foe"], [SHOW_STAR, "star"], [Color(1.0, 0.0, 1.0), "boss"],
]
## What the pattern size does, shown over its box.
const PATTERN_TIP: String = "The size (pixels square) of the pieces the sample is cut into.\nThe collapse only puts pieces side by side the way they overlap somewhere in the sample:\nsmall pieces copy the sample loosely (more variety, odder shapes), big ones closely (truer to it, and fails to settle more often).\nThe game uses 3."
## The eight versions of each piece the collapse can use (NextWorldDef.symmetry), in its order: bit k
## of the mask is version k. Each is [its name, a short name for its box, and the extension's own
## steps that make it from the piece as drawn]:
## "f" flips it (upside down, as the game reads it) and "r" turns it a quarter, as
## gdextension/src/overlapping_wfc.hpp makes them, so the pictures show what each really is.
const VERSIONS: Array = [
	["as drawn", "as drawn", ""], ["upside down", "upside down", "f"], ["a quarter turn", "quarter", "r"],
	["a quarter turn, upside down", "quarter, flip", "rf"], ["a half turn", "half turn", "rr"],
	["a half turn, upside down: the left-right mirror", "mirror", "rrf"], ["three quarters", "3 quarters", "rrr"],
	["three quarters, upside down", "3 quarters, flip", "rrrf"],
]
## The mask that keeps up up and also mirrors left to right (versions 0 and 5).
const UPRIGHT_MIRROR: int = 0b100001
## What the symmetry does, shown over its box.
const SYMMETRY_TIP: String = "Which turned and flipped versions of each piece the collapse may use (each picture shows one, done to a lopsided glyph).\nA band uses the first N of them (Archetype.symmetry): the garden 5 (its caves have no up), the cemetery 1 (up stays up).\nAny set can be picked here; a band can use one too, through its \"symmetry_mask\" (Bands.LAYOUTS tune; bit k for version k).\nUpright + mirror (versions 1 and 6 here) keeps gravity's sense and doubles the variety."
## The "How it works" text under the key.
const HOW: String = "The game makes a level's terrain with wave function collapse (WFC): it cuts the band's sample into small pieces (pattern size) and fills the level with them so that every patch of the level looks like some patch of the sample. White is open air, black rock, red thorns. Symmetry lets it use the pieces turned and flipped too.\n\nThen the band dresses it (LevelGen): it joins the caves, places the way in and the way on, keys and doors, lanterns, portals, stars and foes, by the band's own passes and the tuning above. The same world and row is always the same level.\n\nPaint the sample, change a setting, and the levels are laid out again a moment later. Click one to see it large, then Look in game (the whole level as the game prints it; P plays from there) or Play from its way in. Backspace comes back here."

## The band tuning knobs offered (Archetype vars), each [name, step, what it does].
const KNOBS: Array = [
	["star_share", 0.01, "The share of a level's open cells given a star (Archetype.star_share)."],
	["wisp_share", 0.01, "The share of open cells given a wisp, times the difficulty's foes (Archetype.wisp_share)."],
	["watcher_share", 0.01, "The share of open cells given a watcher, times the difficulty's foes (Archetype.watcher_share)."],
	["hoppers_per_k", 0.1, "Hoppers per 1000 cells from depth 1, times the difficulty's foes (Archetype.hoppers_per_k)."],
]
## How long after the last change the levels are laid out again (seconds).
const SETTLE: float = 0.35
## Tries a collapse gets (each on a seed of its own) before a level counts as never settling.
const TRIES: int = 8
## The game, and the save a run started from the lab keeps (apart from the player's own).
const MAIN: String = "res://prefabs/scenes/main.tscn"
const LAB_SAVE: String = "user://gen_lab.save"
## Back to the lab from the game (Backspace is the game's own Back too: the lab takes it first).
const BACK_KEYS: Array[Key] = [KEY_BACKSPACE, KEY_F10]
## Looking at a level in the game: how much a wheel step zooms.
const ZOOM_STEP: float = 1.15
## How big a level is drawn in the grid, at most (px); the sample is painted at SampleCanvas.PX.
const THUMB: Vector2 = Vector2(300, 240)
## The window it opens in, if it starts smaller.
const WINDOW: Vector2i = Vector2i(1600, 900)

var sample_path: String = ""
var sample: Image
var _saved: Image
var ink: int = 1
var _paths: Array[String] = []

var _sample_pick: OptionButton
var _canvas: SampleCanvas
var _sample_note: Label
var _width: SpinBox
var _height: SpinBox
var _pattern: SpinBox
var _versions: Array[CheckBox] = []
var _row: SpinBox
var _first: SpinBox
var _count: SpinBox
var _size_auto: CheckBox
var _size_w: SpinBox
var _size_h: SpinBox
var _dress: CheckBox
var _knobs: Dictionary = {}
var _grid: GridContainer
var _status: Label
var _big: Panel
var _big_view: TextureRect
var _big_note: Label
## The level shown large, and the game it is being looked at or played in (null in the lab).
var _chosen: Dictionary = {}
var _game: Node
var _hint: Label
var _looking: bool = false
var _was_save: String = ""
var _was_by_sight: bool = true
var _limits: Array[int] = []
## The camera's zoom as the game set it (its own, times the print's zoom, RisoPrint.zoom_factor),
## kept while looking, to play at again.
var _zoom: Vector2 = Vector2.ONE
var _save_as: LineEdit

## Counts each lay-out asked for, so a worker knows when its work is stale.
var _wanted: int = 0
var _due: float = -1.0
## A lay-out asked for while the worker was busy, started when it is done.
var _pending: bool = false
var _thread: Thread
var _cells: Array[Dictionary] = []


func _ready() -> void:
	# The game draws at 320 x 180 and scales it up; a tool wants the window's own pixels.
	var win: Window = get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if win.mode == Window.MODE_WINDOWED and win.size.x < WINDOW.x:
		win.size = WINDOW
	_build_ui()
	_list_samples()
	_on_row_changed(_row.value)
	_ask()


func _process(delta: float) -> void:
	if _due >= 0.0:
		_due -= delta
		if _due < 0.0:
			_start()


func _exit_tree() -> void:
	_wanted += 1
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


# ------------------------------------------------------------------ the panel

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var split: HBoxContainer = HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 12)
	add_child(split)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(430, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(left_scroll)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)

	_title(left, "Sample (WFC)")
	_sample_pick = OptionButton.new()
	_sample_pick.item_selected.connect(func(i: int) -> void: _load_sample(_paths[i]))
	left.add_child(_sample_pick)
	var inks: HBoxContainer = HBoxContainer.new()
	left.add_child(inks)
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in range(INKS.size()):
		var b: Button = Button.new()
		b.text = INK_NAMES[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == ink
		var which: int = i
		b.pressed.connect(func() -> void: ink = which)
		inks.add_child(b)
	var hint: Label = Label.new()
	hint.text = "left paints, right paints open air"
	hint.modulate = Color(1, 1, 1, 0.6)
	inks.add_child(hint)
	_canvas = SampleCanvas.new()
	_canvas.lab = self
	left.add_child(_canvas)
	_sample_note = Label.new()
	left.add_child(_sample_note)
	var resize: HBoxContainer = HBoxContainer.new()
	left.add_child(resize)
	_width = _spin(resize, "w", 4, 128, 1, 32, "The sample's width in pixels, for Resize.")
	_height = _spin(resize, "h", 4, 128, 1, 32, "The sample's height in pixels, for Resize.")
	_button(resize, "Resize", func() -> void: _resize(int(_width.value), int(_height.value)),
			"Cut the sample, or grow it with open air, to w x h (from its top left).")
	var files: HBoxContainer = HBoxContainer.new()
	left.add_child(files)
	_button(files, "Revert", func() -> void: _load_sample(sample_path), "Back to the sample as it was last loaded or saved.")
	_button(files, "Save", func() -> void: _save(sample_path), "Write the sample over its file in wfc_images. The game reads it once the project is imported again.\nA sample drawn by a tests/make_*_sample.gd script is remade by it: edit the script for good.")
	_save_as = LineEdit.new()
	_save_as.placeholder_text = "new_sample"
	_save_as.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files.add_child(_save_as)
	_button(files, "Save as", func() -> void:
		if _save_as.text.strip_edges() != "":
			_save("res://wfc_images/%s.png" % _save_as.text.strip_edges().trim_suffix(".png")),
			"Write the sample to a new file in wfc_images, named in the box.")

	_title(left, "Collapse")
	var wfc_row: HBoxContainer = HBoxContainer.new()
	left.add_child(wfc_row)
	_pattern = _spin(wfc_row, "pattern", 2, 5, 1, 3, PATTERN_TIP)
	var sym_title: Label = Label.new()
	sym_title.text = "symmetry: the versions of each piece used"
	sym_title.tooltip_text = SYMMETRY_TIP
	sym_title.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(sym_title)
	var presets: HBoxContainer = HBoxContainer.new()
	left.add_child(presets)
	_button(presets, "band's", func() -> void: _use_mask(_band_mask()), "The band's own: the first N versions (Archetype.symmetry), or its mask.")
	_button(presets, "upright", func() -> void: _use_mask(1), "Only as drawn: up stays up, left stays left.")
	_button(presets, "upright + mirror", func() -> void: _use_mask(UPRIGHT_MIRROR), "As drawn and mirrored left to right: up stays up.")
	_button(presets, "all", func() -> void: _use_mask(255), "All eight versions.")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	left.add_child(grid)
	for k: int in range(VERSIONS.size()):
		var item: VBoxContainer = VBoxContainer.new()
		item.tooltip_text = "%d: %s\n%s" % [k + 1, VERSIONS[k][0], SYMMETRY_TIP]
		grid.add_child(item)
		var glyph: TextureRect = TextureRect.new()
		glyph.texture = ImageTexture.create_from_image(_version_glyph(String(VERSIONS[k][2])))
		glyph.custom_minimum_size = Vector2(40, 40)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.mouse_filter = Control.MOUSE_FILTER_PASS
		item.add_child(glyph)
		var box: CheckBox = CheckBox.new()
		box.text = "%d %s" % [k + 1, VERSIONS[k][1]]
		box.tooltip_text = item.tooltip_text
		box.add_theme_font_size_override("font_size", 12)
		box.toggled.connect(func(_on: bool) -> void: _ask())
		item.add_child(box)
		_versions.append(box)
	var size_row: HBoxContainer = HBoxContainer.new()
	left.add_child(size_row)
	_size_auto = CheckBox.new()
	_size_auto.text = "band's size"
	_size_auto.tooltip_text = "Lay each level out as big as the game would at its row (Rules.level_size, times the archetype's scale).\nUntick to set w x h yourself."
	_size_auto.button_pressed = true
	_size_auto.toggled.connect(func(_on: bool) -> void: _ask())
	size_row.add_child(_size_auto)
	_size_w = _spin(size_row, "w", 8, 160, 1, 36, "Cells across, when the band's size is unticked.")
	_size_h = _spin(size_row, "h", 8, 160, 1, 30, "Cells down, when the band's size is unticked.")

	_title(left, "Levels")
	var seeds: HBoxContainer = HBoxContainer.new()
	left.add_child(seeds)
	_row = _spin(seeds, "row", -40, 40, 1, 1, "The row the levels are laid out on: 0 the start, down positive, up negative.\nIt picks the band (its archetype's dressing, size and tuning), and loads its sample while yours is unedited.")
	_row.value_changed.connect(_on_row_changed)
	_first = _spin(seeds, "first world", 0, 99999, 1, 1, "The world seed of the first level; the rest follow it (first, first + 1, ...).\nThe same world and row is the same level, as in the game.")
	_count = _spin(seeds, "how many", 1, 48, 1, 12, "How many levels to lay out.")
	_dress = CheckBox.new()
	_dress.text = "dress as the band does (exits, keys, foes, stars...)"
	_dress.tooltip_text = "Lay each level out fully, as the game does (LevelGen), with the tuning below.\nUntick to see only the terrain the collapse made. The cemetery's crypts are not made here: it shows undressed."
	_dress.button_pressed = true
	_dress.toggled.connect(func(_on: bool) -> void: _ask())
	left.add_child(_dress)

	_title(left, "Band tuning (Archetype)")
	for knob: Array in KNOBS:
		var line: HBoxContainer = HBoxContainer.new()
		left.add_child(line)
		var spin: SpinBox = _spin(line, String(knob[0]), 0.0, 10.0, float(knob[1]), 0.0, String(knob[2]))
		spin.custom_minimum_size.x = 120
		_knobs[knob[0]] = spin
	_button(left, "Copy settings (for Bands.LAYOUTS)", _copy_settings,
			"Put the sample, the collapse's settings and the tuning on the clipboard, to carry into a band's line in Bands.LAYOUTS.")

	_title(left, "Key")
	var key: GridContainer = GridContainer.new()
	key.columns = 3
	key.add_theme_constant_override("h_separation", 14)
	left.add_child(key)
	for entry: Array in KEY:
		var item: HBoxContainer = HBoxContainer.new()
		key.add_child(item)
		# A thin light edge, so the dark ones show on the panel's dark ground.
		var swatch: Panel = Panel.new()
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = entry[0]
		box.set_border_width_all(1)
		box.border_color = Color(0.7, 0.7, 0.7)
		swatch.add_theme_stylebox_override("panel", box)
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var what: Label = Label.new()
		what.text = entry[1]
		item.add_child(what)

	_title(left, "How it works")
	var how: Label = Label.new()
	how.text = HOW
	how.autowrap_mode = TextServer.AUTOWRAP_WORD
	how.custom_minimum_size.x = 400
	how.modulate = Color(1, 1, 1, 0.75)
	left.add_child(how)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_status = Label.new()
	right.add_child(_status)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	_big = Panel.new()
	_big.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big.visible = false
	add_child(_big)
	var big_box: VBoxContainer = VBoxContainer.new()
	big_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big.add_child(big_box)
	_big_note = Label.new()
	big_box.add_child(_big_note)
	_big_view = TextureRect.new()
	_big_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_big_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_big_view.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_big.visible = false)
	big_box.add_child(_big_view)
	var actions: HBoxContainer = HBoxContainer.new()
	big_box.add_child(actions)
	_button(actions, "Look in game", func() -> void: _enter_game(true))
	_button(actions, "Play", func() -> void: _enter_game(false))
	_button(actions, "Close", func() -> void: _big.visible = false)

	# Over the game: how to get back (a layer of its own, above the game's).
	var over: CanvasLayer = CanvasLayer.new()
	over.layer = 120
	add_child(over)
	_hint = Label.new()
	_hint.position = Vector2(8, 4)
	# Drawn in the game's own small view (320 x 180, scaled up), so small here.
	_hint.add_theme_font_size_override("font_size", 7)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 2)
	_hint.visible = false
	over.add_child(_hint)


func _title(parent: Control, text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	parent.add_child(l)


func _spin(parent: Control, label: String, lo: float, hi: float, step: float, value: float, tip: String = "") -> SpinBox:
	var l: Label = Label.new()
	l.text = label
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(l)
	var s: SpinBox = SpinBox.new()
	s.tooltip_text = tip
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.value_changed.connect(func(_v: float) -> void: _ask())
	parent.add_child(s)
	return s


func _button(parent: Control, text: String, on: Callable, tip: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(on)
	parent.add_child(b)
	return b


# ------------------------------------------------------------------ the sample

func _list_samples() -> void:
	_paths.clear()
	_sample_pick.clear()
	for f: String in DirAccess.get_files_at("res://wfc_images"):
		if f.ends_with(".png"):
			_paths.append("res://wfc_images/" + f)
			_sample_pick.add_item(f)


func _load_sample(path: String) -> void:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		_status.text = "could not read %s" % path
		return
	img.convert(Image.FORMAT_RGBA8)
	sample_path = path
	sample = img
	_saved = img.duplicate() as Image
	_sample_pick.select(_paths.find(path))
	_width.set_value_no_signal(img.get_width())
	_height.set_value_no_signal(img.get_height())
	_canvas.refresh()
	_note_sample()
	_ask()


func _note_sample() -> void:
	var edited: bool = _saved == null or sample.get_data() != _saved.get_data()
	_sample_note.text = "%s, %d x %d%s" % [sample_path.get_file(), sample.get_width(), sample.get_height(), " (edited)" if edited else ""]


## A pixel of the sample painted (by the canvas).
func paint(p: Vector2i, which: int) -> void:
	if p.x < 0 or p.y < 0 or p.x >= sample.get_width() or p.y >= sample.get_height():
		return
	if sample.get_pixelv(p).is_equal_approx(INKS[which]):
		return
	sample.set_pixelv(p, INKS[which])
	_canvas.refresh()
	_note_sample()
	_ask()


## The sample cut or grown to `w` x `h`, new pixels open air.
func _resize(w: int, h: int) -> void:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(INKS[0])
	img.blit_rect(sample, Rect2i(0, 0, mini(w, sample.get_width()), mini(h, sample.get_height())), Vector2i.ZERO)
	sample = img
	_canvas.refresh()
	_note_sample()
	_ask()


func _save(path: String) -> void:
	var err: Error = sample.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		_status.text = "could not save %s (%s)" % [path, error_string(err)]
		return
	_saved = sample.duplicate() as Image
	sample_path = path
	_list_samples()
	_sample_pick.select(_paths.find(path))
	_note_sample()
	_status.text = "saved %s (the game reads it once the project is imported again)" % path


func _on_row_changed(_v: float) -> void:
	# The band's own sample and collapse, while the sample is not edited.
	var def: NextWorldDef = Rules.def_for(Vector2i(int(_first.value), int(_row.value)))
	if sample == null or sample.get_data() == _saved.get_data():
		if def.region != sample_path:
			_load_sample(def.region)
		_use_mask(_band_mask(), false)
	for knob: Array in KNOBS:
		(_knobs[knob[0]] as SpinBox).set_value_no_signal(float(def.arch.get(String(knob[0]))))
	if _size_auto.button_pressed:
		_size_w.set_value_no_signal(def.size.x)
		_size_h.set_value_no_signal(def.size.y)
	_ask()


## The versions ticked, as a mask (bit k for version k; at least the first, as drawn).
func _mask() -> int:
	var mask: int = 0
	for k: int in range(_versions.size()):
		if _versions[k].button_pressed:
			mask |= 1 << k
	return mask if mask != 0 else 1


## The band's own versions at the row shown: its mask, else its first `symmetry` of them.
func _band_mask() -> int:
	var def: NextWorldDef = Rules.def_for(Vector2i(int(_first.value), int(_row.value)))
	return def.symmetry_mask if def.symmetry_mask != 0 else (1 << def.symmetry) - 1


## Tick the versions of `mask`, and lay the levels out again (unless `relay` is false).
func _use_mask(mask: int, relay: bool = true) -> void:
	for k: int in range(_versions.size()):
		_versions[k].set_pressed_no_signal((mask >> k) & 1 != 0)
	if relay:
		_ask()


## A lopsided glyph (an F, so every turn and flip shows), put through `steps` as the extension does
## a piece: it holds the sample transposed (gdextension/src/wave_function_collapse.cpp), "f" reverses
## each of its rows (upside down in the picture) and "r" turns it a quarter.
static func _version_glyph(steps: String) -> Image:
	var rows: Array[String] = ["#####", "#....", "####.", "#....", "#...."]
	var n: int = rows.size()
	# a[i][j] is the glyph's pixel at x i, y j, as the extension reads an image.
	var a: Array = []
	for i: int in range(n):
		var column: Array[bool] = []
		for j: int in range(n):
			column.append(rows[j][i] == "#")
		a.append(column)
	for step: String in steps:
		var b: Array = []
		for i: int in range(n):
			var column: Array[bool] = []
			for j: int in range(n):
				# Array2D::reflected: get(y, w-1-x); Array2D::rotated: get(x, w-1-y).
				column.append(a[i][n - 1 - j] if step == "f" else a[j][n - 1 - i])
			b.append(column)
		a = b
	var img: Image = Image.create(n + 2, n + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.27, 0.28))
	for i: int in range(n):
		for j: int in range(n):
			if a[i][j]:
				img.set_pixel(i + 1, j + 1, Color(0.95, 0.93, 0.85))
	return img


func _copy_settings() -> void:
	var tune: Dictionary = {}
	for knob: Array in KNOBS:
		tune[knob[0]] = snappedf((_knobs[knob[0]] as SpinBox).value, float(knob[1]))
	tune["symmetry_mask"] = _mask()
	var text: String = "sample %s, pattern %d, \"tune\": %s" % [sample_path, int(_pattern.value), JSON.stringify(tune)]
	DisplayServer.clipboard_set(text)
	_status.text = "copied: " + text


# ------------------------------------------------------------------ laying levels out

## Lay the levels out again a moment from now (changes come in bursts while painting).
func _ask() -> void:
	_due = SETTLE


func _start() -> void:
	if sample == null:
		return
	# Whatever the worker is doing is stale now: it stops, and this starts once it has.
	_wanted += 1
	if _thread != null and _thread.is_started():
		_pending = true
		return
	_launch()


func _launch() -> void:
	var job: Dictionary = {
		"id": _wanted,
		"sample": sample.duplicate(),
		"pattern": int(_pattern.value),
		"symmetry_mask": _mask(),
		"row": int(_row.value),
		"first": int(_first.value),
		"count": int(_count.value),
		"size": Vector2i(int(_size_w.value), int(_size_h.value)) if not _size_auto.button_pressed else Vector2i.ZERO,
		"dress": _dress.button_pressed,
		"tune": {},
	}
	for knob: Array in KNOBS:
		(job["tune"] as Dictionary)[knob[0]] = (_knobs[knob[0]] as SpinBox).value
	for child: Node in _grid.get_children():
		child.queue_free()
	_cells.clear()
	_grid.columns = maxi(1, int((size.x - 460.0) / (THUMB.x + 10.0)))
	_status.text = "laying out %d levels on row %d..." % [job["count"], job["row"]]
	_thread = Thread.new()
	_thread.start(_work.bind(job))


## The worker: each level in turn, handed to the panel as it is done.
func _work(job: Dictionary) -> void:
	var wfc: Node = _make_wfc()
	var texture: ImageTexture = ImageTexture.create_from_image(job["sample"])
	var total: int = 0
	for i: int in range(int(job["count"])):
		if job["id"] != _wanted:
			break
		var started: int = Time.get_ticks_msec()
		var at: Vector2i = Vector2i(int(job["first"]) + i, int(job["row"]))
		var out: Dictionary = _level(wfc, texture, at, job)
		out["ms"] = Time.get_ticks_msec() - started
		total += int(out["ms"])
		_got.call_deferred(job["id"], out)
	wfc.free()
	_finished.call_deferred(job["id"], total)


## Level `at` collapsed from the job's sample and settings, dressed if asked: {"at", "image" (a pixel
## a cell), "note", "settled"}.
static func _level(wfc: Node, texture: ImageTexture, at: Vector2i, job: Dictionary) -> Dictionary:
	var def: NextWorldDef = Rules.def_for(at)
	var level_size: Vector2i = job["size"] if job["size"] != Vector2i.ZERO else def.size
	wfc.set("texture", texture)
	wfc.set("output_size", level_size)
	# The versions picked, by mask (the count kept to match, for an extension without masks).
	var mask: int = int(job["symmetry_mask"])
	var count: int = 0
	for k: int in range(8):
		if (mask >> k) & 1 != 0:
			count += 1
	wfc.set("symmetry", count)
	wfc.set("symmetry_mask", mask)
	wfc.set("pattern_size", int(job["pattern"]))
	var cells: Array = []
	var tries: int = 0
	for attempt: int in range(TRIES):
		tries += 1
		wfc.call("set_seed", def.gen_seed if attempt == 0 else Rules.level_seed(def.gen_seed, 1000 + attempt))
		cells = wfc.call("collapse")
		if not cells.is_empty():
			break
	if cells.is_empty():
		return {"at": at, "image": null, "note": "never settled (%d tries)" % tries, "settled": false, "cells": [], "level": null}
	var w: LevelGen = null
	var note: String = ""
	if job["dress"] and def.patches().is_empty():
		for knob: String in job["tune"]:
			def.arch.set(knob, job["tune"][knob])
		w = LevelGen.new(cells, def)
	elif job["dress"]:
		note = " (this band builds insides of its own: shown undressed)"
	var img: Image = _picture(cells, w)
	var line: String = "%s  %dx%d" % [Rules.where(at), level_size.x, level_size.y]
	if tries > 1:
		line += ", %d tries" % tries
	line += "\nopen %d%%" % roundi(100.0 * float(_open_cells(cells)) / float(level_size.x * level_size.y))
	if w != null:
		var foes: int = 0
		for t: LevelGen.Type in FOES:
			foes += w.objects_of(t).size()
		line += ", foes %d, stars %d, keys %d, doors %d" % [foes, w.objects_of(LevelGen.Type.COIN).size(), w.objects_of(LevelGen.Type.KEY).size(), w.objects_of(LevelGen.Type.DOOR).size()]
	return {"at": at, "image": img, "note": line + note, "settled": true, "cells": cells, "level": w, "tune": job["tune"]}


static func _open_cells(cells: Array) -> int:
	var n: int = 0
	for column: Variant in cells:
		if column is Array:
			for c: Color in column:
				if not c.is_equal_approx(Color.BLACK):
					n += 1
	return n


## A level as an image, a pixel a cell: its terrain from the collapse (`cells`), then, dressed
## (`w`), what stands in it.
static func _picture(cells: Array, w: LevelGen) -> Image:
	var wide: int = cells.size()
	var high: int = (cells[0] as Array).size()
	var img: Image = Image.create(wide, high, false, Image.FORMAT_RGBA8)
	for x: int in range(wide):
		var column: Array = cells[x]
		for y: int in range(high):
			var c: Color = column[y]
			img.set_pixel(x, y, SHOW_ROCK if c.is_equal_approx(Color.BLACK) else (SHOW[LevelGen.Type.SPIKES] if c.is_equal_approx(Color.RED) else SHOW_OPEN))
	if w == null:
		return img
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var t: LevelGen.Type = w.get_cell(Vector2i(x, y)).type
			if t == LevelGen.Type.GROUND:
				img.set_pixel(x, y, SHOW_ROCK)
			elif t == LevelGen.Type.EMPTY:
				img.set_pixel(x, y, SHOW_OPEN)
			elif SHOW.has(t):
				img.set_pixel(x, y, SHOW[t])
			elif t in FOES:
				img.set_pixel(x, y, SHOW_FOE)
			elif t == LevelGen.Type.COIN or t == LevelGen.Type.CLUSTER:
				img.set_pixel(x, y, SHOW_STAR)
	return img


## A generator set as the game scene sets its own (pattern size and the rest), out of any tree.
static func _make_wfc() -> Node:
	var wfc: Node = (load("res://scripts/WaveFunctionCollapse.gd") as GDScript).new() as Node
	var state: SceneState = (load("res://prefabs/scenes/main.tscn") as PackedScene).get_state()
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) != &"WaveFunctionCollapse":
			continue
		for p: int in range(state.get_node_property_count(i)):
			var prop: StringName = state.get_node_property_name(i, p)
			if prop != &"script":
				wfc.set(prop, state.get_node_property_value(i, p))
	return wfc


## A level done by job `id`: shown, unless a newer job has been asked for.
func _got(id: int, out: Dictionary) -> void:
	if id != _wanted:
		return
	_cells.append(out)
	var box: VBoxContainer = VBoxContainer.new()
	_grid.add_child(box)
	var view: TextureRect = TextureRect.new()
	view.custom_minimum_size = THUMB
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if out["image"] != null:
		view.texture = ImageTexture.create_from_image(out["image"])
	view.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and view.texture != null:
			_big_view.texture = view.texture
			_big_note.text = String(out["note"]) + "   (click to close)"
			_chosen = out
			_big.visible = true)
	box.add_child(view)
	var note: Label = Label.new()
	note.text = out["note"]
	note.custom_minimum_size.x = THUMB.x
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)


func _finished(id: int, total: int) -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	if _pending:
		_pending = false
		_launch()
		return
	if id != _wanted:
		return
	var settled: int = _cells.filter(func(o: Dictionary) -> bool: return o["settled"]).size()
	_status.text = "%d levels on row %d (%s) in %.1f s, %d settled" % [_cells.size(), int(_row.value), NextWorldDef.archetype_at(int(_row.value)), float(total) / 1000.0, settled]


# ------------------------------------------------------------------ in the game

## Open the game on the level shown large: looking at it whole (`look`), or playing it from its way
## in. The lab is hidden meanwhile, and comes back as it was with BACK_KEYS.
func _enter_game(look: bool) -> void:
	if _chosen.is_empty() or not _chosen["settled"] or _game != null:
		return
	var at: Vector2i = _chosen["at"]
	var cells: Array = _chosen["cells"]
	var w: LevelGen = _chosen["level"]
	if w == null:
		# Shown undressed: dressed now, as the game would.
		var def: NextWorldDef = Rules.def_for(at)
		for knob: String in _chosen["tune"]:
			def.arch.set(knob, _chosen["tune"][knob])
		w = LevelGen.new(cells, def)
	_was_save = RunState.save_path
	RunState.save_path = LAB_SAVE
	RunState.delete_save()
	_was_by_sight = RisoLight.by_sight
	_big.visible = false
	visible = false
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_game = (load(MAIN) as PackedScene).instantiate()
	get_tree().root.add_child(_game)
	var info: MapInfo = _game.get_node("CanvasLayer/MapInfo") as MapInfo
	info.loader.keep(at, cells, w)
	_game.get_node("Menu").call("start_at", at)
	_looking = false
	_hint.text = "Backspace: back to the lab"
	_hint.visible = true
	if look:
		await _settled_in(info)
		_look(info)


## Wait until the place has been built, the wizard set down in it and its title card gone.
func _settled_in(info: MapInfo) -> void:
	for i: int in range(900):
		await get_tree().process_frame
		var titling: bool = RisoTransition.instance != null and RisoTransition.instance.titling()
		if info.world != null and not info.travelling and Stage.player() != null and not titling:
			break
	for i: int in range(20):
		await get_tree().process_frame


## The whole level in view, the wizard held still and light by sight off (as the overview stills).
func _look(info: MapInfo) -> void:
	var player: Player = Stage.player()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	RisoLight.by_sight = false
	var camera: Camera2D = Stage.camera()
	_limits = [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]
	_zoom = camera.zoom
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	var rect: Rect2 = info.level_rect()
	var view: Vector2 = Vector2(get_tree().root.content_scale_size)
	var fit: float = minf(view.x / rect.size.x, view.y / rect.size.y)
	camera.zoom = Vector2(fit, fit)
	camera.global_position = rect.get_center()
	camera.reset_smoothing()
	_looking = true
	_hint.text = "Backspace: back to the lab    P: play from here    wheel: zoom    drag: move"


## From looking to playing: the wizard and the camera as the game has them.
func _play_from_look() -> void:
	var player: Player = Stage.player()
	var camera: Camera2D = Stage.camera()
	RisoLight.by_sight = _was_by_sight
	camera.limit_left = _limits[0]
	camera.limit_top = _limits[1]
	camera.limit_right = _limits[2]
	camera.limit_bottom = _limits[3]
	camera.zoom = _zoom
	player.set_physics_process(true)
	player.get_node("CameraControl").set_process(true)
	CameraControl.snap(player)
	_looking = false
	_hint.text = "Backspace: back to the lab"


## Close the game and show the lab as it was.
func _leave_game() -> void:
	if _game == null:
		return
	_game.queue_free()
	_game = null
	_looking = false
	_hint.visible = false
	await get_tree().process_frame
	RisoLight.by_sight = _was_by_sight
	RunState.delete_save()
	RunState.save_path = _was_save
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	visible = true


func _input(event: InputEvent) -> void:
	if _game == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode in BACK_KEYS or key.physical_keycode in BACK_KEYS:
			get_viewport().set_input_as_handled()
			_leave_game()
		elif _looking and key.keycode == KEY_P:
			get_viewport().set_input_as_handled()
			_play_from_look()
		return
	if not _looking:
		return
	var camera: Camera2D = Stage.camera()
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= ZOOM_STEP
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom /= ZOOM_STEP
	var drag: InputEventMouseMotion = event as InputEventMouseMotion
	if drag != null and drag.button_mask != 0:
		camera.global_position -= drag.relative / camera.zoom
		camera.reset_smoothing()


## The sample, drawn large, painted with the mouse.
class SampleCanvas extends Control:
	## Px a pixel of the sample is drawn.
	const PX: int = 12
	var lab: Node
	var _texture: ImageTexture

	func refresh() -> void:
		var img: Image = lab.get("sample")
		_texture = ImageTexture.create_from_image(img)
		custom_minimum_size = Vector2(img.get_size() * PX)
		queue_redraw()

	func _draw() -> void:
		if _texture == null:
			return
		var img_size: Vector2 = Vector2(_texture.get_size())
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, img_size * PX), false)
		var grid: Color = Color(0.5, 0.5, 0.5, 0.25)
		for x: int in range(int(img_size.x) + 1):
			draw_line(Vector2(x * PX, 0), Vector2(x * PX, img_size.y * PX), grid)
		for y: int in range(int(img_size.y) + 1):
			draw_line(Vector2(0, y * PX), Vector2(img_size.x * PX, y * PX), grid)

	func _gui_input(event: InputEvent) -> void:
		var pressed: int = 0
		var at: Vector2 = Vector2.ZERO
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			pressed = (event as InputEventMouseButton).button_index
			at = (event as InputEventMouseButton).position
		elif event is InputEventMouseMotion:
			var mask: int = (event as InputEventMouseMotion).button_mask
			pressed = MOUSE_BUTTON_LEFT if (mask & MOUSE_BUTTON_MASK_LEFT) != 0 else (MOUSE_BUTTON_RIGHT if (mask & MOUSE_BUTTON_MASK_RIGHT) != 0 else 0)
			at = (event as InputEventMouseMotion).position
		if pressed == MOUSE_BUTTON_LEFT:
			lab.call("paint", Vector2i(at / PX), int(lab.get("ink")))
		elif pressed == MOUSE_BUTTON_RIGHT:
			lab.call("paint", Vector2i(at / PX), 0)
