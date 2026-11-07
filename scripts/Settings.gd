class_name Settings
extends RefCounted
## The player's settings, kept apart from any run: how loud the game, its music and its sound
## effects are, whether it fills the screen, and how hard the screen shakes. Chosen on the settings
## page of the menu (menu.gd), kept in a file of their own (`user://settings.cfg`) and put into
## effect as the game starts (ensure_loaded) and again on every change. Tests and captures never
## read or write the player's file: run as a script, the game keeps the defaults unless a test
## names a file of its own (path).

## The steps of a volume or of the shake: 0 (silent, still) to STEPS (as the game is made).
const STEPS: int = 10
## Each setting and its value when nothing is saved: every volume and the shake at full, windowed.
const DEFAULTS: Dictionary = {
	&"master": STEPS,
	&"music": STEPS,
	&"effects": STEPS,
	&"shake": STEPS,
	&"fullscreen": false,
}
## The audio bus each volume turns down: the whole game, the music, the sound effects.
const BUSES: Dictionary = {&"master": &"Master", &"music": &"Music", &"effects": &"SoundEffects"}
## Below this a bus is as good as silent (dB), used for a volume of 0.
const SILENT_DB: float = -80.0
## The player's own file of settings.
const PLAYER_FILE: String = "user://settings.cfg"
## The section of the file the settings are kept under.
const SECTION: String = "settings"

## The file the settings are read from and kept in. Left empty it is the player's own file in the
## game itself and none at all in a script run (a test or a capture); a test of the settings names
## one of its own.
static var path: String = ""
## The settings now (a value for every key of DEFAULTS).
static var values: Dictionary = DEFAULTS.duplicate()
## Whether the settings have been read and put into effect since the game started.
static var loaded: bool = false
## Each bus's volume as the game is made (dB, the bus layout's), read once, which the volumes turn
## down from.
static var _base_db: Dictionary = {}


## The file in use (path, else the player's file in the game and none in a script run).
static func file() -> String:
	if path != "":
		return path
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.get_script() != null:
		return ""
	return PLAYER_FILE


## Read the settings and put them into effect, once a game.
static func ensure_loaded() -> void:
	if loaded:
		return
	load_file()
	apply()


## Read the settings from the file (the defaults for any missing, or with no file).
static func load_file() -> void:
	loaded = true
	values = DEFAULTS.duplicate()
	var f: String = file()
	if f == "":
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(f) != OK:
		return
	for key: StringName in DEFAULTS:
		var v: Variant = cfg.get_value(SECTION, String(key), DEFAULTS[key])
		if typeof(v) == typeof(DEFAULTS[key]):
			values[key] = v
	for key: StringName in BUSES:
		values[key] = clampi(int(values[key]), 0, STEPS)
	values[&"shake"] = clampi(int(values[&"shake"]), 0, STEPS)


## Keep the settings in the file (nothing without one), leaving the rest of it as it was (the
## player's file also keeps whether they have been through the tutorial, Tutorial.done).
static func save_file() -> void:
	var f: String = file()
	if f == "":
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(f)
	for key: StringName in DEFAULTS:
		cfg.set_value(SECTION, String(key), values[key])
	cfg.save(f)


## A setting's value now.
static func value(key: StringName) -> Variant:
	return values.get(key, DEFAULTS[key])


## A volume or the shake now, 0 to STEPS.
static func level(key: StringName) -> int:
	return int(value(key))


## Change setting `key` to `v` (a volume or the shake held to 0..STEPS), put it into effect and
## keep it.
static func change(key: StringName, v: Variant) -> void:
	if not loaded:
		load_file()
	if key == &"fullscreen":
		values[key] = bool(v)
	else:
		values[key] = clampi(int(v), 0, STEPS)
	apply()
	save_file()


## Put every setting into effect: the buses' volumes and the window.
static func apply() -> void:
	for key: StringName in BUSES:
		var bus: int = AudioServer.get_bus_index(BUSES[key])
		if bus < 0:
			continue
		if not _base_db.has(key):
			_base_db[key] = AudioServer.get_bus_volume_db(bus)
		AudioServer.set_bus_volume_db(bus, volume_db(float(_base_db[key]), level(key)))
	_apply_window()


## A bus's volume (dB) at `steps` of STEPS, from its volume as made, `base`.
static func volume_db(base: float, steps: int) -> float:
	if steps <= 0:
		return SILENT_DB
	return maxf(base + linear_to_db(float(steps) / float(STEPS)), SILENT_DB)


## How much of a shake to give (0 none, 1 all of it).
static func shake() -> float:
	return float(level(&"shake")) / float(STEPS)


## Fill the screen, or come back to a window (maximized, as the game opens) from filling it. A
## window is left as it is in a script run with no file of settings, and under a headless display.
static func _apply_window() -> void:
	if file() == "" or DisplayServer.get_name() == "headless":
		return
	var full: bool = bool(value(&"fullscreen"))
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_full: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not full and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
