class_name Controls
extends RefCounted
## The player's own controls: which key and which pad button each of the game's actions is on,
## changed on the controls page of the settings (menu.gd) and kept with the settings, in their file
## (Settings.file), under a section of their own. Each action has one key and one pad button the
## player chooses (its own, primary: the one the tutorial's cards and the prompts show); a second
## the game gives it (the spell on the left trigger as well as X) stays. Choosing a
## key or button another action is on swaps the two, so no action is left without one. The pause
## button (Escape, Start) is not among them, so the menus can always be reached and left.

## The actions the player may move, in the page's order, each with the name it shows.
const ACTIONS: Dictionary = {
	&"Jump": "jump",
	&"Dash": "dash",
	&"Spell": "spell",
	&"Utility": "utility",
	&"Discover": "interact",
	&"ShowMap": "map",
	&"Left": "left",
	&"Right": "right",
	&"Up": "up",
	&"Down": "down",
}
## The section of the settings file the controls are kept under.
const SECTION: String = "controls"
## How far a stick or trigger must go to be taken as the button chosen.
const AXIS_PRESS: float = 0.6
## The pad's buttons by the names printed on the page (an Xbox pad's; the prompts draw them so).
const PAD_BUTTONS: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
## The pad's sticks and triggers by name, by axis and way (+1 or -1).
const PAD_AXES: Dictionary = {
	Vector2i(JOY_AXIS_LEFT_X, -1): "stick left", Vector2i(JOY_AXIS_LEFT_X, 1): "stick right",
	Vector2i(JOY_AXIS_LEFT_Y, -1): "stick up", Vector2i(JOY_AXIS_LEFT_Y, 1): "stick down",
	Vector2i(JOY_AXIS_RIGHT_X, -1): "right stick left", Vector2i(JOY_AXIS_RIGHT_X, 1): "right stick right",
	Vector2i(JOY_AXIS_RIGHT_Y, -1): "right stick up", Vector2i(JOY_AXIS_RIGHT_Y, 1): "right stick down",
	Vector2i(JOY_AXIS_TRIGGER_LEFT, 1): "LT", Vector2i(JOY_AXIS_TRIGGER_RIGHT, 1): "RT",
}

## Each action's bindings as the game is made, read once before any of the player's are put in.
static var _made: Dictionary = {}


## Put the player's controls (from the settings file, `cfg`) into the input map, from the game's
## own: an action the file does not name keeps the game's.
static func load_from(cfg: ConfigFile) -> void:
	_remember_made()
	for action: StringName in ACTIONS:
		_set_events(action, _made[action] as Array[InputEvent])
		if cfg == null or not cfg.has_section_key(SECTION, String(action)):
			continue
		var events: Array[InputEvent] = []
		for code: Variant in cfg.get_value(SECTION, String(action), []) as Array:
			var e: InputEvent = decode(str(code))
			if e != null:
				events.append(e)
		if not events.is_empty():
			_set_events(action, events)


## Keep the controls in the settings file `cfg` (every action, as it is now).
static func save_to(cfg: ConfigFile) -> void:
	_remember_made()
	for action: StringName in ACTIONS:
		var codes: Array[String] = []
		for e: InputEvent in InputMap.action_get_events(action):
			var code: String = encode(e)
			if code != "":
				codes.append(code)
		cfg.set_value(SECTION, String(action), codes)


## Every action back on the game's own controls, kept so.
static func reset() -> void:
	_remember_made()
	for action: StringName in ACTIONS:
		_set_events(action, _made[action] as Array[InputEvent])
	Settings.save_file()


## Put `action` on `event` (a key, or a pad button, stick or trigger) in place of its own of that
## kind (keyboard or pad, primary), and keep it. Another action already on it takes the one `action` had.
## False if `event` is not one a control can be put on.
static func bind(action: StringName, event: InputEvent) -> bool:
	_remember_made()
	var chosen: InputEvent = plain(event)
	if chosen == null or not ACTIONS.has(action):
		return false
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var had: InputEvent = primary(action, is_pad(chosen))
	if had != null and same(had, chosen):
		return true
	for other: StringName in ACTIONS:
		if other == action:
			continue
		var theirs: Array[InputEvent] = InputMap.action_get_events(other)
		for i: int in range(theirs.size()):
			if same(theirs[i], chosen):
				if had != null:
					theirs[i] = had
				else:
					theirs.remove_at(i)
				_set_events(other, theirs)
				break
	# The chosen first, so it is the action's own (primary); the one it had goes, and so does a
	# second binding that is now the chosen one, so it is not on it twice.
	var kept: Array[InputEvent] = [chosen]
	for e: InputEvent in events:
		if not same(e, chosen) and not (had != null and same(e, had)):
			kept.append(e)
	_set_events(action, kept)
	Settings.save_file()
	return true


## The key (by its name on this keyboard) and the pad button `action` is on, as the page shows them.
static func label(action: StringName) -> String:
	var key: InputEvent = primary(action, false)
	var pad: InputEvent = primary(action, true)
	return "%s  %s · %s" % [ACTIONS.get(action, String(action)), key_name(key as InputEventKey) if key != null else "-", pad_name(pad) if pad != null else "-"]


## The key (`pad` false) or the pad button `action` is on, its own (as the prompts show it,
## RisoPad.part_of): its first key; on the pad its first button, else its first stick or trigger.
## Null when it has none.
static func primary(action: StringName, pad: bool) -> InputEvent:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if not pad:
		for e: InputEvent in events:
			if e is InputEventKey:
				return e
		return null
	for e: InputEvent in events:
		if e is InputEventJoypadButton:
			return e
	for e: InputEvent in events:
		if e is InputEventJoypadMotion:
			return e
	return null


## A key's name as this keyboard prints it.
static func key_name(e: InputEventKey) -> String:
	var key: Key = e.keycode
	if key == KEY_NONE:
		key = e.physical_keycode
		if DisplayServer.get_name() != "headless":
			var local: Key = DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
			if local != KEY_NONE:
				key = local
	return HintArt.key_label(key)


## A pad button's, stick's or trigger's name.
static func pad_name(e: InputEvent) -> String:
	if e is InputEventJoypadButton:
		return PAD_BUTTONS.get((e as InputEventJoypadButton).button_index, "button %d" % (e as InputEventJoypadButton).button_index)
	var m: InputEventJoypadMotion = e as InputEventJoypadMotion
	if m != null:
		return PAD_AXES.get(Vector2i(m.axis, int(signf(m.axis_value))), "axis %d" % m.axis)
	return "-"


## Whether `e` is on the pad.
static func is_pad(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


## `e` as a control is put on it: a key by its place on the keyboard, a button or a stick's way (any
## pad), or null for a press that is not one (a key let go, a stick barely moved, the mouse).
static func plain(e: InputEvent) -> InputEvent:
	if e is InputEventKey:
		var k: InputEventKey = e as InputEventKey
		if not k.pressed or k.echo:
			return null
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return key
	if e is InputEventJoypadButton:
		if not (e as InputEventJoypadButton).pressed:
			return null
		var b: InputEventJoypadButton = InputEventJoypadButton.new()
		b.button_index = (e as InputEventJoypadButton).button_index
		b.device = -1
		return b
	if e is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = e as InputEventJoypadMotion
		if absf(m.axis_value) < AXIS_PRESS:
			return null
		var a: InputEventJoypadMotion = InputEventJoypadMotion.new()
		a.axis = m.axis
		a.axis_value = signf(m.axis_value)
		a.device = -1
		return a
	return null


## Whether `a` and `b` are the same key, button, or stick's way.
static func same(a: InputEvent, b: InputEvent) -> bool:
	return encode(a) != "" and encode(a) == encode(b)


## `e` written short for the settings file: "k" and a key's place, "b" and a button, "a" an axis
## and its way; "" for anything else.
static func encode(e: InputEvent) -> String:
	if e is InputEventKey:
		var k: InputEventKey = e as InputEventKey
		return "k%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if e is InputEventJoypadButton:
		return "b%d" % (e as InputEventJoypadButton).button_index
	if e is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = e as InputEventJoypadMotion
		return "a%d%s" % [m.axis, "+" if m.axis_value > 0.0 else "-"]
	return ""


## A binding read back from the file (encode's), or null for one that cannot be read.
static func decode(code: String) -> InputEvent:
	if code.length() < 2:
		return null
	var rest: String = code.substr(1)
	match code[0]:
		"k":
			if not rest.is_valid_int():
				return null
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = int(rest) as Key
			return key
		"b":
			if not rest.is_valid_int():
				return null
			var b: InputEventJoypadButton = InputEventJoypadButton.new()
			b.button_index = int(rest) as JoyButton
			b.device = -1
			return b
		"a":
			var way: String = rest.right(1)
			var axis: String = rest.left(rest.length() - 1)
			if not axis.is_valid_int() or not (way == "+" or way == "-"):
				return null
			var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
			m.axis = int(axis) as JoyAxis
			m.axis_value = 1.0 if way == "+" else -1.0
			m.device = -1
			return m
	return null


## Note each action's bindings as the game makes them, once, before the player's change them.
static func _remember_made() -> void:
	if not _made.is_empty():
		return
	Abilities.ensure_input()
	for action: StringName in ACTIONS:
		var events: Array[InputEvent] = []
		for e: InputEvent in InputMap.action_get_events(action):
			events.append(e.duplicate() as InputEvent)
		_made[action] = events


## Put `action` on exactly `events`.
static func _set_events(action: StringName, events: Array[InputEvent]) -> void:
	InputMap.action_erase_events(action)
	for e: InputEvent in events:
		InputMap.action_add_event(action, e)
