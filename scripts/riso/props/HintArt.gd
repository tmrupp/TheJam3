extends RisoProp
class_name HintArt
## A tutorial control card (ControlHint): while it is up, a paper card over its spot with the
## control it asks for, in the player's own bindings, read from the input map: on the keyboard, key
## caps (the key's letter; the space bar a wide blank cap, shift a cap with an arrow up), two of them
## with arrows either side for walking; on a pad, the four face buttons with the bound one inked,
## the two shoulders with the bound one inked (a trigger tall, a bumper flat), or the stick with
## arrows either way for walking. It rises and sinks as the card comes and goes. No words.

## The ControlHint it dresses.
var hint: ControlHint:
	get:
		return host as ControlHint
## How far up the card is, eased from 0 to 1.
var open: float = 0.0
## The card's middle over the ground, and the padding round what is on it (world pixels).
const CARD_Y: float = 230.0
const PAD: Vector2 = Vector2(16, 12)
## A key cap: its height, its width for a letter, the space bar's, and the lip along its foot.
const CAP_H: float = 44.0
const CAP_W: float = 46.0
const SPACE_W: float = 120.0
const LIP: float = 7.0
## A key's letter (font size), and the gap between two caps.
const LETTER_PX: int = 28
const GAP: float = 14.0
## A pad's face buttons: their radius and how far each sits from the middle.
const FACE_R: float = 9.0
const FACE_OFF: float = 17.0
## The pad drawn under its shoulders: its body, and a trigger's size and a bumper's, standing on
## the body's top corners.
const BODY: Vector2 = Vector2(78, 30)
const TRIGGER: Vector2 = Vector2(20, 18)
const BUMPER: Vector2 = Vector2(26, 9)
## The paper left between a shoulder and the body under it.
const SHOULDER_GAP: float = 4.0
## The stick: its well and its cap.
const STICK_R: float = 22.0
const STICK_CAP: float = 11.0
## Shift's arrow up: half its height (and its head's half width).
const SHIFT_ARROW: float = 13.0
## A walking arrow's length and half height.
const ARROW: Vector2 = Vector2(14, 10)
## What a faint part (an unbound button, the pad's body) is printed at, in the card's tint plate.
const FAINT: float = 0.6
## The card's tint, a key cap's face and its lip (in night).
const CARD_TINT: float = 0.1
const CAP_FACE: float = 0.4
const CAP_LIP: float = 0.55


func _draw_art() -> void:
	open = move_toward(open, 1.0 if hint.showing() else 0.0, _dt * 4.0)
	if open < 0.02:
		return
	var p: float = open - 1.0
	var s: float = 1.0 + 2.7 * p * p * p + 1.7 * p * p
	var centre: Vector2 = Vector2(0, _ground() - CARD_Y * s)
	var size: Vector2 = _glyph_size() * s
	var card: PackedVector2Array = RisoShapes.rrect(centre.x - size.x * 0.5 - PAD.x * s, centre.y - size.y * 0.5 - PAD.y * s,
			size.x + PAD.x * 2.0 * s, size.y + PAD.y * 2.0 * s, 12.0 * s)
	var u: InkCanvas = _ui()
	u.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [card])
	u.ink(RisoPrint.BLUE, CARD_TINT, [card], false)
	_glyph(u, centre, s)


# ------------------------------------------------------------------ what the card shows

## The size of what the card shows, unscaled.
func _glyph_size() -> Vector2:
	if ControlHint.pad:
		match _pad_kind():
			&"face":
				return Vector2(FACE_OFF * 2.0 + FACE_R * 2.0, FACE_OFF * 2.0 + FACE_R * 2.0)
			&"stick":
				return Vector2(STICK_R * 2.0 + (ARROW.x + 8.0) * 2.0, STICK_R * 2.0)
			_:
				return Vector2(BODY.x, BODY.y + TRIGGER.y + SHOULDER_GAP)
	if hint.action == &"Move":
		return Vector2(CAP_W * 2.0 + GAP + (ARROW.x + 8.0) * 2.0, CAP_H)
	return Vector2(_cap_width(_key(hint.action)), CAP_H)


func _glyph(u: InkCanvas, at: Vector2, s: float) -> void:
	if ControlHint.pad:
		match _pad_kind():
			&"face":
				_face(u, at, s, _pad_button(hint.action))
			&"stick":
				_stick(u, at, s)
			_:
				_shoulders(u, at, s)
		return
	if hint.action == &"Move":
		var off: float = (CAP_W + GAP) * 0.5 * s
		_cap(u, at - Vector2(off, 0), s, _key(&"Left"))
		_cap(u, at + Vector2(off, 0), s, _key(&"Right"))
		var reach: float = off + CAP_W * 0.5 * s + 8.0 * s
		_arrow(u, at - Vector2(reach, 0), -1.0, s)
		_arrow(u, at + Vector2(reach, 0), 1.0, s)
		return
	_cap(u, at, s, _key(hint.action))


## A key cap for `key` centred on `at`: paper, tinted, with a darker lip along its foot, and its
## letter, or an arrow up (shift), or nothing (the space bar).
func _cap(u: InkCanvas, at: Vector2, s: float, key: Key) -> void:
	var w: float = _cap_width(key) * s
	var h: float = CAP_H * s
	var face: PackedVector2Array = RisoShapes.rrect(at.x - w * 0.5, at.y - h * 0.5, w, h, 8.0 * s)
	u.ink(RisoPrint.NIGHT, CAP_LIP, [face], false)
	var top: PackedVector2Array = RisoShapes.rrect(at.x - w * 0.5, at.y - h * 0.5, w, h - LIP * s, 8.0 * s)
	u.knock([RisoPrint.NIGHT], [top])
	u.ink(RisoPrint.BLUE, CAP_FACE, [top], false)
	var mid: Vector2 = at - Vector2(0, LIP * 0.5 * s)
	if key == KEY_SPACE:
		return
	if key == KEY_SHIFT:
		var a: float = SHIFT_ARROW * s
		var head: PackedVector2Array = PackedVector2Array([mid + Vector2(0, -a), mid + Vector2(a, 0), mid + Vector2(-a, 0)])
		var stem: PackedVector2Array = RisoShapes.rrect(mid.x - a * 0.4, mid.y - 1.0 * s, a * 0.8, a, 1.5 * s)
		u.ink(RisoPrint.NIGHT, 1.0, [head, stem], false)
		return
	_text(_label(key), mid, LETTER_PX, s)


## A walking arrow at `at`, pointing `dir` (-1 left, 1 right).
func _arrow(u: InkCanvas, at: Vector2, dir: float, s: float) -> void:
	var tip: Vector2 = at + Vector2(dir * ARROW.x * s, 0)
	u.ink(RisoPrint.NIGHT, 1.0, [PackedVector2Array([tip, at + Vector2(0, -ARROW.y * s), at + Vector2(0, ARROW.y * s)])], false)


## The four face buttons round `at`, button `bound` (0 the bottom, 1 the right, 2 the left, 3 the
## top) inked, the rest faint.
func _face(u: InkCanvas, at: Vector2, s: float, bound: int) -> void:
	var spots: Array[Vector2] = [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]
	for i: int in range(spots.size()):
		var disc: PackedVector2Array = RisoShapes.circle(at + spots[i] * FACE_OFF * s, FACE_R * s)
		if i == bound:
			u.ink(RisoPrint.NIGHT, 1.0, [disc], false)
		else:
			u.ink(RisoPrint.BLUE, FAINT, [disc], false)


## A pad seen from the front, centred on `at`: its body faint, a shoulder on each of its top corners
## (a trigger tall, a bumper flat), the bound one inked.
func _shoulders(u: InkCanvas, at: Vector2, s: float) -> void:
	var size: Vector2 = (TRIGGER if _pad_kind() == &"trigger" else BUMPER) * s
	var right: bool = _pad_side() > 0
	var body: Vector2 = BODY * s
	var top: float = at.y - (body.y + (TRIGGER.y + SHOULDER_GAP) * s) * 0.5 + (TRIGGER.y + SHOULDER_GAP) * s
	u.ink(RisoPrint.BLUE, FAINT, [RisoShapes.rrect(at.x - body.x * 0.5, top, body.x, body.y, body.y * 0.45)], false)
	for side: float in [-1.0, 1.0]:
		var x: float = at.x + side * (body.x * 0.5 - size.x * 0.5 - 6.0 * s)
		var shape: PackedVector2Array = RisoShapes.rrect(x - size.x * 0.5, top - size.y - SHOULDER_GAP * s, size.x, size.y, 3.0 * s)
		if (side > 0.0) == right:
			u.ink(RisoPrint.NIGHT, 1.0, [shape], false)
		else:
			u.ink(RisoPrint.BLUE, FAINT, [shape], false)


## The stick at `at`: its well, its cap, and arrows either way.
func _stick(u: InkCanvas, at: Vector2, s: float) -> void:
	u.ink(RisoPrint.BLUE, FAINT, [RisoShapes.circle(at, STICK_R * s)], false)
	u.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.circle(at, STICK_CAP * s)], false)
	var reach: float = (STICK_R + 8.0) * s
	_arrow(u, at - Vector2(reach, 0), -1.0, s)
	_arrow(u, at + Vector2(reach, 0), 1.0, s)


# ------------------------------------------------------------------ the bindings

## The key action `a` is bound to on the keyboard (as laid out on this one), or KEY_NONE.
static func _key(a: StringName) -> Key:
	if not InputMap.has_action(a):
		return KEY_NONE
	for e: InputEvent in InputMap.action_get_events(a):
		var k: InputEventKey = e as InputEventKey
		if k == null:
			continue
		if k.keycode != KEY_NONE:
			return k.keycode
		# The key in that place on this keyboard's layout (a headless run has no keyboard to ask).
		var local: Key = KEY_NONE
		if DisplayServer.get_name() != "headless":
			local = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		return local if local != KEY_NONE else k.physical_keycode
	return KEY_NONE


## A key cap's width: wide for the space bar, wider for a key with a long name.
func _cap_width(key: Key) -> float:
	if key == KEY_SPACE:
		return SPACE_W
	if key == KEY_SHIFT:
		return CAP_W * 1.3
	var label: String = _label(key)
	if label.length() <= 1:
		return CAP_W
	return maxf(CAP_W, RisoTheme.serif().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_PX).x + 20.0)


## What a key cap is printed with: the key's name as the keyboard shows it.
static func _label(key: Key) -> String:
	return OS.get_keycode_string(key)


## Which part of a pad the card's control is on: &"face" (a face button), &"trigger", &"bumper",
## or &"stick".
func _pad_kind() -> StringName:
	if hint.action == &"Move":
		return &"stick"
	for e: InputEvent in _pad_events():
		if e is InputEventJoypadButton:
			var b: int = (e as InputEventJoypadButton).button_index
			if b <= JOY_BUTTON_Y:
				return &"face"
			if b == JOY_BUTTON_LEFT_SHOULDER or b == JOY_BUTTON_RIGHT_SHOULDER:
				return &"bumper"
	for e: InputEvent in _pad_events():
		if e is InputEventJoypadMotion:
			var axis: int = (e as InputEventJoypadMotion).axis
			if axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT:
				return &"trigger"
			return &"stick"
	return &"face"


## Which side the bound shoulder is on (-1 left, 1 right).
func _pad_side() -> int:
	for e: InputEvent in _pad_events():
		if e is InputEventJoypadButton:
			return 1 if (e as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		if e is InputEventJoypadMotion:
			return 1 if (e as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT else -1
	return 1


## The face button action `a` is bound to (0 the bottom ... 3 the top; see _face).
static func _pad_button(a: StringName) -> int:
	if not InputMap.has_action(a):
		return 0
	for e: InputEvent in InputMap.action_get_events(a):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index <= JOY_BUTTON_Y:
			return (e as InputEventJoypadButton).button_index
	return 0


## The pad events of the card's control, buttons first.
func _pad_events() -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if not InputMap.has_action(hint.action):
		return out
	for e: InputEvent in InputMap.action_get_events(hint.action):
		if e is InputEventJoypadButton:
			out.push_front(e)
		elif e is InputEventJoypadMotion:
			out.append(e)
	return out
