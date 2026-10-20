extends Node2D
class_name RisoTransition
## The printed passage between levels: a sheet of night ink with a ragged, inky edge sweeps
## across the view like scenery going by (up when you go deeper, down when you go back,
## sideways for the side doors), holds while the next level is laid out, showing where you are
## going on a paper plaque, then sweeps on and away. Printed in the 320 x 180 UI space, above
## the world and below the HUD.
## Coming into a region (a band of levels: the garden, the cemetery...) from another, and at a run's
## start, its title card follows (title): a paper banner across the top of the view with the
## region's name, rising in, held a moment and fading. It is the one place words print in the UI.

const COVER_TIME: float = 0.28
const REVEAL_TIME: float = 0.38
## The sheet holds at least this long, so the destination can be read even when the level is
## already cached.
const HOLD: float = 0.35
const EDGE: float = 0.08
## Beyond the view on both sides: ink registration and paper wobble shift the printed plates.
const OVERSCAN: float = 16.0
const KNOCK_ALL: Array[int] = RisoPrint.ALL_PLATES

static var instance: RisoTransition

signal covered

enum State { IDLE, COVERING, COVERED, REVEALING }

var state: int = State.IDLE
## Leading and trailing edges of the sheet along its path, 0..1 (plus EDGE overshoot).
var lead: float = 0.0
var trail: float = 0.0
## The direction the sheet moves across the view.
var sweep: Vector2 = Vector2.UP
## Where you are going, printed as marks and numbers (RisoMarks.place_marks).
var destination: Vector2i = Vector2i.ZERO
## Half the height of its marks on the card.
const PLACE_R: float = 5.0
var covered_at: float = 0.0
var reveal_wanted: bool = false
var ink: InkCanvas
## The destination's world and depth numbers.
var world_label: Label
var depth_label: Label
var t: float = 0.0
## The region title card (see title): its text, its label, and its age (seconds; -1 when none).
## It waits for the sheet to be gone before it shows.
const TITLE_IN: float = 0.35
const TITLE_HOLD: float = 2.0
const TITLE_OUT: float = 0.7
## The banner's middle (UI units) and height; the name's print size.
const TITLE_Y: float = 34.0
const TITLE_H: float = 26.0
const TITLE_PX: float = 16.0
var title_text: String = ""
var title_label: Label
var title_age: float = -1.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	z_index = 58
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)
	world_label = _make_label()
	depth_label = _make_label()
	title_label = _make_label()
	title_label.scale = Vector2.ONE * (TITLE_PX / 64.0)


func _make_label() -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", RisoTheme.serif())
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.scale = Vector2.ONE * (11.0 / 64.0)
	label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
	label.visible = false
	add_child(label)
	return label


func busy() -> bool:
	return state != State.IDLE


## Sweep the sheet over the view; returns once it covers it. `travel` is the way the player is
## going (the sheet moves the other way, as scenery would). Instant when the print is off.
func cover(travel: Vector2, to: Vector2i) -> void:
	if not RisoPrint.is_on() or not is_inside_tree():
		return
	sweep = -travel.normalized() if travel != Vector2.ZERO else Vector2.UP
	destination = to
	lead = 0.0
	trail = 0.0
	reveal_wanted = false
	state = State.COVERING
	await covered


## Show the title card of a region, `text` (once the sheet, if it is up, has gone).
func title(text: String) -> void:
	if text == "" or not RisoPrint.is_on():
		return
	title_text = text
	title_age = 0.0


## Whether a title card is up or waiting to be.
func titling() -> bool:
	return title_age >= 0.0


## Sweep the sheet on and away (no-op unless it is covering the view).
func reveal() -> void:
	if state == State.COVERING or state == State.COVERED:
		reveal_wanted = true


func _process(delta: float) -> void:
	t += delta
	match state:
		State.COVERING:
			lead = minf(1.0 + EDGE, lead + delta / COVER_TIME)
			if lead >= 1.0 + EDGE:
				state = State.COVERED
				covered_at = t
				covered.emit()
		State.COVERED:
			if reveal_wanted and t - covered_at >= HOLD:
				state = State.REVEALING
		State.REVEALING:
			trail = minf(1.0 + EDGE, trail + delta / REVEAL_TIME)
			if trail >= 1.0 + EDGE:
				state = State.IDLE
	ink.begin()
	world_label.visible = false
	depth_label.visible = false
	title_label.visible = false
	if state != State.IDLE:
		_draw_sheet()
	elif title_age >= 0.0:
		title_age += delta
		if title_age >= TITLE_IN + TITLE_HOLD + TITLE_OUT:
			title_age = -1.0
		else:
			_draw_title()
	ink.finish()


## The region's title card: a paper banner across the top of the view, its name in night ink
## between two short rules, rising in, held, and fading out.
func _draw_title() -> void:
	_fit_to_view()
	var come: float = clampf(title_age / TITLE_IN, 0.0, 1.0)
	var go: float = clampf((title_age - TITLE_IN - TITLE_HOLD) / TITLE_OUT, 0.0, 1.0)
	var y: float = TITLE_Y + (1.0 - come) * (1.0 - come) * 10.0
	var fade: float = come * (1.0 - go)
	var w: float = RisoTheme.serif().get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * (TITLE_PX / 64.0)
	var banner: PackedVector2Array = RisoShapes.rrect(160.0 - w * 0.5 - 30.0, y - TITLE_H * 0.5, w + 60.0, TITLE_H, 8.0)
	ink.knock(KNOCK_ALL, [banner])
	ink.ink(RisoPrint.BLUE, 0.12 * fade, [banner], false)
	var rule_w: float = 14.0
	ink.ink(RisoPrint.NIGHT, fade, [RisoShapes.rrect(160.0 - w * 0.5 - 22.0, y - 1.0, rule_w, 2.0, 1.0), RisoShapes.rrect(160.0 + w * 0.5 + 8.0, y - 1.0, rule_w, 2.0, 1.0)], false)
	if fade > 0.35:
		title_label.visible = true
		title_label.text = title_text
		title_label.size = Vector2((w + 4.0) / title_label.scale.x, TITLE_H / title_label.scale.y)
		title_label.position = Vector2(160.0 - w * 0.5, y - TITLE_H * 0.5).round()


## Line the node up with the view, so its 320 x 180 UI units cover it.
func _fit_to_view() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var base: Vector2 = Vector2(get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var view: Vector2 = base / cam.zoom
	global_position = cam.get_screen_center_position() - view * 0.5
	scale = Vector2.ONE / cam.zoom


func _draw_sheet() -> void:
	if get_viewport().get_camera_2d() == null:
		return
	_fit_to_view()
	var size: Vector2 = Vector2(320, 180)
	# Work in a frame where the sheet moves along +u; map back to the view.
	var along_x: bool = sweep.x != 0.0
	var length: float = size.x if along_x else size.y
	var across: float = size.y if along_x else size.x
	var flip: bool = (sweep.x < 0.0) if along_x else (sweep.y < 0.0)
	var to_view: Callable = func(u: float, w: float) -> Vector2:
		var uu: float = length - u if flip else u
		return Vector2(uu, w) if along_x else Vector2(w, uu)
	var steps: int = 24
	var front: PackedVector2Array = PackedVector2Array()
	var back: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var w: float = -OVERSCAN + (across + 2.0 * OVERSCAN) * float(i) / float(steps)
		var ragged: float = (RisoShapes.hash1(float(i) * 3.7 + 1.3) - 0.5) * EDGE * length + sin(w * 0.09 + t * 3.0) * 2.0
		var reach: float = lead * length + ragged
		# Fully over the view, the ragged front runs well past its far edge, so no sliver of the
		# old place shows there, whatever the plates' misregistration or the camera's last nudge.
		if lead >= 1.0:
			reach = maxf(reach, length + OVERSCAN)
		front.append(to_view.call(clampf(reach, -4.0, length + 40.0), w))
		var tail: float = -40.0 if trail <= 0.0 else trail * length + (RisoShapes.hash1(float(i) * 5.1 + 7.7) - 0.5) * EDGE * length
		back.append(to_view.call(clampf(tail, -40.0, length + 40.0), w))
	back.reverse()
	var sheet: PackedVector2Array = front + back
	ink.knock(KNOCK_ALL, [sheet])
	ink.ink(RisoPrint.NIGHT, 1.0, [sheet], false)
	ink.ink(RisoPrint.BLUE, 0.25, [sheet], false)
	# Where you are going, once the sheet has the middle of the view.
	if state == State.COVERED or (state == State.COVERING and lead > 0.7) or (state == State.REVEALING and trail < 0.3):
		var n: Vector3i = Rules.place_numbers(destination)
		var texts: PackedStringArray = PackedStringArray([str(n.x), str(absi(n.y))])
		var widths: Vector2 = Vector2(_width(texts[0]), _width(texts[1]))
		var side: bool = Worlds.is_side(destination)
		var w: float = RisoMarks.place_width(PLACE_R, widths, side)
		var plate: PackedVector2Array = RisoShapes.rrect(160.0 - w * 0.5 - 9.0, 81.0, w + 18.0, 18.0, 6.0)
		ink.knock(KNOCK_ALL, [plate])
		ink.ink(RisoPrint.BLUE, 0.12, [plate], false)
		var xs: Vector2 = RisoMarks.place_marks(ink, Vector2(160.0 - w * 0.5, 90.0), PLACE_R, widths, side, n.y < 0)
		for k: int in range(2):
			var label: Label = world_label if k == 0 else depth_label
			label.visible = true
			label.text = texts[k]
			label.size = Vector2((widths[k] + 4.0) / label.scale.x, 18.0 / label.scale.y)
			label.position = Vector2(xs[k], 81.0)


## Width of a number on the card, in UI units.
func _width(text: String) -> float:
	return RisoTheme.serif().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * (11.0 / 64.0)
