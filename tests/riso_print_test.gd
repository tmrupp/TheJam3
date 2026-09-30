extends SceneTree
## Headless checks for the riso print integration in the generated main game.
## godot --headless --path . --script res://tests/riso_print_test.gd

var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + what)
	else:
		print("ok  ", what)


func run() -> void:
	var original_mode: Window.ContentScaleMode = root.content_scale_mode
	var original_mask: int = root.canvas_cull_mask
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	var info: Node = main.get_node("CanvasLayer/MapInfo")
	var deadline: int = Time.get_ticks_msec() + 20000
	while info.world == null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(info.world != null, "world generated")
	for i: int in range(20):
		await physics_frame
		await process_frame
	var riso: RisoPrint = RisoPrint.instance
	check(riso != null and riso.enabled, "RisoPrint present and on")
	check(not main.has_node("UpgradeMenu") and not paused, "game starts without the upgrade shop")
	check(not (main.get_node("CanvasLayer/HUD/TopHUD") as CanvasItem).visible, "pixel HUD hidden while printing")
	check(main.get_node_or_null("RisoHud") != null, "printed HUD present")
	check((load(RisoTheme.MENU_THEME) as Theme).default_font is SystemFont, "menus use the riso theme")
	check(riso.plates.size() == RisoPrint.PLATE_COUNT, "six ink plates")
	check(riso.print_layer.visible, "print layer visible")
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "canvas_items stretch while printing")
	check((root.canvas_cull_mask & RisoPrint.plate_mask(RisoPrint.BLUE)) == 0, "main view hides plate layers")
	var player: Player = main.get_node("Player") as Player
	var wizard: Node2D = player.get_node_or_null("RisoWizard") as Node2D
	check(wizard != null, "player wears the wizard")
	var terrain: Node = main.get_node_or_null("RisoTerrain")
	check(terrain != null and (terrain.get("ink") as Node).get_child_count() >= 4, "terrain printed from the tilemap")
	var dressed: int = 0
	var expected: int = 0
	for node: Node in info.map_elements.get_children():
		if RisoPrint.DRESS.has(node.scene_file_path):
			expected += 1
			if node.has_node("RisoArt"):
				dressed += 1
	check(expected > 0 and dressed == expected, "all %d spawned prefabs dressed (%d)" % [expected, dressed])
	var kinds: Dictionary = {}
	for art: Node in get_nodes_in_group(&"riso_art"):
		if art.get("kind") != null:
			kinds[art.get("kind")] = true
	print("dressed kinds: ", kinds.keys())
	var lift: Node2D = null
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path == "res://prefabs/moving_platform.tscn":
			lift = node as Node2D
			break
	check(lift != null, "moving platforms generated")
	if lift != null:
		var was: Vector2 = lift.global_position
		for i: int in range(10):
			await physics_frame
		check(lift.global_position != was, "moving platform moves")
	var fx: RisoFx = RisoFx.instance
	check(fx != null, "particle layer present")
	# Wizard reacts to real player events without errors.
	player.jump()
	await process_frame
	check(fx != null and fx.parts.size() > 0, "jump kicks up particles")
	player.dash.enable()
	player.do_dash(Vector2.RIGHT)
	for i: int in range(12):
		await physics_frame
		await process_frame
	check((wizard.get("trail") as Array).size() > 0, "dash leaves a smear trail")
	check(riso.glow_ability == &"dash", "hat glow follows the dash")
	player.parry.emit()
	await process_frame
	check(riso.glow_ability == &"parry", "hat glow follows parry")
	player.normal_hurt(-1, Vector2.ZERO, null)
	for i: int in range(8):
		await physics_frame
		await process_frame
	check(player.invulnerable.is_acting(), "hurt state reached (flash frames drawn)")
	var projection: Node = player.get_node("AstralProjection")
	projection.project()
	await process_frame
	await process_frame
	check((wizard.get("ghosts") as Array).size() > 0, "astral projection leaves a ghost")
	projection.end_projection(projection.projection_timer)
	# Sheets advance on the clock (motion gating off, so an idle player can't stall the check).
	var before: int = riso.sheet_index
	riso.reprint_on_motion = false
	for i: int in range(40):
		await process_frame
	riso.reprint_on_motion = true
	check(riso.sheet_index > before or riso.sheet_rate == 0.0, "new sheets are printed")
	# Keys: carried one at a time, open only doors of their colour.
	var key_node: Node = null
	var door_node: Node = null
	for node: Node in info.map_elements.get_children():
		if key_node == null and node.scene_file_path == "res://prefabs/key.tscn":
			key_node = node
	for node: Node in info.map_elements.get_children():
		if door_node == null and node.scene_file_path == "res://prefabs/door.tscn" and key_node != null and int(node.get_meta(&"key_color", -1)) == int(key_node.get_meta(&"key_color", -2)):
			door_node = node
	check(key_node != null and door_node != null, "a key and a door of the same colour exist")
	if key_node != null and door_node != null:
		if player.has_meta(&"carried_key"):
			player.remove_meta(&"carried_key")
		key_node.call("touch", player)
		check(player.has_meta(&"carried_key") and int(player.get_meta(&"carried_key")) == int(key_node.get_meta(&"key_color")), "picking up a key carries its colour")
		var other_key: Node = null
		for node: Node in info.map_elements.get_children():
			if node != key_node and node.scene_file_path == "res://prefabs/key.tscn" and is_instance_valid(node) and int(node.get_meta(&"key_color", -1)) != int(key_node.get_meta(&"key_color")):
				other_key = node
				break
		if other_key != null:
			other_key.call("touch", player)
			check(int(player.get_meta(&"carried_key")) == int(other_key.get_meta(&"key_color")), "a new key replaces the carried one")
			key_node.call("touch", player)
			check(int(player.get_meta(&"carried_key")) == int(other_key.get_meta(&"key_color")), "a collected key cannot be picked up again")
			player.set_meta(&"carried_key", int(key_node.get_meta(&"key_color")))
		var wrong: Node = null
		for node: Node in info.map_elements.get_children():
			if node.scene_file_path == "res://prefabs/door.tscn" and int(node.get_meta(&"key_color", -1)) != int(player.get_meta(&"carried_key")):
				wrong = node
				break
		if wrong != null:
			wrong.get_node("Unlock").call("try_open")
			check(is_instance_valid(wrong) and not wrong.is_queued_for_deletion() and player.has_meta(&"carried_key"), "a door of another colour stays shut")
		door_node.get_node("Unlock").call("try_open")
		check(door_node.is_queued_for_deletion() and player.has_meta(&"carried_key"), "the matching door opens and the key is kept")
	# Realm follows the world and cycles.
	check(riso.realm == &"twilight" and riso.reprint_on_motion and riso.blend_sheets and riso.sheet_rate == 8.0, "defaults: twilight, 8/s, reprint on motion, blend")
	var cam: Camera2D = main.get_node("Camera2D") as Camera2D
	check(is_equal_approx(cam.zoom.x, 0.25 * riso.zoom_factor), "camera zoomed out while printing")
	riso.cycle_realm()
	check(riso.realm == &"aurora", "realm cycles")
	# Off switch restores the original presentation.
	riso.set_enabled(false)
	await process_frame
	check(not riso.print_layer.visible, "print hidden when off")
	check(root.content_scale_mode == original_mode, "stretch mode restored when off")
	check(root.canvas_cull_mask == original_mask & ~(RisoPrint.overlay_mask() | 0x3F000), "cull mask restored when off")
	check(not wizard.visible, "ink art hidden when off")
	check((main.get_node("CanvasLayer/HUD/TopHUD") as CanvasItem).visible, "pixel HUD back when off")
	check((load(RisoTheme.MENU_THEME) as Theme).default_font is FontFile, "menu theme restored when off")
	check(is_equal_approx(cam.zoom.x, 0.25), "camera zoom restored when off")
	riso.set_enabled(true)
	await process_frame
	check(riso.print_layer.visible and wizard.visible, "print back on")
	main.queue_free()
	await process_frame
	await process_frame
	print("RISO TEST: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
