extends SceneTree
## Phase 5 of docs/DEEPER_PLAN.md: start modes, background pre-generation of neighbouring
## levels, and saving and continuing a run. Uses its own save file.
## godot --headless --path . --script res://tests/interface_test.gd

var main: Node
var info: MapInfo
var player: Player
var menu: Node
var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(frames: int = 4) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame


func boot() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	menu = main.get_node("Menu")
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	await process_frame


func placed(scene: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == scene and not node.is_queued_for_deletion():
			found.append(node)
	return found


func run() -> void:
	MapInfo.save_path = "user://test_interface.save"
	MapInfo.delete_save()

	print("start menu")
	await boot()
	check(not menu.continue_button.visible, "no save: no Continue")
	menu.world_seed.text = ""
	menu.start_game()
	player = main.get_node("Player") as Player
	await settle()
	var rolled: int = int(menu.world_seed.text)
	check(menu.world_seed.text.is_valid_int() and info.coord == Vector2i(rolled, 0), "a blank world starts at a random world (%d)" % rolled)
	check(menu.start.text == "Resume" and menu.copy.visible and not menu.continue_button.visible, "the menu becomes the pause menu")
	menu.pause_resume_game()
	await process_frame
	check(menu.visible and paused and menu.where.text == MapInfo.where(info.coord), "pausing shows where you are")
	menu.pause_resume_game()
	await process_frame
	check(not menu.visible and not paused, "and resumes")

	print("pre-generation")
	var s: int = info.coord.x
	var neighbours: Array[Vector2i] = [Vector2i(s, 1), Vector2i(s + 1, 0), Vector2i(s - 1, 0)]
	var deadline: int = Time.get_ticks_msec() + 60000
	while neighbours.any(func(c: Vector2i) -> bool: return not info.cache.has(c)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(neighbours.all(func(c: Vector2i) -> bool: return info.cache.has(c)), "deeper, left and right are generated in the background")
	while info.gen_busy:
		await process_frame
	var fresh: Array = info.wfc.generate_level(MapInfo.def_for(Vector2i(s + 1, 0)))
	check(fresh == info.cache[Vector2i(s + 1, 0)], "a cached level is exactly the level generated fresh")
	var frames: int = 0
	info.travel(MapInfo.Exit.RIGHT)
	# The printed transition covers the view first; caching should make the rest instant.
	var sheet: RisoTransition = RisoTransition.instance
	while sheet != null and sheet.state == RisoTransition.State.COVERING:
		await process_frame
	while info.travelling and frames < 600:
		await process_frame
		frames += 1
	check(info.coord == Vector2i(s + 1, 0) and frames <= 3, "once the sheet covers the view, the cached level is up in %d frame(s)" % frames)
	var held: int = 0
	while sheet != null and sheet.state == RisoTransition.State.COVERED and held < 120:
		await process_frame
		held += 1
	check(sheet != null and sheet.state == RisoTransition.State.REVEALING and held > 5, "then holds to show where you are, and sweeps away")
	info.travel(MapInfo.Exit.LEFT)
	await settle()

	print("saving")
	player.set_physics_process(false)
	var coin: Node = placed("coin.tscn")[0]
	var coin_cell: Vector2i = coin.get_meta(&"cell")
	coin.call("touch", player)
	var lantern: Node = placed("checkpoint.tscn")[1]
	lantern.call("interacted")
	var lantern_cell: Vector2i = lantern.get_meta(&"cell")
	Abilities.grant(player, &"double_jump")
	player.collect(9)
	player.die()
	await settle()
	player.collect(7)
	player.set_meta(&"carried_key", 2)
	player.health.health = 2
	menu.pause_resume_game()
	await process_frame
	menu.pause_resume_game()
	var saved: Dictionary = MapInfo.read_save()
	check(not saved.is_empty() and int(saved["run_seed"]) == s, "pausing saved the run")
	var ghost_stars: int = info.ghost_stars
	main.queue_free()
	await process_frame
	await process_frame

	print("continuing")
	await boot()
	check(menu.continue_button.visible and menu.where.text.contains(MapInfo.where(Vector2i(s, 0))), "Continue is offered, naming the saved level")
	menu.continue_game()
	player = main.get_node("Player") as Player
	await settle()
	check(info.coord == Vector2i(s, 0) and player.global_position.distance_to(info.cell_position(lantern_cell)) < 80.0, "resumes at the last lit lantern")
	check(player.coins.coins == 7 and int(player.get_meta(&"carried_key", -1)) == 2 and player.health.health == 2, "with its stars, key and health")
	check(Abilities.tier(player, &"double_jump") == 1 and player.MAX_JUMPS == 2, "and its abilities")
	check(info.vulnerable and info.has_ghost and info.ghost_stars == ghost_stars and placed("corpse.tscn").size() == 1, "and its ghost, still vulnerable")
	check(not placed("coin.tscn").any(func(n: Node) -> bool: return n.get_meta(&"cell") == coin_cell), "and its level records")
	check(info.run_seed == s, "on the same world")

	print("controller")
	var pad: Callable = func(ev: InputEvent) -> void:
		Input.parse_input_event(ev)
	var press_button: Callable = func(button: JoyButton, down: bool) -> InputEventJoypadButton:
		var b: InputEventJoypadButton = InputEventJoypadButton.new()
		b.button_index = button
		b.pressed = down
		return b
	pad.call(press_button.call(JOY_BUTTON_START, true))
	await process_frame
	pad.call(press_button.call(JOY_BUTTON_START, false))
	await process_frame
	check(menu.visible and paused and root.gui_get_focus_owner() == menu.start, "Start pauses, with Resume focused")
	var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1.0
	pad.call(stick)
	await process_frame
	var centre: InputEventJoypadMotion = InputEventJoypadMotion.new()
	centre.axis = JOY_AXIS_LEFT_Y
	centre.axis_value = 0.0
	pad.call(centre)
	await process_frame
	check(root.gui_get_focus_owner() != menu.start and root.gui_get_focus_owner() is Button, "the left stick moves down the menu (to %s)" % (root.gui_get_focus_owner().name if root.gui_get_focus_owner() != null else "nothing"))
	pad.call(press_button.call(JOY_BUTTON_B, true))
	await process_frame
	pad.call(press_button.call(JOY_BUTTON_B, false))
	await process_frame
	check(not menu.visible and not paused, "B backs out of the pause menu")

	print("back to the main menu")
	menu.pause_resume_game()
	await process_frame
	check(menu.main_menu.visible, "the pause menu offers the main menu")
	menu.main_menu.pressed.emit()
	await process_frame
	await process_frame
	main = root.get_node("Main")
	menu = main.get_node("Menu")
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	check(not paused and menu.visible and not menu.started and not main.has_node("Player") and not menu.main_menu.visible, "it opens a fresh start menu, unpaused, with no run going")
	check(menu.continue_button.visible and root.get_node_or_null("MainLeaving") == null, "with Continue offered, and the old run gone")
	menu.continue_game()
	player = main.get_node("Player") as Player
	await settle()
	check(info.coord == Vector2i(s, 0) and player.coins.coins == 7, "and Continue picks the run up again")

	print("debug runs")
	main.queue_free()
	await process_frame
	await process_frame
	MapInfo.delete_save()
	await boot()
	menu.call("set_debug", true)
	menu.world_seed.text = "28"
	menu.start_game()
	player = main.get_node("Player") as Player
	await settle()
	check(player.coins.coins == MapInfo.DEBUG_STARS, "a debug run starts with %d stars" % MapInfo.DEBUG_STARS)
	var back: Vector2i = info.world.exits[MapInfo.Exit.BACK]
	var spread: int = 0
	for which: int in info.world.exits:
		var e: Vector2i = info.world.exits[which]
		spread = maxi(spread, absi(e.x - back.x) + absi(e.y - back.y))
	check(spread <= 10, "every exit is within %d cells of the spawn" % spread)
	check(info.seen_count() == info.world.size.x * info.world.size.y and not bool(info.record().get("mapped", false)), "the whole map is seen from the start, and the ink well still sells")
	check(bool(MapInfo.read_save().get("debug", false)), "the save remembers it is a debug run")
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	var arrive: Vector2i = info.world.exits[MapInfo.Exit.BACK]
	check(info.world.exits.values().all(func(e: Vector2i) -> bool: return absi(e.x - arrive.x) + absi(e.y - arrive.y) <= 10), "and so in every level")
	check(info.seen_count() == info.world.size.x * info.world.size.y, "the next level's map is seen too")

	print("the F7 panel by controller (debug runs)")
	var riso: RisoPrint = RisoPrint.instance
	var select: InputEventJoypadButton = InputEventJoypadButton.new()
	select.button_index = JOY_BUTTON_BACK
	select.pressed = true
	Input.parse_input_event(select)
	await process_frame
	await process_frame
	var focus: Control = root.gui_get_focus_owner()
	check(riso.panel.visible and paused and focus != null and riso.panel.is_ancestor_of(focus), "Back opens it, paused, with a control focused for the pad")
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await process_frame
	await process_frame
	check(not riso.panel.visible and not paused, "B closes it and play goes on")

	print("debug travel")
	Input.parse_input_event(select)
	await process_frame
	await process_frame
	focus = root.gui_get_focus_owner()
	check(focus != null and riso._travel_box.is_ancestor_of(focus), "the panel opens on its Travel rows")
	var from: Vector2i = info.coord
	check(riso._travel_at == from, "set to where the wizard is")
	riso._travel(Vector2i(from.x, RisoPrint._nearest_band(&"cemetery", from.y)))
	await settle()
	check(not riso.panel.visible and not paused and info.here.cemetery() and info.coord.x == from.x, "Cemetery goes to the nearest cemetery band (%s)" % info.coord)
	riso._travel(Vector2i(from.x + 5, 7))
	await settle()
	check(info.coord == Vector2i(from.x + 5, 7) and player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 200.0, "Go goes to any world and depth, arriving at its way back")
	riso._travel(Worlds.side_at(0, info.coord))
	await settle()
	check(Worlds.kind_at(info.coord) == 0, "and into hyperspace")
	MapInfo.debug = false
	riso._travel(Vector2i(1, 1))
	await settle()
	check(Worlds.kind_at(info.coord) == 0, "outside debug runs it goes nowhere")
	Input.parse_input_event(select)
	await process_frame
	await process_frame
	check(not riso.panel.visible and not paused, "outside debug runs Back does nothing")

	MapInfo.delete_save()
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: deeper phase 5")
		quit()
