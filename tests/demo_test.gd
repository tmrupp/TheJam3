extends TestKit
## A demo build (MapInfo.demo_build, an export with the "demo" feature) has none of the developer's
## tools (MapInfo.dev_tools): no debug toggle on the start menu, no F7 or ` panel, F8 leaves the
## realm as it is, the Debug-Back key goes nowhere, and a debug run saved before plays as an
## ordinary one. Outside a demo build F7 still opens the panel.
## godot --headless --path . --script res://tests/demo_test.gd


func run() -> void:
	MapInfo.demo_build = true
	await boot(28)
	await _keys()
	_save()
	MapInfo.demo_build = false
	await _key(KEY_F7)
	check(RisoPrint.instance.panel.visible, "outside a demo build, F7 opens the panel")
	await _key(KEY_F7)
	MapInfo.demo_build = true
	await _menu()
	RunState.delete_save()
	finish()


## The start menu, come back to from the run (Menu.return_to_menu, which builds the scene afresh).
func _menu() -> void:
	print("the start menu")
	(main.get_node("Menu") as Menu).return_to_menu()
	check(await until(func() -> bool: return root.get_node_or_null("Main") != null and root.get_node("Main") != main), "back at the start menu")
	var menu: Menu = root.get_node("Main/Menu") as Menu
	await frames(2)
	check(menu.visible and not menu.debug_button.visible, "no debug toggle on a demo's start menu")


## The keys that open the developer's tools.
func _keys() -> void:
	print("the keys")
	var art: RisoPrint = RisoPrint.instance
	for key: Key in RisoPrint.PANEL_KEYS:
		await _key(key)
		check(not art.panel.visible, "%s leaves the panel closed" % OS.get_keycode_string(key))
	var realm: StringName = art.realm
	await _key(KEY_F8)
	check_eq(art.realm, realm, "F8 leaves the realm as it is")
	var at: Vector2i = info.coord
	var back: InputEventAction = InputEventAction.new()
	back.action = &"Debug-Back"
	back.pressed = true
	Input.parse_input_event(back)
	await settle()
	back.pressed = false
	Input.parse_input_event(back)
	check(info.coord == at and not info.travelling, "the Debug-Back key goes nowhere")


## A debug run saved (say, before the demo feature was set) comes back as an ordinary one.
func _save() -> void:
	print("a debug run saved")
	MapInfo.debug = true
	info.run.from_save(info.run.to_save(info.coord, player.to_save()))
	check(not MapInfo.debug, "taken up in a demo build, it is an ordinary run")


## Press and let go of `key`.
func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
