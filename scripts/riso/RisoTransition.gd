extends Node2D
class_name RisoTransition
## The printed passage between levels: a sheet of night ink with a ragged, inky edge sweeps
## across the view like scenery going by (up when you go deeper, down when you go back,
## sideways for the side doors), holds while the next level is laid out, showing where you are
## going on a paper plaque, then sweeps on and away. Printed in the 320 x 180 UI space, above
## the world and below the HUD.

const COVER_TIME: float = 0.28
const REVEAL_TIME: float = 0.38
## The sheet holds at least this long, so the destination can be read even when the level is
## already cached.
const HOLD: float = 0.35
const EDGE: float = 0.08
const KNOCK_ALL: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW]

static var instance: RisoTransition

signal covered

enum State { IDLE, COVERING, COVERED, REVEALING }

var state: int = State.IDLE
## Leading and trailing edges of the sheet along its path, 0..1 (plus EDGE overshoot).
var lead: float = 0.0
var trail: float = 0.0
## The direction the sheet moves across the view.
var sweep: Vector2 = Vector2.UP
var text: String = ""
var covered_at: float = 0.0
var reveal_wanted: bool = false
var ink: InkCanvas
var label: Label
var t: float = 0.0


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
	label = Label.new()
	label.add_theme_font_override("font", RisoTheme.serif())
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.scale = Vector2.ONE * (11.0 / 64.0)
	label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
	label.visible = false
	add_child(label)


func busy() -> bool:
	return state != State.IDLE


## Sweep the sheet over the view; returns once it covers it. `travel` is the way the player is
## going (the sheet moves the other way, as scenery would). Instant when the print is off.
func cover(travel: Vector2, destination: String) -> void:
	if not RisoPrint.is_on() or not is_inside_tree():
		return
	sweep = -travel.normalized() if travel != Vector2.ZERO else Vector2.UP
	text = destination
	lead = 0.0
	trail = 0.0
	reveal_wanted = false
	state = State.COVERING
	await covered


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
	label.visible = false
	if state != State.IDLE:
		_draw_sheet()
	ink.finish()


func _draw_sheet() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var base: Vector2 = Vector2(get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var view: Vector2 = base / cam.zoom
	global_position = cam.get_screen_center_position() - view * 0.5
	scale = Vector2.ONE / cam.zoom
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
		var w: float = across * float(i) / float(steps)
		var ragged: float = (RisoShapes.hash1(float(i) * 3.7 + 1.3) - 0.5) * EDGE * length + sin(w * 0.09 + t * 3.0) * 2.0
		front.append(to_view.call(clampf(lead * length + ragged, -4.0, length + 40.0), w))
		var tail: float = -40.0 if trail <= 0.0 else trail * length + (RisoShapes.hash1(float(i) * 5.1 + 7.7) - 0.5) * EDGE * length
		back.append(to_view.call(clampf(tail, -40.0, length + 40.0), w))
	back.reverse()
	var sheet: PackedVector2Array = front + back
	ink.knock(KNOCK_ALL, [sheet])
	ink.ink(RisoPrint.NIGHT, 1.0, [sheet], false)
	ink.ink(RisoPrint.BLUE, 0.25, [sheet], false)
	# Where you are going, once the sheet has the middle of the view.
	if state == State.COVERED or (state == State.COVERING and lead > 0.7) or (state == State.REVEALING and trail < 0.3):
		var w: float = RisoTheme.serif().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x * label.scale.x
		var plate: PackedVector2Array = RisoShapes.rrect(160.0 - w * 0.5 - 9.0, 81.0, w + 18.0, 18.0, 6.0)
		ink.knock(KNOCK_ALL, [plate])
		ink.ink(RisoPrint.BLUE, 0.12, [plate], false)
		label.visible = true
		label.text = text
		label.size = Vector2((w + 18.0) / label.scale.x, 18.0 / label.scale.y)
		label.position = Vector2(160.0 - w * 0.5 - 9.0, 81.0)
