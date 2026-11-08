extends TestKit
## The player's controls (Controls) and the controls and credits pages off the settings (menu.gd):
## an action put on a new key or pad button takes it in place of its first of that kind, keeps a
## second the game gives it (the spell's left trigger), and swaps with an action already on it; the
## choice is kept in the settings file and read back; Reset puts every action back; the tutorial's
## cards name the new key (HintArt). On the page, a row chosen waits for the next key, Escape leaves
## it as it was, and B or Escape comes back to the settings page; the credits page lists the
## credits (Credits).
## godot --headless --path . --script res://tests/controls_test.gd

const FILE: String = "user://controls_test.cfg"


func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	Settings.path = FILE
	Settings.load_file()
	_binding()
	_kept()
	await boot(28)
	await _page()
	await _credits()
	Controls.reset()
	Settings.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	Settings.load_file()
	RunState.delete_save()
	finish()


## Putting actions on new keys and buttons, and the swaps.
func _binding() -> void:
	print("binding")
	check_eq(_first_key(&"Jump"), KEY_SPACE, "jump starts on space")
	check(Controls.label(&"Jump").contains("Space") and Controls.label(&"Jump").ends_with("A"), "its row names space and A")
	check(Controls.bind(&"Jump", _press(KEY_K)), "jump put on K")
	check_eq(_first_key(&"Jump"), KEY_K, "jump is on K")
	check_eq(HintArt.key_of(&"Jump"), "K", "the tutorial's cards name K")
	var interact: Key = _first_key(&"Discover")
	Controls.bind(&"Jump", _press(interact))
	check_eq(_first_key(&"Jump"), interact, "jump takes interact's key")
	check_eq(_first_key(&"Discover"), KEY_K, "and interact takes jump's")
	var rb: InputEventJoypadButton = InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	Controls.bind(&"Spell", rb)
	check_eq(Controls.pad_name(_first_pad(&"Spell")), "RB", "the spell is on RB")
	check(_has_pad(&"Spell", "LT"), "and keeps the left trigger")
	check_eq(Controls.pad_name(_first_pad(&"Utility")), "X", "the utility takes X, the spell's button")
	var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.3
	check(not Controls.bind(&"Dash", stick), "a stick barely moved is not taken")
	check_eq(Controls.encode(Controls.decode("a5+")), "a5+", "a trigger written short reads back")
	check(Controls.decode("k") == null and Controls.decode("zz") == null and Controls.decode("ax+") == null, "nonsense reads as nothing")


## Kept in the file, read back, and reset.
func _kept() -> void:
	print("kept")
	var interact: Key = _first_key(&"Jump")
	Controls.load_from(null)
	check_eq(_first_key(&"Jump"), KEY_SPACE, "the game's own controls without the file")
	Settings.load_file()
	check_eq(_first_key(&"Jump"), interact, "the file puts jump back on the key chosen")
	check_eq(Controls.pad_name(_first_pad(&"Spell")), "RB", "and the spell on RB")
	Controls.reset()
	check_eq(_first_key(&"Jump"), KEY_SPACE, "reset puts jump back on space")
	check_eq(Controls.pad_name(_first_pad(&"Spell")), "X", "and the spell on X")
	Settings.load_file()
	check_eq(_first_key(&"Jump"), KEY_SPACE, "and the file keeps it so")


## The controls page, from the pause menu's settings.
func _page() -> void:
	print("the page")
	var menu: Menu = main.get_node("Menu") as Menu
	menu.pause_resume_game()
	await frames(2)
	menu.open_settings()
	await frames(2)
	menu.controls_button.pressed.emit()
	await frames(2)
	check(menu.controls_page.visible and not menu.settings_page.visible, "Controls opens its page")
	var row: Button = menu.control_buttons[&"Jump"] as Button
	check(row.has_focus(), "jump's row in focus")
	await _key(KEY_ENTER)
	check_eq(menu.listening, &"Jump", "chosen, the row waits for a key")
	check(row.text.contains("press"), "and says so")
	await _key(KEY_ESCAPE)
	check(menu.listening == &"" and menu.controls_page.visible, "Escape gives up waiting, on the page")
	check_eq(_first_key(&"Jump"), KEY_SPACE, "and leaves jump as it was")
	await _key(KEY_ENTER)
	await _key(KEY_L)
	check_eq(_first_key(&"Jump"), KEY_L, "the key pressed is jump's")
	check(row.text.contains("L") and row.has_focus(), "its row shows it, in focus")
	var reset: Button = menu.controls_reset
	reset.pressed.emit()
	check_eq(_first_key(&"Jump"), KEY_SPACE, "Reset puts it back")
	await _key(KEY_ESCAPE)
	check(menu.settings_page.visible and not menu.controls_page.visible, "Escape comes back to the settings")
	check(menu.controls_button.has_focus(), "with Controls in focus")


## The credits page.
func _credits() -> void:
	print("the credits")
	var menu: Menu = main.get_node("Menu") as Menu
	menu.credits_button.pressed.emit()
	await frames(2)
	check(menu.credits_page.visible and not menu.settings_page.visible, "Credits opens its page")
	check_eq(menu.credit_lines.get_child_count(), Credits.LINES.size(), "a line for each credit")
	await _key(KEY_ESCAPE)
	check(menu.settings_page.visible and menu.credits_button.has_focus(), "Escape comes back to the settings, Credits in focus")
	menu.pause_resume_game()
	await frames(2)
	check(not menu.visible and menu.list.visible and not menu.settings_page.visible, "unpausing shuts every page")


## The first key `action` is on (by its place on the keyboard).
func _first_key(action: StringName) -> Key:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			return (e as InputEventKey).physical_keycode
	return KEY_NONE


## The pad button, stick or trigger `action` is on, its own (Controls.primary).
func _first_pad(action: StringName) -> InputEvent:
	return Controls.primary(action, true)


## Whether `action` is on the pad's `name` (any of its pad bindings).
func _has_pad(action: StringName, name: String) -> bool:
	for e: InputEvent in InputMap.action_get_events(action):
		if Controls.is_pad(e) and Controls.pad_name(e) == name:
			return true
	return false


## A press of `key`.
func _press(key: Key) -> InputEventKey:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = key
	e.pressed = true
	return e


## Press and let go of `key`.
func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
