extends TestKit
## The debug panel (RisoPrint's F7 panel) and its cheats, in debug runs. The panel opens and closes
## on F7 and on the key left of 1 (backquote), and from the pause menu's Debug panel button, which
## only debug runs show. Its Cheats section: Invincible keeps every heart (a blow, a fall), and only
## in a debug run; Empowered makes any spell cast empowered on a held press, again and again, with
## no lodestone and no wait; Darkness sets the charges of darkness carried, never below none.
## godot --headless --path . --script res://tests/debug_cheats_test.gd

## Every hex bolt added to the level from now on.
var bolts: Array[HexBolt] = []


func run() -> void:
	await boot(28)
	MapInfo.debug = true
	var riso: RisoPrint = RisoPrint.instance
	await _keys(riso)
	await _pause_menu(riso)
	await _invincible(riso)
	await _empowered(riso)
	await _darkness(riso)
	Health.invincible = false
	Empower.always = false
	MapInfo.debug = false
	RunState.delete_save()
	finish()


## Press and let go of a key, by its physical place (as a player's keyboard sends it) or its code.
func _key(code: Key, physical: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	if physical:
		event.physical_keycode = code
	else:
		event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func _keys(riso: RisoPrint) -> void:
	print("keys")
	await _key(KEY_QUOTELEFT, true)
	check(riso.panel.visible and paused, "the key left of 1 opens the panel and pauses")
	check(riso.section_open("Cheats (debug)") and (riso._options[&"invincible"] as Control).is_visible_in_tree(), "the cheats start open in a debug run")
	await _key(KEY_QUOTELEFT, true)
	check(not riso.panel.visible and not paused, "and closes it again")
	await _key(KEY_F7, false)
	check(riso.panel.visible, "F7 still opens it")
	await _key(KEY_F7, false)
	check(not riso.panel.visible and not paused, "and closes it")


func _pause_menu(riso: RisoPrint) -> void:
	print("the pause menu")
	var menu: Node = main.get_node("Menu")
	var button: Button = menu.get("debug_panel_button") as Button
	menu.call("pause_resume_game")
	check(paused and button.visible, "a debug run's pause menu offers the debug panel")
	button.pressed.emit()
	await frames(2)
	check(riso.panel.visible and paused and not (menu as CanvasLayer).visible, "which leaves the menu for the panel, still paused")
	riso.set_pad_panel(false)
	await frames(2)
	check(not paused, "closing the panel lets the game go on")
	MapInfo.debug = false
	menu.call("pause_resume_game")
	check(not button.visible, "outside debug runs the pause menu does not offer it")
	menu.call("pause_resume_game")
	MapInfo.debug = true
	await frames(2)


## Pick choice `i` of the panel's option `key`, as a click or the controller does.
func _pick(riso: RisoPrint, key: StringName, i: int) -> void:
	var pick: OptionButton = riso._options[key]
	pick.select(i)
	pick.item_selected.emit(i)


func _invincible(riso: RisoPrint) -> void:
	print("invincible")
	_pick(riso, &"invincible", 1)
	check(Health.invincible, "Invincible on sets the wizard invincible")
	var hearts: int = player.health.health
	player.end_invulnerable()
	player.hurt(-1, Vector2.LEFT, null)
	check_eq(player.health.health, hearts, "a blow takes no heart")
	player.fall_back()
	check_eq(player.health.health, hearts, "nor does a fall")
	MapInfo.debug = false
	player.end_invulnerable()
	player.hurt(-1, Vector2.LEFT, null)
	check_eq(player.health.health, hearts - 1, "outside a debug run it does nothing")
	MapInfo.debug = true
	player.health.health = hearts
	_pick(riso, &"invincible", 0)
	player.end_invulnerable()
	player.hurt(-1, Vector2.LEFT, null)
	check(not Health.invincible and player.health.health == hearts - 1, "off, a blow takes a heart again")
	player.health.health = hearts
	player.end_invulnerable()
	await frames(2)


func _note_bolt(n: Node) -> void:
	if n is HexBolt:
		bolts.append(n as HexBolt)


## Hold the Spell button until a bolt flies (or long past an empowered hold), then let go.
func _hold_cast() -> void:
	bolts.clear()
	(player.get_node("Hex") as Hex).refill()
	Input.action_press(Abilities.SPELL_ACTION)
	await within(func() -> bool: return not bolts.is_empty(), Empower.HOLD + 0.3)
	Input.action_release(Abilities.SPELL_ACTION)
	await frames(3)


func _empowered(riso: RisoPrint) -> void:
	print("empowered")
	info.map_elements.child_entered_tree.connect(_note_bolt)
	info.run.tempered.clear()
	Abilities.set_tier(player, &"hex", 1)
	var empower: Empower = Empower.of(player)
	check(not empower.ready_now(), "with no lodestone touched, nothing casts empowered")
	_pick(riso, &"empowered", 1)
	check(Empower.always and empower.ready_now() and empower.readiness() == 1.0, "Empowered on: the spell in the slot is ready to cast empowered")
	await _hold_cast()
	check(bolts.size() == 1 and bolts[0].empowered, "held, an empowered bolt flies")
	check(empower.wait == 0.0 and empower.ready_now(), "and empowerment is back at once")
	await _hold_cast()
	check(bolts.size() == 1 and bolts[0].empowered, "so the next held press casts empowered too")
	_pick(riso, &"empowered", 0)
	check(not Empower.always and not empower.ready_now(), "off, the untempered spell casts as ever")
	await _hold_cast()
	check(bolts.size() == 1 and not bolts[0].empowered, "a plain bolt, held or not")
	info.map_elements.child_entered_tree.disconnect(_note_bolt)


func _darkness(riso: RisoPrint) -> void:
	print("darkness")
	info.run.dark_charges = 0
	riso._sync_panel()
	var row: Node = riso._darkness_label.get_parent()
	var fewer: Button = row.get_child(1) as Button
	var more: Button = row.get_child(3) as Button
	more.pressed.emit()
	more.pressed.emit()
	check(info.run.dark_charges == 2 and riso._darkness_label.text == "2", "+ adds a charge of darkness, shown on the panel")
	for i: int in range(3):
		fewer.pressed.emit()
	check(info.run.dark_charges == 0 and riso._darkness_label.text == "0", "- takes them away, never below none")
