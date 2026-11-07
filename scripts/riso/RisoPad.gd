class_name RisoPad
extends RefCounted
## The pad as the game prints it wherever a control is shown on one (the tutorial's cards, HintArt;
## the interact prompt, RisoPrompt): always the same pad seen from the front, so a player learns
## where each button is on it. Its body is faint, with grips under its ends; on it, faint, the left
## stick, the d-pad, back and start, the right stick and the four face buttons; on top, either side,
## a bumper, a strip lying along the body's top, and standing clear over it a trigger as wide, a
## tab rounded at its top corners, so the two cannot be taken for each other. The control asked for is solid in night:
## a button or a shoulder, or the stick (walking, with an arrow either way); a shoulder gets a broad
## arrow at it from the pad's side too, as it is the hardest part to see. Pressed (`press`), the control sinks a little and
## a ring of accent ink spreads from it. No words.
## Which device the player last used is kept here too (pad, note_device), for whatever shows one.

## The parts of the pad a control can be on.
enum Part { FACE_DOWN, FACE_RIGHT, FACE_LEFT, FACE_UP, BACK, START, LEFT_STICK, RIGHT_STICK, LEFT_BUMPER, RIGHT_BUMPER, LEFT_TRIGGER, RIGHT_TRIGGER, NONE }

## The pad's body, the radius of the grips under its two ends, and the rounding of its corners
## (as a share of its height).
const BODY: Vector2 = Vector2(128, 74)
const GRIP_R: float = 20.0
const BODY_ROUND: float = 0.35
## A trigger's size (a tab, as wide as its bumper) and a bumper's (a strip), how far in from the body's
## ends their middles sit, the paper left between a trigger and its bumper (a clear gap, so a
## trigger stands apart), and the hairline between a bumper and the body (so it lies along the body
## without melting into it). The room they take over the body is the same as before they were told
## apart, so the pad keeps its size on a card.
const TRIGGER: Vector2 = Vector2(30, 14)
const BUMPER: Vector2 = Vector2(30, 6)
const SHOULDER_IN: float = 30.0
const TRIGGER_GAP: float = 4.0
const BUMPER_GAP: float = 2.0
## How round a trigger's top corners are and a bumper's corners (px, unscaled).
const TRIGGER_ROUND: float = 6.0
const BUMPER_ROUND: float = 2.0
## Where the body's controls sit, from the middle of its top edge (unscaled px): the left stick and
## the face buttons up high, the d-pad and the right stick lower and further in, back and start
## between them at the top.
const LEFT_STICK_AT: Vector2 = Vector2(-37, 28)
const FACE_AT: Vector2 = Vector2(36, 28)
const DPAD_AT: Vector2 = Vector2(-16, 55)
const RIGHT_STICK_AT: Vector2 = Vector2(16, 55)
const MIDDLE_AT: Vector2 = Vector2(10, 17)
## A stick's well and cap; a face button's radius and how far each sits from their middle; the
## d-pad's arm length and width; back and start's size.
const STICK_WELL: float = 12.0
const STICK_CAP: float = 7.0
const FACE_R: float = 8.5
const FACE_OFF: float = 16.0
const DPAD: Vector2 = Vector2(9, 5)
const MIDDLE: Vector2 = Vector2(10, 5)
## The arrow pointing in at a shoulder asked for from the pad's side: its half height and length,
## and the gap between its tip and the shoulder; and the walking arrows either side of the stick:
## their length and half height, and the gap from the well.
const POINT: Vector2 = Vector2(10, 12)
const POINT_GAP: float = 3.0
const WALK: Vector2 = Vector2(9, 7)
const WALK_GAP: float = 4.0
## What the faint parts are printed at: the body (in the blue plate) and its controls (in night).
const BODY_INK: float = 0.6
const CONTROL_INK: float = 0.32
## How far (px, unscaled) a pressed control sinks, and the press's ring at most.
const SINK: float = 1.5
const RING: float = 14.0
## The control asked for stands out: a button or a stick's cap that much bigger than the rest, and
## a ring of bare paper this wide (px, unscaled) round it.
const LIT_GROW: float = 1.3
const HALO: float = 2.5

## Whether the player last used a pad rather than the keyboard (note_device).
static var pad: bool = not Input.get_connected_joypads().is_empty()
## How far a pad's stick must lean to count as using the pad.
const STICK_LEAN: float = 0.5


## Note which device `event` came from (pad).
static func note_device(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > STICK_LEAN:
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false


## The pad's size, unscaled: the shoulders over the body, and the grips under it.
static func size() -> Vector2:
	return Vector2(BODY.x, _over() + BODY.y + GRIP_R * 0.8)


## The room over the body (unscaled): a trigger and a bumper.
static func _over() -> float:
	return TRIGGER.y + TRIGGER_GAP + BUMPER.y + BUMPER_GAP


## The part of the pad input action `action` is on (&"Move" is walking, the left stick): its first
## pad button, else its first pad axis; NONE when it has neither, or one the pad here does not show.
## Every part of the pad input action `action` is on, its first (part_of) first: the spell is on a
## face button and the left trigger alike, and the whole pad (draw) lights both.
static func parts_of(action: StringName) -> Array[Part]:
	var out: Array[Part] = []
	var first: Part = part_of(action)
	if first == Part.NONE:
		return out
	out.append(first)
	if action == &"Move" or not InputMap.has_action(action):
		return out
	for e: InputEvent in InputMap.action_get_events(action):
		var part: Part = Part.NONE
		var b: InputEventJoypadButton = e as InputEventJoypadButton
		var m: InputEventJoypadMotion = e as InputEventJoypadMotion
		if b != null:
			part = _button_part(b.button_index)
		elif m != null:
			match m.axis:
				JOY_AXIS_TRIGGER_LEFT: part = Part.LEFT_TRIGGER
				JOY_AXIS_TRIGGER_RIGHT: part = Part.RIGHT_TRIGGER
		if part != Part.NONE and not out.has(part):
			out.append(part)
	return out


## The part of the pad a button is (NONE for one the pad does not show).
static func _button_part(button: int) -> Part:
	match button:
		JOY_BUTTON_A: return Part.FACE_DOWN
		JOY_BUTTON_B: return Part.FACE_RIGHT
		JOY_BUTTON_X: return Part.FACE_LEFT
		JOY_BUTTON_Y: return Part.FACE_UP
		JOY_BUTTON_BACK: return Part.BACK
		JOY_BUTTON_START: return Part.START
		JOY_BUTTON_LEFT_STICK: return Part.LEFT_STICK
		JOY_BUTTON_RIGHT_STICK: return Part.RIGHT_STICK
		JOY_BUTTON_LEFT_SHOULDER: return Part.LEFT_BUMPER
		JOY_BUTTON_RIGHT_SHOULDER: return Part.RIGHT_BUMPER
	return Part.NONE


static func part_of(action: StringName) -> Part:
	if action == &"Move":
		return Part.LEFT_STICK
	if not InputMap.has_action(action):
		return Part.NONE
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for e: InputEvent in events:
		var b: InputEventJoypadButton = e as InputEventJoypadButton
		if b == null:
			continue
		match b.button_index:
			JOY_BUTTON_A: return Part.FACE_DOWN
			JOY_BUTTON_B: return Part.FACE_RIGHT
			JOY_BUTTON_X: return Part.FACE_LEFT
			JOY_BUTTON_Y: return Part.FACE_UP
			JOY_BUTTON_BACK: return Part.BACK
			JOY_BUTTON_START: return Part.START
			JOY_BUTTON_LEFT_STICK: return Part.LEFT_STICK
			JOY_BUTTON_RIGHT_STICK: return Part.RIGHT_STICK
			JOY_BUTTON_LEFT_SHOULDER: return Part.LEFT_BUMPER
			JOY_BUTTON_RIGHT_SHOULDER: return Part.RIGHT_BUMPER
	for e: InputEvent in events:
		var m: InputEventJoypadMotion = e as InputEventJoypadMotion
		if m == null:
			continue
		match m.axis:
			JOY_AXIS_TRIGGER_LEFT: return Part.LEFT_TRIGGER
			JOY_AXIS_TRIGGER_RIGHT: return Part.RIGHT_TRIGGER
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return Part.LEFT_STICK
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return Part.RIGHT_STICK
	return Part.NONE


## Print the pad on `ink`, centred on `at`, `s` its scale, with every part `action` is on solid
## (parts_of; walking's stick with arrows either way), pressed by `press` (0 up .. 1 down; its ring
## spreads from each as it lands). Returns where its first part's middle is.
static func draw(ink: InkCanvas, at: Vector2, s: float, action: StringName, press: float = 0.0) -> Vector2:
	var lits: Array[Part] = parts_of(action)
	var lit: Part = lits[0] if not lits.is_empty() else Part.NONE
	var rings: Array[Vector2] = []
	var top: float = at.y - size().y * 0.5 * s
	var body_top: float = top + _over() * s
	var origin: Vector2 = Vector2(at.x, body_top)
	var sink: Vector2 = Vector2(0, SINK * press * s)
	# The body and its grips.
	var body: Vector2 = BODY * s
	var grip: float = GRIP_R * s
	var shell: Array[PackedVector2Array] = [RisoShapes.rrect(at.x - body.x * 0.5, body_top, body.x, body.y, body.y * BODY_ROUND)]
	for side: float in [-1.0, 1.0]:
		shell.append(RisoShapes.circle(Vector2(at.x + side * (body.x * 0.5 - grip), body_top + body.y - grip * 0.2), grip, 20))
	ink.ink(RisoPrint.BLUE, BODY_INK, shell, false)
	var faint: Array[PackedVector2Array] = []
	var solid: Array[PackedVector2Array] = []
	var pointers: Array[PackedVector2Array] = []
	var lit_at: Vector2 = at
	# The shoulders: on each side a trigger standing clear over a bumper flat on the body.
	var trigger_top: float = top
	var bumper_top: float = trigger_top + (TRIGGER.y + TRIGGER_GAP) * s
	for side: float in [-1.0, 1.0]:
		var x: float = at.x + side * (BODY.x * 0.5 - SHOULDER_IN) * s
		var right: bool = side > 0.0
		var trig_part: Part = Part.RIGHT_TRIGGER if right else Part.LEFT_TRIGGER
		var bump_part: Part = Part.RIGHT_BUMPER if right else Part.LEFT_BUMPER
		for pair: Array in [[trig_part, TRIGGER, trigger_top], [bump_part, BUMPER, bumper_top]]:
			var part: Part = pair[0]
			var size_of: Vector2 = (pair[1] as Vector2) * s
			var y: float = float(pair[2])
			var shape: PackedVector2Array = RisoPad.tab(x - size_of.x * 0.5, y, size_of.x, size_of.y, TRIGGER_ROUND * s) if part == trig_part else RisoShapes.rrect(x - size_of.x * 0.5, y, size_of.x, size_of.y, BUMPER_ROUND * s)
			if lits.has(part):
				solid.append(Transform2D(0.0, sink) * shape)
				rings.append(Vector2(x, y + size_of.y * 0.5))
				if part == lit:
					lit_at = Vector2(x, y + size_of.y * 0.5)
				# From the pad's side, pointing in at it.
				var tip: Vector2 = Vector2(x + side * (size_of.x * 0.5 + POINT_GAP * s), y + size_of.y * 0.5)
				pointers.append(PackedVector2Array([tip, tip + Vector2(side * POINT.y * s, -POINT.x * s), tip + Vector2(side * POINT.y * s, POINT.x * s)]))
			else:
				ink.ink(RisoPrint.BLUE, BODY_INK, [shape], false)
	# The sticks: a well and a cap each.
	for pair: Array in [[Part.LEFT_STICK, LEFT_STICK_AT], [Part.RIGHT_STICK, RIGHT_STICK_AT]]:
		var c: Vector2 = origin + (pair[1] as Vector2) * s
		if lits.has(pair[0]):
			faint.append(RisoShapes.circle(c, STICK_WELL * s, 18))
			solid.append(RisoShapes.circle(c + sink, STICK_CAP * LIT_GROW * s, 14))
			rings.append(c)
			if pair[0] == lit:
				lit_at = c
			if action == &"Move":
				for dir: float in [-1.0, 1.0]:
					var base: Vector2 = c + Vector2(dir * (STICK_WELL + WALK_GAP) * s, 0)
					pointers.append(PackedVector2Array([base + Vector2(dir * WALK.x * s, 0), base + Vector2(0, -WALK.y * s), base + Vector2(0, WALK.y * s)]))
		else:
			faint.append(RisoShapes.circle(c, STICK_WELL * s, 18))
	# The d-pad, a cross; back and start, two small bars at the top.
	var d: Vector2 = origin + DPAD_AT * s
	faint.append(RisoShapes.rrect(d.x - DPAD.x * s, d.y - DPAD.y * 0.5 * s, DPAD.x * 2.0 * s, DPAD.y * s, 1.0 * s))
	faint.append(RisoShapes.rrect(d.x - DPAD.y * 0.5 * s, d.y - DPAD.x * s, DPAD.y * s, DPAD.x * 2.0 * s, 1.0 * s))
	for pair: Array in [[Part.BACK, -1.0], [Part.START, 1.0]]:
		var c: Vector2 = origin + Vector2(float(pair[1]) * MIDDLE_AT.x, MIDDLE_AT.y) * s
		var bar: PackedVector2Array = RisoShapes.rrect(c.x - MIDDLE.x * 0.5 * s, c.y - MIDDLE.y * 0.5 * s, MIDDLE.x * s, MIDDLE.y * s, MIDDLE.y * 0.5 * s)
		if lits.has(pair[0]):
			solid.append(Transform2D(0.0, sink) * bar)
			rings.append(c)
			if pair[0] == lit:
				lit_at = c
		else:
			faint.append(bar)
	# The face buttons: down, right, left, up round their middle.
	var face: Vector2 = origin + FACE_AT * s
	var spots: Array[Array] = [[Part.FACE_DOWN, Vector2(0, 1)], [Part.FACE_RIGHT, Vector2(1, 0)], [Part.FACE_LEFT, Vector2(-1, 0)], [Part.FACE_UP, Vector2(0, -1)]]
	for pair: Array in spots:
		var c: Vector2 = face + (pair[1] as Vector2) * FACE_OFF * s
		if lits.has(pair[0]):
			solid.append(RisoShapes.circle(c + sink, FACE_R * LIT_GROW * s, 14))
			rings.append(c)
			if pair[0] == lit:
				lit_at = c
		else:
			faint.append(RisoShapes.circle(c, FACE_R * s, 14))
	ink.ink(RisoPrint.NIGHT, CONTROL_INK, faint, false)
	# A ring of bare paper round the control asked for, so it stands out of the faint pad.
	var halos: Array[PackedVector2Array] = []
	for shape: PackedVector2Array in solid:
		halos.append_array(Geometry2D.offset_polygon(shape, HALO * s))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], halos)
	ink.ink(RisoPrint.NIGHT, 1.0, solid + pointers, false)
	for c: Vector2 in rings:
		ring(ink, c + sink, s, press)
	return lit_at


## The size (unscaled) of the small pad for input action `action` (draw_small): only the part of
## the pad it is on.
static func small_size(action: StringName) -> Vector2:
	match part_of(action):
		Part.FACE_DOWN, Part.FACE_RIGHT, Part.FACE_LEFT, Part.FACE_UP:
			return Vector2.ONE * (FACE_OFF + FACE_R * LIT_GROW) * 2.0
		Part.LEFT_TRIGGER, Part.RIGHT_TRIGGER, Part.LEFT_BUMPER, Part.RIGHT_BUMPER:
			return Vector2(BUMPER.x, TRIGGER.y + TRIGGER_GAP + BUMPER.y)
		Part.LEFT_STICK, Part.RIGHT_STICK:
			var arrows: float = (WALK_GAP + WALK.x) * 2.0 if action == &"Move" else 0.0
			return Vector2(STICK_WELL * 2.0 + arrows, STICK_WELL * 2.0)
		Part.BACK, Part.START:
			return Vector2(MIDDLE_AT.x * 2.0 + MIDDLE.x * LIT_GROW, MIDDLE.y * LIT_GROW)
	return Vector2.ZERO


## The small pad, for a control shown outside the tutorial (the interact prompt, RisoPrompt): only
## the part of the pad `action` is on, as the player sees it there, centred on `at`, `s` its scale:
## the four face buttons as a diamond, the one asked for solid; a shoulder as the trigger and bumper
## of its side, the one asked for solid; a stick alone, its cap solid (walking, with an arrow either
## way); back and start side by side. Pressed by `press` as the whole pad is (draw). The tutorial's
## cards keep the whole pad, so the parts are learned there. Returns where the part's middle is.
static func draw_small(ink: InkCanvas, at: Vector2, s: float, action: StringName, press: float = 0.0) -> Vector2:
	var lit: Part = part_of(action)
	var sink: Vector2 = Vector2(0, SINK * press * s)
	var faint: Array[PackedVector2Array] = []
	var shell: Array[PackedVector2Array] = []
	var solid: Array[PackedVector2Array] = []
	var pointers: Array[PackedVector2Array] = []
	var lit_at: Vector2 = at
	match lit:
		Part.FACE_DOWN, Part.FACE_RIGHT, Part.FACE_LEFT, Part.FACE_UP:
			var spots: Array[Array] = [[Part.FACE_DOWN, Vector2(0, 1)], [Part.FACE_RIGHT, Vector2(1, 0)], [Part.FACE_LEFT, Vector2(-1, 0)], [Part.FACE_UP, Vector2(0, -1)]]
			for pair: Array in spots:
				var c: Vector2 = at + (pair[1] as Vector2) * FACE_OFF * s
				if pair[0] == lit:
					solid.append(RisoShapes.circle(c + sink, FACE_R * LIT_GROW * s, 14))
					lit_at = c
				else:
					faint.append(RisoShapes.circle(c, FACE_R * s, 14))
		Part.LEFT_TRIGGER, Part.RIGHT_TRIGGER, Part.LEFT_BUMPER, Part.RIGHT_BUMPER:
			var trigger_lit: bool = lit == Part.LEFT_TRIGGER or lit == Part.RIGHT_TRIGGER
			var top: float = at.y - (TRIGGER.y + TRIGGER_GAP + BUMPER.y) * 0.5 * s
			var trigger: PackedVector2Array = RisoPad.tab(at.x - TRIGGER.x * 0.5 * s, top, TRIGGER.x * s, TRIGGER.y * s, TRIGGER_ROUND * s)
			var bumper_top: float = top + (TRIGGER.y + TRIGGER_GAP) * s
			var bumper: PackedVector2Array = RisoShapes.rrect(at.x - BUMPER.x * 0.5 * s, bumper_top, BUMPER.x * s, BUMPER.y * s, BUMPER_ROUND * s)
			solid.append(Transform2D(0.0, sink) * (trigger if trigger_lit else bumper))
			shell.append(bumper if trigger_lit else trigger)
			lit_at = Vector2(at.x, top + TRIGGER.y * 0.5 * s) if trigger_lit else Vector2(at.x, bumper_top + BUMPER.y * 0.5 * s)
		Part.LEFT_STICK, Part.RIGHT_STICK:
			faint.append(RisoShapes.circle(at, STICK_WELL * s, 18))
			solid.append(RisoShapes.circle(at + sink, STICK_CAP * LIT_GROW * s, 14))
			if action == &"Move":
				for dir: float in [-1.0, 1.0]:
					var base: Vector2 = at + Vector2(dir * (STICK_WELL + WALK_GAP) * s, 0)
					pointers.append(PackedVector2Array([base + Vector2(dir * WALK.x * s, 0), base + Vector2(0, -WALK.y * s), base + Vector2(0, WALK.y * s)]))
		Part.BACK, Part.START:
			for pair: Array in [[Part.BACK, -1.0], [Part.START, 1.0]]:
				var c: Vector2 = at + Vector2(float(pair[1]) * MIDDLE_AT.x * s, 0)
				var grow: float = LIT_GROW if pair[0] == lit else 1.0
				var bar: PackedVector2Array = RisoShapes.rrect(c.x - MIDDLE.x * 0.5 * grow * s, c.y - MIDDLE.y * 0.5 * grow * s, MIDDLE.x * grow * s, MIDDLE.y * grow * s, MIDDLE.y * 0.5 * grow * s)
				if pair[0] == lit:
					solid.append(Transform2D(0.0, sink) * bar)
					lit_at = c
				else:
					faint.append(bar)
		_:
			return at
	if not shell.is_empty():
		ink.ink(RisoPrint.BLUE, BODY_INK, shell, false)
	if not faint.is_empty():
		ink.ink(RisoPrint.NIGHT, CONTROL_INK, faint, false)
	ink.ink(RisoPrint.NIGHT, 1.0, solid + pointers, false)
	ring(ink, lit_at + sink, s, press)
	return lit_at


## A trigger's tab: `w` across and `h` high from (`x`, `y`), its top corners rounded `r`, its foot
## square.
static func tab(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([Vector2(x, y + h)])
	for k: int in range(7):
		var a: float = PI + PI * 0.5 * float(k) / 6.0
		out.append(Vector2(x + r, y + r) + Vector2(cos(a), sin(a)) * r)
	for k: int in range(7):
		var a: float = PI * 1.5 + PI * 0.5 * float(k) / 6.0
		out.append(Vector2(x + w - r, y + r) + Vector2(cos(a), sin(a)) * r)
	out.append(Vector2(x + w, y + h))
	return out


## The ring of accent ink a press spreads from `at` as it lands (`press` past 0.6), `s` its scale.
static func ring(ink: InkCanvas, at: Vector2, s: float, press: float) -> void:
	var landed: float = clampf((press - 0.6) / 0.4, 0.0, 1.0)
	if landed <= 0.0:
		return
	var r: float = (3.0 + RING * landed) * s
	ink.ink(RisoPrint.ACCENT, 1.0 - landed * 0.6, [RisoShapes.ellipse(at, r, r * 0.6, 20)], false)
	ink.knock([RisoPrint.ACCENT], [RisoShapes.ellipse(at, r * 0.7, r * 0.42, 20)])


## A key cap's shape centred on `at`, `w` across and `h` high, printed on `ink`: paper, tinted, with
## a darker lip along its foot (`lip` px high), its corners rounded `corner`; its letter is the
## caller's. Returns where the letter's middle goes.
static func key_cap(ink: InkCanvas, at: Vector2, w: float, h: float, lip: float, corner: float) -> Vector2:
	var face: PackedVector2Array = RisoShapes.rrect(at.x - w * 0.5, at.y - h * 0.5, w, h, corner)
	ink.ink(RisoPrint.NIGHT, CAP_LIP, [face], false)
	var top: PackedVector2Array = RisoShapes.rrect(at.x - w * 0.5, at.y - h * 0.5, w, h - lip, corner)
	ink.knock([RisoPrint.NIGHT], [top])
	ink.ink(RisoPrint.BLUE, CAP_FACE, [top], false)
	return at - Vector2(0, lip * 0.5)


## A key cap's face and its lip (in night).
const CAP_FACE: float = 0.4
const CAP_LIP: float = 0.55
