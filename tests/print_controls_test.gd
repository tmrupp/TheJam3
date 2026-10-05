extends SceneTree
## Real controller events change F7 choices/sliders and move between controls.
## godot --headless --path . --script res://tests/print_controls_test.gd

var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func frames(count: int = 3) -> void:
	for i: int in range(count):
		await process_frame


func button(which: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = which
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()


func stick(direction: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = direction
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.axis_value = 0.0
	Input.parse_input_event(event)
	await frames()


func f7() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F7
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()


func run() -> void:
	MapInfo.save_path = "user://print_controls_test.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	var menu: Node = main.get_node("Menu")
	menu.set_debug(true)
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = MapInfo.instance
	while info.world == null or info.travelling:
		await process_frame
	await frames(4)
	var riso: RisoPrint = RisoPrint.instance
	await f7()
	var focus: Control = root.gui_get_focus_owner()
	check(riso.panel.visible and focus != null and riso.panel.is_ancestor_of(focus), "F7 focuses its controls for controller navigation")
	await f7()
	await button(JOY_BUTTON_BACK)
	check(riso.panel.visible and paused, "Back opens and pauses the panel")
	focus = root.gui_get_focus_owner()
	await button(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner() != focus and root.gui_get_focus_owner().get_parent() == focus.get_parent(),
		"D-pad right moves between the travel row buttons")
	await button(JOY_BUTTON_DPAD_LEFT)
	check(root.gui_get_focus_owner() == focus, "D-pad left returns to the previous travel button")

	var fog: OptionButton = riso._options[&"fog"]
	fog.grab_focus()
	await frames()
	var selected: int = fog.selected
	await button(JOY_BUTTON_DPAD_RIGHT)
	check(fog.selected == selected + 1 and riso.fog_style == RisoPrint.FOG_STYLES[fog.selected],
		"D-pad right changes the focused fog choice and renderer")
	check(root.gui_get_focus_owner() == fog, "changing an option keeps its focus")
	await button(JOY_BUTTON_DPAD_LEFT)
	check(fog.selected == selected, "D-pad left changes the choice back")
	await stick(1.0)
	check(fog.selected == selected + 1, "left stick right changes a choice")
	await stick(-1.0)
	check(fog.selected == selected, "left stick left changes it back")
	fog.select(0)
	fog.item_selected.emit(0)
	await button(JOY_BUTTON_DPAD_LEFT)
	check(fog.selected == fog.item_count - 1, "choices wrap left from the first option")
	await button(JOY_BUTTON_DPAD_RIGHT)
	check(fog.selected == 0, "choices wrap right from the last option")
	await button(JOY_BUTTON_DPAD_UP)
	check(root.gui_get_focus_owner() != fog, "up still moves to another row")
	await button(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == fog, "down returns to the fog row")

	var specks: HSlider = riso._specks_label.get_parent().get_child(1)
	specks.grab_focus()
	await frames()
	var before: float = riso.specks
	await button(JOY_BUTTON_DPAD_RIGHT)
	check(is_equal_approx(riso.specks, before + specks.step), "D-pad right increases a slider")
	await stick(-1.0)
	check(is_equal_approx(riso.specks, before), "left stick left decreases a slider")
	await button(JOY_BUTTON_B)
	check(not riso.panel.visible and not paused, "B closes the panel and resumes play")
	MapInfo.debug = false
	await f7()
	focus = root.gui_get_focus_owner()
	check(focus is HSlider and riso.panel.is_ancestor_of(focus), "outside debug runs F7 starts on a setting rather than hidden travel controls")
	await button(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() is HSlider and root.gui_get_focus_owner() != focus,
		"controller row navigation also works outside debug runs")
	await f7()
	check(not riso.panel.visible and not paused, "F7 closes its pause cleanly")

	MapInfo.delete_save()
	print("FAILED" if failed else "PASS: print controls")
	quit(1 if failed else 0)
