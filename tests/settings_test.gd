extends TestKit
## The settings (Settings) and their page in the menu (menu.gd): a script run keeps the defaults and
## no file; a file of settings keeps what is changed and reads it back; the volumes turn their buses
## down from the bus layout's volumes, 0 silencing; the shake setting scales the camera's shake,
## 0 stilling it; the page opens from the pause menu, left and right step a row, B comes back to the
## list, and the pause button closes the page with the menu.
## godot --headless --path . --script res://tests/settings_test.gd

const FILE: String = "user://settings_test.cfg"


func run() -> void:
	_script_run()
	_file()
	await boot(28)
	await _page()
	await _shake()
	Settings.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	RunState.delete_save()
	finish()


## A script run reads and writes no file of settings, so the player's never reaches a test.
func _script_run() -> void:
	print("a script run")
	Settings.path = ""
	check_eq(Settings.file(), "", "a script run has no file of settings")


## Changes kept in a file and read back; the volumes on the buses.
func _file() -> void:
	print("the file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	Settings.path = FILE
	Settings.load_file()
	check_eq(Settings.values, Settings.DEFAULTS, "with no file, the defaults")
	var music: int = AudioServer.get_bus_index(&"Music")
	check(music >= 0, "a bus for the music")
	Settings.apply()
	var base: float = AudioServer.get_bus_volume_db(music)
	Settings.change(&"music", 4)
	Settings.change(&"shake", 0)
	Settings.change(&"effects", 99)
	check(is_equal_approx(AudioServer.get_bus_volume_db(music), base + linear_to_db(0.4)), "music at 4 of 10 turns its bus down")
	check_eq(Settings.level(&"effects"), Settings.STEPS, "a volume is held to its steps")
	Settings.values = Settings.DEFAULTS.duplicate()
	Settings.load_file()
	check_eq(Settings.level(&"music"), 4, "the music's volume is read back")
	check_eq(Settings.level(&"shake"), 0, "the shake is read back")
	check_eq(Settings.volume_db(0.0, 0), Settings.SILENT_DB, "0 is silent")
	Settings.change(&"music", Settings.STEPS)
	Settings.change(&"shake", Settings.STEPS)
	check(is_equal_approx(AudioServer.get_bus_volume_db(music), base), "back at 10, the bus as it was made")


## The page, from the pause menu.
func _page() -> void:
	print("the page")
	var menu: Menu = main.get_node("Menu") as Menu
	menu.pause_resume_game()
	await frames(2)
	check(menu.visible and menu.settings_button.visible, "the pause menu has Settings")
	menu.settings_button.pressed.emit()
	await frames(2)
	check(menu.settings_page.visible and not menu.list.visible, "Settings opens the page in place of the list")
	var master: Button = menu.steps[&"master"] as Button
	check(master.has_focus(), "the first row in focus")
	await _key(KEY_LEFT)
	await _key(KEY_LEFT)
	check_eq(Settings.level(&"master"), Settings.STEPS - 2, "left steps the volume down")
	check(master.has_focus(), "left keeps the focus on the row")
	check(master.text.contains("8"), "the row shows its step")
	await _key(KEY_RIGHT)
	check_eq(Settings.level(&"master"), Settings.STEPS - 1, "right steps it up")
	await _key(KEY_DOWN)
	check((menu.steps[&"music"] as Button).has_focus(), "down moves to the next row")
	await _key(KEY_ESCAPE)
	check(not menu.settings_page.visible and menu.list.visible and menu.visible, "cancel comes back to the list")
	check(menu.settings_button.has_focus(), "with Settings in focus")
	menu.open_settings()
	menu.fullscreen_button.toggled.emit(true)
	check(bool(Settings.value(&"fullscreen")), "the fullscreen toggle sets it")
	check_eq(menu.fullscreen_button.text, "fullscreen: on", "and says so")
	menu.fullscreen_button.toggled.emit(false)
	menu.pause_resume_game()
	await frames(2)
	check(not menu.visible and not menu.settings_page.visible and menu.list.visible, "unpausing closes the page with the menu")
	Settings.change(&"master", Settings.STEPS)


## The shake setting scales the camera's shake.
func _shake() -> void:
	print("the shake")
	var cam: CameraEffects = Stage.camera()
	Settings.change(&"shake", 0)
	cam.shake(20.0, 0.3)
	await frames(3)
	check(cam.offset == Vector2.ZERO, "at 0 the camera does not shake")
	Settings.change(&"shake", Settings.STEPS)
	cam.shake(20.0, 0.3)
	await frames(3)
	check(cam.offset != Vector2.ZERO, "at 10 it shakes")
	await frames(30)


## Press and let go of `key`.
func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
