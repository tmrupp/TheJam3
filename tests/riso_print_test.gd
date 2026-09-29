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
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.map_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	main.get_node("UpgradeMenu").done()
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
	# Wizard reacts to real player events without errors.
	player.jump()
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
	# Sheets advance on the clock.
	var before: int = riso.sheet_index
	for i: int in range(40):
		await process_frame
	check(riso.sheet_index > before or riso.sheet_rate == 0.0, "new sheets are printed")
	# Realm follows the world and cycles.
	riso.cycle_realm()
	check(riso.realm == &"twilight", "realm cycles")
	# Off switch restores the original presentation.
	riso.set_enabled(false)
	await process_frame
	check(not riso.print_layer.visible, "print hidden when off")
	check(root.content_scale_mode == original_mode, "stretch mode restored when off")
	check(root.canvas_cull_mask == original_mask & ~(RisoPrint.overlay_mask() | 0x3F000), "cull mask restored when off")
	check(not wizard.visible, "ink art hidden when off")
	riso.set_enabled(true)
	await process_frame
	check(riso.print_layer.visible and wizard.visible, "print back on")
	main.queue_free()
	await process_frame
	await process_frame
	print("RISO TEST: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
