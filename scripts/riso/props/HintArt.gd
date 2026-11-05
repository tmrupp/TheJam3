extends RisoProp
class_name HintArt
## A tutorial control card (ControlHint): while it is up, a paper card over its spot with the
## control it asks for, in the player's own bindings, read from the input map: on the keyboard, key
## caps (the key's letter; the space bar a wide blank cap, shift a cap with an arrow up), two of them
## with arrows either side for walking; on a pad, the game's one pad (RisoPad) with the control
## solid on it (the stick with arrows either way for walking, a shoulder with an arrow down at it).
## The guard's cards (ControlHint.PARRY, POGO) show the Spell button between two gold gleams, the
## guard's own colour; the pogo's has a row of pink thorns under it. It rises and sinks as the card
## comes and goes. No words.

## The ControlHint it dresses.
var hint: ControlHint:
	get:
		return host as ControlHint
## How far up the card is, eased from 0 to 1.
var open: float = 0.0
## The card's middle over the ground, and the padding round what is on it (world pixels).
const CARD_Y: float = 230.0
const PAD: Vector2 = Vector2(16, 12)
## A key cap: its height, its width for a letter, the space bar's, the lip along its foot and the
## rounding of its corners.
const CAP_H: float = 44.0
const CAP_W: float = 46.0
const SPACE_W: float = 120.0
const LIP: float = 7.0
const CAP_ROUND: float = 8.0
## A key's letter (font size), and the gap between two caps.
const LETTER_PX: int = 28
const GAP: float = 14.0
## Shift's arrow up: half its height (and its head's half width).
const SHIFT_ARROW: float = 13.0
## A walking arrow's length and half height.
const ARROW: Vector2 = Vector2(14, 10)
## A guard card's gleams either side of its control: how far out from it, their radius and
## thickness, and how far round each sweeps (radians either side of level).
const GLEAM_GAP: float = 8.0
const GLEAM_R: float = 26.0
const GLEAM_W: float = 6.0
const GLEAM_SWEEP: float = 0.85
## The pogo card's thorns under its control: how many, each one's width and height, and the gap.
const THORNS: int = 4
const THORN: Vector2 = Vector2(16, 14)
const THORN_GAP: float = 10.0
## The card's tint.
const CARD_TINT: float = 0.1


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

## The size of what the card shows, unscaled: its control, with a guard card's gleams either side
## and the pogo's thorns under it.
func _glyph_size() -> Vector2:
	var size: Vector2 = _control_size()
	if _guard():
		size.x += (GLEAM_GAP + GLEAM_W) * 2.0
		size.y = maxf(size.y, GLEAM_R * 2.0 * sin(GLEAM_SWEEP))
	if hint.action == ControlHint.POGO:
		size.y += THORN_GAP + THORN.y
	return size


## Whether the card is one of the guard's (a parry, a pogo).
func _guard() -> bool:
	return hint.action in [ControlHint.PARRY, ControlHint.POGO]


## The size of the control alone, unscaled.
func _control_size() -> Vector2:
	if RisoPad.pad:
		return RisoPad.size()
	if hint.action == &"Move":
		return Vector2(CAP_W * 2.0 + GAP + (ARROW.x + 8.0) * 2.0, CAP_H)
	return Vector2(_cap_width(_key(ControlHint.bound(hint.action))), CAP_H)


## What the card shows, centred on `at`: its control, and a guard card's gleams and thorns.
func _glyph(u: InkCanvas, at: Vector2, s: float) -> void:
	var drop: float = (THORN_GAP + THORN.y) * s if hint.action == ControlHint.POGO else 0.0
	var c: Vector2 = at - Vector2(0, drop * 0.5)
	_control(u, c, s)
	if _guard():
		var half: float = (_control_size().x * 0.5 + GLEAM_GAP) * s
		var arcs: Array[PackedVector2Array] = []
		for side: float in [-1.0, 1.0]:
			arcs.append(_gleam(c + Vector2(side * half, 0), side, s))
		u.ink(RisoPrint.ACCENT, 1.0, arcs, false)
	if hint.action == ControlHint.POGO:
		var thorns: Array[PackedVector2Array] = []
		var base: float = at.y + _glyph_size().y * 0.5 * s
		for i: int in range(THORNS):
			var x: float = at.x + (float(i) - float(THORNS - 1) * 0.5) * THORN.x * s
			thorns.append(PackedVector2Array([Vector2(x - THORN.x * 0.5 * s, base), Vector2(x + THORN.x * 0.5 * s, base), Vector2(x, base - THORN.y * s)]))
		u.ink(RisoPrint.PINK, 1.0, thorns, false)


## A gleam of the guard: a band of arc bowing out to `side` (-1 left, 1 right), the inner edge of its
## middle at `at` (world pixels at scale `s`).
func _gleam(at: Vector2, side: float, s: float) -> PackedVector2Array:
	var r: float = GLEAM_R * s
	var centre: Vector2 = at - Vector2(side * r, 0)
	var out: PackedVector2Array = PackedVector2Array()
	var steps: int = 10
	for k: int in range(steps + 1):
		var a: float = lerpf(-GLEAM_SWEEP, GLEAM_SWEEP, float(k) / float(steps))
		out.append(centre + Vector2(side * cos(a), sin(a)) * (r + GLEAM_W * s))
	for k: int in range(steps, -1, -1):
		var a: float = lerpf(-GLEAM_SWEEP, GLEAM_SWEEP, float(k) / float(steps))
		out.append(centre + Vector2(side * cos(a), sin(a)) * r)
	return out


## The control the card asks for, centred on `at`.
func _control(u: InkCanvas, at: Vector2, s: float) -> void:
	if RisoPad.pad:
		RisoPad.draw(u, at, s, ControlHint.bound(hint.action))
		return
	if hint.action == &"Move":
		var off: float = (CAP_W + GAP) * 0.5 * s
		_cap(u, at - Vector2(off, 0), s, _key(&"Left"))
		_cap(u, at + Vector2(off, 0), s, _key(&"Right"))
		var reach: float = off + CAP_W * 0.5 * s + 8.0 * s
		_arrow(u, at - Vector2(reach, 0), -1.0, s)
		_arrow(u, at + Vector2(reach, 0), 1.0, s)
		return
	_cap(u, at, s, _key(ControlHint.bound(hint.action)))


## A key cap for `key` centred on `at` (RisoPad.key_cap), with its letter, or an arrow up (shift), or
## nothing (the space bar).
func _cap(u: InkCanvas, at: Vector2, s: float, key: Key) -> void:
	var mid: Vector2 = RisoPad.key_cap(u, at, _cap_width(key) * s, CAP_H * s, LIP * s, CAP_ROUND * s)
	if key == KEY_SPACE:
		return
	if key == KEY_SHIFT:
		var a: float = SHIFT_ARROW * s
		var head: PackedVector2Array = PackedVector2Array([mid + Vector2(0, -a), mid + Vector2(a, 0), mid + Vector2(-a, 0)])
		var stem: PackedVector2Array = RisoShapes.rrect(mid.x - a * 0.4, mid.y - 1.0 * s, a * 0.8, a, 1.5 * s)
		u.ink(RisoPrint.NIGHT, 1.0, [head, stem], false)
		return
	_text(key_label(key), mid, LETTER_PX, s)


## A walking arrow at `at`, pointing `dir` (-1 left, 1 right).
func _arrow(u: InkCanvas, at: Vector2, dir: float, s: float) -> void:
	var tip: Vector2 = at + Vector2(dir * ARROW.x * s, 0)
	u.ink(RisoPrint.NIGHT, 1.0, [PackedVector2Array([tip, at + Vector2(0, -ARROW.y * s), at + Vector2(0, ARROW.y * s)])], false)


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


## The key input action `a` is bound to, by its name as the keyboard prints it (key_label).
static func key_of(a: StringName) -> String:
	return key_label(_key(a))


## A key cap's width: wide for the space bar, wider for a key with a long name.
func _cap_width(key: Key) -> float:
	if key == KEY_SPACE:
		return SPACE_W
	if key == KEY_SHIFT:
		return CAP_W * 1.3
	var label: String = key_label(key)
	if label.length() <= 1:
		return CAP_W
	return maxf(CAP_W, RisoTheme.serif().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_PX).x + 20.0)


## What a key cap is printed with: the key's name as the keyboard shows it.
static func key_label(key: Key) -> String:
	return OS.get_keycode_string(key)
